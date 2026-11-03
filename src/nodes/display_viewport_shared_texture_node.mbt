// nodes/display/ViewportSharedTextureNode.js

///|
/// `_sharedFramebuffer`: the framebuffer texture every shared viewport texture uses.
let _viewport_shared_texture_node_shared_framebuffer : Ref[@core.Texture?] = Ref(
  None,
)

///|
/// A viewport texture whose framebuffer copy is shared by all its instances.
pub(all) struct ViewportSharedTextureNode {
  viewport : ViewportTextureNode
}

///|
pub impl NodeClass for ViewportSharedTextureNode with fn class_name(_) {
  "ViewportSharedTextureNode"
}

///|
pub impl NodeClass for ViewportSharedTextureNode with fn parent(self) {
  Some(self.viewport)
}

///|
pub impl NodeClass for ViewportSharedTextureNode with fn update_reference(
  _,
  node,
  _,
) {
  @core.JsValue::of(node)
}

///|
pub impl InputNodeClass for ViewportSharedTextureNode with fn input_parent(self) {
  Some(self.viewport)
}

///|
pub impl TextureNodeClass for ViewportSharedTextureNode with fn texture_parent(
  self,
) {
  Some(self.viewport)
}

///|
pub impl ViewportTextureNodeClass for ViewportSharedTextureNode with fn get_texture_for_reference(
  _,
  _,
  _,
) {
  _viewport_shared_texture_node_shared_framebuffer.val.unwrap()
}

///|
/// `new ViewportSharedTextureNode( uvNode = screenUV, levelNode = null )`.
/// `uv_node_null=true` passes an explicit `null` uvNode (no default).
pub fn ViewportSharedTextureNode::new(
  uv_node? : Node,
  uv_node_null~ : Bool = false,
  level_node? : Node,
) -> Node {
  let shared = match _viewport_shared_texture_node_shared_framebuffer.val {
    Some(t) => t
    None => {
      let t = @core.FramebufferTexture::new()
      _viewport_shared_texture_node_shared_framebuffer.val = Some(t)
      t
    }
  }
  let node = Node::alloc()
  let viewport = ViewportTextureNode::construct(
    node,
    viewport_texture_node_default_uv(uv_node, uv_node_null),
    level_node,
    Some(shared),
  )
  let s = ViewportSharedTextureNode::{ viewport, }
  viewport.viewport_class = s
  viewport.texture.install(node, s, s, s)
}

///|
pub fn ViewportSharedTextureNode::of(node : Node) -> ViewportSharedTextureNode? {
  match node.class_payload("ViewportSharedTextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `viewportSharedTexture( uvNode, levelNode )`.
pub fn viewport_shared_texture(
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
) -> Node {
  ViewportSharedTextureNode::new(
    uv_node?=viewport_texture_node_arg(uv_node),
    uv_node_null=viewport_texture_node_arg_null(uv_node),
    level_node?=viewport_texture_node_arg(level_node),
  )
}
