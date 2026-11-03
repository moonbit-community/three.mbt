// nodes/math/OperatorNode.js: arithmetic, comparison, logical and bitwise operators.
//
// Every TSL operator is `nodeProxyAssignable( OperatorNode, op )`: its arguments go
// through `nodeObject` before the node is created, and the result is assignable (and
// added to the current stack). Operators upstream accepts with any number of
// arguments (`add( a, b, c )`) have an `_of` form taking an array (`add_of([a, b, c])`),
// as the type conversions do. Chained methods (`a.add( b )`) and their assign forms
// (`a.addAssign( b )`, statements returning `Unit`) are `Node` methods here, as
// `addMethodChaining` registers them.

///|
let _operator_node_vector_operators : Map[String, String] = {
  "==": "equal",
  "!=": "notEqual",
  "<": "lessThan",
  ">": "greaterThan",
  "<=": "lessThanEqual",
  ">=": "greaterThanEqual",
  "%": "mod",
}

///|
/// `a op b` (or `op a` for the unary operators).
pub(all) struct OperatorNode {
  mut op : String
  mut a_node : Node
  /// `undefined` for the unary operators.
  mut b_node : Node?
}

///|
pub impl NodeClass for OperatorNode with fn class_name(_) {
  "OperatorNode"
}

///|
pub impl NodeClass for OperatorNode with fn has_flag(_, flag) {
  flag == "isOperatorNode"
}

///|
pub impl NodeClass for OperatorNode with fn children(self, _, out) {
  push_child(out, "aNode", Some(self.a_node))
  push_child(out, "bNode", self.b_node)
}

///|
pub impl NodeClass for OperatorNode with fn generate_uses_output(_) {
  true
}

///|
fn operator_node_is_comparison(op : String) -> Bool {
  op is ("==" | "!=" | "<" | ">" | "<=" | ">=")
}

///|
fn operator_node_max_int(a : Int32, b : Int32) -> Int32 {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn operator_node_str(type_ : String?) -> String {
  match type_ {
    Some(t) => t
    None => "null"
  }
}

///|
pub impl NodeClass for OperatorNode with fn generate_node_type(
  self,
  _,
  builder,
  output,
) {
  let op = self.op
  let a_node = self.a_node
  let b_node = self.b_node
  let type_a = a_node.get_node_type(builder)
  let type_b = match b_node {
    Some(b) => b.get_node_type(builder)
    None => None
  }
  if type_a == Some("void") || type_b == Some("void") {
    match output {
      Some(o) if o != "" => Some(o)
      _ => Some("void")
    }
  } else if op is ("~" | "&" | "|" | "^" | ">>" | "<<") {
    Some(builder.get_integer_type(operator_node_str(type_a)))
  } else if op is ("&&" | "||" | "^^") {
    Some("bool")
  } else if op == "!" {
    let type_length = builder.get_type_length(type_a)
    Some(if type_length > 1 { "bvec\{type_length}" } else { "bool" })
  } else if operator_node_is_comparison(op) {
    let type_length = operator_node_max_int(
      builder.get_type_length(type_a),
      builder.get_type_length(type_b),
    )
    Some(if type_length > 1 { "bvec\{type_length}" } else { "bool" })
  } else if type_b is None {
    type_a
  } else {
    // Handle matrix operations
    if builder.is_matrix(type_a) {
      if builder.is_scalar(type_b) {
        return type_a // matrix * scalar = matrix
      } else if builder.is_vector(type_b) {
        return Some(builder.get_vector_from_matrix(operator_node_str(type_a))) // matrix * vector
      } else if builder.is_matrix(type_b) {
        return type_a // matrix * matrix
      }
    } else if builder.is_matrix(type_b) {
      if builder.is_scalar(type_a) {
        return type_b // scalar * matrix = matrix
      } else if builder.is_vector(type_a) {
        return Some(builder.get_vector_from_matrix(operator_node_str(type_b))) // vector * matrix
      }
    }
    // anytype x anytype: use the greater length vector
    let type_ = if builder.get_type_length(type_b) >
      builder.get_type_length(type_a) {
      type_b
    } else {
      type_a
    }
    let promoted_type = builder.get_promoted_component_type([
      Some(a_node),
      b_node,
    ])
    Some(builder.change_component_type(operator_node_str(type_), promoted_type))
  }
}

///|
pub impl NodeClass for OperatorNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let op = self.op
  let a_node = self.a_node
  let b_node = self.b_node
  let type_ = node.get_node_type(builder, output?)
  let mut type_a : String? = None
  let mut type_b : String? = None
  if type_ != Some("void") {
    type_a = a_node.get_node_type(builder)
    type_b = match b_node {
      Some(b) => b.get_node_type(builder)
      None => None
    }
    if operator_node_is_comparison(op) {
      let length = operator_node_max_int(
        builder.get_type_length(type_a),
        builder.get_type_length(type_b),
      )
      let t = builder.get_type_from_length(
        length,
        component_type=builder.get_promoted_component_type([
          Some(a_node),
          b_node,
        ]),
      )
      type_a = Some(t)
      type_b = Some(t)
    } else if op is (">>" | "<<") {
      type_a = type_
      type_b = Some(
        builder.change_component_type(operator_node_str(type_b), "uint"),
      )
    } else if builder.is_matrix(type_a) {
      if builder.is_scalar(type_b) {
        // Keep matrix type for typeA, but ensure typeB stays float
        type_b = Some("float")
      } else if builder.is_vector(type_b) {
        // matrix x vector
        type_b = Some(builder.get_vector_from_matrix(operator_node_str(type_a)))
      } else if builder.is_matrix(type_b) {
        // matrix x matrix - keep both types
        ()
      } else {
        type_a = type_
        type_b = type_
      }
    } else if builder.is_matrix(type_b) {
      if builder.is_scalar(type_a) {
        // Keep matrix type for typeB, but ensure typeA stays float
        type_a = Some("float")
      } else if builder.is_vector(type_a) {
        // vector x matrix
        type_a = Some(builder.get_vector_from_matrix(operator_node_str(type_b)))
      } else {
        type_a = type_
        type_b = type_
      }
    } else {
      // anytype x anytype
      type_a = type_
      type_b = type_
    }
  } else {
    type_a = type_
    type_b = type_
  }
  let a = a_node.build(builder, output?=type_a)
  let b = match b_node {
    Some(bn) => bn.build(builder, output?=type_b)
    None => "null"
  }
  let fn_op_snippet = builder.get_function_operator(op)
  if output != Some("void") {
    let is_glsl = builder.renderer.coordinate_system() ==
      @core.WebGLCoordinateSystem
    if operator_node_is_comparison(op) {
      if is_glsl {
        if builder.is_vector(type_a) {
          Some(
            builder.format(
              "\{OperatorNode::get_operator_method(self, builder, output)}( \{a}, \{b} )",
              type_,
              output,
            ),
          )
        } else {
          Some(builder.format("( \{a} \{op} \{b} )", type_, output))
        }
      } else {
        // WGSL
        Some(builder.format("( \{a} \{op} \{b} )", type_, output))
      }
    } else if op == "%" {
      if builder.is_integer(type_b) {
        Some(builder.format("( \{a} % \{b} )", type_, output))
      } else {
        Some(
          builder.format(
            "\{OperatorNode::get_operator_method(self, builder, type_)}( \{a}, \{b} )",
            type_,
            output,
          ),
        )
      }
    } else if op == "!" {
      if is_glsl && builder.is_vector(type_a) {
        Some(builder.format("not( \{a} )", output, None))
      } else {
        // WGSL and scalars on GLSL
        Some(builder.format("( \{op} \{a} )", type_a, output))
      }
    } else if op == "~" {
      Some(builder.format("( \{op} \{a} )", type_a, output))
    } else if fn_op_snippet is Some(fn_op) && fn_op != "" {
      Some(builder.format("\{fn_op}( \{a}, \{b} )", type_, output))
    } else if builder.is_matrix(type_a) && builder.is_scalar(type_b) {
      // Handle matrix operations
      Some(builder.format("( \{b} \{op} \{a} )", type_, output))
    } else if builder.is_scalar(type_a) && builder.is_matrix(type_b) {
      Some(builder.format("\{a} \{op} \{b}", type_, output))
    } else {
      let mut snippet = "( \{a} \{op} \{b} )"
      if !is_glsl &&
        type_ == Some("bool") &&
        builder.is_vector(type_a) &&
        builder.is_vector(type_b) {
        snippet = "all\{snippet}"
      }
      Some(builder.format(snippet, type_, output))
    }
  } else if type_a != Some("void") {
    if fn_op_snippet is Some(fn_op) && fn_op != "" {
      Some(builder.format("\{fn_op}( \{a}, \{b} )", type_, output))
    } else if builder.is_matrix(type_a) && builder.is_scalar(type_b) {
      Some(builder.format("\{b} \{op} \{a}", type_, output))
    } else {
      Some(builder.format("\{a} \{op} \{b}", type_, output))
    }
  } else {
    None
  }
}

///|
pub impl NodeClass for OperatorNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("op", @core.JsValue::of(self.op))
}

///|
pub impl NodeClass for OperatorNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self.op = @webgl.js_to_string(data.get("op"))
}

///|
/// `getOperatorMethod( builder, output )`.
pub fn OperatorNode::get_operator_method(
  self : OperatorNode,
  builder : NodeBuilder,
  output : String?,
) -> String {
  let method_ = match _operator_node_vector_operators.get(self.op) {
    Some(m) => m
    None => "undefined"
  }
  builder.get_method(method_, output?)
}

///|
/// The constructor body: `super()` has run in `Node::alloc`. Extra parameters nest
/// left to right: `a op b op c` is `( a op b ) op c`.
pub fn OperatorNode::construct(
  _node : Node,
  op : String,
  a_node : Node,
  b_node : Node?,
  params : Array[Node],
) -> OperatorNode {
  let mut a_node = a_node
  let mut b_node = b_node
  if params.length() > 0 {
    let mut final_op = OperatorNode::new(op, a_node, b_node?)
    for i in 0..<(params.length() - 1) {
      final_op = OperatorNode::new(op, final_op, b_node=params[i])
    }
    a_node = final_op
    b_node = Some(params[params.length() - 1])
  }
  { op, a_node, b_node, }
}

///|
/// `new OperatorNode( op, aNode, bNode, ...params )`.
pub fn OperatorNode::new(
  op : String,
  a_node : Node,
  b_node? : Node,
  params~ : Array[Node] = [],
) -> Node {
  let node = Node::alloc()
  node.set_class(OperatorNode::construct(node, op, a_node, b_node, params))
}

///|
pub fn OperatorNode::of(node : Node) -> OperatorNode? {
  match node.class_payload("OperatorNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

// ---------------------------------------------------------------------------
// TSL

///|
/// `verifyParamsLimit( params )` of `ShaderNodeProxy`: pads with `0` below the minimum
/// and truncates above the maximum (`-1` is no maximum), with upstream's errors.
/// `name` is the TSL name (`setName`) or the scope; `/[a-z]/i` names get `()`.
pub fn tsl_verify_params(
  name : String,
  params : Array[TslValue],
  min : Int32,
  max : Int32,
) -> Array[TslValue] {
  let has_letter = name.iter().any(fn(c) { c is ('a'..<='z' | 'A'..<='Z') })
  let tsl_name = if has_letter { name + "()" } else { name }
  if params.length() < min {
    @core.error(
      "TSL: \"\{tsl_name}\" parameter length is less than minimum required.",
    )
    let padded = params.copy()
    while padded.length() < min {
      padded.push(Number(0.0))
    }
    padded
  } else if max >= 0 && params.length() > max {
    @core.error("TSL: \"\{tsl_name}\" parameter length exceeds limit.")
    params[0:max].to_owned()
  } else {
    params
  }
}

///|
/// `nodeObject( value )` for a proxy argument: `undefined` and `null` stay `None`.
pub fn tsl_proxy_arg(value : TslValue) -> Node? {
  match node_object_value(value) {
    Node(n) => Some(n)
    Undefined | Null => None
    v => abort("TSL: \{get_value_type(v).unwrap_or("value")} is not a node")
  }
}

///|
/// `nodeObject( value )` for a required proxy argument.
fn operator_node_required(value : Node?) -> Node {
  match value {
    Some(n) => n
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'getNodeType')",
      )
  }
}

///|
/// `nodeProxyAssignable( OperatorNode, op ).setParameterLength( min, max ).setName( name )`.
fn operator_node_proxy(
  op : String,
  name : String,
  min : Int32,
  max : Int32,
  params : Array[TslValue],
) -> Node {
  let params = tsl_verify_params(name, params, min, max)
  let nodes = params.map(tsl_proxy_arg)
  let a_node = operator_node_required(nodes.get(0).unwrap_or(None))
  let b_node = nodes.get(1).unwrap_or(None)
  let rest = if nodes.length() > 2 {
    nodes[2:].to_owned().map(operator_node_required)
  } else {
    []
  }
  OperatorNode::new(op, a_node, b_node?, params=rest).to_assignable()
}

///|
fn tsl_values2(a : &IntoTsl, b : &IntoTsl) -> Array[TslValue] {
  [a.to_tsl(), b.to_tsl()]
}

///|
fn tsl_values_of(params : Array[&IntoTsl]) -> Array[TslValue] {
  params.map(fn(p) { p.to_tsl() })
}

///|
fn operator_node_add(p : Array[TslValue]) -> Node {
  operator_node_proxy("+", "add", 2, -1, p)
}

///|
fn operator_node_sub(p : Array[TslValue]) -> Node {
  operator_node_proxy("-", "sub", 2, -1, p)
}

///|
fn operator_node_mul(p : Array[TslValue]) -> Node {
  operator_node_proxy("*", "mul", 2, -1, p)
}

///|
fn operator_node_div(p : Array[TslValue]) -> Node {
  operator_node_proxy("/", "div", 2, -1, p)
}

///|
fn operator_node_mod(p : Array[TslValue]) -> Node {
  operator_node_proxy("%", "mod", 2, 2, p)
}

///|
fn operator_node_equal(p : Array[TslValue]) -> Node {
  operator_node_proxy("==", "equal", 2, 2, p)
}

///|
fn operator_node_not_equal(p : Array[TslValue]) -> Node {
  operator_node_proxy("!=", "notEqual", 2, 2, p)
}

///|
fn operator_node_less_than(p : Array[TslValue]) -> Node {
  operator_node_proxy("<", "lessThan", 2, 2, p)
}

///|
fn operator_node_greater_than(p : Array[TslValue]) -> Node {
  operator_node_proxy(">", "greaterThan", 2, 2, p)
}

///|
fn operator_node_less_than_equal(p : Array[TslValue]) -> Node {
  operator_node_proxy("<=", "lessThanEqual", 2, 2, p)
}

///|
fn operator_node_greater_than_equal(p : Array[TslValue]) -> Node {
  operator_node_proxy(">=", "greaterThanEqual", 2, 2, p)
}

///|
fn operator_node_and(p : Array[TslValue]) -> Node {
  operator_node_proxy("&&", "and", 2, -1, p)
}

///|
fn operator_node_or(p : Array[TslValue]) -> Node {
  operator_node_proxy("||", "or", 2, -1, p)
}

///|
fn operator_node_not(p : Array[TslValue]) -> Node {
  operator_node_proxy("!", "not", 1, 1, p)
}

///|
fn operator_node_xor(p : Array[TslValue]) -> Node {
  operator_node_proxy("^^", "xor", 2, 2, p)
}

///|
fn operator_node_bit_and(p : Array[TslValue]) -> Node {
  operator_node_proxy("&", "bitAnd", 2, 2, p)
}

///|
fn operator_node_bit_not(p : Array[TslValue]) -> Node {
  operator_node_proxy("~", "bitNot", 1, 1, p)
}

///|
fn operator_node_bit_or(p : Array[TslValue]) -> Node {
  operator_node_proxy("|", "bitOr", 2, 2, p)
}

///|
fn operator_node_bit_xor(p : Array[TslValue]) -> Node {
  operator_node_proxy("^", "bitXor", 2, 2, p)
}

///|
fn operator_node_shift_left(p : Array[TslValue]) -> Node {
  operator_node_proxy("<<", "shiftLeft", 2, 2, p)
}

///|
fn operator_node_shift_right(p : Array[TslValue]) -> Node {
  operator_node_proxy(">>", "shiftRight", 2, 2, p)
}

///|
/// `a + b`.
pub fn add(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_add(tsl_values2(a, b))
}

///|
/// `add( a, b, ...params )`.
pub fn add_of(params : Array[&IntoTsl]) -> Node {
  operator_node_add(tsl_values_of(params))
}

///|
/// `a - b`.
pub fn sub(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_sub(tsl_values2(a, b))
}

///|
/// `sub( a, b, ...params )`.
pub fn sub_of(params : Array[&IntoTsl]) -> Node {
  operator_node_sub(tsl_values_of(params))
}

///|
/// `a * b`.
pub fn mul(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_mul(tsl_values2(a, b))
}

///|
/// `mul( a, b, ...params )`.
pub fn mul_of(params : Array[&IntoTsl]) -> Node {
  operator_node_mul(tsl_values_of(params))
}

///|
/// `a / b`.
pub fn div(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_div(tsl_values2(a, b))
}

///|
/// `div( a, b, ...params )`.
pub fn div_of(params : Array[&IntoTsl]) -> Node {
  operator_node_div(tsl_values_of(params))
}

///|
/// `a % b`.
pub fn mod(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_mod(tsl_values2(a, b))
}

///|
/// `a == b`.
pub fn equal(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_equal(tsl_values2(a, b))
}

///|
/// `a != b`.
pub fn not_equal(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_not_equal(tsl_values2(a, b))
}

///|
/// `a < b`.
pub fn less_than(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_less_than(tsl_values2(a, b))
}

///|
/// `a > b`.
pub fn greater_than(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_greater_than(tsl_values2(a, b))
}

///|
/// `a <= b`.
pub fn less_than_equal(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_less_than_equal(tsl_values2(a, b))
}

///|
/// `a >= b`.
pub fn greater_than_equal(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_greater_than_equal(tsl_values2(a, b))
}

///|
/// `and( a, b )`: `a && b` (`and` is a MoonBit keyword).
pub fn and_(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_and(tsl_values2(a, b))
}

///|
/// `and( ...nodes )`.
pub fn and_of(params : Array[&IntoTsl]) -> Node {
  operator_node_and(tsl_values_of(params))
}

///|
/// `a || b`.
pub fn or(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_or(tsl_values2(a, b))
}

///|
/// `or( ...nodes )`.
pub fn or_of(params : Array[&IntoTsl]) -> Node {
  operator_node_or(tsl_values_of(params))
}

///|
/// `not( value )`: `!value`.
pub fn not_(value : &IntoTsl) -> Node {
  operator_node_not([value.to_tsl()])
}

///|
/// `a ^^ b`.
pub fn xor(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_xor(tsl_values2(a, b))
}

///|
/// `a & b`.
pub fn bit_and(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_bit_and(tsl_values2(a, b))
}

///|
/// `~a`.
pub fn bit_not(a : &IntoTsl) -> Node {
  operator_node_bit_not([a.to_tsl()])
}

///|
/// `a | b`.
pub fn bit_or(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_bit_or(tsl_values2(a, b))
}

///|
/// `a ^ b`.
pub fn bit_xor(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_bit_xor(tsl_values2(a, b))
}

///|
/// `a << b`.
pub fn shift_left(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_shift_left(tsl_values2(a, b))
}

///|
/// `a >> b`.
pub fn shift_right(a : &IntoTsl, b : &IntoTsl) -> Node {
  operator_node_shift_right(tsl_values2(a, b))
}

///|
/// The first argument of a library `Fn` body (`( [ a ] ) =>`).
fn operator_node_input(inputs : FnInputs, i : Int32) -> Node {
  match inputs.get(i) {
    Some(n) => n
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'isNode')")
  }
}

///|
/// `incrementBefore`: `++a`.
pub let increment_before : Node = module_nodes(
  "nodes/math/OperatorNode.js:incrementBefore",
  fn() {
    fn_(fn(inputs, _) {
      let a = operator_node_input(inputs, 0)
      a.add_assign(1)
      Some(a)
    })
  },
)

///|
/// `decrementBefore`: `--a`.
pub let decrement_before : Node = module_nodes(
  "nodes/math/OperatorNode.js:decrementBefore",
  fn() {
    fn_(fn(inputs, _) {
      let a = operator_node_input(inputs, 0)
      a.sub_assign(1)
      Some(a)
    })
  },
)

///|
/// `increment`: `a++`, the previous value.
pub let increment : Node = module_nodes(
  "nodes/math/OperatorNode.js:increment",
  fn() {
    fn_(fn(inputs, _) {
      let a = operator_node_input(inputs, 0)
      let temp = int(a).to_const()
      a.add_assign(1)
      Some(temp)
    })
  },
)

///|
/// `decrement`: `a--`, the previous value.
pub let decrement : Node = module_nodes(
  "nodes/math/OperatorNode.js:decrement",
  fn() {
    fn_(fn(inputs, _) {
      let a = operator_node_input(inputs, 0)
      let temp = int(a).to_const()
      a.sub_assign(1)
      Some(temp)
    })
  },
)

///|
/// `fn( ...params )` for a `Fn` called with converted values.
pub fn tsl_call(f : Node, params : Array[TslValue]) -> Node {
  f.call(params.map(fn(p) -> &IntoTsl { p }))
}

// ---------------------------------------------------------------------------
// Method chaining

///|
/// `Node.prototype[ name + 'Assign' ]` of `addMethodChaining( name, element )`: a stack
/// adds `assign( params[ 0 ], element( ...params ) )`, any other node assigns
/// `element( this, ...params )` to itself.
pub fn Node::chain_assign(
  self : Node,
  element : (Array[TslValue]) -> Node,
  params : Array[TslValue],
) -> Unit {
  match StackNode::of(self) {
    Some(stack) => {
      let target = params.get(0).unwrap_or(Undefined)
      let value = element(params)
      stack.add_to_stack(assign(target, value)) |> ignore
    }
    None => self.assign(element([Node(self), ..params]))
  }
}

///|
pub fn Node::add(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_add, [b.to_tsl()])
}

///|
/// `a.add( b, ...params )`.
pub fn Node::add_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(operator_node_add, tsl_values_of(params))
}

///|
pub fn Node::add_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_add, [b.to_tsl()])
}

///|
pub fn Node::add_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(operator_node_add, tsl_values_of(params))
}

///|
pub fn Node::sub(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_sub, [b.to_tsl()])
}

///|
pub fn Node::sub_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(operator_node_sub, tsl_values_of(params))
}

///|
pub fn Node::sub_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_sub, [b.to_tsl()])
}

///|
pub fn Node::sub_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(operator_node_sub, tsl_values_of(params))
}

///|
pub fn Node::mul(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_mul, [b.to_tsl()])
}

///|
pub fn Node::mul_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(operator_node_mul, tsl_values_of(params))
}

///|
pub fn Node::mul_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_mul, [b.to_tsl()])
}

///|
pub fn Node::mul_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(operator_node_mul, tsl_values_of(params))
}

///|
pub fn Node::div(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_div, [b.to_tsl()])
}

///|
pub fn Node::div_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(operator_node_div, tsl_values_of(params))
}

///|
pub fn Node::div_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_div, [b.to_tsl()])
}

///|
pub fn Node::div_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(operator_node_div, tsl_values_of(params))
}

///|
pub fn Node::mod(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_mod, [b.to_tsl()])
}

///|
pub fn Node::mod_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_mod, [b.to_tsl()])
}

///|
pub fn Node::equal(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_equal, [b.to_tsl()])
}

///|
pub fn Node::equal_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_equal, [b.to_tsl()])
}

///|
pub fn Node::not_equal(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_not_equal, [b.to_tsl()])
}

///|
pub fn Node::not_equal_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_not_equal, [b.to_tsl()])
}

///|
pub fn Node::less_than(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_less_than, [b.to_tsl()])
}

///|
pub fn Node::less_than_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_less_than, [b.to_tsl()])
}

///|
pub fn Node::greater_than(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_greater_than, [b.to_tsl()])
}

///|
pub fn Node::greater_than_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_greater_than, [b.to_tsl()])
}

///|
pub fn Node::less_than_equal(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_less_than_equal, [b.to_tsl()])
}

///|
pub fn Node::less_than_equal_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_less_than_equal, [b.to_tsl()])
}

///|
pub fn Node::greater_than_equal(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_greater_than_equal, [b.to_tsl()])
}

///|
pub fn Node::greater_than_equal_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_greater_than_equal, [b.to_tsl()])
}

///|
/// `a.and( b )`.
pub fn Node::and_(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_and, [b.to_tsl()])
}

///|
pub fn Node::and_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(operator_node_and, tsl_values_of(params))
}

///|
pub fn Node::and_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_and, [b.to_tsl()])
}

///|
pub fn Node::and_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(operator_node_and, tsl_values_of(params))
}

///|
pub fn Node::or(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_or, [b.to_tsl()])
}

///|
pub fn Node::or_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(operator_node_or, tsl_values_of(params))
}

///|
pub fn Node::or_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_or, [b.to_tsl()])
}

///|
pub fn Node::or_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(operator_node_or, tsl_values_of(params))
}

///|
/// `a.not()`.
pub fn Node::not_(self : Node) -> Node {
  self.chain(operator_node_not, [])
}

///|
pub fn Node::not_assign(self : Node) -> Unit {
  self.chain_assign(operator_node_not, [])
}

///|
pub fn Node::xor(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_xor, [b.to_tsl()])
}

///|
pub fn Node::xor_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_xor, [b.to_tsl()])
}

///|
pub fn Node::bit_and(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_bit_and, [b.to_tsl()])
}

///|
pub fn Node::bit_and_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_bit_and, [b.to_tsl()])
}

///|
pub fn Node::bit_not(self : Node) -> Node {
  self.chain(operator_node_bit_not, [])
}

///|
pub fn Node::bit_not_assign(self : Node) -> Unit {
  self.chain_assign(operator_node_bit_not, [])
}

///|
pub fn Node::bit_or(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_bit_or, [b.to_tsl()])
}

///|
pub fn Node::bit_or_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_bit_or, [b.to_tsl()])
}

///|
pub fn Node::bit_xor(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_bit_xor, [b.to_tsl()])
}

///|
pub fn Node::bit_xor_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_bit_xor, [b.to_tsl()])
}

///|
pub fn Node::shift_left(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_shift_left, [b.to_tsl()])
}

///|
pub fn Node::shift_left_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_shift_left, [b.to_tsl()])
}

///|
pub fn Node::shift_right(self : Node, b : &IntoTsl) -> Node {
  self.chain(operator_node_shift_right, [b.to_tsl()])
}

///|
pub fn Node::shift_right_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(operator_node_shift_right, [b.to_tsl()])
}

///|
fn operator_node_call_increment_before(p : Array[TslValue]) -> Node {
  tsl_call(increment_before, p)
}

///|
fn operator_node_call_decrement_before(p : Array[TslValue]) -> Node {
  tsl_call(decrement_before, p)
}

///|
fn operator_node_call_increment(p : Array[TslValue]) -> Node {
  tsl_call(increment, p)
}

///|
fn operator_node_call_decrement(p : Array[TslValue]) -> Node {
  tsl_call(decrement, p)
}

///|
/// `a.incrementBefore()` as a statement; `increment_before.call([a])` is the value.
pub fn Node::increment_before(self : Node) -> Unit {
  self.chain(operator_node_call_increment_before, []) |> ignore
}

///|
pub fn Node::increment_before_assign(self : Node) -> Unit {
  self.chain_assign(operator_node_call_increment_before, [])
}

///|
pub fn Node::decrement_before(self : Node) -> Unit {
  self.chain(operator_node_call_decrement_before, []) |> ignore
}

///|
pub fn Node::decrement_before_assign(self : Node) -> Unit {
  self.chain_assign(operator_node_call_decrement_before, [])
}

///|
/// `a.increment()` as a statement; `increment.call([a])` is the previous value.
pub fn Node::increment(self : Node) -> Unit {
  self.chain(operator_node_call_increment, []) |> ignore
}

///|
pub fn Node::increment_assign(self : Node) -> Unit {
  self.chain_assign(operator_node_call_increment, [])
}

///|
pub fn Node::decrement(self : Node) -> Unit {
  self.chain(operator_node_call_decrement, []) |> ignore
}

///|
pub fn Node::decrement_assign(self : Node) -> Unit {
  self.chain_assign(operator_node_call_decrement, [])
}
