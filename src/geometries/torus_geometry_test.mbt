///|
test "TorusGeometry: type" {
  assert_eq(@geometries.TorusGeometry::new().type_, "TorusGeometry")
}

///|
test "TorusGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.TorusGeometry::new(),
      @geometries.TorusGeometry::new(radius=10),
      @geometries.TorusGeometry::new(radius=10, tube=20),
      @geometries.TorusGeometry::new(radius=10, tube=20, radial_segments=30),
      @geometries.TorusGeometry::new(
        radius=10,
        tube=20,
        radial_segments=30,
        tubular_segments=10,
      ),
      @geometries.TorusGeometry::new(
        radius=10,
        tube=20,
        radial_segments=30,
        tubular_segments=10,
        arc=2.0,
      ),
      @geometries.TorusGeometry::new(
        radius=10,
        tube=20,
        radial_segments=30,
        tubular_segments=10,
        arc=2.0,
        theta_start=test_pi * 0.5,
      ),
      @geometries.TorusGeometry::new(
        radius=10,
        tube=20,
        radial_segments=30,
        tubular_segments=10,
        arc=2.0,
        theta_start=test_pi * 0.5,
        theta_length=test_pi,
      ),
    ],
    @geometries.TorusGeometry::from_json,
  )
}
