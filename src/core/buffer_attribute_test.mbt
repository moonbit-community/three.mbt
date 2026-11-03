///|
fn float32_attribute(
  values : Array[Double],
  item_size : Int32,
  normalized~ : Bool = false,
) -> @core.BufferAttribute {
  @core.BufferAttribute::new(
    @core.TypedArray::float32(values),
    item_size,
    normalized~,
  )
}

///|
test "BufferAttribute setUsage" {
  let attr = float32_attribute([0.0], 1)
  ignore(attr.set_usage(@core.DynamicDrawUsage))
  assert_eq(attr.usage, @core.DynamicDrawUsage)
}

///|
test "BufferAttribute copy" {
  let attr = float32_attribute([1.0, 2, 3, 4, 5, 6], 3)
  ignore(attr.set_usage(@core.DynamicDrawUsage))
  attr.set_needs_update(true)
  let attr_copy = float32_attribute([0.0], 1).copy(attr)
  assert_eq(attr.count, attr_copy.count)
  assert_eq(attr.item_size, attr_copy.item_size)
  assert_eq(attr.usage, attr_copy.usage)
  assert_eq(attr.array.length(), attr_copy.array.length())
  assert_eq(attr.version, 1)
  assert_eq(attr_copy.version, 0)
}

///|
test "BufferAttribute copyAt" {
  let attr = float32_attribute([1.0, 2, 3, 4, 5, 6, 7, 8, 9], 3)
  let attr2 = @core.BufferAttribute::new(@core.TypedArray::float32(9), 3)
  ignore(attr2.copy_at(1, attr, 2))
  ignore(attr2.copy_at(0, attr, 1))
  ignore(attr2.copy_at(2, attr, 0))
  assert_eq(attr2.array.to_array(), [4.0, 5, 6, 7, 8, 9, 1, 2, 3])
}

///|
test "BufferAttribute copyArray" {
  let f32a = @core.TypedArray::float32([5.0, 6, 7, 8])
  let a = float32_attribute([1.0, 2, 3, 4], 2)
  ignore(a.copy_array(f32a))
  assert_eq(a.array.to_array(), f32a.to_array())
}

///|
test "BufferAttribute set" {
  let a = float32_attribute([1.0, 2, 3, 4], 2)
  ignore(a.set([9.0]))
  ignore(a.set([8.0], offset=2))
  assert_eq(a.array.to_array(), [9.0, 2, 8, 4])
}

///|
test "BufferAttribute set[X, Y, Z, W, XYZ, XYZW]/get[X, Y, Z, W]" {
  let a = float32_attribute([1.0, 2, 3, 4, 5, 6, 7, 8], 4)
  ignore(a.set_x(1, a.get_x(1) * -1))
  ignore(a.set_y(1, a.get_y(1) * -1))
  ignore(a.set_z(0, a.get_z(0) * -1))
  ignore(a.set_w(0, a.get_w(0) * -1))
  assert_eq(a.array.to_array(), [1.0, 2, -3, -4, -5, -6, 7, 8])
}

///|
test "BufferAttribute setXY" {
  let a = float32_attribute([1.0, 2, 3, 4], 2)
  ignore(a.set_xy(0, -1, -2))
  assert_eq(a.array.to_array(), [-1.0, -2, 3, 4])
}

///|
test "BufferAttribute setXYZ" {
  let a = float32_attribute([1.0, 2, 3, 4, 5, 6], 3)
  ignore(a.set_xyz(1, -4, -5, -6))
  assert_eq(a.array.to_array(), [1.0, 2, 3, -4, -5, -6])
}

///|
test "BufferAttribute setXYZW" {
  let a = float32_attribute([1.0, 2, 3, 4], 4)
  ignore(a.set_xyzw(0, -1, -2, -3, -4))
  assert_eq(a.array.to_array(), [-1.0, -2, -3, -4])
}

///|
test "BufferAttribute onUpload" {
  let a = float32_attribute([0.0], 1)
  let func = () => ()
  ignore(a.on_upload(func))
  assert_true(physical_equal(a.on_upload_callback, func))
}

///|
test "BufferAttribute clone" {
  let attr = float32_attribute([1.0, 2, 3, 4, 0.12, -12], 2)
  let attr_copy = attr.clone()
  assert_eq(attr.array.length(), attr_copy.array.length())
  for i in 0..<attr.array.length() {
    assert_eq(attr.array[i], attr_copy.array[i])
  }
  assert_false(physical_equal(attr.array, attr_copy.array))
}

///|
test "BufferAttribute toJSON" {
  let attr = float32_attribute([1.0, 2, 3, 4, 5, 6], 3)
  assert_eq(
    attr.to_json(),
    Json::object({
      "itemSize": Json::number(3),
      "type": Json::string("Float32Array"),
      "array": Json::array([1.0, 2, 3, 4, 5, 6].map(v => Json::number(v))),
      "normalized": Json::boolean(false),
      "name": Json::string(""),
      "usage": Json::number(@core.StaticDrawUsage.to_double()),
      "gpuType": Json::number(@core.FloatType.to_double()),
    }),
  )
  let attr2 = float32_attribute([1.0, 2, 3, 4, 5, 6], 3, normalized=true)
  attr2.name = "attributeName"
  ignore(attr2.set_usage(@core.DynamicDrawUsage))
  attr2.add_update_range(1, 2)
  assert_eq(
    attr2.to_json(),
    Json::object({
      "itemSize": Json::number(3),
      "type": Json::string("Float32Array"),
      "array": Json::array([1.0, 2, 3, 4, 5, 6].map(v => Json::number(v))),
      "normalized": Json::boolean(true),
      "name": Json::string("attributeName"),
      "usage": Json::number(@core.DynamicDrawUsage.to_double()),
      "gpuType": Json::number(@core.FloatType.to_double()),
    }),
  )
}

///|
test "BufferAttribute count" {
  assert_eq(float32_attribute([1.0, 2, 3, 4, 5, 6], 3).count, 2)
}

///|
test "BufferAttribute update ranges" {
  let attr = float32_attribute([1.0, 2, 3], 3)
  attr.add_update_range(0, 2)
  assert_eq(attr.update_ranges[0].count, 2)
  attr.clear_update_ranges()
  assert_eq(attr.update_ranges.length(), 0)
}

///|
test "BufferAttribute dispose event" {
  let attr = float32_attribute([1.0], 1)
  let mut target_ok = false
  attr.add_event_listener("dispose", event => {
    target_ok = event.target is Some(BufferAttribute(a)) &&
      physical_equal(a, attr)
  })
  attr.dispose()
  assert_true(target_ok)
}

///|
test "BufferAttribute getComponent and setComponent" {
  let a = float32_attribute([1.0, 2, 3, 4], 2)
  ignore(a.set_component(1, 1, 9))
  assert_eq(a.get_component(1, 1), 9)
  let n = @core.BufferAttribute::new(
    @core.TypedArray::uint8(2),
    2,
    normalized=true,
  )
  ignore(n.set_component(0, 1, 1))
  assert_eq(n.array[1], 255)
  assert_eq(n.get_component(0, 1), 1)
}

///|
test "Float32 rounding happens in the JS array" {
  let a = float32_attribute([0.1], 1)
  assert_eq(a.get_x(0), 0.10000000149011612)
  ignore(a.set_x(0, 1.0 / 3.0))
  assert_eq(a.get_x(0), 0.3333333432674408)
}

///|
test "normalized integer attributes" {
  let cases : Array[(@core.TypedArray, Double)] = [
    (@core.TypedArray::int8(2), 127),
    (@core.TypedArray::uint8(2), 255),
    (@core.TypedArray::uint8_clamped(2), 255),
    (@core.TypedArray::int16(2), 32767),
    (@core.TypedArray::uint16(2), 65535),
    (@core.TypedArray::int32(2), 2147483647),
    (@core.TypedArray::uint32(2), 4294967295),
  ]
  for case in cases {
    let (array, scale) = case
    let a = @core.BufferAttribute::new(array, 2, normalized=true)
    ignore(a.set_xy(0, 0.5, 1))
    assert_eq(array[0], (0.5 * scale).round())
    assert_eq(array[1], scale)
    assert_eq(a.get_y(0), 1)
  }
  // signed values clamp at -1
  let a = @core.BufferAttribute::new(
    @core.TypedArray::int8([-128.0]),
    1,
    normalized=true,
  )
  assert_eq(a.get_x(0), -1)
  // a normalized Float32 attribute stores values as they are
  let f = float32_attribute([0.0], 1, normalized=true)
  ignore(f.set_x(0, 0.25))
  assert_eq(f.get_x(0), 0.25)
}

///|
test "BufferAttribute transforms" {
  let a = float32_attribute([1.0, 2, 3, 4], 2)
  ignore(a.apply_matrix3(@math.Matrix3::new().make_translation(1, 2)))
  assert_eq(a.array.to_array(), [2.0, 4, 4, 6])
  let b = float32_attribute([1.0, 2, 3], 3)
  ignore(b.apply_matrix3(@math.Matrix3::new().make_scale(2, 3)))
  assert_eq(b.array.to_array(), [2.0, 6, 3])
  let c = float32_attribute([1.0, 0, 0], 3)
  ignore(c.apply_matrix4(@math.Matrix4::new().make_translation(1, 2, 3)))
  assert_eq(c.array.to_array(), [2.0, 2, 3])
  let d = float32_attribute([1.0, 0, 0], 3)
  ignore(
    d.transform_direction(@math.Matrix4::new().make_rotation_z(test_pi() / 2.0)),
  )
  assert_true(approx(d.get_x(0), 0))
  assert_true(approx(d.get_y(0), 1))
  // applyNormalMatrix normalizes
  let e = float32_attribute([0.0, 2, 0], 3)
  ignore(e.apply_normal_matrix(@math.Matrix3::new()))
  assert_eq(e.array.to_array(), [0.0, 1, 0])
}

///|
test "math reads a BufferAttribute through BufferAttributeLike" {
  let a = float32_attribute([1.0, 2, 3, 4, 5, 6, 7, 8], 4)
  let v = @math.Vector4::new(0, 0, 0, 0).from_buffer_attribute(a, 1)
  assert_true(v.equals(@math.Vector4::new(5, 6, 7, 8)))
  let q = @math.Quaternion::new(0, 0, 0, 1).from_buffer_attribute(a, 0)
  assert_eq(q.w, 4)
  let c = @math.Color::new(0, 0, 0).from_buffer_attribute(a, 1)
  assert_eq(c.b, 7)
}

///|
test "typed subclasses use the matching typed array" {
  let cases = [
    (@core.Int8BufferAttribute::new([1.0], 1), "Int8Array"),
    (@core.Uint8BufferAttribute::new([1.0], 1), "Uint8Array"),
    (@core.Uint8ClampedBufferAttribute::new([1.0], 1), "Uint8ClampedArray"),
    (@core.Int16BufferAttribute::new([1.0], 1), "Int16Array"),
    (@core.Uint16BufferAttribute::new([1.0], 1), "Uint16Array"),
    (@core.Int32BufferAttribute::new([1.0], 1), "Int32Array"),
    (@core.Uint32BufferAttribute::new([1.0], 1), "Uint32Array"),
    (@core.Float32BufferAttribute::new([1.0], 1), "Float32Array"),
    (@core.Float16BufferAttribute::new([1.0], 1), "Uint16Array"),
  ]
  for case in cases {
    let (attribute, name) = case
    assert_eq(attribute.array.type_name(), name)
  }
  // a length and a typed array work as in `new Uint16Array( x )`
  let by_length = @core.Uint16BufferAttribute::new(4, 2)
  assert_eq(by_length.count, 2)
  let by_array = @core.Uint16BufferAttribute::new(
    @core.TypedArray::float32([1.9]),
    1,
  )
  assert_eq(by_array.array[0], 1)
  let by_int = @core.Float32BufferAttribute::new([1, 2, 3], 3, normalized=true)
  assert_true(by_int.normalized)
}

///|
test "wrapping and clamping stay with the JS array" {
  let a = @core.Uint8BufferAttribute::new([0.0], 1)
  ignore(a.set_x(0, 300))
  assert_eq(a.get_x(0), 44)
  let c = @core.Uint8ClampedBufferAttribute::new([0.0], 1)
  ignore(c.set_x(0, 300))
  assert_eq(c.get_x(0), 255)
  ignore(c.set_x(0, 1.5))
  assert_eq(c.get_x(0), 2)
}

///|
fn to_half_float_array(values : Array[Double]) -> @core.TypedArray {
  @core.TypedArray::uint16(values.map(@core.to_half_float))
}

///|
fn from_half_float_array(array : @core.TypedArray) -> Array[Double] {
  array.to_array().map(@core.from_half_float)
}

///|
test "Float16BufferAttribute set[X, Y, Z, W, XYZ, XYZW]/get[X, Y, Z, W]" {
  let a = @core.Float16BufferAttribute::new(
    to_half_float_array([1.0, 2, 3, 4, 5, 6, 7, 8]),
    4,
  )
  ignore(a.set_x(1, a.get_x(1) * -1))
  ignore(a.set_y(1, a.get_y(1) * -1))
  ignore(a.set_z(0, a.get_z(0) * -1))
  ignore(a.set_w(0, a.get_w(0) * -1))
  assert_eq(from_half_float_array(a.array), [1.0, 2, -3, -4, -5, -6, 7, 8])
}

///|
test "Float16BufferAttribute setXY" {
  let a = @core.Float16BufferAttribute::new(
    to_half_float_array([1.0, 2, 3, 4]),
    2,
  )
  ignore(a.set_xy(0, -1, -2))
  assert_eq(from_half_float_array(a.array), [-1.0, -2, 3, 4])
}

///|
test "Float16BufferAttribute setXYZ" {
  let a = @core.Float16BufferAttribute::new(
    to_half_float_array([1.0, 2, 3, 4, 5, 6]),
    3,
  )
  ignore(a.set_xyz(1, -4, -5, -6))
  assert_eq(from_half_float_array(a.array), [1.0, 2, 3, -4, -5, -6])
}

///|
test "Float16BufferAttribute setXYZW" {
  let a = @core.Float16BufferAttribute::new(
    to_half_float_array([1.0, 2, 3, 4]),
    4,
  )
  ignore(a.set_xyzw(0, -1, -2, -3, -4))
  assert_eq(from_half_float_array(a.array), [-1.0, -2, -3, -4])
}

///|
test "Float16BufferAttribute clone keeps the class" {
  let a = @core.Float16BufferAttribute::new(to_half_float_array([1.5]), 1)
  let b = a.clone()
  assert_true(b.is_float16_buffer_attribute())
  assert_eq(b.get_x(0), 1.5)
}
