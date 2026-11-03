///|
test "FramebufferTexture Instancing" {
  let object = @core.FramebufferTexture::new(width=4, height=2)
  assert_true(object.texture_type is FramebufferTexture)
  assert_eq(object.mag_filter, @core.NearestFilter)
  assert_eq(object.min_filter, @core.NearestFilter)
  assert_false(object.generate_mipmaps)
  assert_eq(object.version, 1)
  assert_eq(object.width(), 4)
  assert_eq(object.depth(), 0)
  let c = object.clone()
  assert_false(physical_equal(c.source, object.source))
  assert_eq(c.height(), 2)
  assert_eq(c.version, 2)
}
