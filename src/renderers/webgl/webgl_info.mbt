// Upstream src/renderers/webgl/WebGLInfo.js.

///|
/// `info.memory`.
pub(all) struct WebGLInfoMemory {
  mut geometries : Int32
  mut textures : Int32
}

///|
/// `info.render`. Primitive counts are JS numbers upstream (`count / 3` need not be whole).
pub(all) struct WebGLInfoRender {
  mut frame : Int32
  mut calls : Int32
  mut triangles : Double
  mut points : Double
  mut lines : Double
}

///|
pub(all) struct WebGLInfo {
  gl : WebGL2RenderingContext
  memory : WebGLInfoMemory
  render : WebGLInfoRender
  /// `programCache.programs`, set by `WebGLRenderer`.
  mut programs : Array[WebGLProgram]?
  mut auto_reset : Bool
}

///|
/// `new WebGLInfo( gl )`.
pub fn WebGLInfo::new(gl : WebGL2RenderingContext) -> WebGLInfo {
  {
    gl,
    memory: { geometries: 0, textures: 0, },
    render: { frame: 0, calls: 0, triangles: 0, points: 0, lines: 0, },
    programs: None,
    auto_reset: true,
  }
}

///|
/// `info.update( count, mode, instanceCount )`.
pub fn WebGLInfo::update(
  self : WebGLInfo,
  count : Int32,
  mode : Int32,
  instance_count : Int32,
) -> Unit {
  let render = self.render
  render.calls += 1
  let count = count.to_double()
  let instance_count = instance_count.to_double()
  match mode {
    GL_TRIANGLES => render.triangles += instance_count * (count / 3.0)
    GL_LINES => render.lines += instance_count * (count / 2.0)
    GL_LINE_STRIP => render.lines += instance_count * (count - 1.0)
    GL_LINE_LOOP => render.lines += instance_count * count
    GL_POINTS => render.points += instance_count * count
    _ => @core.error("WebGLInfo: Unknown draw mode: \{mode}")
  }
}

///|
/// `info.reset()`.
pub fn WebGLInfo::reset(self : WebGLInfo) -> Unit {
  self.render.calls = 0
  self.render.triangles = 0
  self.render.points = 0
  self.render.lines = 0
}
