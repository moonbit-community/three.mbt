// Upstream src/extras/curves/EllipseCurve.js.

///|
#external
pub type EllipseCurve

///|
pub(all) struct EllipseCurveData {
  mut a_x : Double
  mut a_y : Double
  mut x_radius : Double
  mut y_radius : Double
  mut a_start_angle : Double
  mut a_end_angle : Double
  mut a_clockwise : Bool
  mut a_rotation : Double
}

///|
fn EllipseCurveData::default_() -> EllipseCurveData {
  {
    a_x: 0.0,
    a_y: 0.0,
    x_radius: 1.0,
    y_radius: 1.0,
    a_start_angle: 0.0,
    a_end_angle: curve_two_pi,
    a_clockwise: false,
    a_rotation: 0.0,
  }
}

///|
pub fn EllipseCurve::new(
  a_x~ : Double = 0.0,
  a_y~ : Double = 0.0,
  x_radius~ : Double = 1.0,
  y_radius~ : Double = 1.0,
  a_start_angle~ : Double = 0.0,
  a_end_angle~ : Double = curve_two_pi,
  a_clockwise~ : Bool = false,
  a_rotation~ : Double = 0.0,
) -> Curve[@math.Vector2] {
  curve_make(
    "EllipseCurve",
    Ellipse({
      a_x,
      a_y,
      x_radius,
      y_radius,
      a_start_angle,
      a_end_angle,
      a_clockwise,
      a_rotation,
    }),
  )
}

///|
fn[V : CurveVector] EllipseCurveData::get_point(
  self : EllipseCurveData,
  t : Double,
  point : V,
) -> V {
  let two_pi = curve_two_pi
  let mut delta_angle = self.a_end_angle - self.a_start_angle
  let same_points = delta_angle.abs() < curve_epsilon
  // ensures that deltaAngle is 0 .. 2 PI
  while delta_angle < 0.0 {
    delta_angle += two_pi
  }
  while delta_angle > two_pi {
    delta_angle -= two_pi
  }
  if delta_angle < curve_epsilon {
    if same_points {
      delta_angle = 0.0
    } else {
      delta_angle = two_pi
    }
  }
  if self.a_clockwise && !same_points {
    if delta_angle == two_pi {
      delta_angle = -two_pi
    } else {
      delta_angle = delta_angle - two_pi
    }
  }
  let angle = self.a_start_angle + t * delta_angle
  let mut x = self.a_x + self.x_radius * @cmath.cos(angle)
  let mut y = self.a_y + self.y_radius * @cmath.sin(angle)
  if self.a_rotation != 0.0 {
    let cos = @cmath.cos(self.a_rotation)
    let sin = @cmath.sin(self.a_rotation)
    let tx = x - self.a_x
    let ty = y - self.a_y
    // Rotate the point about the center of the ellipse.
    x = tx * cos - ty * sin + self.a_x
    y = tx * sin + ty * cos + self.a_y
  }
  point.set_xy(x, y)
}

///|
fn EllipseCurveData::copy(
  self : EllipseCurveData,
  source : EllipseCurveData,
) -> Unit {
  self.a_x = source.a_x
  self.a_y = source.a_y
  self.x_radius = source.x_radius
  self.y_radius = source.y_radius
  self.a_start_angle = source.a_start_angle
  self.a_end_angle = source.a_end_angle
  self.a_clockwise = source.a_clockwise
  self.a_rotation = source.a_rotation
  curve_null_copy(source, self)
}

///|
fn EllipseCurveData::to_json(
  self : EllipseCurveData,
  data : Map[String, Json],
) -> Unit {
  data["aX"] = curve_json_field(self, "aX", self.a_x)
  data["aY"] = curve_json_field(self, "aY", self.a_y)
  data["xRadius"] = curve_json_field(self, "xRadius", self.x_radius)
  data["yRadius"] = curve_json_field(self, "yRadius", self.y_radius)
  data["aStartAngle"] = curve_json_field(
    self,
    "aStartAngle",
    self.a_start_angle,
  )
  data["aEndAngle"] = curve_json_field(self, "aEndAngle", self.a_end_angle)
  data["aClockwise"] = Json::boolean(self.a_clockwise)
  data["aRotation"] = curve_json_field(self, "aRotation", self.a_rotation)
}

///|
fn EllipseCurveData::from_json(self : EllipseCurveData, json : Json) -> Unit {
  self.a_x = curve_json_double_of(self, json, "aX")
  self.a_y = curve_json_double_of(self, json, "aY")
  self.x_radius = curve_json_double_of(self, json, "xRadius")
  self.y_radius = curve_json_double_of(self, json, "yRadius")
  self.a_start_angle = curve_json_double_of(self, json, "aStartAngle")
  self.a_end_angle = curve_json_double_of(self, json, "aEndAngle")
  self.a_clockwise = curve_json_bool(json, "aClockwise")
  self.a_rotation = curve_json_double_of(self, json, "aRotation")
}
