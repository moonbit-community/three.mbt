// nodes/utils/StorageArrayElementNode.js: an element of a storage buffer, read through
// a PBO where storage buffers are unavailable (WebGL).

///|
pub(all) struct StorageArrayElementNode {
  array_element : ArrayElementNode
}

///|
pub impl NodeClass for StorageArrayElementNode with fn class_name(_) {
  "StorageArrayElementNode"
}

///|
pub impl NodeClass for StorageArrayElementNode with fn parent(self) {
  Some(self.array_element)
}

///|
pub impl NodeClass for StorageArrayElementNode with fn has_flag(self, flag) {
  flag == "isStorageArrayElementNode" ||
  NodeClass::has_flag(self.array_element, flag)
}

///|
pub impl NodeClass for StorageArrayElementNode with fn generate_uses_output(_) {
  true
}

///|
/// `this.node.isPBO === true`.
fn storage_array_element_is_pbo(node : Node) -> Bool {
  match StorageBufferNode::of(node) {
    Some(s) => s.is_pbo
    None => false
  }
}

///|
pub impl NodeClass for StorageArrayElementNode with fn get_member_type(
  self,
  _,
  builder,
  name,
) {
  let struct_type_node = match StorageBufferNode::of(self.array_element.node) {
    Some(s) => s.struct_type_node
    None => None
  }
  match struct_type_node {
    Some(s) => s.get_member_type(builder, name)
    None => "void"
  }
}

///|
pub impl NodeClass for StorageArrayElementNode with fn setup(
  self,
  node,
  builder,
) {
  if builder.is_available("storageBuffer") == false {
    if storage_array_element_is_pbo(self.array_element.node) {
      builder.setup_pbo(self.array_element.node)
    }
  }
  NodeClass::setup(self.array_element, node, builder)
}

///|
pub impl NodeClass for StorageArrayElementNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let storage_node = self.array_element.node
  let is_assign_context = builder.is_context_assign()
  let mut snippet = if builder.is_available("storageBuffer") == false {
    let is_instanced = match StorageBufferNode::of(storage_node) {
      Some(s) => s.storage_attribute.is_instanced_buffer_attribute()
      None => false
    }
    if storage_array_element_is_pbo(storage_node) &&
      is_assign_context != true &&
      (is_instanced || builder.shader_stage != Some("compute")) {
      builder.generate_pbo(node)
    } else {
      storage_node.build(builder)
    }
  } else {
    NodeClass::generate(self.array_element, node, builder, None).unwrap_or("")
  }
  if is_assign_context != true {
    let type_ = node.get_node_type(builder)
    snippet = builder.format(snippet, type_, output)
  }
  Some(snippet)
}

///|
/// The constructor body: `super( storageBufferNode, indexNode )`.
pub fn StorageArrayElementNode::construct(
  node : Node,
  storage_buffer_node : Node,
  index_node : Node,
) -> StorageArrayElementNode {
  {
    array_element: ArrayElementNode::construct(
      node, storage_buffer_node, index_node,
    ),
  }
}

///|
/// `new StorageArrayElementNode( storageBufferNode, indexNode )`.
pub fn StorageArrayElementNode::new(
  storage_buffer_node : Node,
  index_node : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(
    StorageArrayElementNode::construct(node, storage_buffer_node, index_node),
  )
}

///|
pub fn StorageArrayElementNode::of(node : Node) -> StorageArrayElementNode? {
  match node.class_payload("StorageArrayElementNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `get storageBufferNode()`.
pub fn StorageArrayElementNode::storage_buffer_node(
  self : StorageArrayElementNode,
) -> Node {
  self.array_element.node
}

///|
/// `set storageBufferNode( value )`.
pub fn StorageArrayElementNode::set_storage_buffer_node(
  self : StorageArrayElementNode,
  value : Node,
) -> Unit {
  self.array_element.node = value
}

///|
/// `storageElement( storageBufferNode, indexNode )` (`nodeProxy`).
pub fn storage_element(
  storage_buffer_node : &IntoTsl,
  index_node : &IntoTsl,
) -> Node {
  let p = tsl_verify_params(
    "StorageArrayElementNode",
    [storage_buffer_node.to_tsl(), index_node.to_tsl()],
    2,
    2,
  )
  let nodes = p.map(tsl_proxy_arg)
  StorageArrayElementNode::new(
    operator_node_required(nodes[0]),
    operator_node_required(nodes[1]),
  )
}
