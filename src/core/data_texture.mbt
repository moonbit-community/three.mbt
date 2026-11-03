// Upstream src/textures/DataTexture.js.

///|
#external
pub type DataTexture

///|
pub fn DataTexture::new(
  data? : TypedArray,
  width~ : Int32 = 1,
  height~ : Int32 = 1,
  format? : Int32,
  type_? : Int32,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter~ : Int32 = NearestFilter,
  min_filter~ : Int32 = NearestFilter,
  anisotropy? : Int32,
  color_space? : String,
) -> Texture {
  let texture = Texture::new(
    image=NoImage,
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter~,
    min_filter~,
    format?,
    type_?,
    anisotropy?,
    color_space?,
  )
  texture.texture_type = DataTexture
  texture.set_image(DataImage(DataImage::new(data?, width~, height~)))
  texture.generate_mipmaps = false
  texture.flip_y = false
  texture.unpack_alignment = 1
  texture
}
