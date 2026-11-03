///|
test "TypedArray construction" {
  assert_eq(@core.TypedArray::float32(3).length(), 3)
  assert_eq(@core.TypedArray::float64(3).type_name(), "Float64Array")
  assert_true(@core.TypedArray::float64(3).kind() is Other)
  assert_eq(@core.TypedArray::uint8([1, 2]).to_array(), [1.0, 2])
  assert_eq(@core.TypedArray::new(Int16Array, [1.5]).to_array(), [1.0])
  assert_true(
    @core.TypedArray::new_by_name("Int32Array", 2).kind() is Int32Array,
  )
}

///|
test "TypedArray kind round trip" {
  let kinds : Array[@math.TypedArrayKind] = [
    Float32Array,
    Uint32Array,
    Uint16Array,
    Uint8Array,
    Uint8ClampedArray,
    Int32Array,
    Int16Array,
    Int8Array,
  ]
  for kind in kinds {
    let name = @core.TypedArray::new(kind, 1).type_name()
    assert_eq(@core.TypedArray::new_by_name(name, 1).type_name(), name)
    assert_false(@core.TypedArray::new(kind, 1).kind() is Other)
  }
}

///|
test "TypedArray slice, subarray and views" {
  let a = @core.TypedArray::float32([1.0, 2, 3, 4])
  let slice = a.slice(start=1, end=3)
  slice[0] = 9
  assert_eq(a[1], 2)
  assert_eq(slice.to_array(), [9.0, 3])
  let sub = a.subarray(start=2)
  sub[0] = 7
  assert_eq(a[2], 7)
  assert_true(physical_equal(sub.buffer(), a.buffer()))
  assert_eq(sub.byte_offset(), 8)
  assert_eq(sub.byte_length(), 8)
  assert_eq(sub.bytes_per_element(), 4)
  let like = a.new_like(2)
  assert_eq(like.type_name(), "Float32Array")
  assert_eq(like.length(), 2)
  let clone = a.clone()
  clone[0] = 5
  assert_eq(a[0], 1)
  like.fill(3)
  assert_eq(like.to_array(), [3.0, 3])
}

///|
test "ArrayBuffer uuid is stable" {
  let buffer = @core.ArrayBuffer::new(8)
  assert_eq(buffer.byte_length(), 8)
  assert_eq(buffer.uuid(), buffer.uuid())
}

///|
test "half float round trips" {
  for value in [0.0, 1, -1, 0.5, 1.5, 100.25, -2.5, 65504] {
    assert_eq(@core.from_half_float(@core.to_half_float(value)), value)
  }
  assert_eq(@core.to_half_float(1.0), 15360)
  assert_eq(@core.to_half_float(-2.0), 49152)
}

///|
test "half float infinities and NaN" {
  let infinity = 1.0 / 0.0
  assert_eq(@core.from_half_float(31744), infinity) // 0x7c00
  assert_eq(@core.from_half_float(64512), -infinity) // 0xfc00
  assert_true(@core.from_half_float(32256).is_nan()) // 0x7e00
  assert_true(@core.from_half_float(65480).is_nan()) // 0xffc8
  assert_eq(@core.to_half_float(65504), 31743) // the largest finite half float
  assert_eq(@core.to_half_float(-65504), 64511)
  assert_eq(@core.to_half_float(1.0e6), 31743) // clamped
}
