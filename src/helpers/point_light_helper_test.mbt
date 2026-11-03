///|
fn point_light() -> @core.Object3D {
  @core.PointLight::new(color=@math.Color::from_hex(0xaaaaaa))
}

///|
test "PointLightHelper extends Mesh" {
  let light = point_light()
  let object = @helpers.PointLightHelper::new(
    light,
    sphere_size=1.0,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  assert_true(object.is_mesh())
}

///|
test "PointLightHelper instancing and type" {
  let light = point_light()
  let object = @helpers.PointLightHelper::new(
    light,
    sphere_size=1.0,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  assert_eq(object.type_, "PointLightHelper")
}

///|
test "PointLightHelper dispose" {
  let light = point_light()
  let object = @helpers.PointLightHelper::new(
    light,
    sphere_size=1.0,
    color=@math.Color::from_hex(0xaaaaaa),
  )
  object.dispose()
}

///|
test "PointLightHelper follows the light color" {
  let light = point_light()
  let object = @helpers.PointLightHelper::new(light)
  ignore(light.as_light().color.set_hex(0xff0000))
  @helpers.PointLightHelper::update(object)
  guard object.get_material() is Some(Single(material)) else {
    fail("material")
  }
  assert_eq(material.color.unwrap().get_hex(), 0xff0000)
  assert_true(physical_equal(object.matrix, light.matrix_world))
}
