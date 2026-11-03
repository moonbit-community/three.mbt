// Upstream src/loaders/DataTextureLoader.js. Upstream subclasses override `parse`;
// here a format loader passes its parser to `DataTextureLoader::new`.

///|
/// What a data texture parser returns; `None` fields are upstream's `undefined`.
pub(all) struct DataTexData {
  mut image : @core.TextureImage?
  mut data : @core.TypedArray?
  mut width : Int32?
  mut height : Int32?
  mut wrap_s : Int32?
  mut wrap_t : Int32?
  mut mag_filter : Int32?
  mut min_filter : Int32?
  mut anisotropy : Int32?
  mut color_space : String?
  mut flip_y : Bool?
  mut format : Int32?
  mut type_ : Int32?
  mut mipmaps : Array[@core.TextureImage]?
  mut mipmap_count : Int32?
  mut generate_mipmaps : Bool?
  /// Format-specific extras, passed on to `on_load` as upstream passes `texData`.
  mut extra : JsValue?
}

///|
/// An empty `DataTexData`, as the object literal `{}`.
pub fn DataTexData::new() -> DataTexData {
  {
    image: None,
    data: None,
    width: None,
    height: None,
    wrap_s: None,
    wrap_t: None,
    mag_filter: None,
    min_filter: None,
    anisotropy: None,
    color_space: None,
    flip_y: None,
    format: None,
    type_: None,
    mipmaps: None,
    mipmap_count: None,
    generate_mipmaps: None,
    extra: None,
  }
}

///|
/// Abstract base for loaders of binary formats that become a `DataTexture`.
pub struct DataTextureLoader {
  base : Loader
  /// Upstream's overridden `parse( buffer )`.
  parse : (JsValue) -> DataTexData
}

///|
pub fn DataTextureLoader::new(
  manager? : LoadingManager,
  parse? : (JsValue) -> DataTexData,
) -> DataTextureLoader {
  {
    base: Loader::new(manager?),
    parse: match parse {
      Some(parse) => parse
      // `Loader.parse()` returns `undefined`, so reading `texData.image` throws
      None => _ => abort("DataTextureLoader: parse() is not implemented")
    },
  }
}

///|
pub impl LoaderLike for DataTextureLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for DataTextureLoader

///|
pub extend DataTextureLoader with LoaderLike::{loader}

///|
pub extend DataTextureLoader with LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
  abort,
}

///|
/// Starts loading `url` as an `ArrayBuffer` and returns the texture it is parsed into.
pub fn DataTextureLoader::load(
  self : DataTextureLoader,
  url : String,
  on_load? : (@core.Texture, DataTexData) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> @core.Texture {
  let texture = @core.DataTexture::new()
  let loader = FileLoader::new(manager=self.base.manager)
    .set_priority(self.base.priority)
    .set_cache(self.base.cache)
    .set_response_type("arraybuffer")
    .set_request_header(self.base.request_header)
    .set_path(self.base.path)
    .set_with_credentials(self.base.with_credentials)
  loader.load(
    url,
    on_load=buffer => {
      let mut tex_data = DataTexData::new()
      let result = js_try(() => tex_data = (self.parse)(buffer))
      if !result.ok() {
        if on_error is Some(on_error) {
          on_error(result.error())
        } else {
          loaders_error_value(result.error())
        }
        return
      }
      self._apply_tex_data(texture, tex_data)
      if on_load is Some(on_load) {
        on_load(texture, tex_data)
      }
    },
    on_progress?,
    on_error?,
  )
  texture
}

///|
/// Upstream `loadAsync`; resolves with the texture.
pub async fn DataTextureLoader::load_async(
  self : DataTextureLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.Texture raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(
      url,
      on_load=(texture, _) => resolve(texture),
      on_progress?,
      on_error=reject,
    )
    |> ignore
  })
}

///|
/// Parses `buffer` into a new `DataTexture`.
pub fn DataTextureLoader::create_data_texture(
  self : DataTextureLoader,
  buffer : JsValue,
) -> @core.Texture {
  let texture = @core.DataTexture::new()
  self._apply_tex_data(texture, (self.parse)(buffer))
  texture
}

///|
pub fn DataTextureLoader::_apply_tex_data(
  self : DataTextureLoader,
  texture : @core.Texture,
  tex_data : DataTexData,
) -> Unit {
  ignore(self)
  if tex_data.image is Some(image) {
    texture.set_image(image)
  } else if tex_data.data is Some(data) {
    guard texture.image() is DataImage(image) else {
      abort("DataTextureLoader: texture image is not a data image")
    }
    image.width = tex_data.width.unwrap_or(0)
    image.height = tex_data.height.unwrap_or(0)
    image.data = Some(data)
  }
  texture.wrap_s = tex_data.wrap_s.unwrap_or(@core.ClampToEdgeWrapping)
  texture.wrap_t = tex_data.wrap_t.unwrap_or(@core.ClampToEdgeWrapping)
  texture.mag_filter = tex_data.mag_filter.unwrap_or(@core.LinearFilter)
  texture.min_filter = tex_data.min_filter.unwrap_or(@core.LinearFilter)
  texture.anisotropy = tex_data.anisotropy.unwrap_or(1)
  if tex_data.color_space is Some(color_space) {
    texture.color_space = color_space
  }
  if tex_data.flip_y is Some(flip_y) {
    texture.flip_y = flip_y
  }
  if tex_data.format is Some(format) {
    texture.format = format
  }
  if tex_data.type_ is Some(type_) {
    texture.type_ = type_
  }
  if tex_data.mipmaps is Some(mipmaps) {
    texture.mipmaps = mipmaps
    texture.min_filter = @core.LinearMipmapLinearFilter
  } // presumably...
  if tex_data.mipmap_count == Some(1) {
    texture.min_filter = @core.LinearFilter
  }
  if tex_data.generate_mipmaps is Some(generate_mipmaps) {
    texture.generate_mipmaps = generate_mipmaps
  }
  texture.set_needs_update(true)
}
