// Upstream src/loaders/ImageLoader.js. Images are DOM values (`JsValue`).

///|
/// One waiting request for an image still in flight, as upstream's `_loading` entries.
priv struct ImageLoaderCallbacks {
  on_load : ((JsValue) -> Unit)?
  on_error : ((JsValue) -> Unit)?
}

///|
/// Upstream's module-level `_loading`, keyed by image.
let image_loader_loading : JsWeakMap = JsWeakMap::new()

///|
fn image_loader_callbacks(image : JsValue) -> Array[ImageLoaderCallbacks] {
  let callbacks = image_loader_loading.get(image)
  if callbacks.is_undefined() {
    []
  } else {
    callbacks.cast()
  }
}

///|
/// Loads images as `HTMLImageElement`s.
pub struct ImageLoader {
  base : Loader
}

///|
pub fn ImageLoader::new(manager? : LoadingManager) -> ImageLoader {
  { base: Loader::new(manager?), }
}

///|
pub impl LoaderLike for ImageLoader with fn loader(self) {
  self.base
}

///|
pub impl LoaderSettings for ImageLoader

///|
pub extend ImageLoader with LoaderLike::{loader}

///|
pub extend ImageLoader with LoaderSettings::{
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
/// Starts loading `url` and returns the image element. `on_progress` is never called.
pub fn ImageLoader::load(
  self : ImageLoader,
  url : String,
  on_load? : (JsValue) -> Unit,
  on_progress? : (ProgressEvent) -> Unit,
  on_error? : (JsValue) -> Unit,
) -> JsValue {
  ignore(on_progress)
  let base = self.base
  let url = base.manager.resolve_url(base.path + url)
  let manager = base.manager
  if Cache::get("image:\{url}") is Some(cached) {
    if js_image_complete(cached) {
      manager.item_start(url)
      js_set_timeout(
        () => {
          if on_load is Some(on_load) {
            on_load(cached)
          }
          manager.item_end(url)
        },
        0,
      )
    } else {
      let mut arr = image_loader_loading.get(cached)
      if arr.is_undefined() {
        arr = JsValue::of(([] : Array[ImageLoaderCallbacks]))
        image_loader_loading.set(cached, arr)
      }
      let arr : Array[ImageLoaderCallbacks] = arr.cast()
      arr.push({ on_load, on_error, })
    }
    return cached
  }
  let image = js_create_image()
  letrec on_image_load = (_ : JsValue) => {
    remove_event_listeners()
    if on_load is Some(on_load) {
      on_load(image)
    }
    for callback in image_loader_callbacks(image) {
      if callback.on_load is Some(on_load) {
        on_load(image)
      }
    }
    image_loader_loading.delete(image)
    manager.item_end(url)
  }
  and on_image_error = (event : JsValue) => {
    remove_event_listeners()
    if on_error is Some(on_error) {
      on_error(event)
    }
    Cache::remove("image:\{url}")
    for callback in image_loader_callbacks(image) {
      if callback.on_error is Some(on_error) {
        on_error(event)
      }
    }
    image_loader_loading.delete(image)
    manager.item_error(url)
    manager.item_end(url)
  }
  and remove_event_listeners = () => {
    js_remove_event_listener(image, "load", on_image_load)
    js_remove_event_listener(image, "error", on_image_error)
  }
  js_add_event_listener(image, "load", on_image_load)
  js_add_event_listener(image, "error", on_image_error)
  if !url.has_prefix("data:") {
    image.set("crossOrigin", js_from_string(base.cross_origin))
  }
  Cache::add("image:\{url}", image)
  manager.item_start(url)
  image.set("fetchPriority", js_from_string(base.priority))
  image.set("src", js_from_string(url))
  image
}

///|
/// Upstream `loadAsync`.
pub async fn ImageLoader::load_async(
  self : ImageLoader,
  url : String,
  on_progress? : (ProgressEvent) -> Unit,
) -> JsValue raise LoaderError {
  loader_promise((resolve, reject) => {
    self.load(url, on_load=resolve, on_progress?, on_error=reject) |> ignore
  })
}
