// Upstream src/textures/FramebufferTexture.js. `copy` is in texture.mbt.

///|
#external
pub type FramebufferTexture

///|
/// Upstream's undefined `width` and `height` are 0 here.
pub fn FramebufferTexture::new(
  width~ : Int32 = 0,
  height~ : Int32 = 0,
) -> Texture {
  let texture = Texture::new(image=DataImage(DataImage::new(width~, height~)))
  texture.texture_type = FramebufferTexture
  texture.mag_filter = NearestFilter
  texture.min_filter = NearestFilter
  texture.generate_mipmaps = false
  texture.set_needs_update(true)
  texture
}
