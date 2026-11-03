///|
test "StereoCamera type" {
  assert_eq(@core.StereoCamera::new().type_, "StereoCamera")
}

///|
test "StereoCamera defaults" {
  let object = @core.StereoCamera::new()
  assert_eq(object.aspect, 1.0)
  assert_eq(object.eye_sep, 0.064)
  assert_true(object.camera_l.layers.is_enabled(1))
  assert_true(object.camera_r.layers.is_enabled(2))
  assert_false(object.camera_l.matrix_auto_update)
  assert_false(object.camera_r.matrix_auto_update)
}

///|
test "StereoCamera update" {
  let stereo = @core.StereoCamera::new()
  let camera = @core.PerspectiveCamera::new(
    fov=60.0,
    aspect=1.5,
    near=0.1,
    far=100.0,
  )
  ignore(camera.position.set(1, 2, 3))
  camera.update_matrix_world()
  stereo.update(camera)
  assert_true(stereo.camera_l.matrix_world_needs_update)
  assert_true(stereo.camera_r.matrix_world_needs_update)
  // eyes are offset by half the separation along x
  assert_true(approx(stereo.camera_l.matrix.elements[12], 1.0 - 0.032))
  assert_true(approx(stereo.camera_r.matrix.elements[12], 1.0 + 0.032))
  let left = stereo.camera_l.as_camera().projection_matrix.elements
  let right = stereo.camera_r.as_camera().projection_matrix.elements
  assert_eq(left[0], right[0])
  assert_true(approx(left[8], -right[8]))
  // an unchanged camera leaves the projections alone
  left[0] = 7.0
  stereo.update(camera)
  assert_eq(left[0], 7.0)
  stereo.eye_sep = 0.1
  stereo.update(camera)
  assert_false(left[0] == 7.0)
}
