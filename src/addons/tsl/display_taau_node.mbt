// examples/jsm/tsl/display/TAAUNode.js

///|
priv struct TAAUNodeModule {
  quad_mesh : @nodes.QuadMesh
  /// `_haltonOffsets`, computed after the class (upstream statement order).
  halton_offsets : Array[(Double, Double)]
}

///|
let _taau_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _taau_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let display_taau_node_module : AddonModule[TAAUNodeModule] = AddonModule::new(fn() {
  // imports: TAAUtils.js
  load_utils_taa_utils()
  let quad_mesh = @nodes.QuadMesh::new()
  let halton_offsets = compute_halton_offsets(32)
  { quad_mesh, halton_offsets, }
})

///|
/// Evaluates TAAUNode.js (its `_quadMesh` and `_haltonOffsets`), as `import` does.
pub fn load_display_taau_node() -> Unit {
  display_taau_node_module.get() |> ignore
}

///|
/// Temporal Anti-Aliasing Upscaling: like TRAA, with lower-resolution inputs resolved to
/// the drawing buffer's resolution (MSAA must be disabled).
pub(all) struct TAAUNode {
  mut beauty_node : @nodes.Node
  mut depth_node : @nodes.Node
  mut velocity_node : @nodes.Node
  mut camera : @core.Object3D
  /// Depth difference above which the history is considered invalid.
  mut depth_threshold : Double
  /// Depth difference within the 3x3 neighborhood that marks an edge.
  mut edge_depth_diff : Double
  /// The pixel velocity length at which the history becomes invalid.
  mut max_velocity_length : Double
  /// Baseline weight of the current frame in the resolve.
  mut current_frame_weight : Double
  mut _jitter_index : Int32
  _jitter_offset : @nodes.Node
  _history_render_target : @core.RenderTarget
  _resolve_render_target : @core.RenderTarget
  _previous_depth_render_target : @core.RenderTarget
  _resolve_material : @core.Material
  _seed_material : @core.Material
  _texture_node : @nodes.Node
  _original_projection_matrix : @math.Matrix4
  _camera_near_far : @nodes.Node
  _camera_world_matrix : @nodes.Node
  _camera_world_matrix_inverse : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _previous_camera_world_matrix : @nodes.Node
  _previous_camera_projection_matrix_inverse : @nodes.Node
  _previous_depth_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for TAAUNode with fn class_name(_) {
  "TAAUNode"
}

///|
pub impl @nodes.NodeClass for TAAUNode with fn has_flag(_, flag) {
  flag == "isTAAUNode"
}

///|
pub impl @nodes.NodeClass for TAAUNode with fn children(self, _, out) {
  @nodes.push_child(out, "beautyNode", Some(self.beauty_node))
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "velocityNode", Some(self.velocity_node))
}

///|
/// `getTextureNode()`: the result of the effect.
pub fn TAAUNode::get_texture_node(self : TAAUNode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( outputWidth, outputHeight )`: the history and resolve targets' size.
pub fn TAAUNode::set_size(
  self : TAAUNode,
  output_width : Double,
  output_height : Double,
) -> Unit {
  self._history_render_target.set_size(
    output_width.to_int(),
    output_height.to_int(),
  )
  self._resolve_render_target.set_size(
    output_width.to_int(),
    output_height.to_int(),
  )
}

///|
/// `setViewOffset( inputWidth, inputHeight )`: the current jitter as a view offset of
/// the camera.
pub fn TAAUNode::set_view_offset(
  self : TAAUNode,
  input_width : Double,
  input_height : Double,
) -> Unit {
  let halton_offsets = display_taau_node_module.get().halton_offsets
  // save original/unjittered projection matrix for velocity pass
  self.camera.update_projection_matrix()
  self._original_projection_matrix.copy(self.camera.projection_matrix())
  |> ignore
  @nodes.VelocityNode::set_projection_matrix(
    @nodes.velocity,
    Some(self._original_projection_matrix),
  )
  // The jitter range must span one output pixel (not one input pixel),
  // so we shrink the input-pixel-unit offset by the ratio of input to
  // output resolution.
  let halton_offset = halton_offsets[self._jitter_index]
  let jitter_x = halton_offset.0 - 0.5
  let jitter_y = halton_offset.1 - 0.5
  traa_uniform_vector2(self._jitter_offset).set(jitter_x, jitter_y) |> ignore
  self.camera.set_view_offset(
    input_width, input_height, jitter_x, jitter_y, input_width, input_height,
  )
}

///|
/// `clearViewOffset()`: clears the camera's view offset and advances the jitter.
pub fn TAAUNode::clear_view_offset(self : TAAUNode) -> Unit {
  let halton_offsets = display_taau_node_module.get().halton_offsets
  self.camera.clear_view_offset()
  @nodes.VelocityNode::set_projection_matrix(@nodes.velocity, None)
  // update jitter index
  self._jitter_index += 1
  self._jitter_index = self._jitter_index % halton_offsets.length()
}

///|
pub impl @nodes.NodeClass for TAAUNode with fn update_before(self, _, frame) {
  let quad_mesh = display_taau_node_module.get().quad_mesh
  let renderer = frame.renderer.unwrap()
  // store previous frame matrices before updating current ones
  traa_uniform_matrix4(self._previous_camera_world_matrix).copy(
    traa_uniform_matrix4(self._camera_world_matrix),
  )
  |> ignore
  traa_uniform_matrix4(self._previous_camera_projection_matrix_inverse).copy(
    traa_uniform_matrix4(self._camera_projection_matrix_inverse),
  )
  |> ignore
  // update camera matrices uniforms
  traa_uniform_vector2(self._camera_near_far).set(
    @nodes.camera_near_of(self.camera),
    @nodes.camera_far_of(self.camera),
  )
  |> ignore
  traa_uniform_matrix4(self._camera_world_matrix).copy(self.camera.matrix_world)
  |> ignore
  traa_uniform_matrix4(self._camera_world_matrix_inverse).copy(
    self.camera.matrix_world_inverse(),
  )
  |> ignore
  traa_uniform_matrix4(self._camera_projection_matrix_inverse).copy(
    self.camera.projection_matrix_inverse(),
  )
  |> ignore
  // the output dimensions are derived from the renderer's drawing buffer
  let drawing_buffer_size = renderer.get_drawing_buffer_size(_taau_node_size)
  let output_width = drawing_buffer_size.x
  let output_height = drawing_buffer_size.y
  //
  _taau_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(renderer, state?=_taau_node_renderer_state.val),
  )
  //
  let needs_restart = self._history_render_target.width.to_double() !=
    output_width ||
    self._history_render_target.height.to_double() != output_height
  self.set_size(output_width, output_height)
  // every time the dimensions change we need fresh history data
  if needs_restart == true {
    // Seed the history with a bilinear upscale of the current beauty
    // buffer. Without this the first frames after a resize fade in
    // from black because the history target was cleared. The seed
    // material is a quad pass that samples beauty at output UVs, so
    // it produces an output-sized image regardless of the input size.
    renderer.set_render_target(Some(self._history_render_target))
    quad_mesh.set_material(self._seed_material)
    quad_mesh.object.name = "TAAU.seed"
    quad_mesh.render(renderer)
    renderer.set_render_target(None)
  }
  // resolve
  renderer.set_render_target(Some(self._resolve_render_target))
  quad_mesh.set_material(self._resolve_material)
  quad_mesh.object.name = "TAAU"
  quad_mesh.render(renderer)
  renderer.set_render_target(None)
  // update history
  renderer.copy_texture_to_texture(
    self._resolve_render_target.texture(),
    self._history_render_target.texture(),
  )
  // Copy the current scene depth into the previous-depth texture. We
  // keep the destination size locked to the source's actual dimensions
  // so that any one-frame timing mismatch between the scene pass's depth
  // attachment and the beauty render target's bookkeeping cannot
  // produce a copy with mismatched extents (which WebGPU rejects for
  // depth/stencil formats).
  let current_depth = @nodes.TextureNode::get_value(self.depth_node)
  let src_w = traa_image_width(current_depth)
  let src_h = traa_image_height(current_depth)
  if src_w > 0.0 && src_h > 0.0 {
    let dst_depth = self._previous_depth_render_target.depth_texture().unwrap()
    if traa_image_width(dst_depth) != src_w ||
      traa_image_height(dst_depth) != src_h {
      traa_set_image_size(dst_depth, src_w, src_h)
      dst_depth.set_needs_update(true)
    }
    renderer.copy_texture_to_texture(current_depth, dst_depth)
  }
  // restore
  @nodes.restore_renderer_state(
    renderer,
    _taau_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for TAAUNode with fn setup(self, node, builder) {
  display_taau_node_module.get() |> ignore
  self.depth_node.build(builder) |> ignore
  self.velocity_node.build(builder) |> ignore
  self.beauty_node.build(builder) |> ignore
  if traa_claim_view_offset(builder, node) {
    @nodes.on_before_render_pipeline(fn() {
      let beauty_render_target = traa_beauty_render_target(self.beauty_node)
      let input_width = beauty_render_target.texture().width()
      let input_height = beauty_render_target.texture().height()
      self.set_view_offset(input_width, input_height)
    })
    |> ignore
    @nodes.on_after_render_pipeline(fn() { self.clear_view_offset() }) |> ignore
  }
  let previous_depth_texture = self._previous_depth_render_target
    .depth_texture()
    .unwrap()
  previous_depth_texture.format = @nodes.TextureNode::get_value(self.depth_node).format
  previous_depth_texture.type_ = @nodes.TextureNode::get_value(self.depth_node).type_
  let history_node = @nodes.texture(self._history_render_target.textures[0])
  let lock_node = @nodes.texture(self._history_render_target.textures[1])
  // --- TAAU resolve ---
  //
  // For each output pixel, we map its position into input-pixel space,
  // find the closest jittered input sample, and reconstruct the current
  // color as a weighted sum of the 3×3 neighborhood around that sample.
  // Each tap's weight is a Gaussian approximation of a Blackman-Harris
  // window evaluated at the distance between the tap's (jittered)
  // sample center and the output pixel center. The same neighborhood
  // also supplies the moments used for variance clipping of the
  // reprojected history, so no second neighborhood read is needed.
  let color_output = @nodes.property("vec4")
  let lock_output = @nodes.property("vec4")
  let output_node = @nodes.output_struct([color_output, lock_output])
  let resolve = @nodes.fn_(fn(_, _) {
    let uv_node = @nodes.uv()
    let input_size = self.beauty_node.size() // ivec2
    let input_size_f = @nodes.vec2(input_size)
    // output pixel center in input-pixel coordinates
    let p_in = uv_node.mul(input_size_f)
    // the input sample at integer texel (m, n) was rendered at world
    // position (m + 0.5 + jitter). Solving for the closest tap gives:
    let closest_tap_f = p_in
      .sub(@nodes.vec2(0.5).add(self._jitter_offset))
      .round()
    let closest_tap = @nodes.ivec2(closest_tap_f)
    // depth dilation around the closest input tap
    let current_depth = sample_current_depth().call([
      self.depth_node,
      closest_tap_f,
      self._camera_near_far,
    ])
    let closest_depth = current_depth.get("closestDepth")
    let closest_position_texel = current_depth.get("closestPositionTexel")
    let farthest_depth = current_depth.get("farthestDepth")
    // reproject using the velocity sampled at the dilated depth tap
    let offset_uv = self.velocity_node
      .load(closest_position_texel)
      .xy()
      .mul(@nodes.vec2_of([0.5, -0.5]))
    let history_uv = uv_node.sub(offset_uv)
    let previous_depth = sample_previous_depth().call([
      self._previous_depth_node,
      history_uv,
      self._previous_camera_projection_matrix_inverse,
      self._previous_camera_world_matrix,
      self._camera_world_matrix_inverse,
      self._camera_near_far,
      self.camera,
    ])
    // history validity
    let is_valid_uv = history_uv
      .greater_than_equal(0)
      .all()
      .and_(history_uv.less_than_equal(1).all())
    let is_edge = farthest_depth
      .sub(closest_depth)
      .greater_than(self.edge_depth_diff)
    let is_disocclusion = closest_depth
      .sub(previous_depth)
      .greater_than(self.depth_threshold)
    let has_valid_history = is_valid_uv.and_(is_edge.or(is_disocclusion.not_()))
    // 9-tap Blackman-Harris (Gaussian approximation) reconstruction
    // of the current frame color, plus moment accumulation for the
    // variance clip of the history.
    let sum_color = @nodes.vec4(0).to_var()
    let sum_weight = @nodes.float(0).to_var()
    let moment1 = @nodes.vec4(0).to_var()
    let moment2 = @nodes.vec4(0).to_var()
    let offsets = [
      (-1, -1),
      (0, -1),
      (1, -1),
      (-1, 0),
      (0, 0),
      (1, 0),
      (-1, 1),
      (0, 1),
      (1, 1),
    ]
    for offset in offsets {
      let (x, y) = offset
      let tap = closest_tap.add(@nodes.ivec2_of([x, y]))
      let tap_center = @nodes.vec2(tap).add(
        @nodes.vec2(0.5).add(self._jitter_offset),
      )
      let delta = p_in.sub(tap_center)
      let d2 = delta.dot(delta)
      let w = @nodes.exp(d2.mul(-2.29))
      // Use max() to prevent NaN values from propagating.
      let c = self.beauty_node.load(tap).max(0)
      sum_color.add_assign(c.mul(w))
      sum_weight.add_assign(w)
      moment1.add_assign(c)
      moment2.add_assign(c.pow2())
    }
    let current_color = sum_color.div(sum_weight.max(1.0e-5))
    // variance clipping using the moments we just gathered
    let n = @nodes.float(offsets.length())
    let mean = moment1.div(n)
    let motion_factor = uv_node
      .sub(history_uv)
      .mul(input_size_f)
      .length()
      .div(self.max_velocity_length)
      .saturate()
    let variance_gamma = @nodes.mix(0.5, 1, motion_factor.one_minus().pow2())
    let variance = moment2
      .div(n)
      .sub(mean.pow2())
      .max(0)
      .sqrt()
      .mul(variance_gamma)
    let min_color = mean.sub(variance)
    let max_color = mean.add(variance)
    let history_color = history_node.sample(history_uv)
    let clipped_history_color = clip_aabb().call([
      mean.clamp(low=min_color, high=max_color),
      history_color,
      min_color,
      max_color,
    ])
    // Current weight. Under TAAU a single input frame covers less of
    // the output grid, so the baseline current weight is lower than
    // in standard TRAA to give the accumulator more frames to fill
    // in sub-pixel detail. Motion still biases toward the current
    // frame to keep disoccluded and fast-moving pixels responsive.
    let current_luma = @nodes.luminance(current_color.rgb())
    let mean_luma = @nodes.luminance(mean.rgb()).to_const()
    let thin_feature = current_luma
      .sub(mean_luma)
      .abs()
      .div(mean_luma)
      .smoothstep(0, 0.2)
    // Gate the lock by a two-sided depth change check. The
    // existing `isDisocclusion` is one-sided (only fires when
    // the scene moves farther), but new geometry appearing
    // closer also makes the history stale.
    let is_depth_changed = closest_depth
      .sub(previous_depth)
      .abs()
      .greater_than(self.depth_threshold)
    let can_lock = is_valid_uv.and_(is_depth_changed.not_())
    let gated_thin_feature = can_lock.select(
      thin_feature,
      else_node=@nodes.float(0),
    )
    let decay = is_disocclusion.select(0, else_node=0.5)
    let lock = @nodes.max(gated_thin_feature, lock_node.r().mul(decay)).saturate()
    let locked_history_color = @nodes.mix(
      clipped_history_color, history_color, lock,
    )
    let current_weight = @nodes.float(self.current_frame_weight).to_var()
    current_weight.assign(
      has_valid_history.select(
        current_weight.add(motion_factor).saturate(),
        else_node=1,
      ),
    )
    let output = flicker_reduction().call([
      current_color, locked_history_color, current_weight,
    ])
    color_output.assign(output)
    lock_output.assign(lock)
    Some(@nodes.vec4(0)) // temporary solution until TSL does not complain anymore
  })
  // materials
  let shared_context = @nodes.context(value=builder.get_shared_context())
  let resolve_material = @nodes.NodeMaterial::of(self._resolve_material).unwrap()
  resolve_material.context_node = Some(shared_context)
  resolve_material.color_node = Some(resolve.call([]))
  resolve_material.output_node = Some(output_node)
  let seed_material = @nodes.NodeMaterial::of(self._seed_material).unwrap()
  seed_material.color_node = Some(
    @nodes.fn_(fn(_, _) {
      color_output.assign(self.beauty_node.sample(@nodes.uv()))
      lock_output.assign(0)
      Some(@nodes.vec4(0))
    }).call([]),
  )
  seed_material.context_node = Some(shared_context)
  seed_material.output_node = Some(output_node)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for TAAUNode with fn dispose(self, node) {
  node.dispose_base()
  self._history_render_target.dispose()
  self._resolve_render_target.dispose()
  self._previous_depth_render_target.dispose()
  self._resolve_material.dispose()
  self._seed_material.dispose()
}

///|
/// The constructor body (after `Node::alloc(node_type="vec4")`).
pub fn TAAUNode::construct(
  node : @nodes.Node,
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
) -> TAAUNode {
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let jitter_offset = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let history_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
    count=2,
  )
  history_render_target.textures[0].name = "TAAUNode.history.color"
  history_render_target.textures[1].name = "TAAUNode.history.lock"
  let resolve_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  resolve_render_target.texture().name = "TAAUNode.resolve"
  let previous_depth_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    depth_texture=@core.DepthTexture::new(),
    count=0,
  )
  previous_depth_render_target.depth_texture().unwrap().name = "TAAUNode.previousDepth"
  let resolve_material = @nodes.NodeMaterial::new()
  resolve_material.name = "TAAU.resolve"
  let seed_material = @nodes.NodeMaterial::new()
  seed_material.name = "TAAU.seed"
  let texture_node = @nodes.pass_texture(node, resolve_render_target.texture())
  let original_projection_matrix = @math.Matrix4::new()
  let camera_near_far = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let camera_world_matrix = @nodes.uniform(@math.Matrix4::new())
  let camera_world_matrix_inverse = @nodes.uniform(@math.Matrix4::new())
  let camera_projection_matrix_inverse = @nodes.uniform(@math.Matrix4::new())
  let previous_camera_world_matrix = @nodes.uniform(@math.Matrix4::new())
  let previous_camera_projection_matrix_inverse = @nodes.uniform(
    @math.Matrix4::new(),
  )
  let previous_depth_node = @nodes.texture(
    previous_depth_render_target.depth_texture().unwrap(),
  )
  {
    beauty_node,
    depth_node,
    velocity_node,
    camera,
    depth_threshold: 0.0005,
    edge_depth_diff: 0.001,
    max_velocity_length: 128.0,
    current_frame_weight: 0.025,
    _jitter_index: 0,
    _jitter_offset: jitter_offset,
    _history_render_target: history_render_target,
    _resolve_render_target: resolve_render_target,
    _previous_depth_render_target: previous_depth_render_target,
    _resolve_material: resolve_material,
    _seed_material: seed_material,
    _texture_node: texture_node,
    _original_projection_matrix: original_projection_matrix,
    _camera_near_far: camera_near_far,
    _camera_world_matrix: camera_world_matrix,
    _camera_world_matrix_inverse: camera_world_matrix_inverse,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _previous_camera_world_matrix: previous_camera_world_matrix,
    _previous_camera_projection_matrix_inverse: previous_camera_projection_matrix_inverse,
    _previous_depth_node: previous_depth_node,
  }
}

///|
/// `new TAAUNode( beautyNode, depthNode, velocityNode, camera )`.
pub fn TAAUNode::new(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_taau_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(
    TAAUNode::construct(node, beauty_node, depth_node, velocity_node, camera),
  )
}

///|
pub fn TAAUNode::of(node : @nodes.Node) -> TAAUNode? {
  addon_class_of(node, "TAAUNode")
}

///|
/// `taau( beautyNode, depthNode, velocityNode, camera )`: Temporal Anti-Aliasing
/// Upscaling of `beautyNode`.
pub fn taau(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_taau_node_module.get() |> ignore
  TAAUNode::new(
    @nodes.convert_to_texture(beauty_node),
    depth_node,
    velocity_node,
    camera,
  )
}
