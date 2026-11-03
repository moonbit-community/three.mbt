// Upstream src/extras/curves/ArcCurve.js. It adds nothing to `EllipseCurve` but its `type`.

///|
#external
pub type ArcCurve

///|
pub fn ArcCurve::new(
  a_x~ : Double = 0.0,
  a_y~ : Double = 0.0,
  a_radius~ : Double = 1.0,
  a_start_angle~ : Double = 0.0,
  a_end_angle~ : Double = curve_two_pi,
  a_clockwise~ : Bool = false,
) -> Curve[@math.Vector2] {
  let curve = EllipseCurve::new(
    a_x~,
    a_y~,
    x_radius=a_radius,
    y_radius=a_radius,
    a_start_angle~,
    a_end_angle~,
    a_clockwise~,
  )
  curve.type_ = "ArcCurve"
  curve
}
