///|
test "MeshToonMaterial Extending" {
  let object = @core.MeshToonMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshToonMaterial type" {
  let object = @core.MeshToonMaterial::new()
  assert_eq(object.type_, "MeshToonMaterial")
}

///|
test "MeshToonMaterial isMeshToonMaterial" {
  assert_true(@core.MeshToonMaterial::new().is_mesh_toon_material())
  assert_true(!@core.Material::new().is_mesh_toon_material())
}

///|
test "MeshToonMaterial clone keeps the class" {
  let object = @core.MeshToonMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_toon_material())
  assert_eq(cloned.type_, "MeshToonMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshToonMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshToonMaterial::new().to_json()),
    material_json_base_keys +
    ",color,emissive,emissiveIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,fog",
  )
}
