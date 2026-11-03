// nodes/accessors/BufferNode.js: a uniform buffer (an array of `bufferType` elements).
// UniformArrayNode and StorageBufferNode extend it.

///|
pub(all) struct BufferNode {
  uniform : UniformNode
  mut buffer_type : String?
  mut buffer_count : Int32
  mut update_ranges : Array[@core.UpdateRange]
}

///|
pub impl NodeClass for BufferNode with fn class_name(_) {
  "BufferNode"
}

///|
pub impl NodeClass for BufferNode with fn parent(self) {
  Some(self.uniform)
}

///|
pub impl NodeClass for BufferNode with fn has_flag(self, flag) {
  flag == "isBufferNode" || self.uniform.has_flag(flag)
}

///|
pub impl NodeClass for BufferNode with fn get_element_type(_, node, builder) {
  node.get_node_type(builder)
}

///|
pub impl InputNodeClass for BufferNode with fn input_parent(self) {
  Some(self.uniform)
}

///|
pub impl InputNodeClass for BufferNode with fn get_input_type(_, _, _) {
  Some("buffer")
}

///|
/// The constructor body: `super( value, bufferType )` has run in `Node::alloc`.
pub fn BufferNode::construct(
  node : Node,
  value : TslValue,
  buffer_type : String?,
  buffer_count : Int32,
) -> BufferNode {
  let uniform = UniformNode::construct(node, value)
  { uniform, buffer_type, buffer_count, update_ranges: [], }
}

///|
/// `new BufferNode( value, bufferType, bufferCount = 0 )`.
pub fn BufferNode::new(
  value : TslValue,
  buffer_type : String?,
  buffer_count~ : Int32 = 0,
) -> Node {
  let node = Node::alloc(node_type?=buffer_type)
  let b = BufferNode::construct(node, value, buffer_type, buffer_count)
  b.uniform.input.class_ = b
  node.set_class(b)
}

///|
pub fn BufferNode::of(node : Node) -> BufferNode? {
  match node.class_payload("BufferNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn buffer_node_payload(node : Node) -> BufferNode {
  match BufferNode::of(node) {
    Some(b) => b
    None => abort("TypeError: \{node.type_()} is not a BufferNode")
  }
}

///|
/// `addUpdateRange( start, count )`.
pub fn Node::add_update_range(
  self : Node,
  start : Int32,
  count : Int32,
) -> Unit {
  buffer_node_payload(self).update_ranges.push({ start, count, })
}

///|
/// `clearUpdateRanges()`.
pub fn Node::clear_update_ranges(self : Node) -> Unit {
  buffer_node_payload(self).update_ranges.clear()
}

///|
/// A typed array passes to TSL as itself (`buffer( array, 'mat4', count )`).
pub impl IntoTsl for @core.TypedArray with fn to_tsl(self) {
  Js(@core.JsValue::of(self))
}

///|
/// `buffer( value, type, count )`.
pub fn buffer(value : &IntoTsl, type_ : String, count : Int32) -> Node {
  BufferNode::new(value.to_tsl(), Some(type_), buffer_count=count)
}
