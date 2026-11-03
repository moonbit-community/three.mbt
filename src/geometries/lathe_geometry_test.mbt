///|
test "LatheGeometry: type" {
  assert_eq(@geometries.LatheGeometry::new().type_, "LatheGeometry")
}

///|
test "LatheGeometry: standard geometry tests" {
  run_std_geometry_tests(
    [@geometries.LatheGeometry::new(points=[], segments=0, phi_length=0)],
    @geometries.LatheGeometry::from_json,
  )
}

///|
test "LatheGeometry: normals" {
  let normals = @geometries.LatheGeometry::new()
    .get_attribute("normal")
    .unwrap()
  let normal = @math.Vector3::new(0, 0, 0)
  let mut non_unit_normals = 0
  for i in 0..<normals.count() {
    normal.from_buffer_attribute(normals, i) |> ignore
    if (normal.length() - 1.0).abs() > 1.0e-6 {
      non_unit_normals += 1
    }
  }
  assert_eq(non_unit_normals, 0)
}

///|
test "LatheGeometry: parameters.points are serialized when toJSON runs" {
  let points = [@math.Vector2::new(0, -1), @math.Vector2::new(0.5, 0)]
  let geometry = @geometries.LatheGeometry::new(points~, segments=3)
  points[0].x = 0.75
  points.push(@math.Vector2::new(0.25, 1))
  guard json_get(geometry.to_json(), "points") is Some(Array(json)) else {
    fail("no points")
  }
  assert_eq(json.length(), 3)
  assert_eq(json_get(json[0], "x"), Some(Json::number(0.75)))
}
