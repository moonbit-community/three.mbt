///|
test "TorusKnotGeometry: type" {
  assert_eq(@geometries.TorusKnotGeometry::new().type_, "TorusKnotGeometry")
}

///|
test "TorusKnotGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [
      @geometries.TorusKnotGeometry::new(),
      @geometries.TorusKnotGeometry::new(radius=10),
      @geometries.TorusKnotGeometry::new(radius=10, tube=20),
      @geometries.TorusKnotGeometry::new(
        radius=10,
        tube=20,
        tubular_segments=30,
      ),
      @geometries.TorusKnotGeometry::new(
        radius=10,
        tube=20,
        tubular_segments=30,
        radial_segments=10,
      ),
      @geometries.TorusKnotGeometry::new(
        radius=10,
        tube=20,
        tubular_segments=30,
        radial_segments=10,
        p=3,
        q=2,
      ),
    ],
    @geometries.TorusKnotGeometry::from_json,
  )
}
