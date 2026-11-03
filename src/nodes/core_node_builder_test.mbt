// Pure helpers of NodeBuilder; expected values come from upstream NodeBuilder.js run in
// Node (`new NodeBuilder( null, undefined )`).

///|
fn str(type_ : String?) -> String {
  match type_ {
    Some(s) => s
    None => "null"
  }
}

///|
test "NodeBuilder pure helpers match upstream" {
  let b = @nodes.NodeBuilder::new(
    NoObject,
    @nodes.Renderer::foundation_stub(),
    None,
  )
  let failures = []
  let check = fn(actual : String, expected : String) {
    if actual != expected {
      failures.push("expected \{expected}, got \{actual}")
    }
  }
  check(b.format("x", Some("float"), Some("vec3")), "vec3( x )")
  check(b.format("x", Some("vec3"), Some("float")), "x.x")
  check(b.format("x", Some("vec4"), Some("vec3")), "x.xyz")
  check(
    b.format("x", Some("vec2"), Some("vec4")),
    "vec4( vec3( x, 0.0 ), 1.0 )",
  )
  check(b.format("x", Some("vec3"), Some("vec4")), "vec4( x, 1.0 )")
  check(b.format("x", Some("vec2"), Some("vec3")), "vec3( x, 0.0 )")
  check(b.format("x", Some("int"), Some("vec3")), "vec3( float( x ) )")
  check(b.format("x", Some("uint"), Some("uvec2")), "uvec2( x )")
  check(
    b.format("m", Some("mat4"), Some("mat3")),
    "mat3( m[ 0 ].xyz, m[ 1 ].xyz, m[ 2 ].xyz )",
  )
  check(
    b.format("m", Some("mat3"), Some("mat2")),
    "mat2( m[ 0 ].xy, m[ 1 ].xy )",
  )
  check(b.format("x", Some("vec3"), Some("bool")), "bool( all( x ) )")
  check(b.format("x", Some("bvec3"), Some("vec3")), "vec3( x )")
  check(b.format("x", Some("float"), Some("color")), "vec3( x )")
  check(b.format("x", Some("vec4"), Some("void")), "x")
  check(b.format("x", None, Some("vec3")), "vec3( x )")
  check(b.format("x", Some("vec3"), None), "x")
  check(b.format("x", Some("float"), Some("int")), "int( x )")
  check(b.format("x", Some("ivec3"), Some("vec2")), "vec2( x.xy )")
  check(b.format("x", Some("bool"), Some("bvec4")), "bvec4( x )")
  check(
    b.format("x", Some("bvec2"), Some("bvec4")),
    "bvec4( bvec3( x, false ), true )",
  )
  check(b.format("x", Some("ivec2"), Some("ivec3")), "ivec3( x, 0 )")
  check(b.format("x", Some("float"), Some("mat3")), "x")
  check(b.format("x", Some("vec4"), Some("ivec4")), "ivec4( x )")
  check(b.get_type_length(Some("float")).to_string(), "1")
  check(b.get_type_length(Some("vec2")).to_string(), "2")
  check(b.get_type_length(Some("ivec3")).to_string(), "3")
  check(b.get_type_length(Some("mat2")).to_string(), "4")
  check(b.get_type_length(Some("mat3")).to_string(), "9")
  check(b.get_type_length(Some("mat4")).to_string(), "16")
  check(b.get_type_length(Some("color")).to_string(), "3")
  check(b.get_type_length(Some("texture")).to_string(), "4")
  check(b.get_type_length(Some("void")).to_string(), "0")
  check(b.get_type_length(None).to_string(), "0")
  check(b.get_type_length(Some("bvec4")).to_string(), "4")
  check(b.get_type_length(Some("uint")).to_string(), "1")
  check(b.get_type_length(Some("bool")).to_string(), "1")
  check(b.get_type_length(Some("uvec2")).to_string(), "2")
  check(str(b.get_vector_type(Some("color"))), "vec3")
  check(str(b.get_vector_type(Some("texture"))), "vec4")
  check(str(b.get_vector_type(Some("cubeTexture"))), "vec4")
  check(str(b.get_vector_type(Some("storageTexture"))), "vec4")
  check(str(b.get_vector_type(Some("texture3D"))), "vec4")
  check(str(b.get_vector_type(Some("depthTexture"))), "depthTexture")
  check(str(b.get_vector_type(Some("vec2"))), "vec2")
  check(str(b.get_vector_type(None)), "null")
  check(b.generate_const("float", value=Number(1.0e-7)), "1e-7")
  check(b.generate_const("float", value=Number(0.1)), "0.1")
  check(b.generate_const("float", value=Number(3.0)), "3.0")
  check(b.generate_const("float", value=Number(-0.0)), "0.0")
  check(b.generate_const("float", value=Number(1.0e21)), "1e21")
  check(b.generate_const("float", value=Number(1.5e-10)), "1.5e-10")
  check(b.generate_const("float", value=Number(-2.5)), "-2.5")
  check(
    b.generate_const("float", value=Number(1.0 / 3.0)),
    "0.3333333333333333",
  )
  check(b.generate_const("float", value=Bool(true)), "true")
  check(b.generate_const("int", value=Number(3.7)), "3")
  check(b.generate_const("int", value=Number(-3.7)), "-3")
  check(b.generate_const("uint", value=Number(-1.0)), "0u")
  check(b.generate_const("uint", value=Number(5.9)), "5u")
  check(b.generate_const("bool", value=Number(0.0)), "false")
  check(b.generate_const("bool", value=Number(1.0)), "true")
  check(b.generate_const("vec2"), "vec2( 0.0, 0.0 )")
  check(b.generate_const("vec3"), "vec3( 0.0, 0.0, 0.0 )")
  check(b.generate_const("vec4"), "vec4( 0.0, 0.0, 0.0, 1.0 )")
  check(b.generate_const("color"), "vec3( 1.0, 1.0, 1.0 )")
  check(b.generate_const("ivec3"), "ivec3( 0, 0, 0 )")
  check(b.generate_const("uvec4"), "uvec4( 0u, 0u, 0u, 1u )")
  check(b.generate_const("bvec2"), "bvec2( false, false )")
  check(b.generate_const("mat3"), "mat3()")
  check(
    b.generate_const("mat3", value=Matrix3(@math.Matrix3::new())),
    "mat3( 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0 )",
  )
  check(
    b.generate_const("vec3", value=Vector3(@math.Vector3::new(1.0, 2.5, -0.0))),
    "vec3( 1.0, 2.5, 0.0 )",
  )
  check(b.generate_const("float"), "0.0")
  check(b.generate_const("int"), "0")
  check(b.generate_const("uint"), "0u")
  check(b.generate_const("bool"), "false")
  check(
    b.generate_const("float", value=Number(123456789012.0)),
    "123456789012.0",
  )
  check(b.generate_const("float", value=Number(0.000001)), "0.000001")
  check(b.get_type_from_length(1), "float")
  check(b.get_type_from_length(2), "vec2")
  check(b.get_type_from_length(3, component_type="int"), "ivec3")
  check(b.get_type_from_length(4, component_type="uint"), "uvec4")
  check(b.get_type_from_length(9), "mat3")
  check(b.get_type_from_length(16), "mat4")
  check(b.get_type_from_length(4, component_type="bool"), "bvec4")
  check(b.get_type_from_length(5), "undefined")
  check(b.get_type_from_length(4, component_type="mat2"), "mmat4")
  check(b.get_type_from_length(1, component_type="int"), "int")
  check(str(b.get_component_type(Some("vec3"))), "float")
  check(str(b.get_component_type(Some("ivec2"))), "int")
  check(str(b.get_component_type(Some("uvec4"))), "uint")
  check(str(b.get_component_type(Some("bvec3"))), "bool")
  check(str(b.get_component_type(Some("mat3"))), "float")
  check(str(b.get_component_type(Some("float"))), "float")
  check(str(b.get_component_type(Some("color"))), "float")
  check(str(b.get_component_type(Some("void"))), "null")
  check(str(b.get_component_type(None)), "null")
  check(str(b.get_component_type(Some("texture"))), "float")
  check(str(b.get_element_type(Some("mat3"))), "vec3")
  check(str(b.get_element_type(Some("vec3"))), "float")
  check(str(b.get_element_type(Some("mat2"))), "vec2")
  check(str(b.get_element_type(Some("ivec4"))), "int")
  check(
    [
      b.is_vector(Some("vec3")),
      b.is_matrix(Some("vec3")),
      b.is_integer(Some("vec3")),
      b.is_scalar(Some("vec3")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "true false false false",
  )
  check(
    [
      b.is_vector(Some("float")),
      b.is_matrix(Some("float")),
      b.is_integer(Some("float")),
      b.is_scalar(Some("float")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "false false false true",
  )
  check(
    [
      b.is_vector(Some("mat3")),
      b.is_matrix(Some("mat3")),
      b.is_integer(Some("mat3")),
      b.is_scalar(Some("mat3")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "false true false false",
  )
  check(
    [
      b.is_vector(Some("ivec2")),
      b.is_matrix(Some("ivec2")),
      b.is_integer(Some("ivec2")),
      b.is_scalar(Some("ivec2")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "true false true false",
  )
  check(
    [
      b.is_vector(Some("int")),
      b.is_matrix(Some("int")),
      b.is_integer(Some("int")),
      b.is_scalar(Some("int")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "false false true true",
  )
  check(
    [
      b.is_vector(Some("uint")),
      b.is_matrix(Some("uint")),
      b.is_integer(Some("uint")),
      b.is_scalar(Some("uint")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "false false true true",
  )
  check(
    [
      b.is_vector(Some("uvec3")),
      b.is_matrix(Some("uvec3")),
      b.is_integer(Some("uvec3")),
      b.is_scalar(Some("uvec3")),
    ]
    .map(fn(x) { x.to_string() })
    .join(" "),
    "true false true false",
  )
  check(b.change_component_type("vec3", "int"), "ivec3")
  check(b.change_component_type("ivec2", "float"), "vec2")
  check(b.change_component_type("float", "uint"), "uint")
  check(b.change_component_type("mat3", "int"), "imat3")
  check(b.get_integer_type("vec3"), "ivec3")
  check(b.get_integer_type("ivec2"), "ivec2")
  check(b.get_integer_type("float"), "int")
  check(b.get_integer_type("uint"), "uint")
  check(b.get_vector_from_matrix("mat3"), "vec3")
  check(b.get_signature(), "// Three.js r187 - Node System\n")
  check(
    b.generate_array("vec2", Some(2)),
    "vec2[ 2 ]( vec2( 0.0, 0.0 ), vec2( 0.0, 0.0 ) )",
  )
  check(
    b.get_var("vec3", "v") +
    " | " +
    b.get_var("float", "a", count=4) +
    " | " +
    b.generate_const_statement("float", "c"),
    "vec3 v | float[ 4 ] a | const float c",
  )
  check(b.get_hash(), "0")
  assert_eq(failures, [])
}

///|
test "NodeBuilder base statements" {
  let b = @nodes.NodeBuilder::new(
    NoObject,
    @nodes.Renderer::foundation_stub(),
    None,
  )
  assert_eq(b.get_type("color"), "vec3")
  assert_eq(b.get_type("vec2"), "vec2")
  assert_eq(b.generate_array_declaration("float", None), "float[ null ]")
  assert_eq(b.get_vars("vertex"), "")
}

///|
fn flow_record(node : @nodes.Node) -> String {
  let b = @nodes.NodeBuilder::new(
    NoObject,
    @nodes.Renderer::foundation_stub(),
    None,
  )
  b.set_shader_stage(Some("fragment"))
  let flow = b.flow_stages_node(node)
  "\{flow.code}|\{flow.result_snippet()}|\{flow.vars.unwrap_or("")}"
}

///|
test "flowStagesNode matches upstream on small graphs" {
  // upstream: `new NodeBuilder( null, renderer ).flowStagesNode( node )` in 'fragment'
  assert_eq(flow_record(@nodes.float(1.5)), "|1.5|")
  assert_eq(flow_record(@nodes.vec3_of([1, 2, 3])), "|vec3( 1.0, 2.0, 3.0 )|")
  assert_eq(
    flow_record(@nodes.vec3_of([1, 2, 3]).to_var(name="a")),
    "\ta = vec3( 1.0, 2.0, 3.0 );\n|a|vec3 a;",
  )
  assert_eq(
    flow_record(@nodes.float(2).to_var()),
    "\tnodeVar0 = 2.0;\n|nodeVar0|float nodeVar0;",
  )
  assert_eq(flow_record(@nodes.uniform(2)), "|nodeUniform0|")
  assert_eq(
    flow_record(@nodes.vec3_of([1, 2, 3]).to_var().xy()),
    "\tnodeVar0 = vec3( 1.0, 2.0, 3.0 );\n|nodeVar0.xy|vec3 nodeVar0;",
  )
}

///|
test "declarations are renamed as upstream" {
  let b = @nodes.NodeBuilder::new(
    NoObject,
    @nodes.Renderer::foundation_stub(),
    None,
  )
  b.set_shader_stage(Some("fragment"))
  let n1 = @nodes.float(1)
  let n2 = @nodes.float(2)
  let n3 = @nodes.vec2_of([1, 2])
  let v1 = b.get_var_from_node(
    n1,
    Some("a"),
    None,
    None,
    false,
    false,
    "variable",
  )
  let v2 = b.get_var_from_node(
    n2,
    Some("a"),
    None,
    None,
    false,
    false,
    "variable",
  )
  let v3 = b.get_var_from_node(n3, None, None, None, true, false, "variable")
  let v4 = b.get_var_from_node(n3, None, None, None, false, false, "variable")
  let u = b.get_uniform_from_node(n1, "float")
  let u2 = b.get_uniform_from_node(n2, "vec3", shader_stage="vertex", name="a")
  let vy = b.get_varying_from_node(n3)
  let at = b.get_attribute("position", "vec3")
  let names = [
    v1.name,
    v2.name,
    v3.name,
    v4.name,
    u.name,
    u2.name,
    vy.name,
    vy.type_,
    at.name,
    b.get_vars("fragment"),
    b.get_codes("fragment"),
  ]
  // upstream (v3 there is created with an explicit `null` type)
  assert_eq(
    names.join("|"),
    "a|a_1|nodeConst0|nodeConst0|nodeUniform0|a_2|nodeVarying0|vec2|position|float a;\n\tfloat a_1;|",
  )
  assert_eq(
    b.generate_struct(
      "S",
      [
        @nodes.StructMember::new("a", "float"),
        @nodes.StructMember::new("b", "vec2"),
      ],
      values=[Some(@nodes.float(3)), None],
    ),
    "S( , vec2( 0.0, 0.0 ) )",
  )
}
