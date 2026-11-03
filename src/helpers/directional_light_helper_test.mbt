///|
fn directional_light() -> @core.Object3D {
  @core.DirectionalLight::new(color=@math.Color::from_hex(0xaaaaaa))
}

///|
test "DirectionalLightHelper extends Object3D" {
  let light = directional_light()
  let object = @helpers.DirectionalLightHelper::new(
    light,
    size=1.0,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  assert_true(object.kind is Base)
}

///|
test "DirectionalLightHelper instancing and type" {
  let light = directional_light()
  let object = @helpers.DirectionalLightHelper::new(
    light,
    size=1.0,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  assert_eq(object.type_, "DirectionalLightHelper")
}

///|
test "DirectionalLightHelper dispose" {
  let light = directional_light()
  let object = @helpers.DirectionalLightHelper::new(
    light,
    size=1.0,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  object.dispose()
}

///|
test "DirectionalLightHelper follows the light" {
  let light = directional_light()
  ignore(light.position.set(0.0, 3.0, 4.0))
  let object = @helpers.DirectionalLightHelper::new(light)
  let payload = @helpers.DirectionalLightHelper::of(object).unwrap()
  assert_true(physical_equal(object.matrix, light.matrix_world))
  assert_eq(payload.target_line.scale.z, 5.0)
  assert_true(
    payload.light_plane.get_material() is Some(Single(m)) &&
    m.color.unwrap().equals(light.as_light().color),
  )
}
