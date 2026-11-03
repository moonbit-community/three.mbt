///|
test "PointLight Extending" {
  assert_true(@core.PointLight::new().is_light())
}

///|
test "PointLight type" {
  assert_eq(@core.PointLight::new().type_, "PointLight")
}

///|
test "PointLight power" {
  let a = @core.PointLight::new(color=@math.Color::from_hex(0xaaaaaa))
  a.as_light().intensity = 100.0
  assert_true(approx(a.power(), 100.0 * test_pi() * 4.0))
  a.as_light().intensity = 40.0
  assert_true(approx(a.power(), 40.0 * test_pi() * 4.0))
  a.set_power(100.0)
  assert_true(approx(a.as_light().intensity, 100.0 / (4.0 * test_pi())))
}

///|
test "PointLight isPointLight" {
  assert_true(@core.PointLight::new().as_light().kind is PointLight(_))
}

///|
test "PointLight dispose" {
  @core.PointLight::new().dispose()
}

///|
test "PointLight Standard light tests" {
  let color = @math.Color::from_hex(0xaaaaaa)
  run_std_light_tests(
    [
      @core.PointLight::new(),
      @core.PointLight::new(color~),
      @core.PointLight::new(color~, intensity=0.5),
      @core.PointLight::new(color~, intensity=0.5, distance=100.0),
      @core.PointLight::new(color~, intensity=0.5, distance=100.0, decay=2.0),
    ],
    color => @core.PointLight::new(color~),
  )
}
