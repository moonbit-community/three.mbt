///|
fn check_instance_against_copy(
  instance : @core.InterleavedBuffer,
  copied : @core.InterleavedBuffer,
) -> Unit raise {
  for i in 0..<instance.array.length() {
    assert_eq(copied.array[i], instance.array[i])
  }
  assert_eq(copied.stride, instance.stride)
  assert_eq(copied.usage, @core.DynamicDrawUsage)
}

///|
fn clone_data() -> @core.AttributeCloneData {
  { array_buffers: Map([]), interleaved_buffers: Map([]), }
}

///|
test "InterleavedBuffer needsUpdate" {
  let a = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 4]),
    2,
  )
  a.set_needs_update(true)
  assert_eq(a.version, 1)
}

///|
test "InterleavedBuffer setUsage" {
  let instance = @core.InterleavedBuffer::new(@core.TypedArray::float32(4), 2)
  ignore(instance.set_usage(@core.DynamicDrawUsage))
  assert_eq(instance.usage, @core.DynamicDrawUsage)
}

///|
test "InterleavedBuffer copy" {
  let array = @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9])
  let instance = @core.InterleavedBuffer::new(array, 3)
  ignore(instance.set_usage(@core.DynamicDrawUsage))
  check_instance_against_copy(instance, instance.copy(instance))
}

///|
test "InterleavedBuffer copyAt" {
  let a = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 4, 5, 6, 7, 8, 9]),
    3,
  )
  let b = @core.InterleavedBuffer::new(@core.TypedArray::float32(9), 3)
  ignore(b.copy_at(1, a, 2))
  ignore(b.copy_at(0, a, 1))
  ignore(b.copy_at(2, a, 0))
  assert_eq(b.array.to_array(), [4.0, 5, 6, 7, 8, 9, 1, 2, 3])
}

///|
test "InterleavedBuffer set" {
  let instance = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9]),
    3,
  )
  ignore(instance.set([0.0, -1]))
  assert_eq(instance.array[0], 0)
  assert_eq(instance.array[1], -1)
}

///|
test "InterleavedBuffer clone" {
  let instance = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9]),
    3,
  )
  ignore(instance.set_usage(@core.DynamicDrawUsage))
  check_instance_against_copy(instance, instance.clone(clone_data()))
}

///|
test "InterleavedBuffer clone (views into a shared array buffer)" {
  // e.g. GLTFLoader creates interleaved buffers as views at different offsets into one array buffer
  let buffer = @core.TypedArray::float32([
    1.0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12,
  ]).buffer()
  let view = (offset, length) => {
    @core.TypedArray::view_by_name(
      "Float32Array",
      buffer,
      byte_offset=offset,
      length~,
    )
  }
  let a = @core.InterleavedBuffer::new(view(0, 4), 2)
  let b = @core.InterleavedBuffer::new(view(16, 8), 4)
  let c = @core.InterleavedBuffer::new(view(16, 8), 2)
  let data = clone_data()
  let cloned_a = a.clone(data)
  let cloned_b = b.clone(data)
  let cloned_c = c.clone(data)
  assert_eq(cloned_a.array.to_array(), [1.0, 2, 3, 4])
  assert_eq(cloned_b.array.to_array(), [5.0, 6, 7, 8, 9, 10, 11, 12])
  assert_false(physical_equal(cloned_a.array.buffer(), buffer))
  assert_eq(cloned_b.array.buffer().byte_length(), 32)
  assert_true(physical_equal(cloned_b.array.buffer(), cloned_c.array.buffer()))
}

///|
test "InterleavedBuffer onUpload" {
  let a = @core.InterleavedBuffer::new(@core.TypedArray::float32(4), 2)
  let func = () => ()
  ignore(a.on_upload(func))
  assert_true(physical_equal(a.on_upload_callback, func))
}

///|
test "InterleavedBuffer count" {
  let instance = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9]),
    3,
  )
  assert_eq(instance.count, 2)
}

///|
test "InterleavedBuffer update ranges" {
  let instance = @core.InterleavedBuffer::new(@core.TypedArray::float32(6), 3)
  instance.add_update_range(1, 2)
  assert_eq(instance.update_ranges.length(), 1)
  instance.clear_update_ranges()
  assert_eq(instance.update_ranges.length(), 0)
}

///|
test "InterleavedBuffer toJSON shares array buffers" {
  let instance = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2]),
    2,
  )
  let data : Map[String, Json] = Map([])
  guard instance.to_json(data) is Object(json) else { fail("not an object") }
  assert_true(json.get("stride") is Some(Number(2, ..)))
  assert_true(json.get("type") is Some(String("Float32Array")))
  guard data.get("arrayBuffers") is Some(Object(array_buffers)) else {
    fail("no arrayBuffers")
  }
  assert_eq(array_buffers.length(), 1)
  // the words of 1.0f and 2.0f
  for _, words in array_buffers {
    assert_eq(
      words,
      Json::array([Json::number(1065353216), Json::number(1073741824)]),
    )
  }
}
