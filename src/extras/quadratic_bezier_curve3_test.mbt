// Port of upstream test/unit/src/extras/curves/QuadraticBezierCurve3.tests.js.

///|
fn quadratic_bezier_curve3_curve() -> @extras.Curve[@math.Vector3] {
  @extras.QuadraticBezierCurve3::new(
    v0=vec3(-10.0, 0.0, 2.0),
    v1=vec3(20.0, 15.0, -5.0),
    v2=vec3(10.0, 0.0, 10.0),
  )
}

///|
test "QuadraticBezierCurve3 extends Curve" {
  let object : @extras.Curve[@math.Vector3] = @extras.QuadraticBezierCurve3::new()
  ignore(object)
}

///|
test "QuadraticBezierCurve3 instancing" {
  ignore(@extras.QuadraticBezierCurve3::new())
}

///|
test "QuadraticBezierCurve3 type" {
  assert_eq(@extras.QuadraticBezierCurve3::new().type_, "QuadraticBezierCurve3")
}

///|
test "QuadraticBezierCurve3 isQuadraticBezierCurve3" {
  assert_true(@extras.QuadraticBezierCurve3::new().kind is QuadraticBezier(_))
}

///|
test "QuadraticBezierCurve3 Simple curve" {
  let curve = quadratic_bezier_curve3_curve()

  let expected_points = [
    vec3(-10.0, 0.0, 2.0),
    vec3(2.5, 5.625, -0.125),
    vec3(10.0, 7.5, 0.5),
    vec3(12.5, 5.625, 3.875),
    vec3(10.0, 0.0, 10.0),
  ]
  let mut points = curve.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
  let curve_rev = @extras.QuadraticBezierCurve3::new(
    v0=quadratic_v(curve, 2),
    v1=quadratic_v(curve, 1),
    v2=quadratic_v(curve, 0),
  )
  points = curve_rev.get_points(divisions=expected_points.length() - 1)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points.rev())
}

///|
test "QuadraticBezierCurve3 getLength/getLengths" {
  let curve = quadratic_bezier_curve3_curve()

  let length = curve.get_length()
  let expected_length = 35.47294274967861
  assert_num(length, expected_length)
  let expected_lengths : Array[Double] = [
    0.0, 13.871057998581074, 21.62710402732536, 26.226696400568883, 34.91037361704809,
  ]
  let lengths = curve.get_lengths(divisions=expected_lengths.length() - 1)
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "QuadraticBezierCurve3 getPointAt" {
  let curve = quadratic_bezier_curve3_curve()

  let expected_points = [
    vec3(-10.0, 0.0, 2.0),
    vec3(-0.4981634504454243, 4.427089043881476, 0.19308849757196012),
    vec3(6.149415812887238, 6.838853310980195, -0.20278120208668637),
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
test "QuadraticBezierCurve3 getTangent/getTangentAt" {
  let curve = quadratic_bezier_curve3_curve()

  let mut expected_tangents = [
    vec3(0.8755715084258769, 0.4377711603816079, -0.2042815331129452),
    vec3(0.9340289249885844, 0.3502608468707904, -0.07005216937416067),
    vec3(0.9284766908853163, 0.0, 0.37139067635396156),
    vec3(-3.669031233375946e-13, -0.6196442885791218, 0.7848827655333463),
    vec3(-0.4263618889888853, -0.6396068005601663, 0.6396238584473043),
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
    vec3(0.8755715084258769, 0.4377711603816079, -0.2042815331129452),
    vec3(0.9060725703490549, 0.3984742932857448, -0.14230507668907377),
    vec3(0.9621604167456882, 0.2688562845452628, 0.044312872940942424),
    vec3(0.016586454041780826, -0.6163270940470614, 0.7873155674098058),
    vec3(-0.4263618889888853, -0.6396068005601663, 0.6396238584473043),
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
test "QuadraticBezierCurve3 getUtoTmapping" {
  let curve = quadratic_bezier_curve3_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.5, distance=1.0)
  let expected_somewhere = 0.014760890927167196
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, expected_somewhere)
}

///|
test "QuadraticBezierCurve3 getSpacedPoints" {
  let curve = quadratic_bezier_curve3_curve()

  let expected_points = [
    vec3(-10.0, 0.0, 2.0),
    vec3(-3.712652983516992, 3.015179001762753, 0.6957120710270492),
    vec3(2.7830973773262975, 5.730399338061483, -0.1452668772806931),
    vec3(9.575825284074465, 7.48754187603603, 0.3461104039841496),
    vec3(12.345199937734154, 4.575759904730531, 5.142117429101656),
    vec3(10.0, 0.0, 10.0),
  ]
  let points = curve.get_spaced_points()
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}

///|
test "QuadraticBezierCurve3 computeFrenetFrames" {
  let curve = quadratic_bezier_curve3_curve()

  let expected = @extras.FrenetFrames::{
    binormals: [
      vec3(-0.447201668889759, 0.8944331542056199, 0.0),
      vec3(-0.2684231751110917, 0.9631753839815436, -0.01556209353802903),
      vec3(0.3459273556592433, 0.53807011680075, 0.7686447905324219),
    ],
    normals: [
      vec3(-0.18271617600817133, -0.09135504253146765, -0.9789121795283909),
      vec3(0.046865035058597876, -0.003078628350883253, -0.9988964863970807),
      vec3(0.8357929194629689, -0.5489842348221077, 0.008155102228190641),
    ],
    tangents: [
      vec3(0.8755715084258767, 0.4377711603816078, -0.20428153311294514),
      vec3(0.9621604167456884, 0.26885628454526284, 0.04431287294094243),
      vec3(-0.4263618889888853, -0.6396068005601663, 0.6396238584473043),
    ],
  }
  let frames = curve.compute_frenet_frames(2, closed=false)
  assert_frames(frames, expected)
}
