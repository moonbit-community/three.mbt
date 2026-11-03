// nodes/utils/RTTNode.js: renders a node into a render target with a full-screen quad
// and samples the result as a texture (`rtt()`, `convertToTexture()`).

///|
let _rtt_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
extern "js" fn rtt_node_math_floor(x : Double) -> Double = "Math.floor"

///|
/// A texture node holding the rendering of `node`.
pub(all) struct RTTNode {
  texture : TextureNode
  mut node : Node
  /// `None` is `null`: the size follows the drawing buffer (`autoResize`).
  mut width : Double?
  mut height : Double?
  render_target : @core.RenderTarget
  mut texture_needs_update : Bool
  mut auto_update : Bool
  mut _resolution_scale : Double
  _quad_mesh : QuadMesh
  _renderer_state : RendererState
}

///|
pub impl NodeClass for RTTNode with fn class_name(_) {
  "RTTNode"
}

///|
pub impl NodeClass for RTTNode with fn parent(self) {
  Some(self.texture)
}

///|
pub impl NodeClass for RTTNode with fn has_flag(self, flag) {
  flag == "isRTTNode" || self.texture.has_flag(flag)
}

///|
pub impl NodeClass for RTTNode with fn children(self, node, out) {
  self.texture.children(node, out)
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for RTTNode with fn setup(self, node, builder) {
  let material = self._quad_mesh.material()
  let node_material = NodeMaterial::of(material).unwrap()
  node_material.context_node = Some(context(value=builder.get_shared_context()))
  node_material.fragment_node = Some(self.node)
  material.name = "RTT"
  material.set_needs_update(true)
  NodeClass::setup(self.texture, node, builder)
}

///|
pub impl NodeClass for RTTNode with fn update_before(self, node, frame) {
  let renderer = frame.renderer.unwrap()
  if self.texture_needs_update == false && self.auto_update == false {
    return None
  }
  self.texture_needs_update = false
  //
  if self.auto_resize() {
    let size = renderer.get_drawing_buffer_size(_rtt_node_size)
    let effective_width = rtt_node_math_floor(size.x * self._resolution_scale).to_int()
    let effective_height = rtt_node_math_floor(size.y * self._resolution_scale).to_int()
    if effective_width != self.render_target.width ||
      effective_height != self.render_target.height {
      self.render_target.set_size(effective_width, effective_height)
      self.texture_needs_update = true
    }
  }
  //
  let mut name = "RTT"
  let call_name = match node.name {
    Some(n) if n != "" => Some(n)
    _ => self.node.name
  }
  match call_name {
    Some(c) if c != "" => name = c + " [ " + name + " ]"
    _ => ()
  }
  self._quad_mesh.object.name = name
  //
  reset_renderer_state(renderer, state=self._renderer_state) |> ignore
  // keep clear color/alpha
  renderer.set_clear_color(
    self._renderer_state.clear_color.unwrap(),
    alpha=self._renderer_state.clear_alpha,
  )
  renderer.set_render_target(Some(self.render_target))
  self._quad_mesh.render(renderer)
  restore_renderer_state(renderer, self._renderer_state)
  None
}

///|
pub impl NodeClass for RTTNode with fn dispose(self, node) {
  self.render_target.dispose()
  self._quad_mesh.material().dispose()
  NodeClass::dispose(self.texture, node)
}

///|
pub impl InputNodeClass for RTTNode with fn input_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for RTTNode with fn texture_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for RTTNode with fn get_value(self, _) {
  Some(self.render_target.texture())
}

///|
pub impl TextureNodeClass for RTTNode with fn set_value(self, _, value) {
  if !(value is Some(v) && physical_equal(v, self.render_target.texture())) {
    @core.error("TSL: \"rtt()\" does not allow overwriting the value.")
  }
}

///|
pub impl TextureNodeClass for RTTNode with fn clone(self, node) {
  let t = self.texture
  let new_node = TextureNode::new(
    value=Some(self.render_target.texture()),
    uv_node?=t.uv_node,
    level_node?=t.level_node,
  )
  let n = TextureNode::of(new_node).unwrap()
  n.sampler = t.sampler
  n.reference_node = Some(node)
  new_node
}

///|
/// `get autoResize()`.
pub fn RTTNode::auto_resize(self : RTTNode) -> Bool {
  self.width is None
}

///|
/// `setSize( width, height )`.
pub fn RTTNode::set_size(
  self : RTTNode,
  width : Double,
  height : Double,
) -> Unit {
  let effective_width = rtt_node_math_floor(width * self._resolution_scale)
  let effective_height = rtt_node_math_floor(height * self._resolution_scale)
  self.render_target.set_size(
    effective_width.to_int(),
    effective_height.to_int(),
  )
  self.texture_needs_update = true
}

///|
/// `setResolutionScale( resolutionScale )`.
pub fn RTTNode::set_resolution_scale(
  self : RTTNode,
  resolution_scale : Double,
) -> RTTNode {
  self._resolution_scale = resolution_scale
  if self.auto_resize() == false {
    self.set_size(self.width.unwrap(), self.height.unwrap())
  }
  self
}

///|
pub fn RTTNode::get_resolution_scale(self : RTTNode) -> Double {
  self._resolution_scale
}

///|
/// `new RTTNode( node, width = null, height = null, options = {} )`; the options are
/// the render target's (`type` defaults to `HalfFloatType`) plus `autoUpdate` and
/// `resolutionScale`.
pub fn RTTNode::new(
  node : Node,
  width? : Double,
  height? : Double,
  auto_update~ : Bool = true,
  resolution_scale~ : Double = 1.0,
  type_~ : Int32 = @core.HalfFloatType,
  format? : Int32,
  depth_buffer? : Bool,
  stencil_buffer? : Bool,
  samples? : Int32,
  generate_mipmaps? : Bool,
  min_filter? : Int32,
  mag_filter? : Int32,
  color_space? : String,
) -> Node {
  let render_target = @core.RenderTarget::new(
    width=width.unwrap_or(1.0).to_int(),
    height=height.unwrap_or(1.0).to_int(),
    type_~,
    format?,
    depth_buffer?,
    stencil_buffer?,
    samples?,
    generate_mipmaps?,
    min_filter?,
    mag_filter?,
    color_space?,
  )
  // `uv()` is an argument of `super()`, created before this node's id
  let uv_node = uv()
  let this = Node::alloc()
  let texture = TextureNode::construct(
    this,
    Some(render_target.texture()),
    Some(uv_node),
    None,
    None,
  )
  let payload = {
    texture,
    node,
    width,
    height,
    render_target,
    texture_needs_update: true,
    auto_update,
    _resolution_scale: resolution_scale,
    _quad_mesh: QuadMesh::new(material=NodeMaterial::new()),
    _renderer_state: RendererState::new(),
  }
  this.update_before_type = NodeUpdateType::frame()
  texture.install(this, payload, payload, payload)
}

///|
pub fn RTTNode::of(node : Node) -> RTTNode? {
  match node.class_payload("RTTNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `rtt( node, width, height, options )`.
pub fn rtt(
  node : &IntoTsl,
  width? : Double,
  height? : Double,
  auto_update~ : Bool = true,
  resolution_scale~ : Double = 1.0,
  type_~ : Int32 = @core.HalfFloatType,
) -> Node {
  RTTNode::new(
    node_object(node.to_tsl()),
    width?,
    height?,
    auto_update~,
    resolution_scale~,
    type_~,
  )
}

///|
/// `convertToTexture( node, width, height, options )`: the node itself when it is
/// already a texture, the pass's texture node, or an `rtt()`.
pub fn convert_to_texture(
  node : Node,
  width? : Double,
  height? : Double,
  auto_update~ : Bool = true,
  resolution_scale~ : Double = 1.0,
  type_~ : Int32 = @core.HalfFloatType,
) -> Node {
  if node.has_flag("isSampleNode") || node.has_flag("isTextureNode") {
    return node
  }
  if node.has_flag("isPassNode") {
    return node.get_texture_node()
  }
  rtt(node, width?, height?, auto_update~, resolution_scale~, type_~)
}
