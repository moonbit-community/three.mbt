///|
fn cylindrical_test_equals(
  a : @math.Cylindrical,
  b : @math.Cylindrical,
) -> Bool {
  a.radius == b.radius && a.theta == b.theta && a.y == b.y
}

///|
test "Cylindrical: Instancing" {
  let a = @math.Cylindrical::new(1.0, 0.0, 0.0)
  let radius = 10.0
  let theta = @cmath.PI
  let y = 5.0
  assert_eq(a.radius, 1.0)
  assert_eq(a.theta, 0.0)
  assert_eq(a.y, 0.0)
  let a = @math.Cylindrical::new(radius, theta, y)
  assert_eq(a.radius, radius)
  assert_eq(a.theta, theta)
  assert_eq(a.y, y)
}

///|
test "Cylindrical: set" {
  let a = @math.Cylindrical::new(1.0, 0.0, 0.0)
  let radius = 10.0
  let theta = @cmath.PI
  let y = 5.0
  ignore(a.set(radius, theta, y))
  assert_eq(a.radius, radius)
  assert_eq(a.theta, theta)
  assert_eq(a.y, y)
}

///|
test "Cylindrical: clone" {
  let a = @math.Cylindrical::new(10.0, @cmath.PI, 5.0)
  let b = a.clone()
  assert_true(cylindrical_test_equals(a, b))
  a.radius = 1.0
  assert_false(cylindrical_test_equals(a, b))
}

///|
test "Cylindrical: copy" {
  let a = @math.Cylindrical::new(10.0, @cmath.PI, 5.0)
  let b = @math.Cylindrical::new(1.0, 0.0, 0.0).copy(a)
  assert_true(cylindrical_test_equals(a, b))
  a.radius = 1.0
  assert_false(cylindrical_test_equals(a, b))
}

///|
test "Cylindrical: setFromVector3" {
  let eps = 0.0001
  let a = @math.Cylindrical::new(1.0, 1.0, 1.0)
  let b = @math.Vector3::new(0.0, 0.0, 0.0)
  let c = @math.Vector3::new(3.0, -1.0, -3.0)
  let expected = @math.Cylindrical::new(
    (9.0 + 9.0).sqrt(),
    @cmath.atan2(3.0, -3.0),
    -1.0,
  )
  ignore(a.set_from_vector3(b))
  assert_eq(a.radius, 0.0)
  assert_eq(a.theta, 0.0)
  assert_eq(a.y, 0.0)
  ignore(a.set_from_vector3(c))
  assert_true((a.radius - expected.radius).abs() <= eps)
  assert_true((a.theta - expected.theta).abs() <= eps)
  assert_true((a.y - expected.y).abs() <= eps)
}
