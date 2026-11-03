///|
fn spot_light() -> @core.Object3D {
  @core.SpotLight::new(color=@math.Color::from_hex(0xaaaaaa))
}

///|
test "SpotLightHelper extends Object3D" {
  let light = spot_light()
  let object = @helpers.SpotLightHelper::new(
    light,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  assert_true(object.kind is Base)
}

///|
test "SpotLightHelper instancing and type" {
  let light = spot_light()
  let object = @helpers.SpotLightHelper::new(
    light,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  assert_eq(object.type_, "SpotLightHelper")
}

///|
test "SpotLightHelper dispose" {
  let light = spot_light()
  let object = @helpers.SpotLightHelper::new(
    light,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  object.dispose()
}

///|
test "SpotLightHelper cone length" {
  let light = @core.SpotLight::new(distance=5.0, angle=0.0)
  let object = @helpers.SpotLightHelper::new(light)
  let cone = @helpers.SpotLightHelper::of(object).unwrap().cone
  assert_eq(cone.scale.z, 5.0)
  light.as_spot_light().distance = 0.0
  @helpers.SpotLightHelper::update(object)
  assert_eq(cone.scale.z, 1000.0)
}
