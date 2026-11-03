// Upstream src/textures/CompressedTexture.js.

///|
#external
pub type CompressedTexture

///|
/// Upstream's undefined `width` and `height` are 0 here.
pub fn CompressedTexture::new(
  mipmaps~ : Array[TextureImage] = [],
  width~ : Int32 = 0,
  height~ : Int32 = 0,
  format? : Int32,
  type_? : Int32,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter? : Int32,
  min_filter? : Int32,
  anisotropy? : Int32,
  color_space? : String,
) -> Texture {
  let texture = Texture::new(
    image=NoImage,
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
    color_space?,
  )
  texture.texture_type = CompressedTexture
  texture.set_image(DataImage(DataImage::new(width~, height~)))
  texture.mipmaps = mipmaps
  texture.flip_y = false
  texture.generate_mipmaps = false
  texture
}
