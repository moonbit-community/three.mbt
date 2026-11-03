///|
test "TubeGeometry: type" {
  assert_eq(@geometries.TubeGeometry::new().type_, "TubeGeometry")
}

///|
test "TubeGeometry: frames" {
  let path = @extras.LineCurve3::new(
    v1=@math.Vector3::new(0, 0, 0),
    v2=@math.Vector3::new(0, 1, 0),
  )
  let geometry = @geometries.TubeGeometry::new(path~, tubular_segments=4)
  assert_eq(
    @geometries.TubeGeometry::frames(geometry).unwrap().normals.length(),
    5,
  )
  // `clone` runs `new TubeGeometry()`, whose frames `copy` leaves alone
  let clone = geometry.clone()
  assert_eq(
    @geometries.TubeGeometry::frames(clone).unwrap().normals.length(),
    65,
  )
  assert_true(
    @geometries.TubeGeometry::frames(@geometries.BoxGeometry::new()) is None,
  )
}

///|
test "TubeGeometry: toJSON keeps path after a transform, read when toJSON runs" {
  let v1 = @math.Vector3::new(-1, 1, 0)
  let path = @extras.QuadraticBezierCurve3::new(
    v0=@math.Vector3::new(-1, -1, 0),
    v1~,
    v2=@math.Vector3::new(1, 1, 0),
  )
  let geometry = @geometries.TubeGeometry::new(path~, tubular_segments=4)
  geometry.translate(1, 0, 0) |> ignore
  v1.x = 9
  let json = geometry.to_json()
  assert_true(json_get(json, "data") is Some(_))
  assert_eq(json_get(json, "path"), Some(path.to_json()))
  assert_eq(json_get(json, "radius"), None)
}
