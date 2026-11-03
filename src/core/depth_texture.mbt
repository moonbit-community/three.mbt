// Upstream src/textures/DepthTexture.js. `copy` and `toJSON` are in texture.mbt.

///|
#external
pub type DepthTexture

///|
/// Upstream's undefined `width` and `height` are 0 here.
pub fn DepthTexture::new(
  width~ : Int32 = 0,
  height~ : Int32 = 0,
  type_~ : Int32 = UnsignedIntType,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter~ : Int32 = NearestFilter,
  min_filter~ : Int32 = NearestFilter,
  anisotropy? : Int32,
  format~ : Int32 = DepthFormat,
  depth~ : Int32 = 1,
) -> Texture {
  if format != DepthFormat && format != DepthStencilFormat {
    abort(
      "THREE.DepthTexture: format must be either THREE.DepthFormat or THREE.DepthStencilFormat",
    )
  }
  let texture = Texture::new(
    image=DataImage(DataImage::new(width~, height~, depth~)),
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter~,
    min_filter~,
    format~,
    type_~,
    anisotropy?,
  )
  texture.texture_type = DepthTexture
  texture.flip_y = false
  texture.generate_mipmaps = false
  texture.compare_function = None
  texture
}
