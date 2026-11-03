// nodes/lighting/IrradianceNode.js

///|
pub(all) struct IrradianceNode {
  lighting : LightingNode
  mut node : Node
}

///|
pub impl NodeClass for IrradianceNode with fn class_name(_) {
  "IrradianceNode"
}

///|
pub impl NodeClass for IrradianceNode with fn parent(self) {
  Some(self.lighting)
}

///|
pub impl NodeClass for IrradianceNode with fn children(self, node, out) {
  NodeClass::children(self.lighting, node, out)
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for IrradianceNode with fn setup(self, _, builder) {
  builder.context.get_node("irradiance").unwrap().add_assign(self.node)
  None
}

///|
/// `new IrradianceNode( node )`.
pub fn IrradianceNode::new(input : Node) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(IrradianceNode::{
    lighting: LightingNode::construct(node),
    node: input,
  })
}

///|
pub fn IrradianceNode::of(node : Node) -> IrradianceNode? {
  match node.class_payload("IrradianceNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
