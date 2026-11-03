///|
let _box2_vector : Vector2 = Vector2::new(0.0, 0.0)

///|
/// An axis-aligned bounding box in 2D space.
pub(all) struct Box2 {
  mut min : Vector2
  mut max : Vector2
}

///|
pub fn Box2::new(
  min~ : Vector2 = Vector2::new(_bounds_infinity, _bounds_infinity),
  max~ : Vector2 = Vector2::new(-_bounds_infinity, -_bounds_infinity),
) -> Box2 {
  { min, max, }
}

///|
pub fn Box2::set(self : Box2, min : Vector2, max : Vector2) -> Box2 {
  self.min.copy(min) |> ignore
  self.max.copy(max) |> ignore
  self
}

///|
pub fn Box2::set_from_points(self : Box2, points : Array[Vector2]) -> Box2 {
  self.make_empty() |> ignore
  for point in points {
    self.expand_by_point(point) |> ignore
  }
  self
}

///|
pub fn Box2::set_from_center_and_size(
  self : Box2,
  center : Vector2,
  size : Vector2,
) -> Box2 {
  let half_size = _box2_vector.copy(size).multiply_scalar(0.5)
  self.min.copy(center).sub(half_size) |> ignore
  self.max.copy(center).add(half_size) |> ignore
  self
}

///|
pub fn Box2::clone(self : Box2) -> Box2 {
  Box2::new().copy(self)
}

///|
pub fn Box2::copy(self : Box2, box : Box2) -> Box2 {
  self.min.copy(box.min) |> ignore
  self.max.copy(box.max) |> ignore
  self
}

///|
pub fn Box2::make_empty(self : Box2) -> Box2 {
  self.min.y = _bounds_infinity
  self.min.x = self.min.y
  self.max.y = -_bounds_infinity
  self.max.x = self.max.y
  self
}

///|
pub fn Box2::is_empty(self : Box2) -> Bool {
  // this is a more robust check for empty than ( volume <= 0 ) because volume can get positive with two negative axes
  self.max.x < self.min.x || self.max.y < self.min.y
}

///|
pub fn Box2::get_center(self : Box2, target : Vector2) -> Vector2 {
  if self.is_empty() {
    target.set(0.0, 0.0)
  } else {
    target.add_vectors(self.min, self.max).multiply_scalar(0.5)
  }
}

///|
pub fn Box2::get_size(self : Box2, target : Vector2) -> Vector2 {
  if self.is_empty() {
    target.set(0.0, 0.0)
  } else {
    target.sub_vectors(self.max, self.min)
  }
}

///|
pub fn Box2::expand_by_point(self : Box2, point : Vector2) -> Box2 {
  self.min.min(point) |> ignore
  self.max.max(point) |> ignore
  self
}

///|
pub fn Box2::expand_by_vector(self : Box2, vector : Vector2) -> Box2 {
  self.min.sub(vector) |> ignore
  self.max.add(vector) |> ignore
  self
}

///|
pub fn Box2::expand_by_scalar(self : Box2, scalar : Double) -> Box2 {
  self.min.add_scalar(-scalar) |> ignore
  self.max.add_scalar(scalar) |> ignore
  self
}

///|
pub fn Box2::contains_point(self : Box2, point : Vector2) -> Bool {
  point.x >= self.min.x &&
  point.x <= self.max.x &&
  point.y >= self.min.y &&
  point.y <= self.max.y
}

///|
pub fn Box2::contains_box(self : Box2, box : Box2) -> Bool {
  self.min.x <= box.min.x &&
  box.max.x <= self.max.x &&
  self.min.y <= box.min.y &&
  box.max.y <= self.max.y
}

///|
pub fn Box2::get_parameter(
  self : Box2,
  point : Vector2,
  target : Vector2,
) -> Vector2 {
  // This can potentially have a divide by zero if the box
  // has a size dimension of 0.
  target.set(
    (point.x - self.min.x) / (self.max.x - self.min.x),
    (point.y - self.min.y) / (self.max.y - self.min.y),
  )
}

///|
pub fn Box2::intersects_box(self : Box2, box : Box2) -> Bool {
  // using 4 splitting planes to rule out intersections
  box.max.x >= self.min.x &&
  box.min.x <= self.max.x &&
  box.max.y >= self.min.y &&
  box.min.y <= self.max.y
}

///|
pub fn Box2::clamp_point(
  self : Box2,
  point : Vector2,
  target : Vector2,
) -> Vector2 {
  target.copy(point).clamp(self.min, self.max)
}

///|
pub fn Box2::distance_to_point(self : Box2, point : Vector2) -> Double {
  self.clamp_point(point, _box2_vector).distance_to(point)
}

///|
pub fn Box2::intersect(self : Box2, box : Box2) -> Box2 {
  self.min.max(box.min) |> ignore
  self.max.min(box.max) |> ignore
  if self.is_empty() {
    self.make_empty() |> ignore
  }
  self
}

///|
pub fn Box2::union(self : Box2, box : Box2) -> Box2 {
  self.min.min(box.min) |> ignore
  self.max.max(box.max) |> ignore
  self
}

///|
pub fn Box2::translate(self : Box2, offset : Vector2) -> Box2 {
  self.min.add(offset) |> ignore
  self.max.add(offset) |> ignore
  self
}

///|
pub fn Box2::equals(self : Box2, box : Box2) -> Bool {
  box.min.equals(self.min) && box.max.equals(self.max)
}
