// nodes/accessors/TextureSizeNode.js

///|
pub(all) struct TextureSizeNode {
  mut texture_node : Node
  mut level_node : Node?
}

///|
pub impl NodeClass for TextureSizeNode with fn class_name(_) {
  "TextureSizeNode"
}

///|
pub impl NodeClass for TextureSizeNode with fn has_flag(_, flag) {
  flag == "isTextureSizeNode"
}

///|
pub impl NodeClass for TextureSizeNode with fn children(self, _, out) {
  push_child(out, "textureNode", Some(self.texture_node))
  push_child(out, "levelNode", self.level_node)
}

///|
pub impl NodeClass for TextureSizeNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for TextureSizeNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for TextureSizeNode with fn generate(self, node, builder, _) {
  let texture_property = self.texture_node.build(builder, output="property")
  let level = match self.level_node {
    None => "0"
    Some(l) => l.build(builder, output="int")
  }
  let snippet = builder.generate_texture_size(
    TextureNode::get_value(self.texture_node),
    texture_property,
    level,
  )
  Some(builder.format(snippet, node.get_node_type(builder), None))
}

///|
/// The constructor body: `super( 'uvec2' )` has run in `Node::alloc`.
pub fn TextureSizeNode::construct(
  _node : Node,
  texture_node : Node,
  level_node : Node?,
) -> TextureSizeNode {
  { texture_node, level_node, }
}

///|
/// `new TextureSizeNode( textureNode, levelNode = null )`.
pub fn TextureSizeNode::new(texture_node : Node, level_node? : Node) -> Node {
  let node = Node::alloc(node_type="uvec2")
  node.set_class(TextureSizeNode::construct(node, texture_node, level_node))
}

///|
pub fn TextureSizeNode::of(node : Node) -> TextureSizeNode? {
  match node.class_payload("TextureSizeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `textureSize( textureNode, levelNode = null )`.
pub fn texture_size(texture_node : &IntoTsl, level_node? : &IntoTsl) -> Node {
  TextureSizeNode::new(
    node_object(texture_node.to_tsl()),
    level_node?=level_node.map(fn(l) { node_object(l.to_tsl()) }),
  )
}
