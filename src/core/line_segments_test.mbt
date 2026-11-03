///|
test "LineSegments type" {
  let object = @core.LineSegments::new()
  assert_eq(object.type_, "LineSegments")
  assert_true(object.is_line())
  assert_true(object.is_line_segments())
  assert_eq(object.clone().type_, "LineSegments")
}

///|
test "LineSegments computeLineDistances" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(
        [0.0, 0.0, 0.0, 3.0, 4.0, 0.0, 9.0, 9.0, 0.0, 9.0, 9.0, 2.0],
        3,
      ),
    ),
  )
  ignore(@core.LineSegments::new(geometry~).compute_line_distances())
  guard geometry.attributes["lineDistance"] is Buffer(distances) else {
    fail("lineDistance is missing")
  }
  assert_eq(distances.array.to_array(), [0.0, 5.0, 5.0, 7.0])
}

///|
test "LineSegments raycast skips the gaps" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_from_points([
      vec3(-1, -1, 0),
      vec3(-1, 1, 0),
      vec3(1, 1, 0),
      vec3(1, -1, 0),
    ]),
  )
  let raycaster = @core.Raycaster::new(
    origin=vec3(0, 1, 1),
    direction=vec3(0, 0, -1),
  )
  raycaster.params.line.threshold = 0.01
  let hits = []
  @core.LineSegments::new(geometry~).raycast(raycaster, hits)
  assert_eq(hits.length(), 0)
}
