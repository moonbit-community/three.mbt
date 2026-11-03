// Port of upstream test/unit/src/extras/curves/QuadraticBezierCurve.tests.js.

///|
fn quadratic_bezier_curve_curve() -> @extras.Curve[@math.Vector2] {
  @extras.QuadraticBezierCurve::new(
    v0=vec2(-10.0, 0.0),
    v1=vec2(20.0, 15.0),
    v2=vec2(10.0, 0.0),
  )
}

///|
test "QuadraticBezierCurve extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.QuadraticBezierCurve::new()
  ignore(object)
}

///|
test "QuadraticBezierCurve instancing" {
  ignore(@extras.QuadraticBezierCurve::new())
}

///|
test "QuadraticBezierCurve type" {
  assert_eq(@extras.QuadraticBezierCurve::new().type_, "QuadraticBezierCurve")
}

///|
test "QuadraticBezierCurve isQuadraticBezierCurve" {
  assert_true(@extras.QuadraticBezierCurve::new().kind is QuadraticBezier(_))
}

///|
test "QuadraticBezierCurve Simple curve" {
  let curve = quadratic_bezier_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(2.5, 5.625),
    vec2(10.0, 7.5),
    vec2(12.5, 5.625),
    vec2(10.0, 0.0),
  ]
  let mut points = curve.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
  let curve_rev = @extras.QuadraticBezierCurve::new(
    v0=quadratic_v(curve, 2),
    v1=quadratic_v(curve, 1),
    v2=quadratic_v(curve, 0),
  )
  points = curve_rev.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points.rev())
}

///|
test "QuadraticBezierCurve getLength/getLengths" {
  let curve = quadratic_bezier_curve_curve()

  let length = curve.get_length()
  let expected_length = 31.269026549416683
  assert_num(length, expected_length)
  let expected_lengths : Array[Double] = [
    0.0, 13.707320124663317, 21.43814317269643, 24.56314317269643, 30.718679298818998,
  ]
  let lengths = curve.get_lengths(divisions=expected_lengths.length() - 1)
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "QuadraticBezierCurve getPointAt" {
  let curve = quadratic_bezier_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-1.5127849599387615, 3.993582003773624),
    vec2(4.310076165722796, 6.269921971403917),
    vec2(10.0, 0.0),
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
test "QuadraticBezierCurve getTangent/getTangentAt" {
  let curve = quadratic_bezier_curve_curve()

  let mut expected_tangents = [
    vec2(0.89443315420562, 0.44720166888975904),
    vec2(0.936329177569021, 0.3511234415884543),
    vec2(1.0, 0.0),
    vec2(-5.921189464667277e-13, -1.0),
    vec2(-0.5546617882904897, -0.8320758983472577),
  ]
  let mut tangents = [
    curve.get_tangent(0.0, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.25, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.5, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(0.75, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent(1.0, optional_target=vec2(0.0, 0.0)),
  ]
  assert_num_points(tangents, expected_tangents)
  expected_tangents = [
    vec2(0.89443315420562, 0.44720166888975904),
    vec2(0.9125211423360805, 0.40902954024086674),
    vec2(0.9480289098765387, 0.3181842014278863),
    vec2(0.7969127189169473, -0.6040944615111106),
    vec2(-0.5546617882904897, -0.8320758983472577),
  ]
  tangents = [
    curve.get_tangent_at(0.0, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent_at(0.25, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent_at(0.5, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent_at(0.75, optional_target=vec2(0.0, 0.0)),
    curve.get_tangent_at(1.0, optional_target=vec2(0.0, 0.0)),
  ]
  assert_num_points(tangents, expected_tangents)
}

///|
test "QuadraticBezierCurve getUtoTmapping" {
  let curve = quadratic_bezier_curve_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.5, distance=1.0)
  let expected_somewhere = 0.015073978276116116
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, expected_somewhere)
}

///|
test "QuadraticBezierCurve getSpacedPoints" {
  let curve = quadratic_bezier_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-4.366603655406173, 2.715408933540383),
    vec2(1.3752241477827831, 5.191972084404416),
    vec2(7.312990279153634, 7.136310044848586),
    vec2(12.499856644824826, 5.653289188715387),
    vec2(10.0, 0.0),
  ]
  let points = curve.get_spaced_points()
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}
