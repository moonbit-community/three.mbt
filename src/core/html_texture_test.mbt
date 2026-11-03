///|
extern "js" fn html_mock_element() -> @core.JsValue =
  #|() => {
  #|  const parent = { painted: 0, requestPaint() { this.painted ++; } };
  #|  return { parentNode: parent };
  #|}

///|
extern "js" fn html_mock_paint(element : @core.JsValue) -> Unit =
  #|(element) => { element.parentNode.onpaint(); }

///|
test "HTMLTexture without a parent element" {
  let object = @core.HTMLTexture::new()
  assert_true(object.texture_type is HTMLTexture)
  assert_false(object.generate_mipmaps)
  assert_eq(object.version, 1)
  object.dispose()
}

///|
test "HTMLTexture paint hooks" {
  let element = html_mock_element()
  let object = @core.HTMLTexture::new(element~)
  assert_eq(element.get("parentNode").get("painted").cast(), 1)
  html_mock_paint(element)
  assert_eq(object.version, 2)
  object.dispose()
  assert_true(element.get("parentNode").get("onpaint").is_null())
  assert_true(object.clone().image() is DomImage(_))
}
