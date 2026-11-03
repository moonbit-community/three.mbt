///|
test "UniformsGroup Extending" {
  let object = @core.UniformsGroup::new()
  let mut disposed = false
  object.add_event_listener("dispose", _ => disposed = true)
  object.dispose()
  assert_true(disposed)
}

///|
test "UniformsGroup add remove and copy" {
  let group = @core.UniformsGroup::new()
  let u1 = @core.Uniform::new(Number(1))
  let u2 = @core.Uniform::new(Vector3(vec3(1, 2, 3)))
  let array = [@core.Uniform::new(Number(3))]
  ignore(group.add(u1).add(u2).add_array(array))
  ignore(group.set_name("group").set_usage(@core.DynamicDrawUsage))
  assert_eq(group.uniforms.length(), 3)
  let copy = group.clone()
  assert_eq(copy.name, "group")
  assert_eq(copy.usage, @core.DynamicDrawUsage)
  assert_eq(copy.uniforms.length(), 3)
  guard copy.uniforms[1] is Single(c2) && c2.value is Vector3(v) else {
    fail("wrong entry")
  }
  assert_true(v.equals(vec3(1, 2, 3)))
  assert_false(physical_equal(c2, u2))
  assert_true(copy.uniforms[2] is Multiple([_]))
  ignore(group.remove(u1))
  assert_eq(group.uniforms.length(), 2)
  ignore(group.remove(u1))
  assert_eq(group.uniforms.length(), 2)
  ignore(group.remove_array(array))
  assert_eq(group.uniforms.length(), 1)
}
