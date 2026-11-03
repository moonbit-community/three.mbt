// Group 2 differential scenarios for WebGLState, mirroring
// harness/scenarios/state_*.mjs in the diff/core/webgl harness step by step.

///|
/// A JS object standing in for a DOM image source.
extern "js" fn state_fake_source(id : Int32) -> @core.JsValue = "(i) => ({ image: i })"

///|
fn state_blend_normal(state : @webgl.WebGLState, premultiplied : Bool) -> Unit {
  state.set_blending(@core.NormalBlending, premultiplied_alpha=premultiplied)
}

///|
test "diff state_all" {
  let gl = mock_gl(options="{\"canvas\":{\"width\":64,\"height\":32}}")
  let extensions = @webgl.WebGLExtensions::new(gl)
  let state = @webgl.WebGLState::new(gl, extensions)
  mock_note(
    gl,
    "maxTextures",
    state.get_parameter(@webgl.GL_MAX_COMBINED_TEXTURE_IMAGE_UNITS),
  )
  // capabilities
  state.enable(@webgl.GL_BLEND)
  state.enable(@webgl.GL_BLEND)
  state.disable(@webgl.GL_BLEND)
  state.disable(@webgl.GL_BLEND)
  state.disable(0x0BD0)
  // framebuffers
  let fb = Some(gl.create_framebuffer())
  let fb2 = Some(gl.create_framebuffer())
  note_bool(gl, "bind", state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, fb))
  note_bool(gl, "bind", state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, fb))
  note_bool(gl, "bind", state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, fb))
  note_bool(gl, "bind", state.bind_framebuffer(@webgl.GL_DRAW_FRAMEBUFFER, fb2))
  note_bool(gl, "bind", state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, fb2))
  note_bool(
    gl,
    "bind",
    state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, None),
  )
  note_bool(
    gl,
    "bind",
    state.bind_framebuffer(@webgl.GL_READ_FRAMEBUFFER, None),
  )
  note_bool(gl, "bind", state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, None))
  // draw buffers
  state.draw_buffers(None, None)
  state.draw_buffers(None, None)
  let rt3 = @core.RenderTarget::new(width=4, height=4, count=3)
  let rt1 = @core.RenderTarget::new(width=4, height=4)
  state.draw_buffers(Some(rt3), fb)
  state.draw_buffers(Some(rt3), fb)
  state.draw_buffers(Some(rt1), fb)
  state.draw_buffers(Some(rt1), fb2)
  state.draw_buffers(Some(rt3), fb)
  // programs
  let p1 = Some(gl.create_program())
  note_bool(gl, "use", state.use_program(p1))
  note_bool(gl, "use", state.use_program(p1))
  note_bool(gl, "use", state.use_program(None))
  note_bool(gl, "use", state.use_program(None))
  // blending
  state.set_blending(@core.NoBlending)
  state_blend_normal(state, false)
  state_blend_normal(state, false)
  state_blend_normal(state, true)
  state.set_blending(@core.AdditiveBlending, premultiplied_alpha=true)
  state.set_blending(@core.AdditiveBlending, premultiplied_alpha=false)
  state.set_blending(@core.SubtractiveBlending, premultiplied_alpha=true)
  state.set_blending(@core.MultiplyBlending, premultiplied_alpha=true)
  state.set_blending(@core.SubtractiveBlending, premultiplied_alpha=false)
  state.set_blending(@core.NormalBlending)
  note_str(gl, "blend", "undefined")
  state.set_blending(@core.NormalBlending)
  note_str(gl, "blend", "undefined again")
  state_blend_normal(state, false)
  state.set_blending(
    @core.CustomBlending,
    blend_equation=@core.AddEquation,
    blend_src=@core.SrcAlphaFactor,
    blend_dst=@core.OneMinusSrcAlphaFactor,
    blend_color=@math.Color::new(0.0, 0.0, 0.0),
    blend_alpha=0.0,
  )
  state.set_blending(
    @core.CustomBlending,
    blend_equation=@core.AddEquation,
    blend_src=@core.SrcAlphaFactor,
    blend_dst=@core.OneMinusSrcAlphaFactor,
    blend_color=@math.Color::new(0.0, 0.0, 0.0),
    blend_alpha=0.0,
  )
  state.set_blending(
    @core.CustomBlending,
    blend_equation=@core.SubtractEquation,
    blend_src=@core.OneFactor,
    blend_dst=@core.ZeroFactor,
    blend_equation_alpha=@core.MaxEquation,
    blend_src_alpha=@core.DstColorFactor,
    blend_dst_alpha=@core.ConstantAlphaFactor,
    blend_color=@math.Color::new(0.25, 0.5, 1.0),
    blend_alpha=0.5,
  )
  state.set_blending(
    @core.CustomBlending,
    blend_equation=@core.SubtractEquation,
    blend_src=@core.OneFactor,
    blend_dst=@core.ZeroFactor,
    blend_equation_alpha=@core.MaxEquation,
    blend_src_alpha=@core.DstColorFactor,
    blend_dst_alpha=@core.ConstantAlphaFactor,
    blend_color=@math.Color::new(0.25, 0.5, 1.0),
    blend_alpha=0.75,
  )
  state.set_blending(
    @core.CustomBlending,
    blend_equation=@core.ReverseSubtractEquation,
    blend_src=@core.SrcAlphaSaturateFactor,
    blend_dst=@core.OneMinusDstAlphaFactor,
    blend_equation_alpha=@core.MinEquation,
    blend_src_alpha=@core.OneMinusConstantColorFactor,
    blend_dst_alpha=@core.ConstantColorFactor,
    blend_color=@math.Color::new(0.25, 0.5, 1.0),
    blend_alpha=0.75,
  )
  state_blend_normal(state, false)
  state.set_blending(@core.NoBlending)
  state.set_blending(@core.NoBlending)
  // materials
  let m1 = @core.MeshBasicMaterial::new()
  state.set_material(m1, false)
  state.set_material(m1, true)
  let m2 = @core.MeshBasicMaterial::new()
  m2.side = @core.DoubleSide
  m2.transparent = true
  m2.depth_func = @core.GreaterDepth
  m2.depth_write = false
  m2.color_write = false
  m2.stencil_write = true
  m2.stencil_write_mask = 0x0f
  m2.stencil_func = @core.EqualStencilFunc
  m2.stencil_ref = 3
  m2.stencil_func_mask = 0xf0
  m2.stencil_fail = @core.ReplaceStencilOp
  m2.stencil_z_fail = @core.IncrementStencilOp
  m2.stencil_z_pass = @core.InvertStencilOp
  m2.polygon_offset = true
  m2.polygon_offset_factor = 2.0
  m2.polygon_offset_units = -1.0
  m2.alpha_to_coverage = true
  m2.premultiplied_alpha = true
  state.set_material(m2, false)
  state.set_material(m2, false)
  let m3 = @core.MeshStandardMaterial::new()
  m3.side = @core.BackSide
  m3.blending = @core.CustomBlending
  m3.blend_equation = @core.AddEquation
  m3.blend_src = @core.OneFactor
  m3.blend_dst = @core.OneFactor
  m3.depth_test = false
  ignore(m3.blend_color.set(0.1, 0.2, 0.3))
  m3.blend_alpha = 0.4
  state.set_material(m3, false)
  state.set_material(m3, true)
  for
    f in [
      @core.NeverDepth,
      @core.AlwaysDepth,
      @core.LessDepth,
      @core.LessEqualDepth,
      @core.EqualDepth,
      @core.GreaterEqualDepth,
      @core.GreaterDepth,
      @core.NotEqualDepth,
      99,
    ] {
    state.buffers.depth.set_func(f)
  }
  state.set_material(m1, false)
  // culling
  state.set_flip_sided(true)
  state.set_flip_sided(true)
  state.set_flip_sided(false)
  state.set_cull_face(@core.CullFaceNone)
  state.set_cull_face(@core.CullFaceFront)
  state.set_cull_face(@core.CullFaceFront)
  state.set_cull_face(@core.CullFaceFrontBack)
  state.set_cull_face(@core.CullFaceBack)
  state.set_line_width(1.0)
  state.set_line_width(1.0)
  state.set_line_width(2.5)
  state.set_polygon_offset(true, factor=1.0, units=2.0)
  state.set_polygon_offset(true, factor=1.0, units=2.0)
  state.set_polygon_offset(false)
  state.set_scissor_test(true)
  state.set_scissor_test(true)
  state.set_scissor_test(false)
  // depth buffer, reversed
  let depth = state.buffers.depth
  depth.set_clear(0.25)
  depth.set_reversed(true)
  note_bool(gl, "reversed", depth.get_reversed())
  depth.set_reversed(true)
  depth.set_clear(0.25)
  depth.set_clear(0.5)
  depth.set_func(@core.LessDepth)
  depth.set_func(@core.LessEqualDepth)
  depth.set_func(@core.GreaterDepth)
  state.set_polygon_offset(true, factor=3.0, units=4.0)
  depth.set_reversed(false)
  depth.set_mask(false)
  depth.set_locked(true)
  depth.set_mask(true)
  depth.set_locked(false)
  depth.set_mask(true)
  depth.set_test(false)
  depth.set_test(true)
  // color buffer
  let color = state.buffers.color
  color.set_clear(0.5, 0.5, 0.5, 0.5)
  color.set_clear(0.5, 0.5, 0.5, 0.5)
  color.set_clear(0.5, 0.5, 0.5, 0.5, premultiplied_alpha=true)
  color.set_mask(false)
  color.set_locked(true)
  color.set_mask(true)
  color.set_locked(false)
  color.set_mask(true)
  // stencil buffer
  let stencil = state.buffers.stencil
  stencil.set_test(true)
  stencil.set_mask(0xff)
  stencil.set_mask(0xff)
  stencil.set_mask(-1)
  stencil.set_func(@webgl.GL_ALWAYS, 1, 0xff)
  stencil.set_func(@webgl.GL_ALWAYS, 1, 0xff)
  stencil.set_func(@webgl.GL_ALWAYS, 2, 0xff)
  stencil.set_op(@webgl.GL_KEEP, @webgl.GL_KEEP, 0x1E01)
  stencil.set_op(@webgl.GL_KEEP, @webgl.GL_KEEP, 0x1E01)
  stencil.set_op(@webgl.GL_KEEP, 0x1E02, 0x1E01)
  stencil.set_clear(1)
  stencil.set_clear(1)
  stencil.set_locked(true)
  stencil.set_test(false)
  stencil.set_mask(0x0f)
  stencil.set_locked(false)
  stencil.set_test(false)
  // textures
  let tex = Some(gl.create_texture())
  let tex2 = Some(gl.create_texture())
  state.bind_texture(@webgl.GL_TEXTURE_2D, tex)
  state.bind_texture(@webgl.GL_TEXTURE_2D, tex)
  state.active_texture()
  state.active_texture(webgl_slot=@webgl.GL_TEXTURE0 + 3)
  state.active_texture(webgl_slot=@webgl.GL_TEXTURE0 + 3)
  state.bind_texture(@webgl.GL_TEXTURE_2D, tex)
  state.bind_texture(
    @webgl.GL_TEXTURE_2D,
    tex2,
    webgl_slot=@webgl.GL_TEXTURE0 + 3,
  )
  state.bind_texture(
    @webgl.GL_TEXTURE_CUBE_MAP,
    tex2,
    webgl_slot=@webgl.GL_TEXTURE0 + 3,
  )
  state.bind_texture(
    @webgl.GL_TEXTURE_2D,
    None,
    webgl_slot=@webgl.GL_TEXTURE0 + 5,
  )
  state.bind_texture(
    @webgl.GL_TEXTURE_2D,
    None,
    webgl_slot=@webgl.GL_TEXTURE0 + 5,
  )
  state.bind_texture(@webgl.GL_TEXTURE_3D, None)
  state.bind_texture(@webgl.GL_TEXTURE_2D_ARRAY, tex)
  state.unbind_texture()
  state.unbind_texture()
  state.active_texture(webgl_slot=@webgl.GL_TEXTURE0)
  state.unbind_texture()
  state.bind_texture(@webgl.GL_TEXTURE_2D, tex)
  state.unbind_texture()
  let data = @core.TypedArray::uint8([1.0, 2, 3, 4])
  state.tex_image2d(
    @webgl.GL_TEXTURE_2D,
    0,
    @webgl.GL_RGBA,
    1,
    1,
    0,
    @webgl.GL_RGBA,
    @webgl.GL_UNSIGNED_BYTE,
    data,
  )
  state.tex_image2d_source(
    @webgl.GL_TEXTURE_2D,
    0,
    @webgl.GL_RGBA,
    @webgl.GL_RGBA,
    @webgl.GL_UNSIGNED_BYTE,
    state_fake_source(1),
  )
  state.tex_image3d(
    @webgl.GL_TEXTURE_3D,
    0,
    @webgl.GL_RGBA,
    1,
    1,
    1,
    0,
    @webgl.GL_RGBA,
    @webgl.GL_UNSIGNED_BYTE,
    data,
  )
  state.tex_sub_image2d(
    @webgl.GL_TEXTURE_2D,
    0,
    0,
    0,
    1,
    1,
    @webgl.GL_RGBA,
    @webgl.GL_UNSIGNED_BYTE,
    data,
  )
  state.tex_sub_image2d_source(
    @webgl.GL_TEXTURE_2D,
    0,
    0,
    0,
    @webgl.GL_RGBA,
    @webgl.GL_UNSIGNED_BYTE,
    state_fake_source(2),
  )
  state.tex_sub_image3d(
    @webgl.GL_TEXTURE_3D,
    0,
    0,
    0,
    0,
    1,
    1,
    1,
    @webgl.GL_RGBA,
    @webgl.GL_UNSIGNED_BYTE,
    data,
  )
  state.compressed_tex_image2d(@webgl.GL_TEXTURE_2D, 0, 0x83F0, 4, 4, 0, data)
  state.compressed_tex_image3d(
    @webgl.GL_TEXTURE_2D_ARRAY,
    0,
    0x83F0,
    4,
    4,
    1,
    0,
    data,
    0,
    0,
  )
  state.compressed_tex_sub_image2d(
    @webgl.GL_TEXTURE_2D,
    0,
    0,
    0,
    4,
    4,
    0x83F0,
    data,
  )
  state.compressed_tex_sub_image3d(
    @webgl.GL_TEXTURE_2D_ARRAY,
    0,
    0,
    0,
    0,
    4,
    4,
    1,
    0x83F0,
    data,
  )
  state.tex_storage2d(@webgl.GL_TEXTURE_2D, 1, @webgl.GL_RGBA8, 4, 4)
  state.tex_storage3d(@webgl.GL_TEXTURE_3D, 1, @webgl.GL_RGBA8, 4, 4, 4)
  // pixel store
  state.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, 1)
  state.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, 1)
  state.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, 4)
  state.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, true)
  state.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, true)
  state.pixel_storei_bool(@webgl.GL_UNPACK_FLIP_Y_WEBGL, false)
  mock_note(gl, "param", state.get_parameter(@webgl.GL_UNPACK_ALIGNMENT))
  mock_note(gl, "param", state.get_parameter(@webgl.GL_UNPACK_FLIP_Y_WEBGL))
  mock_note(gl, "param", state.get_parameter(@webgl.GL_MAX_TEXTURE_SIZE))
  // UBO
  let group = @core.UniformsGroup::new().set_name("Block")
  let group2 = @core.UniformsGroup::new().set_name("Other")
  let p2 = gl.create_program()
  state.update_ubo_mapping(group, p2)
  state.update_ubo_mapping(group, p2)
  state.update_ubo_mapping(group2, p2)
  let buf = Some(gl.create_buffer())
  state.uniform_block_binding(group, p2, buf)
  state.uniform_block_binding(group, p2, buf)
  state.uniform_block_binding(group2, p2, None)
  state.uniform_block_binding(group2, p2, buf)
  // scissor / viewport
  state.scissor(@math.Vector4::new(0.0, 0.0, 64.0, 32.0))
  state.scissor(@math.Vector4::new(1.0, 2.0, 3.0, 4.0))
  state.scissor(@math.Vector4::new(1.0, 2.0, 3.0, 4.0))
  state.viewport(@math.Vector4::new(0.0, 0.0, 64.0, 32.0))
  state.viewport(@math.Vector4::new(0.5, 0.0, 10.0, 20.0))
  state.viewport(@math.Vector4::new(0.5, 0.0, 10.0, 20.0))
  // reset
  state.reset()
  state.enable(@webgl.GL_BLEND)
  state_blend_normal(state, false)
  state.set_material(m2, false)
  state.bind_texture(@webgl.GL_TEXTURE_2D, tex)
  ignore(state.use_program(p1))
  ignore(state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, None))
  state.draw_buffers(None, None)
  state.pixel_storei(@webgl.GL_UNPACK_ALIGNMENT, 4)
  state.scissor(@math.Vector4::new(0.0, 0.0, 64.0, 32.0))
  state.viewport(@math.Vector4::new(0.0, 0.0, 64.0, 32.0))
  state.update_ubo_mapping(group, p2)
  state.uniform_block_binding(group, p2, buf)
  color.set_clear(0.0, 0.0, 0.0, 0.0)
  depth.set_clear(1.0)
  stencil.set_clear(0)
  state.set_line_width(1.0)
  let log = emit_log("state_all", gl)
  // a few direct checks for runs without the harness
  inspect(state.max_textures, content="32")
  inspect(state.line_width_available, content="true")
  assert_true(log.contains("depthFunc(515)"))
}
