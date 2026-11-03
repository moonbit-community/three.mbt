///|
test "DataTexture Instancing" {
  let object = @core.DataTexture::new()
  assert_true(object.texture_type is DataTexture)
  assert_eq(object.width(), 1)
  assert_eq(object.height(), 1)
  assert_eq(object.depth(), 0)
  assert_eq(object.mag_filter, @core.NearestFilter)
  assert_eq(object.min_filter, @core.NearestFilter)
  assert_false(object.generate_mipmaps)
  assert_false(object.flip_y)
  assert_eq(object.unpack_alignment, 1)
  let t = @core.DataTexture::new(
    data=@core.TypedArray::float32(4),
    format=1,
    type_=2,
    mag_filter=@core.LinearFilter,
    color_space="srgb",
  )
  assert_eq(t.format, 1)
  assert_eq(t.type_, 2)
  assert_eq(t.mag_filter, @core.LinearFilter)
  assert_eq(t.color_space, "srgb")
  assert_true(t.clone().texture_type is DataTexture)
}
