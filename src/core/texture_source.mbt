// Upstream src/textures/TextureSource.js, helpers for what `image` can hold, and
// `ImageUtils.getDataURL` from src/extras/ImageUtils.js, which lives in `core` because
// TextureSource needs it. The deprecated `Source` alias is not ported.

///|
let _texture_source_id : Ref[Int32] = Ref(0)

///|
extern "js" fn texture_source_is_video(data : JsValue) -> Bool =
  #|(data) => (typeof HTMLVideoElement !== 'undefined') && (data instanceof HTMLVideoElement)

///|
extern "js" fn texture_source_is_video_frame(data : JsValue) -> Bool =
  #|(data) => (typeof VideoFrame !== 'undefined') && (data instanceof VideoFrame)

///|
extern "js" fn texture_source_is_default_image(image : JsValue) -> Bool =
  #|(image) => (typeof HTMLImageElement !== 'undefined' && image instanceof HTMLImageElement) ||
  #|  (typeof HTMLCanvasElement !== 'undefined' && image instanceof HTMLCanvasElement) ||
  #|  (typeof ImageBitmap !== 'undefined' && image instanceof ImageBitmap)

///|
extern "js" fn texture_source_has_data(image : JsValue) -> Bool = "(image) => image.data ? true : false"

///|
extern "js" fn texture_source_serialize_data(image : JsValue) -> JsValue =
  #|(image) => ({
  #|  data: Array.from(image.data),
  #|  width: image.width,
  #|  height: image.height,
  #|  type: image.data.constructor.name
  #|})

///|
extern "js" fn texture_image_or_zero(value : JsValue, key : String) -> Double = "(o, k) => o[k] || 0"

///|
extern "js" fn texture_image_object_assign(value : JsValue) -> JsValue = "(v) => Object.assign({}, v)"

///|
/// Creates the `{ data, width, height, depth }` object upstream writes as a literal.
pub fn DataImage::new(
  data? : TypedArray,
  width~ : Int32 = 0,
  height~ : Int32 = 0,
  depth? : Int32,
  mipmaps? : Array[DataImage],
) -> DataImage {
  { data, width, height, depth, mipmaps, }
}

///|
/// Wraps a DOM value; `null` and `undefined` become `NoImage`.
pub fn TextureImage::from_js(value : JsValue) -> TextureImage {
  if value.is_null() || value.is_undefined() {
    NoImage
  } else {
    DomImage(value)
  }
}

///|
/// The value as JS sees it, with `NoImage` as `null`.
pub fn TextureImage::to_js(self : TextureImage) -> JsValue {
  match self {
    NoImage => JsValue::null()
    DomImage(value) => value
    DataImage(image) => JsValue::of(image)
    TextureImage(texture) => JsValue::of(texture)
    ImageArray(images) => JsValue::of(images)
  }
}

///|
/// `image.width || 0`. Image arrays are JS arrays and can carry `width` as a property.
pub fn TextureImage::width(self : TextureImage) -> Double {
  match self {
    NoImage => abort("TextureImage::width: image is null")
    DomImage(_) | ImageArray(_) => texture_image_or_zero(self.to_js(), "width")
    DataImage(image) => image.width.to_double()
    TextureImage(texture) => texture.width()
  }
}

///|
/// `image.height || 0`.
pub fn TextureImage::height(self : TextureImage) -> Double {
  match self {
    NoImage => abort("TextureImage::height: image is null")
    DomImage(_) | ImageArray(_) => texture_image_or_zero(self.to_js(), "height")
    DataImage(image) => image.height.to_double()
    TextureImage(texture) => texture.height()
  }
}

///|
/// `image.depth || 0`.
pub fn TextureImage::depth(self : TextureImage) -> Double {
  match self {
    NoImage => abort("TextureImage::depth: image is null")
    DomImage(_) | ImageArray(_) => texture_image_or_zero(self.to_js(), "depth")
    DataImage(image) => image.depth.unwrap_or(0).to_double()
    TextureImage(texture) => texture.depth()
  }
}

///|
/// `image.width = width`, and the same for `height` and `depth`.
pub fn TextureImage::set_size(
  self : TextureImage,
  width : Int32,
  height : Int32,
  depth : Int32,
) -> Unit {
  match self {
    DataImage(image) => {
      image.width = width
      image.height = height
      image.depth = Some(depth)
    }
    DomImage(_) | ImageArray(_) => {
      let image = self.to_js()
      image.set("width", JsValue::of(width))
      image.set("height", JsValue::of(height))
      image.set("depth", JsValue::of(depth))
    }
    NoImage => abort("TextureImage::set_size: image is null")
    TextureImage(_) => abort("TextureImage::set_size: image is a Texture")
  }
}

///|
/// `Object.assign( {}, image )`. As upstream, an array or `null` becomes a plain object.
pub fn TextureImage::shallow_copy(self : TextureImage) -> TextureImage {
  match self {
    DataImage(image) => DataImage({ ..image, })
    _ => DomImage(texture_image_object_assign(self.to_js()))
  }
}

///|
pub fn TextureSource::new(data~ : TextureImage = NoImage) -> TextureSource {
  let id = _texture_source_id.val
  _texture_source_id.val = id + 1
  { id, uuid: @math.generate_uuid(), data, data_ready: true, version: 0, }
}

///|
pub fn TextureSource::get_size(
  self : TextureSource,
  target : @math.Vector3,
) -> @math.Vector3 {
  match self.data {
    DomImage(data) if texture_source_is_video(data) =>
      target.set(
        data.get("videoWidth").cast(),
        data.get("videoHeight").cast(),
        0.0,
      )
    DomImage(data) if texture_source_is_video_frame(data) =>
      target.set(
        data.get("displayWidth").cast(),
        data.get("displayHeight").cast(),
        0.0,
      )
    NoImage => target.set(0.0, 0.0, 0.0)
    data => target.set(data.width(), data.height(), data.depth())
  }
}

///|
/// Setter of upstream `needsUpdate`.
pub fn TextureSource::set_needs_update(
  self : TextureSource,
  value : Bool,
) -> Unit {
  if value {
    self.version += 1
  }
}

///|
pub fn TextureSource::to_json(self : TextureSource, meta? : ToJsonMeta) -> Json {
  if meta is Some(meta) && meta.images.get(self.uuid) is Some(image) {
    return image
  }
  let output : Map[String, Json] = {
    "uuid": Json::string(self.uuid),
    "url": Json::string(""),
  }
  match self.data {
    NoImage => ()
    // cube texture
    ImageArray(images) =>
      output["url"] = Json::array(
        images.map(image => {
          match image {
            TextureImage(texture) if texture.texture_type is DataTexture =>
              texture_source_serialize_image(texture.image())
            _ => texture_source_serialize_image(image)
          }
        }),
      )
    // texture
    data => output["url"] = texture_source_serialize_image(data)
  }
  let json = Json::object(output)
  if meta is Some(meta) {
    meta.images[self.uuid] = json
  }
  json
}

///|
fn texture_source_serialize_image(image : TextureImage) -> Json {
  match image {
    NoImage => abort("TextureSource: cannot serialize a null image")
    // default images
    DomImage(value) if texture_source_is_default_image(value) =>
      Json::string(ImageUtils::get_data_url(value))
    // images of DataTexture
    DomImage(value) if texture_source_has_data(value) =>
      texture_source_serialize_data(value).to_json()
    DataImage({ data: Some(data), width, height, .. }) =>
      Json::object({
        "data": json_numbers(data.to_array()),
        "width": json_int(width),
        "height": json_int(height),
        "type": Json::string(data.type_name()),
      })
    _ => {
      warn("Texture: Unable to serialize Texture.")
      Json::object({})
    }
  }
}

///|
/// Upstream `ImageUtils`. The rest of the class belongs to `extras`.
#external
pub type ImageUtils

///|
extern "js" fn image_utils_get_data_url(
  image : JsValue,
  type_ : String,
) -> String =
  #|(() => {
  #|  let _canvas;
  #|  return (image, type) => {
  #|    if (/^data:/i.test(image.src)) {
  #|      return image.src;
  #|    }
  #|    if (typeof HTMLCanvasElement === 'undefined') {
  #|      return image.src;
  #|    }
  #|    let canvas;
  #|    if (image instanceof HTMLCanvasElement) {
  #|      canvas = image;
  #|    } else {
  #|      if (_canvas === undefined) _canvas = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas');
  #|      _canvas.width = image.width;
  #|      _canvas.height = image.height;
  #|      const context = _canvas.getContext('2d');
  #|      if (image instanceof ImageData) {
  #|        context.putImageData(image, 0, 0);
  #|      } else {
  #|        context.drawImage(image, 0, 0, image.width, image.height);
  #|      }
  #|      canvas = _canvas;
  #|    }
  #|    return canvas.toDataURL(type);
  #|  };
  #|})()

///|
pub fn ImageUtils::get_data_url(
  image : JsValue,
  type_~ : String = "image/png",
) -> String {
  image_utils_get_data_url(image, type_)
}
