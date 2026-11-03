///|
test "SphereGeometry: type" {
  assert_eq(@geometries.SphereGeometry::new().type_, "SphereGeometry")
}

///|
test "SphereGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.SphereGeometry::new(),
      @geometries.SphereGeometry::new(radius=10),
      @geometries.SphereGeometry::new(radius=10, width_segments=20),
      @geometries.SphereGeometry::new(
        radius=10,
        width_segments=20,
        height_segments=30,
      ),
      @geometries.SphereGeometry::new(
        radius=10,
        width_segments=20,
        height_segments=30,
        phi_start=0.5,
      ),
      @geometries.SphereGeometry::new(
        radius=10,
        width_segments=20,
        height_segments=30,
        phi_start=0.5,
        phi_length=1.0,
      ),
      @geometries.SphereGeometry::new(
        radius=10,
        width_segments=20,
        height_segments=30,
        phi_start=0.5,
        phi_length=1.0,
        theta_start=0.4,
      ),
      @geometries.SphereGeometry::new(
        radius=10,
        width_segments=20,
        height_segments=30,
        phi_start=0.5,
        phi_length=1.0,
        theta_start=0.4,
        theta_length=2.0,
      ),
    ],
    @geometries.SphereGeometry::from_json,
  )
}
