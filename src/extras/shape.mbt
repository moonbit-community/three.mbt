// Upstream src/extras/core/Shape.js. See path.mbt for how it extends `Path`.

///|
pub(all) struct ShapeData {
  mut uuid : String
  mut holes : Array[Path]
}

///|
fn ShapeData::new() -> ShapeData {
  { uuid: @math.generate_uuid(), holes: [], }
}

///|
fn ShapeData::copy(self : ShapeData, source : ShapeData) -> Unit {
  self.holes = source.holes.map(hole => hole.clone())
}

///|
fn ShapeData::to_json(self : ShapeData, data : Map[String, Json]) -> Unit {
  data["uuid"] = Json::string(self.uuid)
  data["holes"] = Json::array(self.holes.map(hole => hole.to_json()))
}

///|
fn ShapeData::from_json(self : ShapeData, json : Json) -> Unit {
  self.uuid = curve_json_string(json, "uuid")
  self.holes = curve_json_array(json, "holes").map(hole => {
    Path::new().from_json(hole)
  })
}

///|
/// Upstream `Shape`. See the note at the top of path.mbt.
pub(all) struct Shape {
  curve : Curve[@math.Vector2]
}

///|
/// The result of `Shape::extract_points`.
pub(all) struct ShapePoints {
  shape : Array[@math.Vector2]
  holes : Array[Array[@math.Vector2]]
}

///|
pub impl PathLike for Shape with fn path_curve(self) {
  self.curve
}

///|
pub extend Shape with PathLike::{
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
pub impl @core.SerializableResource for Shape with fn uuid(self) {
  self.shape_data().uuid
}

///|
pub impl @core.SerializableResource for Shape with fn to_json(self) {
  self.curve.to_json()
}

///|
pub extend Shape with @core.SerializableResource::{payload}

///|
pub fn Shape::new(points? : Array[@math.Vector2]) -> Shape {
  let shape = Shape::{
    curve: curve_make(
      "Shape",
      Shape(
        CurvePathData::new(),
        { current_point: @math.Vector2::new(0.0, 0.0), },
        ShapeData::new(),
      ),
    ),
  }
  if points is Some(points) {
    ignore(shape.set_from_points(points))
  }
  shape
}

///|
fn Shape::shape_data(self : Shape) -> ShapeData {
  match self.curve.kind {
    Shape(_, _, shape) => shape
    _ => abort("'\{self.curve.type_}' is not a Shape")
  }
}

///|
/// Upstream `uuid`.
pub fn Shape::uuid(self : Shape) -> String {
  self.shape_data().uuid
}

///|
/// Upstream `holes`.
pub fn Shape::holes(self : Shape) -> Array[Path] {
  self.shape_data().holes
}

///|
pub fn Shape::set_holes(self : Shape, holes : Array[Path]) -> Unit {
  self.shape_data().holes = holes
}

///|
/// The upcast to `Path`, sharing this shape's state.
pub fn Shape::to_path(self : Shape) -> Path {
  Path::{ curve: self.curve, }
}

///|
pub fn Shape::get_points_holes(
  self : Shape,
  divisions : Int32,
) -> Array[Array[@math.Vector2]] {
  self.holes().map(hole => hole.get_points(divisions~))
}

///|
pub fn Shape::extract_points(self : Shape, divisions : Int32) -> ShapePoints {
  {
    shape: self.get_points(divisions~),
    holes: self.get_points_holes(divisions),
  }
}

///|
pub fn Shape::arc(
  self : Shape,
  a_x : Double,
  a_y : Double,
  a_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
) -> Shape {
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
pub fn Shape::absarc(
  self : Shape,
  a_x : Double,
  a_y : Double,
  a_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
) -> Shape {
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
pub fn Shape::ellipse(
  self : Shape,
  a_x : Double,
  a_y : Double,
  x_radius : Double,
  y_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
  a_rotation~ : Double = 0.0,
) -> Shape {
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
pub fn Shape::absellipse(
  self : Shape,
  a_x : Double,
  a_y : Double,
  x_radius : Double,
  y_radius : Double,
  a_start_angle : Double,
  a_end_angle : Double,
  a_clockwise~ : Bool = false,
  a_rotation~ : Double = 0.0,
) -> Shape {
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
pub fn Shape::get_point(
  self : Shape,
  t : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_point(t, optional_target?)
}

///|
pub fn Shape::get_point_or_null(
  self : Shape,
  t : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2? {
  self.curve.get_point_or_null(t, optional_target?)
}

///|
pub fn Shape::get_point_at(
  self : Shape,
  u : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_point_at(u, optional_target?)
}

///|
pub fn Shape::get_points(
  self : Shape,
  divisions? : Int32,
) -> Array[@math.Vector2] {
  self.curve.get_points(divisions?)
}

///|
pub fn Shape::get_spaced_points(
  self : Shape,
  divisions? : Int32,
) -> Array[@math.Vector2] {
  self.curve.get_spaced_points(divisions?)
}

///|
pub fn Shape::get_lengths(self : Shape, divisions? : Int32) -> Array[Double] {
  self.curve.get_lengths(divisions?)
}

///|
pub fn Shape::get_uto_tmapping(
  self : Shape,
  u : Double,
  distance? : Double,
) -> Double {
  self.curve.get_uto_tmapping(u, distance?)
}

///|
pub fn Shape::get_tangent(
  self : Shape,
  t : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_tangent(t, optional_target?)
}

///|
pub fn Shape::get_tangent_at(
  self : Shape,
  u : Double,
  optional_target? : @math.Vector2,
) -> @math.Vector2 {
  self.curve.get_tangent_at(u, optional_target?)
}

///|
pub fn Shape::compute_frenet_frames(
  self : Shape,
  segments : Int32,
  closed~ : Bool = false,
) -> FrenetFrames {
  self.curve.compute_frenet_frames(segments, closed~)
}

///|
pub fn Shape::clone(self : Shape) -> Shape {
  Shape::{ curve: self.curve.clone(), }
}

///|
pub fn Shape::copy(self : Shape, source : Shape) -> Shape {
  ignore(self.curve.copy(source.curve))
  self
}

///|
pub fn Shape::to_json(self : Shape) -> Json {
  self.curve.to_json()
}

///|
pub fn Shape::from_json(self : Shape, json : Json) -> Shape {
  ignore(self.curve.from_json(json))
  self
}
