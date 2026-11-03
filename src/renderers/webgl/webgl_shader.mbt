// Upstream src/renderers/webgl/WebGLShader.js.

///|
/// `WebGLShader( gl, type, string )`: creates and compiles a shader.
pub fn webgl_shader(
  gl : WebGL2RenderingContext,
  type_ : Int32,
  string : String,
) -> GLShader {
  let shader = gl.create_shader(type_)
  gl.shader_source(shader, string)
  gl.compile_shader(shader)
  shader
}
