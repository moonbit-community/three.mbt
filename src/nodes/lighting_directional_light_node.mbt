// nodes/lighting/DirectionalLightNode.js

///|
pub(all) struct DirectionalLightNode {
  analytic : AnalyticLightNode
}

///|
pub impl NodeClass for DirectionalLightNode with fn class_name(_) {
  "DirectionalLightNode"
}

///|
pub impl NodeClass for DirectionalLightNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl AnalyticLightNodeClass for DirectionalLightNode with fn analytic_parent(
  self,
) {
  Some(self.analytic)
}

///|
pub impl AnalyticLightNodeClass for DirectionalLightNode with fn setup_direct(
  self,
  _,
  _,
) {
  let light_color = self.analytic.color_node.unwrap()
  let light_direction = light_target_direction(self.analytic.light.unwrap())
  Some(LightData::direct(light_direction, light_color))
}

///|
/// `new DirectionalLightNode( light = null )`.
pub fn DirectionalLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let payload = DirectionalLightNode::{
    analytic: AnalyticLightNode::construct(node, light),
  }
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn DirectionalLightNode::of(node : Node) -> DirectionalLightNode? {
  match node.class_payload("DirectionalLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `DirectionalLight.registerNode( DirectionalLightNode )` stores.
pub fn DirectionalLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { DirectionalLightNode::new(light~) },
  })
}
