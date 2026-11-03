// Upstream src/extras/core/Interpolations.js.

///|
/// Computes a point on a Catmull-Rom spline.
pub fn catmull_rom(
  t : Double,
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Double {
  let v0 = (p2 - p0) * 0.5
  let v1 = (p3 - p1) * 0.5
  let t2 = t * t
  let t3 = t * t2
  (2.0 * p1 - 2.0 * p2 + v0 + v1) * t3 +
  (-3.0 * p1 + 3.0 * p2 - 2.0 * v0 - v1) * t2 +
  v0 * t +
  p1
}

///|
fn quadratic_bezier_p0(t : Double, p : Double) -> Double {
  let k = 1.0 - t
  k * k * p
}

///|
fn quadratic_bezier_p1(t : Double, p : Double) -> Double {
  2.0 * (1.0 - t) * t * p
}

///|
fn quadratic_bezier_p2(t : Double, p : Double) -> Double {
  t * t * p
}

///|
/// Computes a point on a Quadratic Bezier curve.
pub fn quadratic_bezier(
  t : Double,
  p0 : Double,
  p1 : Double,
  p2 : Double,
) -> Double {
  quadratic_bezier_p0(t, p0) +
  quadratic_bezier_p1(t, p1) +
  quadratic_bezier_p2(t, p2)
}

///|
fn cubic_bezier_p0(t : Double, p : Double) -> Double {
  let k = 1.0 - t
  k * k * k * p
}

///|
fn cubic_bezier_p1(t : Double, p : Double) -> Double {
  let k = 1.0 - t
  3.0 * k * k * t * p
}

///|
fn cubic_bezier_p2(t : Double, p : Double) -> Double {
  3.0 * (1.0 - t) * t * t * p
}

///|
fn cubic_bezier_p3(t : Double, p : Double) -> Double {
  t * t * t * p
}

///|
/// Computes a point on a Cubic Bezier curve.
pub fn cubic_bezier(
  t : Double,
  p0 : Double,
  p1 : Double,
  p2 : Double,
  p3 : Double,
) -> Double {
  cubic_bezier_p0(t, p0) +
  cubic_bezier_p1(t, p1) +
  cubic_bezier_p2(t, p2) +
  cubic_bezier_p3(t, p3)
}
