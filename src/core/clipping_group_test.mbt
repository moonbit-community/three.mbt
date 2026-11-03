///|
test "ClippingGroup defaults" {
  let object = @core.ClippingGroup::new()
  assert_eq(object.type_, "Group")
  assert_true(object.is_group())
  assert_true(object.is_clipping_group())
  guard object.kind is ClippingGroup(group) else { fail("not a ClippingGroup") }
  assert_eq(group.clipping_planes.length(), 0)
  assert_true(group.enabled)
  assert_false(group.clip_intersection)
  assert_false(group.clip_shadows)
}
