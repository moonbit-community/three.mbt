// Upstream src/renderers/webgl/WebGLState.js. GROUP 2.
//
// The three buffer closures become structs. `DepthBuffer` and `StencilBuffer` call the
// state's `enable` / `disable`, so they hold the state (assigned right after it is built;
// `uninitialized()` until then). Texture upload wrappers keep upstream's `try`/`catch`
// through `js_try`.

///|
/// `ColorBuffer()`.
pub(all) struct ColorBuffer {
  gl : WebGL2RenderingContext
  mut locked : Bool
  color : @math.Vector4
  mut current_color_mask : Bool?
  current_color_clear : @math.Vector4
}

///|
/// `buffers.color.setMask( colorMask )`.
pub fn ColorBuffer::set_mask(self : ColorBuffer, color_mask : Bool) -> Unit {
  if self.current_color_mask != Some(color_mask) && !self.locked {
    self.gl.color_mask(color_mask, color_mask, color_mask, color_mask)
    self.current_color_mask = Some(color_mask)
  }
}

///|
/// `buffers.color.setLocked( lock )`.
pub fn ColorBuffer::set_locked(self : ColorBuffer, lock : Bool) -> Unit {
  self.locked = lock
}

///|
/// `buffers.color.setClear( r, g, b, a, premultipliedAlpha )`.
pub fn ColorBuffer::set_clear(
  self : ColorBuffer,
  r : Double,
  g : Double,
  b : Double,
  a : Double,
  premultiplied_alpha~ : Bool = false,
) -> Unit {
  let (r, g, b) = if premultiplied_alpha {
    (r * a, g * a, b * a)
  } else {
    (r, g, b)
  }
  ignore(self.color.set(r, g, b, a))
  if !self.current_color_clear.equals(self.color) {
    self.gl.clear_color(r, g, b, a)
    ignore(self.current_color_clear.copy(self.color))
  }
}

///|
/// `buffers.color.reset()`.
pub fn ColorBuffer::reset(self : ColorBuffer) -> Unit {
  self.locked = false
  self.current_color_mask = None
  ignore(self.current_color_clear.set(-1.0, 0.0, 0.0, 0.0)) // set to invalid state
}

///|
/// `DepthBuffer()`.
pub(all) struct DepthBuffer {
  gl : WebGL2RenderingContext
  extensions : WebGLExtensions
  mut state : WebGLState
  mut locked : Bool
  mut current_reversed : Bool
  mut current_depth_mask : Bool?
  mut current_depth_func : Int32?
  mut current_depth_clear : Double?
}

///|
/// `buffers.depth.setReversed( reversed )`.
pub fn DepthBuffer::set_reversed(self : DepthBuffer, reversed : Bool) -> Unit {
  if self.current_reversed != reversed {
    let ext = self.extensions.get("EXT_clip_control").unwrap()
    if reversed {
      ext.clip_control_ext(
        ext.constant("LOWER_LEFT_EXT"),
        ext.constant("ZERO_TO_ONE_EXT"),
      )
    } else {
      ext.clip_control_ext(
        ext.constant("LOWER_LEFT_EXT"),
        ext.constant("NEGATIVE_ONE_TO_ONE_EXT"),
      )
    }
    self.current_reversed = reversed
    let old_depth = self.current_depth_clear
    self.current_depth_clear = None
    self.set_clear_optional(old_depth)
  }
}

///|
/// `buffers.depth.getReversed()`.
pub fn DepthBuffer::get_reversed(self : DepthBuffer) -> Bool {
  self.current_reversed
}

///|
/// `buffers.depth.setTest( depthTest )`.
pub fn DepthBuffer::set_test(self : DepthBuffer, depth_test : Bool) -> Unit {
  if depth_test {
    self.state.enable(GL_DEPTH_TEST)
  } else {
    self.state.disable(GL_DEPTH_TEST)
  }
}

///|
/// `buffers.depth.setMask( depthMask )`.
pub fn DepthBuffer::set_mask(self : DepthBuffer, depth_mask : Bool) -> Unit {
  if self.current_depth_mask != Some(depth_mask) && !self.locked {
    self.gl.depth_mask(depth_mask)
    self.current_depth_mask = Some(depth_mask)
  }
}

///|
/// `ReversedDepthFuncs[ depthFunc ]` (utils.js); `None` is `undefined`.
fn webgl_state_reversed_depth_func(depth_func : Int32) -> Int32? {
  match depth_func {
    @core.NeverDepth => Some(@core.NeverDepth)
    @core.LessDepth => Some(@core.GreaterDepth)
    @core.EqualDepth => Some(@core.EqualDepth)
    @core.LessEqualDepth => Some(@core.GreaterEqualDepth)
    @core.AlwaysDepth => Some(@core.AlwaysDepth)
    @core.GreaterDepth => Some(@core.LessDepth)
    @core.NotEqualDepth => Some(@core.NotEqualDepth)
    @core.GreaterEqualDepth => Some(@core.LessEqualDepth)
    _ => None
  }
}

///|
/// `buffers.depth.setFunc( depthFunc )`.
pub fn DepthBuffer::set_func(self : DepthBuffer, depth_func : Int32) -> Unit {
  let depth_func = if self.current_reversed {
    webgl_state_reversed_depth_func(depth_func)
  } else {
    Some(depth_func)
  }
  if self.current_depth_func != depth_func {
    match depth_func {
      Some(@core.NeverDepth) => self.gl.depth_func(GL_NEVER)
      Some(@core.AlwaysDepth) => self.gl.depth_func(GL_ALWAYS)
      Some(@core.LessDepth) => self.gl.depth_func(GL_LESS)
      Some(@core.LessEqualDepth) => self.gl.depth_func(GL_LEQUAL)
      Some(@core.EqualDepth) => self.gl.depth_func(GL_EQUAL)
      Some(@core.GreaterEqualDepth) => self.gl.depth_func(GL_GEQUAL)
      Some(@core.GreaterDepth) => self.gl.depth_func(GL_GREATER)
      Some(@core.NotEqualDepth) => self.gl.depth_func(GL_NOTEQUAL)
      _ => self.gl.depth_func(GL_LEQUAL)
    }
    self.current_depth_func = depth_func
  }
}

///|
/// `buffers.depth.setLocked( lock )`.
pub fn DepthBuffer::set_locked(self : DepthBuffer, lock : Bool) -> Unit {
  self.locked = lock
}

///|
/// `buffers.depth.setClear( depth )`. (`setReversed` re-applies a possibly `null` clear
/// value internally; `current_depth_clear` is `None` then.)
pub fn DepthBuffer::set_clear(self : DepthBuffer, depth : Double) -> Unit {
  self.set_clear_optional(Some(depth))
}

///|
/// `setClear( depth )` where `depth` may be `null` (`None`).
fn DepthBuffer::set_clear_optional(self : DepthBuffer, depth : Double?) -> Unit {
  if self.current_depth_clear != depth {
    self.current_depth_clear = depth
    // `1 - null` is 1 in JS; `null` itself is only passed when it equals the current
    // value, so this branch always has a number.
    let mut value = depth.unwrap_or(0.0)
    if self.current_reversed {
      value = 1.0 - value
    }
    self.gl.clear_depth(value)
  }
}

///|
/// `buffers.depth.reset()`.
pub fn DepthBuffer::reset(self : DepthBuffer) -> Unit {
  self.locked = false
  self.current_depth_mask = None
  self.current_depth_func = None
  self.current_depth_clear = None
  self.current_reversed = false
}

///|
/// `StencilBuffer()`.
pub(all) struct StencilBuffer {
  gl : WebGL2RenderingContext
  mut state : WebGLState
  mut locked : Bool
  mut current_stencil_mask : Int32?
  mut current_stencil_func : Int32?
  mut current_stencil_ref : Int32?
  mut current_stencil_func_mask : Int32?
  mut current_stencil_fail : Int32?
  mut current_stencil_z_fail : Int32?
  mut current_stencil_z_pass : Int32?
  mut current_stencil_clear : Int32?
}

///|
/// `buffers.stencil.setTest( stencilTest )`.
pub fn StencilBuffer::set_test(
  self : StencilBuffer,
  stencil_test : Bool,
) -> Unit {
  if !self.locked {
    if stencil_test {
      self.state.enable(GL_STENCIL_TEST)
    } else {
      self.state.disable(GL_STENCIL_TEST)
    }
  }
}

///|
/// `buffers.stencil.setMask( stencilMask )`. `0xffffffff` is `-1` as an `Int`.
pub fn StencilBuffer::set_mask(
  self : StencilBuffer,
  stencil_mask : Int32,
) -> Unit {
  if self.current_stencil_mask != Some(stencil_mask) && !self.locked {
    self.gl.stencil_mask(stencil_mask)
    self.current_stencil_mask = Some(stencil_mask)
  }
}

///|
/// `buffers.stencil.setFunc( stencilFunc, stencilRef, stencilMask )`.
pub fn StencilBuffer::set_func(
  self : StencilBuffer,
  stencil_func : Int32,
  stencil_ref : Int32,
  stencil_mask : Int32,
) -> Unit {
  if self.current_stencil_func != Some(stencil_func) ||
    self.current_stencil_ref != Some(stencil_ref) ||
    self.current_stencil_func_mask != Some(stencil_mask) {
    self.gl.stencil_func(stencil_func, stencil_ref, stencil_mask)
    self.current_stencil_func = Some(stencil_func)
    self.current_stencil_ref = Some(stencil_ref)
    self.current_stencil_func_mask = Some(stencil_mask)
  }
}

///|
/// `buffers.stencil.setOp( stencilFail, stencilZFail, stencilZPass )`.
pub fn StencilBuffer::set_op(
  self : StencilBuffer,
  stencil_fail : Int32,
  stencil_z_fail : Int32,
  stencil_z_pass : Int32,
) -> Unit {
  if self.current_stencil_fail != Some(stencil_fail) ||
    self.current_stencil_z_fail != Some(stencil_z_fail) ||
    self.current_stencil_z_pass != Some(stencil_z_pass) {
    self.gl.stencil_op(stencil_fail, stencil_z_fail, stencil_z_pass)
    self.current_stencil_fail = Some(stencil_fail)
    self.current_stencil_z_fail = Some(stencil_z_fail)
    self.current_stencil_z_pass = Some(stencil_z_pass)
  }
}

///|
/// `buffers.stencil.setLocked( lock )`.
pub fn StencilBuffer::set_locked(self : StencilBuffer, lock : Bool) -> Unit {
  self.locked = lock
}

///|
/// `buffers.stencil.setClear( stencil )`.
pub fn StencilBuffer::set_clear(self : StencilBuffer, stencil : Int32) -> Unit {
  if self.current_stencil_clear != Some(stencil) {
    self.gl.clear_stencil(stencil)
    self.current_stencil_clear = Some(stencil)
  }
}

///|
/// `buffers.stencil.reset()`.
pub fn StencilBuffer::reset(self : StencilBuffer) -> Unit {
  self.locked = false
  self.current_stencil_mask = None
  self.current_stencil_func = None
  self.current_stencil_ref = None
  self.current_stencil_func_mask = None
  self.current_stencil_fail = None
  self.current_stencil_z_fail = None
  self.current_stencil_z_pass = None
  self.current_stencil_clear = None
}

///|
/// `state.buffers`.
pub(all) struct WebGLStateBuffers {
  color : ColorBuffer
  depth : DepthBuffer
  stencil : StencilBuffer
}

///|
/// `currentBoundTextures[ slot ]`; `None` fields are upstream's `undefined`.
pub(all) struct BoundTexture {
  mut type_ : Int32?
  mut texture : GLTexture?
}

///|
pub(all) struct WebGLState {
  gl : WebGL2RenderingContext
  extensions : WebGLExtensions
  buffers : WebGLStateBuffers
  /// binding point -> buffer
  mut ubo_bindings : Map[Int32, GLBuffer?]
  /// program -> (uniforms group id -> block index)
  ubo_program_map : WeakMap[GLProgram, Map[Int32, Int32]]
  mut enabled_capabilities : Map[Int32, Bool]
  /// `pixelStorei` values (numbers or booleans) by name
  mut parameters : Map[Int32, @core.JsValue]
  mut current_bound_framebuffers : Map[Int32, GLFramebuffer?]
  mut current_drawbuffers : WeakMap[GLFramebuffer, Array[Int32]]
  mut default_drawbuffers : Array[Int32]
  mut current_program : GLProgram?
  mut current_blending_enabled : Bool
  mut current_blending : Int32?
  mut current_blend_equation : Int32?
  mut current_blend_src : Int32?
  mut current_blend_dst : Int32?
  mut current_blend_equation_alpha : Int32?
  mut current_blend_src_alpha : Int32?
  mut current_blend_dst_alpha : Int32?
  mut current_blend_color : @math.Color
  mut current_blend_alpha : Double
  mut current_premultipled_alpha : Bool
  mut current_flip_sided : Bool?
  mut current_cull_face : Int32?
  mut current_line_width : Double?
  mut current_polygon_offset_factor : Double?
  mut current_polygon_offset_units : Double?
  max_textures : Int32
  line_width_available : Bool
  version : Double
  mut current_texture_slot : Int32?
  mut current_bound_textures : Map[Int32, BoundTexture]
  current_scissor : @math.Vector4
  current_viewport : @math.Vector4
  /// GL texture target -> 1x1 placeholder
  empty_textures : Map[Int32, GLTexture]
  equation_to_gl : Map[Int32, Int32]
  factor_to_gl : Map[Int32, Int32]
}

///|
/// States whose `currentPremultipledAlpha` holds `undefined` (a `setBlending` call without
/// that argument assigned it); the field then reads `false`.
let webgl_state_premultiplied_alpha_undefined : WeakMap[WebGLState, Bool] = WeakMap::new()

///|
/// `currentPremultipledAlpha`, with `None` for `undefined`.
fn WebGLState::current_premultiplied(self : WebGLState) -> Bool? {
  if webgl_state_premultiplied_alpha_undefined.get(self) == Some(true) {
    None
  } else {
    Some(self.current_premultipled_alpha)
  }
}

///|
/// `currentPremultipledAlpha = value`.
fn WebGLState::set_current_premultiplied(
  self : WebGLState,
  value : Bool?,
) -> Unit {
  match value {
    Some(v) => {
      self.current_premultipled_alpha = v
      webgl_state_premultiplied_alpha_undefined.delete(self)
    }
    None => {
      self.current_premultipled_alpha = false
      webgl_state_premultiplied_alpha_undefined.set(self, true)
    }
  }
}

///|
extern "js" fn webgl_state_parse_version(gl_version : String) -> Double =
  #|(v) => {
  #|  if (v.indexOf('WebGL') !== -1) return parseFloat(/^WebGL (\d)/.exec(v)[1]);
  #|  if (v.indexOf('OpenGL ES') !== -1) return parseFloat(/^OpenGL ES (\d)/.exec(v)[1]);
  #|  return 0;
  #|}

///|
/// JS `NaN`, what `undefined` reads as in arithmetic.
let webgl_state_nan : Double = 0.0 / 0.0

///|
/// `createTexture( type, target, count, dimensions )`.
fn webgl_state_create_texture(
  gl : WebGL2RenderingContext,
  type_ : Int32,
  target : Int32,
  count : Int32,
  dimensions : Int32,
) -> GLTexture {
  let data = @core.TypedArray::uint8([0.0, 0.0, 0.0, 0.0]) // 4 is required to match default unpack alignment of 4.
  let texture = gl.create_texture()
  gl.bind_texture(type_, Some(texture))
  gl.tex_parameteri(type_, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
  gl.tex_parameteri(type_, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
  for i in 0..<count {
    if type_ == GL_TEXTURE_3D || type_ == GL_TEXTURE_2D_ARRAY {
      gl.tex_image3d(
        target,
        0,
        GL_RGBA,
        1,
        1,
        dimensions,
        0,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        data,
      )
    } else {
      gl.tex_image2d(
        target + i,
        0,
        GL_RGBA,
        1,
        1,
        0,
        GL_RGBA,
        GL_UNSIGNED_BYTE,
        data,
      )
    }
  }
  texture
}

///|
/// `new WebGLState( gl, extensions )`: creates the buffers, empty textures and the initial
/// GL state.
pub fn WebGLState::new(
  gl : WebGL2RenderingContext,
  extensions : WebGLExtensions,
) -> WebGLState {
  let color_buffer : ColorBuffer = {
    gl,
    locked: false,
    color: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    current_color_mask: None,
    current_color_clear: @math.Vector4::new(0.0, 0.0, 0.0, 0.0),
  }
  let depth_buffer : DepthBuffer = {
    gl,
    extensions,
    state: uninitialized(),
    locked: false,
    current_reversed: false,
    current_depth_mask: None,
    current_depth_func: None,
    current_depth_clear: None,
  }
  let stencil_buffer : StencilBuffer = {
    gl,
    state: uninitialized(),
    locked: false,
    current_stencil_mask: None,
    current_stencil_func: None,
    current_stencil_ref: None,
    current_stencil_func_mask: None,
    current_stencil_fail: None,
    current_stencil_z_fail: None,
    current_stencil_z_pass: None,
    current_stencil_clear: None,
  }
  let max_textures = gl.get_parameter_int(GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS)
  let gl_version = gl.get_parameter_string(GL_VERSION)
  let version = webgl_state_parse_version(gl_version)
  let line_width_available = if gl_version.contains("WebGL") {
    version >= 1.0
  } else if gl_version.contains("OpenGL ES") {
    version >= 2.0
  } else {
    false
  }
  let scissor_param = gl.get_parameter_array(GL_SCISSOR_BOX)
  let viewport_param = gl.get_parameter_array(GL_VIEWPORT)
  let current_scissor = @math.Vector4::new(0.0, 0.0, 0.0, 1.0).from_array(
    scissor_param,
  )
  let current_viewport = @math.Vector4::new(0.0, 0.0, 0.0, 1.0).from_array(
    viewport_param,
  )
  let empty_textures : Map[Int32, GLTexture] = Map([])
  empty_textures[GL_TEXTURE_2D] = webgl_state_create_texture(
    gl,
    GL_TEXTURE_2D,
    GL_TEXTURE_2D,
    1,
    0,
  )
  empty_textures[GL_TEXTURE_CUBE_MAP] = webgl_state_create_texture(
    gl,
    GL_TEXTURE_CUBE_MAP,
    GL_TEXTURE_CUBE_MAP_POSITIVE_X,
    6,
    0,
  )
  empty_textures[GL_TEXTURE_2D_ARRAY] = webgl_state_create_texture(
    gl,
    GL_TEXTURE_2D_ARRAY,
    GL_TEXTURE_2D_ARRAY,
    1,
    1,
  )
  empty_textures[GL_TEXTURE_3D] = webgl_state_create_texture(
    gl,
    GL_TEXTURE_3D,
    GL_TEXTURE_3D,
    1,
    1,
  )
  let equation_to_gl : Map[Int32, Int32] = Map::from_array([
    (@core.AddEquation, GL_FUNC_ADD),
    (@core.SubtractEquation, GL_FUNC_SUBTRACT),
    (@core.ReverseSubtractEquation, GL_FUNC_REVERSE_SUBTRACT),
  ])
  equation_to_gl[@core.MinEquation] = GL_MIN
  equation_to_gl[@core.MaxEquation] = GL_MAX
  let factor_to_gl : Map[Int32, Int32] = Map::from_array([
    (@core.ZeroFactor, GL_ZERO),
    (@core.OneFactor, GL_ONE),
    (@core.SrcColorFactor, GL_SRC_COLOR),
    (@core.SrcAlphaFactor, GL_SRC_ALPHA),
    (@core.SrcAlphaSaturateFactor, GL_SRC_ALPHA_SATURATE),
    (@core.DstColorFactor, GL_DST_COLOR),
    (@core.DstAlphaFactor, GL_DST_ALPHA),
    (@core.OneMinusSrcColorFactor, GL_ONE_MINUS_SRC_COLOR),
    (@core.OneMinusSrcAlphaFactor, GL_ONE_MINUS_SRC_ALPHA),
    (@core.OneMinusDstColorFactor, GL_ONE_MINUS_DST_COLOR),
    (@core.OneMinusDstAlphaFactor, GL_ONE_MINUS_DST_ALPHA),
    (@core.ConstantColorFactor, GL_CONSTANT_COLOR),
    (@core.OneMinusConstantColorFactor, GL_ONE_MINUS_CONSTANT_COLOR),
    (@core.ConstantAlphaFactor, GL_CONSTANT_ALPHA),
    (@core.OneMinusConstantAlphaFactor, GL_ONE_MINUS_CONSTANT_ALPHA),
  ])
  let state : WebGLState = {
    gl,
    extensions,
    buffers: {
      color: color_buffer,
      depth: depth_buffer,
      stencil: stencil_buffer,
    },
    ubo_bindings: {},
    ubo_program_map: WeakMap::new(),
    enabled_capabilities: {},
    parameters: {},
    current_bound_framebuffers: {},
    current_drawbuffers: WeakMap::new(),
    default_drawbuffers: [],
    current_program: None,
    current_blending_enabled: false,
    current_blending: None,
    current_blend_equation: None,
    current_blend_src: None,
    current_blend_dst: None,
    current_blend_equation_alpha: None,
    current_blend_src_alpha: None,
    current_blend_dst_alpha: None,
    current_blend_color: @math.Color::new(0.0, 0.0, 0.0),
    current_blend_alpha: 0.0,
    current_premultipled_alpha: false,
    current_flip_sided: None,
    current_cull_face: None,
    current_line_width: None,
    current_polygon_offset_factor: None,
    current_polygon_offset_units: None,
    max_textures,
    line_width_available,
    version,
    current_texture_slot: None,
    current_bound_textures: {},
    current_scissor,
    current_viewport,
    empty_textures,
    equation_to_gl,
    factor_to_gl,
  }
  depth_buffer.state = state
  stencil_buffer.state = state

  // init

  color_buffer.set_clear(0.0, 0.0, 0.0, 1.0)
  depth_buffer.set_clear(1.0)
  stencil_buffer.set_clear(0)
  state.enable(GL_DEPTH_TEST)
  depth_buffer.set_func(@core.LessEqualDepth)
  state.set_flip_sided(false)
  state.set_cull_face(@core.CullFaceBack)
  state.enable(GL_CULL_FACE)
  state.set_blending(@core.NoBlending)
  state
}

///|
/// `state.enable( id )`.
pub fn WebGLState::enable(self : WebGLState, id : Int32) -> Unit {
  if self.enabled_capabilities.get(id) != Some(true) {
    self.gl.enable(id)
    self.enabled_capabilities[id] = true
  }
}

///|
/// `state.disable( id )`.
pub fn WebGLState::disable(self : WebGLState, id : Int32) -> Unit {
  if self.enabled_capabilities.get(id) != Some(false) {
    self.gl.disable(id)
    self.enabled_capabilities[id] = false
  }
}

///|
/// `state.bindFramebuffer( target, framebuffer )`; true if the binding changed.
pub fn WebGLState::bind_framebuffer(
  self : WebGLState,
  target : Int32,
  framebuffer : GLFramebuffer?,
) -> Bool {
  let changed = match self.current_bound_framebuffers.get(target) {
    None => true // undefined !== framebuffer
    Some(current) => !same_handle(current, framebuffer)
  }
  if changed {
    self.gl.bind_framebuffer(target, framebuffer)
    self.current_bound_framebuffers[target] = framebuffer

    // gl.DRAW_FRAMEBUFFER is equivalent to gl.FRAMEBUFFER

    if target == GL_DRAW_FRAMEBUFFER {
      self.current_bound_framebuffers[GL_FRAMEBUFFER] = framebuffer
    }
    if target == GL_FRAMEBUFFER {
      self.current_bound_framebuffers[GL_DRAW_FRAMEBUFFER] = framebuffer
    }
    return true
  }
  false
}

///|
/// `state.drawBuffers( renderTarget, framebuffer )`.
pub fn WebGLState::draw_buffers(
  self : WebGLState,
  render_target : @core.RenderTarget?,
  framebuffer : GLFramebuffer?,
) -> Unit {
  let mut draw_buffers = self.default_drawbuffers
  let mut needs_update = false
  match render_target {
    Some(render_target) => {
      let key = framebuffer.unwrap()
      draw_buffers = match self.current_drawbuffers.get(key) {
        Some(buffers) => buffers
        None => {
          let buffers = []
          self.current_drawbuffers.set(key, buffers)
          buffers
        }
      }
      let textures = render_target.textures
      if draw_buffers.length() != textures.length() ||
        draw_buffers.get(0) != Some(GL_COLOR_ATTACHMENT0) {
        for i in 0..<textures.length() {
          if i < draw_buffers.length() {
            draw_buffers[i] = GL_COLOR_ATTACHMENT0 + i
          } else {
            draw_buffers.push(GL_COLOR_ATTACHMENT0 + i)
          }
        }
        truncate_array(draw_buffers, textures.length())
        needs_update = true
      }
    }
    None =>
      if draw_buffers.get(0) != Some(GL_BACK) {
        if draw_buffers.length() == 0 {
          draw_buffers.push(GL_BACK)
        } else {
          draw_buffers[0] = GL_BACK
        }
        needs_update = true
      }
  }
  if needs_update {
    self.gl.draw_buffers(draw_buffers)
  }
}

///|
/// `state.useProgram( program )`; true if the program changed.
pub fn WebGLState::use_program(self : WebGLState, program : GLProgram?) -> Bool {
  if !same_handle(self.current_program, program) {
    self.gl.use_program(program)
    self.current_program = program
    return true
  }
  false
}

///|
/// JS `a || b` for optional numbers (`0` and `undefined` are falsy).
fn webgl_state_or(a : Int32?, b : Int32?) -> Int32? {
  match a {
    Some(v) if v != 0 => a
    _ => b
  }
}

///|
/// `state.setBlending( blending, blendEquation, blendSrc, blendDst, blendEquationAlpha,
/// blendSrcAlpha, blendDstAlpha, blendColor, blendAlpha, premultipliedAlpha )`.
/// Omitted arguments are upstream's `undefined`.
pub fn WebGLState::set_blending(
  self : WebGLState,
  blending : Int32,
  blend_equation? : Int32,
  blend_src? : Int32,
  blend_dst? : Int32,
  blend_equation_alpha? : Int32,
  blend_src_alpha? : Int32,
  blend_dst_alpha? : Int32,
  blend_color? : @math.Color,
  blend_alpha? : Double,
  premultiplied_alpha? : Bool,
) -> Unit {
  let gl = self.gl
  if blending == @core.NoBlending {
    if self.current_blending_enabled {
      self.disable(GL_BLEND)
      self.current_blending_enabled = false
    }
    return
  }
  if !self.current_blending_enabled {
    self.enable(GL_BLEND)
    self.current_blending_enabled = true
  }
  if blending != @core.CustomBlending {
    let current_premultiplied = self.current_premultiplied()
    if self.current_blending != Some(blending) ||
      premultiplied_alpha != current_premultiplied {
      if self.current_blend_equation != Some(@core.AddEquation) ||
        self.current_blend_equation_alpha != Some(@core.AddEquation) {
        gl.blend_equation(GL_FUNC_ADD)
        self.current_blend_equation = Some(@core.AddEquation)
        self.current_blend_equation_alpha = Some(@core.AddEquation)
      }
      if premultiplied_alpha == Some(true) {
        match blending {
          @core.NormalBlending =>
            gl.blend_func_separate(
              GL_ONE,
              GL_ONE_MINUS_SRC_ALPHA,
              GL_ONE,
              GL_ONE_MINUS_SRC_ALPHA,
            )
          @core.AdditiveBlending => gl.blend_func(GL_ONE, GL_ONE)
          @core.SubtractiveBlending =>
            gl.blend_func_separate(
              GL_ZERO,
              GL_ONE_MINUS_SRC_COLOR,
              GL_ZERO,
              GL_ONE,
            )
          @core.MultiplyBlending =>
            gl.blend_func_separate(
              GL_DST_COLOR,
              GL_ONE_MINUS_SRC_ALPHA,
              GL_ZERO,
              GL_ONE,
            )
          _ => @core.error("WebGLState: Invalid blending:  \{blending}")
        }
      } else {
        match blending {
          @core.NormalBlending =>
            gl.blend_func_separate(
              GL_SRC_ALPHA,
              GL_ONE_MINUS_SRC_ALPHA,
              GL_ONE,
              GL_ONE_MINUS_SRC_ALPHA,
            )
          @core.AdditiveBlending =>
            gl.blend_func_separate(GL_SRC_ALPHA, GL_ONE, GL_ONE, GL_ONE)
          @core.SubtractiveBlending =>
            @core.error(
              "WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true",
            )
          @core.MultiplyBlending =>
            @core.error(
              "WebGLState: MultiplyBlending requires material.premultipliedAlpha = true",
            )
          _ => @core.error("WebGLState: Invalid blending:  \{blending}")
        }
      }
      self.current_blend_src = None
      self.current_blend_dst = None
      self.current_blend_src_alpha = None
      self.current_blend_dst_alpha = None
      ignore(self.current_blend_color.set(0.0, 0.0, 0.0))
      self.current_blend_alpha = 0.0
      self.current_blending = Some(blending)
      self.set_current_premultiplied(premultiplied_alpha)
    }
    return
  }

  // custom blending

  let blend_equation_alpha = webgl_state_or(
    blend_equation_alpha, blend_equation,
  )
  let blend_src_alpha = webgl_state_or(blend_src_alpha, blend_src)
  let blend_dst_alpha = webgl_state_or(blend_dst_alpha, blend_dst)
  if blend_equation != self.current_blend_equation ||
    blend_equation_alpha != self.current_blend_equation_alpha {
    gl.blend_equation_separate(
      self.equation_to_gl_of(blend_equation),
      self.equation_to_gl_of(blend_equation_alpha),
    )
    self.current_blend_equation = blend_equation
    self.current_blend_equation_alpha = blend_equation_alpha
  }
  if blend_src != self.current_blend_src ||
    blend_dst != self.current_blend_dst ||
    blend_src_alpha != self.current_blend_src_alpha ||
    blend_dst_alpha != self.current_blend_dst_alpha {
    gl.blend_func_separate(
      self.factor_to_gl_of(blend_src),
      self.factor_to_gl_of(blend_dst),
      self.factor_to_gl_of(blend_src_alpha),
      self.factor_to_gl_of(blend_dst_alpha),
    )
    self.current_blend_src = blend_src
    self.current_blend_dst = blend_dst
    self.current_blend_src_alpha = blend_src_alpha
    self.current_blend_dst_alpha = blend_dst_alpha
  }
  let blend_color = blend_color.unwrap()
  let blend_alpha_value = blend_alpha.unwrap_or(webgl_state_nan)
  if !blend_color.equals(self.current_blend_color) ||
    blend_alpha_value != self.current_blend_alpha {
    gl.blend_color(
      blend_color.r,
      blend_color.g,
      blend_color.b,
      blend_alpha_value,
    )
    ignore(self.current_blend_color.copy(blend_color))
    self.current_blend_alpha = blend_alpha_value
  }
  self.current_blending = Some(blending)
  self.set_current_premultiplied(Some(false))
}

///|
/// `equationToGL[ equation ]`; an unknown equation passes 0 where upstream passes
/// `undefined`.
fn WebGLState::equation_to_gl_of(self : WebGLState, equation : Int32?) -> Int32 {
  match equation {
    Some(e) => self.equation_to_gl.get(e).unwrap_or(0)
    None => 0
  }
}

///|
/// `factorToGL[ factor ]`; an unknown factor passes 0 where upstream passes `undefined`.
fn WebGLState::factor_to_gl_of(self : WebGLState, factor : Int32?) -> Int32 {
  match factor {
    Some(f) => self.factor_to_gl.get(f).unwrap_or(0)
    None => 0
  }
}

///|
/// `state.setMaterial( material, frontFaceCW )`.
pub fn WebGLState::set_material(
  self : WebGLState,
  material : @core.Material,
  front_face_cw : Bool,
) -> Unit {
  if material.side == @core.DoubleSide {
    self.disable(GL_CULL_FACE)
  } else {
    self.enable(GL_CULL_FACE)
  }
  let mut flip_sided = material.side == @core.BackSide
  if front_face_cw {
    flip_sided = !flip_sided
  }
  self.set_flip_sided(flip_sided)
  if material.blending == @core.NormalBlending && material.transparent == false {
    self.set_blending(@core.NoBlending)
  } else {
    self.set_blending(
      material.blending,
      blend_equation=material.blend_equation,
      blend_src=material.blend_src,
      blend_dst=material.blend_dst,
      blend_equation_alpha?=material.blend_equation_alpha,
      blend_src_alpha?=material.blend_src_alpha,
      blend_dst_alpha?=material.blend_dst_alpha,
      blend_color=material.blend_color,
      blend_alpha=material.blend_alpha,
      premultiplied_alpha=material.premultiplied_alpha,
    )
  }
  self.buffers.depth.set_func(material.depth_func)
  self.buffers.depth.set_test(material.depth_test)
  self.buffers.depth.set_mask(material.depth_write)
  self.buffers.color.set_mask(material.color_write)
  let stencil_write = material.stencil_write
  self.buffers.stencil.set_test(stencil_write)
  if stencil_write {
    self.buffers.stencil.set_mask(material.stencil_write_mask)
    self.buffers.stencil.set_func(
      material.stencil_func,
      material.stencil_ref,
      material.stencil_func_mask,
    )
    self.buffers.stencil.set_op(
      material.stencil_fail,
      material.stencil_z_fail,
      material.stencil_z_pass,
    )
  }
  self.set_polygon_offset(
    material.polygon_offset,
    factor=material.polygon_offset_factor,
    units=material.polygon_offset_units,
  )
  if material.alpha_to_coverage == true {
    self.enable(GL_SAMPLE_ALPHA_TO_COVERAGE)
  } else {
    self.disable(GL_SAMPLE_ALPHA_TO_COVERAGE)
  }
}

///|
/// `state.setFlipSided( flipSided )`.
pub fn WebGLState::set_flip_sided(self : WebGLState, flip_sided : Bool) -> Unit {
  if self.current_flip_sided != Some(flip_sided) {
    if flip_sided {
      self.gl.front_face(GL_CW)
    } else {
      self.gl.front_face(GL_CCW)
    }
    self.current_flip_sided = Some(flip_sided)
  }
}

///|
/// `state.setCullFace( cullFace )`.
pub fn WebGLState::set_cull_face(self : WebGLState, cull_face : Int32) -> Unit {
  if cull_face != @core.CullFaceNone {
    self.enable(GL_CULL_FACE)
    if self.current_cull_face != Some(cull_face) {
      if cull_face == @core.CullFaceBack {
        self.gl.cull_face(GL_BACK)
      } else if cull_face == @core.CullFaceFront {
        self.gl.cull_face(GL_FRONT)
      } else {
        self.gl.cull_face(GL_FRONT_AND_BACK)
      }
    }
  } else {
    self.disable(GL_CULL_FACE)
  }
  self.current_cull_face = Some(cull_face)
}

///|
/// `state.setLineWidth( width )`.
pub fn WebGLState::set_line_width(self : WebGLState, width : Double) -> Unit {
  if self.current_line_width != Some(width) {
    if self.line_width_available {
      self.gl.line_width(width)
    }
    self.current_line_width = Some(width)
  }
}

///|
/// `state.setPolygonOffset( polygonOffset, factor, units )`.
pub fn WebGLState::set_polygon_offset(
  self : WebGLState,
  polygon_offset : Bool,
  factor? : Double,
  units? : Double,
) -> Unit {
  if polygon_offset {
    self.enable(GL_POLYGON_OFFSET_FILL)
    if self.current_polygon_offset_factor != factor ||
      self.current_polygon_offset_units != units {
      self.current_polygon_offset_factor = factor
      self.current_polygon_offset_units = units
      // `undefined` reads as NaN in arithmetic
      let mut factor = factor.unwrap_or(webgl_state_nan)
      let mut units = units.unwrap_or(webgl_state_nan)
      if self.buffers.depth.get_reversed() {
        factor = -factor
        units = -units
      }
      self.gl.polygon_offset(factor, units)
    }
  } else {
    self.disable(GL_POLYGON_OFFSET_FILL)
  }
}

///|
/// `state.setScissorTest( scissorTest )`.
pub fn WebGLState::set_scissor_test(
  self : WebGLState,
  scissor_test : Bool,
) -> Unit {
  if scissor_test {
    self.enable(GL_SCISSOR_TEST)
  } else {
    self.disable(GL_SCISSOR_TEST)
  }
}

///|
/// `state.activeTexture( webglSlot )`; omitted is the last unit.
pub fn WebGLState::active_texture(
  self : WebGLState,
  webgl_slot? : Int32,
) -> Unit {
  let webgl_slot = match webgl_slot {
    Some(slot) => slot
    None => GL_TEXTURE0 + self.max_textures - 1
  }
  if self.current_texture_slot != Some(webgl_slot) {
    self.gl.active_texture(webgl_slot)
    self.current_texture_slot = Some(webgl_slot)
  }
}

///|
/// Bound-texture records whose `texture` is `null` (bound with no texture) rather than
/// `undefined`; `BoundTexture.texture` is `None` for both.
let webgl_state_bound_null : WeakMap[BoundTexture, Bool] = WeakMap::new()

///|
/// `state.bindTexture( webglType, webglTexture, webglSlot )`.
pub fn WebGLState::bind_texture(
  self : WebGLState,
  webgl_type : Int32,
  webgl_texture : GLTexture?,
  webgl_slot? : Int32,
) -> Unit {
  let webgl_slot = match webgl_slot {
    Some(slot) => slot
    None =>
      match self.current_texture_slot {
        None => GL_TEXTURE0 + self.max_textures - 1
        Some(slot) => slot
      }
  }
  let bound_texture = match self.current_bound_textures.get(webgl_slot) {
    Some(bound) => bound
    None => {
      let bound = { type_: None, texture: None, }
      self.current_bound_textures[webgl_slot] = bound
      bound
    }
  }
  // A stored `None` is `undefined` unless `webgl_state_bound_null` marks it `null`.
  let same_texture = match (bound_texture.texture, webgl_texture) {
    (Some(a), Some(b)) => physical_equal(a, b)
    (None, None) => webgl_state_bound_null.get(bound_texture) == Some(true)
    _ => false
  }
  if bound_texture.type_ != Some(webgl_type) || !same_texture {
    if self.current_texture_slot != Some(webgl_slot) {
      self.gl.active_texture(webgl_slot)
      self.current_texture_slot = Some(webgl_slot)
    }
    let texture = match webgl_texture {
      Some(_) => webgl_texture
      None => self.empty_textures.get(webgl_type)
    }
    self.gl.bind_texture(webgl_type, texture)
    bound_texture.type_ = Some(webgl_type)
    bound_texture.texture = webgl_texture
    if webgl_texture is None {
      webgl_state_bound_null.set(bound_texture, true)
    } else {
      webgl_state_bound_null.delete(bound_texture)
    }
  }
}

///|
/// `state.unbindTexture()`.
pub fn WebGLState::unbind_texture(self : WebGLState) -> Unit {
  let bound_texture = match self.current_texture_slot {
    Some(slot) => self.current_bound_textures.get(slot)
    None => None
  }
  if bound_texture is Some(bound_texture) && bound_texture.type_ is Some(type_) {
    self.gl.bind_texture(type_, None)
    bound_texture.type_ = None
    bound_texture.texture = None
    webgl_state_bound_null.delete(bound_texture)
  }
}

///|
/// `try { ... } catch ( e ) { error( 'WebGLState:', e ) }`.
fn webgl_state_try(f : () -> Unit) -> Unit {
  if js_try(f) is Some(e) {
    @core.error("WebGLState: " + e)
  }
}

///|
/// `state.compressedTexImage2D( ... )`, logging GL exceptions.
pub fn[D : GLData] WebGLState::compressed_tex_image2d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  internalformat : Int32,
  width : Int32,
  height : Int32,
  border : Int32,
  data : D,
) -> Unit {
  let data = data.to_gl_data()
  webgl_state_try(fn() {
    self.gl.compressed_tex_image2d(
      target, level, internalformat, width, height, border, data,
    )
  })
}

///|
/// `state.compressedTexImage3D( ... )`.
pub fn[D : GLData] WebGLState::compressed_tex_image3d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  internalformat : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  border : Int32,
  data : D,
  src_offset : Int32,
  src_length_override : Int32,
) -> Unit {
  let data = data.to_gl_data()
  webgl_state_try(fn() {
    self.gl.compressed_tex_image3d(
      target, level, internalformat, width, height, depth, border, data, src_offset,
      src_length_override,
    )
  })
}

///|
/// `state.texSubImage2D( target, level, x, y, width, height, format, type, pixels )`.
pub fn[D : GLData] WebGLState::tex_sub_image2d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  xoffset : Int32,
  yoffset : Int32,
  width : Int32,
  height : Int32,
  format : Int32,
  type_ : Int32,
  pixels : D,
) -> Unit {
  let pixels = pixels.to_gl_data()
  webgl_state_try(fn() {
    self.gl.tex_sub_image2d(
      target, level, xoffset, yoffset, width, height, format, type_, pixels,
    )
  })
}

///|
/// `state.texSubImage2D( target, level, x, y, format, type, source )`.
pub fn WebGLState::tex_sub_image2d_source(
  self : WebGLState,
  target : Int32,
  level : Int32,
  xoffset : Int32,
  yoffset : Int32,
  format : Int32,
  type_ : Int32,
  source : @core.JsValue,
) -> Unit {
  webgl_state_try(fn() {
    self.gl.tex_sub_image2d_source(
      target, level, xoffset, yoffset, format, type_, source,
    )
  })
}

///|
/// `state.texSubImage3D( ... )`.
pub fn[D : GLData] WebGLState::tex_sub_image3d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  xoffset : Int32,
  yoffset : Int32,
  zoffset : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  format : Int32,
  type_ : Int32,
  pixels : D,
) -> Unit {
  let pixels = pixels.to_gl_data()
  webgl_state_try(fn() {
    self.gl.tex_sub_image3d(
      target, level, xoffset, yoffset, zoffset, width, height, depth, format, type_,
      pixels,
    )
  })
}

///|
/// `state.compressedTexSubImage2D( ... )`.
pub fn[D : GLData] WebGLState::compressed_tex_sub_image2d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  xoffset : Int32,
  yoffset : Int32,
  width : Int32,
  height : Int32,
  format : Int32,
  data : D,
) -> Unit {
  let data = data.to_gl_data()
  webgl_state_try(fn() {
    self.gl.compressed_tex_sub_image2d(
      target, level, xoffset, yoffset, width, height, format, data,
    )
  })
}

///|
/// `state.compressedTexSubImage3D( ... )`.
pub fn[D : GLData] WebGLState::compressed_tex_sub_image3d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  xoffset : Int32,
  yoffset : Int32,
  zoffset : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  format : Int32,
  data : D,
) -> Unit {
  let data = data.to_gl_data()
  webgl_state_try(fn() {
    self.gl.compressed_tex_sub_image3d(
      target, level, xoffset, yoffset, zoffset, width, height, depth, format, data,
    )
  })
}

///|
/// `state.texStorage2D( target, levels, internalformat, width, height )`.
pub fn WebGLState::tex_storage2d(
  self : WebGLState,
  target : Int32,
  levels : Int32,
  internalformat : Int32,
  width : Int32,
  height : Int32,
) -> Unit {
  webgl_state_try(fn() {
    self.gl.tex_storage2d(target, levels, internalformat, width, height)
  })
}

///|
/// `state.texStorage3D( target, levels, internalformat, width, height, depth )`.
pub fn WebGLState::tex_storage3d(
  self : WebGLState,
  target : Int32,
  levels : Int32,
  internalformat : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
) -> Unit {
  webgl_state_try(fn() {
    self.gl.tex_storage3d(target, levels, internalformat, width, height, depth)
  })
}

///|
/// `state.texImage2D( target, level, internalformat, width, height, border, format, type,
/// pixels )`.
pub fn[D : GLData] WebGLState::tex_image2d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  internalformat : Int32,
  width : Int32,
  height : Int32,
  border : Int32,
  format : Int32,
  type_ : Int32,
  pixels : D,
) -> Unit {
  let pixels = pixels.to_gl_data()
  webgl_state_try(fn() {
    self.gl.tex_image2d(
      target, level, internalformat, width, height, border, format, type_, pixels,
    )
  })
}

///|
/// `state.texImage2D( target, level, internalformat, format, type, source )`.
pub fn WebGLState::tex_image2d_source(
  self : WebGLState,
  target : Int32,
  level : Int32,
  internalformat : Int32,
  format : Int32,
  type_ : Int32,
  source : @core.JsValue,
) -> Unit {
  webgl_state_try(fn() {
    self.gl.tex_image2d_source(
      target, level, internalformat, format, type_, source,
    )
  })
}

///|
/// `state.texImage3D( ... )`.
pub fn[D : GLData] WebGLState::tex_image3d(
  self : WebGLState,
  target : Int32,
  level : Int32,
  internalformat : Int32,
  width : Int32,
  height : Int32,
  depth : Int32,
  border : Int32,
  format : Int32,
  type_ : Int32,
  pixels : D,
) -> Unit {
  let pixels = pixels.to_gl_data()
  webgl_state_try(fn() {
    self.gl.tex_image3d(
      target, level, internalformat, width, height, depth, border, format, type_,
      pixels,
    )
  })
}

///|
/// `state.pixelStorei( name, value )` for numeric values.
pub fn WebGLState::pixel_storei(
  self : WebGLState,
  name : Int32,
  value : Int32,
) -> Unit {
  let js_value = @core.JsValue::of(value)
  let changed = match self.parameters.get(name) {
    Some(current) => !current.strict_equal(js_value)
    None => true
  }
  if changed {
    self.gl.pixel_storei(name, value)
    self.parameters[name] = js_value
  }
}

///|
/// `state.pixelStorei( name, value )` for boolean values (`UNPACK_FLIP_Y_WEBGL`, ...).
pub fn WebGLState::pixel_storei_bool(
  self : WebGLState,
  name : Int32,
  value : Bool,
) -> Unit {
  let js_value = @core.JsValue::of(value)
  let changed = match self.parameters.get(name) {
    Some(current) => !current.strict_equal(js_value)
    None => true
  }
  if changed {
    self.gl.pixel_storei_bool(name, value)
    self.parameters[name] = js_value
  }
}

///|
/// `state.getParameter( name )`: the cached `pixelStorei` value, else `gl.getParameter`.
pub fn WebGLState::get_parameter(
  self : WebGLState,
  name : Int32,
) -> @core.JsValue {
  match self.parameters.get(name) {
    Some(value) => value
    None => self.gl.get_parameter(name)
  }
}

///|
/// `state.updateUBOMapping( uniformsGroup, program )`.
pub fn WebGLState::update_ubo_mapping(
  self : WebGLState,
  uniforms_group : @core.UniformsGroup,
  program : GLProgram,
) -> Unit {
  let mapping = match self.ubo_program_map.get(program) {
    Some(mapping) => mapping
    None => {
      let mapping : Map[Int32, Int32] = Map([])
      self.ubo_program_map.set(program, mapping)
      mapping
    }
  }
  if !mapping.contains(uniforms_group.id) {
    let block_index = self.gl.get_uniform_block_index(
      program,
      uniforms_group.name,
    )

    // use the block index as the binding point
    self.gl.uniform_block_binding(program, block_index, block_index)
    mapping[uniforms_group.id] = block_index
  }
}

///|
/// `state.uniformBlockBinding( uniformsGroup, program, buffer )`.
pub fn WebGLState::uniform_block_binding(
  self : WebGLState,
  uniforms_group : @core.UniformsGroup,
  program : GLProgram,
  buffer : GLBuffer?,
) -> Unit {
  let mapping = self.ubo_program_map.get(program).unwrap()
  let block_index = mapping.get(uniforms_group.id).unwrap()
  let changed = match self.ubo_bindings.get(block_index) {
    None => true // undefined !== buffer
    Some(current) => !same_handle(current, buffer)
  }
  if changed {
    self.gl.bind_buffer_base(GL_UNIFORM_BUFFER, block_index, buffer)
    self.ubo_bindings[block_index] = buffer
  }
}

///|
/// `state.scissor( scissor )`.
pub fn WebGLState::scissor(self : WebGLState, scissor : @math.Vector4) -> Unit {
  if !self.current_scissor.equals(scissor) {
    self.gl.scissor(scissor.x, scissor.y, scissor.z, scissor.w)
    ignore(self.current_scissor.copy(scissor))
  }
}

///|
/// `state.viewport( viewport )`.
pub fn WebGLState::viewport(
  self : WebGLState,
  viewport : @math.Vector4,
) -> Unit {
  if !self.current_viewport.equals(viewport) {
    self.gl.viewport(viewport.x, viewport.y, viewport.z, viewport.w)
    ignore(self.current_viewport.copy(viewport))
  }
}

///|
/// `state.reset()`.
pub fn WebGLState::reset(self : WebGLState) -> Unit {
  let gl = self.gl

  // reset state

  gl.disable(GL_BLEND)
  gl.disable(GL_CULL_FACE)
  gl.disable(GL_DEPTH_TEST)
  gl.disable(GL_POLYGON_OFFSET_FILL)
  gl.disable(GL_SCISSOR_TEST)
  gl.disable(GL_STENCIL_TEST)
  gl.disable(GL_SAMPLE_ALPHA_TO_COVERAGE)
  gl.blend_equation(GL_FUNC_ADD)
  gl.blend_func(GL_ONE, GL_ZERO)
  gl.blend_func_separate(GL_ONE, GL_ZERO, GL_ONE, GL_ZERO)
  gl.blend_color(0.0, 0.0, 0.0, 0.0)
  gl.color_mask(true, true, true, true)
  gl.clear_color(0.0, 0.0, 0.0, 0.0)
  gl.depth_mask(true)
  gl.depth_func(GL_LESS)
  self.buffers.depth.set_reversed(false)
  gl.clear_depth(1.0)
  gl.stencil_mask(-1)
  gl.stencil_func(GL_ALWAYS, 0, -1)
  gl.stencil_op(GL_KEEP, GL_KEEP, GL_KEEP)
  gl.clear_stencil(0)
  gl.cull_face(GL_BACK)
  gl.front_face(GL_CCW)
  gl.polygon_offset(0.0, 0.0)
  gl.active_texture(GL_TEXTURE0)
  gl.bind_framebuffer(GL_FRAMEBUFFER, None)
  gl.bind_framebuffer(GL_DRAW_FRAMEBUFFER, None)
  gl.bind_framebuffer(GL_READ_FRAMEBUFFER, None)
  gl.use_program(None)
  gl.line_width(1.0)
  let width = gl.canvas().width().to_double()
  let height = gl.canvas().height().to_double()
  gl.scissor(0.0, 0.0, width, height)
  gl.viewport(0.0, 0.0, width, height)
  gl.pixel_storei(GL_PACK_ALIGNMENT, 4)
  gl.pixel_storei(GL_UNPACK_ALIGNMENT, 4)
  gl.pixel_storei_bool(GL_UNPACK_FLIP_Y_WEBGL, false)
  gl.pixel_storei_bool(GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL, false)
  gl.pixel_storei(
    GL_UNPACK_COLORSPACE_CONVERSION_WEBGL,
    GL_BROWSER_DEFAULT_WEBGL,
  )
  gl.pixel_storei(GL_PACK_ROW_LENGTH, 0)
  gl.pixel_storei(GL_PACK_SKIP_PIXELS, 0)
  gl.pixel_storei(GL_PACK_SKIP_ROWS, 0)
  gl.pixel_storei(GL_UNPACK_ROW_LENGTH, 0)
  gl.pixel_storei(GL_UNPACK_IMAGE_HEIGHT, 0)
  gl.pixel_storei(GL_UNPACK_SKIP_PIXELS, 0)
  gl.pixel_storei(GL_UNPACK_SKIP_ROWS, 0)
  gl.pixel_storei(GL_UNPACK_SKIP_IMAGES, 0)

  // reset internals

  self.enabled_capabilities = {}
  self.parameters = {}
  self.current_texture_slot = None
  self.current_bound_textures = {}
  self.current_bound_framebuffers = {}
  self.ubo_bindings = {}
  self.current_drawbuffers = WeakMap::new()
  self.default_drawbuffers = []
  self.current_program = None
  self.current_blending_enabled = false
  self.current_blending = None
  self.current_blend_equation = None
  self.current_blend_src = None
  self.current_blend_dst = None
  self.current_blend_equation_alpha = None
  self.current_blend_src_alpha = None
  self.current_blend_dst_alpha = None
  self.current_blend_color = @math.Color::new(0.0, 0.0, 0.0)
  self.current_blend_alpha = 0.0
  self.set_current_premultiplied(Some(false))
  self.current_flip_sided = None
  self.current_cull_face = None
  self.current_line_width = None
  self.current_polygon_offset_factor = None
  self.current_polygon_offset_units = None
  ignore(self.current_scissor.set(0.0, 0.0, width, height))
  ignore(self.current_viewport.set(0.0, 0.0, width, height))
  self.buffers.color.reset()
  self.buffers.depth.reset()
  self.buffers.stencil.reset()
}
