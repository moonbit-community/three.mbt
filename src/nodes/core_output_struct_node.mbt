// nodes/core/OutputStructNode.js

///|
/// The fragment output struct: member `m<i>` is `members[ i ]`.
pub(all) struct OutputStructNode {
  /// `None` entries are holes (MRTNode leaves unused attachments empty).
  mut members : Array[Node?]
}

///|
pub impl NodeClass for OutputStructNode with fn class_name(_) {
  "OutputStructNode"
}

///|
pub impl NodeClass for OutputStructNode with fn has_flag(_, flag) {
  flag == "isOutputStructNode"
}

///|
pub impl NodeClass for OutputStructNode with fn children(self, _, out) {
  push_children(out, "members", self.members)
}

///|
pub impl NodeClass for OutputStructNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for OutputStructNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for OutputStructNode with fn generate_node_type(_, _, _, _) {
  Some("OutputType")
}

///|
pub impl NodeClass for OutputStructNode with fn generate(self, node, builder, _) {
  let node_data = builder.get_data_from_node(node)
  let members_layout : Array[StructMember] = match
    node_data.extra.get("membersLayout") {
    Some(layout) => layout.cast()
    None => {
      let members = self.members
      let members_layout = []
      for i, member_ in members {
        let name = "m" + i.to_string()
        let type_ = member_.unwrap().get_node_type(builder).unwrap_or("null")
        members_layout.push(StructMember::new(name, type_, index=i))
      }
      node_data.extra.set("membersLayout", @core.JsValue::of(members_layout))
      node_data.struct_type = Some(
        builder.get_output_struct_type_from_node(node, members_layout),
      )
      members_layout
    }
  }
  let property_name = builder.get_output_struct_name()
  let members = self.members
  let struct_prefix = if property_name != "" { property_name + "." } else { "" }
  for i, member_ in members {
    let snippet = member_
      .unwrap()
      .build(builder, output=members_layout[i].type_)
    builder.add_line_flow_code("\{struct_prefix}m\{i} = \{snippet}", node~)
    |> ignore
  }
  Some(property_name)
}

///|
pub fn OutputStructNode::construct(
  _node : Node,
  members : Array[Node],
) -> OutputStructNode {
  { members: members.map(fn(m) { Some(m) }), }
}

///|
/// `new OutputStructNode( ...members )`.
pub fn OutputStructNode::new(members : Array[Node]) -> Node {
  let node = Node::alloc()
  node.set_class(OutputStructNode::construct(node, members))
}

///|
pub fn OutputStructNode::of(node : Node) -> OutputStructNode? {
  match node.class_payload("OutputStructNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `outputStruct( ...members )`.
pub fn output_struct(members : Array[&IntoTsl]) -> Node {
  OutputStructNode::new(members.map(fn(m) { node_object(m.to_tsl()) }))
}
