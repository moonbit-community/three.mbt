// renderers/webgl-fallback/utils/WebGLState.js: caches the WebGL state so the backend
// only issues state changes when a value differs.

///|
/// `equationToGL[ equation ]` (set up by `_init`; `undefined` for other values, sent to
/// GL as 0).
fn _web_gl_state_equation_to_gl(equation : Int32) -> Int32 {
  match equation {
    @core.AddEquation => @webgl.GL_FUNC_ADD
    @core.SubtractEquation => @webgl.GL_FUNC_SUBTRACT
    @core.ReverseSubtractEquation => @webgl.GL_FUNC_REVERSE_SUBTRACT
    @core.MinEquation => @webgl.GL_MIN
    @core.MaxEquation => @webgl.GL_MAX
    _ => 0
  }
}

///|
/// `factorToGL[ factor ]`.
fn _web_gl_state_factor_to_gl(factor : Int32) -> Int32 {
  match factor {
    @core.ZeroFactor => @webgl.GL_ZERO
    @core.OneFactor => @webgl.GL_ONE
    @core.SrcColorFactor => @webgl.GL_SRC_COLOR
    @core.SrcAlphaFactor => @webgl.GL_SRC_ALPHA
    @core.SrcAlphaSaturateFactor => @webgl.GL_SRC_ALPHA_SATURATE
    @core.DstColorFactor => @webgl.GL_DST_COLOR
    @core.DstAlphaFactor => @webgl.GL_DST_ALPHA
    @core.OneMinusSrcColorFactor => @webgl.GL_ONE_MINUS_SRC_COLOR
    @core.OneMinusSrcAlphaFactor => @webgl.GL_ONE_MINUS_SRC_ALPHA
    @core.OneMinusDstColorFactor => @webgl.GL_ONE_MINUS_DST_COLOR
    @core.OneMinusDstAlphaFactor => @webgl.GL_ONE_MINUS_DST_ALPHA
    @core.ConstantColorFactor => @webgl.GL_CONSTANT_COLOR
    @core.OneMinusConstantColorFactor => @webgl.GL_ONE_MINUS_CONSTANT_COLOR
    @core.ConstantAlphaFactor => @webgl.GL_CONSTANT_ALPHA
    @core.OneMinusConstantAlphaFactor => @webgl.GL_ONE_MINUS_CONSTANT_ALPHA
    _ => 0
  }
}

///|
/// `ReversedDepthFuncs[ depthFunc ]` (utils.js); `None` is `undefined`.
fn _web_gl_state_reversed_depth_func(depth_func : Int32) -> Int32? {
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
/// `drawBuffersIndexedExt.blendFuncSeparateiOES( ... )` (OES_draw_buffers_indexed).
extern "js" fn _web_gl_state_blend_func_separatei_oes(
  ext : @webgl.GLExtension,
  buf : Int32,
  src_rgb : Int32,
  dst_rgb : Int32,
  src_alpha : Int32,
  dst_alpha : Int32,
) -> Unit = "(e, a0, a1, a2, a3, a4) => e.blendFuncSeparateiOES(a0, a1, a2, a3, a4)"

///|
/// `drawBuffersIndexedExt.blendEquationSeparateiOES( ... )`.
extern "js" fn _web_gl_state_blend_equation_separatei_oes(
  ext : @webgl.GLExtension,
  buf : Int32,
  mode_rgb : Int32,
  mode_alpha : Int32,
) -> Unit = "(e, a0, a1, a2) => e.blendEquationSeparateiOES(a0, a1, a2)"

///|
/// A `currentBoundTextures[ slot ]` entry: `{ type, texture }`; `None` is `undefined`
/// (and `Some(None)` a `null` texture).
priv struct WebGLStateBoundTexture {
  mut type_ : Int32?
  mut texture : @webgl.GLTexture??
}

///|
/// The `blending` argument of `_setMRTBlendingIndex`: a material or an MRT blend mode.
priv enum WebGLStateBlending {
  Material(@core.Material)
  Mode(@nodes.BlendMode)
}

///|
pub(all) struct WebGLState {
  backend : WebGLBackend
  gl : @webgl.WebGL2RenderingContext
  /// `enabled[ id ]`.
  mut enabled : Map[Int32, Bool]
  /// `parameters[ name ]` (pixelStorei values).
  mut parameters : Map[Int32, @core.JsValue]
  mut current_flip_sided : Bool?
  mut current_cull_face : Int32?
  mut current_program : @webgl.GLProgram?
  mut current_blending_enabled : Bool
  mut current_blending : Int32?
  mut current_blend_equation : Int32?
  mut current_blend_equation_alpha : Int32?
  mut current_blend_src : Int32?
  mut current_blend_dst : Int32?
  mut current_blend_src_alpha : Int32?
  mut current_blend_dst_alpha : Int32?
  current_blend_color : @math.Color
  mut current_blend_alpha : Double
  mut current_premultipled_alpha : Bool?
  mut current_polygon_offset_factor : Double?
  mut current_polygon_offset_units : Double?
  mut current_color_mask : Bool?
  mut current_depth_reversed : Bool
  /// `currentDepthFunc`: `None` is `null`, `Some(None)` `undefined`.
  mut current_depth_func : Int32??
  mut current_depth_mask : Bool?
  mut current_stencil_func : Int32?
  mut current_stencil_ref : Int32?
  mut current_stencil_func_mask : Int32?
  mut current_stencil_fail : Int32?
  mut current_stencil_z_fail : Int32?
  mut current_stencil_z_pass : Int32?
  mut current_stencil_mask : Int32?
  mut current_line_width : Double?
  mut current_clipping_planes : Int32
  mut current_vao : @webgl.GLVertexArrayObject?
  mut current_index : @webgl.GLBuffer?
  /// `currentBoundFramebuffers[ target ]` (a missing key is `undefined`).
  mut current_bound_framebuffers : Map[Int32, @webgl.GLFramebuffer?]
  mut current_drawbuffers : @webgl.WeakMap[@webgl.GLFramebuffer, Array[Int32]]
  max_textures : Int32
  mut current_texture_slot : Int32?
  priv mut current_bound_textures : Map[Int32, WebGLStateBoundTexture]
  /// `currentBoundBufferBases[ `${ target }-${ index }` ]`.
  mut current_bound_buffer_bases : Map[String, @webgl.GLBuffer?]
  current_scissor : @math.Vector4
  current_viewport : @math.Vector4
  _temp_vec4 : @math.Vector4
}

///|
/// `new WebGLState( backend )`.
pub fn WebGLState::new(backend : WebGLBackend) -> WebGLState {
  let gl = backend.gl.unwrap()
  let max_textures = gl.get_parameter_int(@webgl.GL_MAX_TEXTURE_IMAGE_UNITS)
  let state : WebGLState = {
    backend,
    gl,
    enabled: Map([]),
    parameters: Map([]),
    current_flip_sided: None,
    current_cull_face: None,
    current_program: None,
    current_blending_enabled: false,
    current_blending: None,
    current_blend_equation: None,
    current_blend_equation_alpha: None,
    current_blend_src: None,
    current_blend_dst: None,
    current_blend_src_alpha: None,
    current_blend_dst_alpha: None,
    current_blend_color: @math.Color::new(0.0, 0.0, 0.0),
    current_blend_alpha: 0.0,
    current_premultipled_alpha: None,
    current_polygon_offset_factor: None,
    current_polygon_offset_units: None,
    current_color_mask: None,
    current_depth_reversed: false,
    current_depth_func: None,
    current_depth_mask: None,
    current_stencil_func: None,
    current_stencil_ref: None,
    current_stencil_func_mask: None,
    current_stencil_fail: None,
    current_stencil_z_fail: None,
    current_stencil_z_pass: None,
    current_stencil_mask: None,
    current_line_width: None,
    current_clipping_planes: 0,
    current_vao: None,
    current_index: None,
    current_bound_framebuffers: Map([]),
    current_drawbuffers: @webgl.WeakMap::new(),
    max_textures,
    current_texture_slot: None,
    current_bound_textures: Map([]),
    current_bound_buffer_bases: Map([]),
    current_scissor: @math.Vector4::new(0.0, 0.0, 0.0, 0.0),
    current_viewport: @math.Vector4::new(0.0, 0.0, 0.0, 0.0),
    _temp_vec4: @math.Vector4::new(0.0, 0.0, 0.0, 0.0),
  }
  state._init()
  state
}

///|
/// `_init()`: reads the initial scissor and viewport.
fn WebGLState::_init(self : WebGLState) -> Unit {
  let gl = self.gl
  let scissor_param = gl.get_parameter_array(@webgl.GL_SCISSOR_BOX)
  let viewport_param = gl.get_parameter_array(@webgl.GL_VIEWPORT)
  self.current_scissor.from_array(scissor_param) |> ignore
  self.current_viewport.from_array(viewport_param) |> ignore
}

///|
/// `enable( id )`.
pub fn WebGLState::enable(self : WebGLState, id : Int32) -> Unit {
  if self.enabled.get(id) != Some(true) {
    self.gl.enable(id)
    self.enabled.set(id, true)
  }
}

///|
/// `disable( id )`.
pub fn WebGLState::disable(self : WebGLState, id : Int32) -> Unit {
  if self.enabled.get(id) != Some(false) {
    self.gl.disable(id)
    self.enabled.set(id, false)
  }
}

///|
/// `setFlipSided( flipSided )`.
pub fn WebGLState::set_flip_sided(self : WebGLState, flip_sided : Bool) -> Unit {
  if self.current_flip_sided != Some(flip_sided) {
    let gl = self.gl
    if flip_sided {
      gl.front_face(@webgl.GL_CW)
    } else {
      gl.front_face(@webgl.GL_CCW)
    }
    self.current_flip_sided = Some(flip_sided)
  }
}

///|
/// `setCullFace( cullFace )`.
pub fn WebGLState::set_cull_face(self : WebGLState, cull_face : Int32) -> Unit {
  let gl = self.gl
  if cull_face != @core.CullFaceNone {
    self.enable(@webgl.GL_CULL_FACE)
    if Some(cull_face) != self.current_cull_face {
      if cull_face == @core.CullFaceBack {
        gl.cull_face(@webgl.GL_BACK)
      } else if cull_face == @core.CullFaceFront {
        gl.cull_face(@webgl.GL_FRONT)
      } else {
        gl.cull_face(@webgl.GL_FRONT_AND_BACK)
      }
    }
  } else {
    self.disable(@webgl.GL_CULL_FACE)
  }
  self.current_cull_face = Some(cull_face)
}

///|
/// `setLineWidth( width )`.
pub fn WebGLState::set_line_width(self : WebGLState, width : Double) -> Unit {
  if Some(width) != self.current_line_width {
    self.gl.line_width(width)
    self.current_line_width = Some(width)
  }
}

///|
/// `setMRTBlending( textures, mrt, material )`: per-attachment blending (needs
/// `OES_draw_buffers_indexed`). `mrt` is the `MRTNode` (`None` is `null`).
pub fn WebGLState::set_mrt_blending(
  self : WebGLState,
  textures : Array[@core.Texture],
  mrt : @nodes.Node?,
  material : @core.Material,
) -> Unit {
  let draw_buffers_indexed_ext = match self.backend.draw_buffers_indexed_ext {
    Some(ext) => ext
    None => {
      @core.warn_once(
        "WebGPURenderer: Multiple Render Targets (MRT) blending configuration is not fully supported in compatibility mode. The material blending will be used for all render targets.",
      )
      return
    }
  }
  for i, texture in textures {
    let mut blending : WebGLStateBlending? = None
    match mrt {
      Some(mrt) => {
        let mrt_node = match @nodes.MRTNode::of(mrt) {
          Some(m) => m
          None => abort("TypeError: mrt.getBlendMode is not a function")
        }
        let blend_mode = mrt_node.get_blend_mode(texture.name)
        if blend_mode.blending == @core.MaterialBlending {
          // use material blending
          blending = Some(Material(material))
        } else if blend_mode.blending != @core.NoBlending {
          blending = Some(Mode(blend_mode))
        }
      }
      // use material blending
      None => blending = Some(Material(material))
    }
    match blending {
      Some(blending) => self._set_mrt_blending_index(i, blending)
      // use opaque blending (no blending)
      None =>
        _web_gl_state_blend_func_separatei_oes(
          draw_buffers_indexed_ext,
          i,
          @webgl.GL_ONE,
          @webgl.GL_ZERO,
          @webgl.GL_ONE,
          @webgl.GL_ZERO,
        )
    }
  }
  // invalidate cache
  self.current_blending = None
  self.current_blend_equation = None
  self.current_blend_equation_alpha = None
  self.current_blend_src = None
  self.current_blend_dst = None
  self.current_blend_src_alpha = None
  self.current_blend_dst_alpha = None
  self.current_premultipled_alpha = None
}

///|
/// `_setMRTBlendingIndex( index, blending )`.
fn WebGLState::_set_mrt_blending_index(
  self : WebGLState,
  index : Int32,
  blending : WebGLStateBlending,
) -> Unit {
  let ext = self.backend.draw_buffers_indexed_ext.unwrap()
  // `blending.premultipliedAlpha` is `undefined` on a BlendMode (it has
  // `premultiplyAlpha`).
  let (
    blending_type,
    blend_src,
    blend_dst,
    blend_equation,
    blend_src_alpha_opt,
    blend_dst_alpha_opt,
    blend_equation_alpha_opt,
    premultiplied_alpha,
  ) = match blending {
    Material(m) =>
      (
        m.blending,
        m.blend_src,
        m.blend_dst,
        m.blend_equation,
        m.blend_src_alpha,
        m.blend_dst_alpha,
        m.blend_equation_alpha,
        m.premultiplied_alpha,
      )
    Mode(b) =>
      (
        b.blending,
        b.blend_src,
        b.blend_dst,
        b.blend_equation,
        b.blend_src_alpha,
        b.blend_dst_alpha,
        b.blend_equation_alpha,
        false,
      )
  }
  let fs = fn(a, b, c, d) {
    _web_gl_state_blend_func_separatei_oes(ext, index, a, b, c, d)
  }
  if blending_type == @core.CustomBlending {
    let blend_src_alpha = blend_src_alpha_opt.unwrap_or(blend_src)
    let blend_dst_alpha = blend_dst_alpha_opt.unwrap_or(blend_dst)
    let blend_equation_alpha = blend_equation_alpha_opt.unwrap_or(
      blend_equation,
    )
    _web_gl_state_blend_equation_separatei_oes(
      ext,
      index,
      _web_gl_state_equation_to_gl(blend_equation),
      _web_gl_state_equation_to_gl(blend_equation_alpha),
    )
    fs(
      _web_gl_state_factor_to_gl(blend_src),
      _web_gl_state_factor_to_gl(blend_dst),
      _web_gl_state_factor_to_gl(blend_src_alpha),
      _web_gl_state_factor_to_gl(blend_dst_alpha),
    )
  } else {
    _web_gl_state_blend_equation_separatei_oes(
      ext,
      index,
      @webgl.GL_FUNC_ADD,
      @webgl.GL_FUNC_ADD,
    )
    if premultiplied_alpha {
      match blending_type {
        @core.NormalBlending =>
          fs(
            @webgl.GL_ONE,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
            @webgl.GL_ONE,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
          )
        @core.AdditiveBlending =>
          fs(@webgl.GL_ONE, @webgl.GL_ONE, @webgl.GL_ONE, @webgl.GL_ONE)
        @core.SubtractiveBlending =>
          fs(
            @webgl.GL_ZERO,
            @webgl.GL_ONE_MINUS_SRC_COLOR,
            @webgl.GL_ZERO,
            @webgl.GL_ONE,
          )
        @core.MultiplyBlending =>
          fs(
            @webgl.GL_DST_COLOR,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
            @webgl.GL_ZERO,
            @webgl.GL_ONE,
          )
        _ =>
          fs(
            @webgl.GL_ONE,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
            @webgl.GL_ONE,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
          )
      }
    } else {
      match blending_type {
        @core.NormalBlending =>
          fs(
            @webgl.GL_SRC_ALPHA,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
            @webgl.GL_ONE,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
          )
        @core.AdditiveBlending =>
          fs(@webgl.GL_SRC_ALPHA, @webgl.GL_ONE, @webgl.GL_ONE, @webgl.GL_ONE)
        @core.SubtractiveBlending =>
          fs(
            @webgl.GL_ZERO,
            @webgl.GL_ONE_MINUS_SRC_COLOR,
            @webgl.GL_ZERO,
            @webgl.GL_ONE,
          )
        @core.MultiplyBlending =>
          fs(
            @webgl.GL_DST_COLOR,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
            @webgl.GL_ZERO,
            @webgl.GL_ONE,
          )
        _ =>
          fs(
            @webgl.GL_SRC_ALPHA,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
            @webgl.GL_ONE,
            @webgl.GL_ONE_MINUS_SRC_ALPHA,
          )
      }
    }
  }
}

///|
/// `setBlending( blending, blendEquation, blendSrc, blendDst, blendEquationAlpha,
/// blendSrcAlpha, blendDstAlpha, blendColor, blendAlpha, premultipliedAlpha )`; only
/// `blending` is needed for `NoBlending`.
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
    if self.current_blending_enabled == true {
      self.disable(@webgl.GL_BLEND)
      self.current_blending_enabled = false
    }
    return
  }
  if self.current_blending_enabled == false {
    self.enable(@webgl.GL_BLEND)
    self.current_blending_enabled = true
  }
  if blending != @core.CustomBlending {
    if Some(blending) != self.current_blending ||
      premultiplied_alpha != self.current_premultipled_alpha {
      if self.current_blend_equation != Some(@core.AddEquation) ||
        self.current_blend_equation_alpha != Some(@core.AddEquation) {
        gl.blend_equation(@webgl.GL_FUNC_ADD)
        self.current_blend_equation = Some(@core.AddEquation)
        self.current_blend_equation_alpha = Some(@core.AddEquation)
      }
      if premultiplied_alpha == Some(true) {
        match blending {
          @core.NormalBlending =>
            gl.blend_func_separate(
              @webgl.GL_ONE,
              @webgl.GL_ONE_MINUS_SRC_ALPHA,
              @webgl.GL_ONE,
              @webgl.GL_ONE_MINUS_SRC_ALPHA,
            )
          @core.AdditiveBlending => gl.blend_func(@webgl.GL_ONE, @webgl.GL_ONE)
          @core.SubtractiveBlending =>
            gl.blend_func_separate(
              @webgl.GL_ZERO,
              @webgl.GL_ONE_MINUS_SRC_COLOR,
              @webgl.GL_ZERO,
              @webgl.GL_ONE,
            )
          @core.MultiplyBlending =>
            gl.blend_func_separate(
              @webgl.GL_DST_COLOR,
              @webgl.GL_ONE_MINUS_SRC_ALPHA,
              @webgl.GL_ZERO,
              @webgl.GL_ONE,
            )
          _ => @core.error("WebGLState: Invalid blending: \{blending}")
        }
      } else {
        match blending {
          @core.NormalBlending =>
            gl.blend_func_separate(
              @webgl.GL_SRC_ALPHA,
              @webgl.GL_ONE_MINUS_SRC_ALPHA,
              @webgl.GL_ONE,
              @webgl.GL_ONE_MINUS_SRC_ALPHA,
            )
          @core.AdditiveBlending =>
            gl.blend_func_separate(
              @webgl.GL_SRC_ALPHA,
              @webgl.GL_ONE,
              @webgl.GL_ONE,
              @webgl.GL_ONE,
            )
          @core.SubtractiveBlending =>
            @core.error(
              "WebGLState: SubtractiveBlending requires material.premultipliedAlpha = true",
            )
          @core.MultiplyBlending =>
            @core.error(
              "WebGLState: MultiplyBlending requires material.premultipliedAlpha = true",
            )
          _ => @core.error("WebGLState: Invalid blending: \{blending}")
        }
      }
      self.current_blend_src = None
      self.current_blend_dst = None
      self.current_blend_src_alpha = None
      self.current_blend_dst_alpha = None
      self.current_blending = Some(blending)
      self.current_premultipled_alpha = premultiplied_alpha
    }
    return
  }
  // custom blending
  let blend_equation_alpha = match blend_equation_alpha {
    Some(e) => Some(e)
    None => blend_equation
  }
  let blend_src_alpha = match blend_src_alpha {
    Some(e) => Some(e)
    None => blend_src
  }
  let blend_dst_alpha = match blend_dst_alpha {
    Some(e) => Some(e)
    None => blend_dst
  }
  let to_eq = fn(e : Int32?) {
    match e {
      Some(e) => _web_gl_state_equation_to_gl(e)
      None => 0
    }
  }
  let to_factor = fn(f : Int32?) {
    match f {
      Some(f) => _web_gl_state_factor_to_gl(f)
      None => 0
    }
  }
  if blend_equation != self.current_blend_equation ||
    blend_equation_alpha != self.current_blend_equation_alpha {
    gl.blend_equation_separate(
      to_eq(blend_equation),
      to_eq(blend_equation_alpha),
    )
    self.current_blend_equation = blend_equation
    self.current_blend_equation_alpha = blend_equation_alpha
  }
  if blend_src != self.current_blend_src ||
    blend_dst != self.current_blend_dst ||
    blend_src_alpha != self.current_blend_src_alpha ||
    blend_dst_alpha != self.current_blend_dst_alpha {
    gl.blend_func_separate(
      to_factor(blend_src),
      to_factor(blend_dst),
      to_factor(blend_src_alpha),
      to_factor(blend_dst_alpha),
    )
    self.current_blend_src = blend_src
    self.current_blend_dst = blend_dst
    self.current_blend_src_alpha = blend_src_alpha
    self.current_blend_dst_alpha = blend_dst_alpha
  }
  let blend_color = match blend_color {
    Some(c) => c
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'equals')")
  }
  let blend_alpha = blend_alpha.unwrap_or(0.0)
  if blend_color.equals(self.current_blend_color) == false ||
    blend_alpha != self.current_blend_alpha {
    gl.blend_color(blend_color.r, blend_color.g, blend_color.b, blend_alpha)
    self.current_blend_color.copy(blend_color) |> ignore
    self.current_blend_alpha = blend_alpha
  }
  self.current_blending = Some(blending)
  self.current_premultipled_alpha = Some(false)
}

///|
/// `setColorMask( colorMask )`.
pub fn WebGLState::set_color_mask(self : WebGLState, color_mask : Bool) -> Unit {
  if self.current_color_mask != Some(color_mask) {
    self.gl.color_mask(color_mask, color_mask, color_mask, color_mask)
    self.current_color_mask = Some(color_mask)
  }
}

///|
/// `setDepthTest( depthTest )`.
pub fn WebGLState::set_depth_test(self : WebGLState, depth_test : Bool) -> Unit {
  if depth_test {
    self.enable(@webgl.GL_DEPTH_TEST)
  } else {
    self.disable(@webgl.GL_DEPTH_TEST)
  }
}

///|
/// `setReversedDepth( reversed )`: switches the clip control (EXT_clip_control).
pub fn WebGLState::set_reversed_depth(
  self : WebGLState,
  reversed : Bool,
) -> Unit {
  if self.current_depth_reversed != reversed {
    let ext = match self.backend.extensions.unwrap().get("EXT_clip_control") {
      Some(e) => e
      None =>
        abort(
          "TypeError: Cannot read properties of null (reading 'clipControlEXT')",
        )
    }
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
    self.current_depth_reversed = reversed
  }
}

///|
/// `setDepthMask( depthMask )`.
pub fn WebGLState::set_depth_mask(self : WebGLState, depth_mask : Bool) -> Unit {
  if self.current_depth_mask != Some(depth_mask) {
    self.gl.depth_mask(depth_mask)
    self.current_depth_mask = Some(depth_mask)
  }
}

///|
/// `setDepthFunc( depthFunc )`.
pub fn WebGLState::set_depth_func(
  self : WebGLState,
  depth_func : Int32,
) -> Unit {
  let depth_func = if self.current_depth_reversed {
    _web_gl_state_reversed_depth_func(depth_func)
  } else {
    Some(depth_func)
  }
  if self.current_depth_func != Some(depth_func) {
    let gl = self.gl
    match depth_func {
      Some(@core.NeverDepth) => gl.depth_func(@webgl.GL_NEVER)
      Some(@core.AlwaysDepth) => gl.depth_func(@webgl.GL_ALWAYS)
      Some(@core.LessDepth) => gl.depth_func(@webgl.GL_LESS)
      Some(@core.LessEqualDepth) => gl.depth_func(@webgl.GL_LEQUAL)
      Some(@core.EqualDepth) => gl.depth_func(@webgl.GL_EQUAL)
      Some(@core.GreaterEqualDepth) => gl.depth_func(@webgl.GL_GEQUAL)
      Some(@core.GreaterDepth) => gl.depth_func(@webgl.GL_GREATER)
      Some(@core.NotEqualDepth) => gl.depth_func(@webgl.GL_NOTEQUAL)
      _ => gl.depth_func(@webgl.GL_LEQUAL)
    }
    self.current_depth_func = Some(depth_func)
  }
}

///|
/// `scissor( x, y, width, height )`.
pub fn WebGLState::scissor(
  self : WebGLState,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  let scissor = self._temp_vec4.set(x, y, width, height)
  if self.current_scissor.equals(scissor) == false {
    self.gl.scissor(scissor.x, scissor.y, scissor.z, scissor.w)
    self.current_scissor.copy(scissor) |> ignore
  }
}

///|
/// `viewport( x, y, width, height )`.
pub fn WebGLState::viewport(
  self : WebGLState,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  let viewport = self._temp_vec4.set(x, y, width, height)
  if self.current_viewport.equals(viewport) == false {
    self.gl.viewport(viewport.x, viewport.y, viewport.z, viewport.w)
    self.current_viewport.copy(viewport) |> ignore
  }
}

///|
/// `setScissorTest( boolean )`.
pub fn WebGLState::set_scissor_test(self : WebGLState, boolean : Bool) -> Unit {
  if boolean {
    self.enable(@webgl.GL_SCISSOR_TEST)
  } else {
    self.disable(@webgl.GL_SCISSOR_TEST)
  }
}

///|
/// `setStencilTest( stencilTest )`.
pub fn WebGLState::set_stencil_test(
  self : WebGLState,
  stencil_test : Bool,
) -> Unit {
  if stencil_test {
    self.enable(@webgl.GL_STENCIL_TEST)
  } else {
    self.disable(@webgl.GL_STENCIL_TEST)
  }
}

///|
/// `setStencilMask( stencilMask )`.
pub fn WebGLState::set_stencil_mask(
  self : WebGLState,
  stencil_mask : Int32,
) -> Unit {
  if self.current_stencil_mask != Some(stencil_mask) {
    self.gl.stencil_mask(stencil_mask)
    self.current_stencil_mask = Some(stencil_mask)
  }
}

///|
/// `setStencilFunc( stencilFunc, stencilRef, stencilMask )`.
pub fn WebGLState::set_stencil_func(
  self : WebGLState,
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
/// `setStencilOp( stencilFail, stencilZFail, stencilZPass )`.
pub fn WebGLState::set_stencil_op(
  self : WebGLState,
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
/// `setMaterial( material, frontFaceCW, hardwareClippingPlanes )`.
pub fn WebGLState::set_material(
  self : WebGLState,
  material : @core.Material,
  front_face_cw : Bool,
  hardware_clipping_planes : Int32,
) -> Unit {
  if material.side == @core.DoubleSide {
    self.disable(@webgl.GL_CULL_FACE)
  } else {
    self.enable(@webgl.GL_CULL_FACE)
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
  self.set_depth_func(material.depth_func)
  self.set_depth_test(material.depth_test)
  self.set_depth_mask(material.depth_write)
  self.set_color_mask(material.color_write)
  let stencil_write = material.stencil_write
  self.set_stencil_test(stencil_write)
  if stencil_write {
    self.set_stencil_mask(material.stencil_write_mask)
    self.set_stencil_func(
      material.stencil_func,
      material.stencil_ref,
      material.stencil_func_mask,
    )
    self.set_stencil_op(
      material.stencil_fail,
      material.stencil_z_fail,
      material.stencil_z_pass,
    )
  }
  self.set_polygon_offset(
    material.polygon_offset,
    material.polygon_offset_factor,
    material.polygon_offset_units,
  )
  if material.alpha_to_coverage == true &&
    self.backend.renderer().current_samples() > 0 {
    self.enable(@webgl.GL_SAMPLE_ALPHA_TO_COVERAGE)
  } else {
    self.disable(@webgl.GL_SAMPLE_ALPHA_TO_COVERAGE)
  }
  if self.current_clipping_planes != hardware_clipping_planes {
    let clip_distance0_webgl = 0x3000
    for i in 0..<8 {
      if i < hardware_clipping_planes {
        self.enable(clip_distance0_webgl + i)
      } else {
        self.disable(clip_distance0_webgl + i)
      }
    }
    self.current_clipping_planes = hardware_clipping_planes
  }
}

///|
/// `setPolygonOffset( polygonOffset, factor, units )`.
pub fn WebGLState::set_polygon_offset(
  self : WebGLState,
  polygon_offset : Bool,
  factor : Double,
  units : Double,
) -> Unit {
  if polygon_offset {
    self.enable(@webgl.GL_POLYGON_OFFSET_FILL)
    if self.current_polygon_offset_factor != Some(factor) ||
      self.current_polygon_offset_units != Some(units) {
      self.current_polygon_offset_factor = Some(factor)
      self.current_polygon_offset_units = Some(units)
      let (factor, units) = if self.current_depth_reversed {
        (-factor, -units)
      } else {
        (factor, units)
      }
      self.gl.polygon_offset(factor, units)
    }
  } else {
    self.disable(@webgl.GL_POLYGON_OFFSET_FILL)
  }
}

///|
/// `useProgram( program )`: whether the program changed.
pub fn WebGLState::use_program(
  self : WebGLState,
  program : @webgl.GLProgram?,
) -> Bool {
  if !@webgl.same_handle(self.current_program, program) {
    self.gl.use_program(program)
    self.current_program = program
    return true
  }
  false
}

///|
/// `setVertexState( vao, indexBuffer = null )`: whether the state changed.
pub fn WebGLState::set_vertex_state(
  self : WebGLState,
  vao : @webgl.GLVertexArrayObject?,
  index_buffer? : @webgl.GLBuffer,
) -> Bool {
  let gl = self.gl
  if !@webgl.same_handle(self.current_vao, vao) ||
    !@webgl.same_handle(self.current_index, index_buffer) {
    gl.bind_vertex_array(vao)
    if index_buffer is Some(_) {
      gl.bind_buffer(@webgl.GL_ELEMENT_ARRAY_BUFFER, index_buffer)
    }
    self.current_vao = vao
    self.current_index = index_buffer
    return true
  }
  false
}

///|
/// `resetVertexState()`.
pub fn WebGLState::reset_vertex_state(self : WebGLState) -> Unit {
  let gl = self.gl
  gl.bind_vertex_array(None)
  gl.bind_buffer(@webgl.GL_ELEMENT_ARRAY_BUFFER, None)
  self.current_vao = None
  self.current_index = None
}

///|
/// `bindFramebuffer( target, framebuffer )`: whether the binding changed.
pub fn WebGLState::bind_framebuffer(
  self : WebGLState,
  target : Int32,
  framebuffer : @webgl.GLFramebuffer?,
) -> Bool {
  let gl = self.gl
  let current_bound_framebuffers = self.current_bound_framebuffers
  let same = match current_bound_framebuffers.get(target) {
    Some(current) => @webgl.same_handle(current, framebuffer)
    None => false
  }
  if !same {
    gl.bind_framebuffer(target, framebuffer)
    current_bound_framebuffers.set(target, framebuffer)
    // gl.DRAW_FRAMEBUFFER is equivalent to gl.FRAMEBUFFER
    if target == @webgl.GL_DRAW_FRAMEBUFFER {
      current_bound_framebuffers.set(@webgl.GL_FRAMEBUFFER, framebuffer)
    }
    if target == @webgl.GL_FRAMEBUFFER {
      current_bound_framebuffers.set(@webgl.GL_DRAW_FRAMEBUFFER, framebuffer)
    }
    return true
  }
  false
}

///|
/// `renderContext.textures` of a `_setFramebuffer` descriptor: `None` is `null`.
fn _web_gl_state_descriptor_textures(
  descriptor : @nodes.FramebufferSource,
) -> Array[@core.Texture]? {
  match descriptor {
    Context(rc) => rc.textures
    TargetData(data) =>
      match data.textures {
        Some(t) => Some(t)
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'length')",
          )
      }
    NoContext =>
      abort("TypeError: Cannot read properties of null (reading 'textures')")
  }
}

///|
/// `drawBuffers( renderContext, framebuffer )`.
pub fn WebGLState::draw_buffers(
  self : WebGLState,
  render_context : @nodes.FramebufferSource,
  framebuffer : @webgl.GLFramebuffer?,
) -> Unit {
  let gl = self.gl
  let mut draw_buffers : Array[Int32] = []
  let mut needs_update = false
  match _web_gl_state_descriptor_textures(render_context) {
    Some(textures) => {
      let cached = match framebuffer {
        Some(fb) => self.current_drawbuffers.get(fb)
        None => None
      }
      draw_buffers = match cached {
        Some(d) => d
        None => {
          let d = [@webgl.GL_COLOR_ATTACHMENT0]
          match framebuffer {
            Some(fb) => self.current_drawbuffers.set(fb, d)
            None => abort("TypeError: Invalid value used as weak map key")
          }
          d
        }
      }
      if draw_buffers.length() != textures.length() {
        for i in 0..<textures.length() {
          if i < draw_buffers.length() {
            draw_buffers[i] = @webgl.GL_COLOR_ATTACHMENT0 + i
          } else {
            draw_buffers.push(@webgl.GL_COLOR_ATTACHMENT0 + i)
          }
        }
        while draw_buffers.length() > textures.length() {
          draw_buffers.pop() |> ignore
        }
        needs_update = true
      }
    }
    None =>
      if draw_buffers.length() == 0 || draw_buffers[0] != @webgl.GL_BACK {
        if draw_buffers.length() == 0 {
          draw_buffers.push(@webgl.GL_BACK)
        } else {
          draw_buffers[0] = @webgl.GL_BACK
        }
        needs_update = true
      }
  }
  if needs_update {
    gl.draw_buffers(draw_buffers)
  }
}

///|
/// `activeTexture( webglSlot )`; without a slot, the last unit.
pub fn WebGLState::active_texture(
  self : WebGLState,
  webgl_slot? : Int32,
) -> Unit {
  let webgl_slot = match webgl_slot {
    Some(s) => s
    None => @webgl.GL_TEXTURE0 + self.max_textures - 1
  }
  if self.current_texture_slot != Some(webgl_slot) {
    self.gl.active_texture(webgl_slot)
    self.current_texture_slot = Some(webgl_slot)
  }
}

///|
/// `bindTexture( webglType, webglTexture, webglSlot )`.
pub fn WebGLState::bind_texture(
  self : WebGLState,
  webgl_type : Int32,
  webgl_texture : @webgl.GLTexture?,
  webgl_slot? : Int32,
) -> Unit {
  let gl = self.gl
  let current_texture_slot = self.current_texture_slot
  let webgl_slot = match webgl_slot {
    Some(s) => s
    None =>
      match current_texture_slot {
        None => @webgl.GL_TEXTURE0 + self.max_textures - 1
        Some(s) => s
      }
  }
  let bound_texture = match self.current_bound_textures.get(webgl_slot) {
    Some(b) => b
    None => {
      let b = WebGLStateBoundTexture::{ type_: None, texture: None, }
      self.current_bound_textures.set(webgl_slot, b)
      b
    }
  }
  let same_texture = match bound_texture.texture {
    Some(t) => @webgl.same_handle(t, webgl_texture)
    None => false
  }
  if bound_texture.type_ != Some(webgl_type) || !same_texture {
    if current_texture_slot != Some(webgl_slot) {
      gl.active_texture(webgl_slot)
      self.current_texture_slot = Some(webgl_slot)
    }
    gl.bind_texture(webgl_type, webgl_texture)
    bound_texture.type_ = Some(webgl_type)
    bound_texture.texture = Some(webgl_texture)
  }
}

///|
/// `bindBufferBase( target, index, buffer )`: whether the binding changed.
pub fn WebGLState::bind_buffer_base(
  self : WebGLState,
  target : Int32,
  index : Int32,
  buffer : @webgl.GLBuffer?,
) -> Bool {
  let key = "\{target}-\{index}"
  let same = match self.current_bound_buffer_bases.get(key) {
    Some(current) => @webgl.same_handle(current, buffer)
    None => false
  }
  if !same {
    self.gl.bind_buffer_base(target, index, buffer)
    self.current_bound_buffer_bases.set(key, buffer)
    return true
  }
  false
}

///|
/// `unbindTexture()`: unbinds the texture of the active slot.
pub fn WebGLState::unbind_texture(self : WebGLState) -> Unit {
  let bound_texture = match self.current_texture_slot {
    Some(slot) => self.current_bound_textures.get(slot)
    // `currentBoundTextures[ null ]`.
    None => None
  }
  match bound_texture {
    Some(bound_texture) =>
      match bound_texture.type_ {
        Some(type_) => {
          self.gl.bind_texture(type_, None)
          bound_texture.type_ = None
          bound_texture.texture = None
        }
        None => ()
      }
    None => ()
  }
}

///|
/// `getParameter( name )`: the cached `pixelStorei` value, else `gl.getParameter`.
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
/// `pixelStorei( name, value )` for numeric values.
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
    self.parameters.set(name, js_value)
  }
}

///|
extern "js" fn _web_gl_state_pixel_storei_js(
  gl : @webgl.WebGL2RenderingContext,
  name : Int32,
  value : @core.JsValue,
) -> Unit = "(gl, n, v) => gl.pixelStorei( n, v )"

///|
/// `pixelStorei( name, value )` with a value read back by `getParameter` (which may be
/// `null`), restored as is.
pub fn WebGLState::pixel_storei_js(
  self : WebGLState,
  name : Int32,
  value : @core.JsValue,
) -> Unit {
  let changed = match self.parameters.get(name) {
    Some(current) => !current.strict_equal(value)
    None => !value.is_undefined()
  }
  if changed {
    _web_gl_state_pixel_storei_js(self.gl, name, value)
    self.parameters.set(name, value)
  }
}

///|
/// `pixelStorei( name, value )` for boolean values (`UNPACK_FLIP_Y_WEBGL`, ...).
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
    self.parameters.set(name, js_value)
  }
}

///|
/// `reset()`: resets the WebGL state and the cache.
pub fn WebGLState::reset(self : WebGLState) -> Unit {
  let gl = self.gl
  // reset WebGL state
  gl.disable(@webgl.GL_BLEND)
  gl.disable(@webgl.GL_CULL_FACE)
  gl.disable(@webgl.GL_DEPTH_TEST)
  gl.disable(@webgl.GL_POLYGON_OFFSET_FILL)
  gl.disable(@webgl.GL_SCISSOR_TEST)
  gl.disable(@webgl.GL_STENCIL_TEST)
  gl.disable(@webgl.GL_SAMPLE_ALPHA_TO_COVERAGE)
  gl.blend_equation(@webgl.GL_FUNC_ADD)
  gl.blend_func(@webgl.GL_ONE, @webgl.GL_ZERO)
  gl.blend_func_separate(
    @webgl.GL_ONE,
    @webgl.GL_ZERO,
    @webgl.GL_ONE,
    @webgl.GL_ZERO,
  )
  gl.blend_color(0.0, 0.0, 0.0, 0.0)
  gl.color_mask(true, true, true, true)
  gl.clear_color(0.0, 0.0, 0.0, 0.0)
  gl.depth_mask(true)
  gl.depth_func(@webgl.GL_LESS)
  gl.clear_depth(1.0)
  // 0xffffffff
  gl.stencil_mask(-1)
  gl.stencil_func(@webgl.GL_ALWAYS, 0, -1)
  gl.stencil_op(@webgl.GL_KEEP, @webgl.GL_KEEP, @webgl.GL_KEEP)
  gl.clear_stencil(0)
  gl.cull_face(@webgl.GL_BACK)
  gl.front_face(@webgl.GL_CCW)
  gl.polygon_offset(0.0, 0.0)
  gl.active_texture(@webgl.GL_TEXTURE0)
  gl.bind_framebuffer(@webgl.GL_FRAMEBUFFER, None)
  gl.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, None)
  gl.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, None)
  gl.use_program(None)
  gl.line_width(1.0)
  let width = gl.canvas().width().to_double()
  let height = gl.canvas().height().to_double()
  gl.scissor(0.0, 0.0, width, height)
  gl.viewport(0.0, 0.0, width, height)
  gl.pixel_storei(@webgl.GL_PACK_ALIGNMENT, 4)
  gl.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, 4)
  gl.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, false)
  gl.pixel_storei_bool(@webgl.GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL, false)
  gl.pixel_storei(
    @webgl.GL_UNPACK_COLORSPACE_CONVERSION_WEBGL,
    @webgl.GL_BROWSER_DEFAULT_WEBGL,
  )
  gl.pixel_storei(@webgl.GL_PACK_ROW_LENGTH, 0)
  gl.pixel_storei(@webgl.GL_PACK_SKIP_PIXELS, 0)
  gl.pixel_storei(@webgl.GL_PACK_SKIP_ROWS, 0)
  gl.pixel_storei(@webgl.GL_UNPACK_ROW_LENGTH, 0)
  gl.pixel_storei(@webgl.GL_UNPACK_IMAGE_HEIGHT, 0)
  gl.pixel_storei(@webgl.GL_UNPACK_SKIP_PIXELS, 0)
  gl.pixel_storei(@webgl.GL_UNPACK_SKIP_ROWS, 0)
  gl.pixel_storei(@webgl.GL_UNPACK_SKIP_IMAGES, 0)
  self.reset_vertex_state()
  // reset internal cache
  self.enabled = Map([])
  self.parameters = Map([])
  self.current_flip_sided = None
  self.current_cull_face = None
  self.current_program = None
  self.current_blending_enabled = false
  self.current_blending = None
  self.current_blend_equation = None
  self.current_blend_equation_alpha = None
  self.current_blend_src = None
  self.current_blend_dst = None
  self.current_blend_src_alpha = None
  self.current_blend_dst_alpha = None
  self.current_blend_color.set(0.0, 0.0, 0.0) |> ignore
  self.current_blend_alpha = 0.0
  self.current_premultipled_alpha = None
  self.current_polygon_offset_factor = None
  self.current_polygon_offset_units = None
  self.current_color_mask = None
  self.current_depth_func = None
  self.current_depth_mask = None
  self.current_stencil_func = None
  self.current_stencil_ref = None
  self.current_stencil_func_mask = None
  self.current_stencil_fail = None
  self.current_stencil_z_fail = None
  self.current_stencil_z_pass = None
  self.current_stencil_mask = None
  self.current_line_width = None
  self.current_clipping_planes = 0
  self.current_bound_framebuffers = Map([])
  self.current_drawbuffers = @webgl.WeakMap::new()
  self.current_texture_slot = None
  self.current_bound_textures = Map([])
  self.current_bound_buffer_bases = Map([])
  self.current_scissor.set(0.0, 0.0, width, height) |> ignore
  self.current_viewport.set(0.0, 0.0, width, height) |> ignore
  // re-apply reversed depth if used by the renderer
  self.current_depth_reversed = false
  if self.backend.renderer().reversed_depth_buffer == true {
    self.set_reversed_depth(true)
  }
}
