// Upstream src/extras/curves/CubicBezierCurve.js. The data and overrides are shared with
// `CubicBezierCurve3`.

///|
#external
pub type CubicBezierCurve

///|
pub(all) struct CubicBezierCurveData[V] {
  mut v0 : V
  mut v1 : V
  mut v2 : V
  mut v3 : V
}

///|
fn[V : CurveVector] CubicBezierCurveData::default_() -> CubicBezierCurveData[V] {
  { v0: V::zero(), v1: V::zero(), v2: V::zero(), v3: V::zero(), }
}

///|
pub fn CubicBezierCurve::new(
  v0? : @math.Vector2,
  v1? : @math.Vector2,
  v2? : @math.Vector2,
  v3? : @math.Vector2,
) -> Curve[@math.Vector2] {
  curve_make(
    "CubicBezierCurve",
    CubicBezier({
      v0: v0.unwrap_or_else(CurveVector::zero),
      v1: v1.unwrap_or_else(CurveVector::zero),
      v2: v2.unwrap_or_else(CurveVector::zero),
      v3: v3.unwrap_or_else(CurveVector::zero),
    }),
  )
}

///|
fn[V : CurveVector] CubicBezierCurveData::get_point(
  self : CubicBezierCurveData[V],
  t : Double,
  point : V,
) -> V {
  let { v0, v1, v2, v3, } = self
  point.set_by_axis(axis => {
    cubic_bezier(
      t,
      v0.component(axis),
      v1.component(axis),
      v2.component(axis),
      v3.component(axis),
    )
  })
}

///|
fn[V : CurveVector] CubicBezierCurveData::copy(
  self : CubicBezierCurveData[V],
  source : CubicBezierCurveData[V],
) -> Unit {
  curve_copy_vector(self.v0, source.v0)
  curve_copy_vector(self.v1, source.v1)
  curve_copy_vector(self.v2, source.v2)
  curve_copy_vector(self.v3, source.v3)
}

///|
fn[V : CurveVector] CubicBezierCurveData::to_json(
  self : CubicBezierCurveData[V],
  data : Map[String, Json],
) -> Unit {
  data["v0"] = curve_json_vector_numbers(self.v0)
  data["v1"] = curve_json_vector_numbers(self.v1)
  data["v2"] = curve_json_vector_numbers(self.v2)
  data["v3"] = curve_json_vector_numbers(self.v3)
}

///|
fn[V : CurveVector] CubicBezierCurveData::from_json(
  self : CubicBezierCurveData[V],
  json : Json,
) -> Unit {
  curve_json_vector(self.v0, json, "v0")
  curve_json_vector(self.v1, json, "v1")
  curve_json_vector(self.v2, json, "v2")
  curve_json_vector(self.v3, json, "v3")
}
