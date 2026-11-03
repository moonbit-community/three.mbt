// Upstream has no test file for TextureUtils.

///|
fn sized_texture(width : Int32, height : Int32) -> @core.Texture {
  let texture = @core.Texture::new()
  texture.set_image(
    DataImage({ data: None, width, height, depth: None, mipmaps: None, }),
  )
  texture
}

///|
test "TextureUtils contain" {
  let texture = @extras.contain(sized_texture(2, 1), 1.0)
  assert_eq(texture.repeat.y, 2.0)
  assert_eq(texture.offset.y, -0.5)
  let texture = @extras.TextureUtils::contain(sized_texture(1, 2), 1.0)
  assert_eq(texture.repeat.x, 2.0)
  assert_eq(texture.offset.x, -0.5)
}

///|
test "TextureUtils cover" {
  let texture = @extras.cover(sized_texture(2, 1), 1.0)
  assert_eq(texture.repeat.x, 0.5)
  assert_eq(texture.offset.x, 0.25)
  let texture = @extras.TextureUtils::cover(sized_texture(1, 2), 1.0)
  assert_eq(texture.repeat.y, 0.5)
  assert_eq(texture.offset.y, 0.25)
}

///|
test "TextureUtils image without a width has aspect 1" {
  let texture = @extras.contain(@core.Texture::new(), 2.0)
  assert_eq(texture.repeat.x, 2.0)
}

///|
test "TextureUtils fill" {
  let texture = @extras.cover(sized_texture(2, 1), 1.0)
  ignore(@extras.TextureUtils::fill(texture))
  assert_eq(texture.repeat.to_array(), [1.0, 1.0])
  assert_eq(texture.offset.to_array(), [0.0, 0.0])
}

///|
test "TextureUtils get_byte_length" {
  assert_eq(
    @extras.get_byte_length(4, 4, @core.RGBAFormat, @core.UnsignedByteType),
    64.0,
  )
  assert_eq(
    @extras.TextureUtils::get_byte_length(
      4,
      4,
      @core.RGBAFormat,
      @core.FloatType,
    ),
    256.0,
  )
  assert_eq(
    @extras.get_byte_length(
      5,
      5,
      @core.RGBA_S3TC_DXT5_Format,
      @core.UnsignedByteType,
    ),
    64.0,
  )
  assert_eq(
    @extras.get_byte_length(1, 1, @core.RedFormat, @core.UnsignedShort4444Type),
    0.5,
  )
}
