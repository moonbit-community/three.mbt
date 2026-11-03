// Upstream src/renderers/webgl/WebGLExtensions.js.

///|
pub struct WebGLExtensions {
  gl : WebGL2RenderingContext
  /// name -> extension, `None` once `getExtension` returned `null`.
  extensions : Map[String, GLExtension?]
}

///|
/// `new WebGLExtensions( gl )`.
pub fn WebGLExtensions::new(gl : WebGL2RenderingContext) -> WebGLExtensions {
  { gl, extensions: {}, }
}

///|
fn WebGLExtensions::get_extension(
  self : WebGLExtensions,
  name : String,
) -> GLExtension? {
  if self.extensions.get(name) is Some(extension) {
    return extension
  }
  let extension = self.gl.get_extension(name)
  self.extensions[name] = extension
  extension
}

///|
/// `extensions.has( name )`.
pub fn WebGLExtensions::has(self : WebGLExtensions, name : String) -> Bool {
  self.get_extension(name) is Some(_)
}

///|
/// `extensions.init()`: requests the extensions the renderer relies on up front.
pub fn WebGLExtensions::init(self : WebGLExtensions) -> Unit {
  ignore(self.get_extension("EXT_color_buffer_float"))
  ignore(self.get_extension("WEBGL_clip_cull_distance"))
  ignore(self.get_extension("OES_texture_float_linear"))
  ignore(self.get_extension("EXT_color_buffer_half_float"))
  ignore(self.get_extension("WEBGL_multisampled_render_to_texture"))
  ignore(self.get_extension("WEBGL_render_shared_exponent"))
}

///|
/// `extensions.get( name )`; warns once when unsupported.
pub fn WebGLExtensions::get(
  self : WebGLExtensions,
  name : String,
) -> GLExtension? {
  let extension = self.get_extension(name)
  if extension is None {
    @core.warn_once("WebGLRenderer: " + name + " extension not supported.")
  }
  extension
}
