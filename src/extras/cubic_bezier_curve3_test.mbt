// Port of upstream test/unit/src/extras/curves/CubicBezierCurve3.tests.js.

///|
fn cubic_bezier_curve3_curve() -> @extras.Curve[@math.Vector3] {
  @extras.CubicBezierCurve3::new(
    v0=vec3(-10.0, 0.0, 2.0),
    v1=vec3(-5.0, 15.0, 4.0),
    v2=vec3(20.0, 15.0, -5.0),
    v3=vec3(10.0, 0.0, 10.0),
  )
}

///|
test "CubicBezierCurve3 extends Curve" {
  let object : @extras.Curve[@math.Vector3] = @extras.CubicBezierCurve3::new()
  ignore(object)
}

///|
test "CubicBezierCurve3 instancing" {
  ignore(@extras.CubicBezierCurve3::new())
}

///|
test "CubicBezierCurve3 type" {
  assert_eq(@extras.CubicBezierCurve3::new().type_, "CubicBezierCurve3")
}

///|
test "CubicBezierCurve3 isCubicBezierCurve3" {
  assert_true(@extras.CubicBezierCurve3::new().kind is CubicBezier(_))
}

///|
test "CubicBezierCurve3 Simple curve" {
  let curve = cubic_bezier_curve3_curve()

  let expected_points = [
    vec3(-10.0, 0.0, 2.0),
    vec3(-3.359375, 8.4375, 1.984375),
    vec3(5.625, 11.25, 1.125),
    vec3(11.796875, 8.4375, 2.703125),
    vec3(10.0, 0.0, 10.0),
  ]
  let mut points = curve.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
  let curve_rev = @extras.CubicBezierCurve3::new(
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
test "CubicBezierCurve3 getLength/getLengths" {
  let curve = cubic_bezier_curve3_curve()

  let length = curve.get_length()
  let expected_length = 39.58103024989427
  assert_num(length, expected_length)
  let expected_lengths : Array[Double] = [
    0.0, 10.73729718231036, 20.19074500737662, 27.154413277853756, 38.453287150114214,
  ]
  let lengths = curve.get_lengths(divisions=expected_lengths.length() - 1)
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "CubicBezierCurve3 getPointAt" {
  let curve = cubic_bezier_curve3_curve()

  let expected_points = [
    vec3(-10.0, 0.0, 2.0),
    vec3(-2.591880240484318, 8.908333501170798, 1.8953420625251136),
    vec3(4.866251460832755, 11.22787914038507, 1.150832855206874),
    vec3(10.0, 0.0, 10.0),
  ]
  let points = [
    curve.get_point_at(0.0, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_point_at(0.3, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_point_at(0.5, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_point_at(1.0, optional_target=vec3(0.0, 0.0, 0.0)),
  ]
  assert_exact_points(points, expected_points)
}

///|
test "CubicBezierCurve3 getTangent/getTangentAt" {
  let curve = cubic_bezier_curve3_curve()

  let mut expected_tangents = [
    vec3(0.3138715439944244, 0.9411440474105875, 0.12542940601858074),
    vec3(0.8351825262580098, 0.54174002562179, -0.09480449605683638),
    vec3(0.9997531780538501, 0.0, -0.02221672728433752),
    vec3(0.40693407933981185, -0.7512629496079668, 0.5196235518317053),
    vec3(-0.42632467075185815, -0.6396469221230213, 0.6396085444448543),
  ]
  let mut tangents = [
    curve.get_tangent(0.0, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent(0.25, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent(0.5, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent(0.75, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent(1.0, optional_target=vec3(0.0, 0.0, 0.0)),
  ]
  assert_num_points(tangents, expected_tangents)
  expected_tangents = [
    vec3(0.3138715439944244, 0.9411440474105875, 0.12542940601858074),
    vec3(0.8016539573770751, 0.5918626760037707, -0.08396133262002324),
    vec3(0.997337559412928, 0.05740742907719314, -0.044968652092444425),
    vec3(0.1389373097746809, -0.7882209938358005, 0.5995032016837588),
    vec3(-0.42632467075185815, -0.6396469221230213, 0.6396085444448543),
  ]
  tangents = [
    curve.get_tangent_at(0.0, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent_at(0.25, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent_at(0.5, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent_at(0.75, optional_target=vec3(0.0, 0.0, 0.0)),
    curve.get_tangent_at(1.0, optional_target=vec3(0.0, 0.0, 0.0)),
  ]
  assert_num_points(tangents, expected_tangents)
}

///|
test "CubicBezierCurve3 getUtoTmapping" {
  let curve = cubic_bezier_curve3_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.5, distance=1.0)
  let expected_somewhere = 0.021163245321323316
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, expected_somewhere)
}

///|
test "CubicBezierCurve3 getSpacedPoints" {
  let curve = cubic_bezier_curve3_curve()

  let expected_points = [
    vec3(-10.0, 0.0, 2.0),
    vec3(-5.756524515061918, 6.568020242700483, 2.22116711170301),
    vec3(1.0003511895116906, 10.49656064587831, 1.4727101010850698),
    vec3(8.767656412295171, 10.784286845278622, 1.2873599519775174),
    vec3(12.306772513558396, 5.545103788071547, 4.909948454535794),
    vec3(10.0, 0.0, 10.0),
  ]
  let points = curve.get_spaced_points()
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}

///|
test "CubicBezierCurve3 computeFrenetFrames" {
  let curve = cubic_bezier_curve3_curve()

  let expected = @extras.FrenetFrames::{
    binormals: [
      vec3(-0.9486358543207215, 0.316370061632252, -6.938893903907228e-18),
      vec3(-0.05491430765311864, 0.9969838307670049, 0.054842137122173326),
      vec3(0.5944656510461876, 0.334836503700931, 0.7310917216844742),
    ],
    normals: [
      vec3(0.03968210891259515, 0.11898683173537697, -0.9921025471723304),
      vec3(-0.047981365124836806, 0.05222670079466692, -0.9974819097732357),
      vec3(0.6818048583242511, -0.6919077473246573, -0.23749906180354932),
    ],
    tangents: [
      vec3(0.3138715439944244, 0.9411440474105875, 0.12542940601858074),
      vec3(0.9973375594129282, 0.05740742907719315, -0.04496865209244443),
      vec3(-0.42632467075185815, -0.6396469221230213, 0.6396085444448543),
    ],
  }
  let frames = curve.compute_frenet_frames(2, closed=false)
  assert_frames(frames, expected)
}
