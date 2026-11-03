// Upstream src/extras/curves/CubicBezierCurve3.js. See cubic_bezier_curve.mbt for the shared
// data.

///|
#external
pub type CubicBezierCurve3

///|
pub fn CubicBezierCurve3::new(
  v0? : @math.Vector3,
  v1? : @math.Vector3,
  v2? : @math.Vector3,
  v3? : @math.Vector3,
) -> Curve[@math.Vector3] {
  curve_make(
    "CubicBezierCurve3",
    CubicBezier({
      v0: v0.unwrap_or_else(CurveVector::zero),
      v1: v1.unwrap_or_else(CurveVector::zero),
      v2: v2.unwrap_or_else(CurveVector::zero),
      v3: v3.unwrap_or_else(CurveVector::zero),
    }),
  )
}
