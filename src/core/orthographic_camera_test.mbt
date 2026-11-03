///|
test "OrthographicCamera Extending" {
  let object = @core.OrthographicCamera::new()
  assert_true(object.is_camera())
  assert_true(object.is_orthographic_camera())
}

///|
test "OrthographicCamera type" {
  assert_eq(@core.OrthographicCamera::new().type_, "OrthographicCamera")
}

///|
test "OrthographicCamera updateProjectionMatrix" {
  let left = -1.0
  let right = 1.0
  let top = 1.0
  let bottom = -1.0
  let near = 1.0
  let far = 3.0
  let cam = @core.OrthographicCamera::new(
    left~,
    right~,
    top~,
    bottom~,
    near~,
    far~,
  )
  let m = cam.as_camera().projection_matrix.elements
  assert_eq(m[0], 2.0 / (right - left))
  assert_eq(m[5], 2.0 / (top - bottom))
  assert_eq(m[10], -2.0 / (far - near))
  assert_eq(m[12], -((right + left) / (right - left)))
  assert_eq(m[13], -((top + bottom) / (top - bottom)))
  assert_eq(m[14], -((far + near) / (far - near)))
}

///|
test "OrthographicCamera clone" {
  let cam = @core.OrthographicCamera::new(
    left=-1.5,
    right=1.5,
    top=1.0,
    bottom=-1.0,
    near=0.1,
    far=42.0,
  )
  let a = cam.as_orthographic_camera()
  let b = cam.clone().as_orthographic_camera()
  assert_eq(a.left, b.left)
  assert_eq(a.right, b.right)
  assert_eq(a.top, b.top)
  assert_eq(a.bottom, b.bottom)
  assert_eq(a.near, b.near)
  assert_eq(a.far, b.far)
  assert_eq(a.zoom, b.zoom)
}

///|
test "OrthographicCamera setViewOffset and clearViewOffset" {
  let cam = @core.OrthographicCamera::new()
  let plain = cam.as_camera().projection_matrix.clone()
  cam.set_view_offset(100, 100, 0, 0, 100, 100)
  assert_true(matrix_equals4(plain, cam.as_camera().projection_matrix))
  cam.set_view_offset(100, 100, 25, 25, 50, 50)
  assert_false(matrix_equals4(plain, cam.as_camera().projection_matrix))
  cam.clear_view_offset()
  assert_true(matrix_equals4(plain, cam.as_camera().projection_matrix))
}

///|
test "OrthographicCamera toJSON" {
  let cam = @core.OrthographicCamera::new(left=-2.0)
  guard cam.to_json() is Object(json) &&
    json.get("object") is Some(Object(object)) else {
    fail("no object")
  }
  assert_true(object.get("left") is Some(Number(-2.0, ..)))
  assert_true(object.get("zoom") is Some(Number(1.0, ..)))
  assert_true(object.get("view") is None)
}
