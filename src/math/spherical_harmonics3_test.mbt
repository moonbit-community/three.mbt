///|
test "SphericalHarmonics3: Instancing" {
  let object = @math.SphericalHarmonics3::new()
  assert_eq(object.coefficients.length(), 9)
}

// Not in upstream's test file: expected values are upstream's output.

///|
fn spherical_harmonics3_test_fixture() -> @math.SphericalHarmonics3 {
  let array = []
  for i = 0; i < 27; i = i + 1 {
    array.push(i.to_double() * 0.25 - 3.0)
  }
  @math.SphericalHarmonics3::new().from_array(array)
}

///|
test "SphericalHarmonics3: getAt" {
  let sh = spherical_harmonics3_test_fixture()
  let normal = @math.Vector3::new(1.0, 2.0, 2.0).normalize()
  let target = sh.get_at(normal, @math.Vector3::new(0.0, 0.0, 0.0))
  assert_eq(target.x, -1.668064583333333)
  assert_eq(target.y, -1.1704079722222218)
  assert_eq(target.z, -0.6727513611111112)
}

///|
test "SphericalHarmonics3: getIrradianceAt" {
  let sh = spherical_harmonics3_test_fixture()
  let normal = @math.Vector3::new(1.0, 2.0, 2.0).normalize()
  let target = sh.get_irradiance_at(normal, @math.Vector3::new(0.0, 0.0, 0.0))
  assert_eq(target.x, -5.062949666666667)
  assert_eq(target.y, -4.239431611111112)
  assert_eq(target.z, -3.415913555555555)
}

///|
test "SphericalHarmonics3: getBasisAt" {
  let normal = @math.Vector3::new(1.0, 2.0, 2.0).normalize()
  let basis = []
  @math.SphericalHarmonics3::get_basis_at(normal, basis)
  assert_eq(basis, [
    0.282095, 0.3257353333333333, 0.3257353333333333, 0.16286766666666666, 0.24278844444444442,
    0.48557688888888884, 0.10513066666666665, 0.24278844444444442, -0.18209133333333333,
  ])
}

///|
test "SphericalHarmonics3: fromArray, toArray, copy, equals" {
  let sh = spherical_harmonics3_test_fixture()
  let array = sh.to_array()
  assert_eq(array.length(), 27)
  assert_eq(array[0], -3.0)
  assert_eq(array[26], 3.5)
  let clone = sh.clone()
  assert_true(sh.equals(clone))
  ignore(clone.zero())
  assert_false(sh.equals(clone))
  assert_true(clone.copy(sh).equals(sh))
}
