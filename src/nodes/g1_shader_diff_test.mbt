// MoonBit side of the G1 shader scenarios (nodes/math, utils, code, geometry,
// procedural, shapes, fog). The upstream side is
// diff/core/webgpu/shader_diff/upstream_g1.mjs; `node shader_diff/run.mjs g1_...` compares them byte for byte.
//
// Both sides build with `G1Builder`: a NodeBuilder class whose backend methods print
// their arguments, whose `buildFunctionCode` writes layout functions in a WGSL-like form
// that `g1_parser` reads back, run with the WebGPU renderer stub (`wgsl`) or the same
// renderer with a backend that is not WebGPU and uses the WebGL coordinate system
// (`glsl`, where `getFunctionOperator( '^^' )` is `xor_fn`). Records add `codes`.

///|
extern "js" fn g1_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g1_shader_json(
  code : String,
  result : String,
  vars : String,
  uniforms : FixedArray[String],
  codes : String,
) -> String = "(code, result, vars, uniforms, codes) => JSON.stringify({ code, result, vars, uniforms, codes })"

///|
/// `g1ParseFunction` of upstream_g1.mjs, verbatim: `[ name, type, [ [ name, type ] ] ]`.
extern "js" fn g1_parse_function(source : String) -> @core.JsValue =
  #|( source ) => {
  #|	const m = /^fn (\w+)\( (.*?) \) -> (\w+) \{/.exec( source );
  #|	const inputs = m[ 2 ] === '' ? [] : m[ 2 ].split( ', ' ).map( ( p ) => p.split( ' : ' ) );
  #|	return [ m[ 1 ], m[ 3 ], inputs ];
  #|}

///|
/// `g1FunctionCode` of upstream_g1.mjs, verbatim.
extern "js" fn g1_function_code(
  source : String,
  name : String,
  new_name : String,
) -> String = "( source, name, newName ) => source.replace( 'fn ' + name + '(', 'fn ' + newName + '(' )"

///|
extern "js" fn g1_js_get(value : @core.JsValue, i : Int32) -> @core.JsValue = "(v, i) => v[ i ]"

///|
extern "js" fn g1_js_length(value : @core.JsValue) -> Int32 = "(v) => v.length"

///|
/// `G1Parser`: a `G1Function` per source.
fn g1_parser() -> @nodes.NodeParser {
  {
    parse_function_impl: Some(fn(source) {
      let parsed = g1_parse_function(source)
      let name : String = g1_js_get(parsed, 0).cast()
      let type_ : String = g1_js_get(parsed, 1).cast()
      let params = g1_js_get(parsed, 2)
      let inputs = []
      for i in 0..<g1_js_length(params) {
        let p = g1_js_get(params, i)
        inputs.push(
          @nodes.NodeFunctionInput::new(
            g1_js_get(p, 1).cast(),
            g1_js_get(p, 0).cast(),
          ),
        )
      }
      let f = @nodes.NodeFunction::new(type_, inputs, name~)
      f.payload = @core.JsValue::of(source)
      f.get_code_impl = Some(fn(f, new_name) {
        g1_function_code(f.payload.cast(), f.name, new_name)
      })
      f
    }),
  }
}

///|
struct G1Builder {
  glsl : Bool
  /// `isAvailable( 'storageBuffer' )`.
  storage : Bool
}

///|
fn g1_fmt(s : String?) -> String {
  match s {
    Some(s) => s
    None => "-"
  }
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn is_available(self, _, name) {
  self.storage && name == "storageBuffer"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn generate_texture(
  _,
  _,
  _,
  p,
  uv,
  depth,
  offset,
  _,
) {
  "tex(\{p}, \{uv}, \{g1_fmt(depth)}, \{g1_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn generate_texture_level(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLevel(\{p}, \{uv}, \{level}, \{g1_fmt(depth)}, \{g1_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn generate_texture_load(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLoad(\{p}, \{uv}, \{g1_fmt(level)}, \{g1_fmt(depth)}, \{g1_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn generate_texture_size(
  _,
  _,
  _,
  p,
  level,
) {
  "size(\{p}, \{level})"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn register_transform(
  _,
  _,
  _,
  _,
) {

}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn class_name(_) {
  "G1Builder"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn get_function_operator(
  self,
  _,
  op,
) {
  if self.glsl && op == "^^" {
    Some("xor_fn")
  } else {
    None
  }
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn get_ternary(_, _, c, a, b) {
  Some("select( \{b}, \{a}, \{c} )")
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn get_bitcast_method(
  _,
  _,
  type_,
  input_type,
) {
  "bitcast<\{type_}:\{input_type.unwrap_or("null")}>"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn get_float_packing_method(
  _,
  _,
  encoding,
  layout,
) {
  "pack_\{encoding}_\{layout}"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn get_float_unpacking_method(
  _,
  _,
  encoding,
  layout,
) {
  "unpack_\{encoding}_\{layout}"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn get_instance_index(_, _) {
  "instance_index"
}

///|
impl @nodes.NodeBuilderClass for G1Builder with fn build_function_code(
  _,
  b,
  shader_node,
) {
  let layout = @nodes.ShaderNodeInternal::get_layout(shader_node).unwrap()
  let flow_data = b.flow_shader_node(shader_node)
  let parameters = layout.inputs.map(fn(input) {
    input.name + " : " + b.get_type(input.type_)
  })
  let type_ = match layout.type_ {
    Some(t) => b.get_type(t)
    None => "null"
  }
  let mut code = "fn \{layout.name}( \{parameters.join(", ")} ) -> \{type_} {\n\{flow_data.vars.unwrap_or("undefined")}\n\{flow_data.code}\n"
  let result = flow_data.result_snippet()
  if result != "" {
    code += "\treturn \{result};\n"
  }
  code += "\n}\n"
  code
}

///|
/// The backend of the `glsl` renderer: not WebGPU, WebGL coordinate system.
struct G1GlslBackend {}

///|
impl @nodes.BackendClass for G1GlslBackend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for G1GlslBackend with fn coordinate_system(_, _) {
  @core.WebGLCoordinateSystem
}

///|
fn g1_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
/// The mesh geometry: 24 vertices with position, normal and uv.
let g1_geometry : @core.BufferGeometry = {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", g1_attribute(24, 3)) |> ignore
  g.set_attribute("normal", g1_attribute(24, 3)) |> ignore
  g.set_attribute("uv", g1_attribute(24, 2)) |> ignore
  g
}

///|
fn g1_setup(f : () -> @nodes.Node) -> @core.JsValue {
  @core.JsValue::of(@nodes.ContextSetup::{ f, })
}

///|
/// `materialContext( builder )` of upstream_g1.mjs.
fn g1_material_context(b : @nodes.NodeBuilder) -> Unit {
  b.context.set(
    "setupPositionView",
    Other(
      g1_setup(fn() {
        @nodes.model_view_matrix.mul(@nodes.position_local).xyz()
      }),
    ),
  )
  b.context.set(
    "setupModelViewProjection",
    Other(
      g1_setup(fn() {
        @nodes.camera_projection_matrix.mul(@nodes.position_view)
      }),
    ),
  )
  b.context.set(
    "setupNormal",
    Other(
      g1_setup(fn() {
        @nodes.sub_build(@nodes.normal_view_geometry, "NORMAL", type_="vec3")
      }),
    ),
  )
}

///|
fn g1_fv(v : Double) -> @nodes.Node {
  @nodes.float(v).to_var()
}

///|
fn g1_v2() -> @nodes.Node {
  @nodes.vec2_of([1, 2]).to_var()
}

///|
fn g1_v3() -> @nodes.Node {
  @nodes.vec3_of([1, 2, 3]).to_var()
}

///|
fn g1_v4() -> @nodes.Node {
  @nodes.vec4_of([1, 2, 3, 4]).to_var()
}

///|
fn g1_iv(v : Int32) -> @nodes.Node {
  @nodes.int(v).to_var()
}

///|
fn g1_uv(v : Int32) -> @nodes.Node {
  @nodes.uint(v).to_var()
}

///|
fn g1_m2() -> @nodes.Node {
  @nodes.mat2_of([1, 2, 3, 4]).to_var()
}

///|
fn g1_m3() -> @nodes.Node {
  @nodes.mat3_of([1, 0, 0, 0, 1, 0, 0, 0, 1]).to_var()
}

///|
fn g1_m4() -> @nodes.Node {
  @nodes.mat4_of([]).to_var()
}

///|
fn g1_named(inputs : @nodes.FnInputs, name : String) -> @nodes.Node {
  inputs.named(name).unwrap()
}

///|
fn g1_arg(inputs : @nodes.FnInputs, i : Int32) -> @nodes.Node {
  inputs.get(i).unwrap()
}

///|
priv struct G1Scenario {
  name : String
  stage : String
  glsl : Bool
  make : () -> @nodes.Node
  /// `renderer.reversedDepthBuffer` while the scenario builds.
  reversed : Bool
  /// Builds for a mesh with a camera and the node material context.
  mesh : Bool
  /// `isAvailable( 'storageBuffer' )`.
  storage : Bool
}

///|
fn g1_scenarios() -> Array[G1Scenario] {
  let scenarios : Array[G1Scenario] = []
  let push = fn(
    name : String,
    make : () -> @nodes.Node,
    glsl : Bool,
    stage : String,
  ) {
    scenarios.push({
      name: "g1_" + name,
      stage,
      glsl,
      make,
      reversed: false,
      mesh: false,
      storage: false,
    })
  }
  let push_reversed = fn(name : String, make : () -> @nodes.Node, glsl : Bool) {
    scenarios.push({
      name: "g1_" + name,
      stage: "fragment",
      glsl,
      make,
      reversed: true,
      mesh: false,
      storage: false,
    })
  }
  let push_mesh = fn(
    name : String,
    make : () -> @nodes.Node,
    stage : String,
    storage : Bool,
  ) {
    scenarios.push({
      name: "g1_" + name,
      stage,
      glsl: false,
      make,
      reversed: false,
      mesh: true,
      storage,
    })
  }
  let add_mesh = fn(name : String, make : () -> @nodes.Node) {
    push_mesh(name, make, "fragment", false)
  }
  let add = fn(name : String, make : () -> @nodes.Node) {
    push(name, make, false, "fragment")
  }
  let both = fn(name : String, make : () -> @nodes.Node) {
    add(name, make)
    push(name + "_glsl", make, true, "fragment")
  }

  // --- OperatorNode
  both("op_add_float", fn() { @nodes.add(g1_fv(1), 2) })
  both("op_add_variadic", fn() { @nodes.add_of([g1_fv(1), 2, g1_fv(3), 4]) })
  both("op_sub_vec3_float", fn() { g1_v3().sub(g1_fv(1)) })
  both("op_mul_vec2_vec3", fn() { g1_v2().mul(g1_v3()) })
  both("op_div_int_float", fn() { g1_iv(4).div(2.5) })
  both("op_div_int_int", fn() { g1_iv(4).div(g1_iv(2)) })
  both("op_mul_uint_weak", fn() { g1_uv(3).mul(2) })
  both("op_mul_uint_negative", fn() { g1_uv(3).mul(-2) })
  both("op_mul_uint_int", fn() { g1_uv(3).mul(g1_iv(2)) })
  both("op_add_bool_weak", fn() { @nodes.bool(true).to_var().add(1) })
  both("op_mod_float", fn() { g1_fv(5).mod(2) })
  both("op_mod_vec3_float", fn() { g1_v3().mod(g1_fv(2)) })
  both("op_mod_int", fn() { g1_iv(5).mod(g1_iv(2)) })
  both("op_equal_float", fn() { g1_fv(1).equal(2) })
  both("op_not_equal_vec3", fn() { g1_v3().not_equal(g1_v3()) })
  both("op_less_than_vec2_float", fn() { g1_v2().less_than(g1_fv(1)) })
  both("op_greater_than_int_uint", fn() { g1_iv(1).greater_than(g1_uv(2)) })
  both("op_less_than_equal", fn() { g1_fv(1).less_than_equal(2) })
  both("op_greater_than_equal_vec4", fn() {
    g1_v4().greater_than_equal(@nodes.vec4(0))
  })
  both("op_and", fn() {
    @nodes.bool(true).to_var().and_(@nodes.bool(false).to_var())
  })
  both("op_and_variadic", fn() {
    @nodes.and_of([
      @nodes.bool(true).to_var(),
      @nodes.bool(false).to_var(),
      @nodes.bool(true).to_var(),
    ])
  })
  both("op_and_bvec", fn() {
    @nodes.bvec2_of([true, false])
    .to_var()
    .and_(@nodes.bvec2_of([false, true]).to_var())
  })
  both("op_or", fn() { g1_fv(1).greater_than(0).or(g1_fv(2).less_than(3)) })
  both("op_not", fn() { @nodes.bool(true).to_var().not_() })
  both("op_not_vec3", fn() {
    @nodes.bvec3_of([true, false, true]).to_var().not_()
  })
  both("op_xor", fn() {
    @nodes.bool(true).to_var().xor(@nodes.bool(false).to_var())
  })
  both("op_bit_and_int", fn() { g1_iv(6).bit_and(3) })
  both("op_bit_or_uint", fn() { g1_uv(6).bit_or(g1_uv(1)) })
  both("op_bit_xor_ivec", fn() {
    @nodes.ivec2_of([1, 2]).to_var().bit_xor(@nodes.ivec2_of([3, 4]))
  })
  both("op_bit_and_float", fn() { g1_fv(6).bit_and(3) })
  both("op_bit_not", fn() { g1_iv(6).bit_not() })
  both("op_shift_left_int", fn() { g1_iv(1).shift_left(g1_iv(3)) })
  both("op_shift_right_uvec", fn() {
    @nodes.uvec3_of([8, 16, 32]).to_var().shift_right(2)
  })
  both("op_mat3_vec3", fn() { g1_m3().mul(g1_v3()) })
  both("op_vec3_mat3", fn() { g1_v3().mul(g1_m3()) })
  both("op_mat4_mat4", fn() { g1_m4().mul(g1_m4()) })
  both("op_mat3_float", fn() { g1_m3().mul(g1_fv(2)) })
  both("op_float_mat2", fn() { g1_fv(2).mul(g1_m2()) })
  both("op_mat4_vec3", fn() { g1_m4().mul(g1_v3()) })
  both("op_mat2_mat3", fn() { g1_m2().add(g1_m3()) })
  add("op_void_statement", fn() {
    @nodes.fn_(fn(_, _) {
      let v = g1_fv(1)
      v.add(2) |> ignore
      @nodes.mul(v, v) |> ignore
      Some(v)
    }).call([])
  })
  both("op_assign_ops", fn() {
    @nodes.fn_(fn(_, _) {
      let v = g1_fv(1)
      v.add_assign(2)
      v.sub_assign(1)
      v.mul_assign(3)
      v.div_assign(2)
      v.mod_assign(5)
      let i = g1_iv(3)
      i.bit_and_assign(1)
      i.bit_or_assign(2)
      i.bit_xor_assign(7)
      i.shift_left_assign(1)
      i.shift_right_assign(1)
      Some(v.add(@nodes.float(i)))
    }).call([])
  })
  add("op_increment", fn() {
    @nodes.fn_(fn(_, _) {
      let i = g1_iv(0)
      i.increment()
      i.decrement()
      i.increment_before()
      i.decrement_before()
      let j = g1_iv(2)
      let prev = @nodes.increment.call([j])
      Some(prev.add(j))
    }).call([])
  })

  // --- MathNode
  let one : Array[(String, (@nodes.Node) -> @nodes.Node)] = [
    ("radians", fn(n) { n.radians() }),
    ("degrees", fn(n) { n.degrees() }),
    ("exp", fn(n) { n.exp() }),
    ("exp2", fn(n) { n.exp2() }),
    ("log", fn(n) { n.log() }),
    ("log2", fn(n) { n.log2() }),
    ("sqrt", fn(n) { n.sqrt() }),
    ("inverseSqrt", fn(n) { n.inverse_sqrt() }),
    ("floor", fn(n) { n.floor() }),
    ("ceil", fn(n) { n.ceil() }),
    ("normalize", fn(n) { n.normalize() }),
    ("fract", fn(n) { n.fract() }),
    ("sin", fn(n) { n.sin() }),
    ("sinh", fn(n) { n.sinh() }),
    ("cos", fn(n) { n.cos() }),
    ("cosh", fn(n) { n.cosh() }),
    ("tan", fn(n) { n.tan() }),
    ("tanh", fn(n) { n.tanh() }),
    ("asin", fn(n) { n.asin() }),
    ("asinh", fn(n) { n.asinh() }),
    ("acos", fn(n) { n.acos() }),
    ("acosh", fn(n) { n.acosh() }),
    ("atan", fn(n) { n.atan() }),
    ("atanh", fn(n) { n.atanh() }),
    ("abs", fn(n) { n.abs() }),
    ("sign", fn(n) { n.sign() }),
    ("length", fn(n) { n.length() }),
    ("lengthSq", fn(n) { n.length_sq() }),
    ("negate", fn(n) { n.negate() }),
    ("oneMinus", fn(n) { n.one_minus() }),
    ("dFdx", fn(n) { n.d_fdx() }),
    ("dFdy", fn(n) { n.d_fdy() }),
    ("round", fn(n) { n.round() }),
    ("reciprocal", fn(n) { n.reciprocal() }),
    ("trunc", fn(n) { n.trunc() }),
    ("fwidth", fn(n) { n.fwidth() }),
    ("saturate", fn(n) { n.saturate() }),
    ("cbrt", fn(n) { n.cbrt() }),
    ("pow2", fn(n) { n.pow2() }),
    ("pow3", fn(n) { n.pow3() }),
    ("pow4", fn(n) { n.pow4() }),
  ]
  for entry in one {
    let (m, f) = entry
    add("math_" + m + "_float", fn() { f(g1_fv(0.5)) })
    add("math_" + m + "_vec3", fn() { f(g1_v3()) })
  }
  for entry in one {
    let (m, f) = entry
    add("math_" + m + "_int", fn() { f(g1_iv(2)) })
  }
  add("math_two_int", fn() {
    @nodes.vec4_of([
      @nodes.step(g1_iv(1), g1_iv(2)),
      @nodes.reflect(g1_iv(1), g1_iv(2)),
      @nodes.distance(g1_iv(1), g1_iv(2)),
      @nodes.difference(g1_iv(1), g1_iv(2)),
    ]).add(
      @nodes.vec4_of([
        @nodes.cross(
          @nodes.ivec3_of([1, 2, 3]).to_var(),
          @nodes.ivec3_of([3, 2, 1]),
        ),
        @nodes.atan(g1_iv(1), x=g1_iv(2)),
      ]),
    )
  })
  add("math_three_int", fn() {
    @nodes.vec3_of([
      @nodes.refract(g1_iv(1), g1_iv(2), g1_iv(3)),
      @nodes.smoothstep(g1_iv(0), g1_iv(1), g1_iv(2)),
      @nodes.face_forward(g1_iv(1), g1_iv(2), g1_iv(3)),
    ])
    .add(@nodes.clamp(g1_iv(5), low=g1_iv(0), high=g1_iv(3)))
    .add(@nodes.min(g1_iv(1), g1_iv(2)))
  })
  for m in ["abs", "oneMinus"] {
    let f = one.search_by(fn(e) { e.0 == m }).map(fn(i) { one[i].1 }).unwrap()
    add("math_" + m + "_uvec2", fn() { f(@nodes.uvec2_of([1, 2]).to_var()) })
  }
  push("math_dfdx_vertex", fn() { g1_fv(1).d_fdx() }, false, "vertex")
  push("math_dfdy_compute", fn() { g1_v2().d_fdy() }, false, "compute")
  add("math_all_any", fn() {
    @nodes.all(@nodes.bvec3_of([true, false, true]).to_var()).and_(
      @nodes.bvec2_of([true, true]).to_var().any(),
    )
  })
  add("math_transpose", fn() { g1_m3().transpose() })
  // One scalar: the other elements are undefined upstream and print as 0.
  add("math_mat2_scalar", fn() { @nodes.mat2(1).to_var() })
  add("math_mat3_scalar", fn() { @nodes.mat3(0).to_var() })
  add("math_mat4_scalar", fn() { @nodes.mat4(2).to_var() })
  add("math_determinant", fn() { g1_m3().determinant() })
  add("math_inverse", fn() { g1_m4().inverse() })
  add("math_mat_methods_mat2", fn() {
    g1_m2().transpose().mul(g1_m2().inverse()).mul(g1_m2().determinant())
  })
  both("math_min_float", fn() { @nodes.min(g1_fv(1), 2) })
  both("math_min_vec3_float", fn() { g1_v3().min(g1_fv(1)) })
  both("math_max_variadic", fn() {
    @nodes.max_of([g1_fv(1), g1_fv(2), 3, g1_fv(4)])
  })
  both("math_max_int", fn() { g1_iv(1).max(g1_iv(3)) })
  both("math_max_uint_weak", fn() { g1_uv(1).max(3) })
  both("math_step_float_vec3", fn() { @nodes.step(g1_fv(0.5), g1_v3()) })
  both("math_step_chain", fn() { g1_v3().step(g1_fv(0.5)) })
  both("math_reflect", fn() { @nodes.reflect(g1_v3(), g1_v3().normalize()) })
  both("math_distance", fn() { @nodes.distance(g1_v3(), @nodes.vec3(0)) })
  both("math_difference", fn() { @nodes.difference(g1_fv(1), 3) })
  both("math_dot_vec2", fn() { g1_v2().dot(@nodes.vec2_of([1, 1])) })
  both("math_cross", fn() { g1_v3().cross(@nodes.vec3_of([0, 1, 0])) })
  both("math_pow_int", fn() { g1_iv(2).pow(3) })
  both("math_pow_vec3_float", fn() { g1_v3().pow(g1_fv(2)) })
  both("math_atan2", fn() { @nodes.atan(g1_fv(1), x=g1_fv(2)) })
  both("math_atan2_chain", fn() { g1_v2().atan(x=@nodes.vec2_of([1, 2])) })
  both("math_transform_direction", fn() {
    @nodes.transform_direction(g1_v3(), g1_m4())
  })
  both("math_transform_direction_mat_first", fn() {
    @nodes.transform_direction(g1_m4(), g1_v3())
  })
  both("math_transform_normal", fn() {
    g1_v3()
    .transform_normal_by_view_matrix(g1_m4())
    .add(g1_v3().transform_normal_by_inverse_view_matrix(g1_m4()))
  })
  both("math_mix_float", fn() { @nodes.mix(g1_fv(0), g1_fv(1), 0.5) })
  both("math_mix_vec3_float_t", fn() {
    @nodes.mix(g1_v3(), @nodes.vec3(0), g1_fv(0.5))
  })
  both("math_mix_vec3_vec3_t", fn() {
    @nodes.mix(g1_v3(), @nodes.vec3(0), g1_v3())
  })
  both("math_mix_chain", fn() { g1_fv(0.25).mix(g1_v3(), @nodes.vec3(1)) })
  both("math_clamp_default", fn() { @nodes.clamp(g1_v3()) })
  both("math_clamp_low", fn() { g1_fv(3).clamp(low=1) })
  both("math_clamp_int", fn() { g1_iv(3).clamp(low=g1_iv(0), high=2) })
  both("math_refract", fn() {
    @nodes.refract(g1_v3(), @nodes.vec3_of([0, 1, 0]), g1_fv(1.5))
  })
  both("math_smoothstep", fn() { @nodes.smoothstep(0, 1, g1_fv(0.3)) })
  both("math_smoothstep_chain", fn() { g1_v3().smoothstep(0, g1_fv(2)) })
  both("math_face_forward", fn() {
    @nodes.face_forward(g1_v3(), g1_v3(), @nodes.vec3_of([0, 0, 1]))
  })
  both("math_faceforward_alias", fn() {
    @nodes.faceforward(g1_v3(), g1_v3(), g1_v3()).add(
      @nodes.inversesqrt(g1_fv(4)),
    )
  })
  add("math_rand", fn() { @nodes.rand.call([g1_v2()]) })
  add("math_rand_chain_twice", fn() {
    g1_v2().rand().add(@nodes.vec2_of([3, 4]).to_var().rand())
  })
  add("math_constants", fn() {
    @nodes.vec4_of([@nodes.pi, @nodes.two_pi, @nodes.half_pi, @nodes.epsilon]).add(
      @nodes.infinity,
    )
  })
  add("math_mix_element", fn() {
    @nodes.mix_element(g1_fv(0.5), g1_v3(), @nodes.vec3(2))
    .add(@nodes.smoothstep_element(g1_fv(0.5), 0, 1))
    .add(@nodes.step_element(g1_fv(0.5), 0.2))
  })

  // --- MathUtils
  add("math_utils", fn() {
    @nodes.parabola(g1_fv(0.5), 2)
    .add(@nodes.gain(g1_fv(0.25), 3))
    .add(@nodes.pcurve(g1_fv(0.5), 2, 3))
    .add(@nodes.sinc(g1_fv(0.5), g1_fv(2)))
  })

  // --- ConditionalNode
  both("cond_select_float", fn() {
    @nodes.select(g1_fv(1).greater_than(0), 1.5, else_node=g1_fv(2))
  })
  add("cond_select_no_else", fn() { g1_fv(1).greater_than(0).select(g1_v3()) })
  add("cond_select_uniform_flow", fn() {
    @nodes.select(g1_fv(1).greater_than(0), g1_fv(2), else_node=3).uniform_flow()
  })
  add("cond_select_vector_cond", fn() {
    @nodes.select(
      g1_v3().greater_than(@nodes.vec3(1)),
      g1_v3(),
      else_node=@nodes.vec3(0),
    )
  })
  add("cond_select_vector_cond_no_else", fn() {
    @nodes.select(@nodes.bvec2_of([true, false]).to_var(), g1_v2())
  })
  add("cond_select_vector_cond_scalar_values", fn() {
    @nodes.select(
      @nodes.bvec3_of([true, false, true]).to_var(),
      g1_fv(1),
      else_node=g1_fv(2),
    )
  })
  add("cond_select_type_from_else", fn() {
    @nodes.select(@nodes.bool(true).to_var(), g1_fv(1), else_node=g1_v4())
  })
  add("cond_if_else", fn() {
    @nodes.fn_(fn(_, _) {
      let r = g1_fv(0)
      let x = g1_fv(2)
      @nodes.if_(x.greater_than(1), fn() { r.assign(1) })
      .else_if(x.less_than(0), fn() { r.assign(2) })
      .else_(fn() { r.assign(3) })
      Some(r)
    }).call([])
  })
  add("cond_if_const_guard", fn() {
    @nodes.fn_(fn(_, _) {
      let r = g1_fv(0)
      let c = @nodes.bool(true).to_const()
      @nodes.if_(c, fn() { r.assign(1) }) |> ignore
      @nodes.if_(c, fn() { r.add_assign(2) }) |> ignore
      Some(r)
    }).call([])
  })
  add("cond_return_in_layout", fn() {
    @nodes.fn_(
      fn(inputs, _) {
        let x = g1_arg(inputs, 0)
        @nodes.if_value(x.greater_than(1), fn() { x.mul(2) }) |> ignore
        Some(x)
      },
      layout=@nodes.FnLayout::short([("x", "float")], return_="float"),
    ).call([g1_fv(3)])
  })
  add("cond_return_inline", fn() {
    @nodes.fn_(fn(inputs, _) {
      let x = g1_arg(inputs, 0)
      @nodes.if_value(x.greater_than(1), fn() { x.mul(2) }).else_value(fn() {
        x
      })
      Some(x)
    }).call([g1_fv(3)])
  })
  add("cond_switch", fn() {
    @nodes.fn_(fn(_, _) {
      let r = g1_fv(0)
      let i = g1_iv(2)
      @nodes.switch_(i)
      .case_([0], fn() { r.assign(1) })
      .case_([1, 2], fn() { r.assign(2) })
      .default(fn() { r.assign(3) })
      Some(r)
    }).call([])
  })

  // --- LoopNode
  add("loop_count", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([4], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      Some(s)
    }).call([])
  })
  add("loop_shared_count", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([3], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      Some(s)
    }).call([])
  })
  add("loop_node_count", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      let n = g1_iv(5)
      @nodes.loop_([n, g1_iv(2)], fn(inputs) {
        let i = g1_named(inputs, "i")
        let j = g1_named(inputs, "j")
        s.add_assign(@nodes.float(i.add(j)))
      })
      Some(s)
    }).call([])
  })
  add("loop_while", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([s.less_than(10)], fn(_) { s.add_assign(1) })
      Some(s)
    }).call([])
  })
  add("loop_forever_break", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([], fn(_) {
        s.add_assign(1)
        @nodes.if_(s.greater_than(3), fn() { @nodes.break_() }) |> ignore
        @nodes.continue_()
      })
      Some(s)
    }).call([])
  })
  add("loop_ranges", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([@nodes.loop_range(start=10, end=0)], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      @nodes.loop_(
        [
          @nodes.loop_range(
            start=@nodes.float(0),
            end=@nodes.float(3),
            type_="float",
            condition="<=",
            name="x",
          ),
        ],
        fn(inputs) { s.add_assign(g1_named(inputs, "x")) },
      )
      @nodes.loop_([@nodes.loop_range(start=4)], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      @nodes.loop_([@nodes.loop_range(end=g1_iv(6), type_="uint")], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      @nodes.loop_([@nodes.loop_range(start=0, end=8, update=2)], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      @nodes.loop_(
        [@nodes.loop_range(start=8, end=0, condition=">", update="-= 2")],
        fn(inputs) { s.add_assign(@nodes.float(g1_named(inputs, "i"))) },
      )
      @nodes.loop_([@nodes.loop_range(start=0, end=10, update=g1_iv(3))], fn(
        inputs,
      ) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      let update : @nodes.ShaderFn = {
        f: fn(inputs, _) {
          g1_named(inputs, "i").mul_assign(2)
          None
        },
      }
      @nodes.loop_([@nodes.loop_range(start=1, end=100, update~)], fn(inputs) {
        s.add_assign(@nodes.float(g1_named(inputs, "i")))
      })
      Some(s)
    }).call([])
  })
  add("loop_bad_update", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([@nodes.loop_range(start=0, end=2, update=true)], fn(_) {
        s.add_assign(1)
      })
      Some(s)
    }).call([])
  })

  // --- Code
  add("code_expression", fn() {
    @nodes.fn_(fn(_, _) {
      @nodes.expression("doSomething()").to_stack() |> ignore
      Some(@nodes.expression("myValue", node_type="vec3").add(1))
    }).call([])
  })
  let wgsl_add = @nodes.wgsl_fn(
    "fn addThree( a : vec3, b : float ) -> vec3 { return a + b; }",
  )
  add("code_wgsl_fn", fn() { wgsl_add.call([g1_v3(), g1_fv(2)]) })
  add("code_wgsl_fn_named", fn() {
    wgsl_add.call_named({ "b": g1_fv(2), "a": g1_v3() })
  })
  add("code_wgsl_fn_missing", fn() { wgsl_add.call_named({ "a": g1_v3() }) })
  add("code_wgsl_fn_too_few", fn() { wgsl_add.call([g1_v3()]) })
  add("code_wgsl_fn_too_many", fn() {
    wgsl_add.call([g1_v3(), g1_fv(1), g1_fv(2)])
  })
  let helper = @nodes.code("// helper code")
  let wgsl_incl = @nodes.glsl_fn(
    "fn useHelper( x : float ) -> float { return x; }",
    includes=[helper],
  )
  add("code_fn_includes", fn() { wgsl_incl.call([g1_fv(1)]) })
  add("code_call_chain", fn() {
    @nodes.function_call(wgsl_add, [Node(g1_v3()), Node(g1_fv(3))])
  })
  let wgsl_helper = @nodes.wgsl("// wgsl helper")
  let fn_includes = @nodes.wgsl_fn(
    "fn useHelpers( x : float ) -> float { return x; }",
    includes=[
      @nodes.js("// js helper"),
      wgsl_helper,
      @nodes.glsl("// glsl helper", includes=[wgsl_helper]),
    ],
  )
  add("code_js_wgsl_glsl", fn() { fn_includes.call([g1_fv(2)]) })

  // --- Bitcast, packing
  add("bitcast", fn() {
    @nodes.bitcast(g1_fv(1), "uint")
    .add(@nodes.float_bits_to_int(g1_v2()).x())
    .add(@nodes.int_bits_to_float(g1_iv(3)))
    .add(@nodes.uint_bits_to_float(g1_uv(4)))
  })
  add("bitcast_vec", fn() { @nodes.float_bits_to_uint(g1_v3()) })
  add("pack_float", fn() {
    @nodes.vec4_of([
      @nodes.pack_snorm2x16(g1_v2()),
      @nodes.pack_unorm2x16(g1_v2()),
      @nodes.pack_half2x16(g1_v2()),
      @nodes.pack_snorm4x8(g1_v4()),
    ]).add(@nodes.pack_unorm4x8(g1_v4()))
  })
  add("unpack_float", fn() {
    @nodes.unpack_snorm2x16(g1_uv(1))
    .add(@nodes.unpack_unorm2x16(g1_uv(2)))
    .add(@nodes.unpack_half2x16(g1_uv(3)))
    .xyxy()
    .add(@nodes.unpack_snorm4x8(g1_uv(4)))
    .add(@nodes.unpack_unorm4x8(g1_uv(5)))
  })
  add("packed4x8", fn() {
    @nodes.vec4_of([
      @nodes.dot4_u8_packed(g1_uv(1), g1_uv(2)),
      @nodes.dot4_i8_packed(g1_uv(3), g1_uv(4)),
      @nodes.pack4x_i8(@nodes.ivec4_of([1, 2, 3, 4]).to_var()),
      @nodes.pack4x_u8(@nodes.uvec4_of([1, 2, 3, 4]).to_var()),
    ])
  })
  add("packed4x8_clamp_unpack", fn() {
    @nodes.vec4_of([
      @nodes.pack4x_i8_clamp(@nodes.ivec4_of([1, 2, 3, 4]).to_var()),
      @nodes.pack4x_u8_clamp(@nodes.uvec4_of([1, 2, 3, 4]).to_var()),
      0,
      0,
    ])
    .add(@nodes.vec4(@nodes.unpack4x_i8(g1_uv(7))))
    .add(@nodes.vec4(@nodes.unpack4x_u8(g1_uv(8))))
  })
  both("bitcount", fn() {
    @nodes.vec3_of([
      @nodes.count_trailing_zeros(g1_uv(8)),
      @nodes.count_leading_zeros(g1_iv(8)),
      @nodes.count_one_bits(g1_uv(7)),
    ])
  })
  push(
    "bitcount_vec_glsl",
    fn() {
      @nodes.vec3(@nodes.count_one_bits(@nodes.ivec3_of([1, 2, 3]).to_var())).add(
        @nodes.vec3(
          @nodes.count_trailing_zeros(@nodes.uvec3_of([1, 2, 3]).to_var()),
        ),
      )
    },
    true,
    "fragment",
  )

  // --- Hash, noise, rotate, UV utils, remap
  add("hash", fn() {
    @nodes.hash_tsl.call([g1_uv(3)]).add(@nodes.hash_tsl.call([g1_fv(2)]))
  })
  add("tri_noise3d", fn() {
    @nodes.tri_noise3d.call([g1_v3(), g1_fv(1), g1_fv(0.5)])
  })
  add("rotate_vec2", fn() { @nodes.rotate(g1_v2(), g1_fv(1)) })
  add("rotate_vec3", fn() { @nodes.rotate(g1_v3(), g1_v3()) })
  add("rotate_vec3_zyx", fn() { @nodes.rotate(g1_v3(), g1_v3(), order="ZYX") })
  add("rotate_set_order", fn() {
    @nodes.rotate(g1_v3(), g1_v3()).set_order("YXZ")
  })
  add("rotate_uv", fn() {
    @nodes.rotate_uv
    .call([g1_v2(), g1_fv(1)])
    .add(@nodes.rotate_uv.call([g1_v2(), g1_fv(1), @nodes.vec2(0.25)]))
  })
  add("spherize_uv", fn() { @nodes.spherize_uv.call([g1_v2(), g1_fv(1)]) })
  add("remap", fn() {
    @nodes.remap
    .call([g1_fv(0.5), 0, 1])
    .add(g1_fv(0.5).remap(0, 1, out_low_node=2, out_high_node=3))
    .add(g1_fv(0.5).remap(0, 1, out_low_node=2, out_high_node=3, do_clamp=true))
  })
  add("remap_clamp", fn() {
    @nodes.remap_clamp(g1_fv(0.5), 0, 1).add(
      g1_v3().remap_clamp(0, 2, out_low_node=-1, out_high_node=1),
    )
  })

  // --- Timer, oscillators, packing
  add("timer", fn() {
    @nodes.vec3_of([
      @nodes.time,
      @nodes.delta_time,
      @nodes.float(@nodes.frame_id),
    ])
  })
  add("oscillators", fn() {
    @nodes.vec4_of([
      @nodes.osc_sine(),
      @nodes.osc_square(),
      @nodes.osc_triangle(),
      @nodes.osc_sawtooth(t=g1_fv(2)),
    ])
  })
  add("packing", fn() {
    @nodes.pack_normal_to_rgb(g1_v3())
    .add(@nodes.unpack_rgb_to_normal(g1_v3()))
    .add(@nodes.unpack_normal(g1_v2()))
  })

  // --- Discard, debug, events, overloading, range
  add("discard", fn() {
    @nodes.fn_(fn(_, _) {
      let x = g1_fv(1)
      @nodes.discard(conditional=x.greater_than(2))
      x.less_than(0).discard()
      @nodes.if_(x.equal(5), fn() { @nodes.discard() }) |> ignore
      @nodes.return_()
      Some(x)
    }).call([])
  })
  add("debug", fn() {
    let snippets = []
    let d = @nodes.debug_(g1_v3().add(1), callback=fn(_, snippet) {
      snippets.push(snippet)
    })
    d.mul(2)
  })
  add("events", fn() {
    @nodes.fn_(fn(_, _) {
      @nodes.on_object_update(fn(_) {  }) |> ignore
      @nodes.on_material_update(fn(_) {  }) |> ignore
      @nodes.on_frame_update(fn(_) {  }) |> ignore
      @nodes.on_before_object_update(fn(_) {  }) |> ignore
      @nodes.on_after_object_update(fn(_) {  }) |> ignore
      @nodes.on_before_material_update(fn(_) {  }) |> ignore
      @nodes.on_before_frame_update(fn(_) {  }) |> ignore
      @nodes.on_before_render_pipeline(fn() {  }) |> ignore
      @nodes.on_after_render_pipeline(fn() {  }) |> ignore
      Some(g1_fv(1))
    }).call([])
  })
  let ov_float = @nodes.fn_(
    fn(inputs, _) { Some(g1_arg(inputs, 0).mul(2)) },
    layout=@nodes.FnLayout::short([("a", "float")], return_="float"),
  ).set_layout(name="ovFloat", type_="float", inputs=[("a", "float")])
  let ov_vec3 = @nodes.fn_(fn(inputs, _) { Some(g1_arg(inputs, 0).mul(3)) }).set_layout(
    name="ovVec3",
    type_="vec3",
    inputs=[("a", "vec3")],
  )
  let ov_pair = @nodes.fn_(fn(inputs, _) {
    Some(g1_arg(inputs, 0).add(g1_arg(inputs, 1)))
  }).set_layout(name="ovPair", type_="vec3", inputs=[
    ("a", "vec3"),
    ("b", "float"),
  ])
  let overloaded = @nodes.overloading_fn([ov_float, ov_vec3, ov_pair])
  add("overloading", fn() {
    @nodes.vec3(overloaded([g1_fv(1)]))
    .add(overloaded([g1_v3()]))
    .add(overloaded([g1_v3(), g1_fv(2)]))
  })
  add("range", fn() {
    @nodes.range(0, 1)
    .add(
      @nodes.range(
        @math.Vector3::new(0.0, 1.0, 2.0),
        @math.Vector3::new(1.0, 2.0, 3.0),
      ).x(),
    )
    .add(
      @nodes.range(
        @math.Color::new(1.0, 0.0, 0.0),
        @math.Color::new(0.0, 0.0, 1.0),
      ).y(),
    )
  })
  add("range_vec_mix", fn() { @nodes.range(0, @nodes.vec3_of([1, 2, 3])) })
  // --- More type combinations
  both("op_add_int_float_var", fn() { g1_iv(1).add(g1_fv(2)) })
  both("op_mod_ivec_uvec", fn() {
    @nodes.ivec2_of([5, 6])
    .to_var()
    .mod(4)
    .add(
      @nodes.ivec2(
        @nodes.uvec2_of([7, 8]).to_var().mod(@nodes.uvec2_of([3, 3])),
      ),
    )
  })
  both("op_shift_ivec", fn() {
    @nodes.ivec3_of([1, 2, 3])
    .to_var()
    .shift_left(@nodes.ivec3_of([1, 1, 1]).to_var())
  })
  both("op_color_float", fn() { @nodes.color(0xff0000).to_var().mul(g1_fv(2)) })
  both("op_compare_int_float", fn() { g1_iv(1).less_than(g1_fv(2)) })
  both("op_compare_bvec_glsl_eq", fn() {
    @nodes.bvec2_of([true, false]).to_var().equal(@nodes.bvec2_of([true, true]))
  })
  both("op_mat_void_statement", fn() {
    @nodes.fn_(fn(_, _) {
      let m = g1_m3()
      m.mul(g1_fv(2)) |> ignore
      m.mul(m) |> ignore
      Some(m)
    }).call([])
  })
  add("op_void_operand", fn() {
    @nodes.fn_(fn(_, _) {
      @nodes.add(@nodes.expression("foo()"), g1_fv(1)) |> ignore
      Some(g1_fv(2))
    }).call([])
  })
  both("math_mix_int", fn() { @nodes.mix(g1_iv(1), g1_iv(2), 0.5) })
  both("math_dot_ivec2", fn() {
    @nodes.ivec2_of([1, 2]).to_var().dot(@nodes.ivec2_of([3, 4]))
  })
  both("math_cross_vec2", fn() { g1_v2().cross(@nodes.vec2_of([0, 1])) })
  add("math_abs_mat3", fn() { g1_m3().abs() })
  both("math_min_uvec_int", fn() {
    @nodes.uvec2_of([1, 2]).to_var().min(g1_iv(1))
  })
  both("math_pow_vec3_int", fn() { g1_v3().pow(g1_iv(2)) })
  add("cond_uniform_flow_no_else", fn() {
    g1_fv(1).greater_than(0).select(g1_fv(3)).uniform_flow()
  })
  add("cond_type_before_setup", fn() {
    @nodes.transform_direction(
      @nodes.select(@nodes.bool(true).to_var(), g1_m4(), else_node=g1_m4()),
      g1_v3(),
    )
  })
  add("loop_float_count", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([g1_fv(3), g1_uv(2)], fn(inputs) {
        let i = g1_named(inputs, "i")
        let j = g1_named(inputs, "j")
        s.add_assign(@nodes.float(i.add(j)))
      })
      Some(s)
    }).call([])
  })
  add("loop_nested", fn() {
    @nodes.fn_(fn(_, _) {
      let s = g1_fv(0)
      @nodes.loop_([2], fn(inputs) {
        let i = g1_named(inputs, "i")
        @nodes.loop_([@nodes.loop_range(start=g1_iv(0), end=i, name="k")], fn(
          inputs,
        ) {
          s.add_assign(@nodes.float(g1_named(inputs, "k")))
        })
      })
      Some(s)
    }).call([])
  })
  let ptr_fn = @nodes.wgsl_fn(
    "fn usePtr( p : pointer, s : float ) -> float { return s; }",
  )
  add("code_pointer_param", fn() { ptr_fn.call([g1_fv(1), g1_fv(2)]) })
  let get_one = @nodes.wgsl_fn("fn getOne(  ) -> float { return 1.0; }")
  add("code_function_node_value", fn() {
    @nodes.vec2_of([get_one, get_one.call([])])
  })
  add("bitcast_vec_conversion", fn() {
    @nodes.bitcast(g1_v3(), "uint").add(
      @nodes.bitcast(@nodes.ivec2_of([1, 2]).to_var(), "vec2").x(),
    )
  })
  push(
    "bitcount_trailing_int_glsl",
    fn() {
      @nodes.count_trailing_zeros(g1_iv(4)).add(
        @nodes.count_leading_zeros(@nodes.uvec2_of([1, 2]).to_var()).x(),
      )
    },
    true,
    "fragment",
  )
  add("max_mip_level", fn() { @nodes.max_mip_level(@nodes.uniform(1)).add(1) })
  both("pp_view_position", fn() {
    @nodes.get_view_position.call([g1_v2(), g1_fv(0.5), g1_m4()])
  })
  push_reversed(
    "pp_view_position_reversed",
    fn() { @nodes.get_view_position.call([g1_v2(), g1_fv(0.5), g1_m4()]) },
    true,
  )
  add("pp_background_depth", fn() {
    @nodes.vec2_of([@nodes.is_background_depth.call([g1_fv(1)]), 0])
  })
  push_reversed(
    "pp_background_depth_reversed",
    fn() { @nodes.vec2_of([@nodes.is_background_depth.call([g1_fv(0)]), 0]) },
    false,
  )
  add("pp_screen_position", fn() {
    @nodes.get_screen_position
    .call([g1_v3(), g1_m4()])
    .add(@nodes.get_screen_position_from_clip.call([g1_v4()]))
  })
  add("pp_noise_vogel", fn() {
    @nodes.vogel_disk_sample
    .call([g1_iv(1), g1_iv(8), g1_fv(0.5)])
    .mul(@nodes.interleaved_gradient_noise.call([g1_v2()]))
  })
  // --- Nodes built on accessors (a mesh, a camera and the node material context)
  let tex = fn() {
    let t = @core.Texture::new()
    t.name = "tex"
    t
  }
  add_mesh("equirect_uv", fn() {
    @nodes.equirect_uv.call([]).add(@nodes.equirect_uv.call([g1_v3()]))
  })
  add_mesh("equirect_direction", fn() {
    @nodes.equirect_direction
    .call([])
    .add(@nodes.equirect_direction.call([g1_v2()]))
  })
  add_mesh("matcap_uv", fn() { @nodes.matcap_uv })
  add_mesh("spritesheet_uv", fn() {
    @nodes.spritesheet_uv
    .call([@nodes.vec2_of([4, 2]).to_var()])
    .add(
      @nodes.spritesheet_uv.call([@nodes.vec2_of([4, 2]), g1_v2(), g1_fv(3)]),
    )
  })
  add_mesh("triplanar_one", fn() {
    @nodes.triplanar_textures.call([@nodes.texture(tex())])
  })
  add_mesh("triplanar_three", fn() {
    @nodes.triplanar_texture([
      @nodes.texture(tex()),
      @nodes.texture(tex()),
      @nodes.texture(tex()),
      g1_fv(2),
      g1_v3(),
      g1_v3(),
    ])
  })
  push_mesh(
    "billboarding",
    fn() { @nodes.billboarding.call([]) },
    "vertex",
    false,
  )
  push_mesh(
    "billboarding_rotation",
    fn() { @nodes.billboarding.call_named({ "horizontalRotation": true }) },
    "vertex",
    false,
  )
  push_mesh(
    "billboarding_position",
    fn() {
      @nodes.billboarding.call_named({
        "position": g1_v3(),
        "horizontal": false,
        "vertical": true,
      })
    },
    "vertex",
    false,
  )
  add_mesh("checker", fn() {
    @nodes.checker.call([]).add(@nodes.checker.call([g1_v2()]))
  })
  add_mesh("sample_node", fn() { @nodes.sample(fn(uv) { uv.mul(2) }) })
  add_mesh("replace_default_uv", fn() {
    @nodes.replace_default_uv(
      fn(_, _) { @nodes.vec2_of([0.25, 0.75]) },
      node=@nodes.texture(tex()),
    )
  })
  add_mesh("fog_factors", fn() {
    @nodes.vec3_of([
      @nodes.range_fog_factor.call([1, 10]),
      @nodes.density_fog_factor.call([g1_fv(0.1)]),
      @nodes.exponential_height_fog_factor.call([g1_fv(0.1), g1_fv(2)]),
    ])
  })
  add_mesh("fog_view_z", fn() {
    let get_view_z : @nodes.ContextGetViewZ = { f: fn(_) { Some(g1_fv(5)) }, }
    @nodes.context(
      node=@nodes.range_fog_factor.call([1, 10]),
      value=@nodes.node_context([
        ("getViewZ", Other(@core.JsValue::of(get_view_z))),
      ]),
    )
  })
  add_mesh("fog_color", fn() {
    @nodes.fog.call([@nodes.color(0x888888), g1_fv(0.5)])
  })
  add_mesh("normal_from_depth", fn() {
    @nodes.get_normal_from_depth.call([g1_v2(), @nodes.texture(tex()), g1_m4()])
  })
  push_mesh(
    "storage_element",
    fn() {
      @nodes.storage_element(
        @nodes.storage(
          @nodes.StorageBufferAttribute::new(4, 4),
          type_="vec4",
          count=4,
        ),
        g1_iv(1),
      )
    },
    "fragment",
    true,
  )
  add_mesh("storage_element_no_storage", fn() {
    @nodes.storage_element(
      @nodes.storage(
        @nodes.StorageBufferAttribute::new(4, 4),
        type_="vec4",
        count=4,
      ),
      g1_iv(1),
    )
  })
  let cube_tex = fn() {
    let t = @core.CubeTexture::new()
    t.name = "cube"
    t
  }
  let equirect = fn() {
    let t = @core.Texture::new()
    t.mapping = @core.EquirectangularReflectionMapping
    t
  }
  add_mesh("cube_map_cube", fn() {
    @nodes.cube_map_node(@nodes.cube_texture(cube_tex()))
  })
  add_mesh("cube_map_equirect_not_ready", fn() {
    @nodes.cube_map_node(@nodes.texture(equirect()))
  })
  add("cond_guard_var_reuse", fn() {
    @nodes.fn_(fn(_, _) {
      let r = g1_fv(0)
      let c = @nodes.bool(true).to_const()
      let v : Ref[@nodes.Node?] = Ref(None)
      @nodes.if_(c, fn() {
        v.val = Some(g1_fv(5).to_var())
        r.assign(v.val.unwrap())
      }).else_(fn() { r.assign(v.val.unwrap().add(1)) })
      @nodes.if_(c, fn() { r.add_assign(v.val.unwrap()) }) |> ignore
      Some(r)
    }).call([])
  })
  // added by G6 once screenUV and the renderer were available
  add_mesh("viewport_safe_uv_arg", fn() {
    @nodes.viewport_safe_uv.call([@nodes.screen_uv.mul(0.5)])
  })
  // no argument: `[ uv = null ]`, so the depth texture samples its default uv()
  add_mesh("viewport_safe_uv_none", fn() { @nodes.viewport_safe_uv.call([]) })
  add_mesh("shape_circle", fn() { @nodes.shape_circle.call([]) })
  add_mesh("shape_circle_coord", fn() {
    @nodes.shape_circle.call([@nodes.uv().mul(2)])
  })
  scenarios
}

///|
test "g1 shader scenarios run (compared with upstream by run.mjs)" {
  let scenarios = g1_scenarios()
  let wgsl_renderer = @nodes.Renderer::foundation_stub()
  let glsl_renderer = @nodes.Renderer::foundation_stub()
  glsl_renderer.backend.class_ = G1GlslBackend::{ }
  for scenario in scenarios {
    let renderer = if scenario.glsl { glsl_renderer } else { wgsl_renderer }
    renderer.reversed_depth_buffer = scenario.reversed
    let object : @nodes.BuilderObject = if scenario.mesh {
      Object3D(
        @core.Mesh::new(
          geometry=g1_geometry,
          material=Single(@core.MeshBasicMaterial::new()),
        ),
      )
    } else {
      NoObject
    }
    let b = @nodes.NodeBuilder::new(object, renderer, Some(g1_parser()), class_=G1Builder::{
      glsl: scenario.glsl,
      storage: scenario.storage,
    })
    if scenario.mesh {
      b.camera = Some(@core.PerspectiveCamera::new())
      g1_material_context(b)
    }
    b.set_shader_stage(Some(scenario.stage))
    let flow = b.flow_stages_node((scenario.make)())
    renderer.reversed_depth_buffer = false
    let uniforms = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in b.uniforms.stage(stage) {
        uniforms.push("\{stage}:\{u.name}:\{u.type_}")
      }
    }
    let record = g1_shader_json(
      flow.code,
      flow.result_snippet(),
      flow.vars.unwrap_or(""),
      FixedArray::from_array(uniforms),
      b.get_codes(scenario.stage),
    )
    if g1_shader_diff_enabled() {
      println("@@SHADER \{scenario.name} \{record}")
    }
  }
}
