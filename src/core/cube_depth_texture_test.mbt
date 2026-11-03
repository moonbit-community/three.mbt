///|
test "CubeDepthTexture Instancing" {
  let object = @core.CubeDepthTexture::new(size=8)
  assert_true(object.is_depth_texture())
  assert_true(object.is_cube_texture())
  assert_eq(object.type_, @core.UnsignedIntType)
  assert_eq(object.mapping, @core.CubeReflectionMapping)
  assert_eq(object.mag_filter, @core.NearestFilter)
  guard object.image() is ImageArray(images) else { fail("not an array") }
  assert_eq(images.length(), 6)
  guard images is [DataImage(first), .., DataImage(last)] else {
    fail("not data images")
  }
  assert_true(physical_equal(first, last))
  assert_eq(first.width, 8)
}

///|
test "CubeDepthTexture clone loses the array as upstream" {
  // `Object.assign( {}, array )` in `DepthTexture.copy` gives a plain object.
  let object = @core.CubeDepthTexture::new(size=8)
  let c = object.clone()
  assert_true(c.texture_type is CubeDepthTexture)
  assert_true(c.image() is DomImage(_))
  assert_eq(c.width(), 0)
}
