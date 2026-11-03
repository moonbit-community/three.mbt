///|
test "Points type" {
  let object = @core.Points::new()
  assert_eq(object.type_, "Points")
  assert_true(object.is_points())
}

///|
test "Points copy/material" {
  let points1 = @core.Points::new()
  test_points_data(points1).material = Multiple([@core.Material::new()])
  let copy1 = points1.clone()
  assert_false(
    test_same_slot(
      test_points_data(points1).material,
      test_points_data(copy1).material,
    ),
  )
  let points2 = @core.Points::new()
  let copy2 = points2.clone()
  assert_true(
    test_same_slot(
      test_points_data(points2).material,
      test_points_data(copy2).material,
    ),
  )
}

///|
test "Points copy/morphTargets" {
  let points = @core.Points::new(geometry=test_morph_geometry())
  let influences = test_points_data(points).morph_target_influences.unwrap()
  influences[0] = 0.5
  let copy = test_points_data(points.clone())
  assert_eq(copy.morph_target_influences, Some([0.5]))
  assert_false(
    physical_equal(copy.morph_target_influences.unwrap(), influences),
  )
  assert_eq(
    copy.morph_target_dictionary,
    Some(Map::from_array([("target", 0)])),
  )
}
