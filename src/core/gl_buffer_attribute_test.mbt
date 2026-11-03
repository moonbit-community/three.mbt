///|
test "GLBufferAttribute setters" {
  let attribute = @core.GLBufferAttribute::new(
    @core.JsValue::object(),
    5126,
    3,
    4,
    10,
  )
  assert_false(attribute.normalized)
  attribute.set_needs_update(true)
  attribute.set_needs_update(false)
  assert_eq(attribute.version, 1)
  let buffer = @core.JsValue::object()
  ignore(attribute.set_buffer(buffer))
  assert_true(attribute.buffer.strict_equal(buffer))
  ignore(attribute.set_type(5123, 2).set_item_size(2).set_count(7))
  assert_eq(attribute.type_, 5123)
  assert_eq(attribute.element_size, 2)
  assert_eq(attribute.item_size, 2)
  assert_eq(attribute.count, 7)
}
