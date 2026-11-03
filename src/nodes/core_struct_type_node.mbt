// nodes/core/StructTypeNode.js

///|
/// `getMembersLayout( members )`: `{ name, type, atomic }` per member.
fn struct_type_node_members_layout(
  members : Array[StructMember],
) -> Array[StructMember] {
  members.map(fn(m) { StructMember::new(m.name, m.type_, atomic_=m.atomic_) })
}

///|
/// A struct type declared from a members layout.
pub(all) struct StructTypeNode {
  mut members_layout : Array[StructMember]
}

///|
pub impl NodeClass for StructTypeNode with fn class_name(_) {
  "StructTypeNode"
}

///|
pub impl NodeClass for StructTypeNode with fn has_flag(_, flag) {
  flag == "isStructTypeNode"
}

///|
pub impl NodeClass for StructTypeNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for StructTypeNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for StructTypeNode with fn get_member_type(self, _, _, name) {
  for member_ in self.members_layout {
    if member_.name == name {
      return member_.type_
    }
  }
  "void"
}

///|
pub impl NodeClass for StructTypeNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  let struct_type = builder.get_struct_type_from_node(
    node,
    self.members_layout,
    name?=node.name,
  )
  Some(struct_type.name)
}

///|
pub impl NodeClass for StructTypeNode with fn setup(self, node, builder) {
  builder.get_struct_type_from_node(node, self.members_layout, name?=node.name)
  |> ignore
  builder.add_include(node)
  None
}

///|
pub impl NodeClass for StructTypeNode with fn generate(_, node, builder, _) {
  node.get_node_type(builder)
}

///|
pub fn StructTypeNode::construct(
  node : Node,
  members_layout : Array[StructMember],
  name : String?,
) -> StructTypeNode {
  let struct_type = StructTypeNode::{
    members_layout: struct_type_node_members_layout(members_layout),
  }
  node.name = name
  struct_type
}

///|
/// `new StructTypeNode( membersLayout, name = null )`.
pub fn StructTypeNode::new(
  members_layout : Array[StructMember],
  name? : String,
) -> Node {
  let node = Node::alloc(node_type="struct")
  node.set_class(StructTypeNode::construct(node, members_layout, name))
}

///|
pub fn StructTypeNode::of(node : Node) -> StructTypeNode? {
  match node.class_payload("StructTypeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `getLength()`: the struct size in 4-byte elements, padded to its alignment.
pub fn StructTypeNode::get_length(self : StructTypeNode) -> Int32 {
  let mut max_alignment = 1
  let mut offset = 0
  for member_ in self.members_layout {
    let type_ = member_.type_
    let item_size = get_memory_length_from_type(type_)
    let alignment = get_alignment_from_type(type_)
    max_alignment = if alignment > max_alignment {
      alignment
    } else {
      max_alignment
    }
    let chunk_offset = offset % max_alignment
    let overhang = chunk_offset % alignment
    if overhang != 0 {
      offset += alignment - overhang
    }
    offset += item_size
  }
  (offset + max_alignment - 1) / max_alignment * max_alignment
}
