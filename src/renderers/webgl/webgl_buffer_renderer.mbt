// Upstream src/renderers/webgl/WebGLBufferRenderer.js.

///|
pub struct WebGLBufferRenderer {
  gl : WebGL2RenderingContext
  extensions : WebGLExtensions
  info : WebGLInfo
  mut mode : Int32
}

///|
/// `new WebGLBufferRenderer( gl, extensions, info )`.
pub fn WebGLBufferRenderer::new(
  gl : WebGL2RenderingContext,
  extensions : WebGLExtensions,
  info : WebGLInfo,
) -> WebGLBufferRenderer {
  { gl, extensions, info, mode: 0, }
}

///|
/// `renderer.setMode( value )`.
pub fn WebGLBufferRenderer::set_mode(
  self : WebGLBufferRenderer,
  value : Int32,
) -> Unit {
  self.mode = value
}

///|
/// `renderer.render( start, count )`.
pub fn WebGLBufferRenderer::render(
  self : WebGLBufferRenderer,
  start : Int32,
  count : Int32,
) -> Unit {
  self.gl.draw_arrays(self.mode, start, count)
  self.info.update(count, self.mode, 1)
}

///|
/// `renderer.renderInstances( start, count, primcount )`.
pub fn WebGLBufferRenderer::render_instances(
  self : WebGLBufferRenderer,
  start : Int32,
  count : Int32,
  primcount : Int32,
) -> Unit {
  if primcount == 0 {
    return
  }
  self.gl.draw_arrays_instanced(self.mode, start, count, primcount)
  self.info.update(count, self.mode, primcount)
}

///|
/// `renderer.renderMultiDraw( starts, counts, drawCount )`.
pub fn WebGLBufferRenderer::render_multi_draw(
  self : WebGLBufferRenderer,
  starts : @core.TypedArray,
  counts : @core.TypedArray,
  draw_count : Int32,
) -> Unit {
  if draw_count == 0 {
    return
  }
  guard self.extensions.get("WEBGL_multi_draw") is Some(extension) else {
    abort("WebGLBufferRenderer: WEBGL_multi_draw is not supported")
  }
  extension.multi_draw_arrays_webgl(self.mode, starts, 0, counts, 0, draw_count)
  let mut element_count = 0
  for i in 0..<draw_count {
    element_count += counts.get_int(i)
  }
  self.info.update(element_count, self.mode, 1)
}
