// Upstream src/textures/VideoTexture.js. `clone` and `dispose` dispatch from texture.mbt.

///|
#external
pub type VideoTexture

///|
extern "js" fn video_texture_has_frame_callback(video : JsValue) -> Bool =
  #|(video) => 'requestVideoFrameCallback' in video

///|
extern "js" fn video_texture_request_frame(
  video : JsValue,
  callback : () -> Unit,
) -> Int32 =
  #|(video, callback) => video.requestVideoFrameCallback(() => { callback(); })

///|
extern "js" fn video_texture_cancel_frame(video : JsValue, id : Int32) -> Unit =
  #|(video, id) => { video.cancelVideoFrameCallback(id); }

///|
extern "js" fn video_texture_has_current_data(video : JsValue) -> Bool =
  #|(video) => video.readyState >= video.HAVE_CURRENT_DATA

///|
/// The constructor, for any image: `clone` passes `this.image` to it.
fn video_texture_construct(
  video : TextureImage,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter~ : Int32 = LinearFilter,
  min_filter~ : Int32 = LinearFilter,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
) -> Texture {
  let texture = Texture::new(
    image=video,
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter~,
    min_filter~,
    format?,
    type_?,
    anisotropy?,
  )
  texture.texture_type = VideoTexture
  texture.generate_mipmaps = false
  texture._request_video_frame_callback_id = 0
  let video = video.to_js()
  fn update_video() -> Unit {
    texture.set_needs_update(true)
    texture._request_video_frame_callback_id = video_texture_request_frame(
      video, update_video,
    )
  }

  if video_texture_has_frame_callback(video) {
    texture._request_video_frame_callback_id = video_texture_request_frame(
      video, update_video,
    )
  }
  texture
}

///|
pub fn VideoTexture::new(
  video : JsValue,
  mapping? : Int32,
  wrap_s? : Int32,
  wrap_t? : Int32,
  mag_filter? : Int32,
  min_filter? : Int32,
  format? : Int32,
  type_? : Int32,
  anisotropy? : Int32,
) -> Texture {
  video_texture_construct(
    TextureImage::from_js(video),
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
  )
}

///|
/// `VideoTexture.update`; a no-op on `VideoFrameTexture`.
pub fn Texture::update(self : Texture) -> Unit {
  match self.texture_type {
    VideoFrameTexture => ()
    VideoTexture => {
      let video = self.image().to_js()
      if !video_texture_has_frame_callback(video) &&
        video_texture_has_current_data(video) {
        self.set_needs_update(true)
      }
    }
    _ => abort("Texture::update: not a video texture")
  }
}

///|
fn video_texture_dispose(texture : Texture) -> Unit {
  if texture._request_video_frame_callback_id != 0 {
    video_texture_cancel_frame(
      texture.source.data.to_js(),
      texture._request_video_frame_callback_id,
    )
    texture._request_video_frame_callback_id = 0
  }
}
