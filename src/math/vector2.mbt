///|
/// A 2D vector.
#derive(Debug, Eq)
pub(all) struct Vector2 {
  mut x : Double
  mut y : Double
}

///|
/// Anything with indexed component getters, such as a future `BufferAttribute`.
pub(open) trait BufferAttributeLike {
  fn get_x(Self, Int32) -> Double
  fn get_y(Self, Int32) -> Double
  fn get_z(Self, Int32) -> Double
  fn get_w(Self, Int32) -> Double
}

///|
/// JS `Math.min`: NaN if either side is NaN, unlike `Double::min`.
extern "js" fn vector_math_min(a : Double, b : Double) -> Double =
  #|(a, b) => Math.min(a, b)

///|
/// JS `Math.max`: NaN if either side is NaN, unlike `Double::max`.
extern "js" fn vector_math_max(a : Double, b : Double) -> Double =
  #|(a, b) => Math.max(a, b)

///|
extern "js" fn vector_math_random() -> Double =
  #|() => Math.random()

///|
/// JS `value || 1` for numbers: both 0 and NaN are falsy.
fn vector_or_one(value : Double) -> Double {
  if value == 0.0 || value.is_nan() {
    1.0
  } else {
    value
  }
}

///|
/// JS `array[index] = value`: grows the array, with NaN standing in for holes.
fn vector_array_set(
  array : Array[Double],
  index : Int32,
  value : Double,
) -> Unit {
  if index < array.length() {
    array[index] = value
  } else {
    while array.length() < index {
      array.push(0.0 / 0.0)
    }
    array.push(value)
  }
}

///|
pub fn Vector2::new(x : Double, y : Double) -> Vector2 {
  { x, y, }
}

///|
pub fn Vector2::width(self : Vector2) -> Double {
  self.x
}

///|
pub fn Vector2::set_width(self : Vector2, value : Double) -> Unit {
  self.x = value
}

///|
pub fn Vector2::height(self : Vector2) -> Double {
  self.y
}

///|
pub fn Vector2::set_height(self : Vector2, value : Double) -> Unit {
  self.y = value
}

///|
pub fn Vector2::set(self : Vector2, x : Double, y : Double) -> Vector2 {
  self.x = x
  self.y = y
  self
}

///|
pub fn Vector2::set_scalar(self : Vector2, scalar : Double) -> Vector2 {
  self.x = scalar
  self.y = scalar
  self
}

///|
pub fn Vector2::set_x(self : Vector2, x : Double) -> Vector2 {
  self.x = x
  self
}

///|
pub fn Vector2::set_y(self : Vector2, y : Double) -> Vector2 {
  self.y = y
  self
}

///|
pub fn Vector2::set_component(
  self : Vector2,
  index : Int32,
  value : Double,
) -> Vector2 {
  match index {
    0 => self.x = value
    1 => self.y = value
    _ => abort("THREE.Vector2: index is out of range: \{index}")
  }
  self
}

///|
pub fn Vector2::get_component(self : Vector2, index : Int32) -> Double {
  match index {
    0 => self.x
    1 => self.y
    _ => abort("THREE.Vector2: index is out of range: \{index}")
  }
}

///|
pub fn Vector2::clone(self : Vector2) -> Vector2 {
  Vector2::new(self.x, self.y)
}

///|
pub fn Vector2::copy(self : Vector2, v : Vector2) -> Vector2 {
  self.x = v.x
  self.y = v.y
  self
}

///|
pub fn Vector2::add(self : Vector2, v : Vector2) -> Vector2 {
  self.x += v.x
  self.y += v.y
  self
}

///|
pub fn Vector2::add_scalar(self : Vector2, s : Double) -> Vector2 {
  self.x += s
  self.y += s
  self
}

///|
pub fn Vector2::add_vectors(
  self : Vector2,
  a : Vector2,
  b : Vector2,
) -> Vector2 {
  self.x = a.x + b.x
  self.y = a.y + b.y
  self
}

///|
pub fn Vector2::add_scaled_vector(
  self : Vector2,
  v : Vector2,
  s : Double,
) -> Vector2 {
  self.x += v.x * s
  self.y += v.y * s
  self
}

///|
pub fn Vector2::sub(self : Vector2, v : Vector2) -> Vector2 {
  self.x -= v.x
  self.y -= v.y
  self
}

///|
pub fn Vector2::sub_scalar(self : Vector2, s : Double) -> Vector2 {
  self.x -= s
  self.y -= s
  self
}

///|
pub fn Vector2::sub_vectors(
  self : Vector2,
  a : Vector2,
  b : Vector2,
) -> Vector2 {
  self.x = a.x - b.x
  self.y = a.y - b.y
  self
}

///|
pub fn Vector2::multiply(self : Vector2, v : Vector2) -> Vector2 {
  self.x *= v.x
  self.y *= v.y
  self
}

///|
pub fn Vector2::multiply_scalar(self : Vector2, scalar : Double) -> Vector2 {
  self.x *= scalar
  self.y *= scalar
  self
}

///|
pub fn Vector2::divide(self : Vector2, v : Vector2) -> Vector2 {
  self.x /= v.x
  self.y /= v.y
  self
}

///|
pub fn Vector2::divide_scalar(self : Vector2, scalar : Double) -> Vector2 {
  self.multiply_scalar(1.0 / scalar)
}

///|
pub fn Vector2::apply_matrix3(self : Vector2, m : Matrix3) -> Vector2 {
  let x = self.x
  let y = self.y
  let e = m.elements
  self.x = e[0] * x + e[3] * y + e[6]
  self.y = e[1] * x + e[4] * y + e[7]
  self
}

///|
pub fn Vector2::min(self : Vector2, v : Vector2) -> Vector2 {
  self.x = vector_math_min(self.x, v.x)
  self.y = vector_math_min(self.y, v.y)
  self
}

///|
pub fn Vector2::max(self : Vector2, v : Vector2) -> Vector2 {
  self.x = vector_math_max(self.x, v.x)
  self.y = vector_math_max(self.y, v.y)
  self
}

///|
pub fn Vector2::clamp(self : Vector2, min : Vector2, max : Vector2) -> Vector2 {
  self.x = clamp(self.x, min.x, max.x)
  self.y = clamp(self.y, min.y, max.y)
  self
}

///|
pub fn Vector2::clamp_scalar(
  self : Vector2,
  min_val : Double,
  max_val : Double,
) -> Vector2 {
  self.x = clamp(self.x, min_val, max_val)
  self.y = clamp(self.y, min_val, max_val)
  self
}

///|
pub fn Vector2::clamp_length(
  self : Vector2,
  min : Double,
  max : Double,
) -> Vector2 {
  let length = self.length()
  self
  .divide_scalar(vector_or_one(length))
  .multiply_scalar(clamp(length, min, max))
}

///|
pub fn Vector2::floor(self : Vector2) -> Vector2 {
  self.x = @cmath.floor(self.x)
  self.y = @cmath.floor(self.y)
  self
}

///|
pub fn Vector2::ceil(self : Vector2) -> Vector2 {
  self.x = @cmath.ceil(self.x)
  self.y = @cmath.ceil(self.y)
  self
}

///|
pub fn Vector2::round(self : Vector2) -> Vector2 {
  self.x = @cmath.round(self.x)
  self.y = @cmath.round(self.y)
  self
}

///|
pub fn Vector2::round_to_zero(self : Vector2) -> Vector2 {
  self.x = @cmath.trunc(self.x)
  self.y = @cmath.trunc(self.y)
  self
}

///|
pub fn Vector2::negate(self : Vector2) -> Vector2 {
  self.x = -self.x
  self.y = -self.y
  self
}

///|
pub fn Vector2::dot(self : Vector2, v : Vector2) -> Double {
  self.x * v.x + self.y * v.y
}

///|
pub fn Vector2::cross(self : Vector2, v : Vector2) -> Double {
  self.x * v.y - self.y * v.x
}

///|
pub fn Vector2::length_sq(self : Vector2) -> Double {
  self.x * self.x + self.y * self.y
}

///|
pub fn Vector2::length(self : Vector2) -> Double {
  (self.x * self.x + self.y * self.y).sqrt()
}

///|
pub fn Vector2::manhattan_length(self : Vector2) -> Double {
  self.x.abs() + self.y.abs()
}

///|
pub fn Vector2::normalize(self : Vector2) -> Vector2 {
  self.divide_scalar(vector_or_one(self.length()))
}

///|
pub fn Vector2::angle(self : Vector2) -> Double {
  @cmath.atan2(-self.y, -self.x) + @cmath.PI
}

///|
pub fn Vector2::angle_to(self : Vector2, v : Vector2) -> Double {
  let denominator = (self.length_sq() * v.length_sq()).sqrt()
  if denominator == 0.0 {
    return @cmath.PI / 2.0
  }
  let theta = self.dot(v) / denominator
  // clamp, to handle numerical problems
  @cmath.acos(clamp(theta, -1.0, 1.0))
}

///|
pub fn Vector2::distance_to(self : Vector2, v : Vector2) -> Double {
  self.distance_to_squared(v).sqrt()
}

///|
pub fn Vector2::distance_to_squared(self : Vector2, v : Vector2) -> Double {
  let dx = self.x - v.x
  let dy = self.y - v.y
  dx * dx + dy * dy
}

///|
pub fn Vector2::manhattan_distance_to(self : Vector2, v : Vector2) -> Double {
  (self.x - v.x).abs() + (self.y - v.y).abs()
}

///|
pub fn Vector2::set_length(self : Vector2, length : Double) -> Vector2 {
  self.normalize().multiply_scalar(length)
}

///|
pub fn Vector2::lerp(self : Vector2, v : Vector2, alpha : Double) -> Vector2 {
  self.x += (v.x - self.x) * alpha
  self.y += (v.y - self.y) * alpha
  self
}

///|
pub fn Vector2::lerp_vectors(
  self : Vector2,
  v1 : Vector2,
  v2 : Vector2,
  alpha : Double,
) -> Vector2 {
  self.x = v1.x + (v2.x - v1.x) * alpha
  self.y = v1.y + (v2.y - v1.y) * alpha
  self
}

///|
pub fn Vector2::equals(self : Vector2, v : Vector2) -> Bool {
  v.x == self.x && v.y == self.y
}

///|
pub fn Vector2::from_array(
  self : Vector2,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Vector2 {
  self.x = array[offset]
  self.y = array[offset + 1]
  self
}

///|
pub fn Vector2::to_array(
  self : Vector2,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  vector_array_set(array, offset, self.x)
  vector_array_set(array, offset + 1, self.y)
  array
}

///|
pub fn[A : BufferAttributeLike] Vector2::from_buffer_attribute(
  self : Vector2,
  attribute : A,
  index : Int32,
) -> Vector2 {
  self.x = attribute.get_x(index)
  self.y = attribute.get_y(index)
  self
}

///|
pub fn Vector2::rotate_around(
  self : Vector2,
  center : Vector2,
  angle : Double,
) -> Vector2 {
  let c = @cmath.cos(angle)
  let s = @cmath.sin(angle)
  let x = self.x - center.x
  let y = self.y - center.y
  self.x = x * c - y * s + center.x
  self.y = x * s + y * c + center.y
  self
}

///|
pub fn Vector2::random(self : Vector2) -> Vector2 {
  self.x = vector_math_random()
  self.y = vector_math_random()
  self
}
