// nodes/display/ViewportTextureNode.js

///|
let _viewport_texture_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
/// The virtual method ViewportTextureNode introduces: `getTextureForReference`.
pub(open) trait ViewportTextureNodeClass {
  /// `getTextureForReference( reference = null )`: the framebuffer texture of a
  /// render target or canvas target (`None` is `null`, the default one).
  fn get_texture_for_reference(Self, Node, @core.JsValue?) -> @core.Texture
}

///|
/// A texture holding a copy of the current framebuffer (`viewportTexture()`).
pub(all) struct ViewportTextureNode {
  texture : TextureNode
  mut generate_mipmaps : Bool
  mut default_framebuffer : @core.Texture
  /// `_cacheTextures`, keyed by render target or canvas target.
  _cache_textures : @webgl.WeakMap[@core.JsValue, @core.Texture]
  /// The most derived payload of the family.
  mut viewport_class : &ViewportTextureNodeClass
}

///|
pub impl NodeClass for ViewportTextureNode with fn class_name(_) {
  "ViewportTextureNode"
}

///|
pub impl NodeClass for ViewportTextureNode with fn parent(self) {
  Some(self.texture)
}

///|
pub impl NodeClass for ViewportTextureNode with fn has_flag(self, flag) {
  flag == "isOutputTextureNode" || self.texture.has_flag(flag)
}

///|
pub impl NodeClass for ViewportTextureNode with fn update_reference(
  _,
  node,
  state,
) {
  ViewportTextureNode::update_reference_base(node, state)
}

///|
pub impl NodeClass for ViewportTextureNode with fn update_before(_, node, frame) {
  ViewportTextureNode::update_before_base(node, frame)
  None
}

///|
pub impl InputNodeClass for ViewportTextureNode with fn input_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for ViewportTextureNode with fn texture_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for ViewportTextureNode with fn clone(self, node) {
  let t = texture_node_of_viewport(node)
  // `new this.constructor( this.uvNode, ... )`: a `null` uvNode stays null
  let new_node = ViewportTextureNode::construct_like_viewport(
    node,
    t.uv_node,
    t.level_node,
    TextureNode::get_value_opt(node),
  )
  ViewportTextureNode::of(new_node).unwrap().generate_mipmaps = self.generate_mipmaps
  new_node
}

///|
pub impl ViewportTextureNodeClass for ViewportTextureNode with fn get_texture_for_reference(
  _,
  node,
  reference,
) {
  ViewportTextureNode::get_texture_for_reference_base(node, reference)
}

///|
fn texture_node_of_viewport(node : Node) -> TextureNode {
  TextureNode::of(node).unwrap()
}

///|
/// `new this.constructor( uvNode, levelNode, value )` of `clone`.
fn ViewportTextureNode::construct_like_viewport(
  node : Node,
  uv_node : Node?,
  level_node : Node?,
  value : @core.Texture?,
) -> Node {
  let uv_node_null = uv_node is None
  if ViewportDepthTextureNode::of(node) is Some(_) {
    ViewportDepthTextureNode::new(
      uv_node?,
      uv_node_null~,
      level_node?,
      depth_texture?=value,
    )
  } else if ViewportSharedTextureNode::of(node) is Some(_) {
    ViewportSharedTextureNode::new(uv_node?, uv_node_null~, level_node?)
  } else {
    ViewportTextureNode::new(
      uv_node?,
      uv_node_null~,
      level_node?,
      framebuffer_texture?=value,
    )
  }
}

///|
/// `getTextureForReference( reference )` dispatched to the most derived class.
pub fn ViewportTextureNode::get_texture_for_reference(
  node : Node,
  reference : @core.JsValue?,
) -> @core.Texture {
  ViewportTextureNode::of(node).unwrap().viewport_class.get_texture_for_reference(
    node, reference,
  )
}

///|
/// ViewportTextureNode's own `getTextureForReference`.
pub fn ViewportTextureNode::get_texture_for_reference_base(
  node : Node,
  reference : @core.JsValue?,
) -> @core.Texture {
  let self = ViewportTextureNode::of(node).unwrap()
  let (default_framebuffer, cache_textures) = match
    texture_node_of_viewport(node).reference_node {
    Some(r) => {
      let r = ViewportTextureNode::of(r).unwrap()
      (r.default_framebuffer, r._cache_textures)
    }
    None => (self.default_framebuffer, self._cache_textures)
  }
  match reference {
    None => default_framebuffer
    Some(reference) =>
      match cache_textures.get(reference) {
        Some(t) => t
        None => {
          let framebuffer_texture = default_framebuffer.clone()
          cache_textures.set(reference, framebuffer_texture)
          framebuffer_texture
        }
      }
  }
}

///|
/// The render target, or else the canvas target, a viewport texture copies.
fn viewport_texture_node_reference(renderer : Renderer) -> @core.JsValue? {
  match renderer.get_render_target() {
    Some(rt) => Some(@core.JsValue::of(rt))
    None => renderer_get_canvas_target(renderer)
  }
}

///|
/// ViewportTextureNode's `updateReference( frame )`.
pub fn ViewportTextureNode::update_reference_base(
  node : Node,
  state : NodeUpdateState,
) -> @core.JsValue {
  let renderer = match state {
    Frame(frame) => frame.renderer.unwrap()
    Builder(builder) => builder.renderer
  }
  let reference = viewport_texture_node_reference(renderer)
  let texture = ViewportTextureNode::get_texture_for_reference(node, reference)
  TextureNode::set_value(node, Some(texture))
  @core.JsValue::of(texture)
}

///|
fn viewport_texture_node_image_size(texture : @core.Texture) -> (Int32, Int32) {
  match texture.image() {
    DataImage(image) => (image.width, image.height)
    _ => (0, 0)
  }
}

///|
/// ViewportTextureNode's `updateBefore( frame )`: copies the framebuffer.
pub fn ViewportTextureNode::update_before_base(
  node : Node,
  frame : NodeFrame,
) -> Unit {
  let self = ViewportTextureNode::of(node).unwrap()
  let renderer = frame.renderer.unwrap()
  let render_target = renderer.get_render_target()
  let reference = viewport_texture_node_reference(renderer)
  match (render_target, reference) {
    (Some(rt), _) =>
      _viewport_texture_node_size.set(
        rt.width.to_double(),
        rt.height.to_double(),
      )
      |> ignore
    // a canvas target has `getDrawingBufferSize`
    (None, Some(canvas_target)) =>
      canvas_target_get_drawing_buffer_size(
        canvas_target, _viewport_texture_node_size,
      )
    (None, None) =>
      renderer_get_drawing_buffer_size(renderer, _viewport_texture_node_size)
  }
  let framebuffer_texture = ViewportTextureNode::get_texture_for_reference(
    node, reference,
  )
  let (width, height) = viewport_texture_node_image_size(framebuffer_texture)
  if width.to_double() != _viewport_texture_node_size.x ||
    height.to_double() != _viewport_texture_node_size.y {
    match framebuffer_texture.image() {
      DataImage(image) => {
        image.width = _viewport_texture_node_size.x.to_int()
        image.height = _viewport_texture_node_size.y.to_int()
      }
      _ => ()
    }
    framebuffer_texture.set_needs_update(true)
  }
  let current_generate_mipmaps = framebuffer_texture.generate_mipmaps
  framebuffer_texture.generate_mipmaps = self.generate_mipmaps
  renderer_copy_framebuffer_to_texture(renderer, framebuffer_texture)
  framebuffer_texture.generate_mipmaps = current_generate_mipmaps
}

///|
/// The constructor body: `super( framebufferTexture, uvNode, levelNode )` and the
/// fields. `uv_node` `None` is the default `screenUV`.
/// `uv_node` is the argument after defaults: `None` is an explicit `null` (the
/// texture's default `uv()` then applies at setup).
pub fn ViewportTextureNode::construct(
  node : Node,
  uv_node : Node?,
  level_node : Node?,
  framebuffer_texture : @core.Texture?,
) -> ViewportTextureNode {
  let default_framebuffer = match framebuffer_texture {
    Some(t) => t
    None => {
      let t = @core.FramebufferTexture::new()
      t.min_filter = @core.LinearMipmapLinearFilter
      t
    }
  }
  let texture = TextureNode::construct(
    node,
    Some(default_framebuffer),
    uv_node,
    level_node,
    None,
  )
  node.update_before_type = NodeUpdateType::render()
  let payload = {
    texture,
    generate_mipmaps: false,
    default_framebuffer,
    _cache_textures: @webgl.WeakMap::new(),
    viewport_class: ViewportTextureNodeUnset::{ },
  }
  payload
}

///|
priv struct ViewportTextureNodeUnset {}

///|
impl ViewportTextureNodeClass for ViewportTextureNodeUnset with fn get_texture_for_reference(
  _,
  node,
  reference,
) {
  ViewportTextureNode::get_texture_for_reference_base(node, reference)
}

///|
/// `new ViewportTextureNode( uvNode = screenUV, levelNode = null, framebufferTexture = null )`.
/// `uv_node_null=true` passes an explicit `null` uvNode (no default).
pub fn ViewportTextureNode::new(
  uv_node? : Node,
  uv_node_null~ : Bool = false,
  level_node? : Node,
  framebuffer_texture? : @core.Texture,
) -> Node {
  let node = Node::alloc()
  let v = ViewportTextureNode::construct(
    node,
    viewport_texture_node_default_uv(uv_node, uv_node_null),
    level_node,
    framebuffer_texture,
  )
  v.viewport_class = v
  v.texture.install(node, v, v, v)
}

///|
pub fn ViewportTextureNode::of(node : Node) -> ViewportTextureNode? {
  match node.class_payload("ViewportTextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// The `uvNode` constructor argument after its default: `screenUV` unless omitted
/// arguments are an explicit `null`.
fn viewport_texture_node_default_uv(
  uv_node : Node?,
  uv_node_null : Bool,
) -> Node? {
  match uv_node {
    Some(n) => Some(n)
    None => if uv_node_null { None } else { Some(screen_uv) }
  }
}

///|
/// Whether a TSL argument is an explicit `null` (`TslValue::Null`).
fn viewport_texture_node_arg_null(value : &IntoTsl?) -> Bool {
  match value {
    Some(v) => v.to_tsl() is Null
    None => false
  }
}

///|
fn viewport_texture_node_arg(value : &IntoTsl?) -> Node? {
  match value {
    Some(v) =>
      match node_object_value(v.to_tsl()) {
        Node(n) => Some(n)
        _ => None
      }
    None => None
  }
}

///|
/// `viewportTexture( uvNode, levelNode, framebufferTexture )`.
pub fn viewport_texture(
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  framebuffer_texture? : @core.Texture,
) -> Node {
  ViewportTextureNode::new(
    uv_node?=viewport_texture_node_arg(uv_node),
    uv_node_null=viewport_texture_node_arg_null(uv_node),
    level_node?=viewport_texture_node_arg(level_node),
    framebuffer_texture?,
  )
}

///|
/// `viewportMipTexture( uvNode, levelNode, framebufferTexture )`: a viewport texture
/// with mipmaps.
pub fn viewport_mip_texture(
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  framebuffer_texture? : @core.Texture,
) -> Node {
  let node = viewport_texture(uv_node?, level_node?, framebuffer_texture?)
  // `nodeProxy( ..., { generateMipmaps: true } )` assigns the setting
  ViewportTextureNode::of(node).unwrap().generate_mipmaps = true
  node
}

///|
// Singleton instances for common usage
let _viewport_texture_node_singleton_opaque : Node = module_nodes(
  "nodes/display/ViewportTextureNode.js:_singletonOpaqueViewportTextureNode",
  fn() { viewport_mip_texture() },
)

///|
/// `viewportOpaqueMipTexture( uv = screenUV, level = null )`.
pub fn viewport_opaque_mip_texture(uv? : &IntoTsl, level? : &IntoTsl) -> Node {
  // TODO: Use once() when sample() supports it
  let uv : &IntoTsl = match uv {
    Some(u) => u
    None => screen_uv
  }
  // `sample( uvNode )` takes one argument: upstream passes `level` and drops it.
  ignore(level)
  _viewport_texture_node_singleton_opaque.sample(uv)
}

// Renderer and CanvasTarget members that group G6 has not declared yet; each becomes
// the method of the same name once it exists.

///|
/// `renderer.getCanvasTarget()`.
fn renderer_get_canvas_target(renderer : Renderer) -> @core.JsValue? {
  Some(@core.JsValue::of(renderer.get_canvas_target()))
}

///|
/// `canvasTarget.getDrawingBufferSize( target )`.
fn canvas_target_get_drawing_buffer_size(
  canvas_target : @core.JsValue,
  target : @math.Vector2,
) -> Unit {
  let canvas_target : CanvasTarget = canvas_target.cast()
  canvas_target.get_drawing_buffer_size(target) |> ignore
}

///|
/// `renderer.copyFramebufferToTexture( framebufferTexture )`.
fn renderer_copy_framebuffer_to_texture(
  renderer : Renderer,
  texture : @core.Texture,
) -> Unit {
  renderer.copy_framebuffer_to_texture(texture)
}
