///|
test "Vector4: Instancing" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let mut a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  a = @math.Vector4::new(x, y, z, w)
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
}

///|
test "Vector4: set" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  a.set(x, y, z, w) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
}

///|
test "Vector4: setX" {
  let x = 2.0
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.x == 0.0)
  a.set_x(x) |> ignore
  assert_true(a.x == x)
}

///|
test "Vector4: setY" {
  let y = 3.0
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.y == 0.0)
  a.set_y(y) |> ignore
  assert_true(a.y == y)
}

///|
test "Vector4: setZ" {
  let z = 4.0
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.z == 0.0)
  a.set_z(z) |> ignore
  assert_true(a.z == z)
}

///|
test "Vector4: setW" {
  let w = 5.0
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.w == 1.0)
  a.set_w(w) |> ignore
  assert_true(a.w == w)
}

///|
test "Vector4: copy" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(0.0, 0.0, 0.0, 1.0).copy(a)
  assert_true(b.x == x)
  assert_true(b.y == y)
  assert_true(b.z == z)
  assert_true(b.w == w)
  a.x = 0.0
  a.y = -1.0
  a.z = -2.0
  a.w = -3.0
  assert_true(b.x == x)
  assert_true(b.y == y)
  assert_true(b.z == z)
  assert_true(b.w == w)
}

///|
test "Vector4: add" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(-x, -y, -z, -w)
  a.add(b) |> ignore
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 0.0)
}

///|
test "Vector4: addVectors" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let b = @math.Vector4::new(-x, -y, -z, -w)
  let c = @math.Vector4::new(0.0, 0.0, 0.0, 1.0).add_vectors(b, b)
  assert_true(c.x == -2.0 * x)
  assert_true(c.y == -2.0 * y)
  assert_true(c.z == -2.0 * z)
  assert_true(c.w == -2.0 * w)
}

///|
test "Vector4: addScaledVector" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(6.0, 7.0, 8.0, 9.0)
  let s = 3.0
  a.add_scaled_vector(b, s) |> ignore
  assert_eq(a.x, x + b.x * s)
  assert_eq(a.y, y + b.y * s)
  assert_eq(a.z, z + b.z * s)
  assert_eq(a.w, w + b.w * s)
}

///|
test "Vector4: sub" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(-x, -y, -z, -w)
  a.sub(b) |> ignore
  assert_true(a.x == 2.0 * x)
  assert_true(a.y == 2.0 * y)
  assert_true(a.z == 2.0 * z)
  assert_true(a.w == 2.0 * w)
}

///|
test "Vector4: subVectors" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let c = @math.Vector4::new(0.0, 0.0, 0.0, 1.0).sub_vectors(a, a)
  assert_true(c.x == 0.0)
  assert_true(c.y == 0.0)
  assert_true(c.z == 0.0)
  assert_true(c.w == 0.0)
}

///|
test "Vector4: applyMatrix4" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let eps = 0.0001
  let a = @math.Vector4::new(x, y, z, w)
  let m = @math.Matrix4::new().make_rotation_x(@cmath.PI)
  let expected = @math.Vector4::new(2.0, -3.0, -4.0, 5.0)
  a.apply_matrix4(m) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
  a.set(x, y, z, w) |> ignore
  m.make_translation(5.0, 7.0, 11.0) |> ignore
  expected.set(27.0, 38.0, 59.0, 5.0) |> ignore
  a.apply_matrix4(m) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
  a.set(x, y, z, w) |> ignore
  m.set(
    1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0,
  )
  |> ignore
  expected.set(2.0, 3.0, 4.0, 4.0) |> ignore
  a.apply_matrix4(m) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
  a.set(x, y, z, w) |> ignore
  m.set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  |> ignore
  expected.set(68.0, 224.0, 442.0, 664.0) |> ignore
  a.apply_matrix4(m) |> ignore
  assert_true((a.x - expected.x).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
  assert_true((a.z - expected.z).abs() <= eps)
  assert_true((a.w - expected.w).abs() <= eps)
}

///|
test "Vector4: divide" {
  let a = @math.Vector4::new(7.0, 8.0, 9.0, 0.0)
  let b = @math.Vector4::new(2.0, 2.0, 3.0, 4.0)
  a.divide(b) |> ignore
  assert_eq(a.x, 3.5)
  assert_eq(a.y, 4.0)
  assert_eq(a.z, 3.0)
  assert_eq(a.w, 0.0)
}

///|
test "Vector4: setFromMatrixPosition" {
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  let m = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  a.set_from_matrix_position(m) |> ignore
  assert_eq(a.x, 7.0)
  assert_eq(a.y, 19.0)
  assert_eq(a.z, 37.0)
  assert_eq(a.w, 53.0)
}

///|
test "Vector4: clampScalar" {
  let eps = 0.0001
  let a = @math.Vector4::new(-0.1, 0.01, 0.5, 1.5)
  let clamped = @math.Vector4::new(0.1, 0.1, 0.5, 1.0)
  a.clamp_scalar(0.1, 1.0) |> ignore
  assert_true((a.x - clamped.x).abs() <= eps)
  assert_true((a.y - clamped.y).abs() <= eps)
  assert_true((a.z - clamped.z).abs() <= eps)
  assert_true((a.w - clamped.w).abs() <= eps)
}

///|
test "Vector4: negate" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  a.negate() |> ignore
  assert_true(a.x == -x)
  assert_true(a.y == -y)
  assert_true(a.z == -z)
  assert_true(a.w == -w)
}

///|
test "Vector4: dot" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(-x, -y, -z, -w)
  let c = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
  let mut result = a.dot(b)
  assert_true(result == -x * x - y * y - z * z - w * w)
  result = a.dot(c)
  assert_true(result == 0.0)
}

///|
test "Vector4: manhattanLength" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, 0.0, 0.0, 0.0)
  let b = @math.Vector4::new(0.0, -y, 0.0, 0.0)
  let c = @math.Vector4::new(0.0, 0.0, z, 0.0)
  let d = @math.Vector4::new(0.0, 0.0, 0.0, w)
  let e = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
  assert_true(a.manhattan_length() == x)
  assert_true(b.manhattan_length() == y)
  assert_true(c.manhattan_length() == z)
  assert_true(d.manhattan_length() == w)
  assert_true(e.manhattan_length() == 0.0)
  a.set(x, y, z, w) |> ignore
  assert_true(a.manhattan_length() == x.abs() + y.abs() + z.abs() + w.abs())
}

///|
test "Vector4: normalize" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, 0.0, 0.0, 0.0)
  let b = @math.Vector4::new(0.0, -y, 0.0, 0.0)
  let c = @math.Vector4::new(0.0, 0.0, z, 0.0)
  let d = @math.Vector4::new(0.0, 0.0, 0.0, -w)
  a.normalize() |> ignore
  assert_true(a.length() == 1.0)
  assert_true(a.x == 1.0)
  b.normalize() |> ignore
  assert_true(b.length() == 1.0)
  assert_true(b.y == -1.0)
  c.normalize() |> ignore
  assert_true(c.length() == 1.0)
  assert_true(c.z == 1.0)
  d.normalize() |> ignore
  assert_true(d.length() == 1.0)
  assert_true(d.w == -1.0)
}

///|
test "Vector4: setLength" {
  let x = 2.0
  let y = 3.0
  let mut a = @math.Vector4::new(x, 0.0, 0.0, 0.0)
  assert_true(a.length() == x)
  a.set_length(y) |> ignore
  assert_true(a.length() == y)
  a = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
  assert_true(a.length() == 0.0)
  a.set_length(y) |> ignore
  assert_true(a.length() == 0.0)
  // upstream calls setLength() with no argument, which multiplies by undefined
  a.set_length(0.0 / 0.0) |> ignore
  assert_true(a.length().is_nan())
}

///|
test "Vector4: equals" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, 0.0, z, 0.0)
  let b = @math.Vector4::new(0.0, -y, 0.0, -w)
  assert_true(a.x != b.x)
  assert_true(a.y != b.y)
  assert_true(a.z != b.z)
  assert_true(a.w != b.w)
  assert_true(!a.equals(b))
  assert_true(!b.equals(a))
  a.copy(b) |> ignore
  assert_true(a.x == b.x)
  assert_true(a.y == b.y)
  assert_true(a.z == b.z)
  assert_true(a.w == b.w)
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Vector4: fromArray" {
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  let array = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
  a.from_array(array) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  assert_eq(a.w, 4.0)
  a.from_array(array, offset=4) |> ignore
  assert_eq(a.x, 5.0)
  assert_eq(a.y, 6.0)
  assert_eq(a.z, 7.0)
  assert_eq(a.w, 8.0)
}

///|
test "Vector4: toArray" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let mut array = a.to_array()
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  assert_eq(array[2], z)
  assert_eq(array[3], w)
  array = []
  a.to_array(array~) |> ignore
  assert_eq(array[0], x)
  assert_eq(array[1], y)
  assert_eq(array[2], z)
  assert_eq(array[3], w)
  array = []
  a.to_array(array~, offset=1) |> ignore
  assert_true(array[0].is_nan())
  assert_eq(array[1], x)
  assert_eq(array[2], y)
  assert_eq(array[3], z)
  assert_eq(array[4], w)
}

///|
test "Vector4: fromBufferAttribute" {
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  let attr = VectorTestAttribute::new(
    [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0],
    4,
  )
  a.from_buffer_attribute(attr, 0) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  assert_eq(a.w, 4.0)
  a.from_buffer_attribute(attr, 1) |> ignore
  assert_eq(a.x, 5.0)
  assert_eq(a.y, 6.0)
  assert_eq(a.z, 7.0)
  assert_eq(a.w, 8.0)
}

///|
test "Vector4: setX,setY,setZ,setW" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  a.set_x(x) |> ignore
  a.set_y(y) |> ignore
  a.set_z(z) |> ignore
  a.set_w(w) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
}

///|
test "Vector4: setComponent,getComponent" {
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  assert_true(a.x == 0.0)
  assert_true(a.y == 0.0)
  assert_true(a.z == 0.0)
  assert_true(a.w == 1.0)
  a.set_component(0, 1.0) |> ignore
  a.set_component(1, 2.0) |> ignore
  a.set_component(2, 3.0) |> ignore
  a.set_component(3, 4.0) |> ignore
  assert_true(a.get_component(0) == 1.0)
  assert_true(a.get_component(1) == 2.0)
  assert_true(a.get_component(2) == 3.0)
  assert_true(a.get_component(3) == 4.0)
}

///|
test "Vector4: setScalar/addScalar/subScalar" {
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  let s = 3.0
  a.set_scalar(s) |> ignore
  assert_eq(a.x, s)
  assert_eq(a.y, s)
  assert_eq(a.z, s)
  assert_eq(a.w, s)
  a.add_scalar(s) |> ignore
  assert_eq(a.x, 2.0 * s)
  assert_eq(a.y, 2.0 * s)
  assert_eq(a.z, 2.0 * s)
  assert_eq(a.w, 2.0 * s)
  a.sub_scalar(2.0 * s) |> ignore
  assert_eq(a.x, 0.0)
  assert_eq(a.y, 0.0)
  assert_eq(a.z, 0.0)
  assert_eq(a.w, 0.0)
}

///|
test "Vector4: multiplyScalar/divideScalar" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(-x, -y, -z, -w)
  a.multiply_scalar(-2.0) |> ignore
  assert_true(a.x == x * -2.0)
  assert_true(a.y == y * -2.0)
  assert_true(a.z == z * -2.0)
  assert_true(a.w == w * -2.0)
  b.multiply_scalar(-2.0) |> ignore
  assert_true(b.x == 2.0 * x)
  assert_true(b.y == 2.0 * y)
  assert_true(b.z == 2.0 * z)
  assert_true(b.w == 2.0 * w)
  a.divide_scalar(-2.0) |> ignore
  assert_true(a.x == x)
  assert_true(a.y == y)
  assert_true(a.z == z)
  assert_true(a.w == w)
  b.divide_scalar(-2.0) |> ignore
  assert_true(b.x == -x)
  assert_true(b.y == -y)
  assert_true(b.z == -z)
  assert_true(b.w == -w)
}

///|
test "Vector4: min/max/clamp" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, y, z, w)
  let b = @math.Vector4::new(-x, -y, -z, -w)
  let c = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  c.copy(a).min(b) |> ignore
  assert_true(c.x == -x)
  assert_true(c.y == -y)
  assert_true(c.z == -z)
  assert_true(c.w == -w)
  c.copy(a).max(b) |> ignore
  assert_true(c.x == x)
  assert_true(c.y == y)
  assert_true(c.z == z)
  assert_true(c.w == w)
  c.set(-2.0 * x, 2.0 * y, -2.0 * z, 2.0 * w) |> ignore
  c.clamp(b, a) |> ignore
  assert_true(c.x == -x)
  assert_true(c.y == y)
  assert_true(c.z == -z)
  assert_true(c.w == w)
}

///|
test "Vector4: length/lengthSq" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, 0.0, 0.0, 0.0)
  let b = @math.Vector4::new(0.0, -y, 0.0, 0.0)
  let c = @math.Vector4::new(0.0, 0.0, z, 0.0)
  let d = @math.Vector4::new(0.0, 0.0, 0.0, w)
  let e = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
  assert_true(a.length() == x)
  assert_true(a.length_sq() == x * x)
  assert_true(b.length() == y)
  assert_true(b.length_sq() == y * y)
  assert_true(c.length() == z)
  assert_true(c.length_sq() == z * z)
  assert_true(d.length() == w)
  assert_true(d.length_sq() == w * w)
  assert_true(e.length() == 0.0)
  assert_true(e.length_sq() == 0.0)
  a.set(x, y, z, w) |> ignore
  assert_true(a.length() == (x * x + y * y + z * z + w * w).sqrt())
  assert_true(a.length_sq() == x * x + y * y + z * z + w * w)
}

///|
test "Vector4: lerp/clone" {
  let x = 2.0
  let y = 3.0
  let z = 4.0
  let w = 5.0
  let a = @math.Vector4::new(x, 0.0, z, 0.0)
  let b = @math.Vector4::new(0.0, -y, 0.0, -w)
  assert_true(a.lerp(a, 0.0).equals(a.lerp(a, 0.5)))
  assert_true(a.lerp(a, 0.0).equals(a.lerp(a, 1.0)))
  assert_true(a.clone().lerp(b, 0.0).equals(a))
  assert_true(a.clone().lerp(b, 0.5).x == x * 0.5)
  assert_true(a.clone().lerp(b, 0.5).y == -y * 0.5)
  assert_true(a.clone().lerp(b, 0.5).z == z * 0.5)
  assert_true(a.clone().lerp(b, 0.5).w == -w * 0.5)
  assert_true(a.clone().lerp(b, 1.0).equals(b))
}

///|
test "panic Vector4: set_component out of range" {
  @math.Vector4::new(0.0, 0.0, 0.0, 1.0).set_component(4, 0.0) |> ignore
}

///|
test "panic Vector4: get_component out of range" {
  @math.Vector4::new(0.0, 0.0, 0.0, 1.0).get_component(4) |> ignore
}

// The rest have no upstream test: they exercise ported overloads and members.

///|
test "Vector4: copy_vector3 sets w to 1" {
  let a = @math.Vector4::new(0.0, 0.0, 0.0, 5.0)
  a.copy_vector3(@math.Vector3::new(1.0, 2.0, 3.0)) |> ignore
  assert_eq(a.x, 1.0)
  assert_eq(a.y, 2.0)
  assert_eq(a.z, 3.0)
  assert_eq(a.w, 1.0)
}

///|
test "Vector4: width and height alias z and w" {
  let a = @math.Vector4::new(1.0, 2.0, 3.0, 4.0)
  assert_eq(a.width(), 3.0)
  assert_eq(a.height(), 4.0)
  a.set_width(5.0)
  a.set_height(6.0)
  assert_eq(a.z, 5.0)
  assert_eq(a.w, 6.0)
}
