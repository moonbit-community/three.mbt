// renderers/webgl-fallback/utils/WebGLExtensions.js: a cache of the extension objects of
// the backend's context.

///|
pub(all) struct WebGLExtensions {
  backend : WebGLBackend
  gl : @webgl.WebGL2RenderingContext
  /// `availableExtensions`: `gl.getSupportedExtensions()`.
  available_extensions : Array[String]
  /// `extensions[ name ]`: `None` is `undefined`, `Some(None)` a `null` extension.
  extensions : Map[String, @webgl.GLExtension?]
  /// A WebGLRenderer's `extensions`, which `get` / `has` forward to when set (the
  /// WebGLNodesHandler add-on's backend uses the renderer's, as upstream duck-types it).
  mut _renderer_extensions : @webgl.WebGLExtensions?
}

///|
extern "js" fn _webgl_extensions_names(
  list : @core.JsValue,
) -> FixedArray[String] = "(l) => l === null || l === undefined ? [] : Array.from( l )"

///|
/// `new WebGLExtensions( backend )`.
pub fn WebGLExtensions::new(backend : WebGLBackend) -> WebGLExtensions {
  let gl = backend.gl.unwrap()
  let available_extensions = Array::from_fixed_array(
    _webgl_extensions_names(gl.get_supported_extensions()),
  )
  {
    backend,
    gl,
    available_extensions,
    extensions: Map([]),
    _renderer_extensions: None,
  }
}

///|
/// `get( name )`: the extension object, `None` when unsupported (`null`).
pub fn WebGLExtensions::get(
  self : WebGLExtensions,
  name : String,
) -> @webgl.GLExtension? {
  if self._renderer_extensions is Some(extensions) {
    return extensions.get(name)
  }
  match self.extensions.get(name) {
    Some(extension) => extension
    None => {
      let extension = self.gl.get_extension(name)
      self.extensions.set(name, extension)
      extension
    }
  }
}

///|
/// `has( name )`.
pub fn WebGLExtensions::has(self : WebGLExtensions, name : String) -> Bool {
  if self._renderer_extensions is Some(extensions) {
    return extensions.has(name)
  }
  self.available_extensions.contains(name)
}
