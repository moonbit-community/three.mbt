///|
/// A 3D vector.
#derive(Debug, Eq)
pub(all) struct Vector3 {
  mut x : Double
  mut y : Double
  mut z : Double
}

///|
/// The matrices `project` and `unproject` read from a camera.
pub(open) trait CameraMatrices {
  fn matrix_world(Self) -> Matrix4
  fn matrix_world_inverse(Self) -> Matrix4
  fn projection_matrix(Self) -> Matrix4
  fn projection_matrix_inverse(Self) -> Matrix4
}

///|
let _vector3_vector : Vector3 = Vector3::new(0.0, 0.0, 0.0)

///|
let _vector3_quaternion : Quaternion = Quaternion::new(0.0, 0.0, 0.0, 1.0)

///|
pub fn Vector3::new(x : Double, y : Double, z : Double) -> Vector3 {
  { x, y, z, }
}

///|
pub fn Vector3::set(
  self : Vector3,
  x : Double,
  y : Double,
  z : Double,
) -> Vector3 {
  self.x = x
  self.y = y
  self.z = z
  self
}

///|
/// Upstream `set( x, y )`, which leaves z alone.
pub fn Vector3::set_xy(self : Vector3, x : Double, y : Double) -> Vector3 {
  self.x = x
  self.y = y
  self
}

///|
pub fn Vector3::set_scalar(self : Vector3, scalar : Double) -> Vector3 {
  self.x = scalar
  self.y = scalar
  self.z = scalar
  self
}

///|
pub fn Vector3::set_x(self : Vector3, x : Double) -> Vector3 {
  self.x = x
  self
}

///|
pub fn Vector3::set_y(self : Vector3, y : Double) -> Vector3 {
  self.y = y
  self
}

///|
pub fn Vector3::set_z(self : Vector3, z : Double) -> Vector3 {
  self.z = z
  self
}

///|
pub fn Vector3::set_component(
  self : Vector3,
  index : Int32,
  value : Double,
) -> Vector3 {
  match index {
    0 => self.x = value
    1 => self.y = value
    2 => self.z = value
    _ => abort("THREE.Vector3: index is out of range: \{index}")
  }
  self
}

///|
pub fn Vector3::get_component(self : Vector3, index : Int32) -> Double {
  match index {
    0 => self.x
    1 => self.y
    2 => self.z
    _ => abort("THREE.Vector3: index is out of range: \{index}")
  }
}

///|
pub fn Vector3::clone(self : Vector3) -> Vector3 {
  Vector3::new(self.x, self.y, self.z)
}

///|
pub fn Vector3::copy(self : Vector3, v : Vector3) -> Vector3 {
  self.x = v.x
  self.y = v.y
  self.z = v.z
  self
}

///|
pub fn Vector3::add(self : Vector3, v : Vector3) -> Vector3 {
  self.x += v.x
  self.y += v.y
  self.z += v.z
  self
}

///|
pub fn Vector3::add_scalar(self : Vector3, s : Double) -> Vector3 {
  self.x += s
  self.y += s
  self.z += s
  self
}

///|
pub fn Vector3::add_vectors(
  self : Vector3,
  a : Vector3,
  b : Vector3,
) -> Vector3 {
  self.x = a.x + b.x
  self.y = a.y + b.y
  self.z = a.z + b.z
  self
}

///|
pub fn Vector3::add_scaled_vector(
  self : Vector3,
  v : Vector3,
  s : Double,
) -> Vector3 {
  self.x += v.x * s
  self.y += v.y * s
  self.z += v.z * s
  self
}

///|
/// Upstream `addScaledVector` given a `Vector4`.
pub fn Vector3::add_scaled_vector4(
  self : Vector3,
  v : Vector4,
  s : Double,
) -> Vector3 {
  self.x += v.x * s
  self.y += v.y * s
  self.z += v.z * s
  self
}

///|
pub fn Vector3::sub(self : Vector3, v : Vector3) -> Vector3 {
  self.x -= v.x
  self.y -= v.y
  self.z -= v.z
  self
}

///|
pub fn Vector3::sub_scalar(self : Vector3, s : Double) -> Vector3 {
  self.x -= s
  self.y -= s
  self.z -= s
  self
}

///|
pub fn Vector3::sub_vectors(
  self : Vector3,
  a : Vector3,
  b : Vector3,
) -> Vector3 {
  self.x = a.x - b.x
  self.y = a.y - b.y
  self.z = a.z - b.z
  self
}

///|
pub fn Vector3::multiply(self : Vector3, v : Vector3) -> Vector3 {
  self.x *= v.x
  self.y *= v.y
  self.z *= v.z
  self
}

///|
pub fn Vector3::multiply_scalar(self : Vector3, scalar : Double) -> Vector3 {
  self.x *= scalar
  self.y *= scalar
  self.z *= scalar
  self
}

///|
pub fn Vector3::multiply_vectors(
  self : Vector3,
  a : Vector3,
  b : Vector3,
) -> Vector3 {
  self.x = a.x * b.x
  self.y = a.y * b.y
  self.z = a.z * b.z
  self
}

///|
pub fn Vector3::apply_euler(self : Vector3, euler : Euler) -> Vector3 {
  self.apply_quaternion(_vector3_quaternion.set_from_euler(euler))
}

///|
pub fn Vector3::apply_axis_angle(
  self : Vector3,
  axis : Vector3,
  angle : Double,
) -> Vector3 {
  self.apply_quaternion(_vector3_quaternion.set_from_axis_angle(axis, angle))
}

///|
pub fn Vector3::apply_matrix3(self : Vector3, m : Matrix3) -> Vector3 {
  let x = self.x
  let y = self.y
  let z = self.z
  let e = m.elements
  self.x = e[0] * x + e[3] * y + e[6] * z
  self.y = e[1] * x + e[4] * y + e[7] * z
  self.z = e[2] * x + e[5] * y + e[8] * z
  self
}

///|
pub fn Vector3::apply_normal_matrix(self : Vector3, m : Matrix3) -> Vector3 {
  self.apply_matrix3(m).normalize()
}

///|
pub fn Vector3::apply_matrix4(self : Vector3, m : Matrix4) -> Vector3 {
  let x = self.x
  let y = self.y
  let z = self.z
  let e = m.elements
  let w = 1.0 / (e[3] * x + e[7] * y + e[11] * z + e[15])
  self.x = (e[0] * x + e[4] * y + e[8] * z + e[12]) * w
  self.y = (e[1] * x + e[5] * y + e[9] * z + e[13]) * w
  self.z = (e[2] * x + e[6] * y + e[10] * z + e[14]) * w
  self
}

///|
pub fn Vector3::apply_quaternion(self : Vector3, q : Quaternion) -> Vector3 {
  // quaternion q is assumed to have unit length
  let vx = self.x
  let vy = self.y
  let vz = self.z
  let qx = q.x
  let qy = q.y
  let qz = q.z
  let qw = q.w
  // t = 2 * cross( q.xyz, v );
  let tx = 2.0 * (qy * vz - qz * vy)
  let ty = 2.0 * (qz * vx - qx * vz)
  let tz = 2.0 * (qx * vy - qy * vx)
  // v + q.w * t + cross( q.xyz, t );
  self.x = vx + qw * tx + qy * tz - qz * ty
  self.y = vy + qw * ty + qz * tx - qx * tz
  self.z = vz + qw * tz + qx * ty - qy * tx
  self
}

///|
pub fn[C : CameraMatrices] Vector3::project(
  self : Vector3,
  camera : C,
) -> Vector3 {
  self
  .apply_matrix4(camera.matrix_world_inverse())
  .apply_matrix4(camera.projection_matrix())
}

///|
pub fn[C : CameraMatrices] Vector3::unproject(
  self : Vector3,
  camera : C,
) -> Vector3 {
  self
  .apply_matrix4(camera.projection_matrix_inverse())
  .apply_matrix4(camera.matrix_world())
}

///|
pub fn Vector3::transform_direction(self : Vector3, m : Matrix4) -> Vector3 {
  // input: THREE.Matrix4 affine matrix
  // vector interpreted as a direction
  let x = self.x
  let y = self.y
  let z = self.z
  let e = m.elements
  self.x = e[0] * x + e[4] * y + e[8] * z
  self.y = e[1] * x + e[5] * y + e[9] * z
  self.z = e[2] * x + e[6] * y + e[10] * z
  self.normalize()
}

///|
pub fn Vector3::divide(self : Vector3, v : Vector3) -> Vector3 {
  self.x /= v.x
  self.y /= v.y
  self.z /= v.z
  self
}

///|
pub fn Vector3::divide_scalar(self : Vector3, scalar : Double) -> Vector3 {
  self.multiply_scalar(1.0 / scalar)
}

///|
pub fn Vector3::min(self : Vector3, v : Vector3) -> Vector3 {
  self.x = vector_math_min(self.x, v.x)
  self.y = vector_math_min(self.y, v.y)
  self.z = vector_math_min(self.z, v.z)
  self
}

///|
pub fn Vector3::max(self : Vector3, v : Vector3) -> Vector3 {
  self.x = vector_math_max(self.x, v.x)
  self.y = vector_math_max(self.y, v.y)
  self.z = vector_math_max(self.z, v.z)
  self
}

///|
pub fn Vector3::clamp(self : Vector3, min : Vector3, max : Vector3) -> Vector3 {
  self.x = clamp(self.x, min.x, max.x)
  self.y = clamp(self.y, min.y, max.y)
  self.z = clamp(self.z, min.z, max.z)
  self
}

///|
pub fn Vector3::clamp_scalar(
  self : Vector3,
  min_val : Double,
  max_val : Double,
) -> Vector3 {
  self.x = clamp(self.x, min_val, max_val)
  self.y = clamp(self.y, min_val, max_val)
  self.z = clamp(self.z, min_val, max_val)
  self
}

///|
pub fn Vector3::clamp_length(
  self : Vector3,
  min : Double,
  max : Double,
) -> Vector3 {
  let length = self.length()
  self
  .divide_scalar(vector_or_one(length))
  .multiply_scalar(clamp(length, min, max))
}

///|
pub fn Vector3::floor(self : Vector3) -> Vector3 {
  self.x = @cmath.floor(self.x)
  self.y = @cmath.floor(self.y)
  self.z = @cmath.floor(self.z)
  self
}

///|
pub fn Vector3::ceil(self : Vector3) -> Vector3 {
  self.x = @cmath.ceil(self.x)
  self.y = @cmath.ceil(self.y)
  self.z = @cmath.ceil(self.z)
  self
}

///|
pub fn Vector3::round(self : Vector3) -> Vector3 {
  self.x = @cmath.round(self.x)
  self.y = @cmath.round(self.y)
  self.z = @cmath.round(self.z)
  self
}

///|
pub fn Vector3::round_to_zero(self : Vector3) -> Vector3 {
  self.x = @cmath.trunc(self.x)
  self.y = @cmath.trunc(self.y)
  self.z = @cmath.trunc(self.z)
  self
}

///|
pub fn Vector3::negate(self : Vector3) -> Vector3 {
  self.x = -self.x
  self.y = -self.y
  self.z = -self.z
  self
}

///|
pub fn Vector3::dot(self : Vector3, v : Vector3) -> Double {
  self.x * v.x + self.y * v.y + self.z * v.z
}

///|
pub fn Vector3::length_sq(self : Vector3) -> Double {
  self.x * self.x + self.y * self.y + self.z * self.z
}

///|
pub fn Vector3::length(self : Vector3) -> Double {
  (self.x * self.x + self.y * self.y + self.z * self.z).sqrt()
}

///|
pub fn Vector3::manhattan_length(self : Vector3) -> Double {
  self.x.abs() + self.y.abs() + self.z.abs()
}

///|
pub fn Vector3::normalize(self : Vector3) -> Vector3 {
  self.divide_scalar(vector_or_one(self.length()))
}

///|
pub fn Vector3::set_length(self : Vector3, length : Double) -> Vector3 {
  self.normalize().multiply_scalar(length)
}

///|
pub fn Vector3::lerp(self : Vector3, v : Vector3, alpha : Double) -> Vector3 {
  self.x += (v.x - self.x) * alpha
  self.y += (v.y - self.y) * alpha
  self.z += (v.z - self.z) * alpha
  self
}

///|
pub fn Vector3::lerp_vectors(
  self : Vector3,
  v1 : Vector3,
  v2 : Vector3,
  alpha : Double,
) -> Vector3 {
  self.x = v1.x + (v2.x - v1.x) * alpha
  self.y = v1.y + (v2.y - v1.y) * alpha
  self.z = v1.z + (v2.z - v1.z) * alpha
  self
}

///|
pub fn Vector3::cross(self : Vector3, v : Vector3) -> Vector3 {
  self.cross_vectors(self, v)
}

///|
pub fn Vector3::cross_vectors(
  self : Vector3,
  a : Vector3,
  b : Vector3,
) -> Vector3 {
  let ax = a.x
  let ay = a.y
  let az = a.z
  let bx = b.x
  let by_ = b.y
  let bz = b.z
  self.x = ay * bz - az * by_
  self.y = az * bx - ax * bz
  self.z = ax * by_ - ay * bx
  self
}

///|
pub fn Vector3::project_on_vector(self : Vector3, v : Vector3) -> Vector3 {
  let denominator = v.length_sq()
  if denominator == 0.0 {
    return self.set(0.0, 0.0, 0.0)
  }
  let scalar = v.dot(self) / denominator
  self.copy(v).multiply_scalar(scalar)
}

///|
pub fn Vector3::project_on_plane(
  self : Vector3,
  plane_normal : Vector3,
) -> Vector3 {
  _vector3_vector.copy(self).project_on_vector(plane_normal) |> ignore
  self.sub(_vector3_vector)
}

///|
pub fn Vector3::reflect(self : Vector3, normal : Vector3) -> Vector3 {
  self.sub(_vector3_vector.copy(normal).multiply_scalar(2.0 * self.dot(normal)))
}

///|
pub fn Vector3::angle_to(self : Vector3, v : Vector3) -> Double {
  let denominator = (self.length_sq() * v.length_sq()).sqrt()
  if denominator == 0.0 {
    return @cmath.PI / 2.0
  }
  let theta = self.dot(v) / denominator
  // clamp, to handle numerical problems
  @cmath.acos(clamp(theta, -1.0, 1.0))
}

///|
pub fn Vector3::distance_to(self : Vector3, v : Vector3) -> Double {
  self.distance_to_squared(v).sqrt()
}

///|
pub fn Vector3::distance_to_squared(self : Vector3, v : Vector3) -> Double {
  let dx = self.x - v.x
  let dy = self.y - v.y
  let dz = self.z - v.z
  dx * dx + dy * dy + dz * dz
}

///|
pub fn Vector3::manhattan_distance_to(self : Vector3, v : Vector3) -> Double {
  (self.x - v.x).abs() + (self.y - v.y).abs() + (self.z - v.z).abs()
}

///|
pub fn Vector3::set_from_spherical(self : Vector3, s : Spherical) -> Vector3 {
  self.set_from_spherical_coords(s.radius, s.phi, s.theta)
}

///|
pub fn Vector3::set_from_spherical_coords(
  self : Vector3,
  radius : Double,
  phi : Double,
  theta : Double,
) -> Vector3 {
  let sin_phi_radius = @cmath.sin(phi) * radius
  self.x = sin_phi_radius * @cmath.sin(theta)
  self.y = @cmath.cos(phi) * radius
  self.z = sin_phi_radius * @cmath.cos(theta)
  self
}

///|
pub fn Vector3::set_from_cylindrical(
  self : Vector3,
  c : Cylindrical,
) -> Vector3 {
  self.set_from_cylindrical_coords(c.radius, c.theta, c.y)
}

///|
pub fn Vector3::set_from_cylindrical_coords(
  self : Vector3,
  radius : Double,
  theta : Double,
  y : Double,
) -> Vector3 {
  self.x = radius * @cmath.sin(theta)
  self.y = y
  self.z = radius * @cmath.cos(theta)
  self
}

///|
pub fn Vector3::set_from_matrix_position(
  self : Vector3,
  m : Matrix4,
) -> Vector3 {
  let e = m.elements
  self.x = e[12]
  self.y = e[13]
  self.z = e[14]
  self
}

///|
pub fn Vector3::set_from_matrix_scale(self : Vector3, m : Matrix4) -> Vector3 {
  let sx = self.set_from_matrix_column(m, 0).length()
  let sy = self.set_from_matrix_column(m, 1).length()
  let sz = self.set_from_matrix_column(m, 2).length()
  self.x = sx
  self.y = sy
  self.z = sz
  self
}

///|
pub fn Vector3::set_from_matrix_column(
  self : Vector3,
  m : Matrix4,
  index : Int32,
) -> Vector3 {
  self.from_array(m.elements, offset=index * 4)
}

///|
pub fn Vector3::set_from_matrix3_column(
  self : Vector3,
  m : Matrix3,
  index : Int32,
) -> Vector3 {
  self.from_array(m.elements, offset=index * 3)
}

///|
pub fn Vector3::set_from_euler(self : Vector3, e : Euler) -> Vector3 {
  self.x = e.x
  self.y = e.y
  self.z = e.z
  self
}

///|
pub fn Vector3::set_from_color(self : Vector3, c : Color) -> Vector3 {
  self.x = c.r
  self.y = c.g
  self.z = c.b
  self
}

///|
pub fn Vector3::equals(self : Vector3, v : Vector3) -> Bool {
  v.x == self.x && v.y == self.y && v.z == self.z
}

///|
pub fn Vector3::from_array(
  self : Vector3,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Vector3 {
  self.x = array[offset]
  self.y = array[offset + 1]
  self.z = array[offset + 2]
  self
}

///|
pub fn Vector3::to_array(
  self : Vector3,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  vector_array_set(array, offset, self.x)
  vector_array_set(array, offset + 1, self.y)
  vector_array_set(array, offset + 2, self.z)
  array
}

///|
pub fn[A : BufferAttributeLike] Vector3::from_buffer_attribute(
  self : Vector3,
  attribute : A,
  index : Int32,
) -> Vector3 {
  self.x = attribute.get_x(index)
  self.y = attribute.get_y(index)
  self.z = attribute.get_z(index)
  self
}

///|
pub fn Vector3::random(self : Vector3) -> Vector3 {
  self.x = vector_math_random()
  self.y = vector_math_random()
  self.z = vector_math_random()
  self
}

///|
pub fn Vector3::random_direction(self : Vector3) -> Vector3 {
  // https://mathworld.wolfram.com/SpherePointPicking.html
  let theta = vector_math_random() * @cmath.PI * 2.0
  let u = vector_math_random() * 2.0 - 1.0
  let c = (1.0 - u * u).sqrt()
  self.x = c * @cmath.cos(theta)
  self.y = u
  self.z = c * @cmath.sin(theta)
  self
}
