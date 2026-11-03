///|
test "WGSLNodeFunction parses a declaration" {
  let f = @webgpu.WGSLNodeFunction::new(
    "// comment\nfn scale( a : f32, b : vec3<f32>, t : texture_2d<f32>, p : ptr<function, f32> ) -> vec3f { return b * a; }",
  )
  inspect(f.name, content="scale")
  inspect(f.type_, content="vec3")
  inspect(
    f.inputs.map(fn(i) { i.name + ":" + i.type_ }),
    content=(
      #|[a:float, b:vec3, t:texture, p:pointer]
    ),
  )
  inspect(
    f.get_code(name="renamed"),
    content="fn renamed ( a : f32, b : vec3<f32>, t : texture_2d<f32>, p : ptr<function, f32> ) -> vec3f { return b * a; }",
  )
}

///|
test "WGSLNodeFunction without a return type" {
  let f = @webgpu.WGSLNodeFunction::new("fn run( x : u32 ) -> void { }")
  inspect(f.type_, content="void")
  inspect(f.get_code(), content="fn run ( x : u32 )  { }")
}

///|
test "WGSLNodeParser" {
  let parser = @webgpu.WGSLNodeParser::new()
  let f = parser
    .parse_function("fn g( v : vec2i ) -> i32 { return v.x; }")
    .unwrap()
  inspect(f.type_, content="int")
  inspect(f.inputs[0].type_, content="ivec2")
}

///|
test "WGSLNodeBuilder types and methods" {
  let b = @webgpu.WGSLNodeBuilder::new(
    NoObject,
    @nodes.Renderer::foundation_stub(),
  )
  inspect(b.allow_early_returns, content="true")
  inspect(b.allow_global_variables, content="true")
  inspect(b.get_type("mat3"), content="mat3x3<f32>")
  inspect(b.get_type("custom"), content="custom")
  inspect(b.get_bitcast_method("uint"), content="bitcast<u32>")
  inspect(b.get_ternary("c", "a", "b"), content="Some(select( b, a, c ))")
  inspect(b.get_method("dFdy"), content="- dpdy")
  inspect(b.get_float_packing_method("snorm"), content="pack2x16snorm")
  inspect(b.is_reserved_keyword("main"), content="true")
  inspect(b.is_reserved_keyword("color"), content="false")
  inspect(
    b.get_var("vec3", "v", count=4),
    content="var v : array< vec3<f32>, 4 >",
  )
}

///|
test "libraries" {
  let basic = @webgpu.BasicNodeLibrary::new()
  inspect(
    basic.get_tone_mapping_function(@core.AgXToneMapping) is Some(_),
    content="true",
  )
  inspect(
    basic.get_material_node_class("MeshBasicMaterial") is None,
    content="true",
  )
  let standard = @webgpu.StandardNodeLibrary::new()
  inspect(
    standard.get_material_node_class("MeshStandardMaterial") is Some(_),
    content="true",
  )
  inspect(@core.Light::light_node_of("PointLight") is Some(_), content="true")
}
