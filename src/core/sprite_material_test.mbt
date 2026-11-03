///|
test "SpriteMaterial Extending" {
  let object = @core.SpriteMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "SpriteMaterial type" {
  let object = @core.SpriteMaterial::new()
  assert_eq(object.type_, "SpriteMaterial")
}

///|
test "SpriteMaterial isSpriteMaterial" {
  assert_true(@core.SpriteMaterial::new().is_sprite_material())
  assert_true(!@core.Material::new().is_sprite_material())
}

///|
test "SpriteMaterial clone keeps the class" {
  let object = @core.SpriteMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_sprite_material())
  assert_eq(cloned.type_, "SpriteMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "SpriteMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.SpriteMaterial::new().to_json()),
    material_json_base_keys + ",color,sizeAttenuation,rotation,fog",
  )
}
