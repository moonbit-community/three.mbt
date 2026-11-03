// Upstream src/loaders/ImageBitmapLoader.js. `isImageBitmapLoader` is not ported.

///|
/// Upstream's module-level `_errorMap`, the errors of failed cached promises.
let image_bitmap_loader_error_map : JsWeakMap = JsWeakMap::new()

///|
/// Loads images as `ImageBitmap`s with `fetch` and `createImageBitmap`.
pub struct ImageBitmapLoader {
  base : Loader
  mut options : Map[String, Json]
  mut _abort_controller : AbortController
}

///|
pub fn ImageBitmapLoader::new(manager? : LoadingManager) -> ImageBitmapLoader {
  let base = Loader::new(manager?)
  if !js_has_create_image_bitmap() {
    @core.warn("ImageBitmapLoader: createImageBitmap() not supported.")
  }
  if !js_has_fetch() {
    @core.warn("ImageBitmapLoader: fetch() not supported.")
  }
  {
    base,
    options: { "premultiplyAlpha": Json::string("none") },
    _abort_controller: AbortController::new(),
  }
}

///|
pub impl LoaderLike for ImageBitmapLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for ImageBitmapLoader with fn abort(self) {
  self._abort_controller.abort()
  self._abort_controller = AbortController::new()
  self
}

///|
pub extend ImageBitmapLoader with LoaderLike::{loader}

///|
pub extend ImageBitmapLoader with LoaderSettings::{
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
/// Sets the options passed to `createImageBitmap()`.
pub fn ImageBitmapLoader::set_options(
  self : ImageBitmapLoader,
  options : Map[String, Json],
) -> ImageBitmapLoader {
  self.options = options
  self
}

///|
/// Starts loading `url`; `on_load` receives the `ImageBitmap`. `on_progress` is never called.
pub fn ImageBitmapLoader::load(
  self : ImageBitmapLoader,
  url : String,
  on_load? : (JsValue) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> Unit {
  ignore(on_progress)
  let base = self.base
  let url = base.manager.resolve_url(base.path + url)
  let manager = base.manager
  if Cache::get("image-bitmap:\{url}") is Some(cached) {
    manager.item_start(url)

    // If cached is a promise, wait for it to resolve
    if js_is_thenable(cached) {
      js_as_promise(cached).then_(image_bitmap => {
        // check if there is an error for the cached promise
        if image_bitmap_loader_error_map.has(cached) {
          if on_error is Some(on_error) {
            on_error(image_bitmap_loader_error_map.get(cached))
          }
          manager.item_error(url)
          manager.item_end(url)
        } else {
          if on_load is Some(on_load) {
            on_load(image_bitmap)
          }
          manager.item_end(url)
        }
        JsValue::undefined()
      })
      |> ignore
      return
    }

    // If cached is not a promise (i.e., it's already an imageBitmap)
    js_set_timeout(
      () => {
        if on_load is Some(on_load) {
          on_load(cached)
        }
        manager.item_end(url)
      },
      0,
    )
    return
  }
  let credentials = if base.with_credentials || base.cross_origin != "anonymous" {
    "include"
  } else {
    "same-origin"
  }
  let options = JsValue::from_json(Json::object(self.options))
  let promise : Ref[JsValue] = Ref(JsValue::undefined())
  promise.val = js_fetch_options(
      url,
      credentials,
      request_header_object(base.request_header),
      base.priority,
      base.cache,
      js_abort_signal(self._abort_controller, manager.abort_controller()),
    )
    .then_(res => js_response_body(res, "blob"))
    .then_(blob => js_create_image_bitmap(blob, options))
    .then_(image_bitmap => {
      Cache::add("image-bitmap:\{url}", image_bitmap)
      if on_load is Some(on_load) {
        on_load(image_bitmap)
      }
      manager.item_end(url)
      image_bitmap // see #34150
    })
    .catch_(e => {
      if on_error is Some(on_error) {
        on_error(e)
      }
      image_bitmap_loader_error_map.set(promise.val, e)
      Cache::remove("image-bitmap:\{url}")
      manager.item_error(url)
      manager.item_end(url)
      JsValue::undefined()
    })
    .to_js()
  Cache::add("image-bitmap:\{url}", promise.val)
  manager.item_start(url)
}

///|
/// Upstream `loadAsync`.
pub async fn ImageBitmapLoader::load_async(
  self : ImageBitmapLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> JsValue raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, on_load=resolve, on_progress?, on_error=reject)
  })
}
