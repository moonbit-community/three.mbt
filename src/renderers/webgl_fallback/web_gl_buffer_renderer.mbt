// renderers/webgl-fallback/WebGLBufferRenderer.js: the draw calls of a render object.

///|
pub(all) struct WebGLBufferRenderer {
  gl : @webgl.WebGL2RenderingContext
  extensions : WebGLExtensions
  info : @nodes.Info
  /// `mode`; `None` is `null`.
  mut mode : Int32?
  mut index : Int32
  /// `type`; `None` is `null`.
  mut type_ : Int32?
  /// `object`; `None` is `null`.
  mut object : @core.Object3D?
}

///|
/// `new WebGLBufferRenderer( backend )`.
pub fn WebGLBufferRenderer::new(backend : WebGLBackend) -> WebGLBufferRenderer {
  {
    gl: backend.gl.unwrap(),
    extensions: backend.extensions.unwrap(),
    info: backend.renderer().info,
    mode: None,
    index: 0,
    type_: None,
    object: None,
  }
}

///|
/// `null` for a GL enum argument (WebGL reads it as 0).
fn _webgl_buffer_renderer_enum(value : Int32?) -> Int32 {
  match value {
    Some(v) => v
    None => 0
  }
}

///|
fn _webgl_buffer_renderer_object(
  renderer : WebGLBufferRenderer,
) -> @core.Object3D {
  match renderer.object {
    Some(o) => o
    None => abort("TypeError: Cannot read properties of null (reading 'count')")
  }
}

///|
/// `render( start, count )`.
pub fn WebGLBufferRenderer::render(
  self : WebGLBufferRenderer,
  start : Int32,
  count : Int32,
) -> Unit {
  let gl = self.gl
  let mode = _webgl_buffer_renderer_enum(self.mode)
  if self.index != 0 {
    gl.draw_elements(
      mode,
      count,
      _webgl_buffer_renderer_enum(self.type_),
      start,
    )
  } else {
    gl.draw_arrays(mode, start, count)
  }
  self.info.update(_webgl_buffer_renderer_object(self), count.to_double(), 1.0)
}

///|
/// `renderInstances( start, count, primcount )`.
pub fn WebGLBufferRenderer::render_instances(
  self : WebGLBufferRenderer,
  start : Int32,
  count : Int32,
  primcount : Int32,
) -> Unit {
  let gl = self.gl
  if primcount == 0 {
    return
  }
  let mode = _webgl_buffer_renderer_enum(self.mode)
  if self.index != 0 {
    gl.draw_elements_instanced(
      mode,
      count,
      _webgl_buffer_renderer_enum(self.type_),
      start,
      primcount,
    )
  } else {
    gl.draw_arrays_instanced(mode, start, count, primcount)
  }
  self.info.update(
    _webgl_buffer_renderer_object(self),
    count.to_double(),
    primcount.to_double(),
  )
}

///|
/// `renderMultiDraw( starts, counts, drawCount )`.
pub fn WebGLBufferRenderer::render_multi_draw(
  self : WebGLBufferRenderer,
  starts : @core.TypedArray,
  counts : @core.TypedArray,
  draw_count : Int32,
) -> Unit {
  if draw_count == 0 {
    return
  }
  match self.extensions.get("WEBGL_multi_draw") {
    None =>
      for i in 0..<draw_count {
        self.render(starts[i].to_int(), counts[i].to_int())
      }
    Some(extension) => {
      let mode = _webgl_buffer_renderer_enum(self.mode)
      if self.index != 0 {
        extension.multi_draw_elements_webgl(
          mode,
          counts,
          0,
          _webgl_buffer_renderer_enum(self.type_),
          starts,
          0,
          draw_count,
        )
      } else {
        extension.multi_draw_arrays_webgl(
          mode, starts, 0, counts, 0, draw_count,
        )
      }
      let mut element_count = 0.0
      for i in 0..<draw_count {
        element_count += counts[i]
      }
      self.info.update(_webgl_buffer_renderer_object(self), element_count, 1.0)
    }
  }
}
