// Upstream src/loaders/Cache.js. `Cache` is a module-level object there, so its
// state lives in private lets and its members are static functions here.

///|
/// Upstream `Cache`: a cache of loaded files keyed by URL, off by default.
#external
pub type Cache

///|
let cache_enabled : Ref[Bool] = Ref(false)

///|
let cache_files : Ref[Map[String, JsValue]] = Ref(Map([]))

///|
/// `Cache.enabled`.
pub fn Cache::enabled() -> Bool {
  cache_enabled.val
}

///|
/// `Cache.enabled = value`.
pub fn Cache::set_enabled(value : Bool) -> Unit {
  cache_enabled.val = value
}

///|
/// `Cache.files`.
pub fn Cache::files() -> Map[String, JsValue] {
  cache_files.val
}

///|
pub fn Cache::add(key : String, file : JsValue) -> Unit {
  if cache_enabled.val == false {
    return
  }
  if js_is_blob_url(key) {
    return
  }
  cache_files.val[key] = file
}

///|
/// `None` is upstream's `undefined`.
pub fn Cache::get(key : String) -> JsValue? {
  if cache_enabled.val == false {
    return None
  }
  if js_is_blob_url(key) {
    return None
  }
  cache_files.val.get(key)
}

///|
pub fn Cache::remove(key : String) -> Unit {
  cache_files.val.remove(key)
}

///|
pub fn Cache::clear() -> Unit {
  cache_files.val = Map([])
}
