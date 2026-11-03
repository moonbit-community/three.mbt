// nodes/display/PassNode.js

///|
let _pass_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
/// The `options` of `pass( scene, camera, options )`: the `RenderTarget` options (with
/// `type` defaulting to `HalfFloatType`) plus the pass's own (`depthTexture`,
/// `autoClear*`). `None` is `undefined`.
pub(all) struct PassNodeOptions {
  type_ : Int32?
  format : Int32?
  samples : Int32?
  depth_buffer : Bool?
  stencil_buffer : Bool?
  generate_mipmaps : Bool?
  min_filter : Int32?
  mag_filter : Int32?
  count : Int32?
  depth_texture : @core.Texture?
  auto_clear : Bool?
  auto_clear_color : Bool?
  auto_clear_depth : Bool?
  auto_clear_stencil : Bool?
}

///|
/// `{}`.
pub fn PassNodeOptions::default() -> PassNodeOptions {
  {
    type_: None,
    format: None,
    samples: None,
    depth_buffer: None,
    stencil_buffer: None,
    generate_mipmaps: None,
    min_filter: None,
    mag_filter: None,
    count: None,
    depth_texture: None,
    auto_clear: None,
    auto_clear_color: None,
    auto_clear_depth: None,
    auto_clear_stencil: None,
  }
}

// ---------------------------------------------------------------------------
// PassTextureNode, PassMultipleTextureNode

///|
/// A texture of a pass, sampled in a later pass.
pub(all) struct PassTextureNode {
  texture : TextureNode
  mut pass_node : Node
}

///|
pub impl NodeClass for PassTextureNode with fn class_name(_) {
  "PassTextureNode"
}

///|
pub impl NodeClass for PassTextureNode with fn parent(self) {
  Some(self.texture)
}

///|
pub impl NodeClass for PassTextureNode with fn has_flag(self, flag) {
  flag == "isPassTextureNode" || self.texture.has_flag(flag)
}

///|
pub impl NodeClass for PassTextureNode with fn children(self, node, out) {
  self.texture.children(node, out)
  push_child(out, "passNode", Some(self.pass_node))
}

///|
pub impl NodeClass for PassTextureNode with fn is_cacheable(_, _, _) {
  true
}

///|
pub impl NodeClass for PassTextureNode with fn setup(self, node, builder) {
  let properties = builder.get_node_properties(node)
  properties.set_node("passNode", self.pass_node)
  self.texture.setup(node, builder)
}

///|
pub impl InputNodeClass for PassTextureNode with fn input_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for PassTextureNode with fn texture_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for PassTextureNode with fn clone(self, node) {
  PassTextureNode::new(self.pass_node, TextureNode::get_value_opt(node))
}

///|
pub fn PassTextureNode::construct(
  node : Node,
  pass_node : Node,
  texture : @core.Texture?,
) -> PassTextureNode {
  let t = TextureNode::construct(node, texture, None, None, None)
  // `this.setUpdateMatrix( false )`
  t.update_matrix = false
  { texture: t, pass_node, }
}

///|
/// `new PassTextureNode( passNode, texture )`.
pub fn PassTextureNode::new(pass_node : Node, texture : @core.Texture?) -> Node {
  let node = Node::alloc()
  let p = PassTextureNode::construct(node, pass_node, texture)
  p.texture.install(node, p, p, p)
}

///|
pub fn PassTextureNode::of(node : Node) -> PassTextureNode? {
  match node.class_payload("PassTextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// A named texture of a pass's render target (`output`, `depth`, or an MRT output).
pub(all) struct PassMultipleTextureNode {
  pass_texture : PassTextureNode
  mut texture_name : String
  mut previous_texture : Bool
}

///|
pub impl NodeClass for PassMultipleTextureNode with fn class_name(_) {
  "PassMultipleTextureNode"
}

///|
pub impl NodeClass for PassMultipleTextureNode with fn parent(self) {
  Some(self.pass_texture)
}

///|
pub impl NodeClass for PassMultipleTextureNode with fn has_flag(self, flag) {
  flag == "isPassMultipleTextureNode" || self.pass_texture.has_flag(flag)
}

///|
pub impl NodeClass for PassMultipleTextureNode with fn setup(
  self,
  node,
  builder,
) {
  self.update_texture(node)
  self.pass_texture.setup(node, builder)
}

///|
pub impl InputNodeClass for PassMultipleTextureNode with fn input_parent(self) {
  Some(self.pass_texture)
}

///|
pub impl TextureNodeClass for PassMultipleTextureNode with fn texture_parent(
  self,
) {
  Some(self.pass_texture)
}

///|
pub impl TextureNodeClass for PassMultipleTextureNode with fn clone(self, _) {
  let new_node = PassMultipleTextureNode::new(
    self.pass_texture.pass_node,
    self.texture_name,
    previous_texture=self.previous_texture,
  )
  let src = self.pass_texture.texture
  let dst = TextureNode::of(new_node).unwrap()
  dst.uv_node = src.uv_node
  dst.level_node = src.level_node
  dst.bias_node = src.bias_node
  dst.sampler = src.sampler
  dst.depth_node = src.depth_node
  dst.compare_node = src.compare_node
  dst.grad_node = src.grad_node
  dst.gather_node = src.gather_node
  dst.offset_node = src.offset_node
  new_node
}

///|
/// `updateTexture()`: the pass's current (or previous) texture of this name.
fn PassMultipleTextureNode::update_texture(
  self : PassMultipleTextureNode,
  node : Node,
) -> Unit {
  let pass_node = self.pass_texture.pass_node
  let texture = if self.previous_texture {
    pass_node.get_previous_texture(self.texture_name)
  } else {
    pass_node.get_texture(self.texture_name)
  }
  TextureNode::set_value(node, Some(texture))
}

///|
/// `new PassMultipleTextureNode( passNode, textureName, previousTexture = false )`.
pub fn PassMultipleTextureNode::new(
  pass_node : Node,
  texture_name : String,
  previous_texture~ : Bool = false,
) -> Node {
  let node = Node::alloc()
  // null is passed to the super call since this class does not
  // use an external texture for rendering pass data into. Instead
  // the texture is managed by the pass node itself
  let pass_texture = PassTextureNode::construct(node, pass_node, None)
  let p = PassMultipleTextureNode::{
    pass_texture,
    texture_name,
    previous_texture,
  }
  pass_texture.texture.install(node, p, p, p)
}

///|
pub fn PassMultipleTextureNode::of(node : Node) -> PassMultipleTextureNode? {
  match node.class_payload("PassMultipleTextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

// ---------------------------------------------------------------------------
// PassNode

///|
/// The virtual methods PassNode introduces (its subclasses override them).
pub(open) trait PassNodeClass {
  /// `setSize( width, height )`.
  fn set_size(Self, Node, Double, Double) -> Unit
}

///|
/// `_contextNodeCache`.
pub(all) struct PassNodeContextCache {
  version : Int32
  renderer_context_node : Node
  renderer_version : Int32
  context : Node
}

///|
/// Renders a scene into its own render target; the node is its color output (or its
/// linear depth for `depthPass`).
pub(all) struct PassNode {
  mut scope : String
  mut scene : @core.Object3D
  mut camera : @core.Object3D
  options : PassNodeOptions
  mut _width : Double
  mut _height : Double
  mut render_target : @core.RenderTarget
  mut override_material : @core.Material?
  mut transparent : Bool
  mut opaque_ : Bool
  /// `None` is `null`: the renderer's.
  mut lighting : Lighting?
  mut auto_clear : Bool
  mut auto_clear_color : Bool
  mut auto_clear_depth : Bool
  mut auto_clear_stencil : Bool
  /// `None` is `null`.
  mut context_node : Node?
  mut _context_node_cache : PassNodeContextCache?
  /// `_textures`, in insertion order.
  _textures : Map[String, @core.Texture]
  _texture_nodes : Map[String, Node]
  _linear_depth_nodes : Map[String, Node]
  _view_z_nodes : Map[String, Node]
  _previous_textures : Map[String, @core.Texture]
  _previous_texture_nodes : Map[String, Node]
  _camera_near : Node
  _camera_far : Node
  mut _mrt : Node?
  mut _layers : @core.Layers?
  mut _resolution_scale : Double
  mut _viewport : @math.Vector4?
  mut _scissor : @math.Vector4?
  /// The most derived payload of the family.
  mut pass_class : &PassNodeClass
}

///|
pub impl NodeClass for PassNode with fn class_name(_) {
  "PassNode"
}

///|
pub impl NodeClass for PassNode with fn has_flag(_, flag) {
  flag == "isPassNode"
}

///|
pub impl NodeClass for PassNode with fn children(self, _, out) {
  push_child(out, "contextNode", self.context_node)
}

///|
pub impl NodeClass for PassNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for PassNode with fn setup(self, node, builder) {
  PassNode::setup_base(self, node, builder)
}

///|
pub impl NodeClass for PassNode with fn update_before(_, node, frame) {
  PassNode::update_before_base(node, frame)
  None
}

///|
pub impl NodeClass for PassNode with fn set_size(self, node, width, height) {
  self.pass_class.set_size(node, width, height)
  true
}

///|
pub impl NodeClass for PassNode with fn dispose(self, node) {
  node.dispose_base()
  self.render_target.dispose()
}

///|
pub impl PassNodeClass for PassNode with fn set_size(_, node, width, height) {
  PassNode::set_size_base(node, width, height)
}

///|
/// `PassNode.COLOR`.
pub fn PassNode::color() -> String {
  "color"
}

///|
/// `PassNode.DEPTH`.
pub fn PassNode::depth() -> String {
  "depth"
}

///|
/// The constructor body.
pub fn PassNode::construct(
  node : Node,
  scope : String,
  scene : @core.Object3D,
  camera : @core.Object3D,
  options : PassNodeOptions,
) -> PassNode {
  let width = 1.0
  let height = 1.0
  let render_target = @core.RenderTarget::new(
    width=width.to_int(),
    height=height.to_int(),
    type_=options.type_.unwrap_or(@core.HalfFloatType),
    format?=options.format,
    samples?=options.samples,
    depth_buffer?=options.depth_buffer,
    stencil_buffer?=options.stencil_buffer,
    generate_mipmaps?=options.generate_mipmaps,
    min_filter?=options.min_filter,
    mag_filter?=options.mag_filter,
    count?=options.count,
  )
  render_target.texture().name = "output"
  let mut depth_texture : @core.Texture? = None
  if scope == PassNode::depth() || options.depth_buffer != Some(false) {
    let t = match options.depth_texture {
      Some(t) => t
      None => {
        let t = @core.DepthTexture::new()
        if render_target.stencil_buffer == true {
          t.format = @core.DepthStencilFormat
          t.type_ = @core.UnsignedInt248Type
        }
        t
      }
    }
    t.is_render_target_texture = true
    //depthTexture.type = FloatType;
    t.name = "depth"
    render_target.set_depth_texture(Some(t))
    depth_texture = Some(t)
  }
  let textures = Map::from_array([("output", render_target.texture())])
  if depth_texture is Some(t) {
    textures.set("depth", t)
  }
  node.update_before_type = NodeUpdateType::frame()
  node.global = true
  {
    scope,
    scene,
    camera,
    options,
    _width: width,
    _height: height,
    render_target,
    override_material: None,
    transparent: true,
    opaque_: true,
    lighting: None,
    auto_clear: options.auto_clear.unwrap_or(true),
    auto_clear_color: options.auto_clear_color.unwrap_or(true),
    auto_clear_depth: options.auto_clear_depth.unwrap_or(true),
    auto_clear_stencil: options.auto_clear_stencil.unwrap_or(true),
    context_node: None,
    _context_node_cache: None,
    _textures: textures,
    _texture_nodes: Map::from_array([]),
    _linear_depth_nodes: Map::from_array([]),
    _view_z_nodes: Map::from_array([]),
    _previous_textures: Map::from_array([]),
    _previous_texture_nodes: Map::from_array([]),
    _camera_near: uniform(0),
    _camera_far: uniform(0),
    _mrt: None,
    _layers: None,
    _resolution_scale: 1.0,
    _viewport: None,
    _scissor: None,
    pass_class: PassNodeUnset::{ },
  }
}

///|
priv struct PassNodeUnset {}

///|
impl PassNodeClass for PassNodeUnset with fn set_size(_, node, width, height) {
  PassNode::set_size_base(node, width, height)
}

///|
/// `new PassNode( scope, scene, camera, options = {} )`.
pub fn PassNode::new(
  scope : String,
  scene : @core.Object3D,
  camera : @core.Object3D,
  options~ : PassNodeOptions = PassNodeOptions::default(),
) -> Node {
  let node = Node::alloc(node_type="vec4")
  let p = PassNode::construct(node, scope, scene, camera, options)
  p.pass_class = p
  node.set_class(p)
}

///|
pub fn PassNode::of(node : Node) -> PassNode? {
  match node.class_payload("PassNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn pass_node_payload(node : Node, name : String) -> PassNode {
  match PassNode::of(node) {
    Some(p) => p
    None => abort("TypeError: \{node.type_()}.\{name} is not a function")
  }
}

///|
/// `setResolutionScale( resolutionScale )`.
pub fn Node::set_resolution_scale(
  self : Node,
  resolution_scale : Double,
) -> Node {
  pass_node_payload(self, "setResolutionScale")._resolution_scale = resolution_scale
  self
}

///|
/// `getResolutionScale()`.
pub fn Node::get_resolution_scale(self : Node) -> Double {
  pass_node_payload(self, "getResolutionScale")._resolution_scale
}

///|
/// `setLayers( layers )`.
pub fn Node::set_layers(self : Node, layers : @core.Layers?) -> Node {
  pass_node_payload(self, "setLayers")._layers = layers
  self
}

///|
/// `getLayers()`.
pub fn Node::get_layers(self : Node) -> @core.Layers? {
  pass_node_payload(self, "getLayers")._layers
}

///|
/// `setMRT( mrt )`.
pub fn Node::set_mrt(self : Node, mrt : Node?) -> Node {
  pass_node_payload(self, "setMRT")._mrt = mrt
  self
}

///|
/// `getMRT()`.
pub fn Node::get_mrt(self : Node) -> Node? {
  pass_node_payload(self, "getMRT")._mrt
}

///|
/// `getTexture( name )`: the render target texture of this name, created on first use.
pub fn Node::get_texture(self : Node, name : String) -> @core.Texture {
  let p = pass_node_payload(self, "getTexture")
  match p._textures.get(name) {
    Some(t) => t
    None => {
      if name == "depth" {
        abort("THREE.PassNode: Depth texture is not available for this pass.")
      }
      let ref_texture = p.render_target.texture()
      let texture = ref_texture.clone()
      texture.name = name
      p._textures.set(name, texture)
      p.render_target.textures.push(texture)
      texture
    }
  }
}

///|
/// `getPreviousTexture( name )`: a copy of `getTexture( name )` swapped with it every
/// frame.
pub fn Node::get_previous_texture(self : Node, name : String) -> @core.Texture {
  let p = pass_node_payload(self, "getPreviousTexture")
  match p._previous_textures.get(name) {
    Some(t) => t
    None => {
      let texture = self.get_texture(name).clone()
      p._previous_textures.set(name, texture)
      texture
    }
  }
}

///|
/// `toggleTexture( name )`: swaps the current and previous textures of this name.
pub fn Node::toggle_texture(self : Node, name : String) -> Unit {
  let p = pass_node_payload(self, "toggleTexture")
  guard p._previous_textures.get(name) is Some(prev_texture) else { return }
  let texture = p._textures.get(name).unwrap()
  if p.render_target.depth_texture() is Some(d) && physical_equal(texture, d) {
    p.render_target.set_depth_texture(Some(prev_texture))
  } else {
    let mut index = -1
    for i, t in p.render_target.textures {
      if physical_equal(t, texture) {
        index = i
        break
      }
    }
    // `textures[ -1 ] = prevTexture` sets a property upstream; nothing to replace
    if index >= 0 {
      p.render_target.textures[index] = prev_texture
    }
  }
  p._textures.set(name, prev_texture)
  p._previous_textures.set(name, texture)
  PassMultipleTextureNode::of(p._texture_nodes.get(name).unwrap())
  .unwrap()
  .update_texture(p._texture_nodes.get(name).unwrap())
  PassMultipleTextureNode::of(p._previous_texture_nodes.get(name).unwrap())
  .unwrap()
  .update_texture(p._previous_texture_nodes.get(name).unwrap())
}

///|
/// `getTextureNode( name = 'output' )`: a texture node sampling this pass's texture.
pub fn Node::get_texture_node(self : Node, name~ : String = "output") -> Node {
  let p = pass_node_payload(self, "getTextureNode")
  match p._texture_nodes.get(name) {
    Some(n) => n
    None => {
      let texture_node = PassMultipleTextureNode::new(self, name)
      PassMultipleTextureNode::of(texture_node)
      .unwrap()
      .update_texture(texture_node)
      p._texture_nodes.set(name, texture_node)
      texture_node
    }
  }
}

///|
/// `getPreviousTextureNode( name = 'output' )`: a texture node sampling the previous
/// frame's texture.
pub fn Node::get_previous_texture_node(
  self : Node,
  name~ : String = "output",
) -> Node {
  let p = pass_node_payload(self, "getPreviousTextureNode")
  match p._previous_texture_nodes.get(name) {
    Some(n) => n
    None => {
      if p._texture_nodes.get(name) is None {
        self.get_texture_node(name~) |> ignore
      }
      let texture_node = PassMultipleTextureNode::new(
        self,
        name,
        previous_texture=true,
      )
      PassMultipleTextureNode::of(texture_node)
      .unwrap()
      .update_texture(texture_node)
      p._previous_texture_nodes.set(name, texture_node)
      texture_node
    }
  }
}

///|
/// `getViewZNode( name = 'depth' )`: the view-space z of a depth texture.
pub fn Node::get_view_z_node(self : Node, name~ : String = "depth") -> Node {
  let p = pass_node_payload(self, "getViewZNode")
  match p._view_z_nodes.get(name) {
    Some(n) => n
    None => {
      let camera_near = p._camera_near
      let camera_far = p._camera_far
      let view_z_node = perspective_depth_to_view_z.call([
        self.get_texture_node(name~),
        camera_near,
        camera_far,
      ])
      p._view_z_nodes.set(name, view_z_node)
      view_z_node
    }
  }
}

///|
/// `getLinearDepthNode( name = 'depth' )`: the linear depth of a depth texture.
pub fn Node::get_linear_depth_node(
  self : Node,
  name~ : String = "depth",
) -> Node {
  let p = pass_node_payload(self, "getLinearDepthNode")
  match p._linear_depth_nodes.get(name) {
    Some(n) => n
    None => {
      let camera_near = p._camera_near
      let camera_far = p._camera_far
      let view_z_node = self.get_view_z_node(name~)
      // TODO: just if ( builder.camera.isPerspectiveCamera )
      let linear_depth_node = view_z_to_orthographic_depth(
        view_z_node, camera_near, camera_far,
      )
      p._linear_depth_nodes.set(name, linear_depth_node)
      linear_depth_node
    }
  }
}

///|
/// PassNode's `setup( { renderer } )`.
pub fn PassNode::setup_base(
  self : PassNode,
  node : Node,
  builder : NodeBuilder,
) -> Node? {
  let renderer = builder.renderer
  self.render_target.samples = match self.options.samples {
    Some(s) => s
    None => renderer_samples(renderer)
  }
  self.render_target.texture().type_ = renderer_get_output_buffer_type(renderer)
  if renderer.reversed_depth_buffer == true &&
    self.render_target.depth_texture() is Some(d) {
    d.type_ = @core.FloatType
  }
  for name, previous in self._previous_textures {
    previous.type_ = self._textures.get(name).unwrap().type_
  }
  if self.scope == PassNode::color() {
    Some(node.get_texture_node())
  } else {
    Some(node.get_linear_depth_node())
  }
}

///|
/// PassNode's `updateBefore( frame )`: renders the scene into the render target.
pub fn PassNode::update_before_base(node : Node, frame : NodeFrame) -> Unit {
  let self = PassNode::of(node).unwrap()
  let renderer = frame.renderer.unwrap()
  let scene = self.scene
  let camera = match renderer.get_output_render_target() {
    Some(output) if output.has_extension_flag("isXRRenderTarget") => {
      let camera = renderer_xr_get_camera(renderer)
      renderer_xr_update_camera(renderer, camera)
      _pass_node_size.set(output.width.to_double(), output.height.to_double())
      |> ignore
      camera
    }
    _ => {
      renderer_get_drawing_buffer_size(renderer, _pass_node_size)
      self.camera
    }
  }
  self.pass_class.set_size(node, _pass_node_size.x, _pass_node_size.y)
  let current_render_target = renderer.get_render_target()
  let current_mrt = renderer.get_mrt()
  let current_auto_clear = renderer.auto_clear
  let current_auto_clear_color = renderer.auto_clear_color
  let current_auto_clear_depth = renderer.auto_clear_depth
  let current_auto_clear_stencil = renderer.auto_clear_stencil
  let current_transparent = renderer.transparent
  let current_opaque = renderer.opaque_
  let current_lighting = renderer.lighting
  let current_mask = camera.layers.mask
  let current_context_node = renderer.context_node
  let scene_data = scene.as_scene()
  let current_override_material = scene_data.override_material
  InputNode::set_value(self._camera_near, Number(camera_near_of(camera)))
  InputNode::set_value(self._camera_far, Number(camera_far_of(camera)))
  if self._layers is Some(layers) {
    camera.layers.mask = layers.mask
  }
  for name in self._previous_textures.keys().collect() {
    node.toggle_texture(name)
  }
  if self.override_material is Some(m) {
    scene_data.override_material = Some(m)
  }
  renderer.set_render_target(Some(self.render_target))
  renderer.set_mrt(self._mrt) |> ignore
  renderer.auto_clear = self.auto_clear
  renderer.auto_clear_color = self.auto_clear_color
  renderer.auto_clear_depth = self.auto_clear_depth
  renderer.auto_clear_stencil = self.auto_clear_stencil
  renderer.transparent = self.transparent
  renderer.opaque_ = self.opaque_
  if self.lighting is Some(lighting) {
    renderer_set_lighting(renderer, lighting)
  }
  if self.context_node is Some(_) {
    renderer.context_node = PassNode::get_context_node(node, renderer)
  }
  let current_scene_name = scene.name
  scene.name = match node.name {
    Some(n) if n != "" => n
    _ => scene.name
  }
  renderer_render(renderer, scene, camera)
  scene.name = current_scene_name
  scene_data.override_material = current_override_material
  renderer.set_render_target(current_render_target)
  renderer.set_mrt(current_mrt) |> ignore
  renderer.auto_clear = current_auto_clear
  renderer.auto_clear_color = current_auto_clear_color
  renderer.auto_clear_depth = current_auto_clear_depth
  renderer.auto_clear_stencil = current_auto_clear_stencil
  renderer.transparent = current_transparent
  renderer.opaque_ = current_opaque
  renderer.context_node = current_context_node
  renderer_set_lighting(renderer, current_lighting)
  camera.layers.mask = current_mask
}

///|
/// `async compileAsync( renderer )`: compiles the pass's scene with the render target
/// configured as in `setup()` and `updateBefore()`; calls back when done (added by G6).
pub fn PassNode::compile_async(
  node : Node,
  renderer : Renderer,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  let self = PassNode::of(node).unwrap()
  let current_render_target = renderer.get_render_target()
  let current_mrt = renderer.get_mrt()
  let current_context_node = renderer.context_node
  // the render target is configured like in setup() and updateBefore(), so the pipelines match the ones of the render
  self.render_target.samples = match self.options.samples {
    Some(s) => s
    None => renderer.samples()
  }
  renderer.get_drawing_buffer_size(_pass_node_size) |> ignore
  self.pass_class.set_size(node, _pass_node_size.x, _pass_node_size.y)
  renderer.set_render_target(Some(self.render_target))
  renderer.set_mrt(self._mrt) |> ignore
  if self.context_node is Some(_) {
    renderer.context_node = PassNode::get_context_node(node, renderer)
  }
  renderer.compile_async(self.scene, self.camera, on_done=fn() {
    renderer.set_render_target(current_render_target)
    renderer.set_mrt(current_mrt) |> ignore
    renderer.context_node = current_context_node
    on_done()
  })
}

///|
/// `_getContextNode( renderer )`: the renderer's context merged with this pass's,
/// cached until either changes.
pub fn PassNode::get_context_node(node : Node, renderer : Renderer) -> Node {
  let self = PassNode::of(node).unwrap()
  let renderer_context_node = renderer.context_node
  let stale = match self._context_node_cache {
    None => true
    Some(cache) =>
      cache.version != node.version ||
      !physical_equal(cache.renderer_context_node, renderer_context_node) ||
      cache.renderer_version != renderer_context_node.version
  }
  if stale {
    self._context_node_cache = Some({
      version: node.version,
      renderer_context_node,
      renderer_version: renderer_context_node.version,
      context: context(
        value=NodeContext::merge(
          ContextNode::get_flow_context_data(renderer_context_node),
          ContextNode::get_flow_context_data(self.context_node.unwrap()),
        ),
      ),
    })
  }
  self._context_node_cache.unwrap().context
}

///|
/// PassNode's `setSize( width, height )`.
pub fn PassNode::set_size_base(
  node : Node,
  width : Double,
  height : Double,
) -> Unit {
  let self = PassNode::of(node).unwrap()
  self._width = width
  self._height = height
  let effective_width = (self._width * self._resolution_scale).floor()
  let effective_height = (self._height * self._resolution_scale).floor()
  self.render_target.set_size(
    effective_width.to_int(),
    effective_height.to_int(),
  )
  // scissor
  match self._scissor {
    Some(scissor) => {
      self.render_target.scissor
      .copy(scissor)
      .multiply_scalar(self._resolution_scale)
      .floor()
      |> ignore
      self.render_target.scissor_test = true
    }
    None => self.render_target.scissor_test = false
  }
  // viewport
  if self._viewport is Some(viewport) {
    self.render_target.viewport
    .copy(viewport)
    .multiply_scalar(self._resolution_scale)
    .floor()
    |> ignore
  }
}

///|
/// `setScissor( x, y, width, height )`; `None` clears the scissor.
pub fn Node::set_scissor(self : Node, rect : @math.Vector4?) -> Unit {
  let p = pass_node_payload(self, "setScissor")
  match rect {
    None => p._scissor = None
    Some(r) => {
      let s = match p._scissor {
        Some(s) => s
        None => {
          let s = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
          p._scissor = Some(s)
          s
        }
      }
      s.copy(r) |> ignore
    }
  }
}

///|
/// `setViewport( x, y, width, height )`; `None` clears the viewport.
pub fn Node::set_viewport(self : Node, rect : @math.Vector4?) -> Unit {
  let p = pass_node_payload(self, "setViewport")
  match rect {
    None => p._viewport = None
    Some(r) => {
      let v = match p._viewport {
        Some(v) => v
        None => {
          let v = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
          p._viewport = Some(v)
          v
        }
      }
      v.copy(r) |> ignore
    }
  }
}

///|
/// `pass( scene, camera, options )`: renders a scene; the node is its color.
pub fn pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
  options~ : PassNodeOptions = PassNodeOptions::default(),
) -> Node {
  PassNode::new(PassNode::color(), scene, camera, options~)
}

///|
/// `passTexture( pass, texture )`: a texture of a pass.
pub fn pass_texture(pass : Node, texture : @core.Texture) -> Node {
  PassTextureNode::new(pass, Some(texture))
}

///|
/// `depthPass( scene, camera, options )`: renders a scene; the node is its linear depth.
pub fn depth_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
  options~ : PassNodeOptions = PassNodeOptions::default(),
) -> Node {
  PassNode::new(PassNode::depth(), scene, camera, options~)
}

// Renderer members that group G6 has not declared yet; each becomes the `Renderer`
// member of the same name once it exists.

///|
/// `renderer.samples`.
fn renderer_samples(renderer : Renderer) -> Int32 {
  renderer.samples()
}

///|
/// `renderer.getOutputBufferType()`.
fn renderer_get_output_buffer_type(renderer : Renderer) -> Int32 {
  renderer.get_output_buffer_type()
}

///|
/// `renderer.render( scene, camera )`.
fn renderer_render(
  renderer : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  renderer.render(scene, camera)
}

///|
/// `renderer.lighting = lighting` (the field is not writable yet).
fn renderer_set_lighting(renderer : Renderer, lighting : Lighting) -> Unit {
  renderer.lighting = lighting
}

///|
/// `renderer.xr.getCamera()`.
fn renderer_xr_get_camera(renderer : Renderer) -> @core.Object3D {
  renderer.xr.get_camera()
}

///|
/// `renderer.xr.updateCamera( camera )`.
fn renderer_xr_update_camera(
  renderer : Renderer,
  camera : @core.Object3D,
) -> Unit {
  renderer.xr.update_camera(camera)
}
