///|
/// Upstream's `eps` from `math-constants.js`.
let matrix4_test_eps : Double = 0.0001

///|
fn matrix4_test_equals(
  a : @math.Matrix4,
  b : @math.Matrix4,
  tolerance~ : Double = 0.0001,
) -> Bool {
  if a.elements.length() != b.elements.length() {
    return false
  }
  for i in 0..<a.elements.length() {
    let delta = (a.elements[i] - b.elements[i]).abs()
    if delta > tolerance {
      return false
    }
  }
  true
}

///|
fn matrix4_test_euler_equals(
  a : @math.Euler,
  b : @math.Euler,
  tolerance~ : Double = 0.0001,
) -> Bool {
  let diff = (a.x - b.x).abs() + (a.y - b.y).abs() + (a.z - b.z).abs()
  diff < tolerance
}

///|
/// `new Matrix4().set( 0, 1, ..., 15 )`.
fn matrix4_test_sequence() -> @math.Matrix4 {
  @math.Matrix4::new().set(
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0,
  )
}

///|
fn matrix4_test_v3() -> @math.Vector3 {
  @math.Vector3::new(0.0, 0.0, 0.0)
}

///|
test "Matrix4 Instancing" {
  let a = @math.Matrix4::new()
  assert_true(a.determinant() == 1.0)
  let b = matrix4_test_sequence()
  assert_eq(b.elements, [
    0.0, 4.0, 8.0, 12.0, 1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0,
    15.0,
  ])
  assert_true(!matrix4_test_equals(a, b))
  let c = @math.Matrix4::new_with(
    0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0,
  )
  assert_eq(c.elements, [
    0.0, 4.0, 8.0, 12.0, 1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0,
    15.0,
  ])
  assert_true(!matrix4_test_equals(a, c))
}

///|
test "Matrix4 set" {
  let b = @math.Matrix4::new()
  assert_true(b.determinant() == 1.0)
  ignore(
    b.set(
      0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
      15.0,
    ),
  )
  assert_eq(b.elements, [
    0.0, 4.0, 8.0, 12.0, 1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0,
    15.0,
  ])
}

///|
test "Matrix4 identity" {
  let b = matrix4_test_sequence()
  assert_eq(b.elements, [
    0.0, 4.0, 8.0, 12.0, 1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0,
    15.0,
  ])
  let a = @math.Matrix4::new()
  assert_true(!matrix4_test_equals(a, b))
  ignore(b.identity())
  assert_true(matrix4_test_equals(a, b))
}

///|
test "Matrix4 clone" {
  let a = matrix4_test_sequence()
  let b = a.clone()
  assert_true(matrix4_test_equals(a, b))
  // ensure that it is a true copy
  a.elements[0] = 2.0
  assert_true(!matrix4_test_equals(a, b))
}

///|
test "Matrix4 copy" {
  let a = matrix4_test_sequence()
  let b = @math.Matrix4::new().copy(a)
  assert_true(matrix4_test_equals(a, b))
  // ensure that it is a true copy
  a.elements[0] = 2.0
  assert_true(!matrix4_test_equals(a, b))
}

///|
test "Matrix4 setFromMatrix3" {
  let a = @math.Matrix3::new().set(0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0)
  let b = @math.Matrix4::new()
  let c = @math.Matrix4::new().set(
    0.0, 1.0, 2.0, 0.0, 3.0, 4.0, 5.0, 0.0, 6.0, 7.0, 8.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(b.set_from_matrix3(a))
  assert_true(b.equals(c))
}

///|
test "Matrix4 copyPosition" {
  let a = @math.Matrix4::new().set(
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
    16.0,
  )
  let b = @math.Matrix4::new().set(
    1.0, 2.0, 3.0, 0.0, 5.0, 6.0, 7.0, 0.0, 9.0, 10.0, 11.0, 0.0, 13.0, 14.0, 15.0,
    16.0,
  )
  assert_true(!matrix4_test_equals(a, b))
  ignore(b.copy_position(a))
  assert_true(matrix4_test_equals(a, b))
}

///|
test "Matrix4 makeBasis/extractBasis" {
  let identity_basis = [
    @math.Vector3::new(1.0, 0.0, 0.0),
    @math.Vector3::new(0.0, 1.0, 0.0),
    @math.Vector3::new(0.0, 0.0, 1.0),
  ]
  let a = @math.Matrix4::new().make_basis(
    identity_basis[0],
    identity_basis[1],
    identity_basis[2],
  )
  let identity = @math.Matrix4::new()
  assert_true(matrix4_test_equals(a, identity))
  let test_bases = [
    [
      @math.Vector3::new(0.0, 1.0, 0.0),
      @math.Vector3::new(-1.0, 0.0, 0.0),
      @math.Vector3::new(0.0, 0.0, 1.0),
    ],
  ]
  for test_basis in test_bases {
    let b = @math.Matrix4::new().make_basis(
      test_basis[0],
      test_basis[1],
      test_basis[2],
    )
    let out_basis = [matrix4_test_v3(), matrix4_test_v3(), matrix4_test_v3()]
    ignore(b.extract_basis(out_basis[0], out_basis[1], out_basis[2]))
    // check what goes in, is what comes out.
    for j in 0..<out_basis.length() {
      assert_true(out_basis[j].equals(test_basis[j]))
    }
    // get the basis out the hard war
    for j in 0..<identity_basis.length() {
      ignore(out_basis[j].copy(identity_basis[j]))
      ignore(out_basis[j].apply_matrix4(b))
    }
    // did the multiply method of basis extraction work?
    for j in 0..<out_basis.length() {
      assert_true(out_basis[j].equals(test_basis[j]))
    }
  }
}

///|
test "Matrix4 extractBasis of a singular matrix" {
  let m = @math.Matrix4::new().make_scale(0.0, 1.0, 1.0)
  let x = matrix4_test_v3()
  let y = matrix4_test_v3()
  let z = matrix4_test_v3()
  ignore(m.extract_basis(x, y, z))
  assert_true(x.equals(@math.Vector3::new(1.0, 0.0, 0.0)))
  assert_true(y.equals(@math.Vector3::new(0.0, 1.0, 0.0)))
  assert_true(z.equals(@math.Vector3::new(0.0, 0.0, 1.0)))
}

///|
test "Matrix4 makeRotationFromEuler/extractRotation" {
  let test_values = [
    @math.Euler::new(0.0, 0.0, 0.0, order="XYZ"),
    @math.Euler::new(1.0, 0.0, 0.0, order="XYZ"),
    @math.Euler::new(0.0, 1.0, 0.0, order="ZYX"),
    @math.Euler::new(0.0, 0.0, 0.5, order="YZX"),
    @math.Euler::new(0.0, 0.0, -0.5, order="YZX"),
  ]
  let eps = matrix4_test_eps
  for v in test_values {
    let m = @math.Matrix4::new().make_rotation_from_euler(v)
    let v2 = @math.Euler::new(0.0, 0.0, 0.0).set_from_rotation_matrix(
      m,
      order=v.order,
    )
    let m2 = @math.Matrix4::new().make_rotation_from_euler(v2)
    assert_true(matrix4_test_equals(m, m2, tolerance=eps))
    assert_true(matrix4_test_euler_equals(v, v2, tolerance=eps))
    let m3 = @math.Matrix4::new().extract_rotation(m2)
    let v3 = @math.Euler::new(0.0, 0.0, 0.0).set_from_rotation_matrix(
      m3,
      order=v.order,
    )
    assert_true(matrix4_test_equals(m, m3, tolerance=eps))
    assert_true(matrix4_test_euler_equals(v, v3, tolerance=eps))
  }
}

///|
test "Matrix4 lookAt" {
  let a = @math.Matrix4::new()
  let expected = @math.Matrix4::new().identity()
  let eye = @math.Vector3::new(0.0, 0.0, 0.0)
  let target = @math.Vector3::new(0.0, 1.0, -1.0)
  let up = @math.Vector3::new(0.0, 1.0, 0.0)
  ignore(a.look_at(eye, target, up))
  let rotation = @math.Euler::new(0.0, 0.0, 0.0).set_from_rotation_matrix(a)
  // assert.numEqual
  assert_true((rotation.x * (180.0 / @cmath.PI) - 45.0).abs() < 0.1)
  // eye and target are in the same position
  ignore(eye.copy(target))
  ignore(a.look_at(eye, target, up))
  assert_true(matrix4_test_equals(a, expected))
  // up and z are parallel
  ignore(eye.set(0.0, 1.0, 0.0))
  ignore(target.set(0.0, 0.0, 0.0))
  ignore(a.look_at(eye, target, up))
  ignore(
    expected.set(
      1.0, 0.0, 0.0, 0.0, 0.0, 0.0001, 1.0, 0.0, 0.0, -1.0, 0.0001, 0.0, 0.0, 0.0,
      0.0, 1.0,
    ),
  )
  assert_true(matrix4_test_equals(a, expected))
}

///|
test "Matrix4 multiply" {
  let lhs = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  let rhs = @math.Matrix4::new().set(
    59.0, 61.0, 67.0, 71.0, 73.0, 79.0, 83.0, 89.0, 97.0, 101.0, 103.0, 107.0, 109.0,
    113.0, 127.0, 131.0,
  )
  ignore(lhs.multiply(rhs))
  assert_eq(lhs.elements, [
    1585.0, 5318.0, 10514.0, 15894.0, 1655.0, 5562.0, 11006.0, 16634.0, 1787.0, 5980.0,
    11840.0, 17888.0, 1861.0, 6246.0, 12378.0, 18710.0,
  ])
}

///|
test "Matrix4 premultiply" {
  let lhs = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  let rhs = @math.Matrix4::new().set(
    59.0, 61.0, 67.0, 71.0, 73.0, 79.0, 83.0, 89.0, 97.0, 101.0, 103.0, 107.0, 109.0,
    113.0, 127.0, 131.0,
  )
  ignore(rhs.premultiply(lhs))
  assert_eq(rhs.elements, [
    1585.0, 5318.0, 10514.0, 15894.0, 1655.0, 5562.0, 11006.0, 16634.0, 1787.0, 5980.0,
    11840.0, 17888.0, 1861.0, 6246.0, 12378.0, 18710.0,
  ])
}

///|
test "Matrix4 multiplyMatrices" {
  let lhs = @math.Matrix4::new().set(
    2.0, 3.0, 5.0, 7.0, 11.0, 13.0, 17.0, 19.0, 23.0, 29.0, 31.0, 37.0, 41.0, 43.0,
    47.0, 53.0,
  )
  let rhs = @math.Matrix4::new().set(
    59.0, 61.0, 67.0, 71.0, 73.0, 79.0, 83.0, 89.0, 97.0, 101.0, 103.0, 107.0, 109.0,
    113.0, 127.0, 131.0,
  )
  let ans = @math.Matrix4::new()
  ignore(ans.multiply_matrices(lhs, rhs))
  assert_eq(ans.elements, [
    1585.0, 5318.0, 10514.0, 15894.0, 1655.0, 5562.0, 11006.0, 16634.0, 1787.0, 5980.0,
    11840.0, 17888.0, 1861.0, 6246.0, 12378.0, 18710.0,
  ])
}

///|
test "Matrix4 multiplyScalar" {
  let b = matrix4_test_sequence()
  assert_eq(b.elements, [
    0.0, 4.0, 8.0, 12.0, 1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0,
    15.0,
  ])
  ignore(b.multiply_scalar(2.0))
  assert_eq(b.elements, [
    0.0, 8.0, 16.0, 24.0, 2.0, 10.0, 18.0, 26.0, 4.0, 12.0, 20.0, 28.0, 6.0, 14.0,
    22.0, 30.0,
  ])
}

///|
test "Matrix4 determinant" {
  let a = @math.Matrix4::new()
  assert_true(a.determinant() == 1.0)
  a.elements[0] = 2.0
  assert_true(a.determinant() == 2.0)
  a.elements[0] = 0.0
  assert_true(a.determinant() == 0.0)
  // calculated via http://www.euclideanspace.com/maths/algebra/matrix/functions/determinant/fourD/index.htm
  ignore(
    a.set(
      2.0, 3.0, 4.0, 5.0, -1.0, -21.0, -3.0, -4.0, 6.0, 7.0, 8.0, 10.0, -8.0, -9.0,
      -10.0, -12.0,
    ),
  )
  assert_true(a.determinant() == 76.0)
}

///|
test "Matrix4 determinantAffine" {
  // for affine matrices (the typical object world matrix), the 3x3 result
  // equals the full 4x4 determinant since the bottom row is [ 0, 0, 0, 1 ]
  let eps = matrix4_test_eps
  let a = @math.Matrix4::new()
  let position = @math.Vector3::new(5.0, -2.0, 3.0)
  let quaternion = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(
    @math.Euler::new(0.1, -0.7, 1.3),
  )
  // translation + rotation + non-uniform scale
  ignore(a.compose(position, quaternion, @math.Vector3::new(2.0, 3.0, 0.5)))
  assert_true((a.determinant_affine() - a.determinant()).abs() <= eps)
  // reflection (negative scale on one axis flips the winding order)
  ignore(a.compose(position, quaternion, @math.Vector3::new(2.0, 3.0, -0.5)))
  assert_true(a.determinant_affine() < 0.0)
  assert_true((a.determinant_affine() - a.determinant()).abs() <= eps)
  // shear
  ignore(
    a.multiply(@math.Matrix4::new().make_shear(0.5, 0.0, 0.2, 0.0, 0.7, 0.0)),
  )
  assert_true((a.determinant_affine() - a.determinant()).abs() <= eps)
}

///|
test "Matrix4 determinantAffine (projective matrix)" {
  // for non-affine (projective) matrices, the bottom row is not [ 0, 0, 0, 1 ]
  // and so the 3x3 result generally differs from the full 4x4 determinant
  let a = @math.Matrix4::new().make_perspective(
    -1.0, 1.0, 1.0, -1.0, 1.0, 100.0,
  )
  assert_true(
    (a.determinant_affine() - a.determinant()).abs() > matrix4_test_eps,
  )
}

///|
test "Matrix4 transpose" {
  let a = @math.Matrix4::new()
  let b = a.clone().transpose()
  assert_true(matrix4_test_equals(a, b))
  let b = matrix4_test_sequence()
  let c = b.clone().transpose()
  assert_true(!matrix4_test_equals(b, c))
  ignore(c.transpose())
  assert_true(matrix4_test_equals(b, c))
}

///|
test "Matrix4 setPosition" {
  let a = matrix4_test_sequence()
  let b = @math.Vector3::new(-1.0, -2.0, -3.0)
  let c = @math.Matrix4::new().set(
    0.0, 1.0, 2.0, -1.0, 4.0, 5.0, 6.0, -2.0, 8.0, 9.0, 10.0, -3.0, 12.0, 13.0, 14.0,
    15.0,
  )
  ignore(a.set_position_vector(b))
  assert_true(matrix4_test_equals(a, c))
  let d = matrix4_test_sequence()
  let e = @math.Matrix4::new().set(
    0.0, 1.0, 2.0, -1.0, 4.0, 5.0, 6.0, -2.0, 8.0, 9.0, 10.0, -3.0, 12.0, 13.0, 14.0,
    15.0,
  )
  ignore(d.set_position(-1.0, -2.0, -3.0))
  assert_true(matrix4_test_equals(d, e))
}

///|
test "Matrix4 invert" {
  let zero = @math.Matrix4::new().set(
    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
  )
  let identity = @math.Matrix4::new()
  let a = @math.Matrix4::new()
  let b = zero.clone()
  ignore(a.copy(b).invert())
  assert_true(matrix4_test_equals(a, zero))
  let test_matrices = [
    @math.Matrix4::new().make_rotation_x(0.3),
    @math.Matrix4::new().make_rotation_x(-0.3),
    @math.Matrix4::new().make_rotation_y(0.3),
    @math.Matrix4::new().make_rotation_y(-0.3),
    @math.Matrix4::new().make_rotation_z(0.3),
    @math.Matrix4::new().make_rotation_z(-0.3),
    @math.Matrix4::new().make_scale(1.0, 2.0, 3.0),
    @math.Matrix4::new().make_scale(1.0 / 8.0, 1.0 / 2.0, 1.0 / 3.0),
    @math.Matrix4::new().make_perspective(-1.0, 1.0, 1.0, -1.0, 1.0, 1000.0),
    @math.Matrix4::new().make_perspective(-16.0, 16.0, 9.0, -9.0, 0.1, 10000.0),
    @math.Matrix4::new().make_translation(1.0, 2.0, 3.0),
  ]
  for m in test_matrices {
    let m_inverse = @math.Matrix4::new().copy(m).invert()
    let m_self_inverse = m.clone()
    ignore(m_self_inverse.copy(m_self_inverse).invert())
    // self-inverse should the same as inverse
    assert_true(matrix4_test_equals(m_self_inverse, m_inverse))
    // the determinant of the inverse should be the reciprocal
    assert_true(
      (m.determinant() * m_inverse.determinant() - 1.0).abs() < 0.0001,
    )
    let m_product = @math.Matrix4::new().multiply_matrices(m, m_inverse)
    // the determinant of the identity matrix is 1
    assert_true((m_product.determinant() - 1.0).abs() < 0.0001)
    assert_true(matrix4_test_equals(m_product, identity))
  }
}

///|
test "Matrix4 scale" {
  let a = @math.Matrix4::new().set(
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
    16.0,
  )
  let b = @math.Vector3::new(2.0, 3.0, 4.0)
  let c = @math.Matrix4::new().set(
    2.0, 6.0, 12.0, 4.0, 10.0, 18.0, 28.0, 8.0, 18.0, 30.0, 44.0, 12.0, 26.0, 42.0,
    60.0, 16.0,
  )
  ignore(a.scale(b))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 getMaxScaleOnAxis" {
  let a = @math.Matrix4::new().set(
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
    16.0,
  )
  let expected = (3.0 * 3.0 + 7.0 * 7.0 + 11.0 * 11.0).sqrt()
  assert_true((a.get_max_scale_on_axis() - expected).abs() <= matrix4_test_eps)
}

///|
test "Matrix4 makeTranslation" {
  let a = @math.Matrix4::new()
  let b = @math.Vector3::new(2.0, 3.0, 4.0)
  let c = @math.Matrix4::new().set(
    1.0, 0.0, 0.0, 2.0, 0.0, 1.0, 0.0, 3.0, 0.0, 0.0, 1.0, 4.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(a.make_translation(b.x, b.y, b.z))
  assert_true(matrix4_test_equals(a, c))
  ignore(a.identity())
  ignore(a.make_translation_vector(b))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 makeRotationX" {
  let a = @math.Matrix4::new()
  let b = 3.0.sqrt() / 2.0
  let c = @math.Matrix4::new().set(
    1.0, 0.0, 0.0, 0.0, 0.0, b, -0.5, 0.0, 0.0, 0.5, b, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(a.make_rotation_x(@cmath.PI / 6.0))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 makeRotationY" {
  let a = @math.Matrix4::new()
  let b = 3.0.sqrt() / 2.0
  let c = @math.Matrix4::new().set(
    b, 0.0, 0.5, 0.0, 0.0, 1.0, 0.0, 0.0, -0.5, 0.0, b, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(a.make_rotation_y(@cmath.PI / 6.0))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 makeRotationZ" {
  let a = @math.Matrix4::new()
  let b = 3.0.sqrt() / 2.0
  let c = @math.Matrix4::new().set(
    b, -0.5, 0.0, 0.0, 0.5, b, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(a.make_rotation_z(@cmath.PI / 6.0))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 makeRotationAxis" {
  let axis = @math.Vector3::new(1.5, 0.0, 1.0).normalize()
  let radians = @math.deg_to_rad(45.0)
  let a = @math.Matrix4::new().make_rotation_axis(axis, radians)
  let expected = @math.Matrix4::new().set(
    0.9098790095958609, -0.39223227027636803, 0.13518148560620882, 0.0, 0.39223227027636803,
    0.7071067811865476, -0.588348405414552, 0.0, 0.13518148560620882, 0.588348405414552,
    0.7972277715906868, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  assert_true(matrix4_test_equals(a, expected))
}

///|
test "Matrix4 makeScale" {
  let a = @math.Matrix4::new()
  let c = @math.Matrix4::new().set(
    2.0, 0.0, 0.0, 0.0, 0.0, 3.0, 0.0, 0.0, 0.0, 0.0, 4.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(a.make_scale(2.0, 3.0, 4.0))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 makeShear" {
  let a = @math.Matrix4::new()
  let c = @math.Matrix4::new().set(
    1.0, 3.0, 5.0, 0.0, 1.0, 1.0, 6.0, 0.0, 2.0, 4.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
  )
  ignore(a.make_shear(1.0, 2.0, 3.0, 4.0, 5.0, 6.0))
  assert_true(matrix4_test_equals(a, c))
}

///|
test "Matrix4 compose/decompose" {
  let t_values = [
    @math.Vector3::new(0.0, 0.0, 0.0),
    @math.Vector3::new(3.0, 0.0, 0.0),
    @math.Vector3::new(0.0, 4.0, 0.0),
    @math.Vector3::new(0.0, 0.0, 5.0),
    @math.Vector3::new(-6.0, 0.0, 0.0),
    @math.Vector3::new(0.0, -7.0, 0.0),
    @math.Vector3::new(0.0, 0.0, -8.0),
    @math.Vector3::new(-2.0, 5.0, -9.0),
    @math.Vector3::new(-2.0, -5.0, -9.0),
  ]
  let s_values = [
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(2.0, 2.0, 2.0),
    @math.Vector3::new(1.0, -1.0, 1.0),
    @math.Vector3::new(-1.0, 1.0, 1.0),
    @math.Vector3::new(1.0, 1.0, -1.0),
    @math.Vector3::new(2.0, -2.0, 1.0),
    @math.Vector3::new(-1.0, 2.0, -2.0),
    @math.Vector3::new(-1.0, -1.0, -1.0),
    @math.Vector3::new(-2.0, -2.0, -2.0),
  ]
  let r_values = [
    @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(
      @math.Euler::new(1.0, 1.0, 0.0),
    ),
    @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_euler(
      @math.Euler::new(1.0, -1.0, 1.0),
    ),
    @math.Quaternion::new(0.0, 0.9238795292366128, 0.0, 0.38268342717215614),
  ]
  for t in t_values {
    for s in s_values {
      for r in r_values {
        let m = @math.Matrix4::new().compose(t, r, s)
        let t2 = matrix4_test_v3()
        let r2 = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
        let s2 = matrix4_test_v3()
        ignore(m.decompose(t2, r2, s2))
        let m2 = @math.Matrix4::new().compose(t2, r2, s2)
        assert_true(matrix4_test_equals(m, m2))
      }
    }
  }
}

///|
test "Matrix4 decompose of a singular matrix" {
  let position = matrix4_test_v3()
  let quaternion = @math.Quaternion::new(1.0, 0.0, 0.0, 0.0)
  let scale = matrix4_test_v3()
  ignore(
    @math.Matrix4::new()
    .make_scale(0.0, 1.0, 1.0)
    .set_position(1.0, 2.0, 3.0)
    .decompose(position, quaternion, scale),
  )
  assert_true(position.equals(@math.Vector3::new(1.0, 2.0, 3.0)))
  assert_true(scale.equals(@math.Vector3::new(1.0, 1.0, 1.0)))
  assert_true(quaternion.equals(@math.Quaternion::new(0.0, 0.0, 0.0, 1.0)))
}

///|
test "Matrix4 makePerspective" {
  let a = @math.Matrix4::new().make_perspective(
    -1.0, 1.0, -1.0, 1.0, 1.0, 100.0,
  )
  let expected = @math.Matrix4::new().set(
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    -1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    -101.0 / 99.0,
    -200.0 / 99.0,
    0.0,
    0.0,
    -1.0,
    0.0,
  )
  assert_true(matrix4_test_equals(a, expected))
}

///|
test "Matrix4 makePerspective coordinate systems" {
  let a = @math.Matrix4::new().make_perspective(
    -1.0,
    1.0,
    -1.0,
    1.0,
    1.0,
    100.0,
    coordinate_system=@math.WebGPUCoordinateSystem,
  )
  assert_eq(a.elements[10], -100.0 / 99.0)
  assert_eq(a.elements[14], -100.0 / 99.0)
  let b = @math.Matrix4::new().make_perspective(
    -1.0,
    1.0,
    -1.0,
    1.0,
    1.0,
    100.0,
    reversed_depth=true,
  )
  assert_eq(b.elements[10], 1.0 / 99.0)
  assert_eq(b.elements[14], 100.0 / 99.0)
}

///|
test "panic Matrix4 makePerspective invalid coordinate system" {
  ignore(
    @math.Matrix4::new().make_perspective(
      -1.0,
      1.0,
      -1.0,
      1.0,
      1.0,
      100.0,
      coordinate_system=0,
    ),
  )
}

///|
test "Matrix4 makeOrthographic" {
  let a = @math.Matrix4::new().make_orthographic(
    -1.0, 1.0, -1.0, 1.0, 1.0, 100.0,
  )
  let expected = @math.Matrix4::new().set(
    1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    -1.0,
    0.0,
    0.0,
    0.0,
    0.0,
    -2.0 / 99.0,
    -101.0 / 99.0,
    0.0,
    0.0,
    0.0,
    1.0,
  )
  assert_true(matrix4_test_equals(a, expected))
}

///|
test "Matrix4 makeOrthographic coordinate systems" {
  let a = @math.Matrix4::new().make_orthographic(
    -1.0,
    1.0,
    -1.0,
    1.0,
    1.0,
    100.0,
    coordinate_system=@math.WebGPUCoordinateSystem,
  )
  assert_eq(a.elements[10], -1.0 / 99.0)
  assert_eq(a.elements[14], -1.0 / 99.0)
  let b = @math.Matrix4::new().make_orthographic(
    -1.0,
    1.0,
    -1.0,
    1.0,
    1.0,
    100.0,
    reversed_depth=true,
  )
  assert_eq(b.elements[10], 1.0 / 99.0)
  assert_eq(b.elements[14], 100.0 / 99.0)
}

///|
test "panic Matrix4 makeOrthographic invalid coordinate system" {
  ignore(
    @math.Matrix4::new().make_orthographic(
      -1.0,
      1.0,
      -1.0,
      1.0,
      1.0,
      100.0,
      coordinate_system=0,
    ),
  )
}

///|
test "Matrix4 equals" {
  let a = matrix4_test_sequence()
  let b = @math.Matrix4::new().set(
    0.0, -1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
    15.0,
  )
  assert_true(!a.equals(b))
  assert_true(!b.equals(a))
  ignore(a.copy(b))
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Matrix4 fromArray" {
  let a = @math.Matrix4::new()
  let b = @math.Matrix4::new().set(
    1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0, 15.0, 4.0, 8.0, 12.0,
    16.0,
  )
  ignore(
    a.from_array([
      1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0,
      15.0, 16.0,
    ]),
  )
  assert_true(a.equals(b))
}

///|
test "Matrix4 toArray" {
  let a = @math.Matrix4::new().set(
    1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
    16.0,
  )
  let no_offset = [
    1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0, 15.0, 4.0, 8.0, 12.0,
    16.0,
  ]
  // upstream leaves `undefined` in the first slot; `Array[Double]` holds 0
  let with_offset = [
    0.0, 1.0, 5.0, 9.0, 13.0, 2.0, 6.0, 10.0, 14.0, 3.0, 7.0, 11.0, 15.0, 4.0, 8.0,
    12.0, 16.0,
  ]
  assert_eq(a.to_array(), no_offset)
  let array : Array[Double] = []
  ignore(a.to_array(array~))
  assert_eq(array, no_offset)
  let array : Array[Double] = []
  ignore(a.to_array(array~, offset=1))
  assert_eq(array, with_offset)
}
