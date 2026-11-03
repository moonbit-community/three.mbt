// nodes/utils/ArrayElementNode.js. The root of the element nodes of StorageBufferNode,
// UniformArrayNode, ReferenceNode and WorkgroupInfoNode; they override `generate` and
// friends through `NodeClass` and reach `super` through the `array_element` payload.

///|
pub(all) struct ArrayElementNode {
  /// The array-like node, `this.node`.
  mut node : Node
  mut index_node : Node
}

///|
pub impl NodeClass for ArrayElementNode with fn class_name(_) {
  "ArrayElementNode"
}

///|
pub impl NodeClass for ArrayElementNode with fn has_flag(_, flag) {
  flag == "isArrayElementNode"
}

///|
pub impl NodeClass for ArrayElementNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
  push_child(out, "indexNode", Some(self.index_node))
}

///|
pub impl NodeClass for ArrayElementNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for ArrayElementNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ArrayElementNode with fn get_scope(self, _) {
  self.node.get_scope()
}

///|
pub impl NodeClass for ArrayElementNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.node.get_element_type(builder)
}

///|
pub impl NodeClass for ArrayElementNode with fn get_member_type(
  self,
  _,
  builder,
  name,
) {
  self.node.get_member_type(builder, name)
}

///|
pub impl NodeClass for ArrayElementNode with fn generate(self, _, builder, _) {
  let index_type = self.index_node.get_node_type(builder)
  let node_snippet = self.node.build(builder)
  let index_output = if !builder.is_vector(index_type) &&
    builder.is_integer(index_type) {
    index_type
  } else {
    Some("uint")
  }
  let index_snippet = self.index_node.build(builder, output?=index_output)
  Some("\{node_snippet}[ \{index_snippet} ]")
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn ArrayElementNode::construct(
  _node : Node,
  node : Node,
  index_node : Node,
) -> ArrayElementNode {
  { node, index_node, }
}

///|
/// `new ArrayElementNode( node, indexNode )`.
pub fn ArrayElementNode::new(node : Node, index_node : Node) -> Node {
  let n = Node::alloc()
  n.set_class(ArrayElementNode::construct(n, node, index_node))
}

///|
pub fn ArrayElementNode::of(node : Node) -> ArrayElementNode? {
  match node.class_payload("ArrayElementNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
