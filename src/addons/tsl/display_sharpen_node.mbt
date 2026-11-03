// examples/jsm/tsl/display/SharpenNode.js

///|
/// The module's top-level state: `_quadMesh` and `_rendererState`.
priv struct SharpenNodeModule {
  quad_mesh : @nodes.QuadMesh
  mut renderer_state : @nodes.RendererState?
}

///|
let sharpen_node_module : AddonModule[SharpenNodeModule] = AddonModule::new(fn() {
  { quad_mesh: @nodes.QuadMesh::new(), renderer_state: None, }
})

///|
let _sharpen_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
/// Evaluates SharpenNode.js's top-level statements (`import`).
pub fn load_display_sharpen_node() -> Unit {
  sharpen_node_module.get() |> ignore
}

///|
/// Post processing node for contrast-adaptive sharpening (RCAS, from AMD FidelityFX
/// FSR 1), rendered into an internal render target.
pub(all) struct SharpenNode {
  mut texture_node : @nodes.Node
  mut sharpness : @nodes.Node
  mut denoise : @nodes.Node
  _render_target : @core.RenderTarget
  _texture_node : @nodes.Node
  mut _material : @core.Material?
}

///|
pub impl @nodes.NodeClass for SharpenNode with fn class_name(_) {
  "SharpenNode"
}

///|
pub impl @nodes.NodeClass for SharpenNode with fn has_flag(_, flag) {
  flag == "isSharpenNode"
}

///|
pub impl @nodes.NodeClass for SharpenNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "sharpness", Some(self.sharpness))
  @nodes.push_child(out, "denoise", Some(self.denoise))
}

///|
/// `setSize( width, height )`.
pub fn SharpenNode::set_size(
  self : SharpenNode,
  width : Double,
  height : Double,
) -> Unit {
  self._render_target.set_size(width.to_int(), height.to_int())
}

///|
pub impl @nodes.NodeClass for SharpenNode with fn update_before(self, _, frame) {
  let renderer = frame.renderer.unwrap()
  let m = sharpen_node_module.get()
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  //
  renderer.get_drawing_buffer_size(_sharpen_node_size) |> ignore
  self.set_size(_sharpen_node_size.x, _sharpen_node_size.y)
  renderer.set_render_target(Some(self._render_target))
  m.quad_mesh.set_material(self._material.unwrap())
  m.quad_mesh.object.name = "Sharpen [ RCAS ]"
  m.quad_mesh.render(renderer)
  //
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
/// `getTextureNode()`: the sharpened result.
pub fn SharpenNode::get_texture_node(self : SharpenNode) -> @nodes.Node {
  self._texture_node
}

///|
pub impl @nodes.NodeClass for SharpenNode with fn setup(self, node, builder) {
  let texture_node = self.texture_node
  let input_tex = @nodes.TextureNode::get_value(texture_node)
  // RCAS: Robust Contrast-Adaptive Sharpening.
  //
  // Ported from AMD FidelityFX FSR 1 (ffx_fsr1.h). Uses a 5-tap
  // cross pattern (center + up/down/left/right) to compute a
  // per-pixel sharpening weight that is automatically limited by
  // local contrast to avoid ringing. An optional noise-attenuation
  // factor reduces sharpening in noisy areas.
  let rcas = @nodes.fn_(fn(_, _) {
    let target_uv = @nodes.uv()
    let tex_size = @nodes.texture_size(@nodes.texture_load(input_tex))
    let p = @nodes.ivec2_of([
      @nodes.int(@nodes.floor(target_uv.x().mul(tex_size.x()))),
      @nodes.int(@nodes.floor(target_uv.y().mul(tex_size.y()))),
    ]).to_const()
    let e = @nodes.texture_load(input_tex, uv_node=p)
    let b = @nodes.texture_load(
      input_tex,
      uv_node=p.add(@nodes.ivec2_of([0, -1])),
    )
    let d = @nodes.texture_load(
      input_tex,
      uv_node=p.add(@nodes.ivec2_of([-1, 0])),
    )
    let f = @nodes.texture_load(
      input_tex,
      uv_node=p.add(@nodes.ivec2_of([1, 0])),
    )
    let h = @nodes.texture_load(
      input_tex,
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
  let material = match self._material {
    Some(m) => m
    None => {
      let m = @nodes.NodeMaterial::new()
      self._material = Some(m)
      m
    }
  }
  let node_material = @nodes.NodeMaterial::of(material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(rcas.call([]))
  material.name = "Sharpen_RCAS"
  material.set_needs_update(true)
  //
  let properties = builder.get_node_properties(node)
  properties.set_node("textureNode", texture_node)
  //
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for SharpenNode with fn dispose(self, node) {
  node.dispose_base()
  self._render_target.dispose()
  if self._material is Some(m) {
    m.dispose()
  }
}

///|
/// `new SharpenNode( textureNode, sharpness = 0.2, denoise = false )`.
pub fn SharpenNode::new(
  texture_node : @nodes.Node,
  sharpness? : &@nodes.IntoTsl,
  denoise? : &@nodes.IntoTsl,
) -> @nodes.Node {
  sharpen_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let sharpness = a4_node_object_or(sharpness, Number(0.2))
  let denoise = a4_node_object_or(denoise, Bool(false))
  let _render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _render_target.texture().name = "SharpenNode.output"
  let _texture_node = @nodes.pass_texture(node, _render_target.texture())
  node.update_before_type = @nodes.NodeUpdateType::frame()
  node.set_class(SharpenNode::{
    texture_node,
    sharpness,
    denoise,
    _render_target,
    _texture_node,
    _material: None,
  })
}

///|
pub fn SharpenNode::of(node : @nodes.Node) -> SharpenNode? {
  addon_class_of(node, "SharpenNode")
}

///|
/// `sharpen( node, sharpness, denoise )`.
pub fn sharpen(
  node : @nodes.Node,
  sharpness? : &@nodes.IntoTsl,
  denoise? : &@nodes.IntoTsl,
) -> @nodes.Node {
  SharpenNode::new(@nodes.convert_to_texture(node), sharpness?, denoise?)
}
