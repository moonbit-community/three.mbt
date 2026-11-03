///|
test "CapsuleGeometry: type" {
  assert_eq(@geometries.CapsuleGeometry::new().type_, "CapsuleGeometry")
}

///|
test "CapsuleGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.CapsuleGeometry::new(),
      @geometries.CapsuleGeometry::new(radius=2),
      @geometries.CapsuleGeometry::new(radius=2, height=2),
      @geometries.CapsuleGeometry::new(radius=2, height=2, cap_segments=20),
      @geometries.CapsuleGeometry::new(
        radius=2,
        height=2,
        cap_segments=20,
        radial_segments=20,
      ),
      @geometries.CapsuleGeometry::new(
        radius=2,
        height=2,
        cap_segments=20,
        radial_segments=20,
        height_segments=1,
      ),
    ],
    @geometries.CapsuleGeometry::from_json,
  )
}
