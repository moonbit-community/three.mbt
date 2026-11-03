// nodes/lighting/AmbientLightNode.js

///|
pub(all) struct AmbientLightNode {
  analytic : AnalyticLightNode
}

///|
pub impl NodeClass for AmbientLightNode with fn class_name(_) {
  "AmbientLightNode"
}

///|
pub impl NodeClass for AmbientLightNode with fn parent(self) {
  Some(self.analytic)
}

///|
pub impl NodeClass for AmbientLightNode with fn setup(self, _, builder) {
  builder.context
  .get_node("irradiance")
  .unwrap()
  .add_assign(self.analytic.color_node.unwrap())
  None
}

///|
pub impl AnalyticLightNodeClass for AmbientLightNode with fn analytic_parent(
  self,
) {
  Some(self.analytic)
}

///|
/// `new AmbientLightNode( light = null )`.
pub fn AmbientLightNode::new(light? : @core.Object3D) -> Node {
  let node = AnalyticLightNode::alloc()
  let payload = AmbientLightNode::{
    analytic: AnalyticLightNode::construct(node, light),
  }
  payload.analytic.class_ = payload
  node.set_class(payload)
}

///|
pub fn AmbientLightNode::of(node : Node) -> AmbientLightNode? {
  match node.class_payload("AmbientLightNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The value `AmbientLight.registerNode( AmbientLightNode )` stores.
pub fn AmbientLightNode::node_class() -> @core.JsValue {
  @core.JsValue::of(LightNodeClass::{
    create: fn(light) { AmbientLightNode::new(light~) },
  })
}
