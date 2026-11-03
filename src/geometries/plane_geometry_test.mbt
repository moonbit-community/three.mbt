///|
test "PlaneGeometry: type" {
  assert_eq(@geometries.PlaneGeometry::new().type_, "PlaneGeometry")
}

///|
test "PlaneGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.PlaneGeometry::new(),
      @geometries.PlaneGeometry::new(width=10),
      @geometries.PlaneGeometry::new(width=10, height=30),
      @geometries.PlaneGeometry::new(width=10, height=30, width_segments=3),
      @geometries.PlaneGeometry::new(
        width=10,
        height=30,
        width_segments=3,
        height_segments=5,
      ),
    ],
    @geometries.PlaneGeometry::from_json,
  )
}
