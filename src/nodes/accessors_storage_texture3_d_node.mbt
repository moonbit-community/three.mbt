// nodes/accessors/StorageTexture3DNode.js

///|
pub(all) struct StorageTexture3DNode {
  storage : StorageTextureNode
}

///|
pub impl NodeClass for StorageTexture3DNode with fn class_name(_) {
  "StorageTexture3DNode"
}

///|
pub impl NodeClass for StorageTexture3DNode with fn parent(self) {
  Some(self.storage)
}

///|
pub impl NodeClass for StorageTexture3DNode with fn has_flag(self, flag) {
  flag == "isStorageTexture3DNode" || self.storage.has_flag(flag)
}

///|
pub impl InputNodeClass for StorageTexture3DNode with fn input_parent(self) {
  Some(self.storage)
}

///|
pub impl TextureNodeClass for StorageTexture3DNode with fn texture_parent(self) {
  Some(self.storage)
}

///|
pub impl TextureNodeClass for StorageTexture3DNode with fn get_default_uv(_, _) {
  vec3_of([0.5, 0.5, 0.5])
}

///|
/// Ignores `.updateMatrix`.
pub impl TextureNodeClass for StorageTexture3DNode with fn set_update_matrix(
  _,
  _,
  _,
) {

}

///|
pub impl TextureNodeClass for StorageTexture3DNode with fn generate_uv(
  self,
  _,
  builder,
  uv_node,
) {
  uv_node.build(
    builder,
    output=if self.storage.texture.sampler { "vec3" } else { "ivec3" },
  )
}

///|
pub impl TextureNodeClass for StorageTexture3DNode with fn generate_offset(
  _,
  _,
  builder,
  offset_node,
) {
  offset_node.build(builder, output="ivec3")
}

///|
pub impl TextureNodeClass for StorageTexture3DNode with fn construct_like(
  _,
  value,
  uv_node,
  level_node,
  _,
) {
  StorageTexture3DNode::new(value, uv_node?, store_node?=level_node)
}

///|
/// `new StorageTexture3DNode( value, uvNode, storeNode = null )`.
pub fn StorageTexture3DNode::new(
  value : @core.Texture?,
  uv_node? : Node,
  store_node? : Node,
) -> Node {
  let node = Node::alloc()
  let storage = StorageTextureNode::construct(node, value, uv_node, store_node)
  // `setUpdateMatrix` is a no-op here, so `updateMatrix` keeps its `false`.
  storage.texture.update_matrix = false
  let s = StorageTexture3DNode::{ storage, }
  storage.texture.install(node, s, s, s)
}

///|
pub fn StorageTexture3DNode::of(node : Node) -> StorageTexture3DNode? {
  match node.class_payload("StorageTexture3DNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `storageTexture3D( value, uvNode, storeNode )`.
pub fn storage_texture3d(
  value : &IntoTsl,
  uv_node? : &IntoTsl,
  store_node? : &IntoTsl,
) -> Node {
  StorageTexture3DNode::new(
    texture_node_texture_arg(value.to_tsl()),
    uv_node?=texture_node_node_arg(texture_node_opt_arg(uv_node)),
    store_node?=texture_node_node_arg(texture_node_opt_arg(store_node)),
  )
}
