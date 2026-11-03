///|
test "InterleavedBufferAttribute count" {
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9]),
    3,
  )
  let instance = @core.InterleavedBufferAttribute::new(buffer, 2, 0)
  assert_eq(instance.count(), 2)
}

///|
// setY, setZ and setW are calculated in the same way, but are checked below.
test "InterleavedBufferAttribute setX" {
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9]),
    3,
  )
  let instance = @core.InterleavedBufferAttribute::new(buffer, 2, 0)
  ignore(instance.set_x(0, 123))
  ignore(instance.set_x(1, 321))
  assert_eq(instance.data.array[0], 123)
  assert_eq(instance.data.array[3], 321)
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 3, 7, 8, 9]),
    3,
  )
  let instance = @core.InterleavedBufferAttribute::new(buffer, 2, 1)
  ignore(instance.set_x(0, 123))
  ignore(instance.set_x(1, 321))
  // the offset was defined as 1, so go one step further in the array
  assert_eq(instance.data.array[1], 123)
  assert_eq(instance.data.array[4], 321)
}

///|
test "InterleavedBufferAttribute components and setXYZW" {
  let buffer = @core.InterleavedBuffer::new(@core.TypedArray::float32(10), 5)
  let attribute = @core.InterleavedBufferAttribute::new(buffer, 4, 1)
  ignore(attribute.set_y(1, 2).set_z(1, 3).set_w(1, 4))
  assert_eq(buffer.array.to_array(), [0.0, 0, 0, 0, 0, 0, 0, 2, 3, 4])
  ignore(attribute.set_xy(0, 1, 2))
  assert_eq(attribute.get_x(0), 1)
  assert_eq(attribute.get_y(0), 2)
  ignore(attribute.set_xyz(0, 3, 4, 5))
  assert_eq(attribute.get_z(0), 5)
  ignore(attribute.set_xyzw(0, 6, 7, 8, 9))
  assert_eq(attribute.get_w(0), 9)
  ignore(attribute.set_component(0, 2, 11))
  assert_eq(attribute.get_component(0, 2), 11)
}

///|
test "InterleavedBufferAttribute normalized" {
  let buffer = @core.InterleavedBuffer::new(@core.TypedArray::uint8(4), 2)
  let attribute = @core.InterleavedBufferAttribute::new(
    buffer,
    2,
    0,
    normalized=true,
  )
  ignore(attribute.set_xy(0, 1, 0.5))
  assert_eq(buffer.array[0], 255)
  assert_eq(buffer.array[1], 128)
  assert_eq(attribute.get_x(0), 1)
  assert_true(approx(attribute.get_y(0), 128.0 / 255.0))
}

///|
test "InterleavedBufferAttribute transforms" {
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 0, 0, 9, 0, 1, 0, 9]),
    4,
  )
  let attribute = @core.InterleavedBufferAttribute::new(buffer, 3, 0)
  ignore(
    attribute.apply_matrix4(@math.Matrix4::new().make_translation(1, 2, 3)),
  )
  assert_eq(buffer.array.to_array(), [2.0, 2, 3, 9, 1, 3, 3, 9])
  attribute.set_needs_update(true)
  assert_eq(buffer.version, 1)
}

///|
test "InterleavedBufferAttribute clone" {
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::uint16([1.0, 2, 3, 4, 5, 6]),
    3,
  )
  let attribute = @core.InterleavedBufferAttribute::new(buffer, 2, 1)
  // without data it de-interleaves
  guard attribute.clone() is Buffer(plain) else {
    fail("not a BufferAttribute")
  }
  assert_eq(plain.array.type_name(), "Uint16Array")
  assert_eq(plain.array.to_array(), [2.0, 3, 5, 6])
  // with data the buffer is shared between the clones
  let data : @core.AttributeCloneData = {
    array_buffers: Map([]),
    interleaved_buffers: Map([]),
  }
  let other = @core.InterleavedBufferAttribute::new(buffer, 1, 0)
  guard attribute.clone(data~) is Interleaved(a) else {
    fail("not interleaved")
  }
  guard other.clone(data~) is Interleaved(b) else { fail("not interleaved") }
  assert_true(physical_equal(a.data, b.data))
  assert_false(physical_equal(a.data, buffer))
  assert_eq(a.offset, 1)
}

///|
test "InterleavedBufferAttribute toJSON" {
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::uint16([1.0, 2, 3, 4, 5, 6]),
    3,
  )
  let attribute = @core.InterleavedBufferAttribute::new(buffer, 2, 1)
  guard attribute.to_json() is Object(plain) else { fail("not an object") }
  assert_true(plain.get("type") is Some(String("Uint16Array")))
  assert_eq(
    plain.get("array").unwrap(),
    Json::array([2.0, 3, 5, 6].map(v => Json::number(v))),
  )
  let data : Map[String, Json] = Map([])
  guard attribute.to_json(data~) is Object(json) else { fail("not an object") }
  assert_true(json.get("isInterleavedBufferAttribute") is Some(True))
  assert_eq(json.get("data").unwrap(), Json::string(buffer.uuid))
  assert_true(data.contains("interleavedBuffers"))
  assert_true(data.contains("arrayBuffers"))
}
