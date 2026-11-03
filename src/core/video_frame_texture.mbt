// Upstream src/textures/VideoFrameTexture.js. `update` is in video_texture.mbt.

///|
#external
pub type VideoFrameTexture

///|
pub fn VideoFrameTexture::new(
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter? : Int32,
  min_filter? : Int32,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
) -> Texture {
  let texture = video_texture_construct(
    DomImage(JsValue::object()),
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
  )
  texture.texture_type = VideoFrameTexture
  texture
}

///|
pub fn Texture::set_frame(self : Texture, frame : JsValue) -> Unit {
  self.set_image(TextureImage::from_js(frame))
  self.set_needs_update(true)
}
