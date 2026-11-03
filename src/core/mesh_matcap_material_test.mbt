///|
test "MeshMatcapMaterial Extending" {
  let object = @core.MeshMatcapMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshMatcapMaterial type" {
  let object = @core.MeshMatcapMaterial::new()
  assert_eq(object.type_, "MeshMatcapMaterial")
}

///|
test "MeshMatcapMaterial isMeshMatcapMaterial" {
  assert_true(@core.MeshMatcapMaterial::new().is_mesh_matcap_material())
  assert_true(!@core.Material::new().is_mesh_matcap_material())
}

///|
test "MeshMatcapMaterial clone keeps the class" {
  let object = @core.MeshMatcapMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_matcap_material())
  assert_eq(cloned.type_, "MeshMatcapMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshMatcapMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshMatcapMaterial::new().to_json()),
    material_json_base_keys +
    ",color,wireframe,wireframeLinewidth,flatShading,fog",
  )
}

///|
test "MeshMatcapMaterial defines" {
  let actual = @core.MeshMatcapMaterial::new().defines.unwrap()
  assert_eq(actual.length(), 1)
  assert_eq(actual.get("MATCAP"), Some(Json::string("")))
}
