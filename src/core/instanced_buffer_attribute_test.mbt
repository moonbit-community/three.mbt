///|
test "InstancedBufferAttribute Instancing" {
  let instance = @core.InstancedBufferAttribute::new(
    @core.TypedArray::float32(10),
    2,
  )
  assert_eq(instance.mesh_per_attribute, 1)
  let instance = @core.InstancedBufferAttribute::new(
    @core.TypedArray::float32(10),
    2,
    normalized=false,
    mesh_per_attribute=123,
  )
  assert_eq(instance.mesh_per_attribute, 123)
  assert_true(instance.is_instanced_buffer_attribute())
}

///|
test "InstancedBufferAttribute copy" {
  let array = @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9])
  let instance = @core.InstancedBufferAttribute::new(
    array,
    2,
    normalized=true,
    mesh_per_attribute=123,
  )
  let copied = instance.copy(instance)
  assert_true(copied.is_instanced_buffer_attribute())
  assert_eq(copied.item_size, 2)
  assert_true(copied.normalized)
  assert_eq(copied.mesh_per_attribute, 123)
  for i in 0..<array.length() {
    assert_eq(copied.array[i], array[i])
  }
}

///|
test "InstancedBufferAttribute clone and toJSON" {
  let array = @core.TypedArray::float32([1.0, 2, 3, 7])
  let instance = @core.InstancedBufferAttribute::new(
    array,
    2,
    mesh_per_attribute=3,
  )
  let cloned = instance.clone()
  assert_true(cloned.is_instanced_buffer_attribute())
  assert_eq(cloned.mesh_per_attribute, 3)
  assert_false(physical_equal(cloned.array, instance.array))
  guard instance.to_json() is Object(json) else { fail("not an object") }
  assert_true(json.get("meshPerAttribute") is Some(Number(3, ..)))
  assert_true(json.get("isInstancedBufferAttribute") is Some(True))
}
