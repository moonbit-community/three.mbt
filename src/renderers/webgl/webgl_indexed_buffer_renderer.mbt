// Upstream src/renderers/webgl/WebGLIndexedBufferRenderer.js.

///|
pub struct WebGLIndexedBufferRenderer {
  gl : WebGL2RenderingContext
  extensions : WebGLExtensions
  info : WebGLInfo
  mut mode : Int32
  mut type_ : Int32
  mut bytes_per_element : Int32
}

///|
/// `new WebGLIndexedBufferRenderer( gl, extensions, info )`.
pub fn WebGLIndexedBufferRenderer::new(
  gl : WebGL2RenderingContext,
  extensions : WebGLExtensions,
  info : WebGLInfo,
) -> WebGLIndexedBufferRenderer {
  { gl, extensions, info, mode: 0, type_: 0, bytes_per_element: 0, }
}

///|
/// `renderer.setMode( value )`.
pub fn WebGLIndexedBufferRenderer::set_mode(
  self : WebGLIndexedBufferRenderer,
  value : Int32,
) -> Unit {
  self.mode = value
}

///|
/// `renderer.setIndex( value )`, the index buffer from `WebGLAttributes`.
pub fn WebGLIndexedBufferRenderer::set_index(
  self : WebGLIndexedBufferRenderer,
  value : WebGLAttributeBuffer,
) -> Unit {
  self.type_ = value.type_
  self.bytes_per_element = value.bytes_per_element
}

///|
/// `renderer.render( start, count )`.
pub fn WebGLIndexedBufferRenderer::render(
  self : WebGLIndexedBufferRenderer,
  start : Int32,
  count : Int32,
) -> Unit {
  self.gl.draw_elements(
    self.mode,
    count,
    self.type_,
    start * self.bytes_per_element,
  )
  self.info.update(count, self.mode, 1)
}

///|
/// `renderer.renderInstances( start, count, primcount )`.
pub fn WebGLIndexedBufferRenderer::render_instances(
  self : WebGLIndexedBufferRenderer,
  start : Int32,
  count : Int32,
  primcount : Int32,
) -> Unit {
  if primcount == 0 {
    return
  }
  self.gl.draw_elements_instanced(
    self.mode,
    count,
    self.type_,
    start * self.bytes_per_element,
    primcount,
  )
  self.info.update(count, self.mode, primcount)
}

///|
/// `renderer.renderMultiDraw( starts, counts, drawCount )`.
pub fn WebGLIndexedBufferRenderer::render_multi_draw(
  self : WebGLIndexedBufferRenderer,
  starts : @core.TypedArray,
  counts : @core.TypedArray,
  draw_count : Int32,
) -> Unit {
  if draw_count == 0 {
    return
  }
  guard self.extensions.get("WEBGL_multi_draw") is Some(extension) else {
    abort("WebGLIndexedBufferRenderer: WEBGL_multi_draw is not supported")
  }
  extension.multi_draw_elements_webgl(
    self.mode,
    counts,
    0,
    self.type_,
    starts,
    0,
    draw_count,
  )
  let mut element_count = 0
  for i in 0..<draw_count {
    element_count += counts.get_int(i)
  }
  self.info.update(element_count, self.mode, 1)
}
