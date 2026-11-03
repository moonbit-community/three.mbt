// nodes/lighting/PointLightNode.js

///|
/// `directPointLight( { color, lightVector, cutoffDistance, decayExponent } )`.
pub fn direct_point_light(
  color~ : Node,
  light_vector~ : Node,
  cutoff_distance~ : Node,
  decay_exponent~ : Node,
) -> LightData {
  let light_direction = light_vector.normalize()
  let light_distance = light_vector.length()
  let attenuation = get_distance_attenuation.call_named({
    "lightDistance": light_distance,
    "cutoffDistance": cutoff_distance,
    "decayExponent": decay_exponent,
  })
  let light_color = color.mul(attenuation)
  LightData::direct(light_direction, light_color)
}

///|
pub(all) struct PointLightNode {
  analytic : AnalyticLightNode
  cutoff_distance_node : Node
  decay_exponent_node : Node
}

///|
pub impl NodeClass for PointLightNode with fn class_name(_) {
  "PointLightNode"
}

///|
pub impl NodeClass for PointLightNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl NodeClass for PointLightNode with fn children(self, node, out) {
  NodeClass::children(self.analytic, node, out)
  push_child(out, "cutoffDistanceNode", Some(self.cutoff_distance_node))
  push_child(out, "decayExponentNode", Some(self.decay_exponent_node))
}

///|
pub impl NodeClass for PointLightNode with fn update(self, node, frame) {
  let light = self.analytic.light.unwrap()
  NodeClass::update(self.analytic, node, frame) |> ignore
  guard light.as_light().kind is PointLight(point) else { return None }
  InputNode::set_value(self.cutoff_distance_node, Number(point.distance))
  InputNode::set_value(self.decay_exponent_node, Number(point.decay))
  None
}

///|
pub impl AnalyticLightNodeClass for PointLightNode with fn analytic_parent(self) {
  Some(self.analytic)
}

///|
pub impl AnalyticLightNodeClass for PointLightNode with fn setup_shadow_node(
  self,
  _,
) {
  point_shadow(self.analytic.light.unwrap())
}

///|
pub impl AnalyticLightNodeClass for PointLightNode with fn setup_direct(
  self,
  node,
  builder,
) {
  Some(
    direct_point_light(
      color=self.analytic.color_node.unwrap(),
      light_vector=AnalyticLightNode::get_light_vector(node, builder),
      cutoff_distance=self.cutoff_distance_node,
      decay_exponent=self.decay_exponent_node,
    ),
  )
}

///|
/// `new PointLightNode( light = null )`.
pub fn PointLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let analytic = AnalyticLightNode::construct(node, light)
  let payload = PointLightNode::{
    analytic,
    cutoff_distance_node: uniform(0).set_group(render_group),
    decay_exponent_node: uniform(2).set_group(render_group),
  }
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn PointLightNode::of(node : Node) -> PointLightNode? {
  match node.class_payload("PointLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `PointLight.registerNode( PointLightNode )` stores.
pub fn PointLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { PointLightNode::new(light~) },
  })
}
