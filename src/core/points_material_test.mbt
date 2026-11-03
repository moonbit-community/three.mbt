///|
test "PointsMaterial Extending" {
  let object = @core.PointsMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "PointsMaterial type" {
  let object = @core.PointsMaterial::new()
  assert_eq(object.type_, "PointsMaterial")
}

///|
test "PointsMaterial isPointsMaterial" {
  assert_true(@core.PointsMaterial::new().is_points_material())
  assert_true(!@core.Material::new().is_points_material())
}

///|
test "PointsMaterial clone keeps the class" {
  let object = @core.PointsMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_points_material())
  assert_eq(cloned.type_, "PointsMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "PointsMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.PointsMaterial::new().to_json()),
    material_json_base_keys + ",color,size,sizeAttenuation,fog",
  )
}
