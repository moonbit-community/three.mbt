///|
test "HemisphereLight Extending" {
  assert_true(@core.HemisphereLight::new().is_light())
}

///|
test "HemisphereLight type" {
  assert_eq(@core.HemisphereLight::new().type_, "HemisphereLight")
}

///|
test "HemisphereLight isHemisphereLight" {
  assert_true(
    @core.HemisphereLight::new().as_light().kind is HemisphereLight(_),
  )
}

///|
test "HemisphereLight Standard light tests" {
  let sky_color = @math.Color::from_hex(0x123456)
  let ground_color = @math.Color::from_hex(0xabc012)
  run_std_light_tests(
    [
      @core.HemisphereLight::new(),
      @core.HemisphereLight::new(sky_color~),
      @core.HemisphereLight::new(sky_color~, ground_color~),
      @core.HemisphereLight::new(sky_color~, ground_color~, intensity=0.6),
    ],
    color => @core.HemisphereLight::new(sky_color=color),
  )
}

///|
test "HemisphereLight toJSON" {
  let ground_color = @math.Color::from_hex(0xabc012)
  let light = @core.HemisphereLight::new(ground_color~)
  let object = light_test_object(light)
  assert_true(object.get("groundColor") is Some(Number(11255826.0, ..)))
}
