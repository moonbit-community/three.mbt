// examples/jsm/tsl/display/BloomNode.js

///|
extern "js" fn bloom_node_math_exp(x : Double) -> Double = "Math.exp"

///|
/// The module's top-level nodes and objects, in upstream statement order.
priv struct BloomNodeModule {
  _quad_mesh : @nodes.QuadMesh
  luminosity_high_pass : @nodes.Node
  lerp_bloom_factor : @nodes.Node
}

///|
let _bloom_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _bloom_node_blur_direction_x : @math.Vector2 = @math.Vector2::new(1.0, 0.0)

///|
let _bloom_node_blur_direction_y : @math.Vector2 = @math.Vector2::new(0.0, 1.0)

///|
let _bloom_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
let display_bloom_node_module : AddonModule[BloomNodeModule] = AddonModule::new(fn() {
    let _quad_mesh = @nodes.QuadMesh::new()
    let luminosity_high_pass = @nodes.fn_(fn(inputs, _) {
      let input = inputs.named("input").unwrap()
      let threshold = inputs.named("threshold").unwrap()
      let smooth_width = inputs.named("smoothWidth").unwrap()
      let v = @nodes.luminance(input.rgb())
      let alpha = @nodes.smoothstep(threshold, threshold.add(smooth_width), v)
      Some(@nodes.mix(@nodes.vec4(0), input, alpha))
    })
    // (class BloomNode)
    let lerp_bloom_factor = @nodes.fn_(
      fn(inputs, _) {
        let factor = inputs.named("factor").unwrap()
        let radius = inputs.named("radius").unwrap()
        let mirror_factor = @nodes.float(1.2).sub(factor)
        Some(@nodes.mix(factor, mirror_factor, radius))
      },
      layout=addon_short_layout(
        [("factor", "float"), ("radius", "float")],
        "float",
      ),
    )
    { _quad_mesh, luminosity_high_pass, lerp_bloom_factor, }
  },
)

///|
/// Evaluates BloomNode.js (`_quadMesh`, `luminosityHighPass`, `lerpBloomFactor`), as
/// `import` does.
pub fn load_display_bloom_node() -> Unit {
  display_bloom_node_module.get() |> ignore
}

///|
/// A separable blur material of the bloom mip chain with its uniforms (the ad-hoc
/// `colorTexture`, `direction` and `invSize` material properties upstream).
pub(all) struct BloomSeparableBlurMaterial {
  material : @core.Material
  color_texture : @nodes.Node
  direction : @nodes.Node
  inv_size : @nodes.Node
}

///|
/// Post processing node for creating a bloom effect (UnrealBloomPass).
pub(all) struct BloomNode {
  mut input_node : @nodes.Node
  mut strength : @nodes.Node
  mut radius : @nodes.Node
  mut threshold : @nodes.Node
  mut smooth_width : @nodes.Node
  bloom_tint_colors : Array[@math.Vector3]
  mut _resolution_scale : Double
  /// `highPassFn`: called with `{ input, threshold, smoothWidth }`.
  mut high_pass_fn : @nodes.Node
  _render_targets_horizontal : Array[@core.RenderTarget]
  _render_targets_vertical : Array[@core.RenderTarget]
  _n_mips : Int32
  _render_target_bright : @core.RenderTarget
  mut _composite_material : @core.Material?
  mut _high_pass_filter_material : @core.Material?
  _separable_blur_materials : Array[BloomSeparableBlurMaterial]
  _texture_node_bright : @nodes.Node
  _texture_node_blur0 : @nodes.Node
  _texture_node_blur1 : @nodes.Node
  _texture_node_blur2 : @nodes.Node
  _texture_node_blur3 : @nodes.Node
  _texture_node_blur4 : @nodes.Node
  _texture_output : @nodes.Node
}

///|
pub impl @nodes.NodeClass for BloomNode with fn class_name(_) {
  "BloomNode"
}

///|
pub impl @nodes.NodeClass for BloomNode with fn children(self, _, out) {
  @nodes.push_child(out, "inputNode", Some(self.input_node))
  @nodes.push_child(out, "strength", Some(self.strength))
  @nodes.push_child(out, "radius", Some(self.radius))
  @nodes.push_child(out, "threshold", Some(self.threshold))
  @nodes.push_child(out, "smoothWidth", Some(self.smooth_width))
  @nodes.push_child(out, "highPassFn", Some(self.high_pass_fn))
}

///|
pub impl @nodes.NodeClass for BloomNode with fn set_size(self, _, width, height) {
  self.set_size(width, height)
  true
}

///|
pub impl @nodes.NodeClass for BloomNode with fn update_before(self, _, frame) {
  let renderer = frame.renderer.unwrap()
  let quad_mesh = display_bloom_node_module.get()._quad_mesh
  _bloom_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(renderer, state?=_bloom_node_renderer_state.val),
  )
  //
  let size = renderer.get_drawing_buffer_size(_bloom_node_size)
  self.set_size(size.x, size.y)
  // 1. Extract bright areas
  renderer.set_render_target(Some(self._render_target_bright))
  quad_mesh.set_material(self._high_pass_filter_material.unwrap())
  quad_mesh.object.name = "Bloom [ High Pass ]"
  quad_mesh.render(renderer)
  // 2. Blur all the mips progressively
  let mut input_render_target = self._render_target_bright
  for i in 0..<self._n_mips {
    let blur = self._separable_blur_materials[i]
    quad_mesh.set_material(blur.material)
    @nodes.TextureNode::set_value(
      blur.color_texture,
      Some(input_render_target.texture()),
    )
    @nodes.InputNode::set_value(
      blur.direction,
      Vector2(_bloom_node_blur_direction_x),
    )
    renderer.set_render_target(Some(self._render_targets_horizontal[i]))
    quad_mesh.object.name = "Bloom [ Blur Horizontal - \{i} ]"
    quad_mesh.render(renderer)
    @nodes.TextureNode::set_value(
      blur.color_texture,
      Some(self._render_targets_horizontal[i].texture()),
    )
    @nodes.InputNode::set_value(
      blur.direction,
      Vector2(_bloom_node_blur_direction_y),
    )
    renderer.set_render_target(Some(self._render_targets_vertical[i]))
    quad_mesh.object.name = "Bloom [ Blur Vertical - \{i} ]"
    quad_mesh.render(renderer)
    input_render_target = self._render_targets_vertical[i]
  }
  // 3. Composite all the mips
  renderer.set_render_target(Some(self._render_targets_horizontal[0]))
  quad_mesh.set_material(self._composite_material.unwrap())
  quad_mesh.object.name = "Bloom [ Composite ]"
  quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(
    renderer,
    _bloom_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for BloomNode with fn setup(self, _, builder) {
  let m = display_bloom_node_module.get()
  let shared_context = @nodes.context(value=builder.get_shared_context())
  // luminosity high pass material
  let high_pass_filter_material = match self._high_pass_filter_material {
    Some(material) => material
    None => @nodes.NodeMaterial::new()
  }
  self._high_pass_filter_material = Some(high_pass_filter_material)
  let high_pass = @nodes.NodeMaterial::of(high_pass_filter_material).unwrap()
  high_pass.context_node = Some(shared_context)
  high_pass.fragment_node = Some(
    self.high_pass_fn.call_named({
      "input": self.input_node,
      "threshold": self.threshold,
      "smoothWidth": self.smooth_width,
    }),
  )
  high_pass_filter_material.name = "Bloom_highPass"
  high_pass_filter_material.set_needs_update(true)
  // gaussian blur materials
  // These sizes have been changed to account for the altered coefficients-calculation to avoid blockiness,
  // while retaining the same blur-strength. For details see https://github.com/mrdoob/three.js/pull/31528
  let kernel_size_array = [6, 10, 14, 18, 22]
  for i in 0..<self._n_mips {
    self._separable_blur_materials.push(
      BloomNode::get_separable_blur_material(
        shared_context,
        kernel_size_array[i],
      ),
    )
  }
  // composite material
  let bloom_factors = @nodes.array([1.0, 0.8, 0.6, 0.4, 0.2])
  let bloom_tint_colors = @nodes.uniform_array(
    @nodes.TslValue::Array(self.bloom_tint_colors.map(fn(c) { Vector3(c) })),
  )
  let composite_pass = @nodes.fn_(fn(_, _) {
    let color0 = m.lerp_bloom_factor
      .call([bloom_factors.element(0), self.radius])
      .mul(@nodes.vec4_of([bloom_tint_colors.element(0), 1.0]))
      .mul(self._texture_node_blur0)
    let color1 = m.lerp_bloom_factor
      .call([bloom_factors.element(1), self.radius])
      .mul(@nodes.vec4_of([bloom_tint_colors.element(1), 1.0]))
      .mul(self._texture_node_blur1)
    let color2 = m.lerp_bloom_factor
      .call([bloom_factors.element(2), self.radius])
      .mul(@nodes.vec4_of([bloom_tint_colors.element(2), 1.0]))
      .mul(self._texture_node_blur2)
    let color3 = m.lerp_bloom_factor
      .call([bloom_factors.element(3), self.radius])
      .mul(@nodes.vec4_of([bloom_tint_colors.element(3), 1.0]))
      .mul(self._texture_node_blur3)
    let color4 = m.lerp_bloom_factor
      .call([bloom_factors.element(4), self.radius])
      .mul(@nodes.vec4_of([bloom_tint_colors.element(4), 1.0]))
      .mul(self._texture_node_blur4)
    let sum = color0.add(color1).add(color2).add(color3).add(color4)
    Some(sum.mul(self.strength))
  })
  let composite_material = match self._composite_material {
    Some(material) => material
    None => @nodes.NodeMaterial::new()
  }
  self._composite_material = Some(composite_material)
  let composite = @nodes.NodeMaterial::of(composite_material).unwrap()
  composite.context_node = Some(shared_context)
  composite.fragment_node = Some(composite_pass.call([]))
  composite_material.name = "Bloom_comp"
  composite_material.set_needs_update(true)
  //
  Some(self._texture_output)
}

///|
pub impl @nodes.NodeClass for BloomNode with fn dispose(self, node) {
  node.dispose_base()
  for render_target in self._render_targets_horizontal {
    render_target.dispose()
  }
  for render_target in self._render_targets_vertical {
    render_target.dispose()
  }
  self._render_target_bright.dispose()
  if self._high_pass_filter_material is Some(material) {
    material.dispose()
  }
  if self._composite_material is Some(material) {
    material.dispose()
  }
  for blur in self._separable_blur_materials {
    blur.material.dispose()
  }
}

///|
/// `getTextureNode()`: the bloom result.
pub fn BloomNode::get_texture_node(self : BloomNode) -> @nodes.Node {
  self._texture_output
}

///|
/// `setResolutionScale( resolutionScale )`.
pub fn BloomNode::set_resolution_scale(
  self : BloomNode,
  resolution_scale : Double,
) -> BloomNode {
  self._resolution_scale = resolution_scale
  self
}

///|
/// `getResolutionScale()`.
pub fn BloomNode::get_resolution_scale(self : BloomNode) -> Double {
  self._resolution_scale
}

///|
/// `setSize( width, height )`: sizes the mip chain from the scaled resolution.
pub fn BloomNode::set_size(
  self : BloomNode,
  width : Double,
  height : Double,
) -> Unit {
  let mut resx = (width * self._resolution_scale).floor()
  let mut resy = (height * self._resolution_scale).floor()
  self._render_target_bright.set_size(resx.to_int(), resy.to_int())
  for i in 0..<self._n_mips {
    self._render_targets_horizontal[i].set_size(resx.to_int(), resy.to_int())
    self._render_targets_vertical[i].set_size(resx.to_int(), resy.to_int())
    bloom_node_uniform_vector2(self._separable_blur_materials[i].inv_size).set(
      1.0 / resx,
      1.0 / resy,
    )
    |> ignore
    resx = (resx / 2.0).floor()
    resy = (resy / 2.0).floor()
  }
}

///|
/// `_getSeparableBlurMaterial( sharedContext, kernelRadius )`.
fn BloomNode::get_separable_blur_material(
  shared_context : @nodes.Node,
  kernel_radius : Int32,
) -> BloomSeparableBlurMaterial {
  let coefficients : Array[Double] = []
  let kr = kernel_radius.to_double()
  let sigma = kr / 3.0
  for i in 0..<kernel_radius {
    let fi = i.to_double()
    coefficients.push(
      0.39894 * bloom_node_math_exp(-0.5 * fi * fi / (sigma * sigma)) / sigma,
    )
  }
  // Merge adjacent taps into single bilinear fetches (linear sampling).
  let center_weight = coefficients[0]
  let offsets : Array[Double] = []
  let weights : Array[Double] = []
  let mut i = 1
  while i < kernel_radius {
    let wa = coefficients[i]
    let wb = if i + 1 < kernel_radius { coefficients[i + 1] } else { 0.0 }
    let w = wa + wb
    offsets.push((i.to_double() * wa + (i + 1).to_double() * wb) / w)
    weights.push(w)
    i += 2
  }
  //
  let color_texture = @nodes.texture(@nodes.TslValue::Null)
  let gaussian_offsets = @nodes.array(
    offsets.map(fn(o) -> &@nodes.IntoTsl { o }),
  )
  let gaussian_weights = @nodes.array(
    weights.map(fn(w) -> &@nodes.IntoTsl { w }),
  )
  let inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let direction = @nodes.uniform(@math.Vector2::new(0.5, 0.5))
  let uv_node = @nodes.uv()
  let sample_texel = fn(uv : @nodes.Node) { color_texture.sample(uv) }
  let separable_blur_pass = @nodes.fn_(fn(_, _) {
    let diffuse_sum = sample_texel(uv_node).rgb().mul(center_weight).to_var()
    @nodes.loop_(
      [
        @nodes.loop_range(
          start=@nodes.int(0),
          end=@nodes.int(offsets.length()),
          type_="int",
          condition="<",
        ),
      ],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        let w = gaussian_weights.element(i)
        let uv_offset = direction.mul(inv_size).mul(gaussian_offsets.element(i))
        let sample1 = sample_texel(uv_node.add(uv_offset)).rgb()
        let sample2 = sample_texel(uv_node.sub(uv_offset)).rgb()
        diffuse_sum.add_assign(@nodes.add(sample1, sample2).mul(w))
      },
    )
    Some(@nodes.vec4_of([diffuse_sum, 1.0]))
  })
  let separable_blur_material = @nodes.NodeMaterial::new()
  let blur = @nodes.NodeMaterial::of(separable_blur_material).unwrap()
  blur.context_node = Some(shared_context)
  blur.fragment_node = Some(separable_blur_pass.call([]))
  separable_blur_material.name = "Bloom_separable"
  separable_blur_material.set_needs_update(true)
  // uniforms
  { material: separable_blur_material, color_texture, direction, inv_size, }
}

///|
fn bloom_node_uniform_vector2(node : @nodes.Node) -> @math.Vector2 {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => v
    _ => abort("uniform value is not a Vector2")
  }
}

///|
/// `new BloomNode( inputNode, strength = 1, radius = 0, threshold = 0 )`; each value is a
/// node or a number (wrapped in a uniform).
pub fn BloomNode::new(
  input_node : @nodes.Node,
  strength~ : &@nodes.IntoTsl = 1.0,
  radius~ : &@nodes.IntoTsl = 0.0,
  threshold~ : &@nodes.IntoTsl = 0.0,
) -> @nodes.Node {
  let m = display_bloom_node_module.get()
  let node = @nodes.Node::alloc(node_type="vec4")
  let strength = addon_node_or_uniform(strength)
  let radius = addon_node_or_uniform(radius)
  let threshold = addon_node_or_uniform(threshold)
  let smooth_width = @nodes.uniform(0.01)
  let bloom_tint_colors = [
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(1.0, 1.0, 1.0),
  ]
  let render_targets_horizontal = []
  let render_targets_vertical = []
  let n_mips = 5
  let render_target_bright = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  render_target_bright.texture().name = "UnrealBloomPass.bright"
  render_target_bright.texture().generate_mipmaps = false
  //
  for i in 0..<n_mips {
    let render_target_horizontal = @core.RenderTarget::new(
      width=1,
      height=1,
      depth_buffer=false,
      type_=@core.HalfFloatType,
    )
    render_target_horizontal.texture().name = "UnrealBloomPass.h\{i}"
    render_target_horizontal.texture().generate_mipmaps = false
    render_targets_horizontal.push(render_target_horizontal)
    let render_target_vertical = @core.RenderTarget::new(
      width=1,
      height=1,
      depth_buffer=false,
      type_=@core.HalfFloatType,
    )
    render_target_vertical.texture().name = "UnrealBloomPass.v\{i}"
    render_target_vertical.texture().generate_mipmaps = false
    render_targets_vertical.push(render_target_vertical)
  }
  let texture_node_bright = @nodes.texture(render_target_bright.texture())
  let texture_node_blur0 = @nodes.texture(render_targets_vertical[0].texture())
  let texture_node_blur1 = @nodes.texture(render_targets_vertical[1].texture())
  let texture_node_blur2 = @nodes.texture(render_targets_vertical[2].texture())
  let texture_node_blur3 = @nodes.texture(render_targets_vertical[3].texture())
  let texture_node_blur4 = @nodes.texture(render_targets_vertical[4].texture())
  let texture_output = @nodes.pass_texture(
    node,
    render_targets_horizontal[0].texture(),
  )
  node.update_before_type = @nodes.NodeUpdateType::frame()
  node.set_class(BloomNode::{
    input_node,
    strength,
    radius,
    threshold,
    smooth_width,
    bloom_tint_colors,
    _resolution_scale: 0.5,
    high_pass_fn: m.luminosity_high_pass,
    _render_targets_horizontal: render_targets_horizontal,
    _render_targets_vertical: render_targets_vertical,
    _n_mips: n_mips,
    _render_target_bright: render_target_bright,
    _composite_material: None,
    _high_pass_filter_material: None,
    _separable_blur_materials: [],
    _texture_node_bright: texture_node_bright,
    _texture_node_blur0: texture_node_blur0,
    _texture_node_blur1: texture_node_blur1,
    _texture_node_blur2: texture_node_blur2,
    _texture_node_blur3: texture_node_blur3,
    _texture_node_blur4: texture_node_blur4,
    _texture_output: texture_output,
  })
}

///|
pub fn BloomNode::of(node : @nodes.Node) -> BloomNode? {
  addon_class_of(node, "BloomNode")
}

///|
/// `bloom( node, strength, radius, threshold )`.
pub fn bloom(
  node : &@nodes.IntoTsl,
  strength~ : &@nodes.IntoTsl = 1.0,
  radius~ : &@nodes.IntoTsl = 0.0,
  threshold~ : &@nodes.IntoTsl = 0.0,
) -> @nodes.Node {
  display_bloom_node_module.get() |> ignore
  BloomNode::new(addon_node_object(node), strength~, radius~, threshold~)
}
