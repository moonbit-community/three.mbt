///|
test "ExternalTexture Instancing" {
  let object = @core.ExternalTexture::new()
  assert_true(object.texture_type is ExternalTexture)
  assert_true(object.source_texture is None)
  let source = @core.Texture::new()
  let t = @core.ExternalTexture::new(source_texture=source)
  let c = t.clone()
  assert_true(c.source_texture is Some(s) && physical_equal(s, source))
}
