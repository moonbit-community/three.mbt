// examples/jsm/tsl/display/StereoCompositePassNode.js

///|
priv struct StereoCompositePassNodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let _stereo_composite_pass_node_size : @math.Vector2 = @math.Vector2::new(
  0.0, 0.0,
)

///|
let _stereo_composite_pass_node_renderer_state : Ref[@nodes.RendererState?] = Ref(
  None,
)

///|
let display_stereo_composite_pass_node_module : AddonModule[
  StereoCompositePassNodeModule,
] = AddonModule::new(fn() { { _quad_mesh: @nodes.QuadMesh::new(), } })

///|
/// Evaluates StereoCompositePassNode.js (its `_quadMesh`), as `import` does.
pub fn load_display_stereo_composite_pass_node() -> Unit {
  display_stereo_composite_pass_node_module.get() |> ignore
}

///|
/// The virtual method StereoCompositePassNode introduces (subclasses override it).
pub(open) trait StereoCompositePassNodeClass {
  /// `updateStereoCamera( coordinateSystem )`.
  fn update_stereo_camera(Self, @nodes.Node, Int32) -> Unit
}

///|
/// The base of the stereo composite passes (anaglyph, parallax barrier): renders the scene
/// for the left and right eye, then composites both views with `_material`.
pub(all) struct StereoCompositePassNode {
  pass : @nodes.PassNode
  stereo : @core.StereoCamera
  _render_target_l : @core.RenderTarget
  _render_target_r : @core.RenderTarget
  _map_left : @nodes.Node
  _map_right : @nodes.Node
  mut _material : @core.Material?
  /// The most derived payload of the family.
  mut stereo_class : &StereoCompositePassNodeClass
}

///|
pub impl @nodes.NodeClass for StereoCompositePassNode with fn class_name(_) {
  "StereoCompositePassNode"
}

///|
pub impl @nodes.NodeClass for StereoCompositePassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl @nodes.NodeClass for StereoCompositePassNode with fn has_flag(
  self,
  flag,
) {
  flag == "isStereoCompositePassNode" || self.pass.has_flag(flag)
}

///|
pub impl @nodes.NodeClass for StereoCompositePassNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let scene = self.pass.scene
  let stereo = self.stereo
  let render_target = self.pass.render_target
  let quad_mesh = display_stereo_composite_pass_node_module.get()._quad_mesh
  _stereo_composite_pass_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(
      renderer,
      state?=_stereo_composite_pass_node_renderer_state.val,
    ),
  )
  //
  self.stereo_class.update_stereo_camera(node, renderer.coordinate_system())
  let size = renderer.get_drawing_buffer_size(_stereo_composite_pass_node_size)
  node.set_size(size.x, size.y)
  // left
  renderer.set_render_target(Some(self._render_target_l))
  renderer.render(scene, stereo.camera_l)
  // right
  renderer.set_render_target(Some(self._render_target_r))
  renderer.render(scene, stereo.camera_r)
  // composite
  renderer.set_render_target(Some(render_target))
  quad_mesh.set_material(self._material.unwrap())
  quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(
    renderer,
    _stereo_composite_pass_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for StereoCompositePassNode with fn dispose(
  self,
  node,
) {
  self.pass.dispose(node)
  self._render_target_l.dispose()
  self._render_target_r.dispose()
  if self._material is Some(material) {
    material.dispose()
  }
}

///|
pub impl @nodes.PassNodeClass for StereoCompositePassNode with fn set_size(
  self,
  node,
  width,
  height,
) {
  @nodes.PassNode::set_size_base(node, width, height)
  self._render_target_l.set_size(
    self.pass.render_target.width,
    self.pass.render_target.height,
  )
  self._render_target_r.set_size(
    self.pass.render_target.width,
    self.pass.render_target.height,
  )
}

///|
pub impl StereoCompositePassNodeClass for StereoCompositePassNode with fn update_stereo_camera(
  self,
  _,
  coordinate_system,
) {
  self.update_stereo_camera_base(coordinate_system)
}

///|
/// `StereoCompositePassNode.prototype.updateStereoCamera` (`super.updateStereoCamera`).
pub fn StereoCompositePassNode::update_stereo_camera_base(
  self : StereoCompositePassNode,
  coordinate_system : Int32,
) -> Unit {
  self.stereo.camera_l.as_camera().coordinate_system = coordinate_system
  self.stereo.camera_r.as_camera().coordinate_system = coordinate_system
  self.stereo.update(self.pass.camera)
}

///|
/// The constructor body (after `Node::alloc(node_type="vec4")`).
pub fn StereoCompositePassNode::construct(
  node : @nodes.Node,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> StereoCompositePassNode {
  display_stereo_composite_pass_node_module.get() |> ignore
  let pass = @nodes.PassNode::construct(
    node,
    @nodes.PassNode::color(),
    scene,
    camera,
    @nodes.PassNodeOptions::default(),
  )
  let stereo = @core.StereoCamera::new()
  let render_target_l = @core.RenderTarget::new(
    width=1,
    height=1,
    min_filter=@core.LinearFilter,
    mag_filter=@core.NearestFilter,
    type_=@core.HalfFloatType,
  )
  let render_target_r = @core.RenderTarget::new(
    width=1,
    height=1,
    min_filter=@core.LinearFilter,
    mag_filter=@core.NearestFilter,
    type_=@core.HalfFloatType,
  )
  let map_left = @nodes.texture(render_target_l.texture())
  let map_right = @nodes.texture(render_target_r.texture())
  let p = StereoCompositePassNode::{
    pass,
    stereo,
    _render_target_l: render_target_l,
    _render_target_r: render_target_r,
    _map_left: map_left,
    _map_right: map_right,
    _material: None,
    stereo_class: StereoCompositePassNodeUnset::{ },
  }
  p.stereo_class = p
  p.pass.pass_class = p
  p
}

///|
priv struct StereoCompositePassNodeUnset {}

///|
impl StereoCompositePassNodeClass for StereoCompositePassNodeUnset with fn update_stereo_camera(
  _,
  _,
  _,
) {
  ()
}

///|
/// `new StereoCompositePassNode( scene, camera )`.
pub fn StereoCompositePassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  display_stereo_composite_pass_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(StereoCompositePassNode::construct(node, scene, camera))
}

///|
pub fn StereoCompositePassNode::of(
  node : @nodes.Node,
) -> StereoCompositePassNode? {
  addon_class_of(node, "StereoCompositePassNode")
}
