///|
test "ShadowMaterial Extending" {
  let object = @core.ShadowMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "ShadowMaterial type" {
  let object = @core.ShadowMaterial::new()
  assert_eq(object.type_, "ShadowMaterial")
}

///|
test "ShadowMaterial isShadowMaterial" {
  assert_true(@core.ShadowMaterial::new().is_shadow_material())
  assert_true(!@core.Material::new().is_shadow_material())
}

///|
test "ShadowMaterial clone keeps the class" {
  let object = @core.ShadowMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_shadow_material())
  assert_eq(cloned.type_, "ShadowMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "ShadowMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.ShadowMaterial::new().to_json()),
    material_json_base_keys + ",color,fog",
  )
}
