///|
test "ArrowHelper extends Object3D" {
  let object = @helpers.ArrowHelper::new()
  assert_true(object.kind is Base)
  assert_eq(object.children.length(), 2)
  assert_true(object.children[0].is_line())
  assert_true(object.children[1].is_mesh())
}

///|
test "ArrowHelper instancing" {
  let object = @helpers.ArrowHelper::new()
  assert_true(@helpers.ArrowHelper::of(object) is Some(_))
}

///|
test "ArrowHelper type" {
  let object = @helpers.ArrowHelper::new()
  assert_eq(object.type_, "ArrowHelper")
}

///|
test "ArrowHelper dispose" {
  let object = @helpers.ArrowHelper::new()
  object.dispose()
}

///|
test "ArrowHelper shares its geometries and sets direction and length" {
  let a = @helpers.ArrowHelper::new()
  let b = @helpers.ArrowHelper::new(
    dir=@math.Vector3::new(0.0, -1.0, 0.0),
    length=2.0,
  )
  let pa = @helpers.ArrowHelper::of(a).unwrap()
  let pb = @helpers.ArrowHelper::of(b).unwrap()
  assert_true(physical_equal(pa.line.get_geometry(), pb.line.get_geometry()))
  assert_true(b.quaternion.equals(@math.Quaternion::new(1.0, 0.0, 0.0, 0.0)))
  assert_eq(pb.cone.position.y, 2.0)
  assert_eq(pb.line.scale.y, 1.6)
  let copy = b.clone()
  assert_eq(copy.type_, "ArrowHelper")
  assert_eq(copy.children.length(), 2)
  assert_eq(@helpers.ArrowHelper::of(copy).unwrap().cone.position.y, 2.0)
}
