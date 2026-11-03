///|
let _plane_vector1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _plane_vector2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _plane_normal_matrix : Matrix3 = Matrix3::new()

///|
/// A two dimensional surface extending infinitely in 3D space, in Hessian normal form.
pub(all) struct Plane {
  mut normal : Vector3
  mut constant : Double
}

///|
pub fn Plane::new(
  normal~ : Vector3 = Vector3::new(1.0, 0.0, 0.0),
  constant~ : Double = 0.0,
) -> Plane {
  { normal, constant, }
}

///|
pub fn Plane::set(self : Plane, normal : Vector3, constant : Double) -> Plane {
  self.normal.copy(normal) |> ignore
  self.constant = constant
  self
}

///|
pub fn Plane::set_components(
  self : Plane,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Plane {
  self.normal.set(x, y, z) |> ignore
  self.constant = w
  self
}

///|
pub fn Plane::set_from_normal_and_coplanar_point(
  self : Plane,
  normal : Vector3,
  point : Vector3,
) -> Plane {
  self.normal.copy(normal) |> ignore
  self.constant = -point.dot(self.normal)
  self
}

///|
pub fn Plane::set_from_coplanar_points(
  self : Plane,
  a : Vector3,
  b : Vector3,
  c : Vector3,
) -> Plane {
  let normal = _plane_vector1
    .sub_vectors(c, b)
    .cross(_plane_vector2.sub_vectors(a, b))
    .normalize()
  // Q: should an error be thrown if normal is zero (e.g. degenerate plane)?
  self.set_from_normal_and_coplanar_point(normal, a) |> ignore
  self
}

///|
pub fn Plane::copy(self : Plane, plane : Plane) -> Plane {
  self.normal.copy(plane.normal) |> ignore
  self.constant = plane.constant
  self
}

///|
pub fn Plane::normalize(self : Plane) -> Plane {
  // Note: will lead to a divide by zero if the plane is invalid.
  let inverse_normal_length = 1.0 / self.normal.length()
  self.normal.multiply_scalar(inverse_normal_length) |> ignore
  self.constant *= inverse_normal_length
  self
}

///|
pub fn Plane::negate(self : Plane) -> Plane {
  self.constant *= -1.0
  self.normal.negate() |> ignore
  self
}

///|
pub fn Plane::distance_to_point(self : Plane, point : Vector3) -> Double {
  self.normal.dot(point) + self.constant
}

///|
pub fn Plane::distance_to_sphere(self : Plane, sphere : Sphere) -> Double {
  self.distance_to_point(sphere.center) - sphere.radius
}

///|
pub fn Plane::project_point(
  self : Plane,
  point : Vector3,
  target : Vector3,
) -> Vector3 {
  target
  .copy(point)
  .add_scaled_vector(self.normal, -self.distance_to_point(point))
}

///|
pub fn Plane::intersect_line(
  self : Plane,
  line : Line3,
  target : Vector3,
  clamp_to_line~ : Bool = true,
) -> Vector3? {
  let direction = line.delta(_plane_vector1)
  let denominator = self.normal.dot(direction)
  if denominator == 0.0 {
    // line is coplanar, return origin
    if self.distance_to_point(line.start) == 0.0 {
      return Some(target.copy(line.start))
    }
    // Unsure if this is the correct method to handle this case.
    return None
  }
  let t = -(line.start.dot(self.normal) + self.constant) / denominator
  if clamp_to_line && (t < 0.0 || t > 1.0) {
    return None
  }
  Some(target.copy(line.start).add_scaled_vector(direction, t))
}

///|
pub fn Plane::intersects_line(self : Plane, line : Line3) -> Bool {
  // Note: this tests if a line intersects the plane, not whether it (or its end-points) are coplanar with it.
  let start_sign = self.distance_to_point(line.start)
  let end_sign = self.distance_to_point(line.end)
  (start_sign < 0.0 && end_sign > 0.0) || (end_sign < 0.0 && start_sign > 0.0)
}

///|
pub fn Plane::intersects_box(self : Plane, box : Box3) -> Bool {
  box.intersects_plane(self)
}

///|
pub fn Plane::intersects_sphere(self : Plane, sphere : Sphere) -> Bool {
  sphere.intersects_plane(self)
}

///|
pub fn Plane::coplanar_point(self : Plane, target : Vector3) -> Vector3 {
  target.copy(self.normal).multiply_scalar(-self.constant)
}

///|
pub fn Plane::apply_matrix4(
  self : Plane,
  matrix : Matrix4,
  optional_normal_matrix? : Matrix3,
) -> Plane {
  let normal_matrix = match optional_normal_matrix {
    Some(m) => m
    None => _plane_normal_matrix.get_normal_matrix(matrix)
  }
  let reference_point = self
    .coplanar_point(_plane_vector1)
    .apply_matrix4(matrix)
  let normal = self.normal.apply_matrix3(normal_matrix).normalize()
  self.constant = -reference_point.dot(normal)
  self
}

///|
pub fn Plane::translate(self : Plane, offset : Vector3) -> Plane {
  self.constant -= offset.dot(self.normal)
  self
}

///|
pub fn Plane::equals(self : Plane, plane : Plane) -> Bool {
  plane.normal.equals(self.normal) && plane.constant == self.constant
}

///|
pub fn Plane::clone(self : Plane) -> Plane {
  Plane::new().copy(self)
}

///|
pub fn Plane::to_json(self : Plane) -> Json {
  {
    "normal": _bounds_json_numbers(self.normal.to_array()),
    "constant": json_number(self.constant),
  }
}

///|
pub fn Plane::from_json(self : Plane, json : Json) -> Plane {
  guard json is { "normal": normal, "constant": constant, .. } &&
    json_to_number(constant) is Some(constant) else {
    abort("Plane::from_json: expected normal and constant")
  }
  self.normal.from_array(_bounds_json_doubles(normal)) |> ignore
  self.constant = constant
  self
}
