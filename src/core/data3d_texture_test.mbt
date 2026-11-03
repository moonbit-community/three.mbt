///|
test "Data3DTexture Instancing" {
  let object = @core.Data3DTexture::new()
  assert_true(object.texture_type is Data3DTexture)
  assert_eq(object.mag_filter, @core.NearestFilter)
  assert_eq(object.min_filter, @core.NearestFilter)
  assert_eq(object.wrap_r, @core.ClampToEdgeWrapping)
  assert_false(object.generate_mipmaps)
  assert_false(object.flip_y)
  assert_eq(object.unpack_alignment, 1)
  assert_eq(object.width(), 1)
  assert_eq(object.depth(), 1)
  assert_false(object.is_array_texture)
  object.wrap_r = @core.RepeatWrapping
  assert_eq(object.clone().wrap_r, @core.RepeatWrapping)
}
