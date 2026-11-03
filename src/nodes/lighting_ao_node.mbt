// nodes/lighting/AONode.js

///|
pub(all) struct AONode {
  lighting : LightingNode
  mut ao_node : Node?
}

///|
pub impl NodeClass for AONode with fn class_name(_) {
  "AONode"
}

///|
pub impl NodeClass for AONode with fn parent(self) {
  Some(self.lighting)
}

///|
pub impl NodeClass for AONode with fn children(self, node, out) {
  NodeClass::children(self.lighting, node, out)
  push_child(out, "aoNode", self.ao_node)
}

///|
pub impl NodeClass for AONode with fn setup(self, _, builder) {
  builder.context
  .get_node("ambientOcclusion")
  .unwrap()
  .mul_assign(physical_optional(self.ao_node))
  None
}

///|
/// `new AONode( aoNode = null )`.
pub fn AONode::new(ao_node? : Node) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(AONode::{ lighting: LightingNode::construct(node), ao_node, })
}

///|
pub fn AONode::of(node : Node) -> AONode? {
  match node.class_payload("AONode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
