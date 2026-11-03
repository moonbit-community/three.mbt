///|
test "CircleGeometry: type" {
  assert_eq(@geometries.CircleGeometry::new().type_, "CircleGeometry")
}

///|
test "CircleGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.CircleGeometry::new(),
      @geometries.CircleGeometry::new(radius=10),
      @geometries.CircleGeometry::new(radius=10, segments=20),
      @geometries.CircleGeometry::new(radius=10, segments=20, theta_start=0.1),
      @geometries.CircleGeometry::new(
        radius=10,
        segments=20,
        theta_start=0.1,
        theta_length=0.2,
      ),
    ],
    @geometries.CircleGeometry::from_json,
  )
}
