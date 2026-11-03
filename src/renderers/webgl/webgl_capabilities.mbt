// Upstream src/renderers/webgl/WebGLCapabilities.js.

///|
/// The renderer constructor options `WebGLCapabilities` reads.
pub(all) struct WebGLCapabilitiesParameters {
  precision : String?
  logarithmic_depth_buffer : Bool
  reversed_depth_buffer : Bool
}

///|
pub struct WebGLCapabilities {
  gl : WebGL2RenderingContext
  extensions : WebGLExtensions
  utils : WebGLUtils
  mut max_anisotropy : Double?
  /// kept for backwards compatibility
  is_webgl2 : Bool
  precision : String
  logarithmic_depth_buffer : Bool
  reversed_depth_buffer : Bool
  max_textures : Int32
  max_vertex_textures : Int32
  max_texture_size : Int32
  max_cubemap_size : Int32
  max_attributes : Int32
  max_vertex_uniforms : Int32
  max_varyings : Int32
  max_fragment_uniforms : Int32
  max_samples : Int32
  samples : Int32
}

///|
/// `new WebGLCapabilities( gl, extensions, parameters, utils )`.
pub fn WebGLCapabilities::new(
  gl : WebGL2RenderingContext,
  extensions : WebGLExtensions,
  parameters : WebGLCapabilitiesParameters,
  utils : WebGLUtils,
) -> WebGLCapabilities {
  let mut precision = parameters.precision.unwrap_or("highp")
  let max_precision = webgl_capabilities_max_precision(gl, precision)
  if max_precision != precision {
    @core.warn(
      "WebGLRenderer: \{precision} not supported, using \{max_precision} instead.",
    )
    precision = max_precision
  }
  let reversed_depth_buffer = parameters.reversed_depth_buffer &&
    extensions.has("EXT_clip_control")
  let logarithmic_depth_buffer = parameters.logarithmic_depth_buffer &&
    !reversed_depth_buffer
  if parameters.reversed_depth_buffer && !reversed_depth_buffer {
    @core.warn(
      "WebGLRenderer: Unable to use reversed depth buffer due to missing EXT_clip_control extension. Fallback to default depth buffer.",
    )
  }
  if parameters.logarithmic_depth_buffer && reversed_depth_buffer {
    @core.warn(
      "WebGLRenderer: Logarithmic depth buffer is ignored when reversed depth buffer is enabled.",
    )
  }
  let max_textures = gl.get_parameter_int(GL_MAX_TEXTURE_IMAGE_UNITS)
  let max_vertex_textures = gl.get_parameter_int(
    GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS,
  )
  let max_texture_size = gl.get_parameter_int(GL_MAX_TEXTURE_SIZE)
  let max_cubemap_size = gl.get_parameter_int(GL_MAX_CUBE_MAP_TEXTURE_SIZE)
  let max_attributes = gl.get_parameter_int(GL_MAX_VERTEX_ATTRIBS)
  let max_vertex_uniforms = gl.get_parameter_int(GL_MAX_VERTEX_UNIFORM_VECTORS)
  let max_varyings = gl.get_parameter_int(GL_MAX_VARYING_VECTORS)
  let max_fragment_uniforms = gl.get_parameter_int(
    GL_MAX_FRAGMENT_UNIFORM_VECTORS,
  )
  let max_samples = gl.get_parameter_int(GL_MAX_SAMPLES)
  let samples = gl.get_parameter_int(GL_SAMPLES)
  {
    gl,
    extensions,
    utils,
    max_anisotropy: None,
    is_webgl2: true,
    precision,
    logarithmic_depth_buffer,
    reversed_depth_buffer,
    max_textures,
    max_vertex_textures,
    max_texture_size,
    max_cubemap_size,
    max_attributes,
    max_vertex_uniforms,
    max_varyings,
    max_fragment_uniforms,
    max_samples,
    samples,
  }
}

///|
/// `capabilities.getMaxAnisotropy()`.
pub fn WebGLCapabilities::get_max_anisotropy(
  self : WebGLCapabilities,
) -> Double {
  if self.max_anisotropy is Some(value) {
    return value
  }
  let value = if self.extensions.has("EXT_texture_filter_anisotropic") {
    match self.extensions.get("EXT_texture_filter_anisotropic") {
      Some(extension) =>
        js_to_double(
          self.gl.get_parameter(
            extension.constant("MAX_TEXTURE_MAX_ANISOTROPY_EXT"),
          ),
        )
      None => 0.0
    }
  } else {
    0.0
  }
  self.max_anisotropy = Some(value)
  value
}

///|
fn webgl_capabilities_max_precision(
  gl : WebGL2RenderingContext,
  precision : String,
) -> String {
  let mut precision = precision
  if precision == "highp" {
    if gl
      .get_shader_precision_format(GL_VERTEX_SHADER, GL_HIGH_FLOAT)
      .precision() >
      0 &&
      gl
      .get_shader_precision_format(GL_FRAGMENT_SHADER, GL_HIGH_FLOAT)
      .precision() >
      0 {
      return "highp"
    }
    precision = "mediump"
  }
  if precision == "mediump" {
    if gl
      .get_shader_precision_format(GL_VERTEX_SHADER, GL_MEDIUM_FLOAT)
      .precision() >
      0 &&
      gl
      .get_shader_precision_format(GL_FRAGMENT_SHADER, GL_MEDIUM_FLOAT)
      .precision() >
      0 {
      return "mediump"
    }
  }
  "lowp"
}

///|
/// `capabilities.getMaxPrecision( precision )`.
pub fn WebGLCapabilities::get_max_precision(
  self : WebGLCapabilities,
  precision : String,
) -> String {
  webgl_capabilities_max_precision(self.gl, precision)
}

///|
/// `capabilities.textureFormatReadable( textureFormat )`.
pub fn WebGLCapabilities::texture_format_readable(
  self : WebGLCapabilities,
  texture_format : Int32,
) -> Bool {
  if texture_format != @core.RGBAFormat &&
    self.utils.convert(texture_format) !=
    Some(self.gl.get_parameter_int(GL_IMPLEMENTATION_COLOR_READ_FORMAT)) {
    return false
  }
  true
}

///|
/// `capabilities.textureTypeReadable( textureType )`.
pub fn WebGLCapabilities::texture_type_readable(
  self : WebGLCapabilities,
  texture_type : Int32,
) -> Bool {
  let half_float_supported_by_ext = texture_type == @core.HalfFloatType &&
    (
      self.extensions.has("EXT_color_buffer_half_float") ||
      self.extensions.has("EXT_color_buffer_float")
    )
  if texture_type != @core.UnsignedByteType &&
    texture_type != @core.FloatType &&
    !half_float_supported_by_ext &&
    self.utils.convert(texture_type) !=
    Some(self.gl.get_parameter_int(GL_IMPLEMENTATION_COLOR_READ_TYPE)) {
    // Edge and Chrome Mac < 52 (#9513)
    return false
  }
  true
}
