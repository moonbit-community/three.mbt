// Port of upstream test/unit/src/extras/curves/LineCurve.tests.js.

///|
fn line_curve_points() -> Array[@math.Vector2] {
  [vec2(0.0, 0.0), vec2(10.0, 10.0), vec2(-10.0, 10.0), vec2(-8.0, 5.0)]
}

///|
fn line_curve_curve() -> @extras.Curve[@math.Vector2] {
  @extras.LineCurve::new(v1=line_curve_points()[0], v2=line_curve_points()[1])
}

///|
test "LineCurve extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.LineCurve::new()
  ignore(object)
}

///|
test "LineCurve instancing" {
  ignore(@extras.LineCurve::new())
}

///|
test "LineCurve type" {
  assert_eq(@extras.LineCurve::new().type_, "LineCurve")
}

///|
test "LineCurve isLineCurve" {
  assert_true(@extras.LineCurve::new().kind is Line(_))
}

///|
test "LineCurve getPointAt" {
  let curve = @extras.LineCurve::new(
    v1=line_curve_points()[0],
    v2=line_curve_points()[3],
  )
  let expected_points = [
    vec2(0.0, 0.0),
    vec2(-2.4, 1.5),
    vec2(-4.0, 2.5),
    vec2(-8.0, 5.0),
  ]
  let points = [
    curve.get_point_at(0.0, optional_target=vec2(0.0, 0.0)),
    curve.get_point_at(0.3, optional_target=vec2(0.0, 0.0)),
    curve.get_point_at(0.5, optional_target=vec2(0.0, 0.0)),
    curve.get_point_at(1.0, optional_target=vec2(0.0, 0.0)),
  ]
  assert_exact_points(points, expected_points)
}

///|
test "LineCurve getTangent/getTangentAt" {
  let curve = line_curve_curve()

  let tangent = vec2(0.0, 0.0)
  ignore(curve.get_tangent(0.0, optional_target=tangent))
  let expected_tangent = 0.5.sqrt()
  assert_num(tangent.x, expected_tangent)
  assert_num(tangent.y, expected_tangent)
  ignore(curve.get_tangent_at(0.0, optional_target=tangent))
  assert_num(tangent.x, expected_tangent)
  assert_num(tangent.y, expected_tangent)
}

///|
test "LineCurve Simple curve" {
  let mut curve = line_curve_curve()
  let mut expected_points = [
    vec2(0.0, 0.0),
    vec2(2.0, 2.0),
    vec2(4.0, 4.0),
    vec2(6.0, 6.0),
    vec2(8.0, 8.0),
    vec2(10.0, 10.0),
  ]
  let mut points = curve.get_points()
  assert_exact_points(points, expected_points)
  curve = @extras.LineCurve::new(
    v1=line_curve_points()[1],
    v2=line_curve_points()[2],
  )
  expected_points = [
    vec2(10.0, 10.0),
    vec2(6.0, 10.0),
    vec2(2.0, 10.0),
    vec2(-2.0, 10.0),
    vec2(-6.0, 10.0),
    vec2(-10.0, 10.0),
  ]
  points = curve.get_points()
  assert_exact_points(points, expected_points)
}

///|
test "LineCurve getLength/getLengths" {
  let curve = line_curve_curve()

  let length = curve.get_length()
  let expected_length = 200.0.sqrt()
  assert_num(length, expected_length)
  let lengths = curve.get_lengths(divisions=5)
  let expected_lengths : Array[Double] = [
    0.0,
    8.0.sqrt(),
    32.0.sqrt(),
    72.0.sqrt(),
    128.0.sqrt(),
    200.0.sqrt(),
  ]
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "LineCurve getUtoTmapping" {
  let curve = line_curve_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.3, distance=0.0)
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, 0.3)
}

///|
test "LineCurve getSpacedPoints" {
  let curve = line_curve_curve()

  let expected_points = [
    vec2(0.0, 0.0),
    vec2(2.5, 2.5),
    vec2(5.0, 5.0),
    vec2(7.5, 7.5),
    vec2(10.0, 10.0),
  ]
  let points = curve.get_spaced_points(divisions=4)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}
