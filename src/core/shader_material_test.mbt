///|
test "ShaderMaterial Extending" {
  let object = @core.ShaderMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "ShaderMaterial type" {
  let object = @core.ShaderMaterial::new()
  assert_eq(object.type_, "ShaderMaterial")
}

///|
test "ShaderMaterial isShaderMaterial" {
  assert_true(@core.ShaderMaterial::new().is_shader_material())
  assert_true(!@core.Material::new().is_shader_material())
}

///|
test "ShaderMaterial clone keeps the class" {
  let object = @core.ShaderMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_shader_material())
  assert_eq(cloned.type_, "ShaderMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "ShaderMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.ShaderMaterial::new().to_json()),
    material_json_base_keys +
    ",linewidth,wireframe,wireframeLinewidth,fog,glslVersion,uniforms,vertexShader,fragmentShader,lights,clipping",
  )
}

///|
test "ShaderMaterial default shaders" {
  let object = @core.ShaderMaterial::new()
  assert_eq(
    object.vertex_shader,
    Some(
      "\nvoid main() {\n\tgl_Position = projectionMatrix * modelViewMatrix * vec4( position, 1.0 );\n}\n",
    ),
  )
  assert_eq(
    object.fragment_shader,
    Some("\nvoid main() {\n\tgl_FragColor = vec4( 1.0, 0.0, 0.0, 1.0 );\n}\n"),
  )
}

///|
test "ShaderMaterial copy clones uniforms, groups and extensions" {
  let source = @core.ShaderMaterial::new()
  let color = @math.Color::new(0.1, 0.2, 0.3)
  source.uniforms.unwrap()["tint"] = @core.Uniform::new(Color(color))
  source.uniforms_groups.unwrap().push(@core.UniformsGroup::new())
  source.defines.unwrap()["A"] = Json::number(1.0)
  source.extensions.unwrap().multi_draw = true
  source.linewidth = Some(5.0)
  let object = @core.ShaderMaterial::new().copy(source)
  guard object.uniforms.unwrap().get("tint") is Some({ value: Color(copied), }) else {
    fail("uniform")
  }
  assert_true(!physical_equal(copied, color))
  assert_eq(copied.g, 0.2)
  assert_eq(object.uniforms_groups.unwrap().length(), 1)
  assert_eq(object.defines.unwrap().get("A"), Some(Json::number(1.0)))
  source.extensions.unwrap().multi_draw = false
  assert_true(object.extensions.unwrap().multi_draw)
  // upstream's copy leaves linewidth alone
  assert_eq(object.linewidth, Some(1.0))
}

///|
test "ShaderMaterial toJSON serializes uniforms by type" {
  let object = @core.ShaderMaterial::new()
  let uniforms = object.uniforms.unwrap()
  uniforms["c"] = @core.Uniform::new(Color(@math.Color::from_hex(0xff0000)))
  uniforms["v"] = @core.Uniform::new(Vector2(@math.Vector2::new(1.0, 2.0)))
  uniforms["n"] = @core.Uniform::new(Number(0.5))
  object.extensions.unwrap().clip_cull_distance = true
  object.defines.unwrap()["X"] = Json::string("1")
  guard object.to_json()
    is {
      "uniforms": {
        "c": { "type": "c", "value": Number(hex, ..), .. },
        "v": { "type": "v2", "value": [Number(x, ..), Number(y, ..)], .. },
        "n": { "value": Number(n, ..), .. },
        ..
      },
      "extensions": { "clipCullDistance": True, .. },
      "defines": { "X": "1", .. },
      "glslVersion": Null,
      ..
    } else {
    fail("shape")
  }
  assert_eq(hex, 0xff0000.0)
  assert_eq(x, 1.0)
  assert_eq(y, 2.0)
  assert_eq(n, 0.5)
}

///|
test "ShaderMaterial fromJSON restores uniforms" {
  let source = @core.ShaderMaterial::new()
  let uniforms = source.uniforms.unwrap()
  uniforms["c"] = @core.Uniform::new(Color(@math.Color::from_hex(0x00ff00)))
  uniforms["m"] = @core.Uniform::new(Matrix3(@math.Matrix3::new()))
  uniforms["n"] = @core.Uniform::new(Number(2.0))
  uniforms["a"] = @core.Uniform::new(Numbers([1.0, 2.0]))
  source.vertex_shader = Some("v")
  source.glsl_version = Some("300 es")
  source.lights = Some(true)
  source.extensions.unwrap().multi_draw = true
  let object = @core.ShaderMaterial::new().from_json(source.to_json())
  let restored = object.uniforms.unwrap()
  guard restored.get("c") is Some({ value: Color(color), }) else { fail("c") }
  assert_eq(color.get_hex(), 0x00ff00)
  guard restored.get("m") is Some({ value: Matrix3(_), }) else { fail("m") }
  guard restored.get("n") is Some({ value: Number(2.0), }) else { fail("n") }
  guard restored.get("a") is Some({ value: Numbers(a), }) else { fail("a") }
  assert_eq(a, [1.0, 2.0])
  assert_eq(object.vertex_shader, Some("v"))
  assert_eq(object.glsl_version, Some("300 es"))
  assert_eq(object.lights, Some(true))
  assert_true(object.extensions.unwrap().multi_draw)
}
