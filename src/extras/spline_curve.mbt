// Upstream src/extras/curves/SplineCurve.js.

///|
#external
pub type SplineCurve

///|
pub(all) struct SplineCurveData[V] {
  mut points : Array[V]
}

///|
pub fn SplineCurve::new(
  points~ : Array[@math.Vector2] = [],
) -> Curve[@math.Vector2] {
  curve_make("SplineCurve", Spline({ points, }))
}

///|
fn[V] SplineCurveData::point_at(self : SplineCurveData[V], index : Double) -> V {
  match curve_array_at(self.points, index) {
    Some(point) => point
    None => abort("SplineCurve: no point at index \{index}")
  }
}

///|
fn[V : CurveVector] SplineCurveData::get_point(
  self : SplineCurveData[V],
  t : Double,
  point : V,
) -> V {
  let length = self.points.length().to_double()
  let p = (length - 1.0) * t
  let int_point = curve_math_floor(p)
  let weight = p - int_point
  let p0 = self.point_at(
    if int_point == 0.0 {
      int_point
    } else {
      int_point - 1.0
    },
  )
  let p1 = self.point_at(int_point)
  let p2 = self.point_at(
    if int_point > length - 2.0 {
      length - 1.0
    } else {
      int_point + 1.0
    },
  )
  let p3 = self.point_at(
    if int_point > length - 3.0 {
      length - 1.0
    } else {
      int_point + 2.0
    },
  )
  point.set_by_axis(axis => {
    catmull_rom(
      weight,
      p0.component(axis),
      p1.component(axis),
      p2.component(axis),
      p3.component(axis),
    )
  })
}

///|
fn[V : CurveVector] SplineCurveData::copy(
  self : SplineCurveData[V],
  source : SplineCurveData[V],
) -> Unit {
  self.points = source.points.map(curve_clone_vector)
}

///|
fn[V : CurveVector] SplineCurveData::to_json(
  self : SplineCurveData[V],
  data : Map[String, Json],
) -> Unit {
  data["points"] = curve_json_points(self.points)
}

///|
fn[V : CurveVector] SplineCurveData::from_json(
  self : SplineCurveData[V],
  json : Json,
) -> Unit {
  self.points = curve_json_array(json, "points").map(point => {
    curve_json_vector_from(V::zero(), point)
  })
}
