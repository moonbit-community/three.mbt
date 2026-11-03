// Upstream src/extras/curves/QuadraticBezierCurve3.js. See quadratic_bezier_curve.mbt for
// the shared data.

///|
#external
pub type QuadraticBezierCurve3

///|
pub fn QuadraticBezierCurve3::new(
  v0? : @math.Vector3,
  v1? : @math.Vector3,
  v2? : @math.Vector3,
) -> Curve[@math.Vector3] {
  curve_make(
    "QuadraticBezierCurve3",
    QuadraticBezier({
      v0: v0.unwrap_or_else(CurveVector::zero),
      v1: v1.unwrap_or_else(CurveVector::zero),
      v2: v2.unwrap_or_else(CurveVector::zero),
    }),
  )
}
