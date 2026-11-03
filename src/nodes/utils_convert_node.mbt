// nodes/utils/ConvertNode.js

///|
pub(all) struct ConvertNode {
  mut node : Node
  /// One type or overloads joined by `|` (`'float|vec2'`).
  mut convert_to : String
}

///|
pub impl NodeClass for ConvertNode with fn class_name(_) {
  "ConvertNode"
}

///|
pub impl NodeClass for ConvertNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for ConvertNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  let request_type = self.node.get_node_type(builder)
  let mut convert_to : String? = None
  for overloading_type in self.convert_to.split("|") {
    let overloading_type = overloading_type.to_owned()
    if convert_to is None ||
      builder.get_type_length(request_type) ==
      builder.get_type_length(Some(overloading_type)) {
      convert_to = Some(overloading_type)
    }
  }
  convert_to
}

///|
pub impl NodeClass for ConvertNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("convertTo", @core.JsValue::of(self.convert_to))
}

///|
pub impl NodeClass for ConvertNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self.convert_to = data.get("convertTo").cast()
}

///|
pub impl NodeClass for ConvertNode with fn generate(self, node, builder, output) {
  let type_ = node.get_node_type(builder)
  let snippet = self.node.build(builder, output?=type_)
  Some(builder.format(snippet, type_, output))
}

///|
pub fn ConvertNode::construct(
  _node : Node,
  node : Node,
  convert_to : String,
) -> ConvertNode {
  { node, convert_to, }
}

///|
/// `new ConvertNode( node, convertTo )`.
pub fn ConvertNode::new(node : Node, convert_to : String) -> Node {
  let n = Node::alloc()
  n.set_class(ConvertNode::construct(n, node, convert_to))
}

///|
pub fn ConvertNode::of(node : Node) -> ConvertNode? {
  match node.class_payload("ConvertNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
