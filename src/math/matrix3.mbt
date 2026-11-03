///|
/// A 3x3 matrix; `elements` is column-major.
#derive(Debug, Eq)
pub(all) struct Matrix3 {
  mut elements : Array[Double]
}

///|
/// Arguments are row-major; with none, the identity matrix.
pub fn Matrix3::new(
  n11~ : Double = 1.0,
  n12~ : Double = 0.0,
  n13~ : Double = 0.0,
  n21~ : Double = 0.0,
  n22~ : Double = 1.0,
  n23~ : Double = 0.0,
  n31~ : Double = 0.0,
  n32~ : Double = 0.0,
  n33~ : Double = 1.0,
) -> Matrix3 {
  { elements: [n11, n21, n31, n12, n22, n32, n13, n23, n33], }
}

///|
/// Arguments are row-major.
pub fn Matrix3::set(
  self : Matrix3,
  n11 : Double,
  n12 : Double,
  n13 : Double,
  n21 : Double,
  n22 : Double,
  n23 : Double,
  n31 : Double,
  n32 : Double,
  n33 : Double,
) -> Matrix3 {
  let te = self.elements
  te[0] = n11
  te[1] = n21
  te[2] = n31
  te[3] = n12
  te[4] = n22
  te[5] = n32
  te[6] = n13
  te[7] = n23
  te[8] = n33
  self
}

///|
pub fn Matrix3::identity(self : Matrix3) -> Matrix3 {
  self.set(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0)
}

///|
pub fn Matrix3::copy(self : Matrix3, m : Matrix3) -> Matrix3 {
  let te = self.elements
  let me = m.elements
  te[0] = me[0]
  te[1] = me[1]
  te[2] = me[2]
  te[3] = me[3]
  te[4] = me[4]
  te[5] = me[5]
  te[6] = me[6]
  te[7] = me[7]
  te[8] = me[8]
  self
}

///|
pub fn Matrix3::extract_basis(
  self : Matrix3,
  x_axis : Vector3,
  y_axis : Vector3,
  z_axis : Vector3,
) -> Matrix3 {
  x_axis.set_from_matrix3_column(self, 0) |> ignore
  y_axis.set_from_matrix3_column(self, 1) |> ignore
  z_axis.set_from_matrix3_column(self, 2) |> ignore
  self
}

///|
pub fn Matrix3::set_from_matrix4(self : Matrix3, m : Matrix4) -> Matrix3 {
  let me = m.elements
  self.set(me[0], me[4], me[8], me[1], me[5], me[9], me[2], me[6], me[10])
}

///|
pub fn Matrix3::multiply(self : Matrix3, m : Matrix3) -> Matrix3 {
  self.multiply_matrices(self, m)
}

///|
pub fn Matrix3::premultiply(self : Matrix3, m : Matrix3) -> Matrix3 {
  self.multiply_matrices(m, self)
}

///|
pub fn Matrix3::multiply_matrices(
  self : Matrix3,
  a : Matrix3,
  b : Matrix3,
) -> Matrix3 {
  let ae = a.elements
  let be = b.elements
  let te = self.elements
  let a11 = ae[0]
  let a12 = ae[3]
  let a13 = ae[6]
  let a21 = ae[1]
  let a22 = ae[4]
  let a23 = ae[7]
  let a31 = ae[2]
  let a32 = ae[5]
  let a33 = ae[8]
  let b11 = be[0]
  let b12 = be[3]
  let b13 = be[6]
  let b21 = be[1]
  let b22 = be[4]
  let b23 = be[7]
  let b31 = be[2]
  let b32 = be[5]
  let b33 = be[8]
  te[0] = a11 * b11 + a12 * b21 + a13 * b31
  te[3] = a11 * b12 + a12 * b22 + a13 * b32
  te[6] = a11 * b13 + a12 * b23 + a13 * b33
  te[1] = a21 * b11 + a22 * b21 + a23 * b31
  te[4] = a21 * b12 + a22 * b22 + a23 * b32
  te[7] = a21 * b13 + a22 * b23 + a23 * b33
  te[2] = a31 * b11 + a32 * b21 + a33 * b31
  te[5] = a31 * b12 + a32 * b22 + a33 * b32
  te[8] = a31 * b13 + a32 * b23 + a33 * b33
  self
}

///|
pub fn Matrix3::multiply_scalar(self : Matrix3, s : Double) -> Matrix3 {
  let te = self.elements
  te[0] *= s
  te[3] *= s
  te[6] *= s
  te[1] *= s
  te[4] *= s
  te[7] *= s
  te[2] *= s
  te[5] *= s
  te[8] *= s
  self
}

///|
pub fn Matrix3::determinant(self : Matrix3) -> Double {
  let te = self.elements
  let a = te[0]
  let b = te[1]
  let c = te[2]
  let d = te[3]
  let e = te[4]
  let f = te[5]
  let g = te[6]
  let h = te[7]
  let i = te[8]
  a * e * i - a * f * h - b * d * i + b * f * g + c * d * h - c * e * g
}

///|
/// Produces a zero matrix when the determinant is zero.
pub fn Matrix3::invert(self : Matrix3) -> Matrix3 {
  let te = self.elements
  let n11 = te[0]
  let n21 = te[1]
  let n31 = te[2]
  let n12 = te[3]
  let n22 = te[4]
  let n32 = te[5]
  let n13 = te[6]
  let n23 = te[7]
  let n33 = te[8]
  let t11 = n33 * n22 - n32 * n23
  let t12 = n32 * n13 - n33 * n12
  let t13 = n23 * n12 - n22 * n13
  let det = n11 * t11 + n21 * t12 + n31 * t13
  if det == 0.0 {
    return self.set(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
  }
  let det_inv = 1.0 / det
  te[0] = t11 * det_inv
  te[1] = (n31 * n23 - n33 * n21) * det_inv
  te[2] = (n32 * n21 - n31 * n22) * det_inv
  te[3] = t12 * det_inv
  te[4] = (n33 * n11 - n31 * n13) * det_inv
  te[5] = (n31 * n12 - n32 * n11) * det_inv
  te[6] = t13 * det_inv
  te[7] = (n21 * n13 - n23 * n11) * det_inv
  te[8] = (n22 * n11 - n21 * n12) * det_inv
  self
}

///|
pub fn Matrix3::transpose(self : Matrix3) -> Matrix3 {
  let m = self.elements
  let mut tmp = m[1]
  m[1] = m[3]
  m[3] = tmp
  tmp = m[2]
  m[2] = m[6]
  m[6] = tmp
  tmp = m[5]
  m[5] = m[7]
  m[7] = tmp
  self
}

///|
pub fn Matrix3::get_normal_matrix(self : Matrix3, matrix4 : Matrix4) -> Matrix3 {
  self.set_from_matrix4(matrix4).invert().transpose()
}

///|
pub fn Matrix3::transpose_into_array(
  self : Matrix3,
  r : Array[Double],
) -> Matrix3 {
  let m = self.elements
  vector_array_set(r, 0, m[0])
  vector_array_set(r, 1, m[3])
  vector_array_set(r, 2, m[6])
  vector_array_set(r, 3, m[1])
  vector_array_set(r, 4, m[4])
  vector_array_set(r, 5, m[7])
  vector_array_set(r, 6, m[2])
  vector_array_set(r, 7, m[5])
  vector_array_set(r, 8, m[8])
  self
}

///|
pub fn Matrix3::set_uv_transform(
  self : Matrix3,
  tx : Double,
  ty : Double,
  sx : Double,
  sy : Double,
  rotation : Double,
  cx : Double,
  cy : Double,
) -> Matrix3 {
  let c = @cmath.cos(rotation)
  let s = @cmath.sin(rotation)
  self.set(
    sx * c,
    sx * s,
    -sx * (c * cx + s * cy) + cx + tx,
    -sy * s,
    sy * c,
    -sy * (-s * cx + c * cy) + cy + ty,
    0.0,
    0.0,
    1.0,
  )
}

///|
pub fn Matrix3::make_translation(
  self : Matrix3,
  x : Double,
  y : Double,
) -> Matrix3 {
  self.set(1.0, 0.0, x, 0.0, 1.0, y, 0.0, 0.0, 1.0)
}

///|
/// Upstream `makeTranslation` given a `Vector2`.
pub fn Matrix3::make_translation_vector(self : Matrix3, v : Vector2) -> Matrix3 {
  self.set(1.0, 0.0, v.x, 0.0, 1.0, v.y, 0.0, 0.0, 1.0)
}

///|
pub fn Matrix3::make_rotation(self : Matrix3, theta : Double) -> Matrix3 {
  // counterclockwise
  let c = @cmath.cos(theta)
  let s = @cmath.sin(theta)
  self.set(c, -s, 0.0, s, c, 0.0, 0.0, 0.0, 1.0)
}

///|
pub fn Matrix3::make_scale(self : Matrix3, x : Double, y : Double) -> Matrix3 {
  self.set(x, 0.0, 0.0, 0.0, y, 0.0, 0.0, 0.0, 1.0)
}

///|
pub fn Matrix3::equals(self : Matrix3, matrix : Matrix3) -> Bool {
  let te = self.elements
  let me = matrix.elements
  for i in 0..<9 {
    if te[i] != me[i] {
      return false
    }
  }
  true
}

///|
pub fn Matrix3::from_array(
  self : Matrix3,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Matrix3 {
  for i in 0..<9 {
    self.elements[i] = array[i + offset]
  }
  self
}

///|
pub fn Matrix3::to_array(
  self : Matrix3,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  let te = self.elements
  vector_array_set(array, offset, te[0])
  vector_array_set(array, offset + 1, te[1])
  vector_array_set(array, offset + 2, te[2])
  vector_array_set(array, offset + 3, te[3])
  vector_array_set(array, offset + 4, te[4])
  vector_array_set(array, offset + 5, te[5])
  vector_array_set(array, offset + 6, te[6])
  vector_array_set(array, offset + 7, te[7])
  vector_array_set(array, offset + 8, te[8])
  array
}

///|
pub fn Matrix3::clone(self : Matrix3) -> Matrix3 {
  Matrix3::new().from_array(self.elements)
}
