// Upstream src/extras/core/CurvePath.js. The overrides of `Curve` methods are arms of the
// matches in curve.mbt and call the functions here.

///|
#external
pub type CurvePath

///|
pub(all) struct CurvePathData[V] {
  mut curves : Array[Curve[V]]
  mut auto_close : Bool
  mut cache_lengths : Array[Double]?
}

///|
fn[V] CurvePathData::new() -> CurvePathData[V] {
  { curves: [], auto_close: false, cache_lengths: None, }
}

///|
/// A `CurvePath`. The vector type comes from the context: `CurvePath::new() : Curve[V]`.
pub fn[V] CurvePath::new() -> Curve[V] {
  curve_make("CurvePath", CurvePath(CurvePathData::new()))
}

///|
fn[V] Curve::curve_path_data(self : Curve[V]) -> CurvePathData[V] {
  match self.kind {
    CurvePath(path) | Path(path, _) | Shape(path, _, _) => path
    _ => abort("'\{self.type_}' is not a CurvePath")
  }
}

///|
/// Upstream `curves`.
pub fn[V] Curve::curves(self : Curve[V]) -> Array[Curve[V]] {
  self.curve_path_data().curves
}

///|
pub fn[V] Curve::set_curves(self : Curve[V], curves : Array[Curve[V]]) -> Unit {
  self.curve_path_data().curves = curves
}

///|
/// Upstream `autoClose`.
pub fn[V] Curve::auto_close(self : Curve[V]) -> Bool {
  self.curve_path_data().auto_close
}

///|
pub fn[V] Curve::set_auto_close(self : Curve[V], auto_close : Bool) -> Unit {
  self.curve_path_data().auto_close = auto_close
}

///|
pub fn[V] Curve::add(self : Curve[V], curve : Curve[V]) -> Unit {
  self.curve_path_data().curves.push(curve)
}

///|
pub fn[V : CurveVector] Curve::close_path(self : Curve[V]) -> Curve[V] {
  let path = self.curve_path_data()
  // Add a line curve if start and end of lines are not connected
  let start_point = path.curves[0].get_point(0.0)
  let end_point = path.curves[path.curves.length() - 1].get_point(1.0)
  if !start_point.equals(end_point) {
    path.curves.push(V::line_curve(end_point, start_point))
  }
  self
}

///|
fn[V : CurveVector] curve_path_get_point(
  curve_path : Curve[V],
  path : CurvePathData[V],
  t : Double,
  optional_target : V?,
) -> V? {
  // To get accurate point with reference to
  // entire path distance at time t,
  // following has to be done:

  // 1. Length of each sub path have to be known
  // 2. Locate and identify type of curve
  // 3. Get t for the curve
  // 4. Return curve.getPointAt(t')
  let d = t * curve_path.get_length()
  let curve_lengths = curve_path_get_curve_lengths(path)
  let mut i = 0
  // To think about boundaries points.
  while i < curve_lengths.length() {
    if curve_lengths[i] >= d {
      let diff = curve_lengths[i] - d
      let curve = path.curves[i]
      let segment_length = curve.get_length()
      let u = if segment_length == 0.0 {
        0.0
      } else {
        1.0 - diff / segment_length
      }
      return curve.get_point_at_or_null(u, optional_target?)
    }
    i += 1
  }
  None
  // loop where sum != 0, sum > d , sum+1 <d
}

///|
fn[V : CurveVector] curve_path_get_curve_lengths(
  path : CurvePathData[V],
) -> Array[Double] {
  // Compute lengths and cache them
  // We cannot overwrite getLengths() because UtoT mapping uses it.
  // We use cache values if curves and cache array are same length
  if path.cache_lengths is Some(lengths) &&
    lengths.length() == path.curves.length() {
    return lengths
  }
  // Get length of sub-curve
  // Push sums into cached array
  let lengths = []
  let mut sums = 0.0
  for curve in path.curves {
    sums += curve.get_length()
    lengths.push(sums)
  }
  path.cache_lengths = Some(lengths)
  lengths
}

///|
/// Upstream `getCurveLengths`.
pub fn[V : CurveVector] Curve::get_curve_lengths(
  self : Curve[V],
) -> Array[Double] {
  curve_path_get_curve_lengths(self.curve_path_data())
}

///|
fn[V : CurveVector] curve_path_get_spaced_points(
  curve_path : Curve[V],
  path : CurvePathData[V],
  divisions : Int32,
) -> Array[V] {
  let points = []
  for i = 0; i <= divisions; i = i + 1 {
    points.push(curve_path.get_point(i.to_double() / divisions.to_double()))
  }
  if path.auto_close {
    points.push(points[0])
  }
  points
}

///|
fn[V : CurveVector] curve_path_get_points(
  path : CurvePathData[V],
  divisions : Int32,
) -> Array[V] {
  let points = []
  let mut last : V? = None
  for curve in path.curves {
    let resolution = match curve.kind {
      Ellipse(_) => divisions * 2
      Line(_) => 1
      Spline(spline) => divisions * spline.points.length()
      _ => divisions
    }
    let pts = curve.get_points(divisions=resolution)
    for point in pts {
      if last is Some(last) && last.equals(point) {
        continue // ensures no consecutive points are duplicates
      }
      points.push(point)
      last = Some(point)
    }
  }
  if path.auto_close &&
    points.length() > 1 &&
    !points[points.length() - 1].equals(points[0]) {
    points.push(points[0])
  }
  points
}

///|
fn[V : CurveVector] CurvePathData::copy(
  self : CurvePathData[V],
  source : CurvePathData[V],
) -> Unit {
  self.curves = source.curves.map(curve => curve.clone())
  self.auto_close = source.auto_close
  self.cache_lengths = None
}

///|
fn[V : CurveVector] CurvePathData::to_json(
  self : CurvePathData[V],
  data : Map[String, Json],
) -> Unit {
  data["autoClose"] = Json::boolean(self.auto_close)
  data["curves"] = Json::array(self.curves.map(curve => curve.to_json()))
}

///|
fn[V : CurveVector] CurvePathData::from_json(
  self : CurvePathData[V],
  json : Json,
) -> Unit {
  self.auto_close = curve_json_bool(json, "autoClose")
  self.curves = curve_json_array(json, "curves").map(curve => {
    V::curve_from_type(curve_json_string(curve, "type")).from_json(curve)
  })
  self.cache_lengths = None
}
