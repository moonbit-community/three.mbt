///|
test "MeshBasicMaterial Extending" {
  let object = @core.MeshBasicMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshBasicMaterial type" {
  let object = @core.MeshBasicMaterial::new()
  assert_eq(object.type_, "MeshBasicMaterial")
}

///|
test "MeshBasicMaterial isMeshBasicMaterial" {
  assert_true(@core.MeshBasicMaterial::new().is_mesh_basic_material())
  assert_true(!@core.Material::new().is_mesh_basic_material())
}

///|
test "MeshBasicMaterial clone keeps the class" {
  let object = @core.MeshBasicMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_basic_material())
  assert_eq(cloned.type_, "MeshBasicMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshBasicMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshBasicMaterial::new().to_json()),
    material_json_base_keys +
    ",color,envMapRotation,reflectivity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,fog",
  )
}
