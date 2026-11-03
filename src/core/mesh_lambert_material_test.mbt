///|
test "MeshLambertMaterial Extending" {
  let object = @core.MeshLambertMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshLambertMaterial type" {
  let object = @core.MeshLambertMaterial::new()
  assert_eq(object.type_, "MeshLambertMaterial")
}

///|
test "MeshLambertMaterial isMeshLambertMaterial" {
  assert_true(@core.MeshLambertMaterial::new().is_mesh_lambert_material())
  assert_true(!@core.Material::new().is_mesh_lambert_material())
}

///|
test "MeshLambertMaterial clone keeps the class" {
  let object = @core.MeshLambertMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_lambert_material())
  assert_eq(cloned.type_, "MeshLambertMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshLambertMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshLambertMaterial::new().to_json()),
    material_json_base_keys +
    ",color,emissive,emissiveIntensity,envMapRotation,envMapIntensity,reflectivity,refractionRatio,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
  )
}
