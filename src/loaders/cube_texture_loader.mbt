// Upstream src/loaders/CubeTextureLoader.js.

///|
/// Loads six images into a new `CubeTexture`, through `ImageLoader`.
pub struct CubeTextureLoader {
  base : Loader
}

///|
pub fn CubeTextureLoader::new(manager? : LoadingManager) -> CubeTextureLoader {
  { base: Loader::new(manager?), }
}

///|
pub impl LoaderLike for CubeTextureLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for CubeTextureLoader

///|
pub extend CubeTextureLoader with LoaderLike::{loader}

///|
pub extend CubeTextureLoader with LoaderSettings::{
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
pub fn CubeTextureLoader::load(
  self : CubeTextureLoader,
  urls : Array[String],
  on_load? : (@core.Texture) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> @core.Texture {
  ignore(on_progress)
  let texture = @core.CubeTexture::new()
  texture.color_space = @core.SRGBColorSpace
  let loader = ImageLoader::new(manager=self.base.manager)
    .set_priority(self.base.priority)
    .set_cache(self.base.cache)
    .set_cross_origin(self.base.cross_origin)
    .set_path(self.base.path)
  let mut loaded = 0
  fn load_texture(i : Int32) -> Unit {
    loader.load(
      urls[i],
      on_load=image => {
        guard texture.images() is ImageArray(images) else {
          abort("CubeTextureLoader: images is not an array")
        }
        while images.length() <= i {
          images.push(NoImage)
        }
        images[i] = @core.TextureImage::from_js(image)
        loaded += 1
        if loaded == 6 {
          texture.set_needs_update(true)
          if on_load is Some(on_load) {
            on_load(texture)
          }
        }
      },
      on_error?,
    )
    |> ignore
  }

  for i in 0..<urls.length() {
    load_texture(i)
  }
  texture
}

///|
/// Upstream `loadAsync`.
pub async fn CubeTextureLoader::load_async(
  self : CubeTextureLoader,
  urls : Array[String],
  on_progress? : (ProgressEvent) -> Unit,
) -> @core.Texture raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(urls, on_load=resolve, on_progress?, on_error=reject) |> ignore
  })
}
