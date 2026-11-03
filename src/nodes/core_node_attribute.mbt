// nodes/core/NodeAttribute.js

///|
pub(all) struct NodeAttribute {
  mut name : String
  mut type_ : String
  mut node : Node?
}

///|
pub fn NodeAttribute::new(
  name : String,
  type_ : String,
  node? : Node,
) -> NodeAttribute {
  { name, type_, node, }
}
