// examples/jsm/tsl/lighting/data/AmbientLightDataNode.js

///|
/// Batched data node for ambient lights in dynamic lighting mode.
pub(all) struct AmbientLightDataNode {
  _color : @math.Color
  mut _lights : Array[@core.Object3D]
  mut color_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for AmbientLightDataNode with fn class_name(_) {
  "AmbientLightDataNode"
}

///|
pub impl @nodes.NodeClass for AmbientLightDataNode with fn children(
  self,
  _,
  out,
) {
  @nodes.push_child(out, "colorNode", Some(self.color_node))
}

///|
pub impl @nodes.NodeClass for AmbientLightDataNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl @nodes.NodeClass for AmbientLightDataNode with fn update(self, _, _) {
  self._color.set_scalar(0.0) |> ignore
  for i in 0..<self._lights.length() {
    let light = self._lights[i].as_light()
    self._color.r += light.color.r * light.intensity
    self._color.g += light.color.g * light.intensity
    self._color.b += light.color.b * light.intensity
  }
  None
}

///|
pub impl @nodes.NodeClass for AmbientLightDataNode with fn setup(
  self,
  _,
  builder,
) {
  builder.context.get_node("irradiance").unwrap().add_assign(self.color_node)
  None
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn AmbientLightDataNode::construct(
  node : @nodes.Node,
) -> AmbientLightDataNode {
  let _color = @math.Color::new(1.0, 1.0, 1.0)
  let color_node = @nodes.uniform(_color).set_group(@nodes.render_group)
  node.update_type = @nodes.NodeUpdateType::render()
  { _color, _lights: [], color_node, }
}

///|
/// `new AmbientLightDataNode()`.
pub fn AmbientLightDataNode::new() -> @nodes.Node {
  let node = @nodes.Node::alloc()
  node.set_class(AmbientLightDataNode::construct(node))
}

///|
pub fn AmbientLightDataNode::of(node : @nodes.Node) -> AmbientLightDataNode? {
  addon_class_of(node, "AmbientLightDataNode")
}

///|
/// `setLights( lights )`.
pub fn AmbientLightDataNode::set_lights(
  node : @nodes.Node,
  lights : Array[@core.Object3D],
) -> @nodes.Node {
  AmbientLightDataNode::of(node).unwrap()._lights = lights
  node
}
