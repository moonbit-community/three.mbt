// Port of the geometry helpers in upstream test/unit/utils/qunit-utils.js. Upstream
// reads geometries back through ObjectLoader; here `from_json` is the class's static.

///|
fn json_get(json : Json, key : String) -> Json? {
  guard json is Object(fields) else { return None }
  fields.get(key)
}

///|
fn position_count(geometry : @core.BufferGeometry) -> Int32 {
  geometry.get_attribute("position").unwrap().count()
}

///|
/// `parameters` as `toJSON` writes them: lazy values evaluated, and `shapes`, which
/// upstream holds as `Shape` objects, as the uuids the class's `toJSON` writes.
fn parameter_values(parameters : @core.GeometryParameters) -> Map[String, Json] {
  let values = parameters.resolved_values()
  if values.contains("shapes") {
    values["shapes"] = Json::array(
      parameters.shapes.map(shape => Json::string(shape.uuid())),
    )
  }
  values
}

///|
/// Compare json file with its source geometry.
fn check_geometry_json_writing(
  geometry : @core.BufferGeometry,
  json : Json,
) -> Unit raise {
  assert_eq(
    json_get(json_get(json, "metadata").unwrap(), "version"),
    Some(Json::number(4.7)),
  )
  assert_eq(json_get(json, "type"), Some(Json::string(geometry.type_)))
  assert_eq(json_get(json, "uuid"), Some(Json::string(geometry.uuid)))
  assert_eq(json_get(json, "id"), None)
  guard geometry.parameters is Some(parameters) else { return }
  let values = parameter_values(parameters)
  // All parameters from geometry should be persisted.
  for key, value in values {
    assert_eq(json_get(json, key), Some(value))
  }
  // All parameters from json should be transferred to the geometry.
  // json is flat. Ignore first level json properties that are not parameters.
  guard json is Object(fields) else { fail("json is not an object") }
  for key, value in fields {
    if !["metadata", "uuid", "type", "name"].contains(key) {
      assert_eq(values.get(key), Some(value))
    }
  }
}

///|
/// Check parsing and reconstruction of json geometry.
fn check_geometry_json_reading(
  json : Json,
  geometry : @core.BufferGeometry,
  from_json : (Json) -> @core.BufferGeometry,
) -> Unit raise {
  let output = from_json(json)
  assert_eq(output.type_, geometry.type_)
  assert_eq(
    parameter_values(output.parameters.unwrap()),
    parameter_values(geometry.parameters.unwrap()),
  )
  assert_eq(position_count(output), position_count(geometry))
}

///|
/// Verify geom -> json -> geom.
fn check_geometry_json_roundtrip(
  geometry : @core.BufferGeometry,
  from_json : (Json) -> @core.BufferGeometry,
) -> Unit raise {
  let json = geometry.to_json()
  check_geometry_json_writing(geometry, json)
  check_geometry_json_reading(json, geometry, from_json)
}

///|
fn check_geometry_clone(
  geometry : @core.BufferGeometry,
  from_json : (Json) -> @core.BufferGeometry,
) -> Unit raise {
  let copy = geometry.clone()
  assert_true(copy.uuid != geometry.uuid)
  assert_true(copy.id != geometry.id)
  assert_eq(copy.type_, geometry.type_)
  assert_eq(copy.parameters is None, geometry.parameters is None)
  assert_eq(position_count(copy), position_count(geometry))
  // json round trip with clone
  check_geometry_json_roundtrip(copy, from_json)
}

///|
/// Run common geometry tests.
fn run_std_geometry_tests(
  geometries : Array[@core.BufferGeometry],
  from_json : (Json) -> @core.BufferGeometry,
) -> Unit raise {
  for geometry in geometries {
    check_geometry_clone(geometry, from_json)
    check_geometry_json_roundtrip(geometry, from_json)
  }
}

///|
let test_pi : Double = 3.141592653589793
