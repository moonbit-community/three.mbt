// Port of upstream test/unit/src/extras/curves/SplineCurve.tests.js.

///|
fn spline_curve_curve() -> @extras.Curve[@math.Vector2] {
  @extras.SplineCurve::new(points=[
    vec2(-10.0, 0.0),
    vec2(-5.0, 5.0),
    vec2(0.0, 0.0),
    vec2(5.0, -5.0),
    vec2(10.0, 0.0),
  ])
}

///|
test "SplineCurve extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.SplineCurve::new()
  ignore(object)
}

///|
test "SplineCurve instancing" {
  ignore(@extras.SplineCurve::new())
}

///|
test "SplineCurve type" {
  assert_eq(@extras.SplineCurve::new().type_, "SplineCurve")
}

///|
test "SplineCurve isSplineCurve" {
  assert_true(@extras.SplineCurve::new().kind is Spline(_))
}

///|
test "SplineCurve Simple curve" {
  let curve = spline_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-6.08, 4.56),
    vec2(-2.0, 2.48),
    vec2(2.0, -2.48),
    vec2(6.08, -4.56),
    vec2(10.0, 0.0),
  ]
  let mut points = curve.get_points(divisions=5)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
  points = curve.get_points(divisions=4)
  assert_exact_points(points, spline_points(curve))
}

///|
test "SplineCurve getLength/getLengths" {
  let curve = spline_curve_curve()

  let length = curve.get_length()
  let expected_length = 28.876950901868135
  assert_num(length, expected_length)
  let expected_lengths : Array[Double] = [
    0.0,
    50.0.sqrt(),
    200.0.sqrt(),
    450.0.sqrt(),
    800.0.sqrt(),
  ]
  let lengths = curve.get_lengths(divisions=4)
  assert_exact_list(lengths, expected_lengths)
}

///|
test "SplineCurve getPointAt" {
  let curve = spline_curve_curve()

  let point = vec2(0.0, 0.0)
  assert_true(
    curve
    .get_point_at(0.0, optional_target=point)
    .equals(spline_points(curve)[0]),
  )
  assert_true(
    curve
    .get_point_at(1.0, optional_target=point)
    .equals(spline_points(curve)[4]),
  )
  ignore(curve.get_point_at(0.5, optional_target=point))
  assert_num(point.x, 0.0)
  assert_num(point.y, 0.0)
}

///|
test "SplineCurve getTangent" {
  let curve = spline_curve_curve()

  let expected_tangent = [
    vec2(0.7068243340243188, 0.7073891155729485),
    vec2(0.7069654305325396, -0.7072481035902046),
    vec2(0.7068243340245123, 0.7073891155727552),
  ]
  let tangents = [
    curve.get_tangent(0.0, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.5, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(1.0, optional_target=vec2(0.0, 0.0)),
  ]
  assert_num_points(tangents, expected_tangent)
}

///|
test "SplineCurve getUtoTmapping" {
  let curve = spline_curve_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let middle = curve.get_uto_tmapping(0.5, distance=0.0)
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(middle, 0.5)
}

///|
test "SplineCurve getSpacedPoints" {
  let curve = spline_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-4.996509634683014, 4.999995128640857),
    vec2(0.0, 0.0),
    vec2(4.996509634683006, -4.999995128640857),
    vec2(10.0, 0.0),
  ]
  let points = curve.get_spaced_points(divisions=4)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}
