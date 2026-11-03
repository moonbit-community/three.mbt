// Port of upstream test/unit/src/extras/curves/CubicBezierCurve.tests.js.

///|
fn cubic_bezier_curve_curve() -> @extras.Curve[@math.Vector2] {
  @extras.CubicBezierCurve::new(
    v0=vec2(-10.0, 0.0),
    v1=vec2(-5.0, 15.0),
    v2=vec2(20.0, 15.0),
    v3=vec2(10.0, 0.0),
  )
}

///|
test "CubicBezierCurve extends Curve" {
  let object : @extras.Curve[@math.Vector2] = @extras.CubicBezierCurve::new()
  ignore(object)
}

///|
test "CubicBezierCurve instancing" {
  ignore(@extras.CubicBezierCurve::new())
}

///|
test "CubicBezierCurve type" {
  assert_eq(@extras.CubicBezierCurve::new().type_, "CubicBezierCurve")
}

///|
test "CubicBezierCurve isCubicBezierCurve" {
  assert_true(@extras.CubicBezierCurve::new().kind is CubicBezier(_))
}

///|
test "CubicBezierCurve Simple curve" {
  let curve = cubic_bezier_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-3.359375, 8.4375),
    vec2(5.625, 11.25),
    vec2(11.796875, 8.4375),
    vec2(10.0, 0.0),
  ]
  let mut points = curve.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
  let curve_rev = @extras.CubicBezierCurve::new(
    v0=cubic_v(curve, 3),
    v1=cubic_v(curve, 2),
    v2=cubic_v(curve, 1),
    v3=cubic_v(curve, 0),
  )
  points = curve_rev.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points.rev())
}

///|
test "CubicBezierCurve getLength/getLengths" {
  let curve = cubic_bezier_curve_curve()

  let length = curve.get_length()
  let expected_length = 36.64630888504102
  assert_num(length, expected_length)
  let expected_lengths : Array[Double] = [
    0.0, 10.737285813492393, 20.15159143794633, 26.93408340370825, 35.56079575637337,
  ]
  let lengths = curve.get_lengths(divisions=expected_lengths.length() - 1)
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "CubicBezierCurve getPointAt" {
  let curve = cubic_bezier_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-3.3188282598022596, 8.463722639089221),
    vec2(3.4718554735926617, 11.07899406116314),
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
test "CubicBezierCurve getTangent/getTangentAt" {
  let curve = cubic_bezier_curve_curve()

  let mut expected_tangents = [
    vec2(0.316370061632252, 0.9486358543207215),
    vec2(0.838961283088303, 0.5441911111721949),
    vec2(1.0, 0.0),
    vec2(0.47628313192245453, -0.8792919755383518),
    vec2(-0.5546041767829665, -0.8321142992972107),
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
    vec2(0.316370061632252, 0.9486358543207215),
    vec2(0.7794223085548987, 0.6264988945935596),
    vec2(0.988266153082452, 0.15274164681452052),
    vec2(0.5004110404199416, -0.8657879593906534),
    vec2(-0.5546041767829665, -0.8321142992972107),
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
test "CubicBezierCurve getUtoTmapping" {
  let curve = cubic_bezier_curve_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.5, distance=1.0)
  let expected_somewhere = 0.02130029182257093
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, expected_somewhere)
}

///|
test "CubicBezierCurve getSpacedPoints" {
  let curve = cubic_bezier_curve_curve()

  let expected_points = [
    vec2(-10.0, 0.0),
    vec2(-6.16826457740703, 6.17025727295411),
    vec2(-0.058874033259857184, 10.1240558653185),
    vec2(7.123523032625162, 11.154913869041575),
    vec2(12.301846885754463, 6.808865855469985),
    vec2(10.0, 0.0),
  ]
  let points = curve.get_spaced_points()
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}
