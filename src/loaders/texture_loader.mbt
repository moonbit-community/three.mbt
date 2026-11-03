// Upstream src/loaders/TextureLoader.js.

///|
/// Loads an image into a new `Texture`, through `ImageLoader`.
pub struct TextureLoader {
  base : Loader
}

///|
pub fn TextureLoader::new(manager? : LoadingManager) -> TextureLoader {
  { base: Loader::new(manager?), }
}

///|
pub impl LoaderLike for TextureLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for TextureLoader

///|
pub extend TextureLoader with LoaderLike::{loader}

///|
pub extend TextureLoader with LoaderSettings::{
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
/// Starts loading `url` and returns the texture the image goes into.
pub fn TextureLoader::load(
  self : TextureLoader,
  url : String,
  on_load? : (@core.Texture) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> @core.Texture {
  let texture = @core.Texture::new()
  let loader = ImageLoader::new(manager=self.base.manager)
    .set_priority(self.base.priority)
    .set_cache(self.base.cache)
    .set_cross_origin(self.base.cross_origin)
    .set_path(self.base.path)
  loader.load(
    url,
    on_load=image => {
      texture.set_image(@core.TextureImage::from_js(image))
      texture.set_needs_update(true)
      if on_load is Some(on_load) {
        on_load(texture)
      }
    },
    on_progress?,
    on_error?,
  )
  |> ignore
  texture
}

///|
/// Upstream `loadAsync`.
pub async fn TextureLoader::load_async(
  self : TextureLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.Texture raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, on_load=resolve, on_progress?, on_error=reject) |> ignore
  })
}
