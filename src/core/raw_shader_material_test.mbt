///|
test "RawShaderMaterial Extending" {
  let object = @core.RawShaderMaterial::new()
  assert_true(object.is_shader_material())
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "RawShaderMaterial type" {
  let object = @core.RawShaderMaterial::new()
  assert_eq(object.type_, "RawShaderMaterial")
}

///|
test "RawShaderMaterial isRawShaderMaterial" {
  assert_true(@core.RawShaderMaterial::new().is_raw_shader_material())
  assert_true(!@core.Material::new().is_raw_shader_material())
}

///|
test "RawShaderMaterial clone keeps the class" {
  let object = @core.RawShaderMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_raw_shader_material())
  assert_eq(cloned.type_, "RawShaderMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "RawShaderMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.RawShaderMaterial::new().to_json()),
    material_json_base_keys +
    ",linewidth,wireframe,wireframeLinewidth,fog,glslVersion,uniforms,vertexShader,fragmentShader,lights,clipping",
  )
}
