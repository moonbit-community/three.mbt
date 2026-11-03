// nodes/accessors/BuiltinNode.js

///|
pub(all) struct BuiltinNode {}

///|
pub impl NodeClass for BuiltinNode with fn class_name(_) {
  "BuiltinNode"
}

///|
/// BuiltinNode has no `static get type()`, so it is Node's.
pub impl NodeClass for BuiltinNode with fn type_name(_) {
  "Node"
}

///|
pub impl NodeClass for BuiltinNode with fn has_flag(_, flag) {
  flag == "isBuiltinNode"
}

///|
pub impl NodeClass for BuiltinNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for BuiltinNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for BuiltinNode with fn generate(_, node, _, _) {
  node.name
}

///|
/// The constructor body: `super( 'float' )` has run in `Node::alloc`.
pub fn BuiltinNode::construct(node : Node, name : String) -> BuiltinNode {
  node.name = Some(name)
  BuiltinNode::{ }
}

///|
/// `new BuiltinNode( name )`.
pub fn BuiltinNode::new(name : String) -> Node {
  let node = Node::alloc(node_type="float")
  node.set_class(BuiltinNode::construct(node, name))
}

///|
pub fn BuiltinNode::of(node : Node) -> BuiltinNode? {
  match node.class_payload("BuiltinNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `builtin( name )`.
pub fn builtin(name : String) -> Node {
  BuiltinNode::new(name)
}
