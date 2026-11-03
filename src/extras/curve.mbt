// Upstream src/extras/core/Curve.js.
//
// `Curve[V]` is one struct generic over the point type, `@math.Vector2` or
// `@math.Vector3`, plus `kind`, an enum with the subclass data, as `Object3D` does.
// Subclass constructors live on marker types and return `Curve[V]`:
// `LineCurve3::new(..) : Curve[@math.Vector3]`. Overridden methods match on `kind`.
// `Path` and `Shape` are separate nominal wrappers around a `Curve[@math.Vector2]`; see
// path.mbt.

///|
/// The vector operations curves need, implemented by `@math.Vector2` and `@math.Vector3`.
pub trait CurveVector {
  /// `new Vector2()` or `new Vector3()`.
  fn zero() -> Self
  fn clone(Self) -> Self
  fn copy(Self, Self) -> Self
  fn add(Self, Self) -> Self
  fn sub(Self, Self) -> Self
  fn sub_vectors(Self, Self, Self) -> Self
  fn multiply_scalar(Self, Double) -> Self
  fn normalize(Self) -> Self
  fn distance_to(Self, Self) -> Double
  fn equals(Self, Self) -> Bool
  fn component(Self, Int32) -> Double
  /// `point.set( x, y )`: a `Vector3` keeps its `z`.
  fn set_xy(Self, Double, Double) -> Self
  /// Sets every component from its axis index.
  fn set_by_axis(Self, (Int32) -> Double) -> Self
  fn to_array(Self) -> Array[Double]
  fn from_array(Self, Array[Double]) -> Self
  /// `LineCurve` or `LineCurve3`, for `CurvePath::close_path`.
  fn line_curve(Self, Self) -> Curve[Self]
  /// `new Curves[ type ]()`, for `CurvePath::from_json`.
  fn curve_from_type(String) -> Curve[Self]
  /// `curve.getTangentAt( u, new Vector3() )`, as `compute_frenet_frames` calls it.
  fn frenet_tangent_at(Curve[Self], Double) -> @math.Vector3
}

///|
pub impl CurveVector for @math.Vector2 with fn zero() {
  @math.Vector2::new(0.0, 0.0)
}

///|
pub impl CurveVector for @math.Vector2 with fn clone(self) {
  @math.Vector2::clone(self)
}

///|
pub impl CurveVector for @math.Vector2 with fn copy(self, other) {
  @math.Vector2::copy(self, other)
}

///|
pub impl CurveVector for @math.Vector2 with fn add(self, other) {
  @math.Vector2::add(self, other)
}

///|
pub impl CurveVector for @math.Vector2 with fn sub(self, other) {
  @math.Vector2::sub(self, other)
}

///|
pub impl CurveVector for @math.Vector2 with fn sub_vectors(self, a, b) {
  @math.Vector2::sub_vectors(self, a, b)
}

///|
pub impl CurveVector for @math.Vector2 with fn multiply_scalar(self, scalar) {
  @math.Vector2::multiply_scalar(self, scalar)
}

///|
pub impl CurveVector for @math.Vector2 with fn normalize(self) {
  @math.Vector2::normalize(self)
}

///|
pub impl CurveVector for @math.Vector2 with fn distance_to(self, other) {
  @math.Vector2::distance_to(self, other)
}

///|
pub impl CurveVector for @math.Vector2 with fn equals(self, other) {
  @math.Vector2::equals(self, other)
}

///|
pub impl CurveVector for @math.Vector2 with fn component(self, index) {
  @math.Vector2::get_component(self, index)
}

///|
pub impl CurveVector for @math.Vector2 with fn set_xy(self, x, y) {
  @math.Vector2::set(self, x, y)
}

///|
pub impl CurveVector for @math.Vector2 with fn set_by_axis(self, value) {
  @math.Vector2::set(self, value(0), value(1))
}

///|
pub impl CurveVector for @math.Vector2 with fn to_array(self) {
  @math.Vector2::to_array(self)
}

///|
pub impl CurveVector for @math.Vector2 with fn from_array(self, array) {
  @math.Vector2::from_array(self, array)
}

///|
pub impl CurveVector for @math.Vector2 with fn line_curve(a, b) {
  LineCurve::new(v1=a, v2=b)
}

///|
pub impl CurveVector for @math.Vector2 with fn curve_from_type(type_) {
  match type_ {
    "ArcCurve" => ArcCurve::new()
    "CubicBezierCurve" => CubicBezierCurve::new()
    "EllipseCurve" => EllipseCurve::new()
    "LineCurve" => LineCurve::new()
    "QuadraticBezierCurve" => QuadraticBezierCurve::new()
    "SplineCurve" => SplineCurve::new()
    _ => abort("CurvePath: no 2D curve type '\{type_}'")
  }
}

///|
/// Upstream writes through a `Vector3` target here. `z` becomes `undefined - undefined`,
/// so the length is `NaN` and `normalize()` divides by 1.
pub impl CurveVector for @math.Vector2 with fn frenet_tangent_at(curve, u) {
  match curve.kind {
    Line(line) =>
      @math.Vector3::new(
        line.v2.x - line.v1.x,
        line.v2.y - line.v1.y,
        curve_nan,
      )
    _ => {
      let (t1, t2) = curve_tangent_range(curve.get_uto_tmapping(u))
      let pt1 = curve.get_point(t1)
      let pt2 = curve.get_point(t2)
      @math.Vector3::new(pt2.x - pt1.x, pt2.y - pt1.y, curve_nan)
    }
  }
}

///|
pub impl CurveVector for @math.Vector3 with fn zero() {
  @math.Vector3::new(0.0, 0.0, 0.0)
}

///|
pub impl CurveVector for @math.Vector3 with fn clone(self) {
  @math.Vector3::clone(self)
}

///|
pub impl CurveVector for @math.Vector3 with fn copy(self, other) {
  @math.Vector3::copy(self, other)
}

///|
pub impl CurveVector for @math.Vector3 with fn add(self, other) {
  @math.Vector3::add(self, other)
}

///|
pub impl CurveVector for @math.Vector3 with fn sub(self, other) {
  @math.Vector3::sub(self, other)
}

///|
pub impl CurveVector for @math.Vector3 with fn sub_vectors(self, a, b) {
  @math.Vector3::sub_vectors(self, a, b)
}

///|
pub impl CurveVector for @math.Vector3 with fn multiply_scalar(self, scalar) {
  @math.Vector3::multiply_scalar(self, scalar)
}

///|
pub impl CurveVector for @math.Vector3 with fn normalize(self) {
  @math.Vector3::normalize(self)
}

///|
pub impl CurveVector for @math.Vector3 with fn distance_to(self, other) {
  @math.Vector3::distance_to(self, other)
}

///|
pub impl CurveVector for @math.Vector3 with fn equals(self, other) {
  @math.Vector3::equals(self, other)
}

///|
pub impl CurveVector for @math.Vector3 with fn component(self, index) {
  @math.Vector3::get_component(self, index)
}

///|
pub impl CurveVector for @math.Vector3 with fn set_xy(self, x, y) {
  @math.Vector3::set_xy(self, x, y)
}

///|
pub impl CurveVector for @math.Vector3 with fn set_by_axis(self, value) {
  @math.Vector3::set(self, value(0), value(1), value(2))
}

///|
pub impl CurveVector for @math.Vector3 with fn to_array(self) {
  @math.Vector3::to_array(self)
}

///|
pub impl CurveVector for @math.Vector3 with fn from_array(self, array) {
  @math.Vector3::from_array(self, array)
}

///|
pub impl CurveVector for @math.Vector3 with fn line_curve(a, b) {
  LineCurve3::new(v1=a, v2=b)
}

///|
pub impl CurveVector for @math.Vector3 with fn curve_from_type(type_) {
  match type_ {
    "CatmullRomCurve3" => CatmullRomCurve3::new()
    "CubicBezierCurve3" => CubicBezierCurve3::new()
    "LineCurve3" => LineCurve3::new()
    "QuadraticBezierCurve3" => QuadraticBezierCurve3::new()
    _ => abort("CurvePath: no 3D curve type '\{type_}'")
  }
}

///|
pub impl CurveVector for @math.Vector3 with fn frenet_tangent_at(curve, u) {
  curve.get_tangent_at(u, optional_target=@math.Vector3::new(0.0, 0.0, 0.0))
}

///|
/// Subclass data. `Line`, `QuadraticBezier` and `CubicBezier` serve both the 2D and the 3D
/// class, told apart by `type_`.
pub(all) enum CurveKind[V] {
  /// Upstream's abstract `Curve` itself.
  Abstract
  /// A subclass outside this package; see `Curve::extended`.
  Custom(CurveExtension[V])
  Line(LineCurveData[V])
  QuadraticBezier(QuadraticBezierCurveData[V])
  CubicBezier(CubicBezierCurveData[V])
  /// `EllipseCurve` and `ArcCurve`.
  Ellipse(EllipseCurveData)
  Spline(SplineCurveData[V])
  CatmullRom(CatmullRomCurve3Data)
  CurvePath(CurvePathData[V])
  Path(CurvePathData[V], PathData[V])
  Shape(CurvePathData[V], PathData[V], ShapeData)
}

///|
/// The overrides of a subclass defined outside this package.
pub(all) struct CurveExtension[V] {
  get_point : (Curve[V], Double, V) -> V
  get_tangent : ((Curve[V], Double, V) -> V)?
  construct : (() -> Curve[V])?
  copy : ((Curve[V], Curve[V]) -> Unit)?
  to_json : ((Curve[V], Map[String, Json]) -> Unit)?
  from_json : ((Curve[V], Json) -> Unit)?
}

///|
/// Upstream `Curve`, generic over `@math.Vector2` or `@math.Vector3`.
pub(all) struct Curve[V] {
  mut type_ : String
  mut arc_length_divisions : Int32
  mut needs_update : Bool
  mut cache_arc_lengths : Array[Double]?
  kind : CurveKind[V]
}

///|
/// The result of `Curve::compute_frenet_frames`.
pub(all) struct FrenetFrames {
  tangents : Array[@math.Vector3]
  normals : Array[@math.Vector3]
  binormals : Array[@math.Vector3]
}

///|
let curve_nan : Double = 0.0 / 0.0

///|
/// `Number.EPSILON`.
let curve_epsilon : Double = 2.220446049250313e-16

///|
/// `Math.PI * 2`.
let curve_two_pi : Double = 3.141592653589793 * 2.0

///|
extern "js" fn curve_math_floor(x : Double) -> Double = "Math.floor"

///|
/// `array[ index ]` for a numeric index, `None` where JS gives `undefined`.
fn[T] curve_array_at(array : Array[T], index : Double) -> T? {
  if index >= 0.0 &&
    index < array.length().to_double() &&
    index == curve_math_floor(index) {
    Some(array[index.to_int()])
  } else {
    None
  }
}

///|
fn[T] curve_make(type_ : String, kind : CurveKind[T]) -> Curve[T] {
  {
    type_,
    arc_length_divisions: 200,
    needs_update: false,
    cache_arc_lengths: None,
    kind,
  }
}

///|
fn[V : CurveVector] curve_target(optional_target : V?) -> V {
  match optional_target {
    Some(target) => target
    None => V::zero()
  }
}

///|
/// Upstream's abstract base class. `get_point` warns.
pub fn[V] Curve::new() -> Curve[V] {
  curve_make("Curve", Abstract)
}

///|
/// A subclass of `Curve` defined outside this package, as upstream `class X extends Curve`.
/// `construct` is `new this.constructor()`; state captured by the other closures is shared
/// with a clone unless it is given.
pub fn[V] Curve::extended(
  type_ : String,
  get_point : (Curve[V], Double, V) -> V,
  get_tangent? : (Curve[V], Double, V) -> V,
  construct? : () -> Curve[V],
  copy? : (Curve[V], Curve[V]) -> Unit,
  to_json? : (Curve[V], Map[String, Json]) -> Unit,
  from_json? : (Curve[V], Json) -> Unit,
) -> Curve[V] {
  curve_make(
    type_,
    Custom({ get_point, get_tangent, construct, copy, to_json, from_json, }),
  )
}

///|
/// Upstream `getPoint`, which is `null` for a `CurvePath` when `t` is past every curve, and
/// `undefined` for the abstract base.
pub fn[V : CurveVector] Curve::get_point_or_null(
  self : Curve[V],
  t : Double,
  optional_target? : V,
) -> V? {
  match self.kind {
    Abstract => {
      @core.warn("Curve: .getPoint() not implemented.")
      None
    }
    Custom(extension) =>
      Some((extension.get_point)(self, t, curve_target(optional_target)))
    Line(line) => Some(line.get_point(t, curve_target(optional_target)))
    QuadraticBezier(curve) =>
      Some(curve.get_point(t, curve_target(optional_target)))
    CubicBezier(curve) =>
      Some(curve.get_point(t, curve_target(optional_target)))
    Ellipse(curve) => Some(curve.get_point(t, curve_target(optional_target)))
    Spline(curve) => Some(curve.get_point(t, curve_target(optional_target)))
    CatmullRom(curve) => Some(curve.get_point(t, curve_target(optional_target)))
    CurvePath(path) | Path(path, _) | Shape(path, _, _) =>
      curve_path_get_point(self, path, t, optional_target)
  }
}

///|
/// Upstream `getPoint`. Aborts where upstream returns `null`; see `get_point_or_null`.
pub fn[V : CurveVector] Curve::get_point(
  self : Curve[V],
  t : Double,
  optional_target? : V,
) -> V {
  match self.get_point_or_null(t, optional_target?) {
    Some(point) => point
    None => abort("Curve::get_point: no point at \{t}")
  }
}

///|
/// Upstream `getPointAt`, `null` under the same conditions as `get_point_or_null`.
pub fn[V : CurveVector] Curve::get_point_at_or_null(
  self : Curve[V],
  u : Double,
  optional_target? : V,
) -> V? {
  match self.kind {
    // Line curve is linear, so we can overwrite default getPointAt
    Line(_) => self.get_point_or_null(u, optional_target?)
    _ => {
      let t = self.get_uto_tmapping(u)
      self.get_point_or_null(t, optional_target?)
    }
  }
}

///|
pub fn[V : CurveVector] Curve::get_point_at(
  self : Curve[V],
  u : Double,
  optional_target? : V,
) -> V {
  match self.get_point_at_or_null(u, optional_target?) {
    Some(point) => point
    None => abort("Curve::get_point_at: no point at \{u}")
  }
}

///|
pub fn[V : CurveVector] Curve::get_points(
  self : Curve[V],
  divisions? : Int32,
) -> Array[V] {
  match self.kind {
    CurvePath(path) | Path(path, _) | Shape(path, _, _) =>
      curve_path_get_points(path, divisions.unwrap_or(12))
    _ => {
      let divisions = divisions.unwrap_or(5)
      let points = []
      for d = 0; d <= divisions; d = d + 1 {
        points.push(self.get_point(d.to_double() / divisions.to_double()))
      }
      points
    }
  }
}

///|
pub fn[V : CurveVector] Curve::get_spaced_points(
  self : Curve[V],
  divisions? : Int32,
) -> Array[V] {
  match self.kind {
    CurvePath(path) | Path(path, _) | Shape(path, _, _) =>
      curve_path_get_spaced_points(self, path, divisions.unwrap_or(40))
    _ => {
      let divisions = divisions.unwrap_or(5)
      let points = []
      for d = 0; d <= divisions; d = d + 1 {
        points.push(self.get_point_at(d.to_double() / divisions.to_double()))
      }
      points
    }
  }
}

///|
pub fn[V : CurveVector] Curve::get_length(self : Curve[V]) -> Double {
  match self.kind {
    // We cannot use the default THREE.Curve getPoint() with getLength() because in
    // THREE.Curve, getLength() depends on getPoint() but in THREE.CurvePath
    // getPoint() depends on getLength
    CurvePath(path) | Path(path, _) | Shape(path, _, _) => {
      let lens = curve_path_get_curve_lengths(path)
      lens.unsafe_get(lens.length() - 1)
    }
    _ => {
      let lengths = self.get_lengths()
      lengths[lengths.length() - 1]
    }
  }
}

///|
pub fn[V : CurveVector] Curve::get_lengths(
  self : Curve[V],
  divisions? : Int32,
) -> Array[Double] {
  let divisions = divisions.unwrap_or(self.arc_length_divisions)
  if self.cache_arc_lengths is Some(cache) &&
    cache.length() == divisions + 1 &&
    !self.needs_update {
    return cache
  }
  self.needs_update = false
  let cache = []
  let mut last = self.get_point_or_null(0.0)
  let mut sum = 0.0
  cache.push(0.0)
  for p = 1; p <= divisions; p = p + 1 {
    let current = self.get_point(p.to_double() / divisions.to_double())
    guard last is Some(previous) else {
      abort("Curve::get_lengths: no point at 0")
    }
    sum += current.distance_to(previous)
    cache.push(sum)
    last = Some(current)
  }
  self.cache_arc_lengths = Some(cache)
  cache // { sums: cache, sum: sum }; Sum is in the last element.
}

///|
pub fn[V : CurveVector] Curve::update_arc_lengths(self : Curve[V]) -> Unit {
  self.needs_update = true
  match self.kind {
    // cacheLengths must be recalculated.
    CurvePath(path) | Path(path, _) | Shape(path, _, _) => {
      path.cache_lengths = None
      ignore(curve_path_get_curve_lengths(path))
    }
    _ => ignore(self.get_lengths())
  }
}

///|
/// Upstream `getUtoTmapping`. Indices may leave the array, where upstream reads `undefined`.
pub fn[V : CurveVector] Curve::get_uto_tmapping(
  self : Curve[V],
  u : Double,
  distance? : Double,
) -> Double {
  let arc_lengths = self.get_lengths()
  let il = arc_lengths.length()
  // The targeted u distance value to get
  let target_arc_length = match distance {
    Some(distance) if distance != 0.0 && distance == distance => distance
    _ => u * arc_lengths[il - 1]
  }
  // binary search for the index with largest value smaller than target u distance
  let mut low = 0
  let mut high = il - 1
  while low <= high {
    let i = low + (high - low) / 2
    let comparison = arc_lengths[i] - target_arc_length
    if comparison < 0.0 {
      low = i + 1
    } else if comparison > 0.0 {
      high = i - 1
    } else {
      high = i
      break
    }
  }
  let i = high
  if arc_lengths.unsafe_get(i) == target_arc_length {
    return i.to_double() / (il - 1).to_double()
  }
  // we could get finer grain at lengths, or use simple interpolation between two points
  let length_before = arc_lengths.unsafe_get(i)
  let length_after = arc_lengths.unsafe_get(i + 1)
  let segment_length = length_after - length_before
  // determine where we are between the 'before' and 'after' points
  let segment_fraction = (target_arc_length - length_before) / segment_length
  // add that fractional amount to t
  (i.to_double() + segment_fraction) / (il - 1).to_double()
}

///|
/// The two sample positions of the default `getTangent`.
fn curve_tangent_range(t : Double) -> (Double, Double) {
  let delta = 0.0001
  let mut t1 = t - delta
  let mut t2 = t + delta
  // Capping in case of danger
  if t1 < 0.0 {
    t1 = 0.0
  }
  if t2 > 1.0 {
    t2 = 1.0
  }
  (t1, t2)
}

///|
pub fn[V : CurveVector] Curve::get_tangent(
  self : Curve[V],
  t : Double,
  optional_target? : V,
) -> V {
  match self.kind {
    Line(line) =>
      curve_target(optional_target).sub_vectors(line.v2, line.v1).normalize()
    Custom({ get_tangent: Some(get_tangent), .. }) =>
      get_tangent(self, t, curve_target(optional_target))
    _ => {
      let (t1, t2) = curve_tangent_range(t)
      let pt1 = self.get_point(t1)
      let pt2 = self.get_point(t2)
      curve_target(optional_target).copy(pt2).sub(pt1).normalize()
    }
  }
}

///|
pub fn[V : CurveVector] Curve::get_tangent_at(
  self : Curve[V],
  u : Double,
  optional_target? : V,
) -> V {
  match self.kind {
    Line(_) => self.get_tangent(u, optional_target?)
    _ => {
      let t = self.get_uto_tmapping(u)
      self.get_tangent(t, optional_target?)
    }
  }
}

///|
/// Upstream `computeFrenetFrames`. It takes a curve in 3D space; a 2D curve gives upstream's
/// `NaN`-laden frames.
pub fn[V : CurveVector] Curve::compute_frenet_frames(
  self : Curve[V],
  segments : Int32,
  closed~ : Bool = false,
) -> FrenetFrames {
  // see http://www.cs.indiana.edu/pub/techreports/TR425.pdf
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let tangents = []
  let normals = []
  let binormals = []
  let vec = @math.Vector3::new(0.0, 0.0, 0.0)
  let mat = @math.Matrix4::new()
  // compute the tangent vectors for each segment on the curve
  for i = 0; i <= segments; i = i + 1 {
    let u = i.to_double() / segments.to_double()
    tangents.push(V::frenet_tangent_at(self, u))
  }
  // select an initial normal vector perpendicular to the first tangent vector,
  // and in the direction of the minimum tangent xyz component
  normals.push(@math.Vector3::new(0.0, 0.0, 0.0))
  binormals.push(@math.Vector3::new(0.0, 0.0, 0.0))
  let mut min = 1.7976931348623157e308
  let tx = tangents[0].x.abs()
  let ty = tangents[0].y.abs()
  let tz = tangents[0].z.abs()
  if tx <= min {
    min = tx
    ignore(normal.set(1.0, 0.0, 0.0))
  }
  if ty <= min {
    min = ty
    ignore(normal.set(0.0, 1.0, 0.0))
  }
  if tz <= min {
    ignore(normal.set(0.0, 0.0, 1.0))
  }
  ignore(vec.cross_vectors(tangents[0], normal).normalize())
  ignore(normals[0].cross_vectors(tangents[0], vec))
  ignore(binormals[0].cross_vectors(tangents[0], normals[0]))
  // compute the slowly-varying normal and binormal vectors for each segment on the curve
  for i = 1; i <= segments; i = i + 1 {
    normals.push(normals[i - 1].clone())
    binormals.push(binormals[i - 1].clone())
    ignore(vec.cross_vectors(tangents[i - 1], tangents[i]))
    if vec.length() > curve_epsilon {
      ignore(vec.normalize())
      let theta = @cmath.acos(
        @math.clamp(tangents[i - 1].dot(tangents[i]), -1.0, 1.0),
      ) // clamp for floating pt errors
      ignore(normals[i].apply_matrix4(mat.make_rotation_axis(vec, theta)))
    }
    ignore(binormals[i].cross_vectors(tangents[i], normals[i]))
  }
  // if the curve is closed, postprocess the vectors so the first and last normal vectors are the same
  if closed {
    let mut theta = @cmath.acos(
      @math.clamp(normals[0].dot(normals[segments]), -1.0, 1.0),
    )
    theta /= segments.to_double()
    if tangents[0].dot(vec.cross_vectors(normals[0], normals[segments])) > 0.0 {
      theta = -theta
    }
    for i = 1; i <= segments; i = i + 1 {
      // twist a little...
      ignore(
        normals[i].apply_matrix4(
          mat.make_rotation_axis(tangents[i], theta * i.to_double()),
        ),
      )
      ignore(binormals[i].cross_vectors(tangents[i], normals[i]))
    }
  }
  { tangents, normals, binormals, }
}

///|
/// `new this.constructor()`.
fn[V : CurveVector] Curve::construct(self : Curve[V]) -> Curve[V] {
  let curve : Curve[V] = match self.kind {
    Abstract => Curve::new()
    Custom({ construct: Some(construct), .. }) => construct()
    Custom(extension) => curve_make(self.type_, Custom(extension))
    Line(_) => curve_make(self.type_, Line(LineCurveData::default_()))
    QuadraticBezier(_) =>
      curve_make(
        self.type_,
        QuadraticBezier(QuadraticBezierCurveData::default_()),
      )
    CubicBezier(_) =>
      curve_make(self.type_, CubicBezier(CubicBezierCurveData::default_()))
    Ellipse(_) => curve_make(self.type_, Ellipse(EllipseCurveData::default_()))
    Spline(_) => curve_make(self.type_, Spline({ points: [], }))
    CatmullRom(_) =>
      curve_make(
        self.type_,
        CatmullRom({
          points: [],
          closed: false,
          curve_type: "centripetal",
          tension: 0.5,
        }),
      )
    CurvePath(_) => CurvePath::new()
    Path(_, _) =>
      curve_make(
        self.type_,
        Path(CurvePathData::new(), { current_point: V::zero(), }),
      )
    Shape(_, _, _) =>
      curve_make(
        self.type_,
        Shape(
          CurvePathData::new(),
          { current_point: V::zero(), },
          ShapeData::new(),
        ),
      )
  }
  curve
}

///|
pub fn[V : CurveVector] Curve::clone(self : Curve[V]) -> Curve[V] {
  self.construct().copy(self)
}

///|
pub fn[V : CurveVector] Curve::copy(
  self : Curve[V],
  source : Curve[V],
) -> Curve[V] {
  self.arc_length_divisions = source.arc_length_divisions
  self.cache_arc_lengths = None
  match (self.kind, source.kind) {
    (Abstract, _) => ()
    (Custom(extension), _) =>
      if extension.copy is Some(copy) {
        copy(self, source)
      }
    (Line(target), Line(source)) => target.copy(source)
    (QuadraticBezier(target), QuadraticBezier(source)) => target.copy(source)
    (CubicBezier(target), CubicBezier(source)) => target.copy(source)
    (Ellipse(target), Ellipse(source)) => target.copy(source)
    (Spline(target), Spline(source)) => target.copy(source)
    (CatmullRom(target), CatmullRom(source)) => target.copy(source)
    (
      CurvePath(target),
      CurvePath(source)
      | Path(source, _)
      | Shape(source, _, _),
    ) => target.copy(source)
    (
      Path(target, path),
      Path(source, source_path)
      | Shape(source, source_path, _),
    ) => {
      target.copy(source)
      curve_copy_vector(path.current_point, source_path.current_point)
    }
    (Shape(target, path, shape), Shape(source, source_path, source_shape)) => {
      target.copy(source)
      curve_copy_vector(path.current_point, source_path.current_point)
      shape.copy(source_shape)
    }
    _ => abort("Curve::copy: '\{self.type_}' from '\{source.type_}'")
  }
  self
}

///|
fn[V : CurveVector] curve_json_points(points : Array[V]) -> Json {
  Json::array(points.map(curve_json_vector_numbers))
}

///|
fn curve_json_get(json : Json, key : String) -> Json {
  match json {
    Object(object) =>
      match object.get(key) {
        Some(value) => value
        None => abort("Curve::from_json: missing '\{key}'")
      }
    _ => abort("Curve::from_json: not an object")
  }
}

///|
/// A number, or `null` as `JSON.stringify` writes NaN and the infinities. JS reads `null`
/// as 0 in arithmetic; readers that keep the field remember the `null` for `toJSON` (see
/// curve_json_nulls.mbt).
fn curve_json_number(json : Json) -> Double {
  match json {
    Number(value, ..) => value
    Null => 0.0
    _ => abort("Curve::from_json: not a number")
  }
}

///|
fn curve_json_double(json : Json, key : String) -> Double {
  curve_json_number(curve_json_get(json, key))
}

///|
fn curve_json_array(json : Json, key : String) -> Array[Json] {
  match curve_json_get(json, key) {
    Array(values) => values
    _ => abort("Curve::from_json: '\{key}' is not an array")
  }
}

///|
fn curve_json_bool(json : Json, key : String) -> Bool {
  match curve_json_get(json, key) {
    True => true
    False => false
    _ => abort("Curve::from_json: '\{key}' is not a boolean")
  }
}

///|
fn curve_json_string(json : Json, key : String) -> String {
  match curve_json_get(json, key) {
    String(value) => value
    _ => abort("Curve::from_json: '\{key}' is not a string")
  }
}

///|
fn curve_json_doubles(json : Json) -> Array[Double] {
  match json {
    Array(values) => values.map(curve_json_number)
    _ => abort("Curve::from_json: not an array")
  }
}

///|
fn[V : CurveVector] curve_json_vector(
  target : V,
  json : Json,
  key : String,
) -> Unit {
  ignore(curve_json_vector_from(target, curve_json_get(json, key)))
}

///|
pub fn[V : CurveVector] Curve::to_json(self : Curve[V]) -> Json {
  let data : Map[String, Json] = Map([])
  data["metadata"] = Json::object({
    "version": Json::number(4.7),
    "type": Json::string("Curve"),
    "generator": Json::string("Curve.toJSON"),
  })
  data["arcLengthDivisions"] = @math.json_number(
    self.arc_length_divisions.to_double(),
  )
  data["type"] = Json::string(self.type_)
  match self.kind {
    Abstract => ()
    Custom(extension) =>
      if extension.to_json is Some(to_json) {
        to_json(self, data)
      }
    Line(line) => line.to_json(data)
    QuadraticBezier(curve) => curve.to_json(data)
    CubicBezier(curve) => curve.to_json(data)
    Ellipse(curve) => curve.to_json(data)
    Spline(curve) => curve.to_json(data)
    CatmullRom(curve) => curve.to_json(data)
    CurvePath(path) => path.to_json(data)
    Path(path, extra) => {
      path.to_json(data)
      extra.to_json(data)
    }
    Shape(path, extra, shape) => {
      path.to_json(data)
      extra.to_json(data)
      shape.to_json(data)
    }
  }
  Json::object(data)
}

///|
pub fn[V : CurveVector] Curve::from_json(
  self : Curve[V],
  json : Json,
) -> Curve[V] {
  self.arc_length_divisions = curve_json_double(json, "arcLengthDivisions").to_int()
  self.cache_arc_lengths = None
  match self.kind {
    Abstract => ()
    Custom(extension) =>
      if extension.from_json is Some(from_json) {
        from_json(self, json)
      }
    Line(line) => line.from_json(json)
    QuadraticBezier(curve) => curve.from_json(json)
    CubicBezier(curve) => curve.from_json(json)
    Ellipse(curve) => curve.from_json(json)
    Spline(curve) => curve.from_json(json)
    CatmullRom(curve) => curve.from_json(json)
    CurvePath(path) => path.from_json(json)
    Path(path, extra) => {
      path.from_json(json)
      extra.from_json(json)
    }
    Shape(path, extra, shape) => {
      path.from_json(json)
      extra.from_json(json)
      shape.from_json(json)
    }
  }
  self
}
