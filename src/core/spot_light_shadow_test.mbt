///|
test "SpotLightShadow Extending" {
  let object = @core.SpotLightShadow::new()
  assert_true(object.kind is SpotLightShadow({ focus: 1.0, aspect: 1.0, }))
  let camera = object.camera.as_perspective_camera()
  assert_eq(camera.fov, 50.0)
  assert_eq(camera.near, 0.5)
  assert_eq(camera.far, 500.0)
}

///|
test "SpotLightShadow clone/copy" {
  let a = @core.SpotLightShadow::new()
  guard a.kind is SpotLightShadow(data) else { fail("not a spot shadow") }
  data.focus = 0.5
  data.aspect = 2.0
  let b = @core.SpotLightShadow::new()
  let c = a.clone()
  assert_true(c.kind is SpotLightShadow({ focus: 0.5, aspect: 2.0, }))
  assert_eq(
    light_test_strip_ids(a.to_json()),
    light_test_strip_ids(c.to_json()),
  )
  ignore(c.map_size.set(256, 256))
  assert_false(
    light_test_strip_ids(a.to_json()) == light_test_strip_ids(c.to_json()),
  )
  ignore(b.copy(a))
  assert_eq(
    light_test_strip_ids(a.to_json()),
    light_test_strip_ids(b.to_json()),
  )
  ignore(b.map_size.set(512, 512))
  assert_eq(a.map_size.x, 512.0)
}

///|
test "SpotLightShadow toJSON" {
  let light = @core.SpotLight::new()
  let shadow = @core.SpotLightShadow::new()
  shadow.bias = 10.0
  shadow.radius = 5.0
  ignore(shadow.map_size.set(128, 128))
  light.as_light().shadow = Some(shadow)
  let object = light_test_object(light)
  guard object.get("shadow") is Some(Object(json)) else { fail("no shadow") }
  assert_true(json.get("bias") is Some(Number(10.0, ..)))
  assert_true(json.get("focus") is Some(Number(1.0, ..)))
  assert_true(json.get("aspect") is Some(Number(1.0, ..)))
}

///|
test "SpotLightShadow updateMatrices follows the light" {
  let light = @core.SpotLight::new(distance=20.0, angle=0.5)
  light.update_matrix_world()
  light.light_target().update_matrix_world()
  guard light.as_light().shadow is Some(shadow) else { fail("no shadow") }
  ignore(shadow.map_size.set(1024, 512))
  shadow.update_matrices(light)
  let camera = shadow.camera.as_perspective_camera()
  assert_true(approx(camera.fov, 2.0 * 0.5 * 180.0 / test_pi()))
  assert_eq(camera.aspect, 2.0)
  assert_eq(camera.far, 20.0)
  // a zero distance falls back to the camera's far plane
  light.as_spot_light().distance = 0.0
  shadow.update_matrices(light)
  assert_eq(camera.far, 20.0)
}
