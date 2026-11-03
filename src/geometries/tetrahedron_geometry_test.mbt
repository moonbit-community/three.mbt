///|
test "TetrahedronGeometry: type" {
  assert_eq(@geometries.TetrahedronGeometry::new().type_, "TetrahedronGeometry")
}

///|
test "TetrahedronGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.TetrahedronGeometry::new(),
      @geometries.TetrahedronGeometry::new(radius=10),
    ],
    @geometries.TetrahedronGeometry::from_json,
  )
}
