///|
test "PlaneHelper extends Line" {
  let object = @helpers.PlaneHelper::new()
  assert_true(object.is_line())
}

///|
test "PlaneHelper instancing and type" {
  let object = @helpers.PlaneHelper::new()
  assert_eq(object.type_, "PlaneHelper")
}

///|
test "PlaneHelper dispose" {
  let object = @helpers.PlaneHelper::new()
  object.dispose()
}

///|
test "PlaneHelper faces the plane" {
  let plane = @math.Plane::new(
    normal=@math.Vector3::new(0.0, 0.0, 1.0),
    constant=-2.0,
  )
  let object = @helpers.PlaneHelper::new(plane~, size=4.0)
  object.update_matrix_world()
  assert_true(object.position.equals(@math.Vector3::new(0.0, 0.0, 2.0)))
  assert_true(object.scale.equals(@math.Vector3::new(2.0, 2.0, 1.0)))
  assert_eq(object.children.length(), 1)
  assert_true(object.children[0].is_mesh())
}
