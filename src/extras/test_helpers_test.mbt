// Shared helpers for the extras tests.

///|
extern "js" fn test_pi() -> Double = "() => Math.PI"

///|
fn vec2(x : Double, y : Double) -> @math.Vector2 {
  @math.Vector2::new(x, y)
}

///|
fn vec3(x : Double, y : Double, z : Double) -> @math.Vector3 {
  @math.Vector3::new(x, y, z)
}

///|
/// Upstream `assert.numEqual` allows 0.1. These literals have full precision, so a much
/// smaller tolerance holds.
fn assert_num(actual : Double, expected : Double) -> Unit raise {
  if !((actual - expected).abs() < 1.0e-9) {
    fail("\{actual} != \{expected}")
  }
}

///|
fn assert_num_list(
  actual : Array[Double],
  expected : Array[Double],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i, value in actual {
    assert_num(value, expected[i])
  }
}

///|
fn assert_exact_list(
  actual : Array[Double],
  expected : Array[Double],
) -> Unit raise {
  assert_eq(actual, expected)
}

///|
fn[V : @extras.CurveVector] assert_num_points(
  actual : Array[V],
  expected : Array[V],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i, point in actual {
    assert_num_list(point.to_array(), expected[i].to_array())
  }
}

///|
/// Upstream `assert.deepEqual`: exact.
fn[V : @extras.CurveVector] assert_exact_points(
  actual : Array[V],
  expected : Array[V],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i, point in actual {
    assert_eq(point.to_array(), expected[i].to_array())
  }
}

///|
fn assert_frames(
  actual : @extras.FrenetFrames,
  expected : @extras.FrenetFrames,
) -> Unit raise {
  assert_num_points(actual.tangents, expected.tangents)
  assert_num_points(actual.normals, expected.normals)
  assert_num_points(actual.binormals, expected.binormals)
}

///|
fn[V] cubic_v(curve : @extras.Curve[V], index : Int32) -> V {
  guard curve.kind is CubicBezier(data) else { abort("not a cubic Bezier") }
  match index {
    0 => data.v0
    1 => data.v1
    2 => data.v2
    _ => data.v3
  }
}

///|
fn[V] quadratic_v(curve : @extras.Curve[V], index : Int32) -> V {
  guard curve.kind is QuadraticBezier(data) else { abort("not a quadratic") }
  match index {
    0 => data.v0
    1 => data.v1
    _ => data.v2
  }
}

///|
fn spline_points(curve : @extras.Curve[@math.Vector2]) -> Array[@math.Vector2] {
  guard curve.kind is Spline(data) else { abort("not a SplineCurve") }
  data.points
}

///|
fn set_curve_type(
  curve : @extras.Curve[@math.Vector3],
  curve_type : String,
) -> Unit {
  guard curve.kind is CatmullRom(data) else { abort("not a CatmullRomCurve3") }
  data.curve_type = curve_type
}

///|
fn set_closed(curve : @extras.Curve[@math.Vector3], closed : Bool) -> Unit {
  guard curve.kind is CatmullRom(data) else { abort("not a CatmullRomCurve3") }
  data.closed = closed
}
