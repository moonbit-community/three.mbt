///|
test "Box3Helper extends LineSegments" {
  let object = @helpers.Box3Helper::new()
  assert_true(object.is_line_segments())
}

///|
test "Box3Helper instancing and type" {
  let object = @helpers.Box3Helper::new()
  assert_eq(object.type_, "Box3Helper")
}

///|
test "Box3Helper dispose" {
  let object = @helpers.Box3Helper::new()
  object.dispose()
}

///|
test "Box3Helper follows its box in updateMatrixWorld" {
  let box = @math.Box3::new(
    min=@math.Vector3::new(-1.0, 0.0, 2.0),
    max=@math.Vector3::new(3.0, 4.0, 4.0),
  )
  let object = @helpers.Box3Helper::new(box~)
  object.update_matrix_world()
  assert_true(object.position.equals(@math.Vector3::new(1.0, 2.0, 3.0)))
  assert_true(object.scale.equals(@math.Vector3::new(2.0, 2.0, 1.0)))
  assert_eq(object.matrix_world.elements[12], 1.0)
  // an empty box leaves the helper alone
  ignore(box.make_empty())
  ignore(object.position.set(0.0, 0.0, 0.0))
  object.update_matrix_world()
  assert_eq(object.matrix_world.elements[12], 1.0)
}
