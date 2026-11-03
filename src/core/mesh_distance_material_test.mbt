///|
test "MeshDistanceMaterial Extending" {
  let object = @core.MeshDistanceMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshDistanceMaterial type" {
  let object = @core.MeshDistanceMaterial::new()
  assert_eq(object.type_, "MeshDistanceMaterial")
}

///|
test "MeshDistanceMaterial isMeshDistanceMaterial" {
  assert_true(@core.MeshDistanceMaterial::new().is_mesh_distance_material())
  assert_true(!@core.Material::new().is_mesh_distance_material())
}

///|
test "MeshDistanceMaterial clone keeps the class" {
  let object = @core.MeshDistanceMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_distance_material())
  assert_eq(cloned.type_, "MeshDistanceMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshDistanceMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshDistanceMaterial::new().to_json()),
    material_json_base_keys + "",
  )
}
