// nodes/lighting/HemisphereLightNode.js

///|
pub(all) struct HemisphereLightNode {
  analytic : AnalyticLightNode
  light_position_node : Node
  light_direction_node : Node
  ground_color_node : Node
  /// The value of `groundColorNode`.
  ground_color : @math.Color
}

///|
pub impl NodeClass for HemisphereLightNode with fn class_name(_) {
  "HemisphereLightNode"
}

///|
pub impl NodeClass for HemisphereLightNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl NodeClass for HemisphereLightNode with fn children(self, node, out) {
  NodeClass::children(self.analytic, node, out)
  push_child(out, "lightPositionNode", Some(self.light_position_node))
  push_child(out, "lightDirectionNode", Some(self.light_direction_node))
  push_child(out, "groundColorNode", Some(self.ground_color_node))
}

///|
pub impl NodeClass for HemisphereLightNode with fn update(self, node, frame) {
  let light = self.analytic.light.unwrap()
  NodeClass::update(self.analytic, node, frame) |> ignore
  // upstream also sets `lightPositionNode.object3d = light`, a property its uniform
  // node does not read.
  guard light.as_light().kind is HemisphereLight(hemi) else { return None }
  self.ground_color
  .copy(hemi.ground_color)
  .multiply_scalar(light.as_light().intensity)
  |> ignore
  None
}

///|
pub impl NodeClass for HemisphereLightNode with fn setup(self, _, builder) {
  let color_node = self.analytic.color_node.unwrap()
  let dot_nl = normal_world.dot(self.light_direction_node)
  let hemi_diffuse_weight = dot_nl.mul(0.5).add(0.5)
  let irradiance = mix(self.ground_color_node, color_node, hemi_diffuse_weight)
  builder.context.get_node("irradiance").unwrap().add_assign(irradiance)
  None
}

///|
pub impl AnalyticLightNodeClass for HemisphereLightNode with fn analytic_parent(
  self,
) {
  Some(self.analytic)
}

///|
/// `new HemisphereLightNode( light = null )`.
pub fn HemisphereLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let analytic = AnalyticLightNode::construct(node, light)
  let light_position_node = light_position(light.unwrap())
  let light_direction_node = light_position_node.normalize()
  let ground_color = @math.Color::new(1.0, 1.0, 1.0)
  let payload = HemisphereLightNode::{
    analytic,
    light_position_node,
    light_direction_node,
    ground_color_node: uniform(ground_color).set_group(render_group),
    ground_color,
  }
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn HemisphereLightNode::of(node : Node) -> HemisphereLightNode? {
  match node.class_payload("HemisphereLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `HemisphereLight.registerNode( HemisphereLightNode )` stores.
pub fn HemisphereLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { HemisphereLightNode::new(light~) },
  })
}
