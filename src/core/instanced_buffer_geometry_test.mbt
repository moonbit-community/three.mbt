///|
test "InstancedBufferGeometry type" {
  let object = @core.InstancedBufferGeometry::new()
  assert_eq(object.type_, "InstancedBufferGeometry")
  assert_true(object.is_instanced_buffer_geometry)
}

///|
test "InstancedBufferGeometry copy" {
  let default_attribute1 = @core.BufferAttribute::new(
    @core.TypedArray::float32([1.0]),
    1,
  )
  let default_attribute2 = @core.BufferAttribute::new(
    @core.TypedArray::float32([2.0]),
    1,
  )
  let instance = @core.InstancedBufferGeometry::new()
  instance.add_group(0, 10, material_index=1)
  instance.add_group(10, 5, material_index=2)
  ignore(instance.set_index([0, 1, 2]))
  ignore(instance.set_attribute("defaultAttribute1", default_attribute1))
  ignore(instance.set_attribute("defaultAttribute2", default_attribute2))
  instance.instance_count = 7
  let copied = @core.InstancedBufferGeometry::new().copy(instance)
  assert_true(copied.is_instanced_buffer_geometry)
  assert_eq(copied.instance_count, 7)
  assert_eq(copied.index.unwrap().array().to_array(), [0.0, 1, 2])
  assert_eq(
    copied.attributes.get("defaultAttribute1").unwrap().array().to_array(),
    default_attribute1.array.to_array(),
  )
  assert_eq(
    copied.attributes.get("defaultAttribute2").unwrap().array().to_array(),
    default_attribute2.array.to_array(),
  )
  assert_eq(copied.groups[0].start, 0)
  assert_eq(copied.groups[0].count, 10)
  assert_eq(copied.groups[0].material_index, 1)
  assert_eq(copied.groups[1].start, 10)
  assert_eq(copied.groups[1].count, 5)
  assert_eq(copied.groups[1].material_index, 2)
}

///|
test "InstancedBufferGeometry clone and toJSON" {
  let instance = @core.InstancedBufferGeometry::new()
  instance.instance_count = 4
  let cloned = instance.clone()
  assert_eq(cloned.type_, "InstancedBufferGeometry")
  assert_true(cloned.is_instanced_buffer_geometry)
  assert_eq(cloned.instance_count, 4)
  guard instance.to_json() is Object(json) else { fail("not an object") }
  assert_true(json.get("instanceCount") is Some(Number(4, ..)))
  assert_true(json.get("isInstancedBufferGeometry") is Some(True))
}
