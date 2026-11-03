///|
test "MeshPhongMaterial Extending" {
  let object = @core.MeshPhongMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshPhongMaterial type" {
  let object = @core.MeshPhongMaterial::new()
  assert_eq(object.type_, "MeshPhongMaterial")
}

///|
test "MeshPhongMaterial isMeshPhongMaterial" {
  assert_true(@core.MeshPhongMaterial::new().is_mesh_phong_material())
  assert_true(!@core.Material::new().is_mesh_phong_material())
}

///|
test "MeshPhongMaterial clone keeps the class" {
  let object = @core.MeshPhongMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_phong_material())
  assert_eq(cloned.type_, "MeshPhongMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshPhongMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshPhongMaterial::new().to_json()),
    material_json_base_keys +
    ",color,emissive,emissiveIntensity,specular,shininess,envMapRotation,envMapIntensity,reflectivity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
  )
}
