///|
test "PolyhedronGeometry: type" {
  assert_eq(@geometries.PolyhedronGeometry::new().type_, "PolyhedronGeometry")
}

///|
test "PolyhedronGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.PolyhedronGeometry::new(
        vertices=[1, 1, 1, -1, -1, 1, -1, 1, -1, 1, -1, -1],
        indices=[2, 1, 0, 0, 3, 2, 1, 3, 0, 2, 3, 1],
      ),
    ],
    @geometries.PolyhedronGeometry::from_json,
  )
}
