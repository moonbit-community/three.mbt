///|
extern "js" fn helpers_test_fround(x : Double) -> Double = "Math.fround"

///|
fn hemisphere_light() -> @core.Object3D {
  @core.HemisphereLight::new(sky_color=@math.Color::from_hex(0x123456))
}

///|
test "HemisphereLightHelper extends Object3D" {
  let light = hemisphere_light()
  let object = @helpers.HemisphereLightHelper::new(
    light,
    size=1.0,
    color=@math.Color::from_hex(0xabc012),
  )
  assert_true(object.kind is Base)
}

///|
test "HemisphereLightHelper instancing and type" {
  let light = hemisphere_light()
  let object = @helpers.HemisphereLightHelper::new(
    light,
    size=1.0,
    color=@math.Color::from_hex(0xabc012),
  )
  assert_eq(object.type_, "HemisphereLightHelper")
}

///|
test "HemisphereLightHelper dispose" {
  let light = hemisphere_light()
  let object = @helpers.HemisphereLightHelper::new(
    light,
    size=1.0,
    color=@math.Color::from_hex(0xabc012),
  )
  object.dispose()
}

///|
test "HemisphereLightHelper colors the halves" {
  let light = hemisphere_light()
  let object = @helpers.HemisphereLightHelper::new(light)
  let payload = @helpers.HemisphereLightHelper::of(object).unwrap()
  assert_true(payload.material.vertex_colors)
  let colors = object.children[0].get_geometry().unwrap().attributes["color"]
  let sky = light.as_light().color
  assert_eq(colors.get_x(0), helpers_test_fround(sky.r))
}
