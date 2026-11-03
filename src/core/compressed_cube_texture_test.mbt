///|
test "CompressedCubeTexture Instancing" {
  let face : @core.TextureImage = DataImage(
    @core.DataImage::new(width=4, height=8),
  )
  let object = @core.CompressedCubeTexture::new(
    [face, face, face, face, face, face],
    format=1,
    type_=2,
  )
  assert_true(object.is_compressed_texture())
  assert_true(object.is_cube_texture())
  assert_eq(object.mapping, @core.CubeReflectionMapping)
  assert_eq(object.format, 1)
  assert_eq(object.type_, 2)
  assert_true(object.image() is ImageArray(images) && images.length() == 6)
}
