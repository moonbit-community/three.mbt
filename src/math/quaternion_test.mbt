///|
/// Upstream's `x`, `y`, `z`, `w`, `eps` from `math-constants.js`.
let quaternion_test_x : Double = 2.0

///|
let quaternion_test_y : Double = 3.0

///|
let quaternion_test_z : Double = 4.0

///|
let quaternion_test_w : Double = 5.0

///|
let quaternion_test_eps : Double = 0.0001

///|
/// `Number.EPSILON`.
let quaternion_test_number_epsilon : Double = 2.220446049250313e-16

///|
/// `Math.SQRT1_2`.
let quaternion_test_sqrt1_2 : Double = 0.7071067811865476

///|
let quaternion_test_orders : Array[String] = [
  "XYZ", "YXZ", "ZXY", "ZYX", "YZX", "XZY",
]

///|
fn quaternion_test_identity() -> @math.Quaternion {
  @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
}

///|
fn quaternion_test_euler_angles() -> @math.Euler {
  @math.Euler::new(0.1, -0.3, 0.25)
}

///|
fn quaternion_test_sub(
  a : @math.Quaternion,
  b : @math.Quaternion,
) -> @math.Quaternion {
  let result = quaternion_test_identity()
  ignore(result.copy(a))
  result.set_x(result.x - b.x)
  result.set_y(result.y - b.y)
  result.set_z(result.z - b.z)
  result.set_w(result.w - b.w)
  result
}

///|
/// The object both `doSlerpObject` and `doSlerpArray` return upstream.
struct QuaternionTestSlerp {
  components : Array[Double]
  length : Double
  dot_a : Double
  dot_b : Double
}

///|
fn QuaternionTestSlerp::equals(
  self : QuaternionTestSlerp,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
  max_error~ : Double = quaternion_test_number_epsilon,
) -> Bool {
  let c = self.components
  (x - c[0]).abs() <= max_error &&
  (y - c[1]).abs() <= max_error &&
  (z - c[2]).abs() <= max_error &&
  (w - c[3]).abs() <= max_error
}

///|
fn quaternion_test_do_slerp_object(
  a_arr : Array[Double],
  b_arr : Array[Double],
  t : Double,
) -> QuaternionTestSlerp {
  let a = quaternion_test_identity().from_array(a_arr)
  let b = quaternion_test_identity().from_array(b_arr)
  let c = quaternion_test_identity().from_array(a_arr)
  ignore(c.slerp(b, t))
  {
    components: [c.x, c.y, c.z, c.w],
    length: c.length(),
    dot_a: c.dot(a),
    dot_b: c.dot(b),
  }
}

///|
fn quaternion_test_arr_dot(a : Array[Double], b : Array[Double]) -> Double {
  a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
}

///|
fn quaternion_test_do_slerp_array(
  a : Array[Double],
  b : Array[Double],
  t : Double,
) -> QuaternionTestSlerp {
  let result = [0.0, 0.0, 0.0, 0.0]
  @math.Quaternion::slerp_flat(result, 0, a, 0, b, 0, t)
  {
    components: result,
    length: quaternion_test_arr_dot(result, result).sqrt(),
    dot_a: quaternion_test_arr_dot(result, a),
    dot_b: quaternion_test_arr_dot(result, b),
  }
}

///|
fn quaternion_test_slerp_skeleton(
  do_slerp : (Array[Double], Array[Double], Double) -> QuaternionTestSlerp,
  max_error : Double,
) -> Unit raise {
  let a = [
    0.6753410084407496, 0.4087830051091744, 0.32856700410659473, 0.5185120064806223,
  ]
  let b = [
    0.6602792107657797, 0.43647413932562285, 0.35119011210236006, 0.5001871596632682,
  ]
  let is_normal = (result : QuaternionTestSlerp) => {
    (1.0 - result.length).abs() <= max_error
  }
  let result = do_slerp(a, b, 0.0)
  assert_true(result.equals(a[0], a[1], a[2], a[3], max_error=0.0))
  let result = do_slerp(a, b, 1.0)
  assert_true(result.equals(b[0], b[1], b[2], b[3], max_error=0.0))
  let result = do_slerp(a, b, 0.5)
  assert_true(
    (result.dot_a - result.dot_b).abs() <= quaternion_test_number_epsilon,
  )
  assert_true(is_normal(result))
  let result = do_slerp(a, b, 0.25)
  assert_true(result.dot_a > result.dot_b)
  assert_true(is_normal(result))
  let result = do_slerp(a, b, 0.75)
  assert_true(result.dot_a < result.dot_b)
  assert_true(is_normal(result))
  let d = quaternion_test_sqrt1_2
  let result = do_slerp([1.0, 0.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], 0.5)
  assert_true(result.equals(d, 0.0, d, 0.0))
  assert_true(is_normal(result))
  let result = do_slerp([0.0, d, 0.0, d], [0.0, -d, 0.0, d], 0.5)
  assert_true(result.equals(0.0, 0.0, 0.0, 1.0))
  assert_true(is_normal(result))
}

///|
fn quaternion_test_change_order(
  euler : @math.Euler,
  order : String,
) -> @math.Euler {
  @math.Euler::new(euler.x, euler.y, euler.z, order~)
}

///|
/// Upstream's `Float32Array`-backed `BufferAttribute`, reduced to its getters.
struct QuaternionTestAttribute {
  array : Array[Double]
}

///|
impl @math.BufferAttributeLike for QuaternionTestAttribute with fn get_x(
  self,
  index,
) {
  self.array[index * 4]
}

///|
impl @math.BufferAttributeLike for QuaternionTestAttribute with fn get_y(
  self,
  index,
) {
  self.array[index * 4 + 1]
}

///|
impl @math.BufferAttributeLike for QuaternionTestAttribute with fn get_z(
  self,
  index,
) {
  self.array[index * 4 + 2]
}

///|
impl @math.BufferAttributeLike for QuaternionTestAttribute with fn get_w(
  self,
  index,
) {
  self.array[index * 4 + 3]
}

///|
test "Quaternion Instancing" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let mut a = quaternion_test_identity()
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  a = @math.Quaternion::new(x, y, z, w)
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
}

///|
test "Quaternion slerp (skeleton)" {
  quaternion_test_slerp_skeleton(
    quaternion_test_do_slerp_object, quaternion_test_number_epsilon,
  )
}

///|
test "Quaternion slerpFlat" {
  quaternion_test_slerp_skeleton(
    quaternion_test_do_slerp_array, quaternion_test_number_epsilon,
  )
}

///|
test "Quaternion multiplyQuaternionsFlat" {
  let a = quaternion_test_identity().set_from_euler(
    @math.Euler::new(1.0, 0.0, 0.0),
  )
  let b = quaternion_test_identity().set_from_euler(
    @math.Euler::new(0.0, 1.0, 0.0),
  )
  let expected = quaternion_test_identity().multiply_quaternions(a, b)
  let dst = [9.0, 0.0, 0.0, 0.0, 0.0]
  let result = @math.Quaternion::multiply_quaternions_flat(
    dst,
    1,
    [7.0, a.x, a.y, a.z, a.w],
    1,
    [b.x, b.y, b.z, b.w],
    0,
  )
  assert_true(physical_equal(result, dst))
  assert_eq(dst, [9.0, expected.x, expected.y, expected.z, expected.w])
}

///|
test "Quaternion properties" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = quaternion_test_identity()
  let mut calls = 0
  ignore(a.on_change(() => calls += 1))
  a.set_x(x)
  a.set_y(y)
  a.set_z(z)
  a.set_w(w)
  assert_eq(a.x, x)
  assert_eq(a.y, y)
  assert_eq(a.z, z)
  assert_eq(a.w, w)
  assert_eq(calls, 4)
}

///|
test "Quaternion x" {
  let mut a = quaternion_test_identity()
  assert_true(a.x == 0.0)
  a = @math.Quaternion::new(1.0, 2.0, 3.0, 1.0)
  assert_true(a.x == 1.0)
  a = @math.Quaternion::new(4.0, 5.0, 6.0, 1.0)
  assert_true(a.x == 4.0)
  a = @math.Quaternion::new(7.0, 8.0, 9.0, 1.0)
  a.set_x(10.0)
  assert_true(a.x == 10.0)
  a = @math.Quaternion::new(11.0, 12.0, 13.0, 1.0)
  let mut b = false
  ignore(a.on_change(() => b = true))
  assert_true(!b)
  a.set_x(14.0)
  assert_true(b)
  assert_true(a.x == 14.0)
}

///|
test "Quaternion y" {
  let mut a = quaternion_test_identity()
  assert_true(a.y == 0.0)
  a = @math.Quaternion::new(1.0, 2.0, 3.0, 1.0)
  assert_true(a.y == 2.0)
  a = @math.Quaternion::new(4.0, 5.0, 6.0, 1.0)
  assert_true(a.y == 5.0)
  a = @math.Quaternion::new(7.0, 8.0, 9.0, 1.0)
  a.set_y(10.0)
  assert_true(a.y == 10.0)
  a = @math.Quaternion::new(11.0, 12.0, 13.0, 1.0)
  let mut b = false
  ignore(a.on_change(() => b = true))
  assert_true(!b)
  a.set_y(14.0)
  assert_true(b)
  assert_true(a.y == 14.0)
}

///|
test "Quaternion z" {
  let mut a = quaternion_test_identity()
  assert_true(a.z == 0.0)
  a = @math.Quaternion::new(1.0, 2.0, 3.0, 1.0)
  assert_true(a.z == 3.0)
  a = @math.Quaternion::new(4.0, 5.0, 6.0, 1.0)
  assert_true(a.z == 6.0)
  a = @math.Quaternion::new(7.0, 8.0, 9.0, 1.0)
  a.set_z(10.0)
  assert_true(a.z == 10.0)
  a = @math.Quaternion::new(11.0, 12.0, 13.0, 1.0)
  let mut b = false
  ignore(a.on_change(() => b = true))
  assert_true(!b)
  a.set_z(14.0)
  assert_true(b)
  assert_true(a.z == 14.0)
}

///|
test "Quaternion w" {
  let mut a = quaternion_test_identity()
  assert_true(a.w == 1.0)
  a = @math.Quaternion::new(1.0, 2.0, 3.0, 1.0)
  assert_true(a.w == 1.0)
  a = @math.Quaternion::new(4.0, 5.0, 6.0, 1.0)
  assert_true(a.w == 1.0)
  a = @math.Quaternion::new(7.0, 8.0, 9.0, 1.0)
  a.set_w(10.0)
  assert_true(a.w == 10.0)
  a = @math.Quaternion::new(11.0, 12.0, 13.0, 1.0)
  let mut b = false
  ignore(a.on_change(() => b = true))
  assert_true(!b)
  a.set_w(14.0)
  assert_true(b)
  assert_true(a.w == 14.0)
}

///|
test "Quaternion set" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = quaternion_test_identity()
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  ignore(a.set(x, y, z, w))
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
}

///|
test "Quaternion clone" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = quaternion_test_identity().clone()
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  let b = a.set(x, y, z, w).clone()
  assert_true(b.x == x)
  assert_true(b.y == y)
  assert_true(b.z == z)
  assert_true(b.w == w)
}

///|
test "Quaternion copy" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = @math.Quaternion::new(x, y, z, w)
  let b = quaternion_test_identity().copy(a)
  assert_true(b.x == x)
  assert_true(b.y == y)
  assert_true(b.z == z)
  assert_true(b.w == w)
  // ensure that it is a true copy
  a.set_x(0.0)
  a.set_y(-1.0)
  a.set_z(0.0)
  a.set_w(-1.0)
  assert_true(b.x == x)
  assert_true(b.y == y)
}

///|
test "Quaternion setFromEuler/setFromQuaternion" {
  let angles = [
    @math.Vector3::new(1.0, 0.0, 0.0),
    @math.Vector3::new(0.0, 1.0, 0.0),
    @math.Vector3::new(0.0, 0.0, 1.0),
  ]
  // ensure euler conversion to/from Quaternion matches.
  for order in quaternion_test_orders {
    for angle in angles {
      let eulers2 = @math.Euler::new(0.0, 0.0, 0.0).set_from_quaternion(
        quaternion_test_identity().set_from_euler(
          @math.Euler::new(angle.x, angle.y, angle.z, order~),
        ),
        order~,
      )
      let new_angle = @math.Vector3::new(eulers2.x, eulers2.y, eulers2.z)
      assert_true(new_angle.distance_to(angle) < 0.001)
    }
  }
}

///|
test "Quaternion setFromAxisAngle" {
  let zero = quaternion_test_identity()
  let mut a = quaternion_test_identity().set_from_axis_angle(
    @math.Vector3::new(1.0, 0.0, 0.0),
    0.0,
  )
  assert_true(a.equals(zero))
  a = quaternion_test_identity().set_from_axis_angle(
    @math.Vector3::new(0.0, 1.0, 0.0),
    0.0,
  )
  assert_true(a.equals(zero))
  a = quaternion_test_identity().set_from_axis_angle(
    @math.Vector3::new(0.0, 0.0, 1.0),
    0.0,
  )
  assert_true(a.equals(zero))
  let b1 = quaternion_test_identity().set_from_axis_angle(
    @math.Vector3::new(1.0, 0.0, 0.0),
    @cmath.PI,
  )
  assert_true(!a.equals(b1))
  let b2 = quaternion_test_identity().set_from_axis_angle(
    @math.Vector3::new(1.0, 0.0, 0.0),
    -@cmath.PI,
  )
  assert_true(!a.equals(b2))
  ignore(b1.multiply(b2))
  assert_true(a.equals(b1))
}

///|
test "Quaternion setFromEuler/setFromRotationMatrix" {
  // ensure euler conversion for Quaternion matches that of Matrix4
  let euler_angles = quaternion_test_euler_angles()
  for order in quaternion_test_orders {
    let q = quaternion_test_identity().set_from_euler(
      quaternion_test_change_order(euler_angles, order),
    )
    let m = @math.Matrix4::new().make_rotation_from_euler(
      quaternion_test_change_order(euler_angles, order),
    )
    let q2 = quaternion_test_identity().set_from_rotation_matrix(m)
    assert_true(quaternion_test_sub(q, q2).length() < 0.001)
  }
}

///|
test "Quaternion setFromRotationMatrix" {
  // contrived examples purely to please the god of code coverage...
  // match conditions in various 'else [if]' blocks
  let eps = quaternion_test_eps
  let a = quaternion_test_identity()
  let mut q = @math.Quaternion::new(-9.0, -2.0, 3.0, -4.0).normalize()
  let m = @math.Matrix4::new().make_rotation_from_quaternion(q)
  let mut expected = @math.Vector4::new(
    0.8581163303210332, 0.19069251784911848, -0.2860387767736777, 0.38138503569823695,
  )
  ignore(a.set_from_rotation_matrix(m))
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
  q = @math.Quaternion::new(-1.0, -2.0, 1.0, -1.0).normalize()
  ignore(m.make_rotation_from_quaternion(q))
  expected = @math.Vector4::new(
    0.37796447300922714, 0.7559289460184544, -0.37796447300922714, 0.37796447300922714,
  )
  ignore(a.set_from_rotation_matrix(m))
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
}

///|
test "Quaternion setFromUnitVectors" {
  let eps = quaternion_test_eps
  let a = quaternion_test_identity()
  let b = @math.Vector3::new(1.0, 0.0, 0.0)
  let c = @math.Vector3::new(0.0, 1.0, 0.0)
  let expected = @math.Quaternion::new(
    0.0,
    0.0,
    2.0.sqrt() / 2.0,
    2.0.sqrt() / 2.0,
  )
  ignore(a.set_from_unit_vectors(b, c))
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
}

///|
test "Quaternion angleTo" {
  let a = quaternion_test_identity()
  let b = quaternion_test_identity().set_from_euler(
    @math.Euler::new(0.0, @cmath.PI, 0.0),
  )
  let c = quaternion_test_identity().set_from_euler(
    @math.Euler::new(0.0, @cmath.PI * 2.0, 0.0),
  )
  assert_true(a.angle_to(a) == 0.0)
  assert_true(a.angle_to(b) == @cmath.PI)
  assert_true(a.angle_to(c) == 0.0)
}

///|
test "Quaternion rotateTowards" {
  let a = quaternion_test_identity()
  let b = quaternion_test_identity().set_from_euler(
    @math.Euler::new(0.0, @cmath.PI, 0.0),
  )
  let c = quaternion_test_identity()
  let half_pi = @cmath.PI * 0.5
  ignore(a.rotate_towards(b, 0.0))
  assert_true(a.equals(a))
  ignore(a.rotate_towards(b, @cmath.PI * 2.0)) // test overshoot
  assert_true(a.equals(b))
  ignore(a.set(0.0, 0.0, 0.0, 1.0))
  ignore(a.rotate_towards(b, half_pi))
  assert_true(a.angle_to(c) - half_pi <= quaternion_test_eps)
}

///|
test "Quaternion identity" {
  let a = quaternion_test_identity()
  ignore(
    a.set(
      quaternion_test_x, quaternion_test_y, quaternion_test_z, quaternion_test_w,
    ),
  )
  ignore(a.identity())
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
}

///|
test "Quaternion invert/conjugate" {
  let a = @math.Quaternion::new(
    quaternion_test_x, quaternion_test_y, quaternion_test_z, quaternion_test_w,
  )
  let b = a.clone().conjugate()
  assert_true(a.x == -b.x)
  assert_true(a.y == -b.y)
  assert_true(a.z == -b.z)
  assert_true(a.w == b.w)
  let c = a.clone().invert()
  assert_true(c.equals(b))
}

///|
test "Quaternion dot" {
  let mut a = quaternion_test_identity()
  let mut b = quaternion_test_identity()
  assert_true(a.dot(b) == 1.0)
  a = @math.Quaternion::new(1.0, 2.0, 3.0, 1.0)
  b = @math.Quaternion::new(3.0, 2.0, 1.0, 1.0)
  assert_true(a.dot(b) == 11.0)
}

///|
test "Quaternion normalize/length/lengthSq" {
  let a = @math.Quaternion::new(
    quaternion_test_x, quaternion_test_y, quaternion_test_z, quaternion_test_w,
  )
  assert_true(a.length() != 1.0)
  assert_true(a.length_sq() != 1.0)
  ignore(a.normalize())
  assert_true(a.length() == 1.0)
  assert_true(a.length_sq() == 1.0)
  ignore(a.set(0.0, 0.0, 0.0, 0.0))
  assert_true(a.length_sq() == 0.0)
  assert_true(a.length() == 0.0)
  ignore(a.normalize())
  assert_true(a.length_sq() == 1.0)
  assert_true(a.length() == 1.0)
}

///|
test "Quaternion multiplyQuaternions/multiply" {
  let angles = [
    @math.Euler::new(1.0, 0.0, 0.0),
    @math.Euler::new(0.0, 1.0, 0.0),
    @math.Euler::new(0.0, 0.0, 1.0),
  ]
  let q1 = quaternion_test_identity().set_from_euler(
    quaternion_test_change_order(angles[0], "XYZ"),
  )
  let q2 = quaternion_test_identity().set_from_euler(
    quaternion_test_change_order(angles[1], "XYZ"),
  )
  let q3 = quaternion_test_identity().set_from_euler(
    quaternion_test_change_order(angles[2], "XYZ"),
  )
  let q = quaternion_test_identity().multiply_quaternions(q1, q2).multiply(q3)
  let m1 = @math.Matrix4::new().make_rotation_from_euler(
    quaternion_test_change_order(angles[0], "XYZ"),
  )
  let m2 = @math.Matrix4::new().make_rotation_from_euler(
    quaternion_test_change_order(angles[1], "XYZ"),
  )
  let m3 = @math.Matrix4::new().make_rotation_from_euler(
    quaternion_test_change_order(angles[2], "XYZ"),
  )
  let m = @math.Matrix4::new().multiply_matrices(m1, m2).multiply(m3)
  let q_from_m = quaternion_test_identity().set_from_rotation_matrix(m)
  assert_true(quaternion_test_sub(q, q_from_m).length() < 0.001)
}

///|
test "Quaternion premultiply" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let eps = quaternion_test_eps
  let a = @math.Quaternion::new(x, y, z, w)
  let b = @math.Quaternion::new(2.0 * x, -y, -2.0 * z, w)
  let expected = @math.Quaternion::new(42.0, -32.0, -2.0, 58.0)
  ignore(a.premultiply(b))
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
}

///|
test "Quaternion slerp" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let eps = quaternion_test_eps
  let a = @math.Quaternion::new(x, y, z, w).normalize()
  let b = @math.Quaternion::new(w, x, y, z).normalize()
  let c = a.clone().slerp(b, 0.0)
  let d = a.clone().slerp(b, 1.0)
  assert_true(a.equals(c))
  assert_true(b.equals(d))
  let sqrt1_2 = quaternion_test_sqrt1_2
  let e = @math.Quaternion::new(1.0, 0.0, 0.0, 0.0)
  let f = @math.Quaternion::new(0.0, 0.0, 1.0, 0.0)
  let mut expected = @math.Quaternion::new(sqrt1_2, 0.0, sqrt1_2, 0.0)
  let mut result = e.clone().slerp(f, 0.5)
  assert_true((result.x - expected.x).abs() <= eps)
  assert_true((result.y - expected.y).abs() <= eps)
  assert_true((result.z - expected.z).abs() <= eps)
  assert_true((result.w - expected.w).abs() <= eps)
  let g = @math.Quaternion::new(0.0, sqrt1_2, 0.0, sqrt1_2)
  let h = @math.Quaternion::new(0.0, -sqrt1_2, 0.0, sqrt1_2)
  expected = quaternion_test_identity()
  result = g.clone().slerp(h, 0.5)
  assert_true((result.x - expected.x).abs() <= eps)
  assert_true((result.y - expected.y).abs() <= eps)
  assert_true((result.z - expected.z).abs() <= eps)
  assert_true((result.w - expected.w).abs() <= eps)
}

///|
test "Quaternion slerpQuaternions" {
  let eps = quaternion_test_eps
  let e = @math.Quaternion::new(1.0, 0.0, 0.0, 0.0)
  let f = @math.Quaternion::new(0.0, 0.0, 1.0, 0.0)
  let expected = @math.Quaternion::new(
    quaternion_test_sqrt1_2, 0.0, quaternion_test_sqrt1_2, 0.0,
  )
  let a = quaternion_test_identity()
  ignore(a.slerp_quaternions(e, f, 0.5))
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
}

///|
test "Quaternion random" {
  let a = quaternion_test_identity()
  ignore(a.random())
  let identity = quaternion_test_identity()
  assert_true(!a.equals(identity))
  assert_true(1.0 - a.length() <= quaternion_test_number_epsilon)
}

///|
test "Quaternion equals" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = @math.Quaternion::new(x, y, z, w)
  let b = @math.Quaternion::new(-x, -y, -z, -w)
  assert_true(a.x != b.x)
  assert_true(a.y != b.y)
  assert_true(!a.equals(b))
  assert_true(!b.equals(a))
  ignore(a.copy(b))
  assert_true(a.x == b.x)
  assert_true(a.y == b.y)
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Quaternion fromArray" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = quaternion_test_identity()
  ignore(a.from_array([x, y, z, w]))
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
  // upstream pads with `undefined`
  ignore(a.from_array([0.0, x, y, z, w, 0.0], offset=1))
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
}

///|
test "Quaternion toArray" {
  let x = quaternion_test_x
  let y = quaternion_test_y
  let z = quaternion_test_z
  let w = quaternion_test_w
  let a = @math.Quaternion::new(x, y, z, w)
  let array = a.to_array()
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  assert_eq(array[2], z)
  assert_eq(array[3], w)
  let array : Array[Double] = []
  ignore(a.to_array(array~))
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  assert_eq(array[2], z)
  assert_eq(array[3], w)
  let array : Array[Double] = []
  ignore(a.to_array(array~, offset=1))
  // upstream leaves `undefined` in the first slot; `Array[Double]` holds 0
  assert_eq(array[0], 0.0)
  assert_eq(array[1], x)
  assert_eq(array[2], y)
  assert_eq(array[3], z)
  assert_eq(array[4], w)
}

///|
test "Quaternion fromBufferAttribute" {
  let a = quaternion_test_identity()
  let attribute : QuaternionTestAttribute = {
    array: [0.0, 0.0, 0.0, 1.0, 0.7, 0.0, 0.0, 0.7, 0.0, 0.7, 0.0, 0.7],
  }
  ignore(a.from_buffer_attribute(attribute, 0))
  assert_true((a.x - 0.0).abs() < 0.1)
  assert_true((a.y - 0.0).abs() < 0.1)
  assert_true((a.z - 0.0).abs() < 0.1)
  assert_true((a.w - 1.0).abs() < 0.1)
  ignore(a.from_buffer_attribute(attribute, 1))
  assert_true((a.x - 0.7).abs() < 0.1)
  assert_true((a.y - 0.0).abs() < 0.1)
  assert_true((a.z - 0.0).abs() < 0.1)
  assert_true((a.w - 0.7).abs() < 0.1)
  ignore(a.from_buffer_attribute(attribute, 2))
  assert_true((a.x - 0.0).abs() < 0.1)
  assert_true((a.y - 0.7).abs() < 0.1)
  assert_true((a.z - 0.0).abs() < 0.1)
  assert_true((a.w - 0.7).abs() < 0.1)
}

///|
test "Quaternion _onChange" {
  let mut b = false
  let f = () => b = true
  let a = @math.Quaternion::new(11.0, 12.0, 13.0, 1.0)
  ignore(a.on_change(f))
  assert_true(physical_equal(a.on_change_callback, f))
  (a.on_change_callback)()
  assert_true(b)
}

///|
test "Quaternion _onChangeCallback" {
  let mut b = false
  let a = @math.Quaternion::new(11.0, 12.0, 13.0, 1.0)
  let f = () => b = true
  ignore(a.on_change(f))
  assert_true(physical_equal(a.on_change_callback, f))
  (a.on_change_callback)()
  assert_true(b)
}

///|
test "Quaternion setFromEuler update flag" {
  let a = quaternion_test_identity()
  let mut calls = 0
  ignore(a.on_change(() => calls += 1))
  ignore(a.set_from_euler(@math.Euler::new(0.1, 0.2, 0.3), update=false))
  assert_eq(calls, 0)
  ignore(a.set_from_euler(@math.Euler::new(0.1, 0.2, 0.3)))
  assert_eq(calls, 1)
}

///|
test "Quaternion multiplyVector3" {
  let angles = [
    @math.Euler::new(1.0, 0.0, 0.0),
    @math.Euler::new(0.0, 1.0, 0.0),
    @math.Euler::new(0.0, 0.0, 1.0),
  ]
  // ensure euler conversion for Quaternion matches that of Matrix4
  for order in quaternion_test_orders {
    for angle in angles {
      let q = quaternion_test_identity().set_from_euler(
        quaternion_test_change_order(angle, order),
      )
      let m = @math.Matrix4::new().make_rotation_from_euler(
        quaternion_test_change_order(angle, order),
      )
      let v0 = @math.Vector3::new(1.0, 0.0, 0.0)
      let qv = v0.clone().apply_quaternion(q)
      let mv = v0.clone().apply_matrix4(m)
      assert_true(qv.distance_to(mv) < 0.001)
    }
  }
}

///|
test "Quaternion toJSON" {
  let q = @math.Quaternion::new(0.0, 0.5, 0.7, 1.0)
  let array = q.to_json()
  assert_eq(array[0], 0.0)
  assert_eq(array[1], 0.5)
  assert_eq(array[2], 0.7)
  assert_eq(array[3], 1.0)
}
