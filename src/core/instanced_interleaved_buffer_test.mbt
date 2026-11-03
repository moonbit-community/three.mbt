///|
test "InstancedInterleavedBuffer Instancing" {
  let array = @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9])
  let instance = @core.InstancedInterleavedBuffer::new(array, 3)
  assert_eq(instance.mesh_per_attribute, 1)
  assert_true(instance.is_instanced_interleaved_buffer)
}

///|
test "InstancedInterleavedBuffer copy" {
  let array = @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9])
  let instance = @core.InstancedInterleavedBuffer::new(array, 3)
  let copied = instance.copy(instance)
  assert_eq(copied.mesh_per_attribute, 1)
}

///|
test "InstancedInterleavedBuffer clone and toJSON" {
  let array = @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9])
  let instance = @core.InstancedInterleavedBuffer::new(
    array,
    3,
    mesh_per_attribute=4,
  )
  let cloned = instance.clone({
    array_buffers: Map([]),
    interleaved_buffers: Map([]),
  })
  assert_true(cloned.is_instanced_interleaved_buffer)
  assert_eq(cloned.mesh_per_attribute, 4)
  let data : Map[String, Json] = Map([])
  guard instance.to_json(data) is Object(json) else { fail("not an object") }
  assert_true(json.get("isInstancedInterleavedBuffer") is Some(True))
  assert_true(json.get("meshPerAttribute") is Some(Number(4, ..)))
}
