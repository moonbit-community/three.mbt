// Upstream examples/jsm/loaders/RGBELoader.js: deprecated (r180) alias of HDRLoader.

///|
/// Deprecated: use `HDRLoader`. `RGBELoader::new` returns an `HDRLoader`.
#external
pub type RGBELoader

///|
extern "js" fn rgbe_console_warn(message : String) -> Unit = "(m) => console.warn(m)"

///|
pub fn RGBELoader::new(manager? : @loaders.LoadingManager) -> HDRLoader {
  rgbe_console_warn(
    "RGBELoader has been deprecated. Please use HDRLoader instead.",
  )
  HDRLoader::new(manager?)
}
