///|
test "RingGeometry: type" {
  assert_eq(@geometries.RingGeometry::new().type_, "RingGeometry")
}

///|
test "RingGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.RingGeometry::new(),
      @geometries.RingGeometry::new(inner_radius=10),
      @geometries.RingGeometry::new(inner_radius=10, outer_radius=60),
      @geometries.RingGeometry::new(
        inner_radius=10,
        outer_radius=60,
        theta_segments=12,
      ),
      @geometries.RingGeometry::new(
        inner_radius=10,
        outer_radius=60,
        theta_segments=12,
        phi_segments=14,
      ),
      @geometries.RingGeometry::new(
        inner_radius=10,
        outer_radius=60,
        theta_segments=12,
        phi_segments=14,
        theta_start=0.1,
      ),
      @geometries.RingGeometry::new(
        inner_radius=10,
        outer_radius=60,
        theta_segments=12,
        phi_segments=14,
        theta_start=0.1,
        theta_length=2.0,
      ),
    ],
    @geometries.RingGeometry::from_json,
  )
}
