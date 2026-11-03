// nodes/math/BitcountNode.js: `countTrailingZeros`, `countLeadingZeros`,
// `countOneBits`. WebGPU has them built in; other backends get layout functions,
// created once per element and input type.

///|
/// `registeredBitcountFunctions`.
let _bitcount_node_registered : Map[String, Node] = Map([])

///|
pub(all) struct BitcountNode {
  math : MathNode
}

///|
pub impl NodeClass for BitcountNode with fn class_name(_) {
  "BitcountNode"
}

///|
pub impl NodeClass for BitcountNode with fn parent(self) {
  Some(self.math)
}

///|
pub impl NodeClass for BitcountNode with fn has_flag(self, flag) {
  flag == "isBitcountNode" || NodeClass::has_flag(self.math, flag)
}

///|
/// `_resolveElementType( inputNode, outputNode, elementType )`.
fn bitcount_node_resolve_element_type(
  input_node : Node,
  output_node : Node,
  element_type : String,
) -> Unit {
  if element_type == "int" {
    output_node.assign(bitcast(input_node, "uint"))
  } else {
    output_node.assign(input_node)
  }
}

///|
/// `_returnDataNode( inputType )`: the conversion to `inputType`.
fn bitcount_node_return_data_node(input_type : String) -> (&IntoTsl) -> Node {
  match input_type {
    "uint" => uint
    "int" => int
    "uvec2" => uvec2
    "uvec3" => uvec3
    "uvec4" => uvec4
    "ivec2" => ivec2
    "ivec3" => ivec3
    "ivec4" => ivec4
    t =>
      fn(_) { abort("TypeError: outputConvertNode is not a function (\{t})") }
  }
}

///|
fn bitcount_node_layout(type_ : String) -> FnLayoutArg {
  FnLayout::short([("value", type_)], return_=type_)
}

///|
/// `_createTrailingZerosBaseLayout( elementType )`.
fn bitcount_node_trailing_zeros_base_layout(element_type : String) -> Node {
  let output_convert_node = bitcount_node_return_data_node(element_type)
  fn_(
    fn(inputs, _) {
      let value = operator_node_input(inputs, 0)
      if_value(value.equal(uint(0)), fn() { output_convert_node(32) }) |> ignore
      let v = uint(0.0)
      bitcount_node_resolve_element_type(value, v, element_type)
      let f = float(v.bit_and(negate(v)))
      let uint_bits = float_bits_to_uint(f)
      let num_trailing_zeros = uint_bits.shift_right(23).sub(127)
      Some(output_convert_node(num_trailing_zeros))
    },
    layout=bitcount_node_layout(element_type),
  )
}

///|
/// `_createLeadingZerosBaseLayout( elementType )`.
fn bitcount_node_leading_zeros_base_layout(element_type : String) -> Node {
  let output_convert_node = bitcount_node_return_data_node(element_type)
  fn_(
    fn(inputs, _) {
      let value = operator_node_input(inputs, 0)
      if_value(value.equal(uint(0)), fn() { output_convert_node(32) }) |> ignore
      let v = uint(0)
      let n = uint(0)
      bitcount_node_resolve_element_type(value, v, element_type)
      if_(v.shift_right(16).equal(0), fn() {
        n.add_assign(16)
        v.shift_left_assign(16)
      })
      |> ignore
      if_(v.shift_right(24).equal(0), fn() {
        n.add_assign(8)
        v.shift_left_assign(8)
      })
      |> ignore
      if_(v.shift_right(28).equal(0), fn() {
        n.add_assign(4)
        v.shift_left_assign(4)
      })
      |> ignore
      if_(v.shift_right(30).equal(0), fn() {
        n.add_assign(2)
        v.shift_left_assign(2)
      })
      |> ignore
      if_(v.shift_right(31).equal(0), fn() { n.add_assign(1) }) |> ignore
      Some(output_convert_node(n))
    },
    layout=bitcount_node_layout(element_type),
  )
}

///|
/// `_createOneBitsBaseLayout( elementType )`.
fn bitcount_node_one_bits_base_layout(element_type : String) -> Node {
  let output_convert_node = bitcount_node_return_data_node(element_type)
  fn_(
    fn(inputs, _) {
      let value = operator_node_input(inputs, 0)
      let v = uint(0.0)
      bitcount_node_resolve_element_type(value, v, element_type)
      v.assign(v.sub(v.shift_right(uint(1)).bit_and(uint(0x55555555))))
      v.assign(
        v
        .bit_and(uint(0x33333333))
        .add(v.shift_right(uint(2)).bit_and(uint(0x33333333))),
      )
      let num_bits = v
        .add(v.shift_right(uint(4)))
        .bit_and(uint(0xF0F0F0F))
        .mul(uint(0x1010101))
        .shift_right(uint(24))
      Some(output_convert_node(num_bits))
    },
    layout=bitcount_node_layout(element_type),
  )
}

///|
/// `_createMainLayout( inputType, typeLength, baseFn )`.
fn bitcount_node_main_layout(
  input_type : String,
  type_length : Int32,
  base_fn : Node,
) -> Node {
  let output_convert_node = bitcount_node_return_data_node(input_type)
  fn_(
    fn(inputs, _) {
      let value = operator_node_input(inputs, 0)
      if type_length == 1 {
        Some(output_convert_node(base_fn.call([value])))
      } else {
        let vec = output_convert_node(0)
        let components = ["x", "y", "z", "w"]
        for i in 0..<type_length {
          let component = components[i]
          vec
          .swizzle(component)
          .assign(base_fn.call([value.swizzle(component)]))
        }
        Some(vec)
      }
    },
    layout=bitcount_node_layout(input_type),
  )
}

///|
pub impl NodeClass for BitcountNode with fn setup(self, node, builder) {
  let method_ = self.math.method_
  let a_node = self.math.a_node
  let renderer = builder.renderer
  if renderer.backend.has_flag("isWebGPUBackend") {
    // use built-in WGSL functions for WebGPU
    return NodeClass::setup(self.math, node, builder)
  }
  let input_type = operator_node_str(self.math.get_input_type(builder))
  let element_type = operator_node_str(
    builder.get_element_type(Some(input_type)),
  )
  let type_length = builder.get_type_length(Some(input_type))
  let base_method = "\{method_}_base_\{element_type}"
  let new_method = "\{method_}_\{input_type}"
  let base_fn = match _bitcount_node_registered.get(base_method) {
    Some(f) => f
    None => {
      let f = match method_ {
        "countLeadingZeros" =>
          bitcount_node_leading_zeros_base_layout(element_type)
        "countTrailingZeros" =>
          bitcount_node_trailing_zeros_base_layout(element_type)
        "countOneBits" => bitcount_node_one_bits_base_layout(element_type)
        m => abort("TypeError: baseFn is not a function (\{m})")
      }
      _bitcount_node_registered[base_method] = f
      f
    }
  }
  let f = match _bitcount_node_registered.get(new_method) {
    Some(f) => f
    None => {
      let f = bitcount_node_main_layout(input_type, type_length, base_fn)
      _bitcount_node_registered[new_method] = f
      f
    }
  }
  let output = fn_(fn(_, _) { Some(f.call([a_node])) })
  Some(output.call([]))
}

///|
/// The constructor body: `super( method, aNode )` is `MathNode::construct`.
pub fn BitcountNode::construct(
  node : Node,
  method_ : String,
  a_node : Node,
) -> BitcountNode {
  { math: MathNode::construct(node, method_, a_node, None, None, []), }
}

///|
/// `new BitcountNode( method, aNode )`.
pub fn BitcountNode::new(method_ : String, a_node : Node) -> Node {
  let node = Node::alloc()
  node.set_class(BitcountNode::construct(node, method_, a_node))
}

///|
pub fn BitcountNode::of(node : Node) -> BitcountNode? {
  match node.class_payload("BitcountNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn bitcount_node_proxy(method_ : String, value : &IntoTsl) -> Node {
  let p = tsl_verify_params(method_, [value.to_tsl()], 1, 1)
  BitcountNode::new(method_, operator_node_required(tsl_proxy_arg(p[0]))).to_assignable()
}

///|
/// `countTrailingZeros( value )`.
pub fn count_trailing_zeros(value : &IntoTsl) -> Node {
  bitcount_node_proxy("countTrailingZeros", value)
}

///|
/// `countLeadingZeros( value )`.
pub fn count_leading_zeros(value : &IntoTsl) -> Node {
  bitcount_node_proxy("countLeadingZeros", value)
}

///|
/// `countOneBits( value )`.
pub fn count_one_bits(value : &IntoTsl) -> Node {
  bitcount_node_proxy("countOneBits", value)
}
