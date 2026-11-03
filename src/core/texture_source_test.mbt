///|
fn js_size(width : Int32, height : Int32, depth : Int32) -> @core.JsValue {
  let image = @core.JsValue::object()
  image.set("width", @core.JsValue::of(width))
  image.set("height", @core.JsValue::of(height))
  image.set("depth", @core.JsValue::of(depth))
  image
}

///|
test "TextureSource Instancing" {
  let source = @core.TextureSource::new()
  assert_true(source.data is NoImage)
  assert_true(source.data_ready)
  assert_eq(source.version, 0)
  assert_true(@core.TextureSource::new().id > source.id)
}

///|
test "TextureSource getSize" {
  let target = vec3(0, 0, 0)
  // data with defined dimensions
  ignore(
    @core.TextureSource::new(data=DomImage(js_size(8, 4, 2))).get_size(target),
  )
  assert_true(target.equals(vec3(8, 4, 2)))
  ignore(
    @core.TextureSource::new(
      data=DataImage(@core.DataImage::new(width=3, height=5)),
    ).get_size(target),
  )
  assert_true(target.equals(vec3(3, 5, 0)))
  // null data
  ignore(@core.TextureSource::new().get_size(target))
  assert_true(target.equals(vec3(0, 0, 0)))
  // undefined dimensions
  let image = js_size(0, 0, 1)
  image.set("width", @core.JsValue::undefined())
  image.set("height", @core.JsValue::undefined())
  ignore(@core.TextureSource::new(data=DomImage(image)).get_size(target))
  assert_true(target.equals(vec3(0, 0, 1)))
  // arrays have no size of their own
  ignore(
    @core.TextureSource::new(data=ImageArray([DomImage(js_size(8, 4, 2))])).get_size(
      target,
    ),
  )
  assert_true(target.equals(vec3(0, 0, 0)))
}

///|
test "TextureSource needsUpdate" {
  let source = @core.TextureSource::new()
  source.set_needs_update(false)
  assert_eq(source.version, 0)
  source.set_needs_update(true)
  assert_eq(source.version, 1)
}

///|
test "TextureSource toJSON" {
  guard @core.TextureSource::new().to_json() is Object(empty) else {
    fail("not an object")
  }
  assert_eq(empty["url"], Json::string(""))
  let data = @core.TypedArray::uint8([1, 2, 3, 4])
  guard @core.TextureSource::new(
      data=DataImage(@core.DataImage::new(data~, width=2, height=2)),
    ).to_json()
    is Object(json) else {
    fail("not an object")
  }
  assert_eq(
    json["url"],
    Json::object({
      "data": Json::array([1.0, 2, 3, 4].map(v => Json::number(v))),
      "width": Json::number(2),
      "height": Json::number(2),
      "type": Json::string("Uint8Array"),
    }),
  )
  // cube texture of DataTextures, and an image without data
  let face = @core.DataTexture::new(data~, width=2, height=2)
  guard @core.TextureSource::new(
      data=ImageArray([TextureImage(face), DomImage(@core.JsValue::object())]),
    ).to_json()
    is Object(cube) else {
    fail("not an object")
  }
  guard cube["url"] is Array([Object(first), Object(second)]) else {
    fail("wrong url")
  }
  assert_eq(first["type"], Json::string("Uint8Array"))
  assert_true(second.is_empty())
}

///|
test "ImageUtils getDataURL without a canvas" {
  let image = @core.JsValue::object()
  image.set("src", @core.JsValue::of("data:image/png;base64,AA"))
  assert_eq(@core.ImageUtils::get_data_url(image), "data:image/png;base64,AA")
}
