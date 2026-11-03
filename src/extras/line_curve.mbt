// Upstream src/extras/curves/LineCurve.js. The data and overrides are shared with
// `LineCurve3`.

///|
#external
pub type LineCurve

///|
pub(all) struct LineCurveData[V] {
  mut v1 : V
  mut v2 : V
}

///|
fn[V : CurveVector] LineCurveData::default_() -> LineCurveData[V] {
  { v1: V::zero(), v2: V::zero(), }
}

///|
pub fn LineCurve::new(
  v1? : @math.Vector2,
  v2? : @math.Vector2,
) -> Curve[@math.Vector2] {
  curve_make(
    "LineCurve",
    Line({
      v1: v1.unwrap_or_else(CurveVector::zero),
      v2: v2.unwrap_or_else(CurveVector::zero),
    }),
  )
}

///|
fn[V : CurveVector] LineCurveData::get_point(
  self : LineCurveData[V],
  t : Double,
  point : V,
) -> V {
  if t == 1.0 {
    ignore(point.copy(self.v2))
  } else {
    ignore(point.copy(self.v2).sub(self.v1))
    ignore(point.multiply_scalar(t).add(self.v1))
  }
  point
}

///|
fn[V : CurveVector] LineCurveData::copy(
  self : LineCurveData[V],
  source : LineCurveData[V],
) -> Unit {
  curve_copy_vector(self.v1, source.v1)
  curve_copy_vector(self.v2, source.v2)
}

///|
fn[V : CurveVector] LineCurveData::to_json(
  self : LineCurveData[V],
  data : Map[String, Json],
) -> Unit {
  data["v1"] = curve_json_vector_numbers(self.v1)
  data["v2"] = curve_json_vector_numbers(self.v2)
}

///|
fn[V : CurveVector] LineCurveData::from_json(
  self : LineCurveData[V],
  json : Json,
) -> Unit {
  curve_json_vector(self.v1, json, "v1")
  curve_json_vector(self.v2, json, "v2")
}
