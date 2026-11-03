///|
fn spherical_test_equals(a : @math.Spherical, b : @math.Spherical) -> Bool {
  a.radius == b.radius && a.phi == b.phi && a.theta == b.theta
}

///|
test "Spherical: Instancing" {
  let a = @math.Spherical::new(1.0, 0.0, 0.0)
  let radius = 10.0
  let phi = @cmath.acos(-0.5)
  let theta = @cmath.PI.sqrt() * phi
  assert_eq(a.radius, 1.0)
  assert_eq(a.phi, 0.0)
  assert_eq(a.theta, 0.0)
  let a = @math.Spherical::new(radius, phi, theta)
  assert_eq(a.radius, radius)
  assert_eq(a.phi, phi)
  assert_eq(a.theta, theta)
}

///|
test "Spherical: set" {
  let a = @math.Spherical::new(1.0, 0.0, 0.0)
  let radius = 10.0
  let phi = @cmath.acos(-0.5)
  let theta = @cmath.PI.sqrt() * phi
  ignore(a.set(radius, phi, theta))
  assert_eq(a.radius, radius)
  assert_eq(a.phi, phi)
  assert_eq(a.theta, theta)
}

///|
test "Spherical: clone" {
  let radius = 10.0
  let phi = @cmath.acos(-0.5)
  let theta = @cmath.PI.sqrt() * phi
  let a = @math.Spherical::new(radius, phi, theta)
  let b = a.clone()
  assert_true(spherical_test_equals(a, b))
  a.radius = 2.0
  assert_false(spherical_test_equals(a, b))
}

///|
test "Spherical: copy" {
  let radius = 10.0
  let phi = @cmath.acos(-0.5)
  let theta = @cmath.PI.sqrt() * phi
  let a = @math.Spherical::new(radius, phi, theta)
  let b = @math.Spherical::new(1.0, 0.0, 0.0).copy(a)
  assert_true(spherical_test_equals(a, b))
  a.radius = 2.0
  assert_false(spherical_test_equals(a, b))
}

///|
test "Spherical: makeSafe" {
  let eps = 0.000001 // from source
  let too_low = 0.0
  let too_high = @cmath.PI
  let just_right = 1.5
  let a = @math.Spherical::new(1.0, too_low, 0.0)
  ignore(a.make_safe())
  assert_eq(a.phi, eps)
  ignore(a.set(1.0, too_high, 0.0))
  ignore(a.make_safe())
  assert_eq(a.phi, @cmath.PI - eps)
  ignore(a.set(1.0, just_right, 0.0))
  ignore(a.make_safe())
  assert_eq(a.phi, just_right)
}

///|
test "Spherical: setFromVector3" {
  let eps = 0.0001
  let a = @math.Spherical::new(1.0, 1.0, 1.0)
  let b = @math.Vector3::new(0.0, 0.0, 0.0)
  let c = @math.Vector3::new(@cmath.PI, 1.0, -@cmath.PI)
  let expected = @math.Spherical::new(
    4.554032147688322, 1.3494066171539107, 2.356194490192345,
  )
  ignore(a.set_from_vector3(b))
  assert_eq(a.radius, 0.0)
  assert_eq(a.phi, 0.0)
  assert_eq(a.theta, 0.0)
  ignore(a.set_from_vector3(c))
  assert_true((a.radius - expected.radius).abs() <= eps)
  assert_true((a.phi - expected.phi).abs() <= eps)
  assert_true((a.theta - expected.theta).abs() <= eps)
}

///|
test "Spherical: setFromCartesianCoords" {
  let eps = 0.0001
  let a = @math.Spherical::new(1.0, 1.0, 1.0)
  let expected = @math.Spherical::new(
    4.554032147688322, 1.3494066171539107, 2.356194490192345,
  )
  ignore(a.set_from_cartesian_coords(0.0, 0.0, 0.0))
  assert_eq(a.radius, 0.0)
  assert_eq(a.phi, 0.0)
  assert_eq(a.theta, 0.0)
  ignore(a.set_from_cartesian_coords(@cmath.PI, 1.0, -@cmath.PI))
  assert_true((a.radius - expected.radius).abs() <= eps)
  assert_true((a.phi - expected.phi).abs() <= eps)
  assert_true((a.theta - expected.theta).abs() <= eps)
}
