///|
fn box_geometries() -> Array[@core.BufferGeometry] {
  [
    @geometries.BoxGeometry::new(),
    @geometries.BoxGeometry::new(width=10, height=20, depth=30),
    @geometries.BoxGeometry::new(
      width=10,
      height=20,
      depth=30,
      width_segments=2,
      height_segments=3,
      depth_segments=4,
    ),
  ]
}

///|
test "BoxGeometry: type" {
  assert_eq(@geometries.BoxGeometry::new().type_, "BoxGeometry")
}

///|
test "BoxGeometry: standard geometry tests" {
  run_std_geometry_tests(box_geometries(), @geometries.BoxGeometry::from_json)
}

///|
test "BoxGeometry: toJSON parametric serialization for untransformed geometry" {
  let geometry = @geometries.BoxGeometry::new(width=10, height=20, depth=30)
  let json = geometry.to_json()
  assert_false(geometry._transformed)
  assert_eq(json_get(json, "type"), Some(Json::string("BoxGeometry")))
  assert_eq(json_get(json, "width"), Some(Json::number(10)))
  assert_eq(json_get(json, "height"), Some(Json::number(20)))
  assert_eq(json_get(json, "depth"), Some(Json::number(30)))
  assert_eq(json_get(json, "data"), None)
}

///|
test "BoxGeometry: toJSON attribute serialization after translate()" {
  let geometry = @geometries.BoxGeometry::new(width=10, height=20, depth=30)
  geometry.translate(1, 2, 3) |> ignore
  let json = geometry.to_json()
  assert_true(geometry._transformed)
  assert_eq(json_get(json, "type"), Some(Json::string("BufferGeometry")))
  assert_eq(json_get(json, "width"), None)
  let attributes = json_get(json_get(json, "data").unwrap(), "attributes")
  assert_true(json_get(attributes.unwrap(), "position") is Some(_))
}

///|
test "BoxGeometry: toJSON clone of a transformed geometry preserves _transformed" {
  let source = @geometries.BoxGeometry::new(width=10, height=20, depth=30)
  source.translate(1, 2, 3) |> ignore
  let clone = source.clone()
  let json = clone.to_json()
  assert_true(clone._transformed)
  assert_eq(json_get(json, "type"), Some(Json::string("BufferGeometry")))
  let attributes = json_get(json_get(json, "data").unwrap(), "attributes")
  assert_true(json_get(attributes.unwrap(), "position") is Some(_))
}
