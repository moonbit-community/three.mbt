// examples/jsm/tsl/display/TRAANode.js

///|
priv struct TRAANodeModule {
  quad_mesh : @nodes.QuadMesh
  /// `_haltonOffsets`, computed after the class (upstream statement order).
  halton_offsets : Array[(Double, Double)]
}

///|
let _traa_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _traa_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let display_traa_node_module : AddonModule[TRAANodeModule] = AddonModule::new(fn() {
  // imports: TAAUtils.js
  load_utils_taa_utils()
  let quad_mesh = @nodes.QuadMesh::new()
  let halton_offsets = compute_halton_offsets(32)
  { quad_mesh, halton_offsets, }
})

///|
/// Evaluates TRAANode.js (its `_quadMesh` and `_haltonOffsets`), as `import` does.
pub fn load_display_traa_node() -> Unit {
  display_traa_node_module.get() |> ignore
}

///|
/// Temporal Reprojection Anti-Aliasing (MSAA must be disabled).
pub(all) struct TRAANode {
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
  /// Whether to decrease the current frame's weight for subpixel velocities.
  mut use_subpixel_correction : Bool
  mut _jitter_index : Int32
  _inv_size : @nodes.Node
  mut _history_render_target : @core.RenderTarget
  mut _resolve_render_target : @core.RenderTarget
  _previous_depth_render_target : @core.RenderTarget
  _resolve_material : @core.Material
  _texture_node : @nodes.Node
  _original_projection_matrix : @math.Matrix4
  _camera_near_far : @nodes.Node
  _camera_world_matrix : @nodes.Node
  _camera_world_matrix_inverse : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _previous_camera_world_matrix : @nodes.Node
  _previous_camera_projection_matrix_inverse : @nodes.Node
  _history_texture_node : @nodes.Node
  _previous_depth_node : @nodes.Node
  mut _velocity_node : @nodes.Node?
}

///|
pub impl @nodes.NodeClass for TRAANode with fn class_name(_) {
  "TRAANode"
}

///|
pub impl @nodes.NodeClass for TRAANode with fn has_flag(_, flag) {
  flag == "isTRAANode"
}

///|
pub impl @nodes.NodeClass for TRAANode with fn children(self, _, out) {
  @nodes.push_child(out, "beautyNode", Some(self.beauty_node))
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "velocityNode", Some(self.velocity_node))
}

///|
/// `getTextureNode()`: the result of the effect.
pub fn TRAANode::get_texture_node(self : TRAANode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`.
pub fn TRAANode::set_size(
  self : TRAANode,
  width : Double,
  height : Double,
) -> Unit {
  self._history_render_target.set_size(width.to_int(), height.to_int())
  self._resolve_render_target.set_size(width.to_int(), height.to_int())
  let previous_depth_texture = self._previous_depth_render_target
    .depth_texture()
    .unwrap()
  if traa_image_width(previous_depth_texture) != width ||
    traa_image_height(previous_depth_texture) != height {
    traa_set_image_size(previous_depth_texture, width, height)
    previous_depth_texture.set_needs_update(true)
  }
  traa_uniform_vector2(self._inv_size).set(1.0 / width, 1.0 / height) |> ignore
}

///|
/// `setViewOffset( width, height )`: the current jitter as a view offset of the camera.
pub fn TRAANode::set_view_offset(
  self : TRAANode,
  width : Double,
  height : Double,
) -> Unit {
  let halton_offsets = display_traa_node_module.get().halton_offsets
  // save original/unjittered projection matrix for velocity pass
  self.camera.update_projection_matrix()
  self._original_projection_matrix.copy(self.camera.projection_matrix())
  |> ignore
  @nodes.VelocityNode::set_projection_matrix(
    self._velocity_node.unwrap(),
    Some(self._original_projection_matrix),
  )
  //
  let full_width = width
  let full_height = height
  let offset_x = 0.0
  let offset_y = 0.0
  let jitter_offset = halton_offsets[self._jitter_index]
  self.camera.set_view_offset(
    full_width,
    full_height,
    offset_x + jitter_offset.0 - 0.5,
    offset_y + jitter_offset.1 - 0.5,
    width,
    height,
  )
}

///|
/// `clearViewOffset()`: clears the camera's view offset and advances the jitter.
pub fn TRAANode::clear_view_offset(self : TRAANode) -> Unit {
  let halton_offsets = display_traa_node_module.get().halton_offsets
  self.camera.clear_view_offset()
  @nodes.VelocityNode::set_projection_matrix(self._velocity_node.unwrap(), None)
  // update jitter index
  self._jitter_index += 1
  self._jitter_index = self._jitter_index % halton_offsets.length()
}

///|
pub impl @nodes.NodeClass for TRAANode with fn update_before(self, _, frame) {
  let quad_mesh = display_traa_node_module.get().quad_mesh
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
  // keep the TRAA in sync with the dimensions of the beauty node
  let beauty_render_target = traa_beauty_render_target(self.beauty_node)
  let width = beauty_render_target.texture().width()
  let height = beauty_render_target.texture().height()
  _traa_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(renderer, state?=_traa_node_renderer_state.val),
  )
  //
  let needs_restart = self._history_render_target.width.to_double() != width ||
    self._history_render_target.height.to_double() != height
  self.set_size(width, height)
  // swap history and resolve
  let history_render_target = self._history_render_target
  self._history_render_target = self._resolve_render_target
  self._resolve_render_target = history_render_target
  @nodes.TextureNode::set_value(
    self._history_texture_node,
    Some(self._history_render_target.texture()),
  )
  @nodes.TextureNode::set_value(
    self._texture_node,
    Some(self._resolve_render_target.texture()),
  )
  // every time when the dimensions change we need fresh history data
  if needs_restart == true {
    // make sure to reset the history with the contents of the beauty buffer otherwise subsequent frames after the
    // resize will fade from a darker color to the correct one because the history was cleared with black.
    renderer.copy_texture_to_texture(
      beauty_render_target.texture(),
      self._history_render_target.texture(),
    )
  }
  // resolve
  renderer.set_render_target(Some(self._resolve_render_target))
  quad_mesh.set_material(self._resolve_material)
  quad_mesh.object.name = "TRAA"
  quad_mesh.render(renderer)
  renderer.set_render_target(None)
  // Copy current depth to previous depth buffer
  let size = renderer.get_drawing_buffer_size(_traa_node_size)
  // only allow the depth copy if the dimensions of the history render target match with the drawing
  // render buffer and thus the depth texture of the scene. For some reasons, there are timing issues
  // with WebGPU resulting in different size of the drawing buffer and the beauty render target when
  // resizing the browser window. This does not happen with the WebGL backend
  if self._history_render_target.height.to_double() == size.y &&
    self._history_render_target.width.to_double() == size.x {
    let current_depth = @nodes.TextureNode::get_value(self.depth_node)
    renderer.copy_texture_to_texture(
      current_depth,
      self._previous_depth_render_target.depth_texture().unwrap(),
    )
  }
  // restore
  @nodes.restore_renderer_state(
    renderer,
    _traa_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for TRAANode with fn setup(self, node, builder) {
  display_traa_node_module.get() |> ignore
  self.depth_node.build(builder) |> ignore
  self.velocity_node.build(builder) |> ignore
  self.beauty_node.build(builder) |> ignore
  if traa_claim_view_offset(builder, node) {
    @nodes.on_before_render_pipeline(fn() {
      let size = builder.renderer.get_drawing_buffer_size(_traa_node_size)
      self.set_view_offset(size.x, size.y)
    })
    |> ignore
    @nodes.on_after_render_pipeline(fn() { self.clear_view_offset() }) |> ignore
  }
  let previous_depth_texture = self._previous_depth_render_target
    .depth_texture()
    .unwrap()
  previous_depth_texture.format = @nodes.TextureNode::get_value(self.depth_node).format
  previous_depth_texture.type_ = @nodes.TextureNode::get_value(self.depth_node).type_
  match builder.context.get("velocity") {
    Undefined => self._velocity_node = Some(@nodes.velocity)
    Node(v) => self._velocity_node = Some(v)
    _ => abort("TRAANode: context.velocity is not a node")
  }
  // Performs variance clipping.
  // See: https://developer.download.nvidia.com/gameworks/events/GDC2016/msalvi_temporal_supersampling.pdf
  let variance_clipping = @nodes.fn_(fn(inputs, _) {
    let position_texel = addon_arg(inputs, 0)
    let current_color = addon_arg(inputs, 1)
    let history_color = addon_arg(inputs, 2)
    let gamma = addon_arg(inputs, 3)
    let offsets = [
      (-1, -1),
      (-1, 1),
      (1, -1),
      (1, 1),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, 0),
    ]
    let moment1 = current_color.to_var()
    let moment2 = current_color.pow2().to_var()
    for offset in offsets {
      let (x, y) = offset
      // Use max() to prevent NaN values from propagating.
      let neighbor = self.beauty_node
        .offset(@nodes.ivec2_of([x, y]))
        .load(position_texel)
        .max(0)
      moment1.add_assign(neighbor)
      moment2.add_assign(neighbor.pow2())
    }
    let n = @nodes.float(offsets.length() + 1)
    let mean = moment1.div(n)
    let variance = moment2.div(n).sub(mean.pow2()).max(0).sqrt().mul(gamma)
    let min_color = mean.sub(variance)
    let max_color = mean.add(variance)
    Some(
      clip_aabb().call([
        mean.clamp(low=min_color, high=max_color),
        history_color,
        min_color,
        max_color,
      ]),
    )
  })
  // Returns the amount of subpixel (expressed within [0, 1]) in the velocity.
  let subpixel_correction = @nodes.fn_(
    fn(inputs, _) {
      let velocity_uv = addon_arg(inputs, 0)
      let texture_size = addon_arg(inputs, 1)
      let velocity_texel = velocity_uv.mul(texture_size)
      let phase = velocity_texel.fract().abs()
      let weight = @nodes.max(phase, phase.one_minus())
      Some(weight.x().mul(weight.y()).one_minus().div(0.75))
    },
    layout=addon_short_layout(
      [("velocityUV", "vec2"), ("textureSize", "ivec2")],
      "float",
    ),
  )
  let history_node = self._history_texture_node
  let resolve = @nodes.fn_(fn(_, _) {
    let uv_node = @nodes.uv()
    let texture_size = self.beauty_node.size() // Assumes all the buffers share the same size.
    let position_texel = uv_node.mul(texture_size)
    // sample the closest and farthest depths in the current buffer
    let current_depth = sample_current_depth().call([
      self.depth_node,
      position_texel,
      self._camera_near_far,
    ])
    let closest_depth = current_depth.get("closestDepth")
    let closest_position_texel = current_depth.get("closestPositionTexel")
    let farthest_depth = current_depth.get("farthestDepth")
    // convert the NDC offset to UV offset
    let offset_uv = self.velocity_node
      .load(closest_position_texel)
      .xy()
      .mul(@nodes.vec2_of([0.5, -0.5]))
    // sample the previous depth
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
    // history is considered valid when the UV is in range and there's no disocclusion except on edges
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
    // sample the current and previous colors
    let current_color = self.beauty_node.sample(uv_node)
    let history_color = history_node.sample(history_uv)
    // increase the weight towards the current frame under motion
    let motion_factor = uv_node
      .sub(history_uv)
      .mul(texture_size)
      .length()
      .div(self.max_velocity_length)
      .saturate()
    let current_weight = @nodes.float(0.05).to_var() // A minimum weight
    if self.use_subpixel_correction {
      // Increase the minimum weight towards the current frame when the velocity is more subpixel.
      current_weight.add_assign(
        subpixel_correction.call([offset_uv, texture_size]).mul(0.25),
      )
    }
    current_weight.assign(
      has_valid_history.select(
        current_weight.add(motion_factor).saturate(),
        else_node=1,
      ),
    )
    // Perform neighborhood clipping/clamping. We use variance clipping here.
    let variance_gamma = @nodes.mix(0.5, 1, motion_factor.one_minus().pow2()) // Reasonable gamma range is [0.75, 2]
    let clipped_history_color = variance_clipping.call([
      position_texel, current_color, history_color, variance_gamma,
    ])
    // flicker reduction based on luminance weighing
    let output = flicker_reduction().call([
      current_color, clipped_history_color, current_weight,
    ])
    Some(output)
  })
  // materials
  let resolve_material = @nodes.NodeMaterial::of(self._resolve_material).unwrap()
  resolve_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  resolve_material.color_node = Some(resolve.call([]))
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for TRAANode with fn dispose(self, node) {
  node.dispose_base()
  self._history_render_target.dispose()
  self._resolve_render_target.dispose()
  self._previous_depth_render_target.dispose()
  self._resolve_material.dispose()
}

///|
/// The constructor body (after `Node::alloc(node_type="vec4")`).
pub fn TRAANode::construct(
  node : @nodes.Node,
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
) -> TRAANode {
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let history_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  history_render_target.texture().name = "TRAANode.history"
  let resolve_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  resolve_render_target.texture().name = "TRAANode.resolve"
  let previous_depth_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    depth_texture=@core.DepthTexture::new(),
    count=0,
  )
  previous_depth_render_target.depth_texture().unwrap().name = "TRAANode.previousDepth"
  let resolve_material = @nodes.NodeMaterial::new()
  resolve_material.name = "TRAA.resolve"
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
  let history_texture_node = @nodes.texture(history_render_target.texture())
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
    use_subpixel_correction: true,
    _jitter_index: 0,
    _inv_size: inv_size,
    _history_render_target: history_render_target,
    _resolve_render_target: resolve_render_target,
    _previous_depth_render_target: previous_depth_render_target,
    _resolve_material: resolve_material,
    _texture_node: texture_node,
    _original_projection_matrix: original_projection_matrix,
    _camera_near_far: camera_near_far,
    _camera_world_matrix: camera_world_matrix,
    _camera_world_matrix_inverse: camera_world_matrix_inverse,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _previous_camera_world_matrix: previous_camera_world_matrix,
    _previous_camera_projection_matrix_inverse: previous_camera_projection_matrix_inverse,
    _history_texture_node: history_texture_node,
    _previous_depth_node: previous_depth_node,
    _velocity_node: None,
  }
}

///|
/// `new TRAANode( beautyNode, depthNode, velocityNode, camera )`.
pub fn TRAANode::new(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_traa_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(
    TRAANode::construct(node, beauty_node, depth_node, velocity_node, camera),
  )
}

///|
pub fn TRAANode::of(node : @nodes.Node) -> TRAANode? {
  addon_class_of(node, "TRAANode")
}

///|
/// `traa( beautyNode, depthNode, velocityNode, camera )`: Temporal Reprojection
/// Anti-Aliasing of `beautyNode`.
pub fn traa(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_traa_node_module.get() |> ignore
  TRAANode::new(
    @nodes.convert_to_texture(beauty_node),
    depth_node,
    velocity_node,
    camera,
  )
}

// Helpers shared by the temporal nodes (TRAANode, TAAUNode, TemporalReprojectNode).

///|
/// `uniform.value` of a `Vector2` uniform (mutated in place, as upstream does).
fn traa_uniform_vector2(node : @nodes.Node) -> @math.Vector2 {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => v
    _ => abort("TRAANode: the uniform is not a Vector2")
  }
}

///|
/// `uniform.value` of a `Vector3` uniform.
fn traa_uniform_vector3(node : @nodes.Node) -> @math.Vector3 {
  match @nodes.InputNode::get_value(node) {
    Vector3(v) => v
    _ => abort("TRAANode: the uniform is not a Vector3")
  }
}

///|
/// `uniform.value` of a `Matrix4` uniform.
fn traa_uniform_matrix4(node : @nodes.Node) -> @math.Matrix4 {
  match @nodes.InputNode::get_value(node) {
    Matrix4(v) => v
    _ => abort("TRAANode: the uniform is not a Matrix4")
  }
}

///|
/// `texture.image.width` (`0` for a missing image, as `null.width` is never read here).
fn traa_image_width(texture : @core.Texture) -> Double {
  match texture.image() {
    NoImage => 0.0
    image => image.width()
  }
}

///|
fn traa_image_height(texture : @core.Texture) -> Double {
  match texture.image() {
    NoImage => 0.0
    image => image.height()
  }
}

///|
/// `texture.image.width = width; texture.image.height = height`.
fn traa_set_image_size(
  texture : @core.Texture,
  width : Double,
  height : Double,
) -> Unit {
  match texture.image() {
    DataImage(image) => {
      image.width = width.to_int()
      image.height = height.to_int()
    }
    DomImage(_) | ImageArray(_) as image => {
      let js = image.to_js()
      js.set("width", @core.JsValue::of(width))
      js.set("height", @core.JsValue::of(height))
    }
    _ => abort("TRAANode: the texture has no image")
  }
}

///|
/// `beautyNode.isRTTNode ? beautyNode.renderTarget : beautyNode.passNode.renderTarget`.
fn traa_beauty_render_target(beauty_node : @nodes.Node) -> @core.RenderTarget {
  match @nodes.RTTNode::of(beauty_node) {
    Some(rtt) => rtt.render_target
    None =>
      match @nodes.PassTextureNode::of(beauty_node) {
        Some(p) =>
          match @nodes.PassNode::of(p.pass_node) {
            Some(pass) => pass.render_target
            None => abort("TRAANode: beautyNode.passNode has no renderTarget")
          }
        None =>
          abort("TRAANode: beautyNode is neither an RTTNode nor a pass texture")
      }
  }
}

///|
/// `if ( builder.renderPipeline && ! builder.context.renderPipelineState.viewOffsetOwner )
/// builder.context.renderPipelineState.viewOffsetOwner = owner`: whether `owner` took it.
fn traa_claim_view_offset(
  builder : @nodes.NodeBuilder,
  owner : @nodes.Node,
) -> Bool {
  match builder.render_pipeline() {
    Undefined | Null | Bool(false) => false
    _ => {
      let state : @nodes.RenderPipelineState = match
        builder.context.get("renderPipelineState") {
        Other(_) as v => v.cast().unwrap()
        _ => abort("TRAANode: the context has no renderPipelineState")
      }
      if state.view_offset_owner is Some(_) {
        false
      } else {
        state.view_offset_owner = Some(@core.JsValue::of(owner))
        true
      }
    }
  }
}
