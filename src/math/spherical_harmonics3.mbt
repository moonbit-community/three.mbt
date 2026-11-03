///|
/// Third-order spherical harmonics holding nine vector coefficients.
pub(all) struct SphericalHarmonics3 {
  mut coefficients : Array[Vector3]
}

///|
pub fn SphericalHarmonics3::new() -> SphericalHarmonics3 {
  let coefficients = []
  for i = 0; i < 9; i = i + 1 {
    coefficients.push(Vector3::new(0.0, 0.0, 0.0))
  }
  { coefficients, }
}

///|
pub fn SphericalHarmonics3::set(
  self : SphericalHarmonics3,
  coefficients : Array[Vector3],
) -> SphericalHarmonics3 {
  for i = 0; i < 9; i = i + 1 {
    ignore(self.coefficients[i].copy(coefficients[i]))
  }
  self
}

///|
pub fn SphericalHarmonics3::zero(
  self : SphericalHarmonics3,
) -> SphericalHarmonics3 {
  for i = 0; i < 9; i = i + 1 {
    ignore(self.coefficients[i].set(0.0, 0.0, 0.0))
  }
  self
}

///|
pub fn SphericalHarmonics3::get_at(
  self : SphericalHarmonics3,
  normal : Vector3,
  target : Vector3,
) -> Vector3 {
  // normal is assumed to be unit length
  let x = normal.x
  let y = normal.y
  let z = normal.z
  let coeff = self.coefficients

  // band 0
  ignore(target.copy(coeff[0]).multiply_scalar(0.282095))

  // band 1
  ignore(target.add_scaled_vector(coeff[1], 0.488603 * y))
  ignore(target.add_scaled_vector(coeff[2], 0.488603 * z))
  ignore(target.add_scaled_vector(coeff[3], 0.488603 * x))

  // band 2
  ignore(target.add_scaled_vector(coeff[4], 1.092548 * (x * y)))
  ignore(target.add_scaled_vector(coeff[5], 1.092548 * (y * z)))
  ignore(target.add_scaled_vector(coeff[6], 0.315392 * (3.0 * z * z - 1.0)))
  ignore(target.add_scaled_vector(coeff[7], 1.092548 * (x * z)))
  ignore(target.add_scaled_vector(coeff[8], 0.546274 * (x * x - y * y)))
  target
}

///|
pub fn SphericalHarmonics3::get_irradiance_at(
  self : SphericalHarmonics3,
  normal : Vector3,
  target : Vector3,
) -> Vector3 {
  // normal is assumed to be unit length
  let x = normal.x
  let y = normal.y
  let z = normal.z
  let coeff = self.coefficients

  // band 0
  ignore(target.copy(coeff[0]).multiply_scalar(0.886227)) // π * 0.282095

  // band 1
  ignore(target.add_scaled_vector(coeff[1], 2.0 * 0.511664 * y)) // ( 2 * π / 3 ) * 0.488603
  ignore(target.add_scaled_vector(coeff[2], 2.0 * 0.511664 * z))
  ignore(target.add_scaled_vector(coeff[3], 2.0 * 0.511664 * x))

  // band 2
  ignore(target.add_scaled_vector(coeff[4], 2.0 * 0.429043 * x * y)) // ( π / 4 ) * 1.092548
  ignore(target.add_scaled_vector(coeff[5], 2.0 * 0.429043 * y * z))
  ignore(target.add_scaled_vector(coeff[6], 0.743125 * z * z - 0.247708)) // ( π / 4 ) * 0.315392 * 3
  ignore(target.add_scaled_vector(coeff[7], 2.0 * 0.429043 * x * z))
  ignore(target.add_scaled_vector(coeff[8], 0.429043 * (x * x - y * y))) // ( π / 4 ) * 0.546274
  target
}

///|
pub fn SphericalHarmonics3::add(
  self : SphericalHarmonics3,
  sh : SphericalHarmonics3,
) -> SphericalHarmonics3 {
  for i = 0; i < 9; i = i + 1 {
    ignore(self.coefficients[i].add(sh.coefficients[i]))
  }
  self
}

///|
pub fn SphericalHarmonics3::add_scaled_sh(
  self : SphericalHarmonics3,
  sh : SphericalHarmonics3,
  s : Double,
) -> SphericalHarmonics3 {
  for i = 0; i < 9; i = i + 1 {
    ignore(self.coefficients[i].add_scaled_vector(sh.coefficients[i], s))
  }
  self
}

///|
pub fn SphericalHarmonics3::scale(
  self : SphericalHarmonics3,
  s : Double,
) -> SphericalHarmonics3 {
  for i = 0; i < 9; i = i + 1 {
    ignore(self.coefficients[i].multiply_scalar(s))
  }
  self
}

///|
pub fn SphericalHarmonics3::lerp(
  self : SphericalHarmonics3,
  sh : SphericalHarmonics3,
  alpha : Double,
) -> SphericalHarmonics3 {
  for i = 0; i < 9; i = i + 1 {
    ignore(self.coefficients[i].lerp(sh.coefficients[i], alpha))
  }
  self
}

///|
pub fn SphericalHarmonics3::equals(
  self : SphericalHarmonics3,
  sh : SphericalHarmonics3,
) -> Bool {
  for i = 0; i < 9; i = i + 1 {
    if !self.coefficients[i].equals(sh.coefficients[i]) {
      return false
    }
  }
  true
}

///|
pub fn SphericalHarmonics3::copy(
  self : SphericalHarmonics3,
  sh : SphericalHarmonics3,
) -> SphericalHarmonics3 {
  self.set(sh.coefficients)
}

///|
pub fn SphericalHarmonics3::clone(
  self : SphericalHarmonics3,
) -> SphericalHarmonics3 {
  SphericalHarmonics3::new().copy(self)
}

///|
pub fn SphericalHarmonics3::from_array(
  self : SphericalHarmonics3,
  array : Array[Double],
  offset~ : Int32 = 0,
) -> SphericalHarmonics3 {
  let coefficients = self.coefficients
  for i = 0; i < 9; i = i + 1 {
    ignore(coefficients[i].from_array(array, offset=offset + i * 3))
  }
  self
}

///|
pub fn SphericalHarmonics3::to_array(
  self : SphericalHarmonics3,
  array~ : Array[Double] = [],
  offset~ : Int32 = 0,
) -> Array[Double] {
  let coefficients = self.coefficients
  for i = 0; i < 9; i = i + 1 {
    ignore(coefficients[i].to_array(array~, offset=offset + i * 3))
  }
  array
}

///|
pub fn SphericalHarmonics3::get_basis_at(
  normal : Vector3,
  sh_basis : Array[Double],
) -> Unit {
  // normal is assumed to be unit length
  let x = normal.x
  let y = normal.y
  let z = normal.z

  // the target grows as a plain upstream array would
  while sh_basis.length() < 9 {
    sh_basis.push(0.0)
  }

  // band 0
  sh_basis[0] = 0.282095

  // band 1
  sh_basis[1] = 0.488603 * y
  sh_basis[2] = 0.488603 * z
  sh_basis[3] = 0.488603 * x

  // band 2
  sh_basis[4] = 1.092548 * x * y
  sh_basis[5] = 1.092548 * y * z
  sh_basis[6] = 0.315392 * (3.0 * z * z - 1.0)
  sh_basis[7] = 1.092548 * x * z
  sh_basis[8] = 0.546274 * (x * x - y * y)
}
