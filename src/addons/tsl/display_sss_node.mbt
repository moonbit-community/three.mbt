// examples/jsm/tsl/display/SSSNode.js

///|
/// The module-level state of SSSNode.js (`_quadMesh`, `_size`, `_rendererState`).
priv struct SSSNodeModule {
  quad_mesh : @nodes.QuadMesh
  size : @math.Vector2
  mut renderer_state : @nodes.RendererState?
}

///|
let _sss_node_module : AddonModule[SSSNodeModule] = AddonModule::new(fn() {
  {
    quad_mesh: @nodes.QuadMesh::new(),
    size: @math.Vector2::new(0.0, 0.0),
    renderer_state: None,
  }
})

///|
/// Evaluates SSSNode.js's module-level statements (as its ES `import` does).
pub fn load_display_sss_node() -> Unit {
  _sss_node_module.get() |> ignore
}

///|
let _sss_node_spatial_offsets : Array[Double] = [0, 0.5, 0.25, 0.75]

///|
extern "js" fn sss_node_math_round(x : Double) -> Double = "Math.round"

///|
/// Post processing node for screen space shadows (SSS): ray marches the depth buffer
/// towards the main light into a single-channel render target.
pub(all) struct SSSNode {
  mut depth_node : @nodes.Node
  max_distance : @nodes.Node
  thickness : @nodes.Node
  shadow_intensity : @nodes.Node
  quality : @nodes.Node
  mut resolution_scale : Double
  mut use_temporal_filtering : Bool
  _camera_view_matrix : @nodes.Node
  _camera_projection_matrix : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _resolution : @nodes.Node
  _temporal_offset : @nodes.Node
  /// `_frameId`: the uniform node, which `updateBefore` replaces by the frame number, as
  /// upstream does.
  mut _frame_id : @nodes.TslValue
  _main_light : @core.Object3D
  _camera : @core.Object3D
  _sss_render_target : @core.RenderTarget
  _material : @core.Material
  mut _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for SSSNode with fn class_name(_) {
  "SSSNode"
}

///|
pub impl @nodes.NodeClass for SSSNode with fn children(self, _, out) {
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "maxDistance", Some(self.max_distance))
  @nodes.push_child(out, "thickness", Some(self.thickness))
  @nodes.push_child(out, "shadowIntensity", Some(self.shadow_intensity))
  @nodes.push_child(out, "quality", Some(self.quality))
}

///|
pub impl @nodes.NodeClass for SSSNode with fn set_size(self, _, width, height) {
  self.set_size(width, height)
  true
}

///|
/// `getTextureNode()`: the texture node holding the shadows.
pub fn SSSNode::get_texture_node(self : SSSNode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`.
pub fn SSSNode::set_size(
  self : SSSNode,
  width : Double,
  height : Double,
) -> Unit {
  let width = sss_node_math_round(self.resolution_scale * width)
  let height = sss_node_math_round(self.resolution_scale * height)
  a4_uniform_vector2(self._resolution).set(width, height) |> ignore
  self._sss_render_target.set_size(width.to_int(), height.to_int())
}

///|
pub impl @nodes.NodeClass for SSSNode with fn update_before(self, _, frame) {
  let m = _sss_node_module.get()
  let renderer = frame.renderer.unwrap()
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  //
  let size = renderer.get_drawing_buffer_size(m.size)
  self.set_size(size.x, size.y)
  // update temporal uniforms
  if self.use_temporal_filtering == true {
    let frame_id = frame.frame_id
    a4_set_uniform_number(
      self._temporal_offset,
      _sss_node_spatial_offsets[frame_id % 4],
    )
    self._frame_id = Number(frame.frame_id.to_double())
  } else {
    a4_set_uniform_number(self._temporal_offset, 0)
    self._frame_id = Number(0)
  }
  //
  m.quad_mesh.set_material(self._material)
  m.quad_mesh.object.name = "SSS"
  // clear
  renderer.set_clear_color_hex(0xffffff, alpha=1)
  // sss
  renderer.set_render_target(Some(self._sss_render_target))
  m.quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for SSSNode with fn setup(self, _, builder) {
  let uv_node = @nodes.uv()
  let get_view_z = @nodes.fn_(fn(inputs, _) {
    let depth = inputs.get(0).unwrap()
    let view_z_node = if self._camera.is_perspective_camera() {
      @nodes.perspective_depth_to_view_z.call([
        depth,
        self._camera_near,
        self._camera_far,
      ])
    } else {
      @nodes.orthographic_depth_to_view_z.call([
        depth,
        self._camera_near,
        self._camera_far,
      ])
    }
    Some(view_z_node)
  })
  let sample_depth = fn(uv : @nodes.Node) {
    @nodes.projection_depth.call([
      self.depth_node.sample(uv).r(),
      self._camera_near,
      self._camera_far,
    ])
  }
  let sss = @nodes.fn_(fn(_, _) {
    let depth = sample_depth(uv_node).to_var()
    @nodes.is_background_depth.call([depth]).discard()
    // compute ray position and direction (in view-space)
    let ray_start_position = @nodes.get_view_position
      .call([uv_node, depth, self._camera_projection_matrix_inverse])
      .to_var(name="rayStartPosition")
    let ray_direction = self._camera_view_matrix
      .transform_direction(
        @nodes.light_position(self._main_light).sub(
          @nodes.light_target_position(self._main_light),
        ),
      )
      .to_const(name="rayDirection")
    let ray_end_position = ray_start_position
      .add(ray_direction.mul(self.max_distance))
      .to_const(name="rayEndPosition")
    // d0 and d1 are the start and maximum points of the ray in screen space
    let d0 = @nodes.screen_coordinate.xy().to_var()
    let d1 = @nodes.get_screen_position
      .call([ray_end_position, self._camera_projection_matrix])
      .mul(self._resolution)
      .to_var()
    // below variables are used to control the raymarching process
    // total length of the ray
    let total_len = d1.sub(d0).length().to_var()
    // offset in x and y direction
    let x_len = d1.x().sub(d0.x()).to_var()
    let y_len = d1.y().sub(d0.y()).to_var()
    // determine the larger delta
    // The larger difference will help to determine how much to travel in the X and Y direction each iteration and
    // how many iterations are needed to travel the entire ray
    let total_step = @nodes.int(
      @nodes.max(@nodes.abs(x_len), @nodes.abs(y_len)).mul(self.quality.clamp()),
    ).to_const()
    // step sizes in the x and y directions
    let x_span = x_len.div(total_step).to_var()
    let y_span = y_len.div(total_step).to_var()
    // compute noise based ray offset
    let noise = @nodes.interleaved_gradient_noise.call([
      @nodes.screen_coordinate,
    ])
    let offset = @nodes.fract(noise.add(self._temporal_offset))
      .add(@nodes.rand.call([uv_node.add(self._frame_id)]))
      .to_const(name="offset")
    let occlusion = @nodes.float(0).to_var()
    @nodes.loop_([total_step], fn(inputs) {
      let i = inputs.named("i").unwrap()
      // advance on the ray by computing a new position in screen coordinates
      let xy = @nodes.vec2_of([
        d0.x().add(x_span.mul(@nodes.float(i).add(offset))),
        d0.y().add(y_span.mul(@nodes.float(i).add(offset))),
      ]).to_var()
      // stop processing if the new position lies outside of the screen
      @nodes.if_(
        xy
        .x()
        .less_than(0)
        .or(xy.x().greater_than(self._resolution.x()))
        .or(xy.y().less_than(0))
        .or(xy.y().greater_than(self._resolution.y())),
        fn() { @nodes.break_() },
      )
      |> ignore
      // compute new uv, depth and viewZ for the next fragment
      let uv_node = xy.div(self._resolution)
      let fragment_depth = sample_depth(uv_node).to_const()
      let fragment_view_z = get_view_z
        .call([fragment_depth])
        .to_const(name="fragmentViewZ")
      let s = xy.sub(d0).length().div(total_len).to_var()
      let ray_position = @nodes.mix(ray_start_position, ray_end_position, s)
      let depth_delta = ray_position.z().sub(fragment_view_z).negate() // Port note: viewZ values are negative in three
      // check if the camera can't "see" the ray (ray depth must be larger than the camera depth, so positive depth_delta)
      @nodes.if_(
        depth_delta.greater_than(0).and_(depth_delta.less_than(self.thickness)),
        fn() {
          // mark as occluded
          occlusion.assign(self.shadow_intensity)
          @nodes.break_()
        },
      )
      |> ignore
    })
    Some(occlusion.one_minus())
  })
  let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(sss.call([]))
  self._material.set_needs_update(true)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for SSSNode with fn dispose(self, node) {
  node.dispose_base()
  self._sss_render_target.dispose()
  self._material.dispose()
}

///|
/// `new SSSNode( depthNode, camera, mainLight )`.
pub fn SSSNode::new(
  depth_node : @nodes.Node,
  camera : @core.Object3D,
  main_light : @core.Object3D,
) -> @nodes.Node {
  _sss_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="float")
  let max_distance = @nodes.uniform(0.1, type_="float")
  let thickness = @nodes.uniform(0.01, type_="float")
  let shadow_intensity = @nodes.uniform(1.0, type_="float")
  let quality = @nodes.uniform(0.5)
  node.update_before_type = @nodes.NodeUpdateType::frame()
  // private uniforms
  let camera_view_matrix = @nodes.uniform(camera.matrix_world_inverse())
  let camera_projection_matrix = @nodes.uniform(camera.projection_matrix())
  let camera_projection_matrix_inverse = @nodes.uniform(
    camera.projection_matrix_inverse(),
  )
  let camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let temporal_offset = @nodes.uniform(0)
  let frame_id = @nodes.uniform(0)
  let sss_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    format=@core.RedFormat,
    type_=@core.UnsignedByteType,
  )
  sss_render_target.texture().name = "SSS"
  let material = @nodes.NodeMaterial::new()
  material.name = "SSS"
  let payload = SSSNode::{
    depth_node,
    max_distance,
    thickness,
    shadow_intensity,
    quality,
    resolution_scale: 1.0,
    use_temporal_filtering: false,
    _camera_view_matrix: camera_view_matrix,
    _camera_projection_matrix: camera_projection_matrix,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _camera_near: camera_near,
    _camera_far: camera_far,
    _resolution: resolution,
    _temporal_offset: temporal_offset,
    _frame_id: Node(frame_id),
    _main_light: main_light,
    _camera: camera,
    _sss_render_target: sss_render_target,
    _material: material,
    _texture_node: node,
  }
  payload._texture_node = @nodes.pass_texture(node, sss_render_target.texture())
  node.set_class(payload)
}

///|
pub fn SSSNode::of(node : @nodes.Node) -> SSSNode? {
  addon_class_of(node, "SSSNode")
}

///|
/// `sss( depthNode, camera, mainLight )`.
pub fn sss(
  depth_node : @nodes.Node,
  camera : @core.Object3D,
  main_light : @core.Object3D,
) -> @nodes.Node {
  SSSNode::new(depth_node, camera, main_light)
}
