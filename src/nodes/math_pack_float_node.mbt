// nodes/math/PackFloatNode.js: packs a float vector into a `uint`.

///|
pub(all) struct PackFloatNode {
  mut vector_node : Node
  mut encoding : String
  /// `'2x16'` or `'4x8'`.
  mut layout : String
}

///|
pub impl NodeClass for PackFloatNode with fn class_name(_) {
  "PackFloatNode"
}

///|
pub impl NodeClass for PackFloatNode with fn has_flag(_, flag) {
  flag == "isPackFloatNode"
}

///|
pub impl NodeClass for PackFloatNode with fn children(self, _, out) {
  push_child(out, "vectorNode", Some(self.vector_node))
}

///|
pub impl NodeClass for PackFloatNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for PackFloatNode with fn generate_node_type(_, _, _, _) {
  Some("uint")
}

///|
pub impl NodeClass for PackFloatNode with fn generate(self, _, builder, _) {
  let input_type = self.vector_node.get_node_type(builder)
  let method_ = builder.get_float_packing_method(
    self.encoding,
    layout=self.layout,
  )
  Some("\{method_}(\{self.vector_node.build(builder, output?=input_type)})")
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn PackFloatNode::construct(
  _node : Node,
  encoding : String,
  vector_node : Node,
) -> PackFloatNode {
  { vector_node, encoding, layout: "2x16", }
}

///|
/// `new PackFloatNode( encoding, vectorNode )`.
pub fn PackFloatNode::new(encoding : String, vector_node : Node) -> Node {
  let node = Node::alloc()
  node.set_class(PackFloatNode::construct(node, encoding, vector_node))
}

///|
pub fn PackFloatNode::of(node : Node) -> PackFloatNode? {
  match node.class_payload("PackFloatNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `nodeProxyAssignable( PackFloatNode, encoding, null, { layout } )`.
fn pack_float_node_proxy(
  encoding : String,
  layout : String?,
  value : &IntoTsl,
) -> Node {
  let p = tsl_verify_params(encoding, [value.to_tsl()], 1, 1)
  let node = PackFloatNode::new(
    encoding,
    operator_node_required(tsl_proxy_arg(p[0])),
  )
  if layout is Some(l) {
    PackFloatNode::of(node).unwrap().layout = l
  }
  node.to_assignable()
}

///|
/// `packSnorm2x16( value )`.
pub fn pack_snorm2x16(value : &IntoTsl) -> Node {
  pack_float_node_proxy("snorm", None, value)
}

///|
/// `packUnorm2x16( value )`.
pub fn pack_unorm2x16(value : &IntoTsl) -> Node {
  pack_float_node_proxy("unorm", None, value)
}

///|
/// `packHalf2x16( value )`.
pub fn pack_half2x16(value : &IntoTsl) -> Node {
  pack_float_node_proxy("float16", None, value)
}

///|
/// `packSnorm4x8( value )`.
pub fn pack_snorm4x8(value : &IntoTsl) -> Node {
  pack_float_node_proxy("snorm", Some("4x8"), value)
}

///|
/// `packUnorm4x8( value )`.
pub fn pack_unorm4x8(value : &IntoTsl) -> Node {
  pack_float_node_proxy("unorm", Some("4x8"), value)
}
