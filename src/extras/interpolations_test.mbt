// Upstream has no test file for Interpolations.

///|
test "catmull_rom passes through its middle points" {
  assert_eq(@extras.catmull_rom(0.0, 1.0, 2.0, 3.0, 4.0), 2.0)
  assert_eq(@extras.catmull_rom(1.0, 1.0, 2.0, 3.0, 4.0), 3.0)
}

///|
test "quadratic_bezier" {
  assert_eq(@extras.quadratic_bezier(0.5, 0.0, 1.0, 2.0), 1.0)
}

///|
test "cubic_bezier" {
  assert_eq(@extras.cubic_bezier(0.5, 0.0, 1.0, 2.0, 3.0), 1.5)
}
