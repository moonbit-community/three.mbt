///|
test "ConeGeometry: type" {
  assert_eq(@geometries.ConeGeometry::new().type_, "ConeGeometry")
}

///|
test "ConeGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [@geometries.ConeGeometry::new()],
    @geometries.ConeGeometry::from_json,
  )
}
