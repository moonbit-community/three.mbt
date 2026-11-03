// nodes/math/UnpackFloatNode.js: unpacks a `uint` into a float vector.

///|
pub(all) struct UnpackFloatNode {
  mut uint_node : Node
  mut encoding : String
  /// `'2x16'` or `'4x8'`.
  mut layout : String
}

///|
pub impl NodeClass for UnpackFloatNode with fn class_name(_) {
  "UnpackFloatNode"
}

///|
pub impl NodeClass for UnpackFloatNode with fn has_flag(_, flag) {
  flag == "isUnpackFloatNode"
}

///|
pub impl NodeClass for UnpackFloatNode with fn children(self, _, out) {
  push_child(out, "uintNode", Some(self.uint_node))
}

///|
pub impl NodeClass for UnpackFloatNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for UnpackFloatNode with fn generate_node_type(self, _, _, _) {
  Some(if self.layout == "4x8" { "vec4" } else { "vec2" })
}

///|
pub impl NodeClass for UnpackFloatNode with fn generate(self, _, builder, _) {
  let input_type = self.uint_node.get_node_type(builder)
  let method_ = builder.get_float_unpacking_method(
    self.encoding,
    layout=self.layout,
  )
  Some("\{method_}(\{self.uint_node.build(builder, output?=input_type)})")
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn UnpackFloatNode::construct(
  _node : Node,
  encoding : String,
  uint_node : Node,
) -> UnpackFloatNode {
  { uint_node, encoding, layout: "2x16", }
}

///|
/// `new UnpackFloatNode( encoding, uintNode )`.
pub fn UnpackFloatNode::new(encoding : String, uint_node : Node) -> Node {
  let node = Node::alloc()
  node.set_class(UnpackFloatNode::construct(node, encoding, uint_node))
}

///|
pub fn UnpackFloatNode::of(node : Node) -> UnpackFloatNode? {
  match node.class_payload("UnpackFloatNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `nodeProxyAssignable( UnpackFloatNode, encoding, null, { layout } )`.
fn unpack_float_node_proxy(
  encoding : String,
  layout : String?,
  value : &IntoTsl,
) -> Node {
  let p = tsl_verify_params(encoding, [value.to_tsl()], 1, 1)
  let node = UnpackFloatNode::new(
    encoding,
    operator_node_required(tsl_proxy_arg(p[0])),
  )
  if layout is Some(l) {
    UnpackFloatNode::of(node).unwrap().layout = l
  }
  node.to_assignable()
}

///|
/// `unpackSnorm2x16( value )`.
pub fn unpack_snorm2x16(value : &IntoTsl) -> Node {
  unpack_float_node_proxy("snorm", None, value)
}

///|
/// `unpackUnorm2x16( value )`.
pub fn unpack_unorm2x16(value : &IntoTsl) -> Node {
  unpack_float_node_proxy("unorm", None, value)
}

///|
/// `unpackHalf2x16( value )`.
pub fn unpack_half2x16(value : &IntoTsl) -> Node {
  unpack_float_node_proxy("float16", None, value)
}

///|
/// `unpackSnorm4x8( value )`.
pub fn unpack_snorm4x8(value : &IntoTsl) -> Node {
  unpack_float_node_proxy("snorm", Some("4x8"), value)
}

///|
/// `unpackUnorm4x8( value )`.
pub fn unpack_unorm4x8(value : &IntoTsl) -> Node {
  unpack_float_node_proxy("unorm", Some("4x8"), value)
}
