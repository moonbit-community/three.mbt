// nodes/core/NodeUniform.js

///|
/// A uniform declaration of a shader stage, backed by a `UniformNode`.
pub(all) struct NodeUniform {
  mut name : String
  mut type_ : String
  /// The `UniformNode` (or a subclass such as `TextureNode`).
  mut node : Node
}

///|
pub fn NodeUniform::new(
  name : String,
  type_ : String,
  node : Node,
) -> NodeUniform {
  { name, type_, node, }
}

///|
/// `get value()`: the uniform node's `value`.
pub fn NodeUniform::value(self : NodeUniform) -> TslValue {
  InputNode::get_value(self.node)
}

///|
/// `set value( val )`.
pub fn NodeUniform::set_value(self : NodeUniform, value : TslValue) -> Unit {
  InputNode::set_value(self.node, value)
}

///|
/// `get id()`: the uniform node's id.
pub fn NodeUniform::id(self : NodeUniform) -> Int32 {
  self.node.id
}

///|
/// `get groupNode()`: the uniform node's `UniformGroupNode`.
pub fn NodeUniform::group_node(self : NodeUniform) -> Node {
  match UniformNode::of(self.node) {
    Some(u) => u.group_node
    None => abort("NodeUniform::group_node: not a UniformNode")
  }
}
