// nodes/math/MathNode.js: the built-in math functions (`sin`, `dot`, `mix`, ...).
//
// The TSL functions are `nodeProxyAssignable( MathNode, method )`; `min`/`max` take any
// number of values through `min_of`/`max_of`. Chained methods and their assign forms
// are `Node` methods, as `addMethodChaining` registers them (`step`, `mix` and
// `smoothstep` chain the `*Element` forms, which put `this` last).

///|
/// One of the math methods, applied to up to three inputs.
pub(all) struct MathNode {
  mut method_ : String
  mut a_node : Node
  mut b_node : Node?
  mut c_node : Node?
}

///|
pub impl NodeClass for MathNode with fn class_name(_) {
  "MathNode"
}

///|
pub impl NodeClass for MathNode with fn has_flag(_, flag) {
  flag == "isMathNode"
}

///|
pub impl NodeClass for MathNode with fn children(self, _, out) {
  push_child(out, "aNode", Some(self.a_node))
  push_child(out, "bNode", self.b_node)
  push_child(out, "cNode", self.c_node)
}

///|
pub impl NodeClass for MathNode with fn generate_uses_output(_) {
  true
}

///|
/// Methods that are only defined for floating-point types.
let _math_node_float_methods : Array[String] = [
  "radians", "degrees", "exp", "exp2", "log", "log2", "sqrt", "inversesqrt", "floor",
  "ceil", "normalize", "fract", "sin", "sinh", "cos", "cosh", "tan", "tanh", "asin",
  "asinh", "acos", "acosh", "atan", "atanh", "length", "dFdx", "dFdy", "round", "trunc",
  "fwidth", "reciprocal", "step", "reflect", "distance", "dot", "cross", "pow", "mix",
  "refract", "smoothstep", "faceforward",
]

///|
/// `getInputType( builder )`: the longest input type, with the promoted component type
/// (`float` for float-only methods).
pub fn MathNode::get_input_type(
  self : MathNode,
  builder : NodeBuilder,
) -> String? {
  let a_type = self.a_node.get_node_type(builder)
  let b_type = match self.b_node {
    Some(b) => b.get_node_type(builder)
    None => None
  }
  let c_type = match self.c_node {
    Some(c) => c.get_node_type(builder)
    None => None
  }
  let a_len = if builder.is_matrix(a_type) {
    0
  } else {
    builder.get_type_length(a_type)
  }
  let b_len = if builder.is_matrix(b_type) {
    0
  } else {
    builder.get_type_length(b_type)
  }
  let c_len = if builder.is_matrix(c_type) {
    0
  } else {
    builder.get_type_length(c_type)
  }
  let type_ = if a_len > b_len && a_len > c_len {
    a_type
  } else if b_len > c_len {
    b_type
  } else if c_len > a_len {
    c_type
  } else {
    a_type
  }
  if builder.is_matrix(type_) {
    return type_
  }
  let promoted_type = if _math_node_float_methods.contains(self.method_) {
    "float"
  } else {
    builder.get_promoted_component_type([
      Some(self.a_node),
      self.b_node,
      self.c_node,
    ])
  }
  Some(builder.change_component_type(operator_node_str(type_), promoted_type))
}

///|
pub impl NodeClass for MathNode with fn generate_node_type(self, _, builder, _) {
  let method_ = self.method_
  if method_ is ("length" | "distance" | "dot" | "determinant") {
    Some("float")
  } else if method_ == "cross" {
    Some("vec3")
  } else if method_ is ("all" | "any") {
    Some("bool")
  } else if method_ == "equals" {
    Some(
      builder.change_component_type(
        operator_node_str(self.a_node.get_node_type(builder)),
        "bool",
      ),
    )
  } else {
    self.get_input_type(builder)
  }
}

///|
pub impl NodeClass for MathNode with fn setup(self, node, builder) {
  let a_node = self.a_node
  let b_node = self.b_node
  let method_ = self.method_
  let mut output_node : Node? = None
  if method_ == "oneMinus" {
    output_node = Some(sub(1.0, a_node))
  } else if method_ == "reciprocal" {
    output_node = Some(div(float(1), a_node))
  } else if method_ == "difference" {
    output_node = Some(abs(sub(a_node, b_node)))
  } else if method_ == "transformDirection" {
    // pre-multiplies the direction by the matrix and normalizes the result
    let (matrix_node, direction_node) = if builder.is_matrix(
        a_node.get_node_type(builder),
      ) {
      (Some(a_node), b_node)
    } else {
      (b_node, Some(a_node))
    }
    output_node = Some(
      normalize(mul(matrix_node, vec4_of([vec3(direction_node), 0.0])).xyz()),
    )
  }
  match output_node {
    Some(_) => output_node
    None => node.setup_base(builder)
  }
}

///|
fn math_node_required(node : Node?) -> Node {
  match node {
    Some(n) => n
    None => abort("TypeError: Cannot read properties of null (reading 'build')")
  }
}

///|
pub impl NodeClass for MathNode with fn generate(self, node, builder, output) {
  let properties = builder.get_node_properties(node)
  if properties.get_node("outputNode") is Some(_) {
    return node.generate_base(builder, output)
  }
  let mut method_ = self.method_
  let type_ = node.get_node_type(builder)
  let input_type = self.get_input_type(builder)
  let a = self.a_node
  let b = self.b_node
  let c = self.c_node
  let coordinate_system = builder.renderer.coordinate_system()
  if method_ == "negate" {
    return Some(
      builder.format(
        "( - " + a.build(builder, output?=input_type) + " )",
        type_,
        output,
      ),
    )
  }
  let params : Array[String] = []
  if method_ == "cross" {
    params.push(a.build(builder, output?=type_))
    params.push(math_node_required(b).build(builder, output?=type_))
  } else if coordinate_system == @core.WebGLCoordinateSystem &&
    method_ == "step" {
    let a_output = if builder.get_type_length(a.get_node_type(builder)) == 1 {
      Some("float")
    } else {
      input_type
    }
    params.push(a.build(builder, output?=a_output))
    params.push(math_node_required(b).build(builder, output?=input_type))
  } else if coordinate_system == @core.WebGLCoordinateSystem &&
    method_ is ("min" | "max") {
    params.push(a.build(builder, output?=input_type))
    let b = math_node_required(b)
    let b_output = if builder.get_type_length(b.get_node_type(builder)) == 1 {
      builder.get_component_type(input_type)
    } else {
      input_type
    }
    params.push(b.build(builder, output?=b_output))
  } else if method_ == "refract" {
    params.push(a.build(builder, output?=input_type))
    params.push(math_node_required(b).build(builder, output?=input_type))
    params.push(math_node_required(c).build(builder, output="float"))
  } else if method_ == "mix" {
    params.push(a.build(builder, output?=input_type))
    params.push(math_node_required(b).build(builder, output?=input_type))
    let c = math_node_required(c)
    let c_output = if builder.get_type_length(c.get_node_type(builder)) == 1 {
      Some("float")
    } else {
      input_type
    }
    params.push(c.build(builder, output?=c_output))
  } else {
    if coordinate_system == @core.WebGPUCoordinateSystem &&
      method_ == "atan" &&
      b is Some(_) {
      method_ = "atan2"
    }
    if builder.shader_stage != Some("fragment") && method_ is ("dFdx" | "dFdy") {
      @core.error(
        "TSL: '\{method_}' is not supported in the \{operator_node_str(builder.shader_stage)} stage.",
      )
      method_ = "/*" + method_ + "*/"
    }
    params.push(a.build(builder, output?=input_type))
    if b is Some(b) {
      params.push(b.build(builder, output?=input_type))
    }
    if c is Some(c) {
      params.push(c.build(builder, output?=input_type))
    }
  }
  let joined = params.join(", ")
  Some(
    builder.format(
      "\{builder.get_method(method_, output?=type_)}( \{joined} )",
      type_,
      output,
    ),
  )
}

///|
pub impl NodeClass for MathNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("method", @core.JsValue::of(self.method_))
}

///|
pub impl NodeClass for MathNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self.method_ = @webgl.js_to_string(data.get("method"))
}

///|
/// The constructor body: `super()` has run in `Node::alloc`. `max`/`min` with more than
/// two values nest left to right.
pub fn MathNode::construct(
  _node : Node,
  method_ : String,
  a_node : Node,
  b_node : Node?,
  c_node : Node?,
  params : Array[Node],
) -> MathNode {
  let mut a_node = a_node
  let mut b_node = b_node
  let mut c_node = c_node
  // Allow the max() and min() functions to take an arbitrary number of arguments.
  if method_ is ("max" | "min") && c_node is Some(c) {
    let args = [c, ..params]
    let mut final_op = MathNode::new(method_, a_node, b_node?)
    for i in 0..<(args.length() - 1) {
      final_op = MathNode::new(method_, final_op, b_node=args[i])
    }
    a_node = final_op
    b_node = Some(args[args.length() - 1])
    c_node = None
  }
  { method_, a_node, b_node, c_node, }
}

///|
/// `new MathNode( method, aNode, bNode = null, cNode = null, ...params )`.
pub fn MathNode::new(
  method_ : String,
  a_node : Node,
  b_node? : Node,
  c_node? : Node,
  params~ : Array[Node] = [],
) -> Node {
  let node = Node::alloc()
  node.set_class(
    MathNode::construct(node, method_, a_node, b_node, c_node, params),
  )
}

///|
pub fn MathNode::of(node : Node) -> MathNode? {
  match node.class_payload("MathNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

// ---------------------------------------------------------------------------
// TSL

///|
/// `nodeProxyAssignable( MathNode, method ).setParameterLength( min, max )`.
fn math_node_proxy(
  method_ : String,
  min : Int32,
  max : Int32,
  params : Array[TslValue],
) -> Node {
  let params = tsl_verify_params(method_, params, min, max)
  let nodes = params.map(tsl_proxy_arg)
  let a_node = operator_node_required(nodes.get(0).unwrap_or(None))
  let b_node = nodes.get(1).unwrap_or(None)
  let c_node = nodes.get(2).unwrap_or(None)
  let rest = if nodes.length() > 3 {
    nodes[3:].to_owned().map(operator_node_required)
  } else {
    []
  }
  MathNode::new(method_, a_node, b_node?, c_node?, params=rest).to_assignable()
}

///|
let math_node_pi : Double = 3.141592653589793

///|
/// `EPSILON`: a small value for floating-point precision errors.
pub let epsilon : Node = module_nodes("nodes/math/MathNode.js:EPSILON", fn() {
  float(1.0e-6)
})

///|
/// `INFINITY`.
pub let infinity : Node = module_nodes("nodes/math/MathNode.js:INFINITY", fn() {
  float(1.0e6)
})

///|
/// `PI`.
pub let pi : Node = module_nodes("nodes/math/MathNode.js:PI", fn() {
  float(math_node_pi)
})

///|
/// `TWO_PI`.
pub let two_pi : Node = module_nodes("nodes/math/MathNode.js:TWO_PI", fn() {
  float(math_node_pi * 2.0)
})

///|
/// `HALF_PI`.
pub let half_pi : Node = module_nodes("nodes/math/MathNode.js:HALF_PI", fn() {
  float(math_node_pi * 0.5)
})

///|
fn math_node_atan(p : Array[TslValue]) -> Node {
  math_node_proxy("atan", 1, 2, p)
}

///|
/// `atan( y, x )`: the arc tangent, `atan2( y, x )` with two values.
pub fn atan(y : &IntoTsl, x? : &IntoTsl) -> Node {
  match x {
    Some(x) => math_node_atan([y.to_tsl(), x.to_tsl()])
    None => math_node_atan([y.to_tsl()])
  }
}

///|
pub fn Node::atan(self : Node, x? : &IntoTsl) -> Node {
  match x {
    Some(x) => self.chain(math_node_atan, [x.to_tsl()])
    None => self.chain(math_node_atan, [])
  }
}

///|
pub fn Node::atan_assign(self : Node, x? : &IntoTsl) -> Unit {
  match x {
    Some(x) => self.chain_assign(math_node_atan, [x.to_tsl()])
    None => self.chain_assign(math_node_atan, [])
  }
}

///|
fn math_node_min(p : Array[TslValue]) -> Node {
  math_node_proxy("min", 2, -1, p)
}

///|
fn math_node_max(p : Array[TslValue]) -> Node {
  math_node_proxy("max", 2, -1, p)
}

///|
/// The least of two values.
pub fn min(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_min([a.to_tsl(), b.to_tsl()])
}

///|
/// `min( ...values )`.
pub fn min_of(values : Array[&IntoTsl]) -> Node {
  math_node_min(tsl_values_of(values))
}

///|
/// The greatest of two values.
pub fn max(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_max([a.to_tsl(), b.to_tsl()])
}

///|
/// `max( ...values )`.
pub fn max_of(values : Array[&IntoTsl]) -> Node {
  math_node_max(tsl_values_of(values))
}

///|
fn math_node_arg(p : Array[TslValue], i : Int32) -> TslValue {
  p.get(i).unwrap_or(Undefined)
}

///|
fn math_node_pow2(p : Array[TslValue]) -> Node {
  let x = math_node_arg(p, 0)
  operator_node_mul([x, x])
}

///|
fn math_node_pow3(p : Array[TslValue]) -> Node {
  let x = math_node_arg(p, 0)
  operator_node_mul([x, x, x])
}

///|
fn math_node_pow4(p : Array[TslValue]) -> Node {
  let x = math_node_arg(p, 0)
  operator_node_mul([x, x, x, x])
}

///|
/// `x * x`.
pub fn pow2(x : &IntoTsl) -> Node {
  math_node_pow2([x.to_tsl()])
}

///|
/// `x * x * x`.
pub fn pow3(x : &IntoTsl) -> Node {
  math_node_pow3([x.to_tsl()])
}

///|
/// `x * x * x * x`.
pub fn pow4(x : &IntoTsl) -> Node {
  math_node_pow4([x.to_tsl()])
}

///|
fn math_node_transform_normal_by_view_matrix(p : Array[TslValue]) -> Node {
  let normal = math_node_arg(p, 0)
  let view_matrix = math_node_arg(p, 1)
  normalize(mul(view_matrix, vec4_of([vec3(normal), 0.0])).xyz())
}

///|
fn math_node_transform_normal_by_inverse_view_matrix(
  p : Array[TslValue],
) -> Node {
  let normal = math_node_arg(p, 0)
  let view_matrix = math_node_arg(p, 1)
  normalize(vec4_of([vec3(normal), 0.0]).mul(view_matrix).xyz())
}

///|
/// The normal (world space) transformed by an orthonormal view matrix, normalized.
pub fn transform_normal_by_view_matrix(
  normal : &IntoTsl,
  view_matrix : &IntoTsl,
) -> Node {
  math_node_transform_normal_by_view_matrix([
    normal.to_tsl(),
    view_matrix.to_tsl(),
  ])
}

///|
/// The normal (view space) transformed by the inverse view matrix, normalized.
pub fn transform_normal_by_inverse_view_matrix(
  normal : &IntoTsl,
  view_matrix : &IntoTsl,
) -> Node {
  math_node_transform_normal_by_inverse_view_matrix([
    normal.to_tsl(),
    view_matrix.to_tsl(),
  ])
}

///|
fn math_node_cbrt(p : Array[TslValue]) -> Node {
  let a = math_node_arg(p, 0)
  mul(sign(a), pow(abs(a), 1.0 / 3.0))
}

///|
/// The cube root.
pub fn cbrt(a : &IntoTsl) -> Node {
  math_node_cbrt([a.to_tsl()])
}

///|
fn math_node_length_sq(p : Array[TslValue]) -> Node {
  let a = math_node_arg(p, 0)
  dot(a, a)
}

///|
/// The squared length of a vector.
pub fn length_sq(a : &IntoTsl) -> Node {
  math_node_length_sq([a.to_tsl()])
}

///|
fn math_node_clamp(p : Array[TslValue]) -> Node {
  let value = math_node_arg(p, 0)
  let low = match math_node_arg(p, 1) {
    Undefined => TslValue::Number(0.0)
    v => v
  }
  let high = match math_node_arg(p, 2) {
    Undefined => TslValue::Number(1.0)
    v => v
  }
  let value = node_object_value(value)
  let low = node_object_value(low)
  let high = node_object_value(high)
  MathNode::new(
    "clamp",
    operator_node_required(tsl_proxy_arg(value)),
    b_node?=tsl_proxy_arg(low),
    c_node?=tsl_proxy_arg(high),
  )
}

///|
/// `clamp( value, low = 0, high = 1 )`.
pub fn clamp(value : &IntoTsl, low? : &IntoTsl, high? : &IntoTsl) -> Node {
  math_node_clamp(math_node_optional_params([Some(value), low, high]))
}

///|
/// The provided arguments, `undefined` for skipped ones before the last given.
fn math_node_optional_params(params : Array[&IntoTsl?]) -> Array[TslValue] {
  let mut last = -1
  for i, p in params {
    if p is Some(_) {
      last = i
    }
  }
  let out = []
  for i in 0..<=last {
    out.push(
      match params[i] {
        Some(p) => p.to_tsl()
        None => Undefined
      },
    )
  }
  out
}

///|
pub fn Node::clamp(self : Node, low? : &IntoTsl, high? : &IntoTsl) -> Node {
  self.chain(math_node_clamp, math_node_optional_params([low, high]))
}

///|
pub fn Node::clamp_assign(
  self : Node,
  low? : &IntoTsl,
  high? : &IntoTsl,
) -> Unit {
  self.chain_assign(math_node_clamp, math_node_optional_params([low, high]))
}

///|
fn math_node_saturate(p : Array[TslValue]) -> Node {
  math_node_clamp([math_node_arg(p, 0)])
}

///|
/// `clamp( value, 0, 1 )`.
pub fn saturate(value : &IntoTsl) -> Node {
  math_node_saturate([value.to_tsl()])
}

///|
/// `rand( uv )`: a pseudo-random value for the given uv.
pub let rand : Node = module_nodes("nodes/math/MathNode.js:rand", fn() {
  fn_(
    fn(inputs, _) {
      let uv = operator_node_input(inputs, 0)
      let a = 12.9898
      let b = 78.233
      let c = 43758.5453
      let dt = dot(uv.xy(), vec2_of([a, b]))
      let sn = mod(dt, pi)
      Some(fract(sin(sn).mul(c)))
    },
    layout=FnLayout::short(
      [("uv", "vec2")],
      return_="float",
      upstream="nodes/math/MathNode.js:rand",
    ),
  )
})

///|
fn math_node_rand(p : Array[TslValue]) -> Node {
  tsl_call(rand, p)
}

///|
fn math_node_mix_element(p : Array[TslValue]) -> Node {
  math_node_mix([math_node_arg(p, 1), math_node_arg(p, 2), math_node_arg(p, 0)])
}

///|
fn math_node_smoothstep_element(p : Array[TslValue]) -> Node {
  math_node_smoothstep([
    math_node_arg(p, 1),
    math_node_arg(p, 2),
    math_node_arg(p, 0),
  ])
}

///|
fn math_node_step_element(p : Array[TslValue]) -> Node {
  math_node_step([math_node_arg(p, 1), math_node_arg(p, 0)])
}

///|
/// `mixElement( t, e1, e2 )`: `mix( e1, e2, t )`.
pub fn mix_element(t : &IntoTsl, e1 : &IntoTsl, e2 : &IntoTsl) -> Node {
  math_node_mix_element([t.to_tsl(), e1.to_tsl(), e2.to_tsl()])
}

///|
/// `smoothstepElement( x, low, high )`: `smoothstep( low, high, x )`.
pub fn smoothstep_element(
  x : &IntoTsl,
  low : &IntoTsl,
  high : &IntoTsl,
) -> Node {
  math_node_smoothstep_element([x.to_tsl(), low.to_tsl(), high.to_tsl()])
}

///|
/// `stepElement( x, edge )`: `step( edge, x )`.
pub fn step_element(x : &IntoTsl, edge : &IntoTsl) -> Node {
  math_node_step_element([x.to_tsl(), edge.to_tsl()])
}

///|
/// The GLSL alias of `inverseSqrt`.
pub fn inversesqrt(x : &IntoTsl) -> Node {
  inverse_sqrt(x)
}

///|
/// The GLSL alias of `faceForward`.
pub fn faceforward(n : &IntoTsl, i : &IntoTsl, nref : &IntoTsl) -> Node {
  face_forward(n, i, nref)
}

// ---------------------------------------------------------------------------
// Generated: the proxies and the chained methods.

///|
fn math_node_all(p : Array[TslValue]) -> Node {
  math_node_proxy("all", 1, 1, p)
}

///|
pub fn all(x : &IntoTsl) -> Node {
  math_node_all([x.to_tsl()])
}

///|
fn math_node_any(p : Array[TslValue]) -> Node {
  math_node_proxy("any", 1, 1, p)
}

///|
pub fn any(x : &IntoTsl) -> Node {
  math_node_any([x.to_tsl()])
}

///|
fn math_node_radians(p : Array[TslValue]) -> Node {
  math_node_proxy("radians", 1, 1, p)
}

///|
pub fn radians(x : &IntoTsl) -> Node {
  math_node_radians([x.to_tsl()])
}

///|
fn math_node_degrees(p : Array[TslValue]) -> Node {
  math_node_proxy("degrees", 1, 1, p)
}

///|
pub fn degrees(x : &IntoTsl) -> Node {
  math_node_degrees([x.to_tsl()])
}

///|
fn math_node_exp(p : Array[TslValue]) -> Node {
  math_node_proxy("exp", 1, 1, p)
}

///|
pub fn exp(x : &IntoTsl) -> Node {
  math_node_exp([x.to_tsl()])
}

///|
fn math_node_exp2(p : Array[TslValue]) -> Node {
  math_node_proxy("exp2", 1, 1, p)
}

///|
pub fn exp2(x : &IntoTsl) -> Node {
  math_node_exp2([x.to_tsl()])
}

///|
fn math_node_log(p : Array[TslValue]) -> Node {
  math_node_proxy("log", 1, 1, p)
}

///|
pub fn log(x : &IntoTsl) -> Node {
  math_node_log([x.to_tsl()])
}

///|
fn math_node_log2(p : Array[TslValue]) -> Node {
  math_node_proxy("log2", 1, 1, p)
}

///|
pub fn log2(x : &IntoTsl) -> Node {
  math_node_log2([x.to_tsl()])
}

///|
fn math_node_sqrt(p : Array[TslValue]) -> Node {
  math_node_proxy("sqrt", 1, 1, p)
}

///|
pub fn sqrt(x : &IntoTsl) -> Node {
  math_node_sqrt([x.to_tsl()])
}

///|
fn math_node_inverse_sqrt(p : Array[TslValue]) -> Node {
  math_node_proxy("inversesqrt", 1, 1, p)
}

///|
pub fn inverse_sqrt(x : &IntoTsl) -> Node {
  math_node_inverse_sqrt([x.to_tsl()])
}

///|
fn math_node_floor(p : Array[TslValue]) -> Node {
  math_node_proxy("floor", 1, 1, p)
}

///|
pub fn floor(x : &IntoTsl) -> Node {
  math_node_floor([x.to_tsl()])
}

///|
fn math_node_ceil(p : Array[TslValue]) -> Node {
  math_node_proxy("ceil", 1, 1, p)
}

///|
pub fn ceil(x : &IntoTsl) -> Node {
  math_node_ceil([x.to_tsl()])
}

///|
fn math_node_normalize(p : Array[TslValue]) -> Node {
  math_node_proxy("normalize", 1, 1, p)
}

///|
pub fn normalize(x : &IntoTsl) -> Node {
  math_node_normalize([x.to_tsl()])
}

///|
fn math_node_fract(p : Array[TslValue]) -> Node {
  math_node_proxy("fract", 1, 1, p)
}

///|
pub fn fract(x : &IntoTsl) -> Node {
  math_node_fract([x.to_tsl()])
}

///|
fn math_node_sin(p : Array[TslValue]) -> Node {
  math_node_proxy("sin", 1, 1, p)
}

///|
pub fn sin(x : &IntoTsl) -> Node {
  math_node_sin([x.to_tsl()])
}

///|
fn math_node_sinh(p : Array[TslValue]) -> Node {
  math_node_proxy("sinh", 1, 1, p)
}

///|
pub fn sinh(x : &IntoTsl) -> Node {
  math_node_sinh([x.to_tsl()])
}

///|
fn math_node_cos(p : Array[TslValue]) -> Node {
  math_node_proxy("cos", 1, 1, p)
}

///|
pub fn cos(x : &IntoTsl) -> Node {
  math_node_cos([x.to_tsl()])
}

///|
fn math_node_cosh(p : Array[TslValue]) -> Node {
  math_node_proxy("cosh", 1, 1, p)
}

///|
pub fn cosh(x : &IntoTsl) -> Node {
  math_node_cosh([x.to_tsl()])
}

///|
fn math_node_tan(p : Array[TslValue]) -> Node {
  math_node_proxy("tan", 1, 1, p)
}

///|
pub fn tan(x : &IntoTsl) -> Node {
  math_node_tan([x.to_tsl()])
}

///|
fn math_node_tanh(p : Array[TslValue]) -> Node {
  math_node_proxy("tanh", 1, 1, p)
}

///|
pub fn tanh(x : &IntoTsl) -> Node {
  math_node_tanh([x.to_tsl()])
}

///|
fn math_node_asin(p : Array[TslValue]) -> Node {
  math_node_proxy("asin", 1, 1, p)
}

///|
pub fn asin(x : &IntoTsl) -> Node {
  math_node_asin([x.to_tsl()])
}

///|
fn math_node_asinh(p : Array[TslValue]) -> Node {
  math_node_proxy("asinh", 1, 1, p)
}

///|
pub fn asinh(x : &IntoTsl) -> Node {
  math_node_asinh([x.to_tsl()])
}

///|
fn math_node_acos(p : Array[TslValue]) -> Node {
  math_node_proxy("acos", 1, 1, p)
}

///|
pub fn acos(x : &IntoTsl) -> Node {
  math_node_acos([x.to_tsl()])
}

///|
fn math_node_acosh(p : Array[TslValue]) -> Node {
  math_node_proxy("acosh", 1, 1, p)
}

///|
pub fn acosh(x : &IntoTsl) -> Node {
  math_node_acosh([x.to_tsl()])
}

///|
fn math_node_atanh(p : Array[TslValue]) -> Node {
  math_node_proxy("atanh", 1, 1, p)
}

///|
pub fn atanh(x : &IntoTsl) -> Node {
  math_node_atanh([x.to_tsl()])
}

///|
fn math_node_abs(p : Array[TslValue]) -> Node {
  math_node_proxy("abs", 1, 1, p)
}

///|
pub fn abs(x : &IntoTsl) -> Node {
  math_node_abs([x.to_tsl()])
}

///|
fn math_node_sign(p : Array[TslValue]) -> Node {
  math_node_proxy("sign", 1, 1, p)
}

///|
pub fn sign(x : &IntoTsl) -> Node {
  math_node_sign([x.to_tsl()])
}

///|
fn math_node_length(p : Array[TslValue]) -> Node {
  math_node_proxy("length", 1, 1, p)
}

///|
pub fn length(x : &IntoTsl) -> Node {
  math_node_length([x.to_tsl()])
}

///|
fn math_node_negate(p : Array[TslValue]) -> Node {
  math_node_proxy("negate", 1, 1, p)
}

///|
pub fn negate(x : &IntoTsl) -> Node {
  math_node_negate([x.to_tsl()])
}

///|
fn math_node_one_minus(p : Array[TslValue]) -> Node {
  math_node_proxy("oneMinus", 1, 1, p)
}

///|
pub fn one_minus(x : &IntoTsl) -> Node {
  math_node_one_minus([x.to_tsl()])
}

///|
fn math_node_d_fdx(p : Array[TslValue]) -> Node {
  math_node_proxy("dFdx", 1, 1, p)
}

///|
pub fn d_fdx(x : &IntoTsl) -> Node {
  math_node_d_fdx([x.to_tsl()])
}

///|
fn math_node_d_fdy(p : Array[TslValue]) -> Node {
  math_node_proxy("dFdy", 1, 1, p)
}

///|
pub fn d_fdy(x : &IntoTsl) -> Node {
  math_node_d_fdy([x.to_tsl()])
}

///|
fn math_node_round(p : Array[TslValue]) -> Node {
  math_node_proxy("round", 1, 1, p)
}

///|
pub fn round(x : &IntoTsl) -> Node {
  math_node_round([x.to_tsl()])
}

///|
fn math_node_reciprocal(p : Array[TslValue]) -> Node {
  math_node_proxy("reciprocal", 1, 1, p)
}

///|
pub fn reciprocal(x : &IntoTsl) -> Node {
  math_node_reciprocal([x.to_tsl()])
}

///|
fn math_node_trunc(p : Array[TslValue]) -> Node {
  math_node_proxy("trunc", 1, 1, p)
}

///|
pub fn trunc(x : &IntoTsl) -> Node {
  math_node_trunc([x.to_tsl()])
}

///|
fn math_node_fwidth(p : Array[TslValue]) -> Node {
  math_node_proxy("fwidth", 1, 1, p)
}

///|
pub fn fwidth(x : &IntoTsl) -> Node {
  math_node_fwidth([x.to_tsl()])
}

///|
fn math_node_transpose(p : Array[TslValue]) -> Node {
  math_node_proxy("transpose", 1, 1, p)
}

///|
pub fn transpose(x : &IntoTsl) -> Node {
  math_node_transpose([x.to_tsl()])
}

///|
fn math_node_determinant(p : Array[TslValue]) -> Node {
  math_node_proxy("determinant", 1, 1, p)
}

///|
pub fn determinant(x : &IntoTsl) -> Node {
  math_node_determinant([x.to_tsl()])
}

///|
fn math_node_inverse(p : Array[TslValue]) -> Node {
  math_node_proxy("inverse", 1, 1, p)
}

///|
pub fn inverse(x : &IntoTsl) -> Node {
  math_node_inverse([x.to_tsl()])
}

///|
fn math_node_step(p : Array[TslValue]) -> Node {
  math_node_proxy("step", 2, 2, p)
}

///|
pub fn step(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_step([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_reflect(p : Array[TslValue]) -> Node {
  math_node_proxy("reflect", 2, 2, p)
}

///|
pub fn reflect(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_reflect([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_distance(p : Array[TslValue]) -> Node {
  math_node_proxy("distance", 2, 2, p)
}

///|
pub fn distance(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_distance([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_difference(p : Array[TslValue]) -> Node {
  math_node_proxy("difference", 2, 2, p)
}

///|
pub fn difference(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_difference([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_dot(p : Array[TslValue]) -> Node {
  math_node_proxy("dot", 2, 2, p)
}

///|
pub fn dot(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_dot([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_cross(p : Array[TslValue]) -> Node {
  math_node_proxy("cross", 2, 2, p)
}

///|
pub fn cross(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_cross([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_pow(p : Array[TslValue]) -> Node {
  math_node_proxy("pow", 2, 2, p)
}

///|
pub fn pow(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_pow([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_transform_direction(p : Array[TslValue]) -> Node {
  math_node_proxy("transformDirection", 2, 2, p)
}

///|
pub fn transform_direction(a : &IntoTsl, b : &IntoTsl) -> Node {
  math_node_transform_direction([a.to_tsl(), b.to_tsl()])
}

///|
fn math_node_mix(p : Array[TslValue]) -> Node {
  math_node_proxy("mix", 3, 3, p)
}

///|
pub fn mix(a : &IntoTsl, b : &IntoTsl, c : &IntoTsl) -> Node {
  math_node_mix([a.to_tsl(), b.to_tsl(), c.to_tsl()])
}

///|
fn math_node_refract(p : Array[TslValue]) -> Node {
  math_node_proxy("refract", 3, 3, p)
}

///|
pub fn refract(a : &IntoTsl, b : &IntoTsl, c : &IntoTsl) -> Node {
  math_node_refract([a.to_tsl(), b.to_tsl(), c.to_tsl()])
}

///|
fn math_node_smoothstep(p : Array[TslValue]) -> Node {
  math_node_proxy("smoothstep", 3, 3, p)
}

///|
pub fn smoothstep(a : &IntoTsl, b : &IntoTsl, c : &IntoTsl) -> Node {
  math_node_smoothstep([a.to_tsl(), b.to_tsl(), c.to_tsl()])
}

///|
fn math_node_face_forward(p : Array[TslValue]) -> Node {
  math_node_proxy("faceforward", 3, 3, p)
}

///|
pub fn face_forward(a : &IntoTsl, b : &IntoTsl, c : &IntoTsl) -> Node {
  math_node_face_forward([a.to_tsl(), b.to_tsl(), c.to_tsl()])
}

///|
pub fn Node::all(self : Node) -> Node {
  self.chain(math_node_all, [])
}

///|
pub fn Node::all_assign(self : Node) -> Unit {
  self.chain_assign(math_node_all, [])
}

///|
pub fn Node::any(self : Node) -> Node {
  self.chain(math_node_any, [])
}

///|
pub fn Node::any_assign(self : Node) -> Unit {
  self.chain_assign(math_node_any, [])
}

///|
pub fn Node::radians(self : Node) -> Node {
  self.chain(math_node_radians, [])
}

///|
pub fn Node::radians_assign(self : Node) -> Unit {
  self.chain_assign(math_node_radians, [])
}

///|
pub fn Node::degrees(self : Node) -> Node {
  self.chain(math_node_degrees, [])
}

///|
pub fn Node::degrees_assign(self : Node) -> Unit {
  self.chain_assign(math_node_degrees, [])
}

///|
pub fn Node::exp(self : Node) -> Node {
  self.chain(math_node_exp, [])
}

///|
pub fn Node::exp_assign(self : Node) -> Unit {
  self.chain_assign(math_node_exp, [])
}

///|
pub fn Node::exp2(self : Node) -> Node {
  self.chain(math_node_exp2, [])
}

///|
pub fn Node::exp2_assign(self : Node) -> Unit {
  self.chain_assign(math_node_exp2, [])
}

///|
pub fn Node::log(self : Node) -> Node {
  self.chain(math_node_log, [])
}

///|
pub fn Node::log_assign(self : Node) -> Unit {
  self.chain_assign(math_node_log, [])
}

///|
pub fn Node::log2(self : Node) -> Node {
  self.chain(math_node_log2, [])
}

///|
pub fn Node::log2_assign(self : Node) -> Unit {
  self.chain_assign(math_node_log2, [])
}

///|
pub fn Node::sqrt(self : Node) -> Node {
  self.chain(math_node_sqrt, [])
}

///|
pub fn Node::sqrt_assign(self : Node) -> Unit {
  self.chain_assign(math_node_sqrt, [])
}

///|
pub fn Node::inverse_sqrt(self : Node) -> Node {
  self.chain(math_node_inverse_sqrt, [])
}

///|
pub fn Node::inverse_sqrt_assign(self : Node) -> Unit {
  self.chain_assign(math_node_inverse_sqrt, [])
}

///|
pub fn Node::floor(self : Node) -> Node {
  self.chain(math_node_floor, [])
}

///|
pub fn Node::floor_assign(self : Node) -> Unit {
  self.chain_assign(math_node_floor, [])
}

///|
pub fn Node::ceil(self : Node) -> Node {
  self.chain(math_node_ceil, [])
}

///|
pub fn Node::ceil_assign(self : Node) -> Unit {
  self.chain_assign(math_node_ceil, [])
}

///|
pub fn Node::normalize(self : Node) -> Node {
  self.chain(math_node_normalize, [])
}

///|
pub fn Node::normalize_assign(self : Node) -> Unit {
  self.chain_assign(math_node_normalize, [])
}

///|
pub fn Node::fract(self : Node) -> Node {
  self.chain(math_node_fract, [])
}

///|
pub fn Node::fract_assign(self : Node) -> Unit {
  self.chain_assign(math_node_fract, [])
}

///|
pub fn Node::sin(self : Node) -> Node {
  self.chain(math_node_sin, [])
}

///|
pub fn Node::sin_assign(self : Node) -> Unit {
  self.chain_assign(math_node_sin, [])
}

///|
pub fn Node::sinh(self : Node) -> Node {
  self.chain(math_node_sinh, [])
}

///|
pub fn Node::sinh_assign(self : Node) -> Unit {
  self.chain_assign(math_node_sinh, [])
}

///|
pub fn Node::cos(self : Node) -> Node {
  self.chain(math_node_cos, [])
}

///|
pub fn Node::cos_assign(self : Node) -> Unit {
  self.chain_assign(math_node_cos, [])
}

///|
pub fn Node::cosh(self : Node) -> Node {
  self.chain(math_node_cosh, [])
}

///|
pub fn Node::cosh_assign(self : Node) -> Unit {
  self.chain_assign(math_node_cosh, [])
}

///|
pub fn Node::tan(self : Node) -> Node {
  self.chain(math_node_tan, [])
}

///|
pub fn Node::tan_assign(self : Node) -> Unit {
  self.chain_assign(math_node_tan, [])
}

///|
pub fn Node::tanh(self : Node) -> Node {
  self.chain(math_node_tanh, [])
}

///|
pub fn Node::tanh_assign(self : Node) -> Unit {
  self.chain_assign(math_node_tanh, [])
}

///|
pub fn Node::asin(self : Node) -> Node {
  self.chain(math_node_asin, [])
}

///|
pub fn Node::asin_assign(self : Node) -> Unit {
  self.chain_assign(math_node_asin, [])
}

///|
pub fn Node::asinh(self : Node) -> Node {
  self.chain(math_node_asinh, [])
}

///|
pub fn Node::asinh_assign(self : Node) -> Unit {
  self.chain_assign(math_node_asinh, [])
}

///|
pub fn Node::acos(self : Node) -> Node {
  self.chain(math_node_acos, [])
}

///|
pub fn Node::acos_assign(self : Node) -> Unit {
  self.chain_assign(math_node_acos, [])
}

///|
pub fn Node::acosh(self : Node) -> Node {
  self.chain(math_node_acosh, [])
}

///|
pub fn Node::acosh_assign(self : Node) -> Unit {
  self.chain_assign(math_node_acosh, [])
}

///|
pub fn Node::atanh(self : Node) -> Node {
  self.chain(math_node_atanh, [])
}

///|
pub fn Node::atanh_assign(self : Node) -> Unit {
  self.chain_assign(math_node_atanh, [])
}

///|
pub fn Node::abs(self : Node) -> Node {
  self.chain(math_node_abs, [])
}

///|
pub fn Node::abs_assign(self : Node) -> Unit {
  self.chain_assign(math_node_abs, [])
}

///|
pub fn Node::sign(self : Node) -> Node {
  self.chain(math_node_sign, [])
}

///|
pub fn Node::sign_assign(self : Node) -> Unit {
  self.chain_assign(math_node_sign, [])
}

///|
pub fn Node::length(self : Node) -> Node {
  self.chain(math_node_length, [])
}

///|
pub fn Node::length_assign(self : Node) -> Unit {
  self.chain_assign(math_node_length, [])
}

///|
pub fn Node::negate(self : Node) -> Node {
  self.chain(math_node_negate, [])
}

///|
pub fn Node::negate_assign(self : Node) -> Unit {
  self.chain_assign(math_node_negate, [])
}

///|
pub fn Node::one_minus(self : Node) -> Node {
  self.chain(math_node_one_minus, [])
}

///|
pub fn Node::one_minus_assign(self : Node) -> Unit {
  self.chain_assign(math_node_one_minus, [])
}

///|
pub fn Node::d_fdx(self : Node) -> Node {
  self.chain(math_node_d_fdx, [])
}

///|
pub fn Node::d_fdx_assign(self : Node) -> Unit {
  self.chain_assign(math_node_d_fdx, [])
}

///|
pub fn Node::d_fdy(self : Node) -> Node {
  self.chain(math_node_d_fdy, [])
}

///|
pub fn Node::d_fdy_assign(self : Node) -> Unit {
  self.chain_assign(math_node_d_fdy, [])
}

///|
pub fn Node::round(self : Node) -> Node {
  self.chain(math_node_round, [])
}

///|
pub fn Node::round_assign(self : Node) -> Unit {
  self.chain_assign(math_node_round, [])
}

///|
pub fn Node::reciprocal(self : Node) -> Node {
  self.chain(math_node_reciprocal, [])
}

///|
pub fn Node::reciprocal_assign(self : Node) -> Unit {
  self.chain_assign(math_node_reciprocal, [])
}

///|
pub fn Node::trunc(self : Node) -> Node {
  self.chain(math_node_trunc, [])
}

///|
pub fn Node::trunc_assign(self : Node) -> Unit {
  self.chain_assign(math_node_trunc, [])
}

///|
pub fn Node::fwidth(self : Node) -> Node {
  self.chain(math_node_fwidth, [])
}

///|
pub fn Node::fwidth_assign(self : Node) -> Unit {
  self.chain_assign(math_node_fwidth, [])
}

///|
pub fn Node::length_sq(self : Node) -> Node {
  self.chain(math_node_length_sq, [])
}

///|
pub fn Node::length_sq_assign(self : Node) -> Unit {
  self.chain_assign(math_node_length_sq, [])
}

///|
pub fn Node::pow2(self : Node) -> Node {
  self.chain(math_node_pow2, [])
}

///|
pub fn Node::pow2_assign(self : Node) -> Unit {
  self.chain_assign(math_node_pow2, [])
}

///|
pub fn Node::pow3(self : Node) -> Node {
  self.chain(math_node_pow3, [])
}

///|
pub fn Node::pow3_assign(self : Node) -> Unit {
  self.chain_assign(math_node_pow3, [])
}

///|
pub fn Node::pow4(self : Node) -> Node {
  self.chain(math_node_pow4, [])
}

///|
pub fn Node::pow4_assign(self : Node) -> Unit {
  self.chain_assign(math_node_pow4, [])
}

///|
pub fn Node::saturate(self : Node) -> Node {
  self.chain(math_node_saturate, [])
}

///|
pub fn Node::saturate_assign(self : Node) -> Unit {
  self.chain_assign(math_node_saturate, [])
}

///|
pub fn Node::cbrt(self : Node) -> Node {
  self.chain(math_node_cbrt, [])
}

///|
pub fn Node::cbrt_assign(self : Node) -> Unit {
  self.chain_assign(math_node_cbrt, [])
}

///|
pub fn Node::rand(self : Node) -> Node {
  self.chain(math_node_rand, [])
}

///|
pub fn Node::rand_assign(self : Node) -> Unit {
  self.chain_assign(math_node_rand, [])
}

///|
pub fn Node::transpose(self : Node) -> Node {
  self.chain(math_node_transpose, [])
}

///|
pub fn Node::transpose_assign(self : Node) -> Unit {
  self.chain_assign(math_node_transpose, [])
}

///|
pub fn Node::determinant(self : Node) -> Node {
  self.chain(math_node_determinant, [])
}

///|
pub fn Node::determinant_assign(self : Node) -> Unit {
  self.chain_assign(math_node_determinant, [])
}

///|
pub fn Node::inverse(self : Node) -> Node {
  self.chain(math_node_inverse, [])
}

///|
pub fn Node::inverse_assign(self : Node) -> Unit {
  self.chain_assign(math_node_inverse, [])
}

///|
pub fn Node::reflect(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_reflect, [b.to_tsl()])
}

///|
pub fn Node::reflect_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_reflect, [b.to_tsl()])
}

///|
pub fn Node::distance(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_distance, [b.to_tsl()])
}

///|
pub fn Node::distance_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_distance, [b.to_tsl()])
}

///|
pub fn Node::dot(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_dot, [b.to_tsl()])
}

///|
pub fn Node::dot_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_dot, [b.to_tsl()])
}

///|
pub fn Node::cross(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_cross, [b.to_tsl()])
}

///|
pub fn Node::cross_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_cross, [b.to_tsl()])
}

///|
pub fn Node::pow(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_pow, [b.to_tsl()])
}

///|
pub fn Node::pow_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_pow, [b.to_tsl()])
}

///|
pub fn Node::transform_direction(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_transform_direction, [b.to_tsl()])
}

///|
pub fn Node::transform_direction_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_transform_direction, [b.to_tsl()])
}

///|
pub fn Node::transform_normal_by_view_matrix(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_transform_normal_by_view_matrix, [b.to_tsl()])
}

///|
pub fn Node::transform_normal_by_view_matrix_assign(
  self : Node,
  b : &IntoTsl,
) -> Unit {
  self.chain_assign(math_node_transform_normal_by_view_matrix, [b.to_tsl()])
}

///|
pub fn Node::transform_normal_by_inverse_view_matrix(
  self : Node,
  b : &IntoTsl,
) -> Node {
  self.chain(math_node_transform_normal_by_inverse_view_matrix, [b.to_tsl()])
}

///|
pub fn Node::transform_normal_by_inverse_view_matrix_assign(
  self : Node,
  b : &IntoTsl,
) -> Unit {
  self.chain_assign(math_node_transform_normal_by_inverse_view_matrix, [
    b.to_tsl(),
  ])
}

///|
pub fn Node::difference(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_difference, [b.to_tsl()])
}

///|
pub fn Node::difference_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_difference, [b.to_tsl()])
}

///|
pub fn Node::step(self : Node, edge : &IntoTsl) -> Node {
  self.chain(math_node_step_element, [edge.to_tsl()])
}

///|
pub fn Node::step_assign(self : Node, edge : &IntoTsl) -> Unit {
  self.chain_assign(math_node_step_element, [edge.to_tsl()])
}

///|
pub fn Node::refract(self : Node, n : &IntoTsl, eta : &IntoTsl) -> Node {
  self.chain(math_node_refract, [n.to_tsl(), eta.to_tsl()])
}

///|
pub fn Node::refract_assign(self : Node, n : &IntoTsl, eta : &IntoTsl) -> Unit {
  self.chain_assign(math_node_refract, [n.to_tsl(), eta.to_tsl()])
}

///|
pub fn Node::face_forward(self : Node, i : &IntoTsl, nref : &IntoTsl) -> Node {
  self.chain(math_node_face_forward, [i.to_tsl(), nref.to_tsl()])
}

///|
pub fn Node::face_forward_assign(
  self : Node,
  i : &IntoTsl,
  nref : &IntoTsl,
) -> Unit {
  self.chain_assign(math_node_face_forward, [i.to_tsl(), nref.to_tsl()])
}

///|
pub fn Node::mix(self : Node, e1 : &IntoTsl, e2 : &IntoTsl) -> Node {
  self.chain(math_node_mix_element, [e1.to_tsl(), e2.to_tsl()])
}

///|
pub fn Node::mix_assign(self : Node, e1 : &IntoTsl, e2 : &IntoTsl) -> Unit {
  self.chain_assign(math_node_mix_element, [e1.to_tsl(), e2.to_tsl()])
}

///|
pub fn Node::smoothstep(self : Node, low : &IntoTsl, high : &IntoTsl) -> Node {
  self.chain(math_node_smoothstep_element, [low.to_tsl(), high.to_tsl()])
}

///|
pub fn Node::smoothstep_assign(
  self : Node,
  low : &IntoTsl,
  high : &IntoTsl,
) -> Unit {
  self.chain_assign(math_node_smoothstep_element, [low.to_tsl(), high.to_tsl()])
}

///|
pub fn Node::min(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_min, [b.to_tsl()])
}

///|
/// `a.min( b, ...params )`.
pub fn Node::min_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(math_node_min, tsl_values_of(params))
}

///|
pub fn Node::min_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_min, [b.to_tsl()])
}

///|
pub fn Node::min_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(math_node_min, tsl_values_of(params))
}

///|
pub fn Node::max(self : Node, b : &IntoTsl) -> Node {
  self.chain(math_node_max, [b.to_tsl()])
}

///|
/// `a.max( b, ...params )`.
pub fn Node::max_of(self : Node, params : Array[&IntoTsl]) -> Node {
  self.chain(math_node_max, tsl_values_of(params))
}

///|
pub fn Node::max_assign(self : Node, b : &IntoTsl) -> Unit {
  self.chain_assign(math_node_max, [b.to_tsl()])
}

///|
pub fn Node::max_assign_of(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(math_node_max, tsl_values_of(params))
}
