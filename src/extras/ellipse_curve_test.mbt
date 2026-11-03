// Port of upstream test/unit/src/extras/curves/EllipseCurve.tests.js.

///|
fn ellipse_curve_curve() -> @extras.Curve[@math.Vector2] {
  @extras.EllipseCurve::new(
    a_x=0.0,
    a_y=0.0,
    x_radius=10.0,
    y_radius=10.0,
    a_start_angle=0.0,
    a_end_angle=2.0 * test_pi(),
    a_clockwise=false,
    a_rotation=0.0,
  )
}

///|
test "EllipseCurve extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.EllipseCurve::new()
  ignore(object)
}

///|
test "EllipseCurve instancing" {
  ignore(@extras.EllipseCurve::new())
}

///|
test "EllipseCurve type" {
  assert_eq(@extras.EllipseCurve::new().type_, "EllipseCurve")
}

///|
test "EllipseCurve isEllipseCurve" {
  assert_true(@extras.EllipseCurve::new().kind is Ellipse(_))
}

///|
test "EllipseCurve Simple curve" {
  let curve = ellipse_curve_curve()

  let expected_points = [
    vec2(10.0, 0.0),
    vec2(0.0, 10.0),
    vec2(-10.0, 0.0),
    vec2(0.0, -10.0),
    vec2(10.0, 0.0),
  ]
  let points = curve.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}

///|
test "EllipseCurve getLength/getLengths" {
  let curve = ellipse_curve_curve()

  let length = curve.get_length()
  let expected_length = 62.829269247282795
  assert_num(length, expected_length)
  let lengths = curve.get_lengths(divisions=5)
  let expected_lengths : Array[Double] = [
    0.0, 11.755705045849462, 23.51141009169892, 35.26711513754839, 47.02282018339785,
    58.77852522924731,
  ]
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "EllipseCurve getPoint/getPointAt" {
  let curve = ellipse_curve_curve()

  let test_values = [0.0, 0.3, 0.5, 0.7, 1.0]
  let p = vec2(0.0, 0.0)
  let a = vec2(0.0, 0.0)
  for val in test_values {
    let expected_x = @cmath.cos(val * test_pi() * 2.0) * 10.0
    let expected_y = @cmath.sin(val * test_pi() * 2.0) * 10.0
    ignore(curve.get_point(val, optional_target=p))
    ignore(curve.get_point_at(val, optional_target=a))
    assert_num(p.x, expected_x)
    assert_num(p.y, expected_y)
    assert_num(a.x, expected_x)
    assert_num(a.y, expected_y)
  }
}

///|
test "EllipseCurve getTangent" {
  let curve = ellipse_curve_curve()

  let expected_tangents = [
    vec2(-0.000314159260186071, 0.9999999506519786),
    vec2(-1.0, 0.0),
    vec2(0.0, -1.0),
    vec2(1.0, 0.0),
    vec2(0.00031415926018600165, 0.9999999506519784),
  ]
  let tangents = [
    curve.get_tangent(0.0, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.25, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.5, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.75, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(1.0, optional_target=vec2(0.0, 0.0)),
  ]
  assert_num_points(tangents, expected_tangents)
}

///|
test "EllipseCurve getUtoTmapping" {
  let curve = ellipse_curve_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.7, distance=1.0)
  let expected_somewhere = 0.01591614882650014
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, expected_somewhere)
}

///|
test "EllipseCurve getSpacedPoints" {
  let curve = ellipse_curve_curve()

  let expected_points = [
    vec2(10.0, 0.0),
    vec2(3.0901699437494603, 9.51056516295154),
    vec2(-8.090169943749492, 5.877852522924707),
    vec2(-8.090169943749459, -5.877852522924751),
    vec2(3.0901699437494807, -9.510565162951533),
    vec2(10.0, -2.4492935982947065e-15),
  ]
  let points = curve.get_spaced_points()
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}
