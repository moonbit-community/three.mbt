// Upstream src/loaders/LoaderUtils.js.

///|
/// Upstream `LoaderUtils`, a class of static helpers.
#external
pub type LoaderUtils

///|
/// The part of `url` up to and including the last `/`, or `./`.
pub fn LoaderUtils::extract_url_base(url : String) -> String {
  let index = js_last_index_of_slash(url)
  if index == -1 {
    return "./"
  }
  js_slice_string(url, 0, index + 1)
}

///|
extern "js" fn js_last_index_of_slash(url : String) -> Int32 = "(u) => u.lastIndexOf('/')"

///|
extern "js" fn js_slice_string(
  value : String,
  start : Int32,
  end : Int32,
) -> String = "(s, a, b) => s.slice(a, b)"

///|
/// Resolves `url` against `path`; an empty `url` gives `''`.
pub fn LoaderUtils::resolve_url(url : String, path : String) -> String {
  js_loader_utils_resolve_url(js_from_string(url), path)
}
