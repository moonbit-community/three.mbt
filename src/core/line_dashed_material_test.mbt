///|
test "LineDashedMaterial Extending" {
  let object = @core.LineDashedMaterial::new()
  assert_true(object.is_line_basic_material())
  assert_eq(object.dispatcher.has_event_listener("dispose", _ => ()), false)
}

///|
test "LineDashedMaterial type" {
  let object = @core.LineDashedMaterial::new()
  assert_eq(object.type_, "LineDashedMaterial")
}

///|
test "LineDashedMaterial isLineDashedMaterial" {
  assert_true(@core.LineDashedMaterial::new().is_line_dashed_material())
  assert_true(!@core.Material::new().is_line_dashed_material())
}

///|
test "LineDashedMaterial clone keeps the class" {
  let object = @core.LineDashedMaterial::new()
  object.name = "a"
  let cloned = object.clone()
  assert_true(cloned.is_line_dashed_material())
  assert_eq(cloned.type_, "LineDashedMaterial")
  assert_eq(cloned.name, "a")
  assert_true(cloned.uuid != object.uuid)
  assert_true(cloned.id != object.id)
}

///|
test "LineDashedMaterial toJSON keys match upstream" {
  assert_eq(
    json_keys(@core.LineDashedMaterial::new().to_json()),
    material_json_base_keys +
    ",color,linewidth,linecap,linejoin,dashSize,gapSize,scale,fog",
  )
}

///|
test "LineDashedMaterial inherits LineBasicMaterial defaults" {
  let object = @core.LineDashedMaterial::new()
  assert_eq(object.linewidth, Some(1.0))
  assert_eq(object.linecap, Some("round"))
  assert_eq(object.scale, Some(1.0))
  assert_eq(object.dash_size, Some(3.0))
  assert_eq(object.gap_size, Some(1.0))
}
