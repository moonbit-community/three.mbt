///|
fn triangle_shape() -> @extras.Shape {
  let triangle_shape = @extras.Shape::new()
  triangle_shape.move_to(0, -1) |> ignore
  triangle_shape.line_to(1, 1) |> ignore
  triangle_shape.line_to(-1, 1) |> ignore
  triangle_shape
}

///|
test "ShapeGeometry: type" {
  assert_eq(@geometries.ShapeGeometry::new().type_, "ShapeGeometry")
}

///|
test "ShapeGeometry: standard geometry tests" {
  let shape = triangle_shape()
  run_std_geometry_tests([@geometries.ShapeGeometry::new(shapes=shape)], data => {
    @geometries.ShapeGeometry::from_json(data, Map([(shape.uuid(), shape)]))
  })
}

///|
test "ShapeGeometry: the array form adds one group per shape" {
  let shapes = [triangle_shape(), triangle_shape()]
  let geometry = @geometries.ShapeGeometry::new_shapes(shapes)
  assert_eq(geometry.groups.length(), 2)
  assert_eq(@geometries.ShapeGeometry::new().groups.length(), 0)
}

///|
test "ShapeGeometry: toJSON keeps shapes after a transform" {
  let shape = triangle_shape()
  let geometry = @geometries.ShapeGeometry::new(shapes=shape)
  geometry.translate(1, 0, 0) |> ignore
  let json = geometry.to_json()
  assert_eq(json_get(json, "type"), Some(Json::string("BufferGeometry")))
  assert_true(json_get(json, "data") is Some(_))
  assert_eq(
    json_get(json, "shapes"),
    Some(Json::array([Json::string(shape.uuid())])),
  )
  assert_eq(json_get(json, "curveSegments"), None)
}

///|
test "ShapeGeometry: a class without the override writes the Shape objects" {
  let shape = triangle_shape()
  let single = @geometries.BoxGeometry::new().copy(
    @geometries.ShapeGeometry::new(shapes=shape),
  )
  assert_eq(json_get(single.to_json(), "shapes"), Some(shape.to_json()))
  let array = @geometries.BoxGeometry::new().copy(
    @geometries.ShapeGeometry::new_shapes([shape]),
  )
  assert_eq(
    json_get(array.to_json(), "shapes"),
    Some(Json::array([shape.to_json()])),
  )
}

///|
test "panic ShapeGeometry: toJSON after copying a plain geometry" {
  // upstream reads `undefined.uuid`
  @geometries.ShapeGeometry::new().copy(@core.BufferGeometry::new()).to_json()
  |> ignore
}
