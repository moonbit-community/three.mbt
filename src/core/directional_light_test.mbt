///|
test "DirectionalLight Extending" {
  assert_true(@core.DirectionalLight::new().is_light())
}

///|
test "DirectionalLight type" {
  assert_eq(@core.DirectionalLight::new().type_, "DirectionalLight")
}

///|
test "DirectionalLight isDirectionalLight" {
  assert_true(
    @core.DirectionalLight::new().as_light().kind is DirectionalLight(_),
  )
}

///|
test "DirectionalLight position and shadow" {
  let light = @core.DirectionalLight::new()
  assert_true(light.position.equals(vec3(0, 1, 0)))
  assert_eq(light.matrix.elements[13], 1.0)
  assert_true(
    light.as_light().shadow is Some({ kind: DirectionalLightShadow, .. }),
  )
}

///|
test "DirectionalLight dispose" {
  @core.DirectionalLight::new().dispose()
}

///|
test "DirectionalLight dispose fires and disposes the shadow map" {
  let light = @core.DirectionalLight::new()
  let log = []
  light.add_event_listener("dispose", _ => log.push("light"))
  let map = @core.RenderTarget::new()
  map.add_event_listener("dispose", _ => log.push("map"))
  guard light.as_light().shadow is Some(shadow) else { fail("no shadow") }
  shadow.map = Some(map)
  light.dispose()
  assert_eq(log, ["light", "map"])
}

///|
test "DirectionalLight Standard light tests" {
  let color = @math.Color::from_hex(0xaaaaaa)
  run_std_light_tests(
    [
      @core.DirectionalLight::new(),
      @core.DirectionalLight::new(color~),
      @core.DirectionalLight::new(color~, intensity=0.8),
    ],
    color => @core.DirectionalLight::new(color~),
  )
}

///|
test "DirectionalLight toJSON writes shadow and target" {
  let light = @core.DirectionalLight::new()
  let object = light_test_object(light)
  assert_eq(object.get("target"), Some(Json::string(light.light_target().uuid)))
  guard object.get("shadow") is Some(Object(shadow)) else { fail("no shadow") }
  guard shadow.get("camera") is Some(Object(camera)) else { fail("no camera") }
  assert_true(camera.get("matrix") is None)
  assert_true(camera.get("left") is Some(Number(-5.0, ..)))
}
