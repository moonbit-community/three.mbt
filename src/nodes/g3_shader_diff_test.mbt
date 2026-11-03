// MoonBit side of the G3 shader scenarios (nodes/lighting, nodes/functions, nodes/pmrem,
// nodes/materialx). The upstream side is
// diff/core/webgpu/shader_diff/upstream_g3.mjs; `node shader_diff/run.mjs g3_...` compares them byte for byte.
//
// Both sides build with `G3Builder`: a NodeBuilder class whose `buildFunctionCode`
// writes layout functions in a WGSL-like form that `g3_parser` reads back, whose
// `getTernary` prints a `select` and whose texture methods print their arguments, with
// the WebGPU renderer stub. Records add `codes`.

///|
extern "js" fn g3_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn g3_shader_json(
  code : String,
  result : String,
  vars : String,
  uniforms : Array[String],
  codes : String,
) -> String = "(code, result, vars, uniforms, codes) => JSON.stringify({ code, result, vars, uniforms, codes })"

///|
/// `g3ParseFunction` of upstream_g3.mjs, verbatim: `[ name, type, [ [ name, type ] ] ]`.
extern "js" fn g3_parse_function(source : String) -> @core.JsValue =
  #|( source ) => {
  #|	const m = /^fn (\w+)\( (.*?) \) -> (\w+) \{/.exec( source );
  #|	const inputs = m[ 2 ] === '' ? [] : m[ 2 ].split( ', ' ).map( ( p ) => p.split( ' : ' ) );
  #|	return [ m[ 1 ], m[ 3 ], inputs ];
  #|}

///|
/// `g3FunctionCode` of upstream_g3.mjs, verbatim.
extern "js" fn g3_function_code(
  source : String,
  name : String,
  new_name : String,
) -> String = "( source, name, newName ) => source.replace( 'fn ' + name + '(', 'fn ' + newName + '(' )"

///|
extern "js" fn g3_js_get(value : @core.JsValue, i : Int32) -> @core.JsValue = "(v, i) => v[ i ]"

///|
extern "js" fn g3_js_length(value : @core.JsValue) -> Int32 = "(v) => v.length"

///|
/// `G3Parser`: a `G3Function` per source.
fn g3_parser() -> @nodes.NodeParser {
  {
    parse_function_impl: Some(fn(source) {
      let parsed = g3_parse_function(source)
      let name : String = g3_js_get(parsed, 0).cast()
      let type_ : String = g3_js_get(parsed, 1).cast()
      let params = g3_js_get(parsed, 2)
      let inputs = []
      for i in 0..<g3_js_length(params) {
        let p = g3_js_get(params, i)
        inputs.push(
          @nodes.NodeFunctionInput::new(
            g3_js_get(p, 1).cast(),
            g3_js_get(p, 0).cast(),
          ),
        )
      }
      let f = @nodes.NodeFunction::new(type_, inputs, name~)
      f.payload = @core.JsValue::of(source)
      f.get_code_impl = Some(fn(f, new_name) {
        g3_function_code(f.payload.cast(), f.name, new_name)
      })
      f
    }),
  }
}

///|
/// `fmt( v )` of upstream_g3.mjs: `-` for null/undefined.
fn g3_fmt(v : String?) -> String {
  match v {
    Some(s) => s
    None => "-"
  }
}

///|
struct G3Builder {}

///|
impl @nodes.NodeBuilderClass for G3Builder with fn class_name(_) {
  "G3Builder"
}

///|
impl @nodes.NodeBuilderClass for G3Builder with fn get_ternary(_, _, c, a, b) {
  Some("select( \{b}, \{a}, \{c} )")
}

///|
impl @nodes.NodeBuilderClass for G3Builder with fn generate_texture(
  _,
  _,
  _,
  p,
  uv,
  depth,
  offset,
  _,
) {
  "tex(\{p}, \{uv}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G3Builder with fn generate_texture_level(
  _,
  _,
  _,
  p,
  uv,
  level,
  depth,
  offset,
) {
  "texLevel(\{p}, \{uv}, \{level}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G3Builder with fn generate_texture_compare(
  _,
  _,
  _,
  p,
  uv,
  compare,
  depth,
  offset,
  _,
) {
  "texCompare(\{p}, \{uv}, \{compare}, \{g3_fmt(depth)}, \{g3_fmt(offset)})"
}

///|
impl @nodes.NodeBuilderClass for G3Builder with fn build_function_code(
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
fn g3_fv(v : Double) -> @nodes.Node {
  @nodes.float(v).to_var()
}

///|
fn g3_v2(a : Double, b : Double) -> @nodes.Node {
  @nodes.vec2_of([a, b]).to_var()
}

///|
fn g3_v3(a : Double, b : Double, c : Double) -> @nodes.Node {
  @nodes.vec3_of([a, b, c]).to_var()
}

///|
fn g3_iv(v : Int32) -> @nodes.Node {
  @nodes.int(v).to_var()
}

///|
fn g3_m3_identity() -> @nodes.Node {
  @nodes.mat3_of([1, 0, 0, 0, 1, 0, 0, 0, 1])
}

///|
fn g3_rect_volume() -> @nodes.Node {
  @nodes.ltc_evaluate_volume.call_named({
    "P": g3_v3(0, 0, 0),
    "p0": g3_v3(1, 1, 1),
    "p1": g3_v3(-1, 1, 1),
    "p2": g3_v3(-1, -1, 1),
    "p3": g3_v3(1, -1, 1),
  })
}

///|
fn g3_rect_evaluate() -> @nodes.Node {
  @nodes.ltc_evaluate.call_named({
    "N": g3_v3(0, 0, 1),
    "V": g3_v3(0, 1, 0),
    "P": g3_v3(0, 0, 0),
    "mInv": g3_m3_identity(),
    "p0": g3_v3(1, 1, 1),
    "p1": g3_v3(-1, 1, 1),
    "p2": g3_v3(-1, -1, 1),
    "p3": g3_v3(1, -1, 1),
  })
}

///|
fn g3_scenarios() -> Array[(String, () -> @nodes.Node)] {
  let scenarios : Array[(String, () -> @nodes.Node)] = []
  let add = fn(name : String, make : () -> @nodes.Node) {
    scenarios.push(("g3_" + name, make))
  }

  // --- BSDF
  add("d_ggx", fn() {
    @nodes.d_ggx.call_named({ "alpha": g3_fv(0.25), "dotNH": g3_fv(0.75) })
  })
  add("d_ggx_anisotropic", fn() {
    @nodes.d_ggx_anisotropic.call_named({
      "alphaT": g3_fv(0.3),
      "alphaB": g3_fv(0.2),
      "dotNH": g3_fv(0.9),
      "dotTH": g3_fv(0.1),
      "dotBH": g3_fv(0.2),
    })
  })
  add("v_ggx_smith_correlated", fn() {
    @nodes.v_ggx_smith_correlated.call_named({
      "alpha": g3_fv(0.25),
      "dotNL": g3_fv(0.5),
      "dotNV": g3_fv(0.6),
    })
  })
  add("v_ggx_smith_correlated_anisotropic", fn() {
    @nodes.v_ggx_smith_correlated_anisotropic.call_named({
      "alphaT": g3_fv(0.3),
      "alphaB": g3_fv(0.2),
      "dotTV": g3_fv(0.1),
      "dotBV": g3_fv(0.2),
      "dotTL": g3_fv(0.3),
      "dotBL": g3_fv(0.4),
      "dotNV": g3_fv(0.5),
      "dotNL": g3_fv(0.6),
    })
  })
  add("f_schlick", fn() {
    @nodes.f_schlick.call_named({
      "f0": g3_v3(0.04, 0.04, 0.04),
      "f90": g3_fv(1),
      "dotVH": g3_fv(0.5),
    })
  })
  add("f_schlick_numbers", fn() {
    @nodes.f_schlick.call_named({
      "f0": @nodes.vec3(0.04),
      "f90": 1.0,
      "dotVH": g3_fv(0.5),
    })
  })
  add("schlick_to_f0", fn() {
    @nodes.schlick_to_f0.call_named({
      "f": g3_v3(0.1, 0.2, 0.3),
      "f90": 1.0,
      "dotVH": g3_fv(0.5),
    })
  })
  add("brdf_lambert", fn() {
    @nodes.brdf_lambert.call_named({ "diffuseColor": g3_v3(1, 0.5, 0.25) })
  })
  add("ltc_uv", fn() {
    @nodes.ltc_uv.call_named({
      "N": g3_v3(0, 0, 1),
      "V": g3_v3(0, 1, 0),
      "roughness": g3_fv(0.5),
    })
  })
  add("ltc_evaluate", g3_rect_evaluate)
  add("ltc_evaluate_volume", g3_rect_volume)
  add("ltc_evaluate_twice", fn() { g3_rect_evaluate().add(g3_rect_volume()) })

  // --- LightUtils, functions/material
  add("distance_attenuation", fn() {
    @nodes.get_distance_attenuation.call_named({
      "lightDistance": g3_fv(3),
      "cutoffDistance": g3_fv(10),
      "decayExponent": g3_fv(2),
    })
  })
  add("alpha_hash_threshold", fn() {
    @nodes.get_alpha_hash_threshold.call([g3_v3(1, 2, 3)])
  })
  add("sh_irradiance_at", fn() {
    @nodes.get_sh_irradiance_at.call([
      g3_v3(0, 1, 0),
      @nodes.array([
        @nodes.vec3(1),
        @nodes.vec3(2),
        @nodes.vec3(3),
        @nodes.vec3(4),
        @nodes.vec3(5),
        @nodes.vec3(6),
        @nodes.vec3(7),
        @nodes.vec3(8),
        @nodes.vec3(9),
      ]).to_var(),
    ])
  })

  // --- MaterialX
  add("mx_perlin_noise_float_2d", fn() {
    @nodes.mx_perlin_noise_float([g3_v2(0.5, 0.25)])
  })
  add("mx_perlin_noise_float_3d", fn() {
    @nodes.mx_perlin_noise_float([g3_v3(0.5, 0.25, 0.125)])
  })
  add("mx_perlin_noise_vec3_3d", fn() {
    @nodes.mx_perlin_noise_vec3([g3_v3(0.5, 0.25, 0.125)])
  })
  add("mx_cell_noise_float_2d", fn() {
    @nodes.mx_cell_noise_float_impl([g3_v2(0.5, 0.25)])
  })
  add("mx_cell_noise_vec3_3d", fn() {
    @nodes.mx_cell_noise_vec3_impl([g3_v3(0.5, 0.25, 0.125)])
  })
  add("mx_fractal_noise_float", fn() {
    @nodes.mx_fractal_noise_float_impl.call([
      g3_v3(0.5, 0.25, 0.125),
      g3_iv(3),
      g3_fv(2),
      g3_fv(0.5),
    ])
  })
  add("mx_fractal_noise_vec4", fn() {
    @nodes.mx_fractal_noise_vec4_impl.call([
      g3_v3(0.5, 0.25, 0.125),
      g3_iv(3),
      g3_fv(2),
      g3_fv(0.5),
    ])
  })
  add("mx_worley_noise_float_2d", fn() {
    @nodes.mx_worley_noise_float_impl([g3_v2(0.5, 0.25), g3_fv(1), g3_iv(0)])
  })
  add("mx_worley_noise_vec3_3d", fn() {
    @nodes.mx_worley_noise_vec3_impl([
      g3_v3(0.5, 0.25, 0.125),
      g3_fv(1),
      g3_iv(0),
    ])
  })
  add("mx_unifiednoise2d", fn() {
    @nodes.mx_unifiednoise2d_impl.call([
      g3_iv(1),
      g3_v2(0.5, 0.25),
      g3_v2(1, 1),
      g3_v2(0, 0),
      g3_fv(1),
      g3_fv(0),
      g3_fv(1),
      g3_fv(0),
      g3_iv(3),
      g3_fv(2),
      g3_fv(0.5),
      g3_iv(0),
    ])
  })
  add("mx_unifiednoise3d", fn() {
    @nodes.mx_unifiednoise3d_impl.call([
      g3_iv(2),
      g3_v3(0.5, 0.25, 0.125),
      g3_v3(1, 1, 1),
      g3_v3(0, 0, 0),
      g3_fv(1),
      g3_fv(0),
      g3_fv(1),
      g3_fv(0),
      g3_iv(3),
      g3_fv(2),
      g3_fv(0.5),
      g3_iv(0),
    ])
  })
  add("mx_hsvtorgb", fn() { @nodes.mx_hsvtorgb.call([g3_v3(0.5, 0.25, 0.75)]) })
  add("mx_rgbtohsv", fn() { @nodes.mx_rgbtohsv.call([g3_v3(0.5, 0.25, 0.75)]) })
  add("mx_srgb_texture_to_lin_rec709", fn() {
    @nodes.mx_srgb_texture_to_lin_rec709.call([g3_v3(0.5, 0.25, 0.75)])
  })
  scenarios
}

///|
test "g3 shader scenarios run (compared with upstream by run.mjs)" {
  for scenario in g3_scenarios() {
    let (name, make) = scenario
    // a renderer per scenario: layout functions are cached per backend
    let b = @nodes.NodeBuilder::new(
      NoObject,
      @nodes.Renderer::foundation_stub(),
      Some(g3_parser()),
      class_=G3Builder::{ },
    )
    b.set_shader_stage(Some("fragment"))
    let flow = b.flow_stages_node(make())
    let uniforms = []
    for stage in ["vertex", "fragment", "compute"] {
      for u in b.uniforms.stage(stage) {
        uniforms.push("\{stage}:\{u.name}:\{u.type_}")
      }
    }
    let record = g3_shader_json(
      flow.code,
      flow.result_snippet(),
      flow.vars.unwrap_or(""),
      uniforms,
      b.get_codes("fragment"),
    )
    if g3_shader_diff_enabled() {
      println("@@SHADER \{name} \{record}")
    }
  }
}
