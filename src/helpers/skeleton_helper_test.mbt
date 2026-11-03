///|
test "SkeletonHelper extends LineSegments" {
  let bone = @core.Bone::new()
  let object = @helpers.SkeletonHelper::new(bone)
  assert_true(object.is_line_segments())
}

///|
test "SkeletonHelper instancing and type" {
  let bone = @core.Bone::new()
  let object = @helpers.SkeletonHelper::new(bone)
  assert_eq(object.type_, "SkeletonHelper")
}

///|
test "isSkeletonHelper" {
  let bone = @core.Bone::new()
  let object = @helpers.SkeletonHelper::new(bone)
  assert_true(object.has_extension_flag("isSkeletonHelper"))
}

///|
test "SkeletonHelper dispose" {
  let bone = @core.Bone::new()
  let object = @helpers.SkeletonHelper::new(bone)
  object.dispose()
}

///|
test "SkeletonHelper draws bone to parent" {
  let root = @core.Bone::new()
  let child = @core.Bone::new()
  ignore(child.position.set(0.0, 2.0, 0.0))
  ignore(root.add(child))
  let object = @helpers.SkeletonHelper::new(root)
  assert_eq(@helpers.SkeletonHelper::of(object).unwrap().bones.length(), 2)
  root.update_matrix_world()
  object.update_matrix_world()
  let position = object.get_geometry().unwrap().attributes["position"]
  assert_eq(position.count(), 2)
  assert_eq(position.get_y(0), 2.0)
  assert_eq(position.get_y(1), 0.0)
}
