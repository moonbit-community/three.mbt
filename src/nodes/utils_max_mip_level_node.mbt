// nodes/utils/MaxMipLevelNode.js: a uniform holding the highest mip level of a
// texture, updated once per frame.

///|
pub(all) struct MaxMipLevelNode {
  uniform : UniformNode
  /// `_textureNode`.
  _texture_node : Node
}

///|
pub impl NodeClass for MaxMipLevelNode with fn class_name(_) {
  "MaxMipLevelNode"
}

///|
pub impl NodeClass for MaxMipLevelNode with fn parent(self) {
  Some(self.uniform)
}

///|
pub impl InputNodeClass for MaxMipLevelNode with fn input_parent(self) {
  Some(self.uniform)
}

///|
/// `( images && images.length > 0 ) ? ( images[ 0 ].image || images[ 0 ] ) :
/// texture.image`, then `Math.log2( Math.max( width, height ) )` if it has a width.
extern "js" fn utils_max_mip_level(
  images : @core.JsValue,
  image : @core.JsValue,
) -> @core.JsValue =
  #|( images, textureImage ) => {
  #|  const image = ( images && images.length > 0 ) ? ( ( images[ 0 ] && images[ 0 ].image ) || images[ 0 ] ) : textureImage;
  #|  if ( image && image.width !== undefined ) {
  #|    const { width, height } = image;
  #|    return Math.log2( Math.max( width, height ) );
  #|  }
  #|  return undefined;
  #|}

///|
pub impl NodeClass for MaxMipLevelNode with fn update(self, node, _) {
  let texture = match utils_node_value(self._texture_node) {
    Texture(t) => t
    _ => abort("TypeError: Cannot read properties of null (reading 'images')")
  }
  let images = if texture.is_cube_texture() {
    texture.images().to_js()
  } else {
    @core.JsValue::undefined()
  }
  let value = utils_max_mip_level(images, texture.image().to_js())
  if !value.is_undefined() {
    InputNode::set_value(node, Number(value.cast()))
  }
  None
}

///|
/// The constructor body: `super( 0 )` is `UniformNode::construct`.
pub fn MaxMipLevelNode::construct(
  node : Node,
  texture_node : Node,
) -> MaxMipLevelNode {
  let uniform = UniformNode::construct(node, Number(0.0))
  node.update_type = NodeUpdateType::frame()
  { uniform, _texture_node: texture_node, }
}

///|
/// `new MaxMipLevelNode( textureNode )`.
pub fn MaxMipLevelNode::new(texture_node : Node) -> Node {
  let node = Node::alloc()
  let payload = MaxMipLevelNode::construct(node, texture_node)
  payload.uniform.input.class_ = payload
  node.set_class(payload)
}

///|
pub fn MaxMipLevelNode::of(node : Node) -> MaxMipLevelNode? {
  match node.class_payload("MaxMipLevelNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `get textureNode()`.
pub fn MaxMipLevelNode::texture_node(self : MaxMipLevelNode) -> Node {
  self._texture_node
}

///|
/// `get texture()`: the texture node's value.
pub fn MaxMipLevelNode::texture(self : MaxMipLevelNode) -> TslValue {
  utils_node_value(self._texture_node)
}

///|
/// `maxMipLevel( textureNode )` (`nodeProxy( MaxMipLevelNode )`).
pub fn max_mip_level(texture_node : &IntoTsl) -> Node {
  MaxMipLevelNode::new(
    operator_node_required(tsl_proxy_arg(texture_node.to_tsl())),
  )
}
