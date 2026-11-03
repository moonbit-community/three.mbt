// nodes/core/ArrayNode.js

///|
/// A constant array of `count` elements (`values` or zero-initialized).
pub(all) struct ArrayNode {
  mut count : Int32
  mut values : Array[Node]?
}

///|
pub impl NodeClass for ArrayNode with fn class_name(_) {
  "ArrayNode"
}

///|
pub impl NodeClass for ArrayNode with fn has_flag(_, flag) {
  flag == "isArrayNode"
}

///|
pub impl NodeClass for ArrayNode with fn children(self, _, out) {
  if self.values is Some(values) {
    push_children(out, "values", values.map(fn(v) { Some(v) }))
  }
}

///|
pub impl NodeClass for ArrayNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for ArrayNode with fn get_array_count(self, _, _) {
  Some(self.count)
}

///|
pub impl NodeClass for ArrayNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  match node.node_type {
    None => self.values.unwrap()[0].get_node_type(builder)
    t => t
  }
}

///|
pub impl NodeClass for ArrayNode with fn get_element_type(_, node, builder) {
  node.get_node_type(builder)
}

///|
pub impl NodeClass for ArrayNode with fn get_member_type(
  self,
  node,
  builder,
  name,
) {
  if node.node_type is None {
    return self.values.unwrap()[0].get_member_type(builder, name)
  }
  "void"
}

///|
pub impl NodeClass for ArrayNode with fn generate(self, node, builder, _) {
  let type_ = node.get_node_type(builder)
  Some(
    builder.generate_array(
      type_.unwrap_or("null"),
      Some(self.count),
      values?=self.values,
    ),
  )
}

///|
pub fn ArrayNode::construct(
  _node : Node,
  count : Int32,
  values : Array[Node]?,
) -> ArrayNode {
  { count, values, }
}

///|
/// `new ArrayNode( nodeType, count, values = null )`.
pub fn ArrayNode::new(
  node_type : String?,
  count : Int32,
  values? : Array[Node],
) -> Node {
  let node = Node::alloc(node_type?)
  node.set_class(ArrayNode::construct(node, count, values))
}

///|
pub fn ArrayNode::of(node : Node) -> ArrayNode? {
  match node.class_payload("ArrayNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `array( values )`: an array of the given values.
pub fn array(values : Array[&IntoTsl]) -> Node {
  let values = values.map(fn(v) { node_object(v.to_tsl()) })
  ArrayNode::new(None, values.length(), values~)
}

///|
/// `array( nodeType, count )`: a zero-initialized array.
pub fn array_of_type(node_type : String, count : Int32) -> Node {
  ArrayNode::new(Some(node_type), count)
}

///|
/// `toArray( count )`: an array of `count` copies of this node.
pub fn Node::to_array(self : Node, count : Int32) -> Node {
  array(Array::make(count, (self : &IntoTsl)))
}
