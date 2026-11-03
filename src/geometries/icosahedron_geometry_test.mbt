///|
test "IcosahedronGeometry: type" {
  assert_eq(@geometries.IcosahedronGeometry::new().type_, "IcosahedronGeometry")
}

///|
test "IcosahedronGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.IcosahedronGeometry::new(),
      @geometries.IcosahedronGeometry::new(radius=10),
    ],
    @geometries.IcosahedronGeometry::from_json,
  )
}
