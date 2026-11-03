// Port of upstream test/unit/src/extras/core/Path.tests.js, plus what it leaves as todo.

///|
test "Path extends CurvePath" {
  assert_true(@extras.Path::new().curve.kind is Path(_, _))
}

///|
test "Path type" {
  assert_eq(@extras.Path::new().curve.type_, "Path")
}

///|
test "Path set_from_points" {
  let path = @extras.Path::new(points=[
    vec2(0.0, 0.0),
    vec2(1.0, 0.0),
    vec2(1.0, 1.0),
  ])
  assert_eq(path.curves().length(), 2)
  assert_eq(path.current_point().to_array(), [1.0, 1.0])
}

///|
test "Path drawing methods chain and add the upstream curve classes" {
  let path = @extras.Path::new()
    .move_to(1.0, 1.0)
    .line_to(2.0, 1.0)
    .quadratic_curve_to(3.0, 1.0, 3.0, 2.0)
    .bezier_curve_to(3.0, 3.0, 2.0, 3.0, 2.0, 2.0)
    .spline_thru([vec2(1.0, 2.0), vec2(1.0, 1.0)])
  assert_eq(path.curves().map(curve => curve.type_), [
    "LineCurve", "QuadraticBezierCurve", "CubicBezierCurve", "SplineCurve",
  ])
  assert_eq(path.current_point().to_array(), [1.0, 1.0])
}

///|
test "Path arc joins the current point with a line" {
  let path = @extras.Path::new().move_to(0.0, 0.0).line_to(1.0, 0.0)
  ignore(path.absarc(5.0, 0.0, 1.0, 0.0, test_pi()))
  assert_eq(path.curves().map(curve => curve.type_), [
    "LineCurve", "LineCurve", "EllipseCurve",
  ])
  assert_num_list(path.current_point().to_array(), [4.0, 0.0])
}

///|
test "Path arc and ellipse are relative to the current point" {
  let path = @extras.Path::new().move_to(1.0, 2.0)
  ignore(path.arc(1.0, 1.0, 1.0, 0.0, test_pi() / 2.0))
  guard path.curves()[0].kind is Ellipse(ellipse) else {
    fail("not an ellipse")
  }
  assert_eq(ellipse.a_x, 2.0)
  assert_eq(ellipse.a_y, 3.0)
}

///|
test "Path JSON and clone keep the current point" {
  let path = @extras.Path::new().move_to(1.0, 2.0).line_to(3.0, 4.0)
  let restored = @extras.Path::new().from_json(path.to_json())
  assert_eq(restored.current_point().to_array(), [3.0, 4.0])
  assert_eq(path.clone().current_point().to_array(), [3.0, 4.0])
  assert_eq(restored.to_json().stringify(), path.to_json().stringify())
}
