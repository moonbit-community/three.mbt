// Upstream src/textures/CanvasTexture.js.

///|
#external
pub type CanvasTexture

///|
pub fn CanvasTexture::new(
  canvas? : JsValue,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter? : Int32,
  min_filter? : Int32,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
) -> Texture {
  let texture = Texture::new(
    image?=canvas.map(TextureImage::from_js),
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
  )
  texture.texture_type = CanvasTexture
  texture.set_needs_update(true)
  texture
}
