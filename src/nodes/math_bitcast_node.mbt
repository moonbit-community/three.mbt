// nodes/math/BitcastNode.js: reinterprets the bits of a value as another type.

///|
pub(all) struct BitcastNode {
  mut value_node : Node
  mut conversion_type : String
  /// The input type of the GLSL aliases (`floatBitsToInt`, ...); `null` otherwise.
  mut input_type : String?
}

///|
pub impl NodeClass for BitcastNode with fn class_name(_) {
  "BitcastNode"
}

///|
pub impl NodeClass for BitcastNode with fn has_flag(_, flag) {
  flag == "isBitcastNode"
}

///|
pub impl NodeClass for BitcastNode with fn children(self, _, out) {
  push_child(out, "valueNode", Some(self.value_node))
}

///|
pub impl NodeClass for BitcastNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for BitcastNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  // GLSL aliasing
  if self.input_type is Some(_) {
    let value_type = self.value_node.get_node_type(builder)
    let value_length = builder.get_type_length(value_type)
    return Some(
      builder.get_type_from_length(
        value_length,
        component_type=self.conversion_type,
      ),
    )
  }
  Some(self.conversion_type)
}

///|
pub impl NodeClass for BitcastNode with fn generate(self, node, builder, _) {
  let type_ = node.get_node_type(builder)
  let input_type = match self.input_type {
    Some(input) => {
      let value_type = self.value_node.get_node_type(builder)
      let value_type_length = builder.get_type_length(value_type)
      if value_type_length == 1 {
        Some(input)
      } else {
        Some(
          builder.change_component_type(operator_node_str(value_type), input),
        )
      }
    }
    None => self.value_node.get_node_type(builder)
  }
  let method_ = builder.get_bitcast_method(
    operator_node_str(type_),
    input_type?,
  )
  Some("\{method_}( \{self.value_node.build(builder, output?=input_type)} )")
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn BitcastNode::construct(
  _node : Node,
  value_node : Node,
  conversion_type : String,
  input_type : String?,
) -> BitcastNode {
  { value_node, conversion_type, input_type, }
}

///|
/// `new BitcastNode( valueNode, conversionType, inputType = null )`.
pub fn BitcastNode::new(
  value_node : Node,
  conversion_type : String,
  input_type? : String,
) -> Node {
  let node = Node::alloc()
  node.set_class(
    BitcastNode::construct(node, value_node, conversion_type, input_type),
  )
}

///|
pub fn BitcastNode::of(node : Node) -> BitcastNode? {
  match node.class_payload("BitcastNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `bitcast( value, conversionType )`: the bits of `value` as `conversionType`.
pub fn bitcast(value : &IntoTsl, conversion_type : String) -> Node {
  let p = tsl_verify_params(
    "BitcastNode",
    [value.to_tsl(), String(conversion_type)],
    2,
    2,
  )
  let value_node = operator_node_required(tsl_proxy_arg(p[0]))
  BitcastNode::new(value_node, conversion_type).to_assignable()
}

///|
/// `floatBitsToInt( value )`.
pub fn float_bits_to_int(value : Node) -> Node {
  BitcastNode::new(value, "int", input_type="float")
}

///|
/// `floatBitsToUint( value )`.
pub fn float_bits_to_uint(value : Node) -> Node {
  BitcastNode::new(value, "uint", input_type="float")
}

///|
/// `intBitsToFloat( value )`.
pub fn int_bits_to_float(value : Node) -> Node {
  BitcastNode::new(value, "float", input_type="int")
}

///|
/// `uintBitsToFloat( value )`.
pub fn uint_bits_to_float(value : Node) -> Node {
  BitcastNode::new(value, "float", input_type="uint")
}
