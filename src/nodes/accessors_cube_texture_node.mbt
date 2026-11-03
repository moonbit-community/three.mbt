// nodes/accessors/CubeTextureNode.js

///|
/// `EmptyTexture` of this file: an empty `CubeTexture`.
let _cube_texture_node_empty_texture : @core.Texture = @core.CubeTexture::new()

///|
pub(all) struct CubeTextureNode {
  texture : TextureNode
}

///|
pub impl NodeClass for CubeTextureNode with fn class_name(_) {
  "CubeTextureNode"
}

///|
pub impl NodeClass for CubeTextureNode with fn parent(self) {
  Some(self.texture)
}

///|
pub impl NodeClass for CubeTextureNode with fn has_flag(self, flag) {
  flag == "isCubeTextureNode" || self.texture.has_flag(flag)
}

///|
pub impl InputNodeClass for CubeTextureNode with fn input_parent(self) {
  Some(self.texture)
}

///|
pub impl InputNodeClass for CubeTextureNode with fn get_input_type(_, node, _) {
  if TextureNode::get_value(node).is_depth_texture() {
    return Some("cubeDepthTexture")
  }
  Some("cubeTexture")
}

///|
pub impl TextureNodeClass for CubeTextureNode with fn texture_parent(self) {
  Some(self.texture)
}

///|
pub impl TextureNodeClass for CubeTextureNode with fn get_default_uv(_, node) {
  let texture = TextureNode::get_value(node)
  if texture.mapping == @core.CubeReflectionMapping {
    reflect_vector
  } else if texture.mapping == @core.CubeRefractionMapping {
    refract_vector
  } else {
    @core.error(
      "CubeTextureNode: Mapping \"\{texture.mapping}\" not supported.",
    )
    vec3_of([0, 0, 0])
  }
}

///|
/// Ignores `.updateMatrix`.
pub impl TextureNodeClass for CubeTextureNode with fn set_update_matrix(_, _, _) {

}

///|
pub impl TextureNodeClass for CubeTextureNode with fn setup_uv(
  _,
  node,
  builder,
  uv_node,
) {
  let texture = TextureNode::get_value(node)
  if builder.renderer.coordinate_system() == @core.WebGPUCoordinateSystem ||
    (!texture.is_render_target_texture && !texture.is_depth_texture()) {
    return vec3_of([uv_node.x().negate(), uv_node.yz()])
  }
  uv_node
}

///|
pub impl TextureNodeClass for CubeTextureNode with fn generate_uv(
  self,
  _,
  builder,
  cube_uv,
) {
  cube_uv.build(
    builder,
    output=if self.texture.sampler { "vec3" } else { "ivec3" },
  )
}

///|
pub impl TextureNodeClass for CubeTextureNode with fn construct_like(
  _,
  value,
  uv_node,
  level_node,
  bias_node,
) {
  CubeTextureNode::new(value, uv_node?, level_node?, bias_node?)
}

///|
/// The constructor body.
pub fn CubeTextureNode::construct(
  node : Node,
  value : @core.Texture?,
  uv_node : Node?,
  level_node : Node?,
  bias_node : Node?,
) -> CubeTextureNode {
  let texture = TextureNode::construct(
    node, value, uv_node, level_node, bias_node,
  )
  // `setUpdateMatrix` is a no-op here, so `updateMatrix` keeps its `false`.
  texture.update_matrix = false
  { texture, }
}

///|
/// `new CubeTextureNode( value, uvNode = null, levelNode = null, biasNode = null )`.
pub fn CubeTextureNode::new(
  value : @core.Texture?,
  uv_node? : Node,
  level_node? : Node,
  bias_node? : Node,
) -> Node {
  let node = Node::alloc()
  let c = CubeTextureNode::construct(
    node, value, uv_node, level_node, bias_node,
  )
  c.texture.install(node, c, c, c)
}

///|
pub fn CubeTextureNode::of(node : Node) -> CubeTextureNode? {
  match node.class_payload("CubeTextureNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `cubeTextureBase( value, uvNode, levelNode, biasNode )`.
pub fn cube_texture_base(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  bias_node? : &IntoTsl,
) -> Node {
  CubeTextureNode::new(
    texture_node_texture_arg(value.to_tsl()),
    uv_node?=texture_node_node_arg(texture_node_opt_arg(uv_node)),
    level_node?=texture_node_node_arg(texture_node_opt_arg(level_node)),
    bias_node?=texture_node_node_arg(texture_node_opt_arg(bias_node)),
  )
}

///|
/// `cubeTexture( value = EmptyTexture, uvNode = null, levelNode = null, biasNode = null )`.
pub fn cube_texture(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  level_node? : &IntoTsl,
  bias_node? : &IntoTsl,
) -> Node {
  match value.to_tsl() {
    Node(v) if v.has_flag("isCubeTextureNode") => {
      let texture_node = TextureNode::clone(v)
      let t = texture_node_payload(texture_node)
      // Ensure the reference is set to the original node
      t.reference_node = Some(v)
      if uv_node is Some(u) {
        t.uv_node = Some(node_object(u.to_tsl()))
      }
      if level_node is Some(l) {
        t.level_node = Some(node_object(l.to_tsl()))
      }
      if bias_node is Some(b) {
        t.bias_node = Some(node_object(b.to_tsl()))
      }
      texture_node
    }
    _ => cube_texture_base(value, uv_node?, level_node?, bias_node?)
  }
}

///|
/// `cubeTexture()` with the default `EmptyTexture`.
pub fn cube_texture_empty() -> Node {
  cube_texture(_cube_texture_node_empty_texture)
}

///|
/// `uniformCubeTexture( value = EmptyTexture )`.
pub fn uniform_cube_texture(value? : @core.Texture) -> Node {
  let texture_node = cube_texture_base(
    value.unwrap_or(_cube_texture_node_empty_texture),
  )
  TextureNode::set_mergeable(texture_node, false)
  texture_node
}
