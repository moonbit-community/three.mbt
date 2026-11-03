// Upstream src/loaders/Loader.js. Every loader holds a `Loader` with the shared
// settings in `base`. `LoaderLike` exposes it (and is what `LoadingManager` handlers
// store); `LoaderSettings` gives each loader upstream's chainable setters.
// The `__THREE_DEVTOOLS__` hook is not ported.

///|
/// Upstream `Loader.DEFAULT_MATERIAL_NAME`.
pub const Loader_DEFAULT_MATERIAL_NAME : String = "__DEFAULT"

///|
/// The settings every loader shares.
pub(all) struct Loader {
  mut manager : LoadingManager
  mut cross_origin : String
  mut with_credentials : Bool
  mut path : String
  mut resource_path : String
  mut request_header : Map[String, String]
  mut priority : String
  mut cache : String
}

///|
pub fn Loader::new(manager? : LoadingManager) -> Loader {
  {
    manager: match manager {
      Some(manager) => manager
      None => default_loading_manager
    },
    cross_origin: "anonymous",
    with_credentials: false,
    path: "",
    resource_path: "",
    request_header: Map([]),
    priority: "auto",
    cache: "default",
  }
}

///|
/// Gives access to the shared settings of a loader.
pub(open) trait LoaderLike {
  fn loader(Self) -> Loader
}

///|
/// Upstream's chainable setters, shared by all loaders.
pub(open) trait LoaderSettings: LoaderLike {
  fn set_cross_origin(Self, String) -> Self = _
  fn set_with_credentials(Self, Bool) -> Self = _
  fn set_path(Self, String) -> Self = _
  fn set_resource_path(Self, String) -> Self = _
  fn set_request_header(Self, Map[String, String]) -> Self = _
  fn set_priority(Self, String) -> Self = _
  fn set_cache(Self, String) -> Self = _
  fn abort(Self) -> Self = _
}

///|
impl LoaderSettings with fn set_cross_origin(self, cross_origin) {
  LoaderLike::loader(self).cross_origin = cross_origin
  self
}

///|
impl LoaderSettings with fn set_with_credentials(self, value) {
  LoaderLike::loader(self).with_credentials = value
  self
}

///|
impl LoaderSettings with fn set_path(self, path) {
  LoaderLike::loader(self).path = path
  self
}

///|
impl LoaderSettings with fn set_resource_path(self, resource_path) {
  LoaderLike::loader(self).resource_path = resource_path
  self
}

///|
impl LoaderSettings with fn set_request_header(self, request_header) {
  LoaderLike::loader(self).request_header = request_header
  self
}

///|
impl LoaderSettings with fn set_priority(self, value) {
  LoaderLike::loader(self).priority = value
  self
}

///|
impl LoaderSettings with fn set_cache(self, value) {
  LoaderLike::loader(self).cache = value
  self
}

///|
impl LoaderSettings with fn abort(self) {
  self
}

///|
pub impl LoaderLike for Loader with fn loader(self) {
  self
}

///|
pub impl LoaderSettings for Loader

///|
pub extend Loader with LoaderLike::{loader}

///|
pub extend Loader with LoaderSettings::{
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
/// The error `load_async` raises: upstream's rejection value.
pub(all) suberror LoaderError {
  LoaderError(JsValue)
}

///|
pub impl Show for LoaderError with fn output(self, logger) {
  let LoaderError(value) = self
  logger.write_string("LoaderError(" + js_string(value) + ")")
}

///|
pub extend LoaderError with Show::{to_string, output}

///|
/// Upstream `loadAsync`: `new Promise( ( resolve, reject ) => load( url, resolve, onProgress, reject ) )`.
/// Public so loaders in other packages (the add-ons) can inherit `loadAsync` the same way.
pub async fn[T] loader_promise(
  start : ((T) -> Unit, (JsValue) -> Unit) -> Unit,
) -> T raise LoaderError {
  let result = js_settle_promise((resolve, reject) => {
    start(value => resolve(JsValue::of(value)), reject)
  }).wait() catch {
    error => raise LoaderError(js_new_error(error.to_string()))
  }
  if result.ok() {
    result.value().cast()
  } else {
    raise LoaderError(result.error())
  }
}
