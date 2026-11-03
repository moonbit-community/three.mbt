// renderers/webgl-fallback/utils/WebGLCapabilities.js: device limits, queried once.

///|
pub(all) struct WebGLCapabilities {
  backend : WebGLBackend
  /// `maxAnisotropy`; `None` is `null` (not queried yet).
  mut max_anisotropy : Int32?
  /// `maxUniformBlockSize`; `None` is `null`.
  mut max_uniform_block_size : Int32?
}

///|
/// `new WebGLCapabilities( backend )`.
pub fn WebGLCapabilities::new(backend : WebGLBackend) -> WebGLCapabilities {
  { backend, max_anisotropy: None, max_uniform_block_size: None, }
}

///|
/// `getMaxAnisotropy()`.
pub fn WebGLCapabilities::get_max_anisotropy(self : WebGLCapabilities) -> Int32 {
  match self.max_anisotropy {
    Some(m) => return m
    None => ()
  }
  let gl = self.backend.gl.unwrap()
  let extensions = self.backend.extensions.unwrap()
  if extensions.has("EXT_texture_filter_anisotropic") == true {
    let extension = extensions.get("EXT_texture_filter_anisotropic").unwrap()
    self.max_anisotropy = Some(
      gl.get_parameter_int(extension.constant("MAX_TEXTURE_MAX_ANISOTROPY_EXT")),
    )
  } else {
    self.max_anisotropy = Some(0)
  }
  self.max_anisotropy.unwrap()
}

///|
/// `getUniformBufferLimit()`.
pub fn WebGLCapabilities::get_uniform_buffer_limit(
  self : WebGLCapabilities,
) -> Int32 {
  match self.max_uniform_block_size {
    Some(m) => return m
    None => ()
  }
  let gl = self.backend.gl.unwrap()
  self.max_uniform_block_size = Some(
    gl.get_parameter_int(@webgl.GL_MAX_UNIFORM_BLOCK_SIZE),
  )
  self.max_uniform_block_size.unwrap()
}
