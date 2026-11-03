///|
test "ArrayCamera Extending" {
  let object = @core.ArrayCamera::new()
  assert_true(object.is_perspective_camera())
  assert_eq(object.type_, "PerspectiveCamera")
}

///|
test "ArrayCamera isArrayCamera" {
  assert_true(@core.ArrayCamera::new().is_array_camera())
  assert_false(@core.PerspectiveCamera::new().is_array_camera())
}

///|
test "ArrayCamera holds its cameras" {
  let cameras = [@core.PerspectiveCamera::new()]
  let object = @core.ArrayCamera::new(array=cameras)
  guard object.kind
    is Camera({ kind: PerspectiveCamera({ array_camera: Some(data), .. }), .. }) else {
    fail("not an array camera")
  }
  assert_true(physical_equal(data.cameras, cameras))
  assert_false(data.is_multi_view_camera)
  assert_false(data.per_camera_frustum_culled)
}

///|
test "ArrayCamera clone is an ArrayCamera without the cameras" {
  let object = @core.ArrayCamera::new(array=[@core.PerspectiveCamera::new()])
  let cloned = object.clone()
  guard cloned.kind
    is Camera({ kind: PerspectiveCamera({ array_camera: Some(data), .. }), .. }) else {
    fail("not an array camera")
  }
  assert_eq(data.cameras.length(), 0)
}
