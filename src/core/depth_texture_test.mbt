///|
test "DepthTexture Instancing" {
  let object = @core.DepthTexture::new()
  assert_true(object.is_depth_texture())
  assert_eq(object.type_, @core.UnsignedIntType)
  assert_eq(object.format, @core.DepthFormat)
  assert_eq(object.mag_filter, @core.NearestFilter)
  assert_eq(object.min_filter, @core.NearestFilter)
  assert_false(object.flip_y)
  assert_false(object.generate_mipmaps)
  assert_eq(object.compare_function, None)
  assert_eq(object.depth(), 1)
  let array = @core.DepthTexture::new(width=2, height=2, depth=3)
  assert_true(array.is_array_texture)
}

///|
test "DepthTexture copy does not share source" {
  let object = @core.DepthTexture::new(width=2, height=3)
  object.compare_function = Some(@core.LessCompare)
  let c = object.clone()
  assert_false(physical_equal(c.source, object.source))
  assert_eq(c.width(), 2)
  assert_eq(c.compare_function, Some(@core.LessCompare))
  guard (c.image(), object.image()) is (DataImage(a), DataImage(b)) else {
    fail("not data images")
  }
  assert_false(physical_equal(a, b))
}

///|
test "DepthTexture toJSON" {
  let object = @core.DepthTexture::new()
  guard object.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json["compareFunction"], Json::null())
  object.compare_function = Some(512)
  guard object.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json["compareFunction"], Json::number(512))
}

///|
test "panic DepthTexture format" {
  ignore(@core.DepthTexture::new(format=@core.RGBAFormat))
}
