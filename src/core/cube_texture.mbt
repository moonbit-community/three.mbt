// Upstream src/textures/CubeTexture.js.

///|
#external
pub type CubeTexture

///|
pub fn CubeTexture::new(
  images~ : Array[TextureImage] = [],
  mapping~ : Int32 = CubeReflectionMapping,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter? : Int32,
  min_filter? : Int32,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
  color_space? : String,
) -> Texture {
  let texture = Texture::new(
    image=ImageArray(images),
    mapping~,
    wrap_s?,
    wrap_t?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
    color_space?,
  )
  texture.texture_type = CubeTexture
  texture.flip_y = false
  texture
}

///|
/// Upstream's `images` accessor of cube textures, an alias for `image`.
pub fn Texture::images(self : Texture) -> TextureImage {
  self.image()
}

///|
pub fn Texture::set_images(self : Texture, value : TextureImage) -> Unit {
  self.set_image(value)
}
