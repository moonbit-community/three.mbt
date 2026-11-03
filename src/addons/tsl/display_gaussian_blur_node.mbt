// examples/jsm/tsl/display/GaussianBlurNode.js

///|
extern "js" fn gaussian_blur_node_math_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn gaussian_blur_node_math_exp(x : Double) -> Double = "Math.exp"

///|
/// The module's top-level state: `_quadMesh` and `_rendererState`.
priv struct GaussianBlurNodeModule {
  quad_mesh : @nodes.QuadMesh
  mut renderer_state : @nodes.RendererState?
}

///|
let gaussian_blur_node_module : AddonModule[GaussianBlurNodeModule] = AddonModule::new(fn() {
    { quad_mesh: @nodes.QuadMesh::new(), renderer_state: None, }
  },
)

///|
/// Evaluates GaussianBlurNode.js's top-level statements (`import`).
pub fn load_display_gaussian_blur_node() -> Unit {
  gaussian_blur_node_module.get() |> ignore
}

///|
/// Post processing node for a separable gaussian blur (a horizontal and a vertical pass
/// into internal render targets).
pub(all) struct GaussianBlurNode {
  mut texture_node : @nodes.Node
  /// `directionNode`: a node, a value `vec2()` converts, or `Null`.
  mut direction_node : @nodes.TslValue
  mut sigma : Double
  _inv_size : @nodes.Node
  _horizontal_rt : @core.RenderTarget
  _vertical_rt : @core.RenderTarget
  _texture_node : @nodes.Node
  mut _h_material : @core.Material?
  mut _v_material : @core.Material?
  mut resolution_scale : Double
  mut premultiplied_alpha : Bool
}

///|
pub impl @nodes.NodeClass for GaussianBlurNode with fn class_name(_) {
  "GaussianBlurNode"
}

///|
pub impl @nodes.NodeClass for GaussianBlurNode with fn has_flag(_, flag) {
  flag == "isGaussianBlurNode"
}

///|
pub impl @nodes.NodeClass for GaussianBlurNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  if self.direction_node is Node(n) {
    @nodes.push_child(out, "directionNode", Some(n))
  }
}

///|
pub impl @nodes.NodeClass for GaussianBlurNode with fn update_before(
  self,
  _,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let m = gaussian_blur_node_module.get()
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  //
  let map = @nodes.TextureNode::get_value(self.texture_node)
  m.quad_mesh.set_material(self._h_material.unwrap())
  self.set_size(map.image().width(), map.image().height())
  let texture_type = map.type_
  self._horizontal_rt.texture().type_ = texture_type
  self._vertical_rt.texture().type_ = texture_type
  // horizontal
  renderer.set_render_target(Some(self._horizontal_rt))
  m.quad_mesh.object.name = "Gaussian Blur [ Horizontal Pass ]"
  m.quad_mesh.render(renderer)
  // vertical
  m.quad_mesh.set_material(self._v_material.unwrap())
  renderer.set_render_target(Some(self._vertical_rt))
  m.quad_mesh.object.name = "Gaussian Blur [ Vertical Pass ]"
  m.quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for GaussianBlurNode with fn setup(
  self,
  node,
  builder,
) {
  let uv_node = @nodes.uv()
  let direction_node = @nodes.vec2(
    if addon_truthy(self.direction_node) {
      self.direction_node
    } else {
      Number(1.0)
    },
  )
  let blur = @nodes.fn_(fn(inputs, _) {
    let texture_node = inputs.get(0).unwrap()
    let pass_direction = inputs.get(1).unwrap()
    let (sample_texture, output) : (
      (@nodes.Node) -> @nodes.Node,
      (@nodes.Node) -> @nodes.Node,
    ) = if self.premultiplied_alpha {
      // https://lisyarus.github.io/blog/posts/blur-coefficients-generator.html
      (
        fn(uv) { @nodes.premultiply_alpha.call([texture_node.sample(uv)]) },
        fn(color) { @nodes.unpremultiply_alpha.call([color]) },
      )
    } else {
      (fn(uv) { texture_node.sample(uv) }, fn(color) { color })
    }
    let kernel_size = 3.0 + 2.0 * self.sigma
    let gaussian_coefficients = GaussianBlurNode::get_coefficients(kernel_size)
    let inv_size = self._inv_size
    let direction = direction_node.mul(pass_direction)
    let diffuse_sum = @nodes.vec4(
      sample_texture(uv_node).mul(gaussian_coefficients[0]),
    ).to_var()
    let mut i = 1
    while i.to_double() < kernel_size {
      let x = @nodes.float(i)
      let w = @nodes.float(gaussian_coefficients[i])
      let uv_offset = @nodes.vec2(direction.mul(inv_size.mul(x))).to_var()
      let sample1 = sample_texture(uv_node.add(uv_offset))
      let sample2 = sample_texture(uv_node.sub(uv_offset))
      diffuse_sum.add_assign(sample1.add(sample2).mul(w))
      i += 1
    }
    Some(output(diffuse_sum))
  })
  //
  let h_texture_node = self.texture_node
  let h_material = match self._h_material {
    Some(m) => m
    None => @nodes.NodeMaterial::new()
  }
  self._h_material = Some(h_material)
  let h = @nodes.NodeMaterial::of(h_material).unwrap()
  h.context_node = Some(@nodes.context(value=builder.get_shared_context()))
  h.fragment_node = Some(blur.call([h_texture_node, @nodes.vec2_of([1, 0])]))
  h_material.name = "Gaussian_blur_horizontal"
  h_material.set_needs_update(true)
  let v_texture_node = @nodes.texture(
    self._horizontal_rt.texture(),
    uv_node=@nodes.uv(),
  )
  let v_material = match self._v_material {
    Some(m) => m
    None => @nodes.NodeMaterial::new()
  }
  self._v_material = Some(v_material)
  let v = @nodes.NodeMaterial::of(v_material).unwrap()
  v.fragment_node = Some(blur.call([v_texture_node, @nodes.vec2_of([0, 1])]))
  v_material.name = "Gaussian_blur_vertical"
  v_material.set_needs_update(true)
  //
  let properties = builder.get_node_properties(node)
  properties.set_node("hTextureNode", h_texture_node)
  properties.set_node("vTextureNode", v_texture_node)
  //
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for GaussianBlurNode with fn dispose(self, node) {
  self._horizontal_rt.dispose()
  self._vertical_rt.dispose()
  if self._h_material is Some(h) {
    h.dispose()
    self._v_material.unwrap().dispose()
    self._h_material = None
    self._v_material = None
  }
  node.dispose_base()
}

///|
/// `setSize( width, height )`: the render targets' size, scaled by `resolutionScale`.
pub fn GaussianBlurNode::set_size(
  self : GaussianBlurNode,
  width : Double,
  height : Double,
) -> Unit {
  let width = @webgl.js_math_max(
    gaussian_blur_node_math_round(width * self.resolution_scale),
    1,
  )
  let height = @webgl.js_math_max(
    gaussian_blur_node_math_round(height * self.resolution_scale),
    1,
  )
  a4_uniform_vector2(self._inv_size).set(1.0 / width, 1.0 / height) |> ignore
  self._horizontal_rt.set_size(width.to_int(), height.to_int())
  self._vertical_rt.set_size(width.to_int(), height.to_int())
}

///|
/// `getTextureNode()`: the blurred result.
pub fn GaussianBlurNode::get_texture_node(
  self : GaussianBlurNode,
) -> @nodes.Node {
  self._texture_node
}

///|
/// `_getCoefficients( kernelRadius )`: the normalized gaussian weights.
fn GaussianBlurNode::get_coefficients(kernel_radius : Double) -> Array[Double] {
  let coefficients = []
  let sigma = kernel_radius / 3.0
  let mut sum = 1.0
  coefficients.push(1.0)
  let mut i = 1
  while i.to_double() < kernel_radius {
    let fi = i.to_double()
    let w = gaussian_blur_node_math_exp(-0.5 * fi * fi / (sigma * sigma))
    coefficients.push(w)
    sum += 2.0 * w
    i += 1
  }
  coefficients.map(fn(c) { c / sum })
}

///|
/// `new GaussianBlurNode( textureNode, directionNode = null, sigma = 4, options = {} )`;
/// the options are `resolutionScale` and `premultipliedAlpha`.
pub fn GaussianBlurNode::new(
  texture_node : @nodes.Node,
  direction_node? : &@nodes.IntoTsl,
  sigma~ : Double = 4.0,
  resolution_scale? : Double,
  premultiplied_alpha? : Bool,
) -> @nodes.Node {
  gaussian_blur_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let direction_node : @nodes.TslValue = match direction_node {
    Some(d) => d.to_tsl()
    None => Null
  }
  let _inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let _horizontal_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  _horizontal_rt.texture().name = "GaussianBlurNode.horizontal"
  let _vertical_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  _vertical_rt.texture().name = "GaussianBlurNode.vertical"
  let _texture_node = @nodes.pass_texture(node, _vertical_rt.texture())
  @nodes.TextureNode::of(_texture_node).unwrap().uv_node = a4_texture_uv_node(
    texture_node,
  )
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let resolution_scale = match resolution_scale {
    Some(s) if addon_truthy(Number(s)) => s
    _ => 1.0
  }
  let premultiplied_alpha = premultiplied_alpha.unwrap_or(false)
  node.set_class(GaussianBlurNode::{
    texture_node,
    direction_node,
    sigma,
    _inv_size,
    _horizontal_rt,
    _vertical_rt,
    _texture_node,
    _h_material: None,
    _v_material: None,
    resolution_scale,
    premultiplied_alpha,
  })
}

///|
pub fn GaussianBlurNode::of(node : @nodes.Node) -> GaussianBlurNode? {
  addon_class_of(node, "GaussianBlurNode")
}

///|
/// `gaussianBlur( node, directionNode, sigma, options = {} )`.
pub fn gaussian_blur(
  node : @nodes.Node,
  direction_node? : &@nodes.IntoTsl,
  sigma~ : Double = 4.0,
  resolution_scale? : Double,
  premultiplied_alpha? : Bool,
) -> @nodes.Node {
  GaussianBlurNode::new(
    @nodes.convert_to_texture(node),
    direction_node?,
    sigma~,
    resolution_scale?,
    premultiplied_alpha?,
  )
}

///|
/// `premultipliedGaussianBlur( node, directionNode, sigma )` (deprecated upstream:
/// `gaussianBlur()` with `premultipliedAlpha: true`).
pub fn premultiplied_gaussian_blur(
  node : @nodes.Node,
  direction_node? : &@nodes.IntoTsl,
  sigma~ : Double = 4.0,
) -> @nodes.Node {
  @core.warn_once(
    "THREE.TSL: \"premultipliedGaussianBlur()\" is deprecated. Use \"gaussianBlur()\" with \"premultipliedAlpha: true\" option instead.",
  )
  gaussian_blur(node, direction_node?, sigma~, premultiplied_alpha=true)
}
