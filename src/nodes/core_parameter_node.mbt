// nodes/core/ParameterNode.js

///|
/// A function parameter, referenced by name.
pub(all) struct ParameterNode {
  property : PropertyNode
}

///|
pub impl NodeClass for ParameterNode with fn class_name(_) {
  "ParameterNode"
}

///|
pub impl NodeClass for ParameterNode with fn parent(self) {
  Some(self.property)
}

///|
pub impl NodeClass for ParameterNode with fn has_flag(self, flag) {
  flag == "isParameterNode" || self.property.has_flag(flag)
}

///|
pub impl NodeClass for ParameterNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for ParameterNode with fn get_member_type(
  _,
  node,
  builder,
  name,
) {
  let type_ = node.get_node_type(builder)
  match builder.get_struct_type_node(type_.unwrap_or("null")) {
    Some(struct_) => struct_.get_member_type(builder, name)
    None => {
      @core.error(
        "TSL: Member \"\{name}\" not found in struct \"\{type_.unwrap_or("null")}\".",
      )
      "float"
    }
  }
}

///|
pub impl NodeClass for ParameterNode with fn get_hash(_, node, _) {
  node.id.to_string()
}

///|
pub impl NodeClass for ParameterNode with fn generate(_, node, _, _) {
  node.name
}

///|
pub fn ParameterNode::construct(node : Node, name : String?) -> ParameterNode {
  { property: PropertyNode::construct(node, name, Bool(false), Null), }
}

///|
/// `new ParameterNode( nodeType, name = null )`.
pub fn ParameterNode::new(node_type : String, name? : String) -> Node {
  let node = Node::alloc(node_type~)
  node.set_class(ParameterNode::construct(node, name))
}

///|
pub fn ParameterNode::of(node : Node) -> ParameterNode? {
  match node.class_payload("ParameterNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `parameter( type, name )`.
pub fn parameter(type_ : String, name? : String) -> Node {
  ParameterNode::new(type_, name?)
}
