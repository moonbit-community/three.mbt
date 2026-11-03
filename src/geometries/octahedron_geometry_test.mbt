///|
test "OctahedronGeometry: type" {
  assert_eq(@geometries.OctahedronGeometry::new().type_, "OctahedronGeometry")
}

///|
test "OctahedronGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.OctahedronGeometry::new(),
      @geometries.OctahedronGeometry::new(radius=10),
    ],
    @geometries.OctahedronGeometry::from_json,
  )
}
