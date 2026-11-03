// Upstream src/extras/core/Path.js.
//
// `Path` and `Shape` are nominal wrappers around a `Curve[@math.Vector2]`, whose `kind` is
// `Path(..)` or `Shape(..)`, because `Shape` must be a type of its own to implement
// `@core.SerializableResource`. `path.curve` is the upcast to `Curve`, and `Curve` methods
// dispatch on the kind, so a wrapped curve can sit in any `curves` array. Inherited methods
// without optional arguments live on `PathLike`; the rest are written out on both types.

///|
pub(all) struct PathData[V] {
  current_point : V
}

///|
fn[V : CurveVector] PathData::to_json(
  self : PathData[V],
  data : Map[String, Json],
) -> Unit {
  data["currentPoint"] = curve_json_vector_numbers(self.current_point)
}

///|
fn[V : CurveVector] PathData::from_json(
  self : PathData[V],
  json : Json,
) -> Unit {
  curve_json_vector(self.current_point, json, "currentPoint")
}

///|
/// Upstream `Path`. See the note at the top of this file.
pub(all) struct Path {
  curve : Curve[@math.Vector2]
}

///|
fn path_current_point(curve : Curve[@math.Vector2]) -> @math.Vector2 {
  match curve.kind {
    Path(_, path) | Shape(_, path, _) => path.current_point
    _ => abort("'\{curve.type_}' is not a Path")
  }
}

///|
/// The methods `Path` and `Shape` share, returning their own type.
pub trait PathLike {
  fn path_curve(Self) -> Curve[@math.Vector2]
  fn curves(Self) -> Array[Curve[@math.Vector2]] = _
  fn set_curves(Self, Array[Curve[@math.Vector2]]) -> Unit = _
  fn auto_close(Self) -> Bool = _
  fn set_auto_close(Self, Bool) -> Unit = _
  fn add(Self, Curve[@math.Vector2]) -> Unit = _
  fn close_path(Self) -> Self = _
  fn get_length(Self) -> Double = _
  fn get_curve_lengths(Self) -> Array[Double] = _
  fn update_arc_lengths(Self) -> Unit = _
  fn current_point(Self) -> @math.Vector2 = _
  fn set_from_points(Self, Array[@math.Vector2]) -> Self = _
  fn move_to(Self, Double, Double) -> Self = _
  fn line_to(Self, Double, Double) -> Self = _
  fn quadratic_curve_to(Self, Double, Double, Double, Double) -> Self = _
  fn bezier_curve_to(Self, Double, Double, Double, Double, Double, Double) -> Self = _
  fn spline_thru(Self, Array[@math.Vector2]) -> Self = _
}

///|
impl PathLike with fn curves(self) {
  self.path_curve().curves()
}

///|
impl PathLike with fn set_curves(self, curves) {
  self.path_curve().set_curves(curves)
}

///|
impl PathLike with fn auto_close(self) {
  self.path_curve().auto_close()
}

///|
impl PathLike with fn set_auto_close(self, auto_close) {
  self.path_curve().set_auto_close(auto_close)
}

///|
impl PathLike with fn add(self, curve) {
  self.path_curve().add(curve)
}

///|
impl PathLike with fn close_path(self) {
  ignore(self.path_curve().close_path())
  self
}

///|
impl PathLike with fn get_length(self) {
  self.path_curve().get_length()
}

///|
impl PathLike with fn get_curve_lengths(self) {
  self.path_curve().get_curve_lengths()
}

///|
impl PathLike with fn update_arc_lengths(self) {
  self.path_curve().update_arc_lengths()
}

///|
impl PathLike with fn current_point(self) {
  path_current_point(self.path_curve())
}

///|
impl PathLike with fn set_from_points(self, points) {
  ignore(self.move_to(points[0].x, points[0].y))
  for i in 1..<points.length() {
    ignore(self.line_to(points[i].x, points[i].y))
  }
  self
}

///|
impl PathLike with fn move_to(self, x, y) {
  ignore(self.current_point().set(x, y)) // TODO consider referencing vectors instead of copying?
  self
}

///|
impl PathLike with fn line_to(self, x, y) {
  let curve = LineCurve::new(
    v1=self.current_point().clone(),
    v2=@math.Vector2::new(x, y),
  )
  self.curves().push(curve)
  ignore(self.current_point().set(x, y))
  self
}

///|
impl PathLike with fn quadratic_curve_to(self, a_c_px, a_c_py, a_x, a_y) {
  let curve = QuadraticBezierCurve::new(
    v0=self.current_point().clone(),
    v1=@math.Vector2::new(a_c_px, a_c_py),
    v2=@math.Vector2::new(a_x, a_y),
  )
  self.curves().push(curve)
  ignore(self.current_point().set(a_x, a_y))
  self
}

///|
impl PathLike with fn bezier_curve_to(
  self,
  a_c_p1x,
  a_c_p1y,
  a_c_p2x,
  a_c_p2y,
  a_x,
  a_y,
) {
  let curve = CubicBezierCurve::new(
    v0=self.current_point().clone(),
    v1=@math.Vector2::new(a_c_p1x, a_c_p1y),
    v2=@math.Vector2::new(a_c_p2x, a_c_p2y),
    v3=@math.Vector2::new(a_x, a_y),
  )
  self.curves().push(curve)
  ignore(self.current_point().set(a_x, a_y))
  self
}

///|
impl PathLike with fn spline_thru(self, pts) {
  let npts = [self.current_point().clone()]
  npts.push_iter(pts.iter())
  let curve = SplineCurve::new(points=npts)
  self.curves().push(curve)
  ignore(self.current_point().copy(pts[pts.length() - 1]))
  self
}

///|
pub impl PathLike for Path with fn path_curve(self) {
  self.curve
}

///|
pub extend Path with PathLike::{
  path_curve,
  curves,
  set_curves,
  auto_close,
  set_auto_close,
  add,
  close_path,
  get_length,
  get_curve_lengths,
  update_arc_lengths,
  current_point,
  set_from_points,
  move_to,
  line_to,
  quadratic_curve_to,
  bezier_curve_to,
  spline_thru,
}

///|
pub fn Path::new(points? : Array[@math.Vector2]) -> Path {
  let path = Path::{
    curve: curve_make(
      "Path",
      Path(CurvePathData::new(), {
        current_point: @math.Vector2::new(0.0, 0.0),
      }),
    ),
  }
  if points is Some(points) {
    ignore(path.set_from_points(points))
  }
  path
}

///|
fn path_absellipse(
  path : Curve[@math.Vector2],
  a_x : Double,
  a_y : Double,
  x_radius : Double,
  y_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise : Bool,
  a_rotation : Double,
) -> Unit {
  let curve = EllipseCurve::new(
    a_x~,
    a_y~,
    x_radius~,
    y_radius~,
    a_start_angle~,
    a_end_angle~,
    a_clockwise~,
    a_rotation~,
  )
  let curves = path.curves()
  let current_point = path_current_point(path)
  if curves.length() > 0 {
    // if a previous curve is present, attempt to join
    let first_point = curve.get_point(0.0)
    if !first_point.equals(current_point) {
      ignore(Path::{ curve: path, }.line_to(first_point.x, first_point.y))
    }
  }
  curves.push(curve)
  let last_point = curve.get_point(1.0)
  ignore(current_point.copy(last_point))
}

///|
fn path_ellipse(
  path : Curve[@math.Vector2],
  a_x : Double,
  a_y : Double,
  x_radius : Double,
  y_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise : Bool,
  a_rotation : Double,
) -> Unit {
  let current_point = path_current_point(path)
  let x0 = current_point.x
  let y0 = current_point.y
  path_absellipse(
    path,
    a_x + x0,
    a_y + y0,
    x_radius,
    y_radius,
    a_start_angle,
    a_end_angle,
    a_clockwise,
    a_rotation,
  )
}

///|
pub fn Path::arc(
  self : Path,
  a_x : Double,
  a_y : Double,
  a_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
) -> Path {
  path_ellipse(
    self.curve,
    a_x,
    a_y,
    a_radius,
    a_radius,
    a_start_angle,
    a_end_angle,
    a_clockwise,
    0.0,
  )
  self
}

///|
pub fn Path::absarc(
  self : Path,
  a_x : Double,
  a_y : Double,
  a_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
) -> Path {
  path_absellipse(
    self.curve,
    a_x,
    a_y,
    a_radius,
    a_radius,
    a_start_angle,
    a_end_angle,
    a_clockwise,
    0.0,
  )
  self
}

///|
pub fn Path::ellipse(
  self : Path,
  a_x : Double,
  a_y : Double,
  x_radius : Double,
  y_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
  a_rotation~ : Double = 0.0,
) -> Path {
  path_ellipse(
    self.curve,
    a_x,
    a_y,
    x_radius,
    y_radius,
    a_start_angle,
    a_end_angle,
    a_clockwise,
    a_rotation,
  )
  self
}

///|
pub fn Path::absellipse(
  self : Path,
  a_x : Double,
  a_y : Double,
  x_radius : Double,
  y_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
  a_rotation~ : Double = 0.0,
) -> Path {
  path_absellipse(
    self.curve,
    a_x,
    a_y,
    x_radius,
    y_radius,
    a_start_angle,
    a_end_angle,
    a_clockwise,
    a_rotation,
  )
  self
}

///|
pub fn Path::get_point(
  self : Path,
  t : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_point(t, optional_target?)
}

///|
pub fn Path::get_point_or_null(
  self : Path,
  t : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2? {
  self.curve.get_point_or_null(t, optional_target?)
}

///|
pub fn Path::get_point_at(
  self : Path,
  u : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_point_at(u, optional_target?)
}

///|
pub fn Path::get_points(
  self : Path,
  divisions? : Int32,
) -> Array[@math.Vector2] {
  self.curve.get_points(divisions?)
}

///|
pub fn Path::get_spaced_points(
  self : Path,
  divisions? : Int32,
) -> Array[@math.Vector2] {
  self.curve.get_spaced_points(divisions?)
}

///|
pub fn Path::get_lengths(self : Path, divisions? : Int32) -> Array[Double] {
  self.curve.get_lengths(divisions?)
}

///|
pub fn Path::get_uto_tmapping(
  self : Path,
  u : Double,
  distance? : Double,
) -> Double {
  self.curve.get_uto_tmapping(u, distance?)
}

///|
pub fn Path::get_tangent(
  self : Path,
  t : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_tangent(t, optional_target?)
}

///|
pub fn Path::get_tangent_at(
  self : Path,
  u : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_tangent_at(u, optional_target?)
}

///|
pub fn Path::compute_frenet_frames(
  self : Path,
  segments : Int32,
  closed~ : Bool = false,
) -> FrenetFrames {
  self.curve.compute_frenet_frames(segments, closed~)
}

///|
pub fn Path::clone(self : Path) -> Path {
  Path::{ curve: self.curve.clone(), }
}

///|
pub fn Path::copy(self : Path, source : Path) -> Path {
  ignore(self.curve.copy(source.curve))
  self
}

///|
pub fn Path::to_json(self : Path) -> Json {
  self.curve.to_json()
}

///|
pub fn Path::from_json(self : Path, json : Json) -> Path {
  ignore(self.curve.from_json(json))
  self
}
