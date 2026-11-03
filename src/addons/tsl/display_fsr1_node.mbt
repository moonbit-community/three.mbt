// examples/jsm/tsl/display/FSR1Node.js

///|
/// The module's top-level `_quadMesh`.
priv struct FSR1NodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let _fsr1_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _fsr1_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let display_fsr1_node_module : AddonModule[FSR1NodeModule] = AddonModule::new(fn() {
  { _quad_mesh: @nodes.QuadMesh::new(), }
})

///|
/// Evaluates FSR1Node.js (its `_quadMesh`), as `import` does.
pub fn load_display_fsr1_node() -> Unit {
  display_fsr1_node_module.get() |> ignore
}

///|
/// Post processing node for AMD FidelityFX Super Resolution 1 (EASU upscaling, then RCAS
/// sharpening).
pub(all) struct FSR1Node {
  mut texture_node : @nodes.Node
  mut sharpness : @nodes.Node
  mut denoise : @nodes.Node
  _easu_rt : @core.RenderTarget
  _rcas_rt : @core.RenderTarget
  _texture_node : @nodes.Node
  mut _easu_material : @core.Material?
  mut _rcas_material : @core.Material?
}

///|
pub impl @nodes.NodeClass for FSR1Node with fn class_name(_) {
  "FSR1Node"
}

///|
pub impl @nodes.NodeClass for FSR1Node with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "sharpness", Some(self.sharpness))
  @nodes.push_child(out, "denoise", Some(self.denoise))
}

///|
pub impl @nodes.NodeClass for FSR1Node with fn set_size(self, _, width, height) {
  self.set_size(width, height)
  true
}

///|
pub impl @nodes.NodeClass for FSR1Node with fn update_before(self, _, frame) {
  let renderer = frame.renderer.unwrap()
  let quad_mesh = display_fsr1_node_module.get()._quad_mesh
  _fsr1_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(renderer, state?=_fsr1_node_renderer_state.val),
  )
  //
  renderer.get_drawing_buffer_size(_fsr1_node_size) |> ignore
  self.set_size(_fsr1_node_size.x, _fsr1_node_size.y)
  // EASU pass
  renderer.set_render_target(Some(self._easu_rt))
  quad_mesh.set_material(self._easu_material.unwrap())
  quad_mesh.object.name = "FSR1 [ EASU Pass ]"
  quad_mesh.render(renderer)
  // RCAS pass
  renderer.set_render_target(Some(self._rcas_rt))
  quad_mesh.set_material(self._rcas_material.unwrap())
  quad_mesh.object.name = "FSR1 [ RCAS Pass ]"
  quad_mesh.render(renderer)
  //
  @nodes.restore_renderer_state(
    renderer,
    _fsr1_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for FSR1Node with fn setup(self, node, builder) {
  let texture_node = self.texture_node
  let input_tex = @nodes.TextureNode::get_value(texture_node)
  // Note on performance: Compared to the orginal FSR1 code, texture sampling does
  // not make use of textureGather() yet. This is only available with WebGPU so the
  // WebGL 2 backend needs a fallback. Besides, in WebGPU and WebGL 2 we also
  // can't make use of packed math (e.g. FP16) which would considerably lower
  // the arithmetic costs (e.g. two 16-bit ops in parallel).

  // Accumulate edge direction and length for one bilinear quadrant.
  let accumulate_edge = fn(
    dir : @nodes.Node,
    len : @nodes.Node,
    w : @nodes.Node,
    a_l : @nodes.Node,
    b_l : @nodes.Node,
    c_l : @nodes.Node,
    d_l : @nodes.Node,
    e_l : @nodes.Node,
  ) {
    let dc = d_l.sub(c_l).to_const()
    let cb = c_l.sub(b_l).to_const()
    let dir_x = d_l.sub(b_l).to_const()
    let len_x = @nodes.max(@nodes.abs(dc), @nodes.abs(cb)).to_const()
    let s_len_x = @nodes.saturate(
      @nodes.abs(dir_x).div(@nodes.max(len_x, @nodes.float(1.0 / 65536.0))),
    ).to_const()
    dir.x().add_assign(dir_x.mul(w))
    len.add_assign(s_len_x.mul(s_len_x).mul(w))
    let ec = e_l.sub(c_l).to_const()
    let ca = c_l.sub(a_l).to_const()
    let dir_y = e_l.sub(a_l).to_const()
    let len_y = @nodes.max(@nodes.abs(ec), @nodes.abs(ca)).to_const()
    let s_len_y = @nodes.saturate(
      @nodes.abs(dir_y).div(@nodes.max(len_y, @nodes.float(1.0 / 65536.0))),
    ).to_const()
    dir.y().add_assign(dir_y.mul(w))
    len.add_assign(s_len_y.mul(s_len_y).mul(w))
  }
  // Compute an approximate Lanczos2 tap weight and accumulate.
  let accumulate_tap = fn(
    a_c : @nodes.Node,
    a_w : @nodes.Node,
    offset : @nodes.Node,
    dir : @nodes.Node,
    len2 : @nodes.Node,
    lob : @nodes.Node,
    clp : @nodes.Node,
    color : @nodes.Node,
  ) {
    let vx = offset.x().mul(dir.x()).add(offset.y().mul(dir.y())).to_const()
    let vy = offset
      .x()
      .mul(dir.y())
      .negate()
      .add(offset.y().mul(dir.x()))
      .to_const()
    let sx = vx.mul(len2.x()).to_const()
    let sy = vy.mul(len2.y()).to_const()
    let d2 = @nodes.min(sx.mul(sx).add(sy.mul(sy)), clp).to_const()
    let w_b = d2.mul(2.0 / 5.0).sub(1.0).to_const()
    let w_a = d2.mul(lob).sub(1.0).to_const()
    let w = w_b
      .mul(w_b)
      .mul(25.0 / 16.0)
      .sub(25.0 / 16.0 - 1.0)
      .mul(w_a.mul(w_a))
      .to_const()
    a_c.add_assign(color.mul(w))
    a_w.add_assign(w)
  }
  // EASU pass: edge-adaptive spatial upsampling.
  let easu = @nodes.fn_(fn(_, _) {
    let target_uv = @nodes.uv()
    let tex_size = @nodes.vec2(@nodes.texture_size(texture_node))
    let pp = target_uv.mul(tex_size).sub(0.5).to_const()
    let fp = @nodes.floor(pp).to_const()
    let f = @nodes.fract(pp).to_const()
    // Fetch exact texel values at integer coordinates (no filtering).
    let ifp = @nodes.ivec2_of([@nodes.int(fp.x()), @nodes.int(fp.y())]).to_const()
    let tap = fn(dx : Int32, dy : Int32) {
      @nodes.texture_load(input_tex, uv_node=ifp.add(@nodes.ivec2_of([dx, dy])))
    }
    // 12-tap cross pattern:
    //       b c
    //     e f g h
    //     i j k l
    //       n o
    let s_b = tap(0, -1)
    let s_c = tap(1, -1)
    let s_e = tap(-1, 0)
    let s_f = tap(0, 0)
    let s_g = tap(1, 0)
    let s_h = tap(2, 0)
    let s_i = tap(-1, 1)
    let s_j = tap(0, 1)
    let s_k = tap(1, 1)
    let s_l = tap(2, 1)
    let s_n = tap(0, 2)
    let s_o = tap(1, 2)
    // Approximate luminance for edge detection.
    let luma = fn(s : @nodes.Node) {
      s.r().mul(0.5).add(s.g()).add(s.b().mul(0.5))
    }
    let b_l = luma(s_b)
    let c_l = luma(s_c)
    let e_l = luma(s_e)
    let f_l = luma(s_f)
    let g_l = luma(s_g)
    let h_l = luma(s_h)
    let i_l = luma(s_i)
    let j_l = luma(s_j)
    let k_l = luma(s_k)
    let l_l = luma(s_l)
    let n_l = luma(s_n)
    let o_l = luma(s_o)
    // Accumulate edge direction and length from 4 bilinear quadrants.
    let dir = @nodes.vec2(0).to_var()
    let len = @nodes.float(0).to_var()
    let w0 = @nodes.float(1)
      .sub(f.x())
      .mul(@nodes.float(1).sub(f.y()))
      .to_const()
    let w1 = f.x().mul(@nodes.float(1).sub(f.y())).to_const()
    let w2 = @nodes.float(1).sub(f.x()).mul(f.y()).to_const()
    let w3 = f.x().mul(f.y()).to_const()
    accumulate_edge(dir, len, w0, b_l, e_l, f_l, g_l, j_l)
    accumulate_edge(dir, len, w1, c_l, f_l, g_l, h_l, k_l)
    accumulate_edge(dir, len, w2, f_l, i_l, j_l, k_l, n_l)
    accumulate_edge(dir, len, w3, g_l, j_l, k_l, l_l, o_l)
    // Normalize direction, defaulting to (1, 0) when gradient is negligible.
    let dir_sq = dir.x().mul(dir.x()).add(dir.y().mul(dir.y())).to_const()
    let zro = dir_sq.less_than(1.0 / 32768.0).to_const()
    let r_dir_len = @nodes.float(1.0)
      .div(@nodes.sqrt(@nodes.max(dir_sq, @nodes.float(1.0 / 32768.0))))
      .to_const()
    dir.x().assign(@nodes.select(zro, @nodes.float(1.0), else_node=dir.x()))
    dir.mul_assign(@nodes.select(zro, @nodes.float(1.0), else_node=r_dir_len))
    // Shape the kernel based on edge strength.
    len.assign(len.mul(0.5))
    len.mul_assign(len)
    // Stretch factor: 1.0 for axis-aligned edges, sqrt(2) on diagonals.
    let stretch = dir
      .x()
      .mul(dir.x())
      .add(dir.y().mul(dir.y()))
      .div(@nodes.max(@nodes.abs(dir.x()), @nodes.abs(dir.y())))
      .to_const()
    // Anisotropic lengths: x stretches along edge, y shrinks perpendicular.
    let len2 = @nodes.vec2_of([
      @nodes.float(1.0).add(stretch.sub(1.0).mul(len)),
      @nodes.float(1.0).sub(len.mul(0.5)),
    ]).to_const()
    // Negative lobe: strong on flat areas (0.5), reduced on edges (0.21).
    let lob = @nodes.float(0.5)
      .add(@nodes.float(1.0 / 4.0 - 0.04 - 0.5).mul(len))
      .to_const()
    let clp = @nodes.float(1.0).div(lob).to_const()
    // Accumulate weighted taps.
    let a_c = @nodes.vec4(0).to_var()
    let a_w = @nodes.float(0).to_var()
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([0, -1]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_b,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([1, -1]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_c,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([-1, 0]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_e,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([0, 0]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_f,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([1, 0]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_g,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([2, 0]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_h,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([-1, 1]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_i,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([0, 1]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_j,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([1, 1]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_k,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([2, 1]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_l,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([0, 2]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_n,
    )
    accumulate_tap(
      a_c,
      a_w,
      @nodes.vec2_of([1, 2]).sub(f),
      dir,
      len2,
      lob,
      clp,
      s_o,
    )
    // Normalize.
    a_c.div_assign(a_w)
    // Anti-ringing: clamp to min/max of the 4 nearest samples (f, g, j, k).
    let min4 = @nodes.min(@nodes.min(s_f, s_g), @nodes.min(s_j, s_k)).to_const()
    let max4 = @nodes.max(@nodes.max(s_f, s_g), @nodes.max(s_j, s_k)).to_const()
    Some(@nodes.clamp(a_c, low=min4, high=max4))
  })
  // RCAS pass: robust contrast-adaptive sharpening.
  let easu_tex = self._easu_rt.texture()
  let rcas = @nodes.fn_(fn(_, _) {
    let target_uv = @nodes.uv()
    let tex_size = @nodes.vec2(
      @nodes.texture_size(@nodes.texture_load(easu_tex)),
    )
    let p = @nodes.ivec2_of([
      @nodes.int(@nodes.floor(target_uv.x().mul(tex_size.x()))),
      @nodes.int(@nodes.floor(target_uv.y().mul(tex_size.y()))),
    ]).to_const()
    let e = @nodes.texture_load(easu_tex, uv_node=p)
    let b = @nodes.texture_load(
      easu_tex,
      uv_node=p.add(@nodes.ivec2_of([0, -1])),
    )
    let d = @nodes.texture_load(
      easu_tex,
      uv_node=p.add(@nodes.ivec2_of([-1, 0])),
    )
    let f = @nodes.texture_load(
      easu_tex,
      uv_node=p.add(@nodes.ivec2_of([1, 0])),
    )
    let h = @nodes.texture_load(
      easu_tex,
      uv_node=p.add(@nodes.ivec2_of([0, 1])),
    )
    // Approximate luminance (luma times 2).
    let luma = fn(s : @nodes.Node) { s.g().add(s.b().add(s.r()).mul(0.5)) }
    let b_l = luma(b)
    let d_l = luma(d)
    let e_l = luma(e)
    let f_l = luma(f)
    let h_l = luma(h)
    // Sharpening amount from user parameter.
    let con = @nodes.exp2(self.sharpness.negate()).to_const()
    // Min and max of ring.
    let mn4 = @nodes.min(
      @nodes.min(b.rgb(), d.rgb()),
      @nodes.min(f.rgb(), h.rgb()),
    ).to_const()
    let mx4 = @nodes.max(
      @nodes.max(b.rgb(), d.rgb()),
      @nodes.max(f.rgb(), h.rgb()),
    ).to_const()
    // Compute adaptive lobe weight.
    // Limiters based on how much sharpening the local contrast can tolerate.
    let rcas_limit = @nodes.float(0.25 - 1.0 / 16.0).to_const()
    let hit_min = @nodes.min(mn4, e.rgb()).div(mx4.mul(4.0)).to_const()
    let hit_max = @nodes.vec3(1.0)
      .sub(@nodes.max(mx4, e.rgb()))
      .div(mn4.mul(4.0).sub(4.0))
      .to_const()
    let lobe_rgb = @nodes.max(hit_min.negate(), hit_max).to_const()
    let lobe = @nodes.max(
        rcas_limit.negate(),
        @nodes.min(
          @nodes.max(lobe_rgb.r(), @nodes.max(lobe_rgb.g(), lobe_rgb.b())),
          @nodes.float(0.0),
        ),
      )
      .mul(con)
      .to_const()
    // Noise attenuation.
    let nz = b_l.add(d_l).add(f_l).add(h_l).mul(0.25).sub(e_l).to_const()
    let nz_range = @nodes.max(
        @nodes.max(b_l, d_l),
        @nodes.max(e_l, @nodes.max(f_l, h_l)),
      )
      .sub(
        @nodes.min(@nodes.min(b_l, d_l), @nodes.min(e_l, @nodes.min(f_l, h_l))),
      )
      .to_const()
    let nz_factor = @nodes.float(1.0)
      .sub(
        @nodes.abs(nz)
        .div(@nodes.max(nz_range, @nodes.float(1.0 / 65536.0)))
        .saturate()
        .mul(0.5),
      )
      .to_const()
    let effective_lobe = self.denoise
      .equal(true)
      .select(lobe.mul(nz_factor), else_node=lobe)
      .to_const()
    // Resolve: weighted blend of cross neighbors and center.
    let result = b
      .rgb()
      .add(d.rgb())
      .add(f.rgb())
      .add(h.rgb())
      .mul(effective_lobe)
      .add(e.rgb())
      .div(effective_lobe.mul(4.0).add(1.0))
      .to_const()
    Some(@nodes.vec4_of([result, e.a()]))
  })
  //
  let shared_context = @nodes.context(value=builder.get_shared_context())
  let easu_material = match self._easu_material {
    Some(material) => material
    None => {
      let material = @nodes.NodeMaterial::new()
      self._easu_material = Some(material)
      material
    }
  }
  let easu_payload = @nodes.NodeMaterial::of(easu_material).unwrap()
  easu_payload.context_node = Some(shared_context)
  easu_payload.fragment_node = Some(easu.call([]))
  easu_material.name = "FSR1_EASU"
  easu_material.set_needs_update(true)
  let rcas_material = match self._rcas_material {
    Some(material) => material
    None => {
      let material = @nodes.NodeMaterial::new()
      self._rcas_material = Some(material)
      material
    }
  }
  let rcas_payload = @nodes.NodeMaterial::of(rcas_material).unwrap()
  rcas_payload.context_node = Some(shared_context)
  rcas_payload.fragment_node = Some(rcas.call([]))
  rcas_material.name = "FSR1_RCAS"
  rcas_material.set_needs_update(true)
  //
  let properties = builder.get_node_properties(node)
  properties.set_node("textureNode", texture_node)
  //
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for FSR1Node with fn dispose(self, node) {
  node.dispose_base()
  self._easu_rt.dispose()
  self._rcas_rt.dispose()
  if self._easu_material is Some(material) {
    material.dispose()
  }
  if self._rcas_material is Some(material) {
    material.dispose()
  }
}

///|
/// `setSize( width, height )`.
pub fn FSR1Node::set_size(
  self : FSR1Node,
  width : Double,
  height : Double,
) -> Unit {
  self._easu_rt.set_size(width.to_int(), height.to_int())
  self._rcas_rt.set_size(width.to_int(), height.to_int())
}

///|
/// `getTextureNode()`: the upscaled and sharpened result.
pub fn FSR1Node::get_texture_node(self : FSR1Node) -> @nodes.Node {
  self._texture_node
}

///|
/// `new FSR1Node( textureNode, sharpness = 0.2, denoise = false )`; `sharpness` and
/// `denoise` are nodes or values `nodeObject` converts.
pub fn FSR1Node::new(
  texture_node : @nodes.Node,
  sharpness~ : &@nodes.IntoTsl = 0.2,
  denoise~ : &@nodes.IntoTsl = false,
) -> @nodes.Node {
  display_fsr1_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let sharpness = addon_node_object(sharpness)
  let denoise = addon_node_object(denoise)
  let easu_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  easu_rt.texture().name = "FSR1Node.easu"
  let rcas_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  rcas_rt.texture().name = "FSR1Node.rcas"
  let texture_node_out = @nodes.pass_texture(node, rcas_rt.texture())
  node.update_before_type = @nodes.NodeUpdateType::frame()
  node.set_class(FSR1Node::{
    texture_node,
    sharpness,
    denoise,
    _easu_rt: easu_rt,
    _rcas_rt: rcas_rt,
    _texture_node: texture_node_out,
    _easu_material: None,
    _rcas_material: None,
  })
}

///|
pub fn FSR1Node::of(node : @nodes.Node) -> FSR1Node? {
  addon_class_of(node, "FSR1Node")
}

///|
/// `fsr1( node, sharpness, denoise )`.
pub fn fsr1(
  node : @nodes.Node,
  sharpness~ : &@nodes.IntoTsl = 0.2,
  denoise~ : &@nodes.IntoTsl = false,
) -> @nodes.Node {
  display_fsr1_node_module.get() |> ignore
  FSR1Node::new(@nodes.convert_to_texture(node), sharpness~, denoise~)
}
