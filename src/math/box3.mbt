///|
/// Positive infinity. `moonbitlang/core/double` is not imported by this package.
let _bounds_infinity : Double = 1.0 / 0.0

///|
/// JS `Math.max`. `Double::max` differs from it on NaN and signed zero.
extern "js" fn _bounds_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// JS `Math.min`. `Double::min` differs from it on NaN and signed zero.
extern "js" fn _bounds_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
let _box3_points : Array[Vector3] = [
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
  Vector3::new(0.0, 0.0, 0.0),
]

///|
let _box3_vector : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_v0 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_v1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_v2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_f0 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_f1 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_f2 : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_center : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_extents : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_triangle_normal : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _box3_test_axis : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
fn _box3_sat_for_axes(
  axes : Array[Double],
  v0 : Vector3,
  v1 : Vector3,
  v2 : Vector3,
  extents : Vector3,
) -> Bool {
  let j = axes.length() - 3
  for i = 0; i <= j; i = i + 3 {
    _box3_test_axis.from_array(axes, offset=i) |> ignore
    // project the aabb onto the separating axis
    let r = extents.x * _box3_test_axis.x.abs() +
      extents.y * _box3_test_axis.y.abs() +
      extents.z * _box3_test_axis.z.abs()
    // project all 3 vertices of the triangle onto the separating axis
    let p0 = v0.dot(_box3_test_axis)
    let p1 = v1.dot(_box3_test_axis)
    let p2 = v2.dot(_box3_test_axis)
    // actual test, basically see if either of the most extreme of the triangle points intersects r
    if _bounds_math_max(
        -_bounds_math_max(_bounds_math_max(p0, p1), p2),
        _bounds_math_min(_bounds_math_min(p0, p1), p2),
      ) >
      r {
      // points of the projected triangle are outside the projected half-length of the aabb
      // the axis is separating and we can exit
      return false
    }
  }
  true
}

///|
/// Encodes numbers as a JSON array.
fn _bounds_json_numbers(array : Array[Double]) -> Json {
  json_numbers(array)
}

///|
/// Decodes a JSON array of numbers.
fn _bounds_json_doubles(json : Json) -> Array[Double] {
  guard json is Array(items) else { abort("expected a JSON array") }
  items.map(fn(item) {
    guard json_to_number(item) is Some(value) else {
      abort("expected a JSON number")
    }
    value
  })
}

///|
/// An axis-aligned bounding box in 3D space.
pub(all) struct Box3 {
  mut min : Vector3
  mut max : Vector3
}

///|
pub fn Box3::new(
  min~ : Vector3 = Vector3::new(
    _bounds_infinity, _bounds_infinity, _bounds_infinity,
  ),
  max~ : Vector3 = Vector3::new(
    -_bounds_infinity,
    -_bounds_infinity,
    -_bounds_infinity,
  ),
) -> Box3 {
  { min, max, }
}

///|
pub fn Box3::set(self : Box3, min : Vector3, max : Vector3) -> Box3 {
  self.min.copy(min) |> ignore
  self.max.copy(max) |> ignore
  self
}

///|
pub fn Box3::set_from_array(self : Box3, array : Array[Double]) -> Box3 {
  self.make_empty() |> ignore
  let il = array.length()
  for i = 0; i < il; i = i + 3 {
    self.expand_by_point(_box3_vector.from_array(array, offset=i)) |> ignore
  }
  self
}

///|
pub fn Box3::set_from_points(self : Box3, points : Array[Vector3]) -> Box3 {
  self.make_empty() |> ignore
  for point in points {
    self.expand_by_point(point) |> ignore
  }
  self
}

///|
pub fn Box3::set_from_center_and_size(
  self : Box3,
  center : Vector3,
  size : Vector3,
) -> Box3 {
  let half_size = _box3_vector.copy(size).multiply_scalar(0.5)
  self.min.copy(center).sub(half_size) |> ignore
  self.max.copy(center).add(half_size) |> ignore
  self
}

///|
pub fn Box3::clone(self : Box3) -> Box3 {
  Box3::new().copy(self)
}

///|
pub fn Box3::copy(self : Box3, box : Box3) -> Box3 {
  self.min.copy(box.min) |> ignore
  self.max.copy(box.max) |> ignore
  self
}

///|
pub fn Box3::make_empty(self : Box3) -> Box3 {
  self.min.z = _bounds_infinity
  self.min.y = self.min.z
  self.min.x = self.min.y
  self.max.z = -_bounds_infinity
  self.max.y = self.max.z
  self.max.x = self.max.y
  self
}

///|
pub fn Box3::is_empty(self : Box3) -> Bool {
  // this is a more robust check for empty than ( volume <= 0 ) because volume can get positive with two negative axes
  self.max.x < self.min.x || self.max.y < self.min.y || self.max.z < self.min.z
}

///|
pub fn Box3::get_center(self : Box3, target : Vector3) -> Vector3 {
  if self.is_empty() {
    target.set(0.0, 0.0, 0.0)
  } else {
    target.add_vectors(self.min, self.max).multiply_scalar(0.5)
  }
}

///|
pub fn Box3::get_size(self : Box3, target : Vector3) -> Vector3 {
  if self.is_empty() {
    target.set(0.0, 0.0, 0.0)
  } else {
    target.sub_vectors(self.max, self.min)
  }
}

///|
pub fn Box3::expand_by_point(self : Box3, point : Vector3) -> Box3 {
  self.min.min(point) |> ignore
  self.max.max(point) |> ignore
  self
}

///|
pub fn Box3::expand_by_vector(self : Box3, vector : Vector3) -> Box3 {
  self.min.sub(vector) |> ignore
  self.max.add(vector) |> ignore
  self
}

///|
pub fn Box3::expand_by_scalar(self : Box3, scalar : Double) -> Box3 {
  self.min.add_scalar(-scalar) |> ignore
  self.max.add_scalar(scalar) |> ignore
  self
}

///|
pub fn Box3::contains_point(self : Box3, point : Vector3) -> Bool {
  point.x >= self.min.x &&
  point.x <= self.max.x &&
  point.y >= self.min.y &&
  point.y <= self.max.y &&
  point.z >= self.min.z &&
  point.z <= self.max.z
}

///|
pub fn Box3::contains_box(self : Box3, box : Box3) -> Bool {
  self.min.x <= box.min.x &&
  box.max.x <= self.max.x &&
  self.min.y <= box.min.y &&
  box.max.y <= self.max.y &&
  self.min.z <= box.min.z &&
  box.max.z <= self.max.z
}

///|
pub fn Box3::get_parameter(
  self : Box3,
  point : Vector3,
  target : Vector3,
) -> Vector3 {
  // This can potentially have a divide by zero if the box
  // has a size dimension of 0.
  target.set(
    (point.x - self.min.x) / (self.max.x - self.min.x),
    (point.y - self.min.y) / (self.max.y - self.min.y),
    (point.z - self.min.z) / (self.max.z - self.min.z),
  )
}

///|
pub fn Box3::intersects_box(self : Box3, box : Box3) -> Bool {
  // using 6 splitting planes to rule out intersections.
  box.max.x >= self.min.x &&
  box.min.x <= self.max.x &&
  box.max.y >= self.min.y &&
  box.min.y <= self.max.y &&
  box.max.z >= self.min.z &&
  box.min.z <= self.max.z
}

///|
pub fn Box3::intersects_sphere(self : Box3, sphere : Sphere) -> Bool {
  // Find the point on the AABB closest to the sphere center.
  self.clamp_point(sphere.center, _box3_vector) |> ignore
  // If that point is inside the sphere, the AABB and sphere intersect.
  _box3_vector.distance_to_squared(sphere.center) <=
  sphere.radius * sphere.radius
}

///|
pub fn Box3::intersects_plane(self : Box3, plane : Plane) -> Bool {
  // We compute the minimum and maximum dot product values. If those values
  // are on the same side (back or front) of the plane, then there is no intersection.
  let mut min = 0.0
  let mut max = 0.0
  if plane.normal.x > 0.0 {
    min = plane.normal.x * self.min.x
    max = plane.normal.x * self.max.x
  } else {
    min = plane.normal.x * self.max.x
    max = plane.normal.x * self.min.x
  }
  if plane.normal.y > 0.0 {
    min += plane.normal.y * self.min.y
    max += plane.normal.y * self.max.y
  } else {
    min += plane.normal.y * self.max.y
    max += plane.normal.y * self.min.y
  }
  if plane.normal.z > 0.0 {
    min += plane.normal.z * self.min.z
    max += plane.normal.z * self.max.z
  } else {
    min += plane.normal.z * self.max.z
    max += plane.normal.z * self.min.z
  }
  min <= -plane.constant && max >= -plane.constant
}

///|
pub fn Box3::intersects_triangle(self : Box3, triangle : Triangle) -> Bool {
  if self.is_empty() {
    return false
  }
  // compute box center and extents
  self.get_center(_box3_center) |> ignore
  _box3_extents.sub_vectors(self.max, _box3_center) |> ignore
  // translate triangle to aabb origin
  _box3_v0.sub_vectors(triangle.a, _box3_center) |> ignore
  _box3_v1.sub_vectors(triangle.b, _box3_center) |> ignore
  _box3_v2.sub_vectors(triangle.c, _box3_center) |> ignore
  // compute edge vectors for triangle
  _box3_f0.sub_vectors(_box3_v1, _box3_v0) |> ignore
  _box3_f1.sub_vectors(_box3_v2, _box3_v1) |> ignore
  _box3_f2.sub_vectors(_box3_v0, _box3_v2) |> ignore
  // test against axes that are given by cross product combinations of the edges of the triangle and the edges of the aabb
  // make an axis testing of each of the 3 sides of the aabb against each of the 3 sides of the triangle = 9 axis of separation
  // axis_ij = u_i x f_j (u0, u1, u2 = face normals of aabb = x,y,z axes vectors since aabb is axis aligned)
  let axes = [
    0.0,
    -_box3_f0.z,
    _box3_f0.y,
    0.0,
    -_box3_f1.z,
    _box3_f1.y,
    0.0,
    -_box3_f2.z,
    _box3_f2.y,
    _box3_f0.z,
    0.0,
    -_box3_f0.x,
    _box3_f1.z,
    0.0,
    -_box3_f1.x,
    _box3_f2.z,
    0.0,
    -_box3_f2.x,
    -_box3_f0.y,
    _box3_f0.x,
    0.0,
    -_box3_f1.y,
    _box3_f1.x,
    0.0,
    -_box3_f2.y,
    _box3_f2.x,
    0.0,
  ]
  if !_box3_sat_for_axes(axes, _box3_v0, _box3_v1, _box3_v2, _box3_extents) {
    return false
  }
  // test 3 face normals from the aabb
  let axes = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
  if !_box3_sat_for_axes(axes, _box3_v0, _box3_v1, _box3_v2, _box3_extents) {
    return false
  }
  // finally testing the face normal of the triangle
  // use already existing triangle edge vectors here
  _box3_triangle_normal.cross_vectors(_box3_f0, _box3_f1) |> ignore
  let axes = [
    _box3_triangle_normal.x,
    _box3_triangle_normal.y,
    _box3_triangle_normal.z,
  ]
  _box3_sat_for_axes(axes, _box3_v0, _box3_v1, _box3_v2, _box3_extents)
}

///|
pub fn Box3::clamp_point(
  self : Box3,
  point : Vector3,
  target : Vector3,
) -> Vector3 {
  target.copy(point).clamp(self.min, self.max)
}

///|
pub fn Box3::distance_to_point(self : Box3, point : Vector3) -> Double {
  self.clamp_point(point, _box3_vector).distance_to(point)
}

///|
pub fn Box3::get_bounding_sphere(self : Box3, target : Sphere) -> Sphere {
  if self.is_empty() {
    target.make_empty() |> ignore
  } else {
    self.get_center(target.center) |> ignore
    target.radius = self.get_size(_box3_vector).length() * 0.5
  }
  target
}

///|
pub fn Box3::intersect(self : Box3, box : Box3) -> Box3 {
  self.min.max(box.min) |> ignore
  self.max.min(box.max) |> ignore
  // ensure that if there is no overlap, the result is fully empty, not slightly empty with non-inf/+inf values that will cause subsequence intersects to erroneously return valid values.
  if self.is_empty() {
    self.make_empty() |> ignore
  }
  self
}

///|
pub fn Box3::union(self : Box3, box : Box3) -> Box3 {
  self.min.min(box.min) |> ignore
  self.max.max(box.max) |> ignore
  self
}

///|
pub fn Box3::apply_matrix4(self : Box3, matrix : Matrix4) -> Box3 {
  // transform of empty box is an empty box.
  if self.is_empty() {
    return self
  }
  // NOTE: I am using a binary pattern to specify all 2^3 combinations below
  let min = self.min
  let max = self.max
  _box3_points[0].set(min.x, min.y, min.z).apply_matrix4(matrix) |> ignore // 000
  _box3_points[1].set(min.x, min.y, max.z).apply_matrix4(matrix) |> ignore // 001
  _box3_points[2].set(min.x, max.y, min.z).apply_matrix4(matrix) |> ignore // 010
  _box3_points[3].set(min.x, max.y, max.z).apply_matrix4(matrix) |> ignore // 011
  _box3_points[4].set(max.x, min.y, min.z).apply_matrix4(matrix) |> ignore // 100
  _box3_points[5].set(max.x, min.y, max.z).apply_matrix4(matrix) |> ignore // 101
  _box3_points[6].set(max.x, max.y, min.z).apply_matrix4(matrix) |> ignore // 110
  _box3_points[7].set(max.x, max.y, max.z).apply_matrix4(matrix) |> ignore // 111
  self.set_from_points(_box3_points) |> ignore
  self
}

///|
pub fn Box3::translate(self : Box3, offset : Vector3) -> Box3 {
  self.min.add(offset) |> ignore
  self.max.add(offset) |> ignore
  self
}

///|
pub fn Box3::equals(self : Box3, box : Box3) -> Bool {
  box.min.equals(self.min) && box.max.equals(self.max)
}

///|
pub fn Box3::to_json(self : Box3) -> Json {
  {
    "min": _bounds_json_numbers(self.min.to_array()),
    "max": _bounds_json_numbers(self.max.to_array()),
  }
}

///|
pub fn Box3::from_json(self : Box3, json : Json) -> Box3 {
  guard json is { "min": min, "max": max, .. } else {
    abort("Box3::from_json: expected min and max")
  }
  self.min.from_array(_bounds_json_doubles(min)) |> ignore
  self.max.from_array(_bounds_json_doubles(max)) |> ignore
  self
}
