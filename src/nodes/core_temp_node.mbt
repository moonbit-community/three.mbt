// nodes/core/TempNode.js (deprecated upstream: extend Node instead).

///|
pub(all) struct TempNode {}

///|
pub impl NodeClass for TempNode with fn class_name(_) {
  "TempNode"
}

///|
pub impl NodeClass for TempNode with fn has_flag(_, flag) {
  flag == "isTempNode"
}

///|
pub impl NodeClass for TempNode with fn is_cacheable(_, node, builder) {
  TempNode::has_dependencies(node, builder)
}

///|
pub fn TempNode::construct(_node : Node) -> TempNode {
  @core.warn("TempNode: This module has been deprecated. Extend Node instead.")
  TempNode::{ }
}

///|
/// `new TempNode( nodeType = null )`.
pub fn TempNode::new(node_type? : String) -> Node {
  let node = Node::alloc(node_type?)
  node.set_class(TempNode::construct(node))
}

///|
pub fn TempNode::of(node : Node) -> TempNode? {
  match node.class_payload("TempNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `hasDependencies( builder )`: whether the node is used more than once.
pub fn TempNode::has_dependencies(node : Node, builder : NodeBuilder) -> Bool {
  builder.get_data_from_node(node).usage_count.unwrap_or(0) > 1
}
