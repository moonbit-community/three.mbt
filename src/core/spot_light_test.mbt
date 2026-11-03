///|
test "SpotLight Extending" {
  assert_true(@core.SpotLight::new().is_light())
}

///|
test "SpotLight type" {
  assert_eq(@core.SpotLight::new().type_, "SpotLight")
}

///|
test "SpotLight defaults" {
  let light = @core.SpotLight::new()
  assert_true(light.position.equals(vec3(0, 1, 0)))
  assert_eq(light.matrix.elements[13], 1.0)
  let spot = light.as_spot_light()
  assert_eq(spot.distance, 0.0)
  assert_eq(spot.angle, test_pi() / 3.0)
  assert_eq(spot.penumbra, 0.0)
  assert_eq(spot.decay, 2.0)
  assert_true(spot.map is None)
}

///|
test "SpotLight power" {
  let a = @core.SpotLight::new(color=@math.Color::from_hex(0xaaaaaa))
  a.as_light().intensity = 100.0
  assert_true(approx(a.power(), 100.0 * test_pi()))
  a.as_light().intensity = 40.0
  assert_true(approx(a.power(), 40.0 * test_pi()))
  a.set_power(100.0)
  assert_true(approx(a.as_light().intensity, 100.0 / test_pi()))
}

///|
test "SpotLight isSpotLight" {
  assert_true(@core.SpotLight::new().as_light().kind is SpotLight(_))
}

///|
test "SpotLight dispose" {
  @core.SpotLight::new().dispose()
}

///|
test "SpotLight Standard light tests" {
  let color = @math.Color::from_hex(0xaaaaaa)
  run_std_light_tests(
    [
      @core.SpotLight::new(color~),
      @core.SpotLight::new(color~, intensity=0.5),
      @core.SpotLight::new(color~, intensity=0.5, distance=100.0),
      @core.SpotLight::new(color~, intensity=0.5, distance=100.0, angle=0.8),
      @core.SpotLight::new(
        color~,
        intensity=0.5,
        distance=100.0,
        angle=0.8,
        penumbra=8.0,
      ),
      @core.SpotLight::new(
        color~,
        intensity=0.5,
        distance=100.0,
        angle=0.8,
        penumbra=8.0,
        decay=2.0,
      ),
    ],
    color => @core.SpotLight::new(color~),
  )
}

///|
test "IESSpotLight" {
  let light = @core.IESSpotLight::new(distance=5.0)
  assert_eq(light.type_, "SpotLight")
  let data = light.as_spot_light()
  assert_true(data.variant is IESSpotLight)
  assert_true(data.ies_map is None)
  assert_eq(data.distance, 5.0)
  let map = @core.Texture::new()
  data.ies_map = Some(map)
  let cloned = light.clone().as_spot_light()
  assert_true(cloned.variant is IESSpotLight)
  assert_true(cloned.ies_map is Some(copied) && physical_equal(copied, map))
}

///|
test "ProjectorLight" {
  let light = @core.ProjectorLight::new(angle=0.5)
  assert_eq(light.type_, "SpotLight")
  let data = light.as_spot_light()
  assert_true(data.variant is ProjectorLight)
  assert_true(data.aspect is None)
  assert_eq(data.angle, 0.5)
  data.aspect = Some(2.0)
  let cloned = light.clone().as_spot_light()
  assert_true(cloned.variant is ProjectorLight)
  assert_eq(cloned.aspect, Some(2.0))
}
