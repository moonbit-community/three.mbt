///|
test "MeshStandardMaterial Extending" {
  let object = @core.MeshStandardMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "MeshStandardMaterial type" {
  let object = @core.MeshStandardMaterial::new()
  assert_eq(object.type_, "MeshStandardMaterial")
}

///|
test "MeshStandardMaterial isMeshStandardMaterial" {
  assert_true(@core.MeshStandardMaterial::new().is_mesh_standard_material())
  assert_true(!@core.Material::new().is_mesh_standard_material())
}

///|
test "MeshStandardMaterial clone keeps the class" {
  let object = @core.MeshStandardMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_mesh_standard_material())
  assert_eq(cloned.type_, "MeshStandardMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "MeshStandardMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.MeshStandardMaterial::new().to_json()),
    material_json_base_keys +
    ",color,roughness,metalness,emissive,emissiveIntensity,envMapRotation,envMapIntensity,wireframe,wireframeLinewidth,wireframeLinecap,wireframeLinejoin,flatShading,fog",
  )
}

///|
test "MeshStandardMaterial defines survive copy as upstream resets them" {
  let object = @core.MeshStandardMaterial::new()
  object.defines = Some(Map([]))
  ignore(object.copy(@core.MeshStandardMaterial::new()))
  assert_eq(object.defines.unwrap().get("STANDARD"), Some(Json::string("")))
}
