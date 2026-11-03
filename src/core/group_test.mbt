///|
test "Group type" {
  let object = @core.Group::new()
  assert_eq(object.type_, "Group")
  assert_true(object.is_group())
  assert_true(object.clone().is_group())
}
