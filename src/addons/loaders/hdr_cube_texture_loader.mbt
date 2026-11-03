// Upstream examples/jsm/loaders/HDRCubeTextureLoader.js.

///|
/// Loads six RGBE faces into a `CubeTexture` of `DataTexture`s.
pub(all) struct HDRCubeTextureLoader {
  base : @loaders.Loader
  /// The internal HDR loader that parses each cube face.
  hdr_loader : HDRLoader
  /// The texture type, `HalfFloatType` (default) or `FloatType`.
  mut type_ : Int32
}

///|
pub fn HDRCubeTextureLoader::new(
  manager? : @loaders.LoadingManager,
) -> HDRCubeTextureLoader {
  {
    base: @loaders.Loader::new(manager?),
    hdr_loader: HDRLoader::new(),
    type_: @core.HalfFloatType,
  }
}

///|
pub impl @loaders.LoaderLike for HDRCubeTextureLoader with fn loader(self) {
  self.base
}

///|
pub impl @loaders.LoaderSettings for HDRCubeTextureLoader

///|
pub extend HDRCubeTextureLoader with @loaders.LoaderLike::{loader}

///|
pub extend HDRCubeTextureLoader with @loaders.LoaderSettings::{
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
/// Starts loading the faces in `urls` (px, nx, py, ny, pz, nz) and returns the texture.
/// Faces that arrive early leave `NoImage` in the slots before them, where upstream
/// leaves holes in the array.
pub fn HDRCubeTextureLoader::load(
  self : HDRCubeTextureLoader,
  urls : Array[String],
  on_load? : (@core.Texture) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> @core.Texture {
  let texture = @core.CubeTexture::new()
  texture.type_ = self.type_
  match texture.type_ {
    @core.FloatType => {
      texture.color_space = @core.LinearSRGBColorSpace
      texture.min_filter = @core.LinearFilter
      texture.mag_filter = @core.LinearFilter
      texture.generate_mipmaps = false
    }
    @core.HalfFloatType => {
      texture.color_space = @core.LinearSRGBColorSpace
      texture.min_filter = @core.LinearFilter
      texture.mag_filter = @core.LinearFilter
      texture.generate_mipmaps = false
    }
    _ => ()
  }
  let scope = self
  let mut loaded = 0
  fn load_hdr_data(
    i : Int32,
    on_load : ((@core.Texture) -> Unit)?,
    on_progress : ((@loaders.ProgressEvent) -> Unit)?,
    on_error : ((@core.JsValue) -> Unit)?,
  ) -> Unit {
    @loaders.FileLoader::new(manager=scope.base.manager)
    .set_priority(scope.base.priority)
    .set_cache(scope.base.cache)
    .set_path(scope.base.path)
    .set_response_type("arraybuffer")
    .set_request_header(scope.base.request_header)
    .set_with_credentials(scope.base.with_credentials)
    .load(
      urls[i],
      on_load=buffer => {
        loaded += 1
        let tex_data = scope.hdr_loader.parse(buffer)
        if tex_data.data is Some(data) {
          let data_texture = @core.DataTexture::new(
            data~,
            width=tex_data.width.unwrap_or(0),
            height=tex_data.height.unwrap_or(0),
          )
          data_texture.type_ = texture.type_
          data_texture.color_space = texture.color_space
          data_texture.format = texture.format
          data_texture.min_filter = texture.min_filter
          data_texture.mag_filter = texture.mag_filter
          data_texture.generate_mipmaps = texture.generate_mipmaps
          guard texture.images() is ImageArray(images) else {
            abort("HDRCubeTextureLoader: images is not an array")
          }
          while images.length() <= i {
            images.push(NoImage)
          }
          images[i] = TextureImage(data_texture)
        }
        if loaded == 6 {
          texture.set_needs_update(true)
          if on_load is Some(on_load) {
            on_load(texture)
          }
        }
      },
      on_progress?,
      on_error?,
    )
  }
  for i in 0..<urls.length() {
    load_hdr_data(i, on_load, on_progress, on_error)
  }
  texture
}

///|
/// Sets the texture type, also on the internal `HDRLoader`.
pub fn HDRCubeTextureLoader::set_data_type(
  self : HDRCubeTextureLoader,
  value : Int32,
) -> HDRCubeTextureLoader {
  self.type_ = value
  self.hdr_loader.set_data_type(value) |> ignore
  self
}

///|
/// `loadAsync( urls, onProgress )`, inherited from `Loader`.
pub async fn HDRCubeTextureLoader::load_async(
  self : HDRCubeTextureLoader,
  urls : Array[String],
  on_progress? : (@loaders.ProgressEvent) -> Unit,
) -> @core.Texture raise @loaders.LoaderError {
  @loaders.loader_promise((resolve, reject) => {
    self.load(urls, on_load=resolve, on_progress?, on_error=reject) |> ignore
  })
}
