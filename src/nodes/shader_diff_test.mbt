// MoonBit side of the shader differential test. Each scenario builds the same node
// graph as the upstream scenario of the same name (diff/core/webgpu/
// shader_diff/upstream.mjs) and runs `flowStagesNode` on a base
// NodeBuilder in the fragment stage. With SHADER_DIFF=1 every record is printed as
// `@@SHADER <name> <json>` for `node shader_diff/run.mjs`, which compares them byte for byte.

///|
extern "js" fn shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn shader_json(
  code : String,
  result : String,
  vars : String,
  uniforms : Array[String],
) -> String = "(code, result, vars, uniforms) => JSON.stringify({ code, result, vars, uniforms })"

///|
/// `record( builder, flow )` of upstream.mjs.
fn shader_record(b : @nodes.NodeBuilder, flow : @nodes.FlowData) -> String {
  let uniforms = []
  for stage in ["vertex", "fragment", "compute"] {
    for u in b.uniforms.stage(stage) {
      uniforms.push("\{stage}:\{u.name}:\{u.type_}")
    }
  }
  shader_json(
    flow.code,
    flow.result_snippet(),
    flow.vars.unwrap_or(""),
    uniforms,
  )
}

///|
fn shader_scenarios() -> Array[(String, () -> @nodes.Node)] {
  [
    ("const_float", fn() { @nodes.float(1.5) }),
    ("const_small", fn() { @nodes.float(1.0e-7) }),
    ("const_negative_zero", fn() { @nodes.float(-0.0) }),
    ("vec3_numbers", fn() { @nodes.vec3_of([1, 2, 3]) }),
    ("vec3_splat", fn() { @nodes.vec3(0.5) }),
    ("vec3_join_var", fn() { @nodes.vec3_of([@nodes.float(1).to_var(), 2, 3]) }),
    ("vec4_convert", fn() { @nodes.vec4(@nodes.vec3_of([1, 2, 3]).to_var()) }),
    ("color_hex", fn() { @nodes.color(0xff8800) }),
    ("mat3_identity", fn() { @nodes.mat3_of([]) }),
    ("int_of_var", fn() { @nodes.int(@nodes.float(2.5).to_var()) }),
    ("uint_bool", fn() { @nodes.vec2_of([@nodes.uint(3), @nodes.bool(1)]) }),
    ("swizzle_chain", fn() { @nodes.vec4_of([1, 2, 3, 4]).to_var().zyx().xy() }),
    (
      "swizzle_rgba",
      fn() { @nodes.vec4_of([1, 2, 3, 4]).to_var(name="c").bgr() },
    ),
    ("set_flip", fn() { @nodes.vec3_of([1, 2, 3]).to_var().set_y(5).flip_x() }),
    (
      "var_named_reuse",
      fn() {
        let v = @nodes.float(2).to_var(name="v")
        @nodes.vec2_of([v, v])
      },
    ),
    ("const_named", fn() { @nodes.vec3(1).to_const(name="k") }),
    (
      "var_shared_expression",
      fn() {
        let s = @nodes.vec3_of([@nodes.float(1).to_var(), 2, 3])
        @nodes.vec2_of([s.x(), s.y()])
      },
    ),
    (
      "uniforms",
      fn() {
        @nodes.vec2_of([
          @nodes.uniform(1.0),
          @nodes.uniform(2).set_name("scale"),
        ])
      },
    ),
    ("uniform_color", fn() { @nodes.uniform(@nodes.color(0x336699)) }),
    ("element_index", fn() { @nodes.vec4_of([1, 2, 3, 4]).to_var()[1] }),
    ("element_float", fn() { @nodes.vec4_of([1, 2, 3, 4]).to_var().element(2) }),
    (
      "convert_types",
      fn() { @nodes.convert(@nodes.vec2_of([1, 2]).to_var(), "vec3") },
    ),
    (
      "array_values",
      fn() { @nodes.array([@nodes.float(1), @nodes.float(2), @nodes.float(3)]) },
    ),
    (
      "context_plain",
      fn() {
        @nodes.context(
          node=@nodes.vec3_of([1, 2, 3]).to_var(),
          value=@nodes.NodeContext::new(),
        )
      },
    ),
    (
      "fn_inline",
      fn() {
        @nodes.fn_(fn(inputs, _) {
          let v = inputs.get(0).unwrap().to_var()
          v.assign(@nodes.vec3(1))
          Some(v)
        }).call([@nodes.vec3_of([1, 2, 3])])
      },
    ),
    (
      "fn_assign_property",
      fn() {
        @nodes.fn_(fn(_, _) {
          let p = @nodes.property("vec3", name="Foo")
          p.assign(@nodes.vec3_of([4, 5, 6]))
          Some(p.yz())
        }).call([])
      },
    ),
    (
      "fn_default_parameter",
      fn() {
        @nodes.fn_(fn(inputs, _) {
          let a = inputs.get(0).or_else(fn() { @nodes.float(7) })
          Some(a.to_var(name="d"))
        }).call([])
      },
    ),
  ]
}

///|
test "shader scenarios run (compared with upstream by run.mjs)" {
  for scenario in shader_scenarios() {
    let (name, make) = scenario
    let b = @nodes.NodeBuilder::new(
      NoObject,
      @nodes.Renderer::foundation_stub(),
      None,
    )
    b.set_shader_stage(Some("fragment"))
    let flow = b.flow_stages_node(make())
    let record = shader_record(b, flow)
    if shader_diff_enabled() {
      println("@@SHADER \{name} \{record}")
    }
  }
}
