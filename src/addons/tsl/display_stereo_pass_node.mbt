// examples/jsm/tsl/display/StereoPassNode.js

///|
let _stereo_pass_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
/// `let _rendererState`.
let _stereo_pass_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
/// A stereo pass: renders the scene side by side for the left and right eye.
pub(all) struct StereoPassNode {
  pass : @nodes.PassNode
  stereo : @core.StereoCamera
}

///|
pub impl @nodes.NodeClass for StereoPassNode with fn class_name(_) {
  "StereoPassNode"
}

///|
pub impl @nodes.NodeClass for StereoPassNode with fn parent(self) {
  Some(self.pass)
}

///|
pub impl @nodes.NodeClass for StereoPassNode with fn has_flag(self, flag) {
  flag == "isStereoPassNode" || self.pass.has_flag(flag)
}

///|
pub impl @nodes.PassNodeClass for StereoPassNode with fn set_size(
  _,
  node,
  width,
  height,
) {
  @nodes.PassNode::set_size_base(node, width, height)
}

///|
pub impl @nodes.NodeClass for StereoPassNode with fn update_before(
  self,
  node,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let scene = self.pass.scene
  let camera = self.pass.camera
  let stereo = self.stereo
  let render_target = self.pass.render_target
  _stereo_pass_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(
      renderer,
      state?=_stereo_pass_node_renderer_state.val,
    ),
  )
  //
  stereo.camera_l.as_camera().coordinate_system = renderer.coordinate_system()
  stereo.camera_r.as_camera().coordinate_system = renderer.coordinate_system()
  stereo.update(camera)
  let size = renderer.get_drawing_buffer_size(_stereo_pass_node_size)
  node.set_size(size.x, size.y)
  renderer.auto_clear = false
  @nodes.InputNode::set_value(
    self.pass._camera_near,
    Number(@nodes.camera_near_of(camera)),
  )
  @nodes.InputNode::set_value(
    self.pass._camera_far,
    Number(@nodes.camera_far_of(camera)),
  )
  for name in self.pass._previous_textures.keys().collect() {
    node.toggle_texture(name)
  }
  renderer.set_render_target(Some(render_target))
  renderer.set_mrt(self.pass._mrt) |> ignore
  renderer.clear()
  render_target.scissor_test = true
  let width = render_target.width.to_double()
  let height = render_target.height.to_double()
  render_target.scissor.set(0.0, 0.0, width / 2.0, height) |> ignore
  render_target.viewport.set(0.0, 0.0, width / 2.0, height) |> ignore
  renderer.render(scene, stereo.camera_l)
  render_target.scissor.set(width / 2.0, 0.0, width / 2.0, height) |> ignore
  render_target.viewport.set(width / 2.0, 0.0, width / 2.0, height) |> ignore
  renderer.render(scene, stereo.camera_r)
  render_target.scissor_test = false
  // restore
  @nodes.restore_renderer_state(
    renderer,
    _stereo_pass_node_renderer_state.val.unwrap(),
  )
  None
}

///|
/// `new StereoPassNode( scene, camera )`.
pub fn StereoPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let pass = @nodes.PassNode::construct(
    node,
    @nodes.PassNode::color(),
    scene,
    camera,
    @nodes.PassNodeOptions::default(),
  )
  let stereo = @core.StereoCamera::new()
  stereo.aspect = 0.5
  let p = StereoPassNode::{ pass, stereo, }
  pass.pass_class = p
  node.set_class(p)
}

///|
pub fn StereoPassNode::of(node : @nodes.Node) -> StereoPassNode? {
  addon_class_of(node, "StereoPassNode")
}

///|
/// `stereoPass( scene, camera )`.
pub fn stereo_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  StereoPassNode::new(scene, camera)
}
