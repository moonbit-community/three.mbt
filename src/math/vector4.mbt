///|
/// A 4D vector.
#derive(Debug, Eq)
pub(all) struct Vector4 {
  mut x : Double
  mut y : Double
  mut z : Double
  mut w : Double
}

///|
pub fn Vector4::new(x : Double, y : Double, z : Double, w : Double) -> Vector4 {
  { x, y, z, w, }
}

///|
pub fn Vector4::width(self : Vector4) -> Double {
  self.z
}

///|
pub fn Vector4::set_width(self : Vector4, value : Double) -> Unit {
  self.z = value
}

///|
pub fn Vector4::height(self : Vector4) -> Double {
  self.w
}

///|
pub fn Vector4::set_height(self : Vector4, value : Double) -> Unit {
  self.w = value
}

///|
pub fn Vector4::set(
  self : Vector4,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Vector4 {
  self.x = x
  self.y = y
  self.z = z
  self.w = w
  self
}

///|
pub fn Vector4::set_scalar(self : Vector4, scalar : Double) -> Vector4 {
  self.x = scalar
  self.y = scalar
  self.z = scalar
  self.w = scalar
  self
}

///|
pub fn Vector4::set_x(self : Vector4, x : Double) -> Vector4 {
  self.x = x
  self
}

///|
pub fn Vector4::set_y(self : Vector4, y : Double) -> Vector4 {
  self.y = y
  self
}

///|
pub fn Vector4::set_z(self : Vector4, z : Double) -> Vector4 {
  self.z = z
  self
}

///|
pub fn Vector4::set_w(self : Vector4, w : Double) -> Vector4 {
  self.w = w
  self
}

///|
pub fn Vector4::set_component(
  self : Vector4,
  index : Int32,
  value : Double,
) -> Vector4 {
  match index {
    0 => self.x = value
    1 => self.y = value
    2 => self.z = value
    3 => self.w = value
    _ => abort("THREE.Vector4: index is out of range: \{index}")
  }
  self
}

///|
pub fn Vector4::get_component(self : Vector4, index : Int32) -> Double {
  match index {
    0 => self.x
    1 => self.y
    2 => self.z
    3 => self.w
    _ => abort("THREE.Vector4: index is out of range: \{index}")
  }
}

///|
pub fn Vector4::clone(self : Vector4) -> Vector4 {
  Vector4::new(self.x, self.y, self.z, self.w)
}

///|
pub fn Vector4::copy(self : Vector4, v : Vector4) -> Vector4 {
  self.x = v.x
  self.y = v.y
  self.z = v.z
  self.w = v.w
  self
}

///|
/// Upstream `copy` given a `Vector3`: w becomes 1.
pub fn Vector4::copy_vector3(self : Vector4, v : Vector3) -> Vector4 {
  self.x = v.x
  self.y = v.y
  self.z = v.z
  self.w = 1.0
  self
}

///|
pub fn Vector4::add(self : Vector4, v : Vector4) -> Vector4 {
  self.x += v.x
  self.y += v.y
  self.z += v.z
  self.w += v.w
  self
}

///|
pub fn Vector4::add_scalar(self : Vector4, s : Double) -> Vector4 {
  self.x += s
  self.y += s
  self.z += s
  self.w += s
  self
}

///|
pub fn Vector4::add_vectors(
  self : Vector4,
  a : Vector4,
  b : Vector4,
) -> Vector4 {
  self.x = a.x + b.x
  self.y = a.y + b.y
  self.z = a.z + b.z
  self.w = a.w + b.w
  self
}

///|
pub fn Vector4::add_scaled_vector(
  self : Vector4,
  v : Vector4,
  s : Double,
) -> Vector4 {
  self.x += v.x * s
  self.y += v.y * s
  self.z += v.z * s
  self.w += v.w * s
  self
}

///|
pub fn Vector4::sub(self : Vector4, v : Vector4) -> Vector4 {
  self.x -= v.x
  self.y -= v.y
  self.z -= v.z
  self.w -= v.w
  self
}

///|
pub fn Vector4::sub_scalar(self : Vector4, s : Double) -> Vector4 {
  self.x -= s
  self.y -= s
  self.z -= s
  self.w -= s
  self
}

///|
pub fn Vector4::sub_vectors(
  self : Vector4,
  a : Vector4,
  b : Vector4,
) -> Vector4 {
  self.x = a.x - b.x
  self.y = a.y - b.y
  self.z = a.z - b.z
  self.w = a.w - b.w
  self
}

///|
pub fn Vector4::multiply(self : Vector4, v : Vector4) -> Vector4 {
  self.x *= v.x
  self.y *= v.y
  self.z *= v.z
  self.w *= v.w
  self
}

///|
pub fn Vector4::multiply_scalar(self : Vector4, scalar : Double) -> Vector4 {
  self.x *= scalar
  self.y *= scalar
  self.z *= scalar
  self.w *= scalar
  self
}

///|
pub fn Vector4::apply_matrix4(self : Vector4, m : Matrix4) -> Vector4 {
  let x = self.x
  let y = self.y
  let z = self.z
  let w = self.w
  let e = m.elements
  self.x = e[0] * x + e[4] * y + e[8] * z + e[12] * w
  self.y = e[1] * x + e[5] * y + e[9] * z + e[13] * w
  self.z = e[2] * x + e[6] * y + e[10] * z + e[14] * w
  self.w = e[3] * x + e[7] * y + e[11] * z + e[15] * w
  self
}

///|
pub fn Vector4::divide(self : Vector4, v : Vector4) -> Vector4 {
  self.x /= v.x
  self.y /= v.y
  self.z /= v.z
  self.w /= v.w
  self
}

///|
pub fn Vector4::divide_scalar(self : Vector4, scalar : Double) -> Vector4 {
  self.multiply_scalar(1.0 / scalar)
}

///|
pub fn Vector4::set_axis_angle_from_quaternion(
  self : Vector4,
  q : Quaternion,
) -> Vector4 {
  // q is assumed to be normalized
  self.w = 2.0 * @cmath.acos(q.w)
  let s = (1.0 - q.w * q.w).sqrt()
  if s < 0.0001 {
    self.x = 1.0
    self.y = 0.0
    self.z = 0.0
  } else {
    self.x = q.x / s
    self.y = q.y / s
    self.z = q.z / s
  }
  self
}

///|
pub fn Vector4::set_axis_angle_from_rotation_matrix(
  self : Vector4,
  m : Matrix4,
) -> Vector4 {
  // assumes the upper 3x3 of m is a pure rotation matrix (i.e, unscaled)
  let epsilon = 0.01 // margin to allow for rounding errors
  let epsilon2 = 0.1 // margin to distinguish between 0 and 180 degrees
  let te = m.elements
  let m11 = te[0]
  let m12 = te[4]
  let m13 = te[8]
  let m21 = te[1]
  let m22 = te[5]
  let m23 = te[9]
  let m31 = te[2]
  let m32 = te[6]
  let m33 = te[10]
  if (m12 - m21).abs() < epsilon &&
    (m13 - m31).abs() < epsilon &&
    (m23 - m32).abs() < epsilon {
    // singularity found
    // first check for identity matrix which must have +1 for all terms
    // in leading diagonal and zero in other terms
    if (m12 + m21).abs() < epsilon2 &&
      (m13 + m31).abs() < epsilon2 &&
      (m23 + m32).abs() < epsilon2 &&
      (m11 + m22 + m33 - 3.0).abs() < epsilon2 {
      // this singularity is identity matrix so angle = 0
      return self.set(1.0, 0.0, 0.0, 0.0) // zero angle, arbitrary axis
    }
    // otherwise this singularity is angle = 180
    let angle = @cmath.PI
    let xx = (m11 + 1.0) / 2.0
    let yy = (m22 + 1.0) / 2.0
    let zz = (m33 + 1.0) / 2.0
    let xy = (m12 + m21) / 4.0
    let xz = (m13 + m31) / 4.0
    let yz = (m23 + m32) / 4.0
    let (x, y, z) = if xx > yy && xx > zz {
      // m11 is the largest diagonal term
      if xx < epsilon {
        (0.0, 0.707106781, 0.707106781)
      } else {
        let x = xx.sqrt()
        (x, xy / x, xz / x)
      }
    } else if yy > zz {
      // m22 is the largest diagonal term
      if yy < epsilon {
        (0.707106781, 0.0, 0.707106781)
      } else {
        let y = yy.sqrt()
        (xy / y, y, yz / y)
      }
    } else if zz < epsilon {
      // m33 is the largest diagonal term so base result on this
      (0.707106781, 0.707106781, 0.0)
    } else {
      let z = zz.sqrt()
      (xz / z, yz / z, z)
    }
    return self.set(x, y, z, angle) // return 180 deg rotation
  }
  // as we have reached here there are no singularities so we can handle normally
  let mut s = ((m32 - m23) * (m32 - m23) +
  (m13 - m31) * (m13 - m31) +
  (m21 - m12) * (m21 - m12)).sqrt() // used to normalize
  if s.abs() < 0.001 {
    s = 1.0
  }
  // prevent divide by zero, should not happen if matrix is orthogonal and should be
  // caught by singularity test above, but I've left it in just in case
  self.x = (m32 - m23) / s
  self.y = (m13 - m31) / s
  self.z = (m21 - m12) / s
  self.w = @cmath.acos((m11 + m22 + m33 - 1.0) / 2.0)
  self
}

///|
pub fn Vector4::set_from_matrix_position(
  self : Vector4,
  m : Matrix4,
) -> Vector4 {
  let e = m.elements
  self.x = e[12]
  self.y = e[13]
  self.z = e[14]
  self.w = e[15]
  self
}

///|
pub fn Vector4::min(self : Vector4, v : Vector4) -> Vector4 {
  self.x = vector_math_min(self.x, v.x)
  self.y = vector_math_min(self.y, v.y)
  self.z = vector_math_min(self.z, v.z)
  self.w = vector_math_min(self.w, v.w)
  self
}

///|
pub fn Vector4::max(self : Vector4, v : Vector4) -> Vector4 {
  self.x = vector_math_max(self.x, v.x)
  self.y = vector_math_max(self.y, v.y)
  self.z = vector_math_max(self.z, v.z)
  self.w = vector_math_max(self.w, v.w)
  self
}

///|
pub fn Vector4::clamp(self : Vector4, min : Vector4, max : Vector4) -> Vector4 {
  self.x = clamp(self.x, min.x, max.x)
  self.y = clamp(self.y, min.y, max.y)
  self.z = clamp(self.z, min.z, max.z)
  self.w = clamp(self.w, min.w, max.w)
  self
}

///|
pub fn Vector4::clamp_scalar(
  self : Vector4,
  min_val : Double,
  max_val : Double,
) -> Vector4 {
  self.x = clamp(self.x, min_val, max_val)
  self.y = clamp(self.y, min_val, max_val)
  self.z = clamp(self.z, min_val, max_val)
  self.w = clamp(self.w, min_val, max_val)
  self
}

///|
pub fn Vector4::clamp_length(
  self : Vector4,
  min : Double,
  max : Double,
) -> Vector4 {
  let length = self.length()
  self
  .divide_scalar(vector_or_one(length))
  .multiply_scalar(clamp(length, min, max))
}

///|
pub fn Vector4::floor(self : Vector4) -> Vector4 {
  self.x = @cmath.floor(self.x)
  self.y = @cmath.floor(self.y)
  self.z = @cmath.floor(self.z)
  self.w = @cmath.floor(self.w)
  self
}

///|
pub fn Vector4::ceil(self : Vector4) -> Vector4 {
  self.x = @cmath.ceil(self.x)
  self.y = @cmath.ceil(self.y)
  self.z = @cmath.ceil(self.z)
  self.w = @cmath.ceil(self.w)
  self
}

///|
pub fn Vector4::round(self : Vector4) -> Vector4 {
  self.x = @cmath.round(self.x)
  self.y = @cmath.round(self.y)
  self.z = @cmath.round(self.z)
  self.w = @cmath.round(self.w)
  self
}

///|
pub fn Vector4::round_to_zero(self : Vector4) -> Vector4 {
  self.x = @cmath.trunc(self.x)
  self.y = @cmath.trunc(self.y)
  self.z = @cmath.trunc(self.z)
  self.w = @cmath.trunc(self.w)
  self
}

///|
pub fn Vector4::negate(self : Vector4) -> Vector4 {
  self.x = -self.x
  self.y = -self.y
  self.z = -self.z
  self.w = -self.w
  self
}

///|
pub fn Vector4::dot(self : Vector4, v : Vector4) -> Double {
  self.x * v.x + self.y * v.y + self.z * v.z + self.w * v.w
}

///|
pub fn Vector4::length_sq(self : Vector4) -> Double {
  self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
}

///|
pub fn Vector4::length(self : Vector4) -> Double {
  (self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w).sqrt()
}

///|
pub fn Vector4::manhattan_length(self : Vector4) -> Double {
  self.x.abs() + self.y.abs() + self.z.abs() + self.w.abs()
}

///|
pub fn Vector4::normalize(self : Vector4) -> Vector4 {
  self.divide_scalar(vector_or_one(self.length()))
}

///|
pub fn Vector4::set_length(self : Vector4, length : Double) -> Vector4 {
  self.normalize().multiply_scalar(length)
}

///|
pub fn Vector4::lerp(self : Vector4, v : Vector4, alpha : Double) -> Vector4 {
  self.x += (v.x - self.x) * alpha
  self.y += (v.y - self.y) * alpha
  self.z += (v.z - self.z) * alpha
  self.w += (v.w - self.w) * alpha
  self
}

///|
pub fn Vector4::lerp_vectors(
  self : Vector4,
  v1 : Vector4,
  v2 : Vector4,
  alpha : Double,
) -> Vector4 {
  self.x = v1.x + (v2.x - v1.x) * alpha
  self.y = v1.y + (v2.y - v1.y) * alpha
  self.z = v1.z + (v2.z - v1.z) * alpha
  self.w = v1.w + (v2.w - v1.w) * alpha
  self
}

///|
pub fn Vector4::equals(self : Vector4, v : Vector4) -> Bool {
  v.x == self.x && v.y == self.y && v.z == self.z && v.w == self.w
}

///|
pub fn Vector4::from_array(
  self : Vector4,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Vector4 {
  self.x = array[offset]
  self.y = array[offset + 1]
  self.z = array[offset + 2]
  self.w = array[offset + 3]
  self
}

///|
pub fn Vector4::to_array(
  self : Vector4,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  vector_array_set(array, offset, self.x)
  vector_array_set(array, offset + 1, self.y)
  vector_array_set(array, offset + 2, self.z)
  vector_array_set(array, offset + 3, self.w)
  array
}

///|
pub fn[A : BufferAttributeLike] Vector4::from_buffer_attribute(
  self : Vector4,
  attribute : A,
  index : Int32,
) -> Vector4 {
  self.x = attribute.get_x(index)
  self.y = attribute.get_y(index)
  self.z = attribute.get_z(index)
  self.w = attribute.get_w(index)
  self
}

///|
pub fn Vector4::random(self : Vector4) -> Vector4 {
  self.x = vector_math_random()
  self.y = vector_math_random()
  self.z = vector_math_random()
  self.w = vector_math_random()
  self
}
