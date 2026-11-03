///|
test "MeshDepthMaterial Extending" {
  let object = @core.MeshDepthMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshDepthMaterial type" {
  let object = @core.MeshDepthMaterial::new()
  assert_eq(object.type_, "MeshDepthMaterial")
}

///|
test "MeshDepthMaterial isMeshDepthMaterial" {
  assert_true(@core.MeshDepthMaterial::new().is_mesh_depth_material())
  assert_true(!@core.Material::new().is_mesh_depth_material())
}

///|
test "MeshDepthMaterial clone keeps the class" {
  let object = @core.MeshDepthMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_depth_material())
  assert_eq(cloned.type_, "MeshDepthMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshDepthMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshDepthMaterial::new().to_json()),
    material_json_base_keys + ",depthPacking,wireframe,wireframeLinewidth",
  )
}
