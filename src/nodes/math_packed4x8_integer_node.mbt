// nodes/math/Packed4x8IntegerNode.js: WGSL's packed 4x8 integer built-ins, emulated
// unless the device has the `packed_4x8_integer_dot_product` language feature.

///|
pub(all) struct Packed4x8IntegerNode {
  mut method_ : String
  mut a_node : Node
  mut b_node : Node?
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn class_name(_) {
  "Packed4x8IntegerNode"
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn has_flag(_, flag) {
  flag == "isPacked4x8IntegerNode"
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn children(self, _, out) {
  push_child(out, "aNode", Some(self.a_node))
  push_child(out, "bNode", self.b_node)
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn generate_uses_output(_) {
  true
}

///|
/// `getInputType()`.
pub fn Packed4x8IntegerNode::get_input_type(
  self : Packed4x8IntegerNode,
) -> String {
  let method_ = self.method_
  if method_ is ("pack4xI8" | "pack4xI8Clamp") {
    "ivec4"
  } else if method_ is ("pack4xU8" | "pack4xU8Clamp") {
    "uvec4"
  } else {
    "uint"
  }
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn generate_node_type(
  self,
  _,
  _,
  _,
) {
  let method_ = self.method_
  Some(
    if method_ == "dot4I8Packed" {
      "int"
    } else if method_ == "unpack4xI8" {
      "ivec4"
    } else if method_ == "unpack4xU8" {
      "uvec4"
    } else {
      "uint"
    },
  )
}

///|
extern "js" fn packed4x8_integer_node_native() -> Bool =
  #|() => typeof navigator !== 'undefined' && navigator.gpu !== undefined &&
  #|  navigator.gpu.wgslLanguageFeatures !== undefined &&
  #|  navigator.gpu.wgslLanguageFeatures.has( 'packed_4x8_integer_dot_product' )

///|
/// `_getEmulatedFn()`.
fn Packed4x8IntegerNode::get_emulated_fn(self : Packed4x8IntegerNode) -> Node {
  match self.method_ {
    "dot4U8Packed" => _packed4x8_emulated_dot4_u8_packed
    "dot4I8Packed" => _packed4x8_emulated_dot4_i8_packed
    "pack4xI8" => _packed4x8_emulated_pack4x_i8
    "pack4xU8" => _packed4x8_emulated_pack4x_u8
    "pack4xI8Clamp" => _packed4x8_emulated_pack4x_i8_clamp
    "pack4xU8Clamp" => _packed4x8_emulated_pack4x_u8_clamp
    "unpack4xI8" => _packed4x8_emulated_unpack4x_i8
    "unpack4xU8" => _packed4x8_emulated_unpack4x_u8
    m => abort("TypeError: fn is not a function (\{m})")
  }
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn setup(self, node, builder) {
  // check for native language support
  if builder.renderer.backend.has_flag("isWebGPUBackend") &&
    packed4x8_integer_node_native() {
    return node.setup_base(builder)
  }
  // emulation
  let f = self.get_emulated_fn()
  match self.b_node {
    Some(b) => Some(f.call([self.a_node, b]))
    None => Some(f.call([self.a_node]))
  }
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let properties = builder.get_node_properties(node)
  if properties.get_node("outputNode") is Some(_) {
    return node.generate_base(builder, output)
  }
  // generate native WGSL call
  let type_ = node.get_node_type(builder)
  let input_type = self.get_input_type()
  let params = [self.a_node.build(builder, output=input_type)]
  if self.b_node is Some(b) {
    params.push(b.build(builder, output=input_type))
  }
  Some(builder.format("\{self.method_}( \{params.join(", ")} )", type_, output))
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("method", @core.JsValue::of(self.method_))
}

///|
pub impl NodeClass for Packed4x8IntegerNode with fn deserialize(
  self,
  node,
  data,
) {
  node.deserialize_base(data)
  self.method_ = @webgl.js_to_string(data.get("method"))
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn Packed4x8IntegerNode::construct(
  _node : Node,
  method_ : String,
  a_node : Node,
  b_node : Node?,
) -> Packed4x8IntegerNode {
  { method_, a_node, b_node, }
}

///|
/// `new Packed4x8IntegerNode( method, aNode, bNode = null )`.
pub fn Packed4x8IntegerNode::new(
  method_ : String,
  a_node : Node,
  b_node? : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(Packed4x8IntegerNode::construct(node, method_, a_node, b_node))
}

///|
pub fn Packed4x8IntegerNode::of(node : Node) -> Packed4x8IntegerNode? {
  match node.class_payload("Packed4x8IntegerNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

// emulations

///|
let _packed4x8_emulated_pack4x_u8 : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedPack4xU8",
  fn() {
    fn_(
      fn(inputs, _) {
        let v = operator_node_input(inputs, 0)
        let x = v.x().bit_and(uint(0xff))
        let y = v.y().bit_and(uint(0xff))
        let z = v.z().bit_and(uint(0xff))
        let w = v.w().bit_and(uint(0xff))
        Some(
          x
          .bit_or(y.shift_left(uint(8)))
          .bit_or(z.shift_left(uint(16)))
          .bit_or(w.shift_left(uint(24))),
        )
      },
      layout=FnLayout::short(
        [("v", "uvec4")],
        return_="uint",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedPack4xU8",
      ),
    )
  },
)

///|
let _packed4x8_emulated_pack4x_i8 : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedPack4xI8",
  fn() {
    fn_(
      fn(inputs, _) {
        let v = operator_node_input(inputs, 0)
        Some(_packed4x8_emulated_pack4x_u8.call([uvec4(v)]))
      },
      layout=FnLayout::short(
        [("v", "ivec4")],
        return_="uint",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedPack4xI8",
      ),
    )
  },
)

///|
let _packed4x8_emulated_pack4x_u8_clamp : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedPack4xU8Clamp",
  fn() {
    fn_(
      fn(inputs, _) {
        let v = operator_node_input(inputs, 0)
        Some(
          _packed4x8_emulated_pack4x_u8.call([
            clamp(v, low=uvec4(0), high=uvec4(255)),
          ]),
        )
      },
      layout=FnLayout::short(
        [("v", "uvec4")],
        return_="uint",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedPack4xU8Clamp",
      ),
    )
  },
)

///|
let _packed4x8_emulated_pack4x_i8_clamp : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedPack4xI8Clamp",
  fn() {
    fn_(
      fn(inputs, _) {
        let v = operator_node_input(inputs, 0)
        Some(
          _packed4x8_emulated_pack4x_i8.call([
            clamp(v, low=ivec4(-128), high=ivec4(127)),
          ]),
        )
      },
      layout=FnLayout::short(
        [("v", "ivec4")],
        return_="uint",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedPack4xI8Clamp",
      ),
    )
  },
)

///|
let _packed4x8_emulated_unpack4x_u8 : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedUnpack4xU8",
  fn() {
    fn_(
      fn(inputs, _) {
        let v = operator_node_input(inputs, 0)
        Some(
          uvec4_of([
            v.bit_and(uint(0xff)),
            v.shift_right(uint(8)).bit_and(uint(0xff)),
            v.shift_right(uint(16)).bit_and(uint(0xff)),
            v.shift_right(uint(24)).bit_and(uint(0xff)),
          ]),
        )
      },
      layout=FnLayout::short(
        [("v", "uint")],
        return_="uvec4",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedUnpack4xU8",
      ),
    )
  },
)

///|
/// `signExtendByte( v, byteShift )`.
fn packed4x8_sign_extend_byte(v : Node, byte_shift : Int32) -> Node {
  int(v.shift_left(uint(24 - byte_shift))).shift_right(int(24))
}

///|
let _packed4x8_emulated_unpack4x_i8 : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedUnpack4xI8",
  fn() {
    fn_(
      fn(inputs, _) {
        let v = operator_node_input(inputs, 0)
        Some(
          ivec4_of([
            packed4x8_sign_extend_byte(v, 0),
            packed4x8_sign_extend_byte(v, 8),
            packed4x8_sign_extend_byte(v, 16),
            packed4x8_sign_extend_byte(v, 24),
          ]),
        )
      },
      layout=FnLayout::short(
        [("v", "uint")],
        return_="ivec4",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedUnpack4xI8",
      ),
    )
  },
)

///|
let _packed4x8_emulated_dot4_u8_packed : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedDot4U8Packed",
  fn() {
    fn_(
      fn(inputs, _) {
        let a = operator_node_input(inputs, 0)
        let b = operator_node_input(inputs, 1)
        let ua = _packed4x8_emulated_unpack4x_u8.call([a])
        let ub = _packed4x8_emulated_unpack4x_u8.call([b])
        Some(
          ua
          .x()
          .mul(ub.x())
          .add(ua.y().mul(ub.y()))
          .add(ua.z().mul(ub.z()))
          .add(ua.w().mul(ub.w())),
        )
      },
      layout=FnLayout::short(
        [("a", "uint"), ("b", "uint")],
        return_="uint",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedDot4U8Packed",
      ),
    )
  },
)

///|
let _packed4x8_emulated_dot4_i8_packed : Node = module_nodes(
  "nodes/math/Packed4x8IntegerNode.js:emulatedDot4I8Packed",
  fn() {
    fn_(
      fn(inputs, _) {
        let a = operator_node_input(inputs, 0)
        let b = operator_node_input(inputs, 1)
        let ia = _packed4x8_emulated_unpack4x_i8.call([a])
        let ib = _packed4x8_emulated_unpack4x_i8.call([b])
        Some(
          ia
          .x()
          .mul(ib.x())
          .add(ia.y().mul(ib.y()))
          .add(ia.z().mul(ib.z()))
          .add(ia.w().mul(ib.w())),
        )
      },
      layout=FnLayout::short(
        [("a", "uint"), ("b", "uint")],
        return_="int",
        upstream="nodes/math/Packed4x8IntegerNode.js:emulatedDot4I8Packed",
      ),
    )
  },
)

///|
/// `nodeProxyAssignable( Packed4x8IntegerNode, method )`.
fn packed4x8_proxy(
  method_ : String,
  min : Int32,
  params : Array[TslValue],
) -> Node {
  let p = tsl_verify_params(method_, params, min, min)
  let nodes = p.map(tsl_proxy_arg)
  Packed4x8IntegerNode::new(
    method_,
    operator_node_required(nodes[0]),
    b_node?=nodes.get(1).unwrap_or(None),
  ).to_assignable()
}

///|
/// `dot4U8Packed( a, b )`.
pub fn dot4_u8_packed(a : &IntoTsl, b : &IntoTsl) -> Node {
  packed4x8_proxy("dot4U8Packed", 2, [a.to_tsl(), b.to_tsl()])
}

///|
/// `dot4I8Packed( a, b )`.
pub fn dot4_i8_packed(a : &IntoTsl, b : &IntoTsl) -> Node {
  packed4x8_proxy("dot4I8Packed", 2, [a.to_tsl(), b.to_tsl()])
}

///|
/// `pack4xI8( v )`.
pub fn pack4x_i8(v : &IntoTsl) -> Node {
  packed4x8_proxy("pack4xI8", 1, [v.to_tsl()])
}

///|
/// `pack4xU8( v )`.
pub fn pack4x_u8(v : &IntoTsl) -> Node {
  packed4x8_proxy("pack4xU8", 1, [v.to_tsl()])
}

///|
/// `pack4xI8Clamp( v )`.
pub fn pack4x_i8_clamp(v : &IntoTsl) -> Node {
  packed4x8_proxy("pack4xI8Clamp", 1, [v.to_tsl()])
}

///|
/// `pack4xU8Clamp( v )`.
pub fn pack4x_u8_clamp(v : &IntoTsl) -> Node {
  packed4x8_proxy("pack4xU8Clamp", 1, [v.to_tsl()])
}

///|
/// `unpack4xI8( v )`.
pub fn unpack4x_i8(v : &IntoTsl) -> Node {
  packed4x8_proxy("unpack4xI8", 1, [v.to_tsl()])
}

///|
/// `unpack4xU8( v )`.
pub fn unpack4x_u8(v : &IntoTsl) -> Node {
  packed4x8_proxy("unpack4xU8", 1, [v.to_tsl()])
}
