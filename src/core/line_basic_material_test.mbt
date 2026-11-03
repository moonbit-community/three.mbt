///|
test "LineBasicMaterial Extending" {
  let object = @core.LineBasicMaterial::new()
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "LineBasicMaterial type" {
  let object = @core.LineBasicMaterial::new()
  assert_eq(object.type_, "LineBasicMaterial")
}

///|
test "LineBasicMaterial isLineBasicMaterial" {
  assert_true(@core.LineBasicMaterial::new().is_line_basic_material())
  assert_true(!@core.Material::new().is_line_basic_material())
}

///|
test "LineBasicMaterial clone keeps the class" {
  let object = @core.LineBasicMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_line_basic_material())
  assert_eq(cloned.type_, "LineBasicMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "LineBasicMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.LineBasicMaterial::new().to_json()),
    material_json_base_keys + ",color,linewidth,linecap,linejoin,fog",
  )
}
