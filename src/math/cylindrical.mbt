///|
/// A point in 3D space in cylindrical coordinates.
pub(all) struct Cylindrical {
  mut radius : Double
  mut theta : Double
  mut y : Double
}

///|
pub fn Cylindrical::new(
  radius : Double,
  theta : Double,
  y : Double,
) -> Cylindrical {
  { radius, theta, y, }
}

///|
pub fn Cylindrical::set(
  self : Cylindrical,
  radius : Double,
  theta : Double,
  y : Double,
) -> Cylindrical {
  self.radius = radius
  self.theta = theta
  self.y = y
  self
}

///|
pub fn Cylindrical::copy(
  self : Cylindrical,
  other : Cylindrical,
) -> Cylindrical {
  self.radius = other.radius
  self.theta = other.theta
  self.y = other.y
  self
}

///|
pub fn Cylindrical::set_from_vector3(
  self : Cylindrical,
  v : Vector3,
) -> Cylindrical {
  self.set_from_cartesian_coords(v.x, v.y, v.z)
}

///|
pub fn Cylindrical::set_from_cartesian_coords(
  self : Cylindrical,
  x : Double,
  y : Double,
  z : Double,
) -> Cylindrical {
  self.radius = (x * x + z * z).sqrt()
  self.theta = @cmath.atan2(x, z)
  self.y = y
  self
}

///|
pub fn Cylindrical::clone(self : Cylindrical) -> Cylindrical {
  Cylindrical::new(1.0, 0.0, 0.0).copy(self)
}
