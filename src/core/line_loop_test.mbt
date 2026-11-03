///|
test "LineLoop type" {
  let object = @core.LineLoop::new()
  assert_eq(object.type_, "LineLoop")
  assert_true(object.is_line())
  assert_true(object.is_line_loop())
  assert_eq(object.clone().type_, "LineLoop")
}

///|
test "LineLoop raycast tests the closing segment" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_from_points([vec3(-1, -1, 0), vec3(1, -1, 0), vec3(0, 1, 0)]),
  )
  let raycaster = @core.Raycaster::new(
    origin=vec3(-0.5, 0, 1),
    direction=vec3(0, 0, -1),
  )
  raycaster.params.line.threshold = 0.01
  let line_hits = []
  @core.Line::new(geometry~).raycast(raycaster, line_hits)
  assert_eq(line_hits.length(), 0)
  let loop_hits = []
  @core.LineLoop::new(geometry~).raycast(raycaster, loop_hits)
  assert_eq(loop_hits.length(), 1)
  assert_eq(loop_hits[0].index, Some(2))
}
