// Port of upstream test/unit/src/extras/curves/LineCurve3.tests.js.

///|
fn line_curve3_points() -> Array[@math.Vector3] {
  [
    vec3(0.0, 0.0, 0.0),
    vec3(10.0, 10.0, 10.0),
    vec3(-10.0, 10.0, -10.0),
    vec3(-8.0, 5.0, -7.0),
  ]
}

///|
fn line_curve3_curve() -> @extras.Curve[@math.Vector3] {
  @extras.LineCurve3::new(
    v1=line_curve3_points()[0],
    v2=line_curve3_points()[1],
  )
}

///|
test "LineCurve3 extends Curve" {
  let object : @extras.Curve[@math.Vector3] = @extras.LineCurve3::new()
  ignore(object)
}

///|
test "LineCurve3 instancing" {
  ignore(@extras.LineCurve3::new())
}

///|
test "LineCurve3 type" {
  assert_eq(@extras.LineCurve3::new().type_, "LineCurve3")
}

///|
test "LineCurve3 isLineCurve3" {
  assert_true(@extras.LineCurve3::new().kind is Line(_))
}

///|
test "LineCurve3 getPointAt" {
  let curve = @extras.LineCurve3::new(
    v1=line_curve3_points()[0],
    v2=line_curve3_points()[3],
  )
  let expected_points = [
    vec3(0.0, 0.0, 0.0),
    vec3(-2.4, 1.5, -2.1),
    vec3(-4.0, 2.5, -3.5),
    vec3(-8.0, 5.0, -7.0),
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
test "LineCurve3 Simple curve" {
  let mut curve = line_curve3_curve()
  let mut expected_points = [
    vec3(0.0, 0.0, 0.0),
    vec3(2.0, 2.0, 2.0),
    vec3(4.0, 4.0, 4.0),
    vec3(6.0, 6.0, 6.0),
    vec3(8.0, 8.0, 8.0),
    vec3(10.0, 10.0, 10.0),
  ]
  let mut points = curve.get_points()
  assert_exact_points(points, expected_points)
  curve = @extras.LineCurve3::new(
    v1=line_curve3_points()[1],
    v2=line_curve3_points()[2],
  )
  expected_points = [
    vec3(10.0, 10.0, 10.0),
    vec3(6.0, 10.0, 6.0),
    vec3(2.0, 10.0, 2.0),
    vec3(-2.0, 10.0, -2.0),
    vec3(-6.0, 10.0, -6.0),
    vec3(-10.0, 10.0, -10.0),
  ]
  points = curve.get_points()
  assert_exact_points(points, expected_points)
}

///|
test "LineCurve3 getLength/getLengths" {
  let curve = line_curve3_curve()

  let length = curve.get_length()
  let expected_length = 300.0.sqrt()
  assert_num(length, expected_length)
  let lengths = curve.get_lengths(divisions=5)
  let expected_lengths : Array[Double] = [
    0.0,
    12.0.sqrt(),
    48.0.sqrt(),
    108.0.sqrt(),
    192.0.sqrt(),
    300.0.sqrt(),
  ]
  assert_eq(lengths.length(), expected_lengths.length())
  assert_num_list(lengths, expected_lengths)
}

///|
test "LineCurve3 getTangent/getTangentAt" {
  let curve = line_curve3_curve()
  let mut tangent = vec3(0.0, 0.0, 0.0)
  ignore(curve.get_tangent(0.5, optional_target=tangent))
  let expected_tangent = (1.0 / 3.0).sqrt()
  assert_num(tangent.x, expected_tangent)
  assert_num(tangent.y, expected_tangent)
  assert_num(tangent.z, expected_tangent)
  tangent = curve.get_tangent_at(0.5)
  assert_num(tangent.x, expected_tangent)
  assert_num(tangent.y, expected_tangent)
  assert_num(tangent.z, expected_tangent)
}

///|
test "LineCurve3 computeFrenetFrames" {
  let curve = line_curve3_curve()

  let expected = @extras.FrenetFrames::{
    binormals: [vec3(-0.5 * 2.0.sqrt(), 0.5 * 2.0.sqrt(), 0.0)],
    normals: [vec3((1.0 / 6.0).sqrt(), (1.0 / 6.0).sqrt(), -(2.0 / 3.0).sqrt())],
    tangents: [vec3((1.0 / 3.0).sqrt(), (1.0 / 3.0).sqrt(), (1.0 / 3.0).sqrt())],
  }
  let frames = curve.compute_frenet_frames(1, closed=false)
  assert_num_points([frames.tangents[0]], expected.tangents)
  assert_num_points([frames.normals[0]], expected.normals)
  assert_num_points([frames.binormals[0]], expected.binormals)
}

///|
test "LineCurve3 getUtoTmapping" {
  let curve = line_curve3_curve()

  let start = curve.get_uto_tmapping(0.0, distance=0.0)
  let end = curve.get_uto_tmapping(0.0, distance=curve.get_length())
  let somewhere = curve.get_uto_tmapping(0.7, distance=0.0)
  assert_eq(start, 0.0)
  assert_eq(end, 1.0)
  assert_num(somewhere, 0.7)
}

///|
test "LineCurve3 getSpacedPoints" {
  let curve = line_curve3_curve()

  let expected_points = [
    vec3(0.0, 0.0, 0.0),
    vec3(2.5, 2.5, 2.5),
    vec3(5.0, 5.0, 5.0),
    vec3(7.5, 7.5, 7.5),
    vec3(10.0, 10.0, 10.0),
  ]
  let points = curve.get_spaced_points(divisions=4)
  assert_eq(points.length(), expected_points.length())
  assert_exact_points(points, expected_points)
}
