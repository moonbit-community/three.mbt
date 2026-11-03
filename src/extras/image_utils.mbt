// Upstream src/extras/ImageUtils.js. `get_data_url` lives in `core`, which needs it for
// serialization. A type from `core` cannot gain methods here, so this is a type of its own
// that forwards it.

///|
#external
pub type ImageUtils

///|
/// Returns a data URI containing a representation of the given image.
pub fn ImageUtils::get_data_url(
  image : @core.JsValue,
  type_~ : String = "image/png",
) -> String {
  @core.ImageUtils::get_data_url(image, type_~)
}

///|
extern "js" fn image_utils_srgb_to_linear(
  image : @core.JsValue,
  srgb_to_linear : (Double) -> Double,
  warn : (String) -> Unit,
) -> @core.JsValue =
  #|(image, SRGBToLinear, warn) => {
  #|  if ( ( typeof HTMLImageElement !== 'undefined' && image instanceof HTMLImageElement ) ||
  #|    ( typeof HTMLCanvasElement !== 'undefined' && image instanceof HTMLCanvasElement ) ||
  #|    ( typeof ImageBitmap !== 'undefined' && image instanceof ImageBitmap ) ) {
  #|    const canvas = document.createElementNS( 'http://www.w3.org/1999/xhtml', 'canvas' );
  #|    canvas.width = image.width;
  #|    canvas.height = image.height;
  #|    const context = canvas.getContext( '2d' );
  #|    context.drawImage( image, 0, 0, image.width, image.height );
  #|    const imageData = context.getImageData( 0, 0, image.width, image.height );
  #|    const data = imageData.data;
  #|    for ( let i = 0; i < data.length; i ++ ) {
  #|      data[ i ] = SRGBToLinear( data[ i ] / 255 ) * 255;
  #|    }
  #|    context.putImageData( imageData, 0, 0 );
  #|    return canvas;
  #|  } else if ( image.data ) {
  #|    const data = image.data.slice( 0 );
  #|    for ( let i = 0; i < data.length; i ++ ) {
  #|      if ( data instanceof Uint8Array || data instanceof Uint8ClampedArray ) {
  #|        data[ i ] = Math.floor( SRGBToLinear( data[ i ] / 255 ) * 255 );
  #|      } else {
  #|        // assuming float
  #|        data[ i ] = SRGBToLinear( data[ i ] );
  #|      }
  #|    }
  #|    return {
  #|      data: data,
  #|      width: image.width,
  #|      height: image.height
  #|    };
  #|  } else {
  #|    warn( 'ImageUtils.sRGBToLinear(): Unsupported image type. No color space conversion applied.' );
  #|    return image;
  #|  }
  #|}

///|
/// Converts the given sRGB image data to linear color space.
pub fn ImageUtils::srgb_to_linear(image : @core.JsValue) -> @core.JsValue {
  image_utils_srgb_to_linear(image, @math.srgb_to_linear, @core.warn)
}
