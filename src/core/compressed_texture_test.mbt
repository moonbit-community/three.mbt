///|
test "CompressedTexture Instancing" {
  let object = @core.CompressedTexture::new()
  assert_true(object.is_compressed_texture())
  assert_false(object.flip_y)
  assert_false(object.generate_mipmaps)
  assert_eq(object.mipmaps.length(), 0)
  let mipmaps : Array[@core.TextureImage] = [
    DataImage(@core.DataImage::new(width=2, height=2)),
  ]
  let t = @core.CompressedTexture::new(mipmaps~, width=4, height=8, format=5)
  assert_true(physical_equal(t.mipmaps, mipmaps))
  assert_eq(t.format, 5)
  assert_eq(t.width(), 4)
  assert_eq(t.height(), 8)
  assert_true(t.clone().texture_type is CompressedTexture)
}
