///|
/// A point in 3D space in spherical coordinates.
pub(all) struct Spherical {
  mut radius : Double
  mut phi : Double
  mut theta : Double
}

///|
pub fn Spherical::new(
  radius : Double,
  phi : Double,
  theta : Double,
) -> Spherical {
  { radius, phi, theta, }
}

///|
pub fn Spherical::set(
  self : Spherical,
  radius : Double,
  phi : Double,
  theta : Double,
) -> Spherical {
  self.radius = radius
  self.phi = phi
  self.theta = theta
  self
}

///|
pub fn Spherical::copy(self : Spherical, other : Spherical) -> Spherical {
  self.radius = other.radius
  self.phi = other.phi
  self.theta = other.theta
  self
}

///|
pub fn Spherical::make_safe(self : Spherical) -> Spherical {
  let eps = 0.000001
  self.phi = clamp(self.phi, eps, @cmath.PI - eps)
  self
}

///|
pub fn Spherical::set_from_vector3(self : Spherical, v : Vector3) -> Spherical {
  self.set_from_cartesian_coords(v.x, v.y, v.z)
}

///|
pub fn Spherical::set_from_cartesian_coords(
  self : Spherical,
  x : Double,
  y : Double,
  z : Double,
) -> Spherical {
  self.radius = (x * x + y * y + z * z).sqrt()
  if self.radius == 0.0 {
    self.theta = 0.0
    self.phi = 0.0
  } else {
    self.theta = @cmath.atan2(x, z)
    self.phi = @cmath.acos(clamp(y / self.radius, -1.0, 1.0))
  }
  self
}

///|
pub fn Spherical::clone(self : Spherical) -> Spherical {
  Spherical::new(1.0, 0.0, 0.0).copy(self)
}
