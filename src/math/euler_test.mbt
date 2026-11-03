///|
/// Upstream's `x`, `y`, `z` from `math-constants.js`.
let euler_test_x : Double = 2.0

///|
let euler_test_y : Double = 3.0

///|
let euler_test_z : Double = 4.0

///|
fn euler_test_zero() -> @math.Euler {
  @math.Euler::new(0.0, 0.0, 0.0, order="XYZ")
}

///|
fn euler_test_axyz() -> @math.Euler {
  @math.Euler::new(1.0, 0.0, 0.0, order="XYZ")
}

///|
fn euler_test_azyx() -> @math.Euler {
  @math.Euler::new(0.0, 1.0, 0.0, order="ZYX")
}

///|
fn euler_test_quat_equals(
  a : @math.Quaternion,
  b : @math.Quaternion,
  tolerance~ : Double = 0.0001,
) -> Bool {
  let diff = (a.x - b.x).abs() +
    (a.y - b.y).abs() +
    (a.z - b.z).abs() +
    (a.w - b.w).abs()
  diff < tolerance
}

///|
test "Euler Instancing" {
  let a = @math.Euler::new(0.0, 0.0, 0.0)
  assert_true(a.equals(euler_test_zero()))
  assert_true(!a.equals(euler_test_axyz()))
  assert_true(!a.equals(euler_test_azyx()))
}

///|
test "Euler DEFAULT_ORDER" {
  assert_eq(@math.EULER_DEFAULT_ORDER, "XYZ")
}

///|
test "Euler x" {
  let mut a = @math.Euler::new(0.0, 0.0, 0.0)
  assert_eq(a.x, 0.0)
  a = @math.Euler::new(1.0, 2.0, 3.0)
  assert_eq(a.x, 1.0)
  a = @math.Euler::new(4.0, 5.0, 6.0, order="XYZ")
  assert_eq(a.x, 4.0)
  a = @math.Euler::new(7.0, 8.0, 9.0, order="XYZ")
  a.set_x(10.0)
  assert_eq(a.x, 10.0)
  a = @math.Euler::new(11.0, 12.0, 13.0, order="XYZ")
  let mut b = false
  ignore(a.on_change(() => b = true))
  a.set_x(14.0)
  assert_true(b)
  assert_eq(a.x, 14.0)
}

///|
test "Euler y" {
  let mut a = @math.Euler::new(0.0, 0.0, 0.0)
  assert_eq(a.y, 0.0)
  a = @math.Euler::new(1.0, 2.0, 3.0)
  assert_eq(a.y, 2.0)
  a = @math.Euler::new(4.0, 5.0, 6.0, order="XYZ")
  assert_eq(a.y, 5.0)
  a = @math.Euler::new(7.0, 8.0, 9.0, order="XYZ")
  a.set_y(10.0)
  assert_eq(a.y, 10.0)
  a = @math.Euler::new(11.0, 12.0, 13.0, order="XYZ")
  let mut b = false
  ignore(a.on_change(() => b = true))
  a.set_y(14.0)
  assert_true(b)
  assert_eq(a.y, 14.0)
}

///|
test "Euler z" {
  let mut a = @math.Euler::new(0.0, 0.0, 0.0)
  assert_eq(a.z, 0.0)
  a = @math.Euler::new(1.0, 2.0, 3.0)
  assert_eq(a.z, 3.0)
  a = @math.Euler::new(4.0, 5.0, 6.0, order="XYZ")
  assert_eq(a.z, 6.0)
  a = @math.Euler::new(7.0, 8.0, 9.0, order="XYZ")
  a.set_z(10.0)
  assert_eq(a.z, 10.0)
  a = @math.Euler::new(11.0, 12.0, 13.0, order="XYZ")
  let mut b = false
  ignore(a.on_change(() => b = true))
  a.set_z(14.0)
  assert_true(b)
  assert_eq(a.z, 14.0)
}

///|
test "Euler order" {
  let mut a = @math.Euler::new(0.0, 0.0, 0.0)
  assert_eq(a.order, @math.EULER_DEFAULT_ORDER)
  a = @math.Euler::new(1.0, 2.0, 3.0)
  assert_eq(a.order, @math.EULER_DEFAULT_ORDER)
  a = @math.Euler::new(4.0, 5.0, 6.0, order="YZX")
  assert_eq(a.order, "YZX")
  a = @math.Euler::new(7.0, 8.0, 9.0, order="YZX")
  a.set_order("ZXY")
  assert_eq(a.order, "ZXY")
  a = @math.Euler::new(11.0, 12.0, 13.0, order="YZX")
  let mut b = false
  ignore(a.on_change(() => b = true))
  a.set_order("ZXY")
  assert_true(b)
  assert_eq(a.order, "ZXY")
}

///|
test "Euler clone/copy/equals" {
  let a = euler_test_axyz().clone()
  assert_true(a.equals(euler_test_axyz()))
  assert_true(!a.equals(euler_test_zero()))
  assert_true(!a.equals(euler_test_azyx()))
  ignore(a.copy(euler_test_azyx()))
  assert_true(a.equals(euler_test_azyx()))
  assert_true(!a.equals(euler_test_axyz()))
  assert_true(!a.equals(euler_test_zero()))
}

///|
test "Euler Quaternion.setFromEuler/Euler.setFromQuaternion" {
  let test_values = [euler_test_zero(), euler_test_axyz(), euler_test_azyx()]
  for v in test_values {
    let q = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(v)
    let v2 = @math.Euler::new(0.0, 0.0, 0.0).set_from_quaternion(
      q,
      order=v.order,
    )
    let q2 = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(v2)
    assert_true(euler_test_quat_equals(q, q2))
  }
}

///|
test "Euler Matrix4.makeRotationFromEuler/Euler.setFromRotationMatrix" {
  let test_values = [euler_test_zero(), euler_test_axyz(), euler_test_azyx()]
  for v in test_values {
    let m = @math.Matrix4::new().make_rotation_from_euler(v)
    let v2 = @math.Euler::new(0.0, 0.0, 0.0).set_from_rotation_matrix(
      m,
      order=v.order,
    )
    let m2 = @math.Matrix4::new().make_rotation_from_euler(v2)
    assert_true(matrix4_test_equals(m, m2, tolerance=0.0001))
  }
}

///|
test "Euler reorder" {
  let test_values = [euler_test_zero(), euler_test_axyz(), euler_test_azyx()]
  for v in test_values {
    let q = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(v)
    ignore(v.reorder("YZX"))
    let q2 = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(v)
    assert_true(euler_test_quat_equals(q, q2))
    ignore(v.reorder("ZXY"))
    let q3 = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(v)
    assert_true(euler_test_quat_equals(q, q3))
  }
}

///|
test "Euler set/get properties, check callbacks" {
  let a = @math.Euler::new(0.0, 0.0, 0.0)
  let mut steps = 0
  ignore(a.on_change(() => steps += 1))
  a.set_x(1.0)
  a.set_y(2.0)
  a.set_z(3.0)
  a.set_order("ZYX")
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  assert_eq(a.order, "ZYX")
  assert_eq(steps, 4)
}

///|
test "Euler clone/copy, check callbacks" {
  let mut a = @math.Euler::new(1.0, 2.0, 3.0, order="ZXY")
  let b = @math.Euler::new(4.0, 5.0, 6.0, order="XZY")
  let mut steps = 0
  let mut failures = 0
  let cb_succeed = () => steps += 1
  let cb_fail = () => failures += 1
  ignore(a.on_change(cb_fail))
  ignore(b.on_change(cb_fail))
  // clone doesn't trigger onChange
  a = b.clone()
  assert_true(a.equals(b))
  // copy triggers onChange once
  a = @math.Euler::new(1.0, 2.0, 3.0, order="ZXY")
  ignore(a.on_change(cb_succeed))
  ignore(a.copy(b))
  assert_true(a.equals(b))
  assert_eq(steps, 1)
  assert_eq(failures, 0)
}

///|
test "Euler toArray" {
  let order = "YXZ"
  let x = euler_test_x
  let y = euler_test_y
  let z = euler_test_z
  let a = @math.Euler::new(x, y, z, order~)
  let array = a.to_array()
  assert_eq(array[0], Json::number(x))
  assert_eq(array[1], Json::number(y))
  assert_eq(array[2], Json::number(z))
  assert_eq(array[3], Json::string(order))
  let array : Array[Json] = []
  ignore(a.to_array(array~))
  assert_eq(array[0], Json::number(x))
  assert_eq(array[1], Json::number(y))
  assert_eq(array[2], Json::number(z))
  assert_eq(array[3], Json::string(order))
  let array : Array[Json] = []
  ignore(a.to_array(array~, offset=1))
  assert_eq(array[0], Json::null())
  assert_eq(array[1], Json::number(x))
  assert_eq(array[2], Json::number(y))
  assert_eq(array[3], Json::number(z))
  assert_eq(array[4], Json::string(order))
}

///|
test "Euler fromArray" {
  let x = euler_test_x
  let y = euler_test_y
  let z = euler_test_z
  let mut a = @math.Euler::new(0.0, 0.0, 0.0)
  let mut array = [Json::number(x), Json::number(y), Json::number(z)]
  let mut steps = 0
  let cb = () => steps += 1
  ignore(a.on_change(cb))
  ignore(a.from_array(array))
  assert_eq(a.x, x)
  assert_eq(a.y, y)
  assert_eq(a.z, z)
  assert_eq(a.order, "XYZ")
  a = @math.Euler::new(0.0, 0.0, 0.0)
  array = [
    Json::number(x),
    Json::number(y),
    Json::number(z),
    Json::string("ZXY"),
  ]
  ignore(a.on_change(cb))
  ignore(a.from_array(array))
  assert_eq(a.x, x)
  assert_eq(a.y, y)
  assert_eq(a.z, z)
  assert_eq(a.order, "ZXY")
  assert_eq(steps, 2)
}

///|
test "Euler _onChange" {
  let f = () => ()
  let a = @math.Euler::new(11.0, 12.0, 13.0, order="XYZ")
  ignore(a.on_change(f))
  assert_true(physical_equal(a.on_change_callback, f))
}

///|
test "Euler _onChangeCallback" {
  let mut b = false
  let a = @math.Euler::new(11.0, 12.0, 13.0, order="XYZ")
  let f = () => b = true
  ignore(a.on_change(f))
  assert_true(physical_equal(a.on_change_callback, f))
  (a.on_change_callback)()
  assert_true(b)
}
