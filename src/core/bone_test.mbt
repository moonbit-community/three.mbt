///|
test "Bone type" {
  let object = @core.Bone::new()
  assert_eq(object.type_, "Bone")
  assert_true(object.is_bone())
  assert_true(object.clone().is_bone())
}
