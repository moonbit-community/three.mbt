// nodes/display/ViewportDepthTextureNode.js

///|
/// `_sharedDepthbuffer`: the depth texture the viewport depth textures share by default.
let _viewport_depth_texture_node_shared_depthbuffer : Ref[@core.Texture?] = Ref(
  None,
)

///|
/// A viewport texture copying the depth buffer.
pub(all) struct ViewportDepthTextureNode {
  viewport : ViewportTextureNode
}

///|
pub impl NodeClass for ViewportDepthTextureNode with fn class_name(_) {
  "ViewportDepthTextureNode"
}

///|
pub impl NodeClass for ViewportDepthTextureNode with fn parent(self) {
  Some(self.viewport)
}

///|
pub impl InputNodeClass for ViewportDepthTextureNode with fn input_parent(self) {
  Some(self.viewport)
}

///|
pub impl TextureNodeClass for ViewportDepthTextureNode with fn texture_parent(
  self,
) {
  Some(self.viewport)
}

///|
pub impl ViewportTextureNodeClass for ViewportDepthTextureNode with fn get_texture_for_reference(
  _,
  node,
  reference,
) {
  ViewportTextureNode::get_texture_for_reference_base(node, reference)
}

///|
/// `new ViewportDepthTextureNode( uvNode = screenUV, levelNode = null, depthTexture = null )`.
/// `uv_node_null=true` passes an explicit `null` uvNode (no default).
pub fn ViewportDepthTextureNode::new(
  uv_node? : Node,
  uv_node_null~ : Bool = false,
  level_node? : Node,
  depth_texture? : @core.Texture,
) -> Node {
  let depth_texture = match depth_texture {
    Some(t) => t
    None =>
      match _viewport_depth_texture_node_shared_depthbuffer.val {
        Some(t) => t
        None => {
          let t = @core.DepthTexture::new()
          _viewport_depth_texture_node_shared_depthbuffer.val = Some(t)
          t
        }
      }
  }
  let node = Node::alloc()
  let viewport = ViewportTextureNode::construct(
    node,
    viewport_texture_node_default_uv(uv_node, uv_node_null),
    level_node,
    Some(depth_texture),
  )
  let d = ViewportDepthTextureNode::{ viewport, }
  viewport.viewport_class = d
  viewport.texture.install(node, d, d, d)
}

///|
pub fn ViewportDepthTextureNode::of(node : Node) -> ViewportDepthTextureNode? {
  match node.class_payload("ViewportDepthTextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `viewportDepthTexture( uvNode, levelNode, depthTexture )`.
pub fn viewport_depth_texture(
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  depth_texture? : @core.Texture,
) -> Node {
  ViewportDepthTextureNode::new(
    uv_node?=viewport_texture_node_arg(uv_node),
    uv_node_null=viewport_texture_node_arg_null(uv_node),
    level_node?=viewport_texture_node_arg(level_node),
    depth_texture?,
  )
}
