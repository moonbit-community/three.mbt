// nodes/accessors/ReferenceElementNode.js: an element of a reference node's array.

///|
pub(all) struct ReferenceElementNode {
  array_element : ArrayElementNode
  reference_node : Node
}

///|
pub impl NodeClass for ReferenceElementNode with fn class_name(_) {
  "ReferenceElementNode"
}

///|
pub impl NodeClass for ReferenceElementNode with fn parent(self) {
  Some(self.array_element)
}

///|
pub impl NodeClass for ReferenceElementNode with fn has_flag(self, flag) {
  flag == "isReferenceElementNode" ||
  NodeClass::has_flag(self.array_element, flag)
}

///|
pub impl NodeClass for ReferenceElementNode with fn children(self, node, out) {
  NodeClass::children(self.array_element, node, out)
  push_child(out, "referenceNode", Some(self.reference_node))
}

///|
pub impl NodeClass for ReferenceElementNode with fn generate_node_type(
  self,
  _,
  _,
  _,
) {
  match ReferenceNode::of(self.reference_node) {
    Some(r) => r.uniform_type
    None =>
      match ReferenceBaseNode::of(self.reference_node) {
        Some(r) => r.uniform_type
        None => None
      }
  }
}

///|
pub impl NodeClass for ReferenceElementNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let snippet = NodeClass::generate(self.array_element, node, builder, output).unwrap_or(
    "",
  )
  let array_type = self.reference_node.get_node_type(builder)
  let element_type = node.get_node_type(builder)
  Some(builder.format(snippet, array_type, element_type))
}

///|
/// `new ReferenceElementNode( referenceNode, indexNode )`.
pub fn ReferenceElementNode::new(
  reference_node : Node,
  index_node : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(ReferenceElementNode::{
    array_element: ArrayElementNode::construct(node, reference_node, index_node),
    reference_node,
  })
}

///|
pub fn ReferenceElementNode::of(node : Node) -> ReferenceElementNode? {
  match node.class_payload("ReferenceElementNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
