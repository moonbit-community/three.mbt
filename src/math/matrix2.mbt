///|
/// A 2x2 matrix; `elements` is column-major.
#derive(Debug, Eq)
pub(all) struct Matrix2 {
  mut elements : Array[Double]
}

///|
/// Arguments are row-major; with none, the identity matrix.
pub fn Matrix2::new(
  n11~ : Double = 1.0,
  n12~ : Double = 0.0,
  n21~ : Double = 0.0,
  n22~ : Double = 1.0,
) -> Matrix2 {
  { elements: [n11, n21, n12, n22], }
}

///|
pub fn Matrix2::identity(self : Matrix2) -> Matrix2 {
  self.set(1.0, 0.0, 0.0, 1.0)
}

///|
pub fn Matrix2::from_array(
  self : Matrix2,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> Matrix2 {
  for i in 0..<4 {
    self.elements[i] = array[i + offset]
  }
  self
}

///|
/// Arguments are row-major.
pub fn Matrix2::set(
  self : Matrix2,
  n11 : Double,
  n12 : Double,
  n21 : Double,
  n22 : Double,
) -> Matrix2 {
  let te = self.elements
  te[0] = n11
  te[2] = n12
  te[1] = n21
  te[3] = n22
  self
}
