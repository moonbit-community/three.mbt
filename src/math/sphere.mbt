///|
let _sphere_box : Box3 = Box3::new()

///|
let _sphere_v1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _sphere_v2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
/// A sphere defined by a center and a radius.
pub(all) struct Sphere {
  mut center : Vector3
  mut radius : Double
}

///|
pub fn Sphere::new(
  center~ : Vector3 = Vector3::new(0.0, 0.0, 0.0),
  radius~ : Double = -1.0,
) -> Sphere {
  { center, radius, }
}

///|
pub fn Sphere::set(self : Sphere, center : Vector3, radius : Double) -> Sphere {
  self.center.copy(center) |> ignore
  self.radius = radius
  self
}

///|
pub fn Sphere::set_from_points(
  self : Sphere,
  points : Array[Vector3],
  optional_center? : Vector3,
) -> Sphere {
  let center = self.center
  match optional_center {
    Some(c) => center.copy(c) |> ignore
    None => _sphere_box.set_from_points(points).get_center(center) |> ignore
  }
  let mut max_radius_sq = 0.0
  for point in points {
    max_radius_sq = _bounds_math_max(
      max_radius_sq,
      center.distance_to_squared(point),
    )
  }
  self.radius = max_radius_sq.sqrt()
  self
}

///|
pub fn Sphere::copy(self : Sphere, sphere : Sphere) -> Sphere {
  self.center.copy(sphere.center) |> ignore
  self.radius = sphere.radius
  self
}

///|
pub fn Sphere::is_empty(self : Sphere) -> Bool {
  self.radius < 0.0
}

///|
pub fn Sphere::make_empty(self : Sphere) -> Sphere {
  self.center.set(0.0, 0.0, 0.0) |> ignore
  self.radius = -1.0
  self
}

///|
pub fn Sphere::contains_point(self : Sphere, point : Vector3) -> Bool {
  point.distance_to_squared(self.center) <= self.radius * self.radius
}

///|
pub fn Sphere::distance_to_point(self : Sphere, point : Vector3) -> Double {
  point.distance_to(self.center) - self.radius
}

///|
pub fn Sphere::intersects_sphere(self : Sphere, sphere : Sphere) -> Bool {
  let radius_sum = self.radius + sphere.radius
  sphere.center.distance_to_squared(self.center) <= radius_sum * radius_sum
}

///|
pub fn Sphere::intersects_box(self : Sphere, box : Box3) -> Bool {
  box.intersects_sphere(self)
}

///|
pub fn Sphere::intersects_plane(self : Sphere, plane : Plane) -> Bool {
  plane.distance_to_point(self.center).abs() <= self.radius
}

///|
pub fn Sphere::clamp_point(
  self : Sphere,
  point : Vector3,
  target : Vector3,
) -> Vector3 {
  let delta_length_sq = self.center.distance_to_squared(point)
  target.copy(point) |> ignore
  if delta_length_sq > self.radius * self.radius {
    target.sub(self.center).normalize() |> ignore
    target.multiply_scalar(self.radius).add(self.center) |> ignore
  }
  target
}

///|
pub fn Sphere::get_bounding_box(self : Sphere, target : Box3) -> Box3 {
  if self.is_empty() {
    // Empty sphere produces empty bounding box
    target.make_empty() |> ignore
    return target
  }
  target.set(self.center, self.center) |> ignore
  target.expand_by_scalar(self.radius) |> ignore
  target
}

///|
pub fn Sphere::apply_matrix4(self : Sphere, matrix : Matrix4) -> Sphere {
  self.center.apply_matrix4(matrix) |> ignore
  self.radius = self.radius * matrix.get_max_scale_on_axis()
  self
}

///|
pub fn Sphere::translate(self : Sphere, offset : Vector3) -> Sphere {
  self.center.add(offset) |> ignore
  self
}

///|
pub fn Sphere::expand_by_point(self : Sphere, point : Vector3) -> Sphere {
  if self.is_empty() {
    self.center.copy(point) |> ignore
    self.radius = 0.0
    return self
  }
  _sphere_v1.sub_vectors(point, self.center) |> ignore
  let length_sq = _sphere_v1.length_sq()
  if length_sq > self.radius * self.radius {
    // calculate the minimal sphere
    let length = length_sq.sqrt()
    let delta = (length - self.radius) * 0.5
    self.center.add_scaled_vector(_sphere_v1, delta / length) |> ignore
    self.radius += delta
  }
  self
}

///|
pub fn Sphere::union(self : Sphere, sphere : Sphere) -> Sphere {
  if sphere.is_empty() {
    return self
  }
  if self.is_empty() {
    self.copy(sphere) |> ignore
    return self
  }
  if self.center.equals(sphere.center) {
    self.radius = _bounds_math_max(self.radius, sphere.radius)
  } else {
    _sphere_v2.sub_vectors(sphere.center, self.center).set_length(sphere.radius)
    |> ignore
    self.expand_by_point(_sphere_v1.copy(sphere.center).add(_sphere_v2))
    |> ignore
    self.expand_by_point(_sphere_v1.copy(sphere.center).sub(_sphere_v2))
    |> ignore
  }
  self
}

///|
pub fn Sphere::equals(self : Sphere, sphere : Sphere) -> Bool {
  sphere.center.equals(self.center) && sphere.radius == self.radius
}

///|
pub fn Sphere::clone(self : Sphere) -> Sphere {
  Sphere::new().copy(self)
}

///|
pub fn Sphere::to_json(self : Sphere) -> Json {
  {
    "radius": json_number(self.radius),
    "center": _bounds_json_numbers(self.center.to_array()),
  }
}

///|
pub fn Sphere::from_json(self : Sphere, json : Json) -> Sphere {
  guard json is { "radius": radius, "center": center, .. } &&
    json_to_number(radius) is Some(radius) else {
    abort("Sphere::from_json: expected radius and center")
  }
  self.radius = radius
  self.center.from_array(_bounds_json_doubles(center)) |> ignore
  self
}
