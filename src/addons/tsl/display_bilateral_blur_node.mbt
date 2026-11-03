// examples/jsm/tsl/display/BilateralBlurNode.js

///|
extern "js" fn bilateral_blur_node_math_exp(x : Double) -> Double = "Math.exp"

///|
extern "js" fn bilateral_blur_node_math_round(x : Double) -> Double = "Math.round"

///|
priv struct BilateralBlurNodeModule {
  _quad_mesh : @nodes.QuadMesh
}

///|
let display_bilateral_blur_node_module : AddonModule[BilateralBlurNodeModule] = AddonModule::new(fn() {
    { _quad_mesh: @nodes.QuadMesh::new(), }
  },
)

///|
let _bilateral_blur_node_renderer_state : Ref[@nodes.RendererState?] = Ref(None)

///|
/// Evaluates BilateralBlurNode.js (its `_quadMesh`), as `import` does.
pub fn load_display_bilateral_blur_node() -> Unit {
  display_bilateral_blur_node_module.get() |> ignore
}

///|
/// Post processing node for creating a bilateral blur effect (edge preserving: a
/// horizontal and a vertical pass weighted by spatial and luminance distance).
pub(all) struct BilateralBlurNode {
  /// The texture node that represents the input of the effect.
  mut texture_node : @nodes.Node
  /// `directionNode`: a node, a value `vec2()` converts, or `Null` (the default).
  mut direction_node : @nodes.TslValue
  /// Controls the spatial kernel size.
  mut sigma : Double
  /// Controls how much the luminance difference affects the weights.
  mut sigma_color : Double
  _inv_size : @nodes.Node
  _pass_direction : @nodes.Node
  _horizontal_rt : @core.RenderTarget
  _vertical_rt : @core.RenderTarget
  _texture_node : @nodes.Node
  mut _material : @core.Material?
  /// The resolution scale.
  mut resolution_scale : Double
}

///|
pub impl @nodes.NodeClass for BilateralBlurNode with fn class_name(_) {
  "BilateralBlurNode"
}

///|
pub impl @nodes.NodeClass for BilateralBlurNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  if self.direction_node is Node(n) {
    @nodes.push_child(out, "directionNode", Some(n))
  }
}

///|
pub impl @nodes.NodeClass for BilateralBlurNode with fn set_size(
  self,
  _,
  width,
  height,
) {
  self.set_size(width, height)
  true
}

///|
fn bilateral_blur_node_uniform_vector2(node : @nodes.Node) -> @math.Vector2 {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => v
    _ => abort("uniform value is not a Vector2")
  }
}

///|
/// `setSize( width, height )`: the render targets' size, scaled by `resolutionScale`.
pub fn BilateralBlurNode::set_size(
  self : BilateralBlurNode,
  width : Double,
  height : Double,
) -> Unit {
  let width = @webgl.js_math_max(
    bilateral_blur_node_math_round(width * self.resolution_scale),
    1,
  )
  let height = @webgl.js_math_max(
    bilateral_blur_node_math_round(height * self.resolution_scale),
    1,
  )
  bilateral_blur_node_uniform_vector2(self._inv_size).set(
    1.0 / width,
    1.0 / height,
  )
  |> ignore
  self._horizontal_rt.set_size(width.to_int(), height.to_int())
  self._vertical_rt.set_size(width.to_int(), height.to_int())
}

///|
pub impl @nodes.NodeClass for BilateralBlurNode with fn update_before(
  self,
  _,
  frame,
) {
  let renderer = frame.renderer.unwrap()
  let quad_mesh = display_bilateral_blur_node_module.get()._quad_mesh
  _bilateral_blur_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(
      renderer,
      state?=_bilateral_blur_node_renderer_state.val,
    ),
  )
  //
  let texture_node = self.texture_node
  let map = @nodes.TextureNode::get_value(texture_node)
  let current_texture = @nodes.TextureNode::get_value_opt(texture_node)
  quad_mesh.set_material(self._material.unwrap())
  self.set_size(map.image().width(), map.image().height())
  let texture_type = map.type_
  self._horizontal_rt.texture().type_ = texture_type
  self._vertical_rt.texture().type_ = texture_type
  // horizontal
  renderer.set_render_target(Some(self._horizontal_rt))
  bilateral_blur_node_uniform_vector2(self._pass_direction).set(1.0, 0.0)
  |> ignore
  quad_mesh.object.name = "Bilateral Blur [ Horizontal Pass ]"
  quad_mesh.render(renderer)
  // vertical
  @nodes.TextureNode::set_value(
    texture_node,
    Some(self._horizontal_rt.texture()),
  )
  renderer.set_render_target(Some(self._vertical_rt))
  bilateral_blur_node_uniform_vector2(self._pass_direction).set(0.0, 1.0)
  |> ignore
  quad_mesh.object.name = "Bilateral Blur [ Vertical Pass ]"
  quad_mesh.render(renderer)
  // restore
  @nodes.TextureNode::set_value(texture_node, current_texture)
  @nodes.restore_renderer_state(
    renderer,
    _bilateral_blur_node_renderer_state.val.unwrap(),
  )
  None
}

///|
/// `getTextureNode()`: the blurred result.
pub fn BilateralBlurNode::get_texture_node(
  self : BilateralBlurNode,
) -> @nodes.Node {
  self._texture_node
}

///|
pub impl @nodes.NodeClass for BilateralBlurNode with fn setup(
  self,
  node,
  builder,
) {
  let texture_node = self.texture_node
  //
  let uv_node = @nodes.uv()
  let direction_node = @nodes.vec2(
    if addon_truthy(self.direction_node) {
      self.direction_node
    } else {
      Number(1.0)
    },
  )
  let sample_texture = fn(uv : @nodes.Node) { texture_node.sample(uv) }
  let blur = @nodes.fn_(fn(_, _) {
    let kernel_size = self.sigma * 2.0 + 3.0
    let spatial_coefficients = BilateralBlurNode::get_spatial_coefficients(
      kernel_size,
    )
    let inv_size = self._inv_size
    let direction = direction_node.mul(self._pass_direction)
    // Sample center pixel
    let center_color = sample_texture(uv_node).to_var()
    let center_luminance = @nodes.luminance(center_color.rgb()).to_var()
    // Accumulate weighted samples
    let weight_sum = @nodes.float(spatial_coefficients[0]).to_var()
    let color_sum = @nodes.vec4(center_color.mul(spatial_coefficients[0])).to_var()
    // Precompute color sigma factor: -0.5 / (sigmaColor^2)
    let color_sigma_factor = @nodes.float(-0.5)
      .div(@nodes.float(self.sigma_color * self.sigma_color))
      .to_const()
    let mut i = 1
    while i.to_double() < kernel_size {
      let x = @nodes.float(i)
      let spatial_weight = @nodes.float(spatial_coefficients[i])
      let uv_offset = @nodes.vec2(direction.mul(inv_size.mul(x))).to_var()
      // Sample in both directions (+/-)
      let sample_uv1 = uv_node.add(uv_offset)
      let sample_uv2 = uv_node.sub(uv_offset)
      let sample1 = sample_texture(sample_uv1)
      let sample2 = sample_texture(sample_uv2)
      // Compute luminance difference for edge detection
      let lum1 = @nodes.luminance(sample1.rgb())
      let lum2 = @nodes.luminance(sample2.rgb())
      let diff1 = @nodes.abs(lum1.sub(center_luminance))
      let diff2 = @nodes.abs(lum2.sub(center_luminance))
      // Compute color-based weights using Gaussian function
      let color_weight1 = @nodes.exp(diff1.mul(diff1).mul(color_sigma_factor)).to_var()
      let color_weight2 = @nodes.exp(diff2.mul(diff2).mul(color_sigma_factor)).to_var()
      // Combined bilateral weight = spatial weight * color weight
      let bilateral_weight1 = spatial_weight.mul(color_weight1)
      let bilateral_weight2 = spatial_weight.mul(color_weight2)
      color_sum.add_assign(sample1.mul(bilateral_weight1))
      color_sum.add_assign(sample2.mul(bilateral_weight2))
      weight_sum.add_assign(bilateral_weight1)
      weight_sum.add_assign(bilateral_weight2)
      i += 1
    }
    // Normalize by the total weight
    Some(color_sum.div(@nodes.max(weight_sum, 0.0001)))
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
  node_material.fragment_node = Some(blur.call([]))
  material.name = "Bilateral_blur"
  material.set_needs_update(true)
  //
  let properties = builder.get_node_properties(node)
  properties.set_node("textureNode", texture_node)
  //
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for BilateralBlurNode with fn dispose(self, node) {
  node.dispose_base()
  self._horizontal_rt.dispose()
  self._vertical_rt.dispose()
  if self._material is Some(m) {
    m.dispose()
  }
}

///|
/// `_getSpatialCoefficients( kernelRadius )`: the gaussian spatial weights.
fn BilateralBlurNode::get_spatial_coefficients(
  kernel_radius : Double,
) -> Array[Double] {
  let coefficients = []
  let sigma = kernel_radius / 3.0
  let mut i = 0
  while i.to_double() < kernel_radius {
    let fi = i.to_double()
    coefficients.push(
      0.39894 *
      bilateral_blur_node_math_exp(-0.5 * fi * fi / (sigma * sigma)) /
      sigma,
    )
    i += 1
  }
  coefficients
}

///|
/// `new BilateralBlurNode( textureNode, directionNode = null, sigma = 4, sigmaColor = 0.1 )`.
pub fn BilateralBlurNode::new(
  texture_node : @nodes.Node,
  direction_node? : &@nodes.IntoTsl,
  sigma~ : Double = 4.0,
  sigma_color~ : Double = 0.1,
) -> @nodes.Node {
  display_bilateral_blur_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  let direction_node : @nodes.TslValue = match direction_node {
    Some(d) =>
      match d.to_tsl() {
        Undefined => Null
        v => v
      }
    None => Null
  }
  let inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let pass_direction = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let horizontal_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  horizontal_rt.texture().name = "BilateralBlurNode.horizontal"
  let vertical_rt = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
  )
  vertical_rt.texture().name = "BilateralBlurNode.vertical"
  let texture_node_ = @nodes.pass_texture(node, vertical_rt.texture())
  @nodes.TextureNode::of(texture_node_).unwrap().uv_node = addon_texture_uv_node(
    texture_node,
  )
  node.update_before_type = @nodes.NodeUpdateType::frame()
  node.set_class(BilateralBlurNode::{
    texture_node,
    direction_node,
    sigma,
    sigma_color,
    _inv_size: inv_size,
    _pass_direction: pass_direction,
    _horizontal_rt: horizontal_rt,
    _vertical_rt: vertical_rt,
    _texture_node: texture_node_,
    _material: None,
    resolution_scale: 1.0,
  })
}

///|
pub fn BilateralBlurNode::of(node : @nodes.Node) -> BilateralBlurNode? {
  addon_class_of(node, "BilateralBlurNode")
}

///|
/// `bilateralBlur( node, directionNode, sigma, sigmaColor )`.
pub fn bilateral_blur(
  node : @nodes.Node,
  direction_node? : &@nodes.IntoTsl,
  sigma~ : Double = 4.0,
  sigma_color~ : Double = 0.1,
) -> @nodes.Node {
  BilateralBlurNode::new(
    @nodes.convert_to_texture(node),
    direction_node?,
    sigma~,
    sigma_color~,
  )
}
