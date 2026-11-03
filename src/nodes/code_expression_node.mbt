// nodes/code/ExpressionNode.js: a raw shader snippet, a statement when `void`.

///|
pub(all) struct ExpressionNode {
  mut snippet : String
}

///|
pub impl NodeClass for ExpressionNode with fn class_name(_) {
  "ExpressionNode"
}

///|
pub impl NodeClass for ExpressionNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for ExpressionNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ExpressionNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let type_ = node.get_node_type(builder)
  let snippet = self.snippet
  if type_ == Some("void") {
    builder.add_line_flow_code(snippet, node~) |> ignore
    None
  } else {
    Some(builder.format(snippet, type_, output))
  }
}

///|
/// The constructor body: `super( nodeType )` has run in `Node::alloc`.
pub fn ExpressionNode::construct(
  _node : Node,
  snippet : String,
) -> ExpressionNode {
  { snippet, }
}

///|
/// `new ExpressionNode( snippet = '', nodeType = 'void' )`.
pub fn ExpressionNode::new(
  snippet~ : String = "",
  node_type~ : String = "void",
) -> Node {
  let node = Node::alloc(node_type~)
  node.set_class(ExpressionNode::construct(node, snippet))
}

///|
pub fn ExpressionNode::of(node : Node) -> ExpressionNode? {
  match node.class_payload("ExpressionNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `expression( snippet, nodeType )` (`nodeProxy( ExpressionNode )`).
pub fn expression(snippet : String, node_type? : String) -> Node {
  match node_type {
    Some(t) => ExpressionNode::new(snippet~, node_type=t)
    None => ExpressionNode::new(snippet~)
  }
}
