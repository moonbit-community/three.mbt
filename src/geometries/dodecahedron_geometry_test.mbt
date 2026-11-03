///|
test "DodecahedronGeometry: type" {
  assert_eq(
    @geometries.DodecahedronGeometry::new().type_,
    "DodecahedronGeometry",
  )
}

///|
test "DodecahedronGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.DodecahedronGeometry::new(),
      @geometries.DodecahedronGeometry::new(radius=10),
    ],
    @geometries.DodecahedronGeometry::from_json,
  )
}
