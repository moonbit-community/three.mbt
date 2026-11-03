///|
test "MeshNormalMaterial Extending" {
  let object = @core.MeshNormalMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshNormalMaterial type" {
  let object = @core.MeshNormalMaterial::new()
  assert_eq(object.type_, "MeshNormalMaterial")
}

///|
test "MeshNormalMaterial isMeshNormalMaterial" {
  assert_true(@core.MeshNormalMaterial::new().is_mesh_normal_material())
  assert_true(!@core.Material::new().is_mesh_normal_material())
}

///|
test "MeshNormalMaterial clone keeps the class" {
  let object = @core.MeshNormalMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_normal_material())
  assert_eq(cloned.type_, "MeshNormalMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshNormalMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshNormalMaterial::new().to_json()),
    material_json_base_keys + ",wireframe,wireframeLinewidth,flatShading",
  )
}
