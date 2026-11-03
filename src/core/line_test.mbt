///|
test "Line type" {
  let object = @core.Line::new()
  assert_eq(object.type_, "Line")
  assert_true(object.is_line())
  assert_false(object.is_line_segments())
}

///|
test "Line copy/material" {
  let line1 = @core.Line::new()
  test_line_data(line1).material = Multiple([@core.Material::new()])
  let copy1 = line1.clone()
  assert_false(
    test_same_slot(
      test_line_data(line1).material,
      test_line_data(copy1).material,
    ),
  )
  let line2 = @core.Line::new()
  let copy2 = line2.clone()
  assert_true(
    test_same_slot(
      test_line_data(line2).material,
      test_line_data(copy2).material,
    ),
  )
}

///|
test "Line copy/morphTargets" {
  let line = @core.Line::new(geometry=test_morph_geometry())
  let influences = test_line_data(line).morph_target_influences.unwrap()
  influences[0] = 0.5
  let copy = test_line_data(line.clone())
  assert_eq(copy.morph_target_influences, Some([0.5]))
  assert_false(
    physical_equal(copy.morph_target_influences.unwrap(), influences),
  )
  assert_eq(
    copy.morph_target_dictionary,
    Some(Map::from_array([("target", 0)])),
  )
}

///|
test "Line computeLineDistances" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(
        [0.0, 0.0, 0.0, 3.0, 4.0, 0.0, 3.0, 4.0, 2.0],
        3,
      ),
    ),
  )
  ignore(@core.Line::new(geometry~).compute_line_distances())
  guard geometry.attributes["lineDistance"] is Buffer(distances) else {
    fail("lineDistance is missing")
  }
  assert_eq(distances.array.to_array(), [0.0, 5.0, 7.0])
}
