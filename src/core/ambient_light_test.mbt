///|
test "AmbientLight Extending" {
  assert_true(@core.AmbientLight::new().is_light())
}

///|
test "AmbientLight type" {
  assert_eq(@core.AmbientLight::new().type_, "AmbientLight")
}

///|
test "AmbientLight isAmbientLight" {
  assert_true(@core.AmbientLight::new().as_light().kind is AmbientLight)
}

///|
test "AmbientLight Standard light tests" {
  let color = @math.Color::from_hex(0xaaaaaa)
  run_std_light_tests(
    [
      @core.AmbientLight::new(),
      @core.AmbientLight::new(color~),
      @core.AmbientLight::new(color~, intensity=0.5),
    ],
    color => @core.AmbientLight::new(color~),
  )
}
