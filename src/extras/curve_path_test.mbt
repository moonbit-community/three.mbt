// Port of upstream test/unit/src/extras/core/CurvePath.tests.js, plus what it leaves as todo.

///|
test "CurvePath extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.CurvePath::new()
  assert_true(object.kind is CurvePath(_))
}

///|
test "CurvePath type" {
  let object : @extras.Curve[@math.Vector2] = @extras.CurvePath::new()
  assert_eq(object.type_, "CurvePath")
}

///|
fn curve_path_l() -> @extras.Curve[@math.Vector2] {
  let path : @extras.Curve[@math.Vector2] = @extras.CurvePath::new()
  path.add(@extras.LineCurve::new(v1=vec2(0.0, 0.0), v2=vec2(3.0, 0.0)))
  path.add(@extras.LineCurve::new(v1=vec2(3.0, 0.0), v2=vec2(3.0, 4.0)))
  path
}

///|
test "CurvePath length and curve lengths" {
  let path = curve_path_l()
  assert_eq(path.get_curve_lengths(), [3.0, 7.0])
  assert_eq(path.get_length(), 7.0)
}

///|
test "CurvePath get_point walks the sub-curves" {
  let path = curve_path_l()
  assert_num_list(path.get_point(0.0).to_array(), [0.0, 0.0])
  assert_num_list(path.get_point(3.0 / 7.0).to_array(), [3.0, 0.0])
  assert_num_list(path.get_point(1.0).to_array(), [3.0, 4.0])
}

///|
test "CurvePath get_point past the end is null" {
  let path = curve_path_l()
  assert_true(path.get_point_or_null(1.5) is None)
}

///|
test "CurvePath close_path adds a line only when open" {
  let path = curve_path_l()
  assert_eq(path.close_path().curves().length(), 3)
  assert_eq(path.curves()[2].type_, "LineCurve")
  assert_eq(path.close_path().curves().length(), 3)
  let path3 : @extras.Curve[@math.Vector3] = @extras.CurvePath::new()
  path3.add(
    @extras.LineCurve3::new(v1=vec3(0.0, 0.0, 0.0), v2=vec3(1.0, 1.0, 1.0)),
  )
  assert_eq(path3.close_path().curves()[1].type_, "LineCurve3")
}

///|
test "CurvePath get_points drops consecutive duplicates and honours auto_close" {
  let path = curve_path_l()
  assert_eq(path.get_points().length(), 3)
  path.set_auto_close(true)
  let points = path.get_points()
  assert_eq(points.length(), 4)
  assert_true(physical_equal(points[3], points[0]))
}

///|
test "CurvePath get_spaced_points defaults to 40 divisions" {
  let path = curve_path_l()
  assert_eq(path.get_spaced_points().length(), 41)
  path.set_auto_close(true)
  assert_eq(path.get_spaced_points().length(), 42)
}

///|
test "CurvePath JSON round trip dispatches on the curve type" {
  let path = curve_path_l()
  path.add(@extras.EllipseCurve::new(a_x=3.0, a_y=4.0))
  path.add(@extras.ArcCurve::new())
  let restored : @extras.Curve[@math.Vector2] = @extras.CurvePath::new().from_json(
    path.to_json(),
  )
  assert_eq(restored.to_json().stringify(), path.to_json().stringify())
  assert_eq(restored.curves()[3].type_, "ArcCurve")
}
