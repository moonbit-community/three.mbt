///|
test "ExtrudeGeometry: type" {
  assert_eq(@geometries.ExtrudeGeometry::new().type_, "ExtrudeGeometry")
}

///|
test "ExtrudeGeometry: omitted options stay out of parameters" {
  let geometry = @geometries.ExtrudeGeometry::new(depth=2, bevel_enabled=false)
  let json = geometry.to_json()
  assert_eq(
    json_get(json, "options"),
    Some(
      Json::object({
        "depth": Json::number(2),
        "bevelEnabled": Json::boolean(false),
      }),
    ),
  )
}

///|
test "ExtrudeGeometry: from_json keeps the key order of options" {
  let shape = @extras.Shape::new(points=[
    @math.Vector2::new(0, 0),
    @math.Vector2::new(1, 0),
    @math.Vector2::new(0, 1),
  ])
  let options = Json::object({
    "steps": Json::number(2),
    "depth": Json::number(3),
    "curveSegments": Json::number(4),
  })
  let data = Json::object({
    "shapes": Json::array([Json::string(shape.uuid())]),
    "options": options,
  })
  let geometry = @geometries.ExtrudeGeometry::from_json(
    data,
    Map([(shape.uuid(), shape)]),
  )
  assert_eq(geometry.to_json().stringify().contains(options.stringify()), true)
}

///|
test "ExtrudeGeometry: toJSON keeps shapes and options after a transform" {
  let shape = @extras.Shape::new(points=[
    @math.Vector2::new(0, 0),
    @math.Vector2::new(1, 0),
    @math.Vector2::new(0, 1),
  ])
  let geometry = @geometries.ExtrudeGeometry::new(shapes=[shape], depth=2)
  geometry.rotate_x(0.5) |> ignore
  guard geometry.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json.keys().collect(), [
    "metadata", "uuid", "type", "name", "data", "shapes", "options",
  ])
  assert_eq(json.get("shapes"), Some(Json::array([Json::string(shape.uuid())])))
  assert_eq(
    json.get("options"),
    Some(Json::object({ "depth": Json::number(2) })),
  )
}

///|
test "ExtrudeGeometry: extrudePath is serialized when toJSON runs" {
  let points = [
    @math.Vector3::new(0, 0, 0),
    @math.Vector3::new(1, 2, 0),
    @math.Vector3::new(2, 0, 1),
  ]
  let path = @extras.CatmullRomCurve3::new(points~)
  let geometry = @geometries.ExtrudeGeometry::new(steps=2, extrude_path=path)
  points[1].x = 7
  guard json_get(geometry.to_json(), "options") is Some(options) else {
    fail("no options")
  }
  assert_eq(json_get(options, "extrudePath"), Some(path.to_json()))
}

///|
test "ExtrudeGeometry: the default shape is upstream's single Shape" {
  let geometry = @geometries.ExtrudeGeometry::new()
  let box = @geometries.BoxGeometry::new().copy(geometry)
  assert_true(json_get(box.to_json(), "shapes") is Some(Object(_)))
}
