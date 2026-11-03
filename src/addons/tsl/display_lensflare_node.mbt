// examples/jsm/tsl/display/LensflareNode.js

///|
extern "js" fn lensflare_node_math_round(x : Double) -> Double = "Math.round"

///|
priv struct LensflareNodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let display_lensflare_node_module : AddonModule[LensflareNodeModule] = AddonModule::new(fn() {
    { _quad_mesh: @nodes.QuadMesh::new(), }
  },
)

///|
let _lensflare_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _lensflare_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
/// Evaluates LensflareNode.js (its `_quadMesh`), as `import` does.
pub fn load_display_lensflare_node() -> Unit {
  display_lensflare_node_module.get() |> ignore
}

///|
/// Post processing node for adding a bloom-based lens flare effect (ghosts along the
/// vector through the image center).
pub(all) struct LensflareNode {
  /// The texture node that represents the input of the effect.
  mut texture_node : @nodes.Node
  /// The tint of the ghosts.
  mut ghost_tint_node : @nodes.Node
  /// Only pixels brighter than this threshold contribute.
  mut threshold_node : @nodes.Node
  /// The number of ghost samples.
  mut ghost_samples_node : @nodes.Node
  /// The spacing of the ghosts.
  mut ghost_spacing_node : @nodes.Node
  /// The attenuation of ghosts at the screen edge.
  mut ghost_attenuation_factor_node : @nodes.Node
  /// The render target resolution is the drawing buffer size divided by this.
  mut down_sample_ratio : Double
  _render_target : @core.RenderTarget
  _material : @core.Material
  _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for LensflareNode with fn class_name(_) {
  "LensflareNode"
}

///|
pub impl @nodes.NodeClass for LensflareNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "ghostTintNode", Some(self.ghost_tint_node))
  @nodes.push_child(out, "thresholdNode", Some(self.threshold_node))
  @nodes.push_child(out, "ghostSamplesNode", Some(self.ghost_samples_node))
  @nodes.push_child(out, "ghostSpacingNode", Some(self.ghost_spacing_node))
  @nodes.push_child(
    out,
    "ghostAttenuationFactorNode",
    Some(self.ghost_attenuation_factor_node),
  )
}

///|
pub impl @nodes.NodeClass for LensflareNode with fn set_size(
  self,
  _,
  width,
  height,
) {
  self.set_size(width, height)
  true
}

///|
/// `getTextureNode()`: the lens flare result.
pub fn LensflareNode::get_texture_node(self : LensflareNode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`: the render target's size (divided by `downSampleRatio`).
pub fn LensflareNode::set_size(
  self : LensflareNode,
  width : Double,
  height : Double,
) -> Unit {
  let resx = lensflare_node_math_round(width / self.down_sample_ratio)
  let resy = lensflare_node_math_round(height / self.down_sample_ratio)
  self._render_target.set_size(resx.to_int(), resy.to_int())
}

///|
pub impl @nodes.NodeClass for LensflareNode with fn update_before(
  self,
  _,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let quad_mesh = display_lensflare_node_module.get()._quad_mesh
  let size = renderer.get_drawing_buffer_size(_lensflare_node_size)
  self.set_size(size.x, size.y)
  _lensflare_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(
      renderer,
      state?=_lensflare_node_renderer_state.val,
    ),
  )
  quad_mesh.set_material(self._material)
  // clear
  renderer.set_mrt(None) |> ignore
  // lensflare
  renderer.set_render_target(Some(self._render_target))
  quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(
    renderer,
    _lensflare_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for LensflareNode with fn setup(self, _, builder) {
  let lensflare = @nodes.fn_(fn(_, _) {
    // flip uvs so lens flare pivot around the image center
    let tex_coord = @nodes.uv().one_minus().to_var()
    // ghosts are positioned along this vector
    let ghost_vec = @nodes.sub(@nodes.vec2(0.5), tex_coord)
      .mul(self.ghost_spacing_node)
      .to_var()
    // sample ghosts
    let result = @nodes.vec4_of([]).to_var()
    let start = @nodes.int(0)
    let end = @nodes.int(self.ghost_samples_node)
    @nodes.loop_(
      [@nodes.loop_range(start~, end~, type_="int", condition="<")],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        // use fract() to ensure that the texture coordinates wrap around
        let sample_uv = @nodes.fract(
          tex_coord.add(ghost_vec.mul(@nodes.float(i))),
        ).to_var()
        // reduce contributions from samples at the screen edge
        let d = @nodes.distance(sample_uv, @nodes.vec2(0.5))
        let weight = @nodes.pow(
          d.one_minus(),
          self.ghost_attenuation_factor_node,
        )
        // accumulate
        let mut sample = self.texture_node.sample(sample_uv).rgb()
        sample = @nodes.max(sample.sub(self.threshold_node), @nodes.vec3(0)).mul(
          self.ghost_tint_node,
        )
        result.add_assign(sample.mul(weight))
      },
    )
    Some(result)
  })
  let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(lensflare.call([]))
  self._material.set_needs_update(true)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for LensflareNode with fn dispose(self, node) {
  node.dispose_base()
  self._render_target.dispose()
  self._material.dispose()
}

///|
/// `new LensflareNode( textureNode, { ghostTint = vec3( 1, 1, 1 ), threshold = float( 0.5 ),
/// ghostSamples = float( 4 ), ghostSpacing = float( 0.25 ), ghostAttenuationFactor =
/// float( 25 ), downSampleRatio = 4 } )`.
pub fn LensflareNode::new(
  texture_node : @nodes.Node,
  ghost_tint? : &@nodes.IntoTsl,
  threshold? : &@nodes.IntoTsl,
  ghost_samples? : &@nodes.IntoTsl,
  ghost_spacing? : &@nodes.IntoTsl,
  ghost_attenuation_factor? : &@nodes.IntoTsl,
  down_sample_ratio~ : Double = 4.0,
) -> @nodes.Node {
  display_lensflare_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  // the destructuring defaults, in order, then `nodeObject` of each
  let param = fn(
    v : &@nodes.IntoTsl?,
    default : () -> @nodes.Node,
  ) -> @nodes.TslValue {
    match v {
      Some(v) =>
        match v.to_tsl() {
          Undefined => Node(default())
          v => v
        }
      None => Node(default())
    }
  }
  let ghost_tint = param(ghost_tint, fn() { @nodes.vec3_of([1, 1, 1]) })
  let threshold = param(threshold, fn() { @nodes.float(0.5) })
  let ghost_samples = param(ghost_samples, fn() { @nodes.float(4) })
  let ghost_spacing = param(ghost_spacing, fn() { @nodes.float(0.25) })
  let ghost_attenuation_factor = param(ghost_attenuation_factor, fn() {
    @nodes.float(25)
  })
  let ghost_tint_node = @nodes.node_object(ghost_tint)
  let threshold_node = @nodes.node_object(threshold)
  let ghost_samples_node = @nodes.node_object(ghost_samples)
  let ghost_spacing_node = @nodes.node_object(ghost_spacing)
  let ghost_attenuation_factor_node = @nodes.node_object(
    ghost_attenuation_factor,
  )
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  render_target.texture().name = "LensflareNode"
  let material = @nodes.NodeMaterial::new()
  material.name = "LensflareNode"
  let texture_node_ = @nodes.pass_texture(node, render_target.texture())
  node.set_class(LensflareNode::{
    texture_node,
    ghost_tint_node,
    threshold_node,
    ghost_samples_node,
    ghost_spacing_node,
    ghost_attenuation_factor_node,
    down_sample_ratio,
    _render_target: render_target,
    _material: material,
    _texture_node: texture_node_,
  })
}

///|
pub fn LensflareNode::of(node : @nodes.Node) -> LensflareNode? {
  addon_class_of(node, "LensflareNode")
}

///|
/// `lensflare( node, params )` (the params as labelled arguments).
pub fn lensflare(
  node : @nodes.Node,
  ghost_tint? : &@nodes.IntoTsl,
  threshold? : &@nodes.IntoTsl,
  ghost_samples? : &@nodes.IntoTsl,
  ghost_spacing? : &@nodes.IntoTsl,
  ghost_attenuation_factor? : &@nodes.IntoTsl,
  down_sample_ratio~ : Double = 4.0,
) -> @nodes.Node {
  LensflareNode::new(
    @nodes.convert_to_texture(node),
    ghost_tint?,
    threshold?,
    ghost_samples?,
    ghost_spacing?,
    ghost_attenuation_factor?,
    down_sample_ratio~,
  )
}
