///|
test "RectAreaLight Extending" {
  assert_true(@core.RectAreaLight::new().is_light())
}

///|
test "RectAreaLight type" {
  assert_eq(@core.RectAreaLight::new().type_, "RectAreaLight")
}

///|
test "RectAreaLight power" {
  let a = @core.RectAreaLight::new(
    color=@math.Color::from_hex(0xaaaaaa),
    intensity=1.0,
    width=10.0,
    height=10.0,
  )
  a.as_light().intensity = 100.0
  assert_true(approx(a.power(), 100.0 * 10.0 * 10.0 * test_pi()))
  a.as_light().intensity = 40.0
  assert_true(approx(a.power(), 40.0 * 10.0 * 10.0 * test_pi()))
  a.set_power(100.0)
  assert_true(approx(a.as_light().intensity, 100.0 / (10.0 * 10.0 * test_pi())))
}

///|
test "RectAreaLight isRectAreaLight" {
  assert_true(@core.RectAreaLight::new().as_light().kind is RectAreaLight(_))
}

///|
test "RectAreaLight Standard light tests" {
  let color = @math.Color::from_hex(0xaaaaaa)
  run_std_light_tests(
    [
      @core.RectAreaLight::new(color~),
      @core.RectAreaLight::new(color~, intensity=0.5),
      @core.RectAreaLight::new(color~, intensity=0.5, width=100.0),
      @core.RectAreaLight::new(color~, intensity=0.5, width=100.0, height=50.0),
    ],
    color => @core.RectAreaLight::new(color~),
  )
}
