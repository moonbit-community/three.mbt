///|
/// A quaternion. Fields are read-only outside this package: write through
/// `set_x`, `set_y`, `set_z`, `set_w` so the change callback fires.
pub struct Quaternion {
  mut x : Double
  mut y : Double
  mut z : Double
  mut w : Double
  mut on_change_callback : () -> Unit
}

///|
/// Constructs a quaternion; upstream's default is `(0, 0, 0, 1)`.
pub fn Quaternion::new(
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Quaternion {
  { x, y, z, w, on_change_callback: () => (), }
}

///|
/// SLERP between two quaternions held in flat arrays.
pub fn Quaternion::slerp_flat(
  dst : Array[Double],
  dst_offset : Int32,
  src0 : Array[Double],
  src_offset0 : Int32,
  src1 : Array[Double],
  src_offset1 : Int32,
  t : Double,
) -> Unit {
  let mut t = t
  let mut x0 = src0[src_offset0 + 0]
  let mut y0 = src0[src_offset0 + 1]
  let mut z0 = src0[src_offset0 + 2]
  let mut w0 = src0[src_offset0 + 3]
  let mut x1 = src1[src_offset1 + 0]
  let mut y1 = src1[src_offset1 + 1]
  let mut z1 = src1[src_offset1 + 2]
  let mut w1 = src1[src_offset1 + 3]
  if w0 != w1 || x0 != x1 || y0 != y1 || z0 != z1 {
    let mut dot = x0 * x1 + y0 * y1 + z0 * z1 + w0 * w1
    if dot < 0.0 {
      x1 = -x1
      y1 = -y1
      z1 = -z1
      w1 = -w1
      dot = -dot
    }
    let mut s = 1.0 - t
    if dot < 0.9995 {
      // slerp
      let theta = @cmath.acos(dot)
      let sin = @cmath.sin(theta)
      s = @cmath.sin(s * theta) / sin
      t = @cmath.sin(t * theta) / sin
      x0 = x0 * s + x1 * t
      y0 = y0 * s + y1 * t
      z0 = z0 * s + z1 * t
      w0 = w0 * s + w1 * t
    } else {
      // for small angles, lerp then normalize
      x0 = x0 * s + x1 * t
      y0 = y0 * s + y1 * t
      z0 = z0 * s + z1 * t
      w0 = w0 * s + w1 * t
      let f = 1.0 / (x0 * x0 + y0 * y0 + z0 * z0 + w0 * w0).sqrt()
      x0 *= f
      y0 *= f
      z0 *= f
      w0 *= f
    }
  }
  dst[dst_offset] = x0
  dst[dst_offset + 1] = y0
  dst[dst_offset + 2] = z0
  dst[dst_offset + 3] = w0
}

///|
/// Multiplies two quaternions held in flat arrays.
pub fn Quaternion::multiply_quaternions_flat(
  dst : Array[Double],
  dst_offset : Int32,
  src0 : Array[Double],
  src_offset0 : Int32,
  src1 : Array[Double],
  src_offset1 : Int32,
) -> Array[Double] {
  let x0 = src0[src_offset0]
  let y0 = src0[src_offset0 + 1]
  let z0 = src0[src_offset0 + 2]
  let w0 = src0[src_offset0 + 3]
  let x1 = src1[src_offset1]
  let y1 = src1[src_offset1 + 1]
  let z1 = src1[src_offset1 + 2]
  let w1 = src1[src_offset1 + 3]
  dst[dst_offset] = x0 * w1 + w0 * x1 + y0 * z1 - z0 * y1
  dst[dst_offset + 1] = y0 * w1 + w0 * y1 + z0 * x1 - x0 * z1
  dst[dst_offset + 2] = z0 * w1 + w0 * z1 + x0 * y1 - y0 * x1
  dst[dst_offset + 3] = w0 * w1 - x0 * x1 - y0 * y1 - z0 * z1
  dst
}

///|
/// Upstream's `x` setter: assigns and fires the change callback.
pub fn Quaternion::set_x(self : Quaternion, value : Double) -> Unit {
  self.x = value
  (self.on_change_callback)()
}

///|
/// Upstream's `y` setter: assigns and fires the change callback.
pub fn Quaternion::set_y(self : Quaternion, value : Double) -> Unit {
  self.y = value
  (self.on_change_callback)()
}

///|
/// Upstream's `z` setter: assigns and fires the change callback.
pub fn Quaternion::set_z(self : Quaternion, value : Double) -> Unit {
  self.z = value
  (self.on_change_callback)()
}

///|
/// Upstream's `w` setter: assigns and fires the change callback.
pub fn Quaternion::set_w(self : Quaternion, value : Double) -> Unit {
  self.w = value
  (self.on_change_callback)()
}

///|
/// Sets the quaternion components.
pub fn Quaternion::set(
  self : Quaternion,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Quaternion {
  self.x = x
  self.y = y
  self.z = z
  self.w = w
  (self.on_change_callback)()
  self
}

///|
/// Returns a new quaternion with the same components, without the callback.
pub fn Quaternion::clone(self : Quaternion) -> Quaternion {
  Quaternion::new(self.x, self.y, self.z, self.w)
}

///|
/// Copies the components of `quaternion` to this instance.
pub fn Quaternion::copy(
  self : Quaternion,
  quaternion : Quaternion,
) -> Quaternion {
  self.x = quaternion.x
  self.y = quaternion.y
  self.z = quaternion.z
  self.w = quaternion.w
  (self.on_change_callback)()
  self
}

///|
/// Sets this quaternion from Euler angles; `update` controls the callback.
pub fn Quaternion::set_from_euler(
  self : Quaternion,
  euler : Euler,
  update~ : Bool = true,
) -> Quaternion {
  let x = euler.x
  let y = euler.y
  let z = euler.z
  let order = euler.order
  let c1 = @cmath.cos(x / 2.0)
  let c2 = @cmath.cos(y / 2.0)
  let c3 = @cmath.cos(z / 2.0)
  let s1 = @cmath.sin(x / 2.0)
  let s2 = @cmath.sin(y / 2.0)
  let s3 = @cmath.sin(z / 2.0)
  match order {
    "XYZ" => {
      self.x = s1 * c2 * c3 + c1 * s2 * s3
      self.y = c1 * s2 * c3 - s1 * c2 * s3
      self.z = c1 * c2 * s3 + s1 * s2 * c3
      self.w = c1 * c2 * c3 - s1 * s2 * s3
    }
    "YXZ" => {
      self.x = s1 * c2 * c3 + c1 * s2 * s3
      self.y = c1 * s2 * c3 - s1 * c2 * s3
      self.z = c1 * c2 * s3 - s1 * s2 * c3
      self.w = c1 * c2 * c3 + s1 * s2 * s3
    }
    "ZXY" => {
      self.x = s1 * c2 * c3 - c1 * s2 * s3
      self.y = c1 * s2 * c3 + s1 * c2 * s3
      self.z = c1 * c2 * s3 + s1 * s2 * c3
      self.w = c1 * c2 * c3 - s1 * s2 * s3
    }
    "ZYX" => {
      self.x = s1 * c2 * c3 - c1 * s2 * s3
      self.y = c1 * s2 * c3 + s1 * c2 * s3
      self.z = c1 * c2 * s3 - s1 * s2 * c3
      self.w = c1 * c2 * c3 + s1 * s2 * s3
    }
    "YZX" => {
      self.x = s1 * c2 * c3 + c1 * s2 * s3
      self.y = c1 * s2 * c3 + s1 * c2 * s3
      self.z = c1 * c2 * s3 - s1 * s2 * c3
      self.w = c1 * c2 * c3 - s1 * s2 * s3
    }
    "XZY" => {
      self.x = s1 * c2 * c3 - c1 * s2 * s3
      self.y = c1 * s2 * c3 - s1 * c2 * s3
      self.z = c1 * c2 * s3 + s1 * s2 * c3
      self.w = c1 * c2 * c3 + s1 * s2 * s3
    }
    _ =>
      println(
        "Quaternion: .setFromEuler() encountered an unknown order: " + order,
      )
  }
  if update {
    (self.on_change_callback)()
  }
  self
}

///|
/// Sets this quaternion from a normalized axis and an angle in radians.
pub fn Quaternion::set_from_axis_angle(
  self : Quaternion,
  axis : Vector3,
  angle : Double,
) -> Quaternion {
  let half_angle = angle / 2.0
  let s = @cmath.sin(half_angle)
  self.x = axis.x * s
  self.y = axis.y * s
  self.z = axis.z * s
  self.w = @cmath.cos(half_angle)
  (self.on_change_callback)()
  self
}

///|
/// Sets this quaternion from a matrix whose upper 3x3 is a pure rotation.
pub fn Quaternion::set_from_rotation_matrix(
  self : Quaternion,
  m : Matrix4,
) -> Quaternion {
  // assumes the upper 3x3 of m is a pure rotation matrix (i.e, unscaled)
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
  let trace = m11 + m22 + m33
  if trace > 0.0 {
    let s = 0.5 / (trace + 1.0).sqrt()
    self.w = 0.25 / s
    self.x = (m32 - m23) * s
    self.y = (m13 - m31) * s
    self.z = (m21 - m12) * s
  } else if m11 > m22 && m11 > m33 {
    let s = 2.0 * (1.0 + m11 - m22 - m33).sqrt()
    self.w = (m32 - m23) / s
    self.x = 0.25 * s
    self.y = (m12 + m21) / s
    self.z = (m13 + m31) / s
  } else if m22 > m33 {
    let s = 2.0 * (1.0 + m22 - m11 - m33).sqrt()
    self.w = (m13 - m31) / s
    self.x = (m12 + m21) / s
    self.y = 0.25 * s
    self.z = (m23 + m32) / s
  } else {
    let s = 2.0 * (1.0 + m33 - m11 - m22).sqrt()
    self.w = (m21 - m12) / s
    self.x = (m13 + m31) / s
    self.y = (m23 + m32) / s
    self.z = 0.25 * s
  }
  (self.on_change_callback)()
  self
}

///|
/// Sets this quaternion to the rotation from direction `v_from` to `v_to`.
pub fn Quaternion::set_from_unit_vectors(
  self : Quaternion,
  v_from : Vector3,
  v_to : Vector3,
) -> Quaternion {
  // assumes direction vectors vFrom and vTo are normalized
  let mut r = v_from.dot(v_to) + 1.0
  if r < 1.0e-8 { // the epsilon value has been discussed in #31286
    // vFrom and vTo point in opposite directions
    r = 0.0
    if v_from.x.abs() > v_from.z.abs() {
      self.x = -v_from.y
      self.y = v_from.x
      self.z = 0.0
      self.w = r
    } else {
      self.x = 0.0
      self.y = -v_from.z
      self.z = v_from.y
      self.w = r
    }
  } else {
    // crossVectors( vFrom, vTo ); // inlined to avoid cyclic dependency on Vector3
    self.x = v_from.y * v_to.z - v_from.z * v_to.y
    self.y = v_from.z * v_to.x - v_from.x * v_to.z
    self.z = v_from.x * v_to.y - v_from.y * v_to.x
    self.w = r
  }
  self.normalize()
}

///|
/// Returns the angle in radians between this quaternion and `q`.
pub fn Quaternion::angle_to(self : Quaternion, q : Quaternion) -> Double {
  2.0 * @cmath.acos(clamp(self.dot(q), -1.0, 1.0).abs())
}

///|
/// Rotates towards `q` by at most `step` radians, without overshooting.
pub fn Quaternion::rotate_towards(
  self : Quaternion,
  q : Quaternion,
  step : Double,
) -> Quaternion {
  let angle = self.angle_to(q)
  if angle == 0.0 {
    return self
  }
  let t = math_utils_min(1.0, step / angle)
  ignore(self.slerp(q, t))
  self
}

///|
/// Sets this quaternion to the identity quaternion.
pub fn Quaternion::identity(self : Quaternion) -> Quaternion {
  self.set(0.0, 0.0, 0.0, 1.0)
}

///|
/// Inverts this quaternion, which is assumed to have unit length.
pub fn Quaternion::invert(self : Quaternion) -> Quaternion {
  self.conjugate()
}

///|
/// Sets this quaternion to its rotational conjugate.
pub fn Quaternion::conjugate(self : Quaternion) -> Quaternion {
  self.x *= -1.0
  self.y *= -1.0
  self.z *= -1.0
  (self.on_change_callback)()
  self
}

///|
/// Dot product of this quaternion and `v`.
pub fn Quaternion::dot(self : Quaternion, v : Quaternion) -> Double {
  self.x * v.x + self.y * v.y + self.z * v.z + self.w * v.w
}

///|
/// Squared Euclidean length of this quaternion.
pub fn Quaternion::length_sq(self : Quaternion) -> Double {
  self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
}

///|
/// Euclidean length of this quaternion.
pub fn Quaternion::length(self : Quaternion) -> Double {
  (self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w).sqrt()
}

///|
/// Normalizes this quaternion; a zero quaternion becomes the identity.
pub fn Quaternion::normalize(self : Quaternion) -> Quaternion {
  let mut l = self.length()
  if l == 0.0 {
    self.x = 0.0
    self.y = 0.0
    self.z = 0.0
    self.w = 1.0
  } else {
    l = 1.0 / l
    self.x = self.x * l
    self.y = self.y * l
    self.z = self.z * l
    self.w = self.w * l
  }
  (self.on_change_callback)()
  self
}

///|
/// Multiplies this quaternion by `q`.
pub fn Quaternion::multiply(self : Quaternion, q : Quaternion) -> Quaternion {
  self.multiply_quaternions(self, q)
}

///|
/// Pre-multiplies this quaternion by `q`.
pub fn Quaternion::premultiply(self : Quaternion, q : Quaternion) -> Quaternion {
  self.multiply_quaternions(q, self)
}

///|
/// Stores the product of `a` and `b` in this quaternion.
pub fn Quaternion::multiply_quaternions(
  self : Quaternion,
  a : Quaternion,
  b : Quaternion,
) -> Quaternion {
  let qax = a.x
  let qay = a.y
  let qaz = a.z
  let qaw = a.w
  let qbx = b.x
  let qby = b.y
  let qbz = b.z
  let qbw = b.w
  self.x = qax * qbw + qaw * qbx + qay * qbz - qaz * qby
  self.y = qay * qbw + qaw * qby + qaz * qbx - qax * qbz
  self.z = qaz * qbw + qaw * qbz + qax * qby - qay * qbx
  self.w = qaw * qbw - qax * qbx - qay * qby - qaz * qbz
  (self.on_change_callback)()
  self
}

///|
/// Spherical linear interpolation between this quaternion and `qb`.
pub fn Quaternion::slerp(
  self : Quaternion,
  qb : Quaternion,
  t : Double,
) -> Quaternion {
  let mut t = t
  let mut x = qb.x
  let mut y = qb.y
  let mut z = qb.z
  let mut w = qb.w
  let mut dot = self.dot(qb)
  if dot < 0.0 {
    x = -x
    y = -y
    z = -z
    w = -w
    dot = -dot
  }
  let mut s = 1.0 - t
  if dot < 0.9995 {
    // slerp
    let theta = @cmath.acos(dot)
    let sin = @cmath.sin(theta)
    s = @cmath.sin(s * theta) / sin
    t = @cmath.sin(t * theta) / sin
    self.x = self.x * s + x * t
    self.y = self.y * s + y * t
    self.z = self.z * s + z * t
    self.w = self.w * s + w * t
    (self.on_change_callback)()
  } else {
    // for small angles, lerp then normalize
    self.x = self.x * s + x * t
    self.y = self.y * s + y * t
    self.z = self.z * s + z * t
    self.w = self.w * s + w * t
    ignore(self.normalize()) // normalize calls on_change_callback
  }
  self
}

///|
/// Stores the spherical interpolation of `qa` and `qb` in this quaternion.
pub fn Quaternion::slerp_quaternions(
  self : Quaternion,
  qa : Quaternion,
  qb : Quaternion,
  t : Double,
) -> Quaternion {
  self.copy(qa).slerp(qb, t)
}

///|
/// Sets this quaternion to a uniformly random, normalized quaternion.
pub fn Quaternion::random(self : Quaternion) -> Quaternion {
  // Ken Shoemake
  // Uniform random rotations
  // D. Kirk, editor, Graphics Gems III, pages 124-132. Academic Press, New York, 1992.
  let theta1 = 2.0 * @cmath.PI * math_utils_random()
  let theta2 = 2.0 * @cmath.PI * math_utils_random()
  let x0 = math_utils_random()
  let r1 = (1.0 - x0).sqrt()
  let r2 = x0.sqrt()
  self.set(
    r1 * @cmath.sin(theta1),
    r1 * @cmath.cos(theta1),
    r2 * @cmath.sin(theta2),
    r2 * @cmath.cos(theta2),
  )
}

///|
/// Returns `true` if this quaternion equals `quaternion`.
pub fn Quaternion::equals(self : Quaternion, quaternion : Quaternion) -> Bool {
  quaternion.x == self.x &&
  quaternion.y == self.y &&
  quaternion.z == self.z &&
  quaternion.w == self.w
}

///|
/// Sets the components from `array`, starting at `offset`.
pub fn Quaternion::from_array(
  self : Quaternion,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Quaternion {
  self.x = array[offset]
  self.y = array[offset + 1]
  self.z = array[offset + 2]
  self.w = array[offset + 3]
  (self.on_change_callback)()
  self
}

///|
/// Writes the components to `array` at `offset`, growing it as needed.
pub fn Quaternion::to_array(
  self : Quaternion,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  math_utils_grow(array, offset + 4)
  array[offset] = self.x
  array[offset + 1] = self.y
  array[offset + 2] = self.z
  array[offset + 3] = self.w
  array
}

///|
/// Sets the components from entry `index` of a buffer attribute.
pub fn[A : BufferAttributeLike] Quaternion::from_buffer_attribute(
  self : Quaternion,
  attribute : A,
  index : Int32,
) -> Quaternion {
  self.x = attribute.get_x(index)
  self.y = attribute.get_y(index)
  self.z = attribute.get_z(index)
  self.w = attribute.get_w(index)
  (self.on_change_callback)()
  self
}

///|
/// Serializes this quaternion as `[x, y, z, w]`.
pub fn Quaternion::to_json(self : Quaternion) -> Array[Double] {
  self.to_array()
}

///|
/// Sets the callback fired when this quaternion changes.
pub fn Quaternion::on_change(
  self : Quaternion,
  callback : () -> Unit,
) -> Quaternion {
  self.on_change_callback = callback
  self
}
