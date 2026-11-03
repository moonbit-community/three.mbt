// Upstream src/extras/curves/LineCurve3.js. See line_curve.mbt for the shared data.

///|
#external
pub type LineCurve3

///|
pub fn LineCurve3::new(
  v1? : @math.Vector3,
  v2? : @math.Vector3,
) -> Curve[@math.Vector3] {
  curve_make(
    "LineCurve3",
    Line({
      v1: v1.unwrap_or_else(CurveVector::zero),
      v2: v2.unwrap_or_else(CurveVector::zero),
    }),
  )
}
