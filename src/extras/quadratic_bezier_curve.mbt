// Upstream src/extras/curves/QuadraticBezierCurve.js. The data and overrides are shared with
// `QuadraticBezierCurve3`.

///|
#external
pub type QuadraticBezierCurve

///|
pub(all) struct QuadraticBezierCurveData[V] {
  mut v0 : V
  mut v1 : V
  mut v2 : V
}

///|
fn[V : CurveVector] QuadraticBezierCurveData::default_() -> QuadraticBezierCurveData[
  V,
] {
  { v0: V::zero(), v1: V::zero(), v2: V::zero(), }
}

///|
pub fn QuadraticBezierCurve::new(
  v0? : @math.Vector2,
  v1? : @math.Vector2,
  v2? : @math.Vector2,
) -> Curve[@math.Vector2] {
  curve_make(
    "QuadraticBezierCurve",
    QuadraticBezier({
      v0: v0.unwrap_or_else(CurveVector::zero),
      v1: v1.unwrap_or_else(CurveVector::zero),
      v2: v2.unwrap_or_else(CurveVector::zero),
    }),
  )
}

///|
fn[V : CurveVector] QuadraticBezierCurveData::get_point(
  self : QuadraticBezierCurveData[V],
  t : Double,
  point : V,
) -> V {
  let { v0, v1, v2, } = self
  point.set_by_axis(axis => {
    quadratic_bezier(
      t,
      v0.component(axis),
      v1.component(axis),
      v2.component(axis),
    )
  })
}

///|
fn[V : CurveVector] QuadraticBezierCurveData::copy(
  self : QuadraticBezierCurveData[V],
  source : QuadraticBezierCurveData[V],
) -> Unit {
  curve_copy_vector(self.v0, source.v0)
  curve_copy_vector(self.v1, source.v1)
  curve_copy_vector(self.v2, source.v2)
}

///|
fn[V : CurveVector] QuadraticBezierCurveData::to_json(
  self : QuadraticBezierCurveData[V],
  data : Map[String, Json],
) -> Unit {
  data["v0"] = curve_json_vector_numbers(self.v0)
  data["v1"] = curve_json_vector_numbers(self.v1)
  data["v2"] = curve_json_vector_numbers(self.v2)
}

///|
fn[V : CurveVector] QuadraticBezierCurveData::from_json(
  self : QuadraticBezierCurveData[V],
  json : Json,
) -> Unit {
  curve_json_vector(self.v0, json, "v0")
  curve_json_vector(self.v1, json, "v1")
  curve_json_vector(self.v2, json, "v2")
}
