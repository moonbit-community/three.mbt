// Port of upstream test/unit/src/extras/curves/CatmullRomCurve3.tests.js.

///|
fn catmull_positions() -> Array[@math.Vector3] {
  [
    vec3(-60.0, -100.0, 60.0),
    vec3(-60.0, 20.0, 60.0),
    vec3(-60.0, 120.0, 60.0),
    vec3(60.0, 20.0, -60.0),
    vec3(60.0, -100.0, -60.0),
  ]
}

///|
test "CatmullRomCurve3 extends Curve" {
  let object : @extras.Curve[@math.Vector3] = @extras.CatmullRomCurve3::new()
  ignore(object)
}

///|
test "CatmullRomCurve3 instancing" {
  ignore(@extras.CatmullRomCurve3::new())
}

///|
test "CatmullRomCurve3 type" {
  assert_eq(@extras.CatmullRomCurve3::new().type_, "CatmullRomCurve3")
}

///|
test "CatmullRomCurve3 isCatmullRomCurve3" {
  assert_true(@extras.CatmullRomCurve3::new().kind is CatmullRom(_))
}

///|
test "CatmullRomCurve3 catmullrom check" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let expected_points = [
    vec3(-60.0, -100.0, 60.0),
    vec3(-60.0, -51.04, 60.0),
    vec3(-60.0, -2.7199999999999998, 60.0),
    vec3(-61.92, 44.48, 61.92),
    vec3(-68.64, 95.36000000000001, 68.64),
    vec3(-60.0, 120.0, 60.0),
    vec3(-14.880000000000017, 95.36000000000001, 14.880000000000017),
    vec3(41.75999999999997, 44.48000000000003, -41.75999999999997),
    vec3(67.68, -2.720000000000023, -67.68),
    vec3(65.75999999999999, -51.04000000000001, -65.75999999999999),
    vec3(60.0, -100.0, -60.0),
  ]
  let points = curve.get_points(divisions=10)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}

///|
test "CatmullRomCurve3 chordal basic check" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "chordal")
  let expected_points = [
    vec3(-60.0, -100.0, 60.0),
    vec3(-60.0, -52.0, 60.0),
    vec3(-60.0, -4.0, 60.0),
    vec3(-60.656435889910924, 41.62455386421379, 60.656435889910924),
    vec3(-62.95396150459915, 87.31049238896205, 62.95396150459915),
    vec3(-60.0, 120.0, 60.0),
    vec3(-16.302568199486444, 114.1500463116312, 16.302568199486444),
    vec3(42.998098664956586, 54.017050116427455, -42.998098664956586),
    vec3(63.542500175682434, -1.137153397546383, -63.542500175682434),
    vec3(62.65687513176183, -49.85286504815978, -62.65687513176183),
    vec3(60.00000000000001, -100.0, -60.00000000000001),
  ]
  let points = curve.get_points(divisions=10)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}

///|
test "CatmullRomCurve3 centripetal basic check" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "centripetal")
  let expected_points = [
    vec3(-60.0, -100.0, 60.0),
    vec3(-60.0, -51.47527724919028, 60.0),
    vec3(-60.0, -3.300369665587032, 60.0),
    vec3(-61.13836565863938, 42.86306307781241, 61.13836565863938),
    vec3(-65.1226454638772, 90.69743905511538, 65.1226454638772),
    vec3(-60.0, 120.0, 60.0),
    vec3(-15.620412575504497, 103.10790870179872, 15.620412575504497),
    vec3(42.384384731047874, 48.35477686933143, -42.384384731047874),
    vec3(65.25545512241153, -1.646250966068339, -65.25545512241153),
    vec3(63.94159134180865, -50.234688224551256, -63.94159134180865),
    vec3(59.99999999999999, -100.0, -59.99999999999999),
  ]
  let points = curve.get_points(divisions=10)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}

///|
test "CatmullRomCurve3 closed catmullrom basic check" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  set_closed(curve, true)
  let expected_points = [
    vec3(-60.0, -100.0, 60.0),
    vec3(-67.5, -46.25, 67.5),
    vec3(-60.0, 20.0, 60.0),
    vec3(-67.5, 83.75, 67.5),
    vec3(-60.0, 120.0, 60.0),
    vec3(0.0, 83.75, 0.0),
    vec3(60.0, 20.0, -60.0),
    vec3(75.0, -46.25, -75.0),
    vec3(60.0, -100.0, -60.0),
    vec3(0.0, -115.0, 0.0),
    vec3(-60.0, -100.0, 60.0),
  ]
  let points = curve.get_points(divisions=10)
  assert_eq(points.length(), expected_points.length())
  assert_num_points(points, expected_points)
}

///|
test "CatmullRomCurve3 getLength/getLengths" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let length = curve.get_length()
  let expected_length = 551.549686276872
  assert_num(length, expected_length)
  let expected_lengths : Array[Double] = [
    0.0, 120.0, 220.0, 416.9771560359221, 536.9771560359221,
  ]
  let lengths = curve.get_lengths(divisions=expected_lengths.length() - 1)
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "CatmullRomCurve3 getPointAt" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let expected_points = [
    vec3(-60.0, -100.0, 60.0),
    vec3(-64.84177333183106, 64.86956465359813, 64.84177333183106),
    vec3(-28.288507045700854, 104.83101184518996, 28.288507045700854),
    vec3(60.0, -100.0, -60.0),
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
test "CatmullRomCurve3 getTangent/getTangentAt" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let mut expected_tangents = [
    vec3(0.0, 1.0, 0.0),
    vec3(-0.0001090274561657922, 0.9999999881130137, 0.0001090274561657922),
    vec3(0.7071067811865475, -2.0930381713877622e-13, -0.7071067811865475),
    vec3(0.43189437062802816, -0.7917919583070032, -0.43189437062802816),
    vec3(-0.00019991333100812723, -0.9999999600346592, 0.00019991333100812723),
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
    vec3(0.0, 1.0, 0.0),
    vec3(-0.10709018822205997, 0.9884651653817284, 0.10709018822205997),
    vec3(0.6396363672964268, -0.4262987629159402, -0.6396363672964268),
    vec3(0.5077298411616501, -0.6960034603275557, -0.5077298411616501),
    vec3(-0.00019991333100812723, -0.9999999600346592, 0.00019991333100812723),
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
test "CatmullRomCurve3 computeFrenetFrames" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let expected = @extras.FrenetFrames::{
    binormals: [
      vec3(-1.0, 0.0, 0.0),
      vec3(-0.28685061854203, 0.6396363672964267, -0.7131493814579701),
      vec3(-1.9982670528160395e-8, -0.0001999133310081272, -0.9999999800173295),
    ],
    normals: [
      vec3(0.0, 0.0, -1.0),
      vec3(-0.7131493814579699, -0.6396363672964268, -0.2868506185420297),
      vec3(-0.9999999800173294, 0.00019991333100810582, -1.99826701852146e-8),
    ],
    tangents: [
      vec3(0.0, 1.0, 0.0),
      vec3(0.6396363672964269, -0.4262987629159403, -0.6396363672964269),
      vec3(-0.0001999133310081273, -0.9999999600346594, 0.0001999133310081273),
    ],
  }
  let frames = curve.compute_frenet_frames(2, closed=false)
  assert_frames(frames, expected)
}

///|
test "CatmullRomCurve3 getUtoTmapping" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.5, distance=500.0)
  let expected_somewhere = 0.8964116382083199
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, expected_somewhere)
}

///|
test "CatmullRomCurve3 getSpacedPoints" {
  let curve = @extras.CatmullRomCurve3::new(points=catmull_positions())
  set_curve_type(curve, "catmullrom")
  let expected_points = [
    vec3(-60.0, -100.0, 60.0),
    vec3(-60.0, 10.311489426555056, 60.0),
    vec3(-65.05889864636504, 117.99691802595966, 65.05889864636504),
    vec3(6.054276900088592, 78.7153118386369, -6.054276900088592),
    vec3(64.9991491385602, 8.386980812799566, -64.9991491385602),
    vec3(60.0, -100.0, -60.0),
  ]
  let points = curve.get_spaced_points()
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}

///|
test "CatmullRomCurve3 two points" {
  let curve = @extras.CatmullRomCurve3::new(
    points=[vec3(0.0, 0.0, 0.0), vec3(10.0, 0.0, 0.0)],
    closed=false,
    curve_type="catmullrom",
  )
  let expected_points = [
    vec3(0.0, 0.0, 0.0),
    vec3(5.0, 0.0, 0.0),
    vec3(10.0, 0.0, 0.0),
  ]
  let points = curve.get_points(divisions=2)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}
