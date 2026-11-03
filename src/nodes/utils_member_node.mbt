// nodes/utils/MemberNode.js

///|
pub(all) struct MemberNode {
  mut struct_node : Node
  mut property : String
}

///|
pub impl NodeClass for MemberNode with fn class_name(_) {
  "MemberNode"
}

///|
pub impl NodeClass for MemberNode with fn has_flag(_, flag) {
  flag == "isMemberNode"
}

///|
pub impl NodeClass for MemberNode with fn children(self, _, out) {
  push_child(out, "structNode", Some(self.struct_node))
}

///|
pub impl NodeClass for MemberNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for MemberNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for MemberNode with fn get_scope(self, _) {
  self.struct_node.get_scope()
}

///|
pub impl NodeClass for MemberNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  if !self.has_member(builder) {
    // default type if member does not exist
    return Some("float")
  }
  Some(self.struct_node.get_member_type(builder, self.property))
}

///|
pub impl NodeClass for MemberNode with fn get_member_type(
  self,
  node,
  builder,
  name,
) {
  if !self.has_member(builder) {
    // default type if member does not exist
    return "float"
  }
  let type_ = node.get_node_type(builder)
  match builder.get_struct_type_node(type_.unwrap_or("null")) {
    Some(struct_) => struct_.get_member_type(builder, name)
    None =>
      abort(
        "MemberNode: Cannot read properties of null (reading 'getMemberType')",
      )
  }
}

///|
pub impl NodeClass for MemberNode with fn generate(self, node, builder, _) {
  if !self.has_member(builder) {
    @core.warn("TSL: Member \"\{self.property}\" does not exist in struct.")
    let type_ = node.get_node_type(builder)
    return Some(builder.generate_const(type_.unwrap()))
  }
  let property_name = self.struct_node.build(builder)
  Some(property_name + "." + self.property)
}

///|
/// `hasMember( builder )`: whether the struct (and each struct it is a member of) has
/// the member.
pub fn MemberNode::has_member(self : MemberNode, builder : NodeBuilder) -> Bool {
  if MemberNode::of(self.struct_node) is Some(parent) {
    if !parent.has_member(builder) {
      return false
    }
  }
  self.struct_node.get_member_type(builder, self.property) != "void"
}

///|
pub fn MemberNode::construct(
  _node : Node,
  struct_node : Node,
  property : String,
) -> MemberNode {
  { struct_node, property, }
}

///|
/// `new MemberNode( structNode, property )`.
pub fn MemberNode::new(struct_node : Node, property : String) -> Node {
  let n = Node::alloc()
  n.set_class(MemberNode::construct(n, struct_node, property))
}

///|
pub fn MemberNode::of(node : Node) -> MemberNode? {
  match node.class_payload("MemberNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
