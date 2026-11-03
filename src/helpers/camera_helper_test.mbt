///|
test "CameraHelper extends LineSegments" {
  let camera = @core.PerspectiveCamera::new()
  let object = @helpers.CameraHelper::new(camera)
  assert_true(object.is_line_segments())
}

///|
test "CameraHelper instancing and type" {
  let camera = @core.PerspectiveCamera::new()
  let object = @helpers.CameraHelper::new(camera)
  assert_eq(object.type_, "CameraHelper")
}

///|
test "CameraHelper dispose" {
  let camera = @core.PerspectiveCamera::new()
  let object = @helpers.CameraHelper::new(camera)
  object.dispose()
}

///|
test "CameraHelper draws the frustum in camera space" {
  let camera = @core.OrthographicCamera::new(
    left=-2.0,
    right=2.0,
    top=1.0,
    bottom=-1.0,
    near=1.0,
    far=5.0,
  )
  let object = @helpers.CameraHelper::new(camera)
  assert_true(physical_equal(object.matrix, camera.matrix_world))
  let payload = @helpers.CameraHelper::of(object).unwrap()
  assert_eq(payload.point_map["p"], [24, 26, 28, 30, 40])
  let position = object.get_geometry().unwrap().attributes["position"]
  // n1 is at index 0: left, bottom, near
  assert_eq(position.get_x(0), -2.0)
  assert_eq(position.get_y(0), -1.0)
  assert_eq(position.get_z(0), -1.0)
  // f4 is at index 10: right, top, far
  assert_eq(position.get_x(10), 2.0)
  assert_eq(position.get_z(10), -5.0)
  let color = object.get_geometry().unwrap().attributes["color"]
  assert_eq(color.get_x(38), 1.0)
}
