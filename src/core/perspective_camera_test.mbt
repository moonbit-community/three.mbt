///|
test "PerspectiveCamera Extending" {
  let object = @core.PerspectiveCamera::new()
  assert_true(object.is_camera())
  assert_true(object.is_perspective_camera())
}

///|
test "PerspectiveCamera type" {
  assert_eq(@core.PerspectiveCamera::new().type_, "PerspectiveCamera")
}

///|
test "PerspectiveCamera defaults" {
  let object = @core.PerspectiveCamera::new().as_perspective_camera()
  assert_eq(object.fov, 50.0)
  assert_eq(object.aspect, 1.0)
  assert_eq(object.near, 0.1)
  assert_eq(object.far, 2000.0)
  assert_eq(object.zoom, 1.0)
  assert_eq(object.focus, 10.0)
  assert_eq(object.film_gauge, 35.0)
  assert_eq(object.film_offset, 0.0)
  assert_true(object.view is None)
}

///|
test "PerspectiveCamera updateProjectionMatrix" {
  let cam = @core.PerspectiveCamera::new(
    fov=75.0,
    aspect=16.0 / 9.0,
    near=0.1,
    far=300.0,
  )
  let reference = @math.Matrix4::new().set(
    0.7330642938613892, 0, 0, 0, 0, 1.3032253980636597, 0, 0, 0, 0, -1.000666856765747,
    -0.2000666856765747, 0, 0, -1, 0,
  )
  let m = cam.as_camera().projection_matrix
  for i in 0..<16 {
    assert_true((reference.elements[i] - m.elements[i]).abs() <= 0.000001)
  }
}

///|
test "PerspectiveCamera clone" {
  let cam = @core.PerspectiveCamera::new(
    fov=90.0,
    aspect=16.0 / 9.0,
    near=1.0,
    far=3.0,
  )
  let cloned_cam = cam.clone()
  let a = cam.as_perspective_camera()
  let b = cloned_cam.as_perspective_camera()
  assert_eq(a.fov, b.fov)
  assert_eq(a.aspect, b.aspect)
  assert_eq(a.near, b.near)
  assert_eq(a.far, b.far)
  assert_eq(a.zoom, b.zoom)
  assert_true(
    cam.as_camera().projection_matrix.equals(
      cloned_cam.as_camera().projection_matrix,
    ),
  )
}

///|
test "PerspectiveCamera clone copies the view" {
  let cam = @core.PerspectiveCamera::new()
  cam.set_view_offset(100, 50, 10, 5, 20, 10)
  let cloned = cam.clone()
  guard cloned.as_perspective_camera().view is Some(view) else {
    fail("no view")
  }
  assert_eq(view.full_width, 100.0)
  view.full_width = 7.0
  guard cam.as_perspective_camera().view is Some(original) else {
    fail("no view")
  }
  assert_eq(original.full_width, 100.0)
}

///|
test "PerspectiveCamera focal length" {
  let cam = @core.PerspectiveCamera::new()
  cam.set_focal_length(35.0)
  assert_true(approx(cam.get_focal_length(), 35.0))
  assert_true(approx(cam.as_perspective_camera().fov, 53.13010235415598))
  assert_eq(cam.get_effective_fov(), cam.as_perspective_camera().fov)
  cam.as_perspective_camera().zoom = 2.0
  assert_true(approx(cam.get_effective_fov(), 28.072486935852957))
}

///|
test "PerspectiveCamera film size" {
  let cam = @core.PerspectiveCamera::new(aspect=2.0)
  assert_eq(cam.get_film_width(), 35.0)
  assert_eq(cam.get_film_height(), 17.5)
  cam.as_perspective_camera().aspect = 0.5
  assert_eq(cam.get_film_width(), 17.5)
  assert_eq(cam.get_film_height(), 35.0)
}

///|
test "PerspectiveCamera view bounds and size" {
  let cam = @core.PerspectiveCamera::new(fov=90.0, aspect=2.0)
  let min = @math.Vector2::new(0, 0)
  let max = @math.Vector2::new(0, 0)
  cam.get_view_bounds(1.0, min, max)
  assert_true(approx(min.x, -2.0) && approx(min.y, -1.0))
  assert_true(approx(max.x, 2.0) && approx(max.y, 1.0))
  let size = @math.Vector2::new(0, 0)
  assert_true(physical_equal(cam.get_view_size(1.0, size), size))
  assert_true(approx(size.x, 4.0) && approx(size.y, 2.0))
}

///|
test "PerspectiveCamera setViewOffset and clearViewOffset" {
  let cam = @core.PerspectiveCamera::new(aspect=1.0)
  let plain = cam.as_camera().projection_matrix.clone()
  cam.set_view_offset(200, 100, 0, 0, 200, 100)
  assert_eq(cam.as_perspective_camera().aspect, 2.0)
  cam.as_perspective_camera().aspect = 1.0
  cam.set_view_offset(100, 100, 0, 0, 100, 100)
  assert_true(matrix_equals4(plain, cam.as_camera().projection_matrix))
  cam.set_view_offset(100, 100, 25, 25, 50, 50)
  assert_false(matrix_equals4(plain, cam.as_camera().projection_matrix))
  cam.clear_view_offset()
  guard cam.as_perspective_camera().view is Some(view) else { fail("no view") }
  assert_false(view.enabled)
  assert_true(matrix_equals4(plain, cam.as_camera().projection_matrix))
}

///|
test "PerspectiveCamera toJSON" {
  let cam = @core.PerspectiveCamera::new(fov=60.0, aspect=2.0)
  cam.set_view_offset(10, 5, 1, 2, 3, 4)
  guard cam.to_json() is Object(json) &&
    json.get("object") is Some(Object(object)) else {
    fail("no object")
  }
  assert_true(object.get("fov") is Some(Number(60.0, ..)))
  assert_true(object.get("aspect") is Some(Number(2.0, ..)))
  assert_true(object.get("filmGauge") is Some(Number(35.0, ..)))
  assert_true(object.get("filmOffset") is Some(Number(0.0, ..)))
  guard object.get("view") is Some(Object(view)) else { fail("no view") }
  assert_true(view.get("enabled") is Some(True))
  assert_true(view.get("offsetY") is Some(Number(2.0, ..)))
}
