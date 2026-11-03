///|
test "PointLightShadow Extending" {
  let object = @core.PointLightShadow::new()
  assert_true(object.kind is PointLightShadow)
  let camera = object.camera.as_perspective_camera()
  assert_eq(camera.fov, 90.0)
  assert_eq(camera.aspect, 1.0)
  assert_eq(camera.near, 0.5)
  assert_eq(camera.far, 500.0)
}

///|
test "PointLightShadow clone keeps the class" {
  assert_true(@core.PointLightShadow::new().clone().kind is PointLightShadow)
}
