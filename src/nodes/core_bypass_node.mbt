// nodes/core/BypassNode.js

///|
/// Emits `callNode` as a statement and evaluates to `outputNode`.
pub(all) struct BypassNode {
  mut output_node : Node
  mut call_node : Node
}

///|
pub impl NodeClass for BypassNode with fn class_name(_) {
  "BypassNode"
}

///|
pub impl NodeClass for BypassNode with fn has_flag(_, flag) {
  flag == "isBypassNode"
}

///|
pub impl NodeClass for BypassNode with fn children(self, _, out) {
  push_child(out, "outputNode", Some(self.output_node))
  push_child(out, "callNode", Some(self.call_node))
}

///|
pub impl NodeClass for BypassNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for BypassNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for BypassNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.output_node.get_node_type(builder)
}

///|
pub impl NodeClass for BypassNode with fn generate(self, node, builder, _) {
  let snippet = self.call_node.build(builder, output="void")
  if snippet != "" {
    builder.add_line_flow_code(snippet, node~) |> ignore
  }
  Some(self.output_node.build(builder))
}

///|
pub fn BypassNode::construct(
  _node : Node,
  output_node : Node,
  call_node : Node,
) -> BypassNode {
  { output_node, call_node, }
}

///|
/// `new BypassNode( outputNode, callNode )`.
pub fn BypassNode::new(output_node : Node, call_node : Node) -> Node {
  let this = Node::alloc()
  this.set_class(BypassNode::construct(this, output_node, call_node))
}

///|
pub fn BypassNode::of(node : Node) -> BypassNode? {
  match node.class_payload("BypassNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `bypass( outputNode, callNode )`.
pub fn bypass(output_node : &IntoTsl, call_node : &IntoTsl) -> Node {
  BypassNode::new(
    node_object(output_node.to_tsl()),
    node_object(call_node.to_tsl()),
  )
}

///|
pub fn Node::bypass(self : Node, call_node : &IntoTsl) -> Node {
  bypass(self, call_node)
}
