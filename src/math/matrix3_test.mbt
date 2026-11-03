///|
fn matrix_test_equals(
  b : Array[Double],
  a : Array[Double],
  tolerance~ : Double = 0.0001,
) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    let delta = (a[i] - b[i]).abs()
    if delta > tolerance {
      return false
    }
  }
  true
}

///|
fn matrix_test_to_matrix4(m3 : @math.Matrix3) -> @math.Matrix4 {
  let result = @math.Matrix4::new()
  let re = result.elements
  let me = m3.elements
  re[0] = me[0]
  re[1] = me[1]
  re[2] = me[2]
  re[4] = me[3]
  re[5] = me[4]
  re[6] = me[5]
  re[8] = me[6]
  re[9] = me[7]
  re[10] = me[8]
  result
}

///|
test "Matrix3: Instancing" {
  let a = @math.Matrix3::new()
  assert_true(a.determinant() == 1.0)
  let b = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  assert_true(b.elements[0] == 0.0)
  assert_true(b.elements[1] == 3.0)
  assert_true(b.elements[2] == 6.0)
  assert_true(b.elements[3] == 1.0)
  assert_true(b.elements[4] == 4.0)
  assert_true(b.elements[5] == 7.0)
  assert_true(b.elements[6] == 2.0)
  assert_true(b.elements[7] == 5.0)
  assert_true(b.elements[8] == 8.0)
  assert_true(!matrix_test_equals(a.elements, b.elements))
  let c = @math.Matrix3::new(
    n11=0.0,
    n12=1.0,
    n13=2.0,
    n21=3.0,
    n22=4.0,
    n23=5.0,
    n31=6.0,
    n32=7.0,
    n33=8.0,
  )
  assert_true(c.elements[0] == 0.0)
  assert_true(c.elements[1] == 3.0)
  assert_true(c.elements[2] == 6.0)
  assert_true(c.elements[3] == 1.0)
  assert_true(c.elements[4] == 4.0)
  assert_true(c.elements[5] == 7.0)
  assert_true(c.elements[6] == 2.0)
  assert_true(c.elements[7] == 5.0)
  assert_true(c.elements[8] == 8.0)
  assert_true(!matrix_test_equals(a.elements, c.elements))
}

///|
test "Matrix3: set" {
  let b = @math.Matrix3::new()
  assert_true(b.determinant() == 1.0)
  b.set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0) |> ignore
  assert_true(b.elements[0] == 0.0)
  assert_true(b.elements[1] == 3.0)
  assert_true(b.elements[2] == 6.0)
  assert_true(b.elements[3] == 1.0)
  assert_true(b.elements[4] == 4.0)
  assert_true(b.elements[5] == 7.0)
  assert_true(b.elements[6] == 2.0)
  assert_true(b.elements[7] == 5.0)
  assert_true(b.elements[8] == 8.0)
}

///|
test "Matrix3: identity" {
  let b = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  assert_true(b.elements[0] == 0.0)
  assert_true(b.elements[1] == 3.0)
  assert_true(b.elements[2] == 6.0)
  assert_true(b.elements[3] == 1.0)
  assert_true(b.elements[4] == 4.0)
  assert_true(b.elements[5] == 7.0)
  assert_true(b.elements[6] == 2.0)
  assert_true(b.elements[7] == 5.0)
  assert_true(b.elements[8] == 8.0)
  let a = @math.Matrix3::new()
  assert_true(!matrix_test_equals(a.elements, b.elements))
  b.identity() |> ignore
  assert_true(matrix_test_equals(a.elements, b.elements))
}

///|
test "Matrix3: clone" {
  let a = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let b = a.clone()
  assert_true(matrix_test_equals(a.elements, b.elements))
  a.elements[0] = 2.0
  assert_true(!matrix_test_equals(a.elements, b.elements))
}

///|
test "Matrix3: copy" {
  let a = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let b = @math.Matrix3::new().copy(a)
  assert_true(matrix_test_equals(a.elements, b.elements))
  a.elements[0] = 2.0
  assert_true(!matrix_test_equals(a.elements, b.elements))
}

///|
test "Matrix3: setFromMatrix4" {
  let a = @math.Matrix4::new().set(
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0,
  )
  let b = @math.Matrix3::new()
  let c = @math.Matrix3::new().set(0.0, 1.0, 2.0, 4.0, 5.0, 6.0, 8.0, 9.0, 10.0)
  b.set_from_matrix4(a) |> ignore
  assert_true(b.equals(c))
}

///|
test "Matrix3: multiply/premultiply" {
  let a = @math.Matrix3::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0,
  )
  let b = @math.Matrix3::new().set(
    29.0, 31.0, 37.0, 41.0, 43.0, 47.0, 53.0, 59.0, 61.0,
  )
  let expected_multiply = [
    446.0, 1343.0, 2491.0, 486.0, 1457.0, 2701.0, 520.0, 1569.0, 2925.0,
  ]
  let expected_premultiply = [
    904.0, 1182.0, 1556.0, 1131.0, 1489.0, 1967.0, 1399.0, 1845.0, 2435.0,
  ]
  a.multiply(b) |> ignore
  assert_eq(a.elements, expected_multiply)
  a.set(2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0) |> ignore
  a.premultiply(b) |> ignore
  assert_eq(a.elements, expected_premultiply)
}

///|
test "Matrix3: multiplyMatrices" {
  let lhs = @math.Matrix3::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0,
  )
  let rhs = @math.Matrix3::new().set(
    29.0, 31.0, 37.0, 41.0, 43.0, 47.0, 53.0, 59.0, 61.0,
  )
  let ans = @math.Matrix3::new()
  ans.multiply_matrices(lhs, rhs) |> ignore
  assert_true(ans.elements[0] == 446.0)
  assert_true(ans.elements[1] == 1343.0)
  assert_true(ans.elements[2] == 2491.0)
  assert_true(ans.elements[3] == 486.0)
  assert_true(ans.elements[4] == 1457.0)
  assert_true(ans.elements[5] == 2701.0)
  assert_true(ans.elements[6] == 520.0)
  assert_true(ans.elements[7] == 1569.0)
  assert_true(ans.elements[8] == 2925.0)
}

///|
test "Matrix3: multiplyScalar" {
  let b = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  assert_true(b.elements[0] == 0.0)
  assert_true(b.elements[1] == 3.0)
  assert_true(b.elements[2] == 6.0)
  assert_true(b.elements[3] == 1.0)
  assert_true(b.elements[4] == 4.0)
  assert_true(b.elements[5] == 7.0)
  assert_true(b.elements[6] == 2.0)
  assert_true(b.elements[7] == 5.0)
  assert_true(b.elements[8] == 8.0)
  b.multiply_scalar(2.0) |> ignore
  assert_true(b.elements[0] == 0.0 * 2.0)
  assert_true(b.elements[1] == 3.0 * 2.0)
  assert_true(b.elements[2] == 6.0 * 2.0)
  assert_true(b.elements[3] == 1.0 * 2.0)
  assert_true(b.elements[4] == 4.0 * 2.0)
  assert_true(b.elements[5] == 7.0 * 2.0)
  assert_true(b.elements[6] == 2.0 * 2.0)
  assert_true(b.elements[7] == 5.0 * 2.0)
  assert_true(b.elements[8] == 8.0 * 2.0)
}

///|
test "Matrix3: determinant" {
  let a = @math.Matrix3::new()
  assert_true(a.determinant() == 1.0)
  a.elements[0] = 2.0
  assert_true(a.determinant() == 2.0)
  a.elements[0] = 0.0
  assert_true(a.determinant() == 0.0)
  a.set(2.0, 3.0, 4.0, 5.0, 13.0, 7.0, 8.0, 9.0, 11.0) |> ignore
  assert_true(a.determinant() == -73.0)
}

///|
test "Matrix3: invert" {
  let zero = @math.Matrix3::new().set(
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  )
  let identity4 = @math.Matrix4::new()
  let a = @math.Matrix3::new().set(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  let b = @math.Matrix3::new()
  b.copy(a).invert() |> ignore
  assert_true(matrix_test_equals(b.elements, zero.elements))
  let test_matrices = [
    @math.Matrix4::new().make_rotation_x(0.3),
    @math.Matrix4::new().make_rotation_x(-0.3),
    @math.Matrix4::new().make_rotation_y(0.3),
    @math.Matrix4::new().make_rotation_y(-0.3),
    @math.Matrix4::new().make_rotation_z(0.3),
    @math.Matrix4::new().make_rotation_z(-0.3),
    @math.Matrix4::new().make_scale(1.0, 2.0, 3.0),
    @math.Matrix4::new().make_scale(1.0 / 8.0, 1.0 / 2.0, 1.0 / 3.0),
  ]
  for m in test_matrices {
    a.set_from_matrix4(m) |> ignore
    let m_inverse3 = b.copy(a).invert()
    let m_inverse = matrix_test_to_matrix4(m_inverse3)
    // the determinant of the inverse should be the reciprocal
    assert_true(
      (a.determinant() * m_inverse3.determinant() - 1.0).abs() < 0.0001,
    )
    assert_true(
      (m.determinant() * m_inverse.determinant() - 1.0).abs() < 0.0001,
    )
    let m_product = @math.Matrix4::new().multiply_matrices(m, m_inverse)
    assert_true((m_product.determinant() - 1.0).abs() < 0.0001)
    assert_true(matrix_test_equals(m_product.elements, identity4.elements))
  }
}

///|
test "Matrix3: transpose" {
  let a = @math.Matrix3::new()
  let mut b = a.clone().transpose()
  assert_true(matrix_test_equals(a.elements, b.elements))
  b = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let c = b.clone().transpose()
  assert_true(!matrix_test_equals(b.elements, c.elements))
  c.transpose() |> ignore
  assert_true(matrix_test_equals(b.elements, c.elements))
}

///|
test "Matrix3: getNormalMatrix" {
  let a = @math.Matrix3::new()
  let b = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 57.0,
  )
  let expected = @math.Matrix3::new().set(
    -1.2857142857142856, 0.7142857142857143, 0.2857142857142857, 0.7428571428571429,
    -0.7571428571428571, 0.15714285714285714, -0.19999999999999998, 0.3, -0.09999999999999999,
  )
  a.get_normal_matrix(b) |> ignore
  assert_true(matrix_test_equals(a.elements, expected.elements))
}

///|
test "Matrix3: transposeIntoArray" {
  let a = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let b : Array[Double] = []
  a.transpose_into_array(b) |> ignore
  assert_true(b[0] == 0.0)
  assert_true(b[1] == 1.0)
  assert_true(b[2] == 2.0)
  assert_true(b[3] == 3.0)
  assert_true(b[4] == 4.0)
  assert_true(b[5] == 5.0)
  assert_true(b[5] == 5.0)
  assert_true(b[6] == 6.0)
  assert_true(b[7] == 7.0)
  assert_true(b[8] == 8.0)
}

///|
test "Matrix3: setUvTransform" {
  let a = @math.Matrix3::new().set(
    0.1767766952966369, 0.17677669529663687, 0.32322330470336313, -0.17677669529663687,
    0.1767766952966369, 0.5, 0.0, 0.0, 1.0,
  )
  let expected = @math.Matrix3::new().set(
    0.1785355940258599, 0.17500011904519763, 0.32323214346447127, -0.17500011904519763,
    0.1785355940258599, 0.4982322625096689, 0.0, 0.0, 1.0,
  )
  a.set_uv_transform(0.0, 0.0, 0.25, 0.25, 0.7753981633974483, 0.5, 0.5)
  |> ignore
  assert_true(matrix_test_equals(a.elements, expected.elements))
}

///|
test "Matrix3: makeTranslation" {
  let a = @math.Matrix3::new()
  let b = @math.Vector2::new(1.0, 2.0)
  let c = @math.Matrix3::new().set(1.0, 0.0, 1.0, 0.0, 1.0, 2.0, 0.0, 0.0, 1.0)
  a.make_translation(b.x, b.y) |> ignore
  assert_true(matrix_test_equals(a.elements, c.elements))
  a.make_translation_vector(b) |> ignore
  assert_true(matrix_test_equals(a.elements, c.elements))
}

///|
test "Matrix3: equals" {
  let a = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let b = @math.Matrix3::new().set(0.0, -1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  assert_true(!a.equals(b))
  assert_true(!b.equals(a))
  a.copy(b) |> ignore
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Matrix3: fromArray" {
  let mut b = @math.Matrix3::new()
  b.from_array([0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]) |> ignore
  assert_true(b.elements[0] == 0.0)
  assert_true(b.elements[1] == 1.0)
  assert_true(b.elements[2] == 2.0)
  assert_true(b.elements[3] == 3.0)
  assert_true(b.elements[4] == 4.0)
  assert_true(b.elements[5] == 5.0)
  assert_true(b.elements[6] == 6.0)
  assert_true(b.elements[7] == 7.0)
  assert_true(b.elements[8] == 8.0)
  b = @math.Matrix3::new()
  b.from_array(
    [
      0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
      15.0, 16.0, 17.0, 18.0,
    ],
    offset=10,
  )
  |> ignore
  assert_true(b.elements[0] == 10.0)
  assert_true(b.elements[1] == 11.0)
  assert_true(b.elements[2] == 12.0)
  assert_true(b.elements[3] == 13.0)
  assert_true(b.elements[4] == 14.0)
  assert_true(b.elements[5] == 15.0)
  assert_true(b.elements[6] == 16.0)
  assert_true(b.elements[7] == 17.0)
  assert_true(b.elements[8] == 18.0)
}

///|
test "Matrix3: toArray" {
  let a = @math.Matrix3::new().set(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0)
  let no_offset = [1.0, 4.0, 7.0, 2.0, 5.0, 8.0, 3.0, 6.0, 9.0]
  let mut array = a.to_array()
  assert_eq(array, no_offset)
  array = []
  a.to_array(array~) |> ignore
  assert_eq(array, no_offset)
  array = []
  a.to_array(array~, offset=1) |> ignore
  assert_eq(array.length(), 10)
  assert_true(array[0].is_nan())
  assert_eq(array[1:].to_owned(), no_offset)
}
