// Upstream src/textures/HTMLTexture.js. `dispose` dispatches from texture.mbt.

///|
#external
pub type HTMLTexture

///|
extern "js" fn html_texture_request_paint(
  element : JsValue,
  on_paint : () -> Unit,
) -> Unit =
  #|(element, onPaint) => {
  #|  const parent = element ? element.parentNode : null;
  #|  if (parent !== null && 'requestPaint' in parent) {
  #|    parent.onpaint = () => {
  #|      onPaint();
  #|    };
  #|    parent.requestPaint();
  #|  }
  #|}

///|
extern "js" fn html_texture_clear_paint(image : JsValue) -> Unit =
  #|(image) => {
  #|  const parent = image ? image.parentNode : null;
  #|  if (parent !== null && 'onpaint' in parent) {
  #|    parent.onpaint = null;
  #|  }
  #|}

///|
pub fn HTMLTexture::new(
  element? : JsValue,
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
    image?=element.map(TextureImage::from_js),
    mapping?,
    wrap_s?,
    wrap_t?,
    mag_filter?,
    min_filter?,
    format?,
    type_?,
    anisotropy?,
  )
  texture.texture_type = HTMLTexture
  texture.generate_mipmaps = false
  texture.set_needs_update(true)
  html_texture_request_paint(element.unwrap_or(JsValue::undefined()), () => {
    texture.set_needs_update(true)
  })
  texture
}

///|
fn html_texture_dispose(texture : Texture) -> Unit {
  html_texture_clear_paint(texture.image().to_js())
}
