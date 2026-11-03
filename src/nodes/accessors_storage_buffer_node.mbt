// nodes/accessors/StorageBufferNode.js: a storage buffer (read/write in compute shaders,
// or emulated with a vertex attribute and transform feedback).

///|
/// `bufferType` of `storage( value, type, count )`: a type name or a struct type node.
pub(all) enum StorageBufferType {
  NoType
  Type(String)
  Struct(Node)
}

///|
pub(all) struct StorageBufferNode {
  buffer : BufferNode
  /// `this.value`.
  storage_attribute : @core.BufferAttribute
  struct_type_node : Node?
  mut access : String
  mut is_atomic : Bool
  mut is_pbo : Bool
  mut _attribute : Node?
  mut _varying : Node?
}

///|
pub impl NodeClass for StorageBufferNode with fn class_name(_) {
  "StorageBufferNode"
}

///|
pub impl NodeClass for StorageBufferNode with fn parent(self) {
  Some(self.buffer)
}

///|
pub impl NodeClass for StorageBufferNode with fn has_flag(self, flag) {
  flag == "isStorageBufferNode" || self.buffer.has_flag(flag)
}

///|
pub impl NodeClass for StorageBufferNode with fn children(self, node, out) {
  self.buffer.children(node, out)
  push_child(out, "structTypeNode", self.struct_type_node)
}

///|
pub impl NodeClass for StorageBufferNode with fn get_hash(self, node, builder) {
  let id = if self.buffer.buffer_count == 0 {
    buffer_attribute_global_node(
      builder,
      @core.JsValue::of(self.storage_attribute),
      node,
    ).id
  } else {
    node.id
  }
  id.to_string()
}

///|
pub impl NodeClass for StorageBufferNode with fn set_atomic(self, node, value) {
  self.is_atomic = value
  Some(node)
}

///|
pub impl NodeClass for StorageBufferNode with fn element(_, node, index_node) {
  Some(storage_element(node, index_node))
}

///|
pub impl NodeClass for StorageBufferNode with fn generate_node_type(
  self,
  node,
  builder,
  output,
) {
  match self.struct_type_node {
    Some(s) => s.get_node_type(builder)
    None => self.buffer.generate_node_type(node, builder, output)
  }
}

///|
pub impl NodeClass for StorageBufferNode with fn get_member_type(
  self,
  _,
  builder,
  name,
) {
  match self.struct_type_node {
    Some(s) => s.get_member_type(builder, name)
    None => "void"
  }
}

///|
pub impl NodeClass for StorageBufferNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for StorageBufferNode with fn generate(
  self,
  node,
  builder,
  _,
) {
  match self.struct_type_node {
    Some(s) => s.build(builder) |> ignore
    None => ()
  }
  if builder.is_available("storageBuffer") ||
    builder.is_available("indirectStorageBuffer") {
    return self.buffer.generate(node, builder, None)
  }
  let (attribute, varying) = StorageBufferNode::get_attribute_data(node)
  let output = varying.build(builder)
  builder.register_transform(output, attribute)
  Some(
    builder.format(
      output,
      attribute.get_node_type(builder),
      node.get_node_type(builder),
    ),
  )
}

///|
pub impl InputNodeClass for StorageBufferNode with fn input_parent(self) {
  Some(self.buffer)
}

///|
pub impl InputNodeClass for StorageBufferNode with fn get_input_type(self, _, _) {
  if is_indirect_storage_buffer_attribute(self.storage_attribute) {
    Some("indirectStorageBuffer")
  } else {
    Some("storageBuffer")
  }
}

///|
/// The constructor body.
pub fn StorageBufferNode::construct(
  node : Node,
  value : @core.BufferAttribute,
  buffer_type : StorageBufferType,
  buffer_count : Int32,
) -> StorageBufferNode {
  let mut buffer_count = buffer_count
  let is_storage = value.kind is (StorageAttribute | StorageInstancedAttribute)
  let (node_type, struct_type_node) = match buffer_type {
    Struct(s) if s.has_flag("isStructTypeNode") => {
      if is_storage {
        buffer_count = value.count
      }
      (Some("struct"), Some(s))
    }
    NoType if is_storage => {
      buffer_count = value.count
      (get_type_from_length(value.item_size), None)
    }
    Type(t) => (Some(t), None)
    _ => (None, None)
  }
  node.node_type = node_type
  let buffer = BufferNode::construct(
    node,
    Js(@core.JsValue::of(value)),
    node_type,
    buffer_count,
  )
  node.global = true
  if !is_storage {
    if value.kind is InstancedAttribute {
      value.kind = StorageInstancedAttribute
    } else {
      value.kind = StorageAttribute
    }
  }
  {
    buffer,
    storage_attribute: value,
    struct_type_node,
    access: node_access_read_write,
    is_atomic: false,
    is_pbo: false,
    _attribute: None,
    _varying: None,
  }
}

///|
/// `new StorageBufferNode( value, bufferType = null, bufferCount = 0 )`.
pub fn StorageBufferNode::new(
  value : @core.BufferAttribute,
  buffer_type~ : StorageBufferType = NoType,
  buffer_count~ : Int32 = 0,
) -> Node {
  let node = Node::alloc()
  let s = StorageBufferNode::construct(node, value, buffer_type, buffer_count)
  s.buffer.uniform.input.class_ = s
  node.set_class(s)
}

///|
pub fn StorageBufferNode::of(node : Node) -> StorageBufferNode? {
  match node.class_payload("StorageBufferNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn storage_buffer_node_payload(node : Node) -> StorageBufferNode {
  match StorageBufferNode::of(node) {
    Some(s) => s
    None => abort("TypeError: \{node.type_()} is not a StorageBufferNode")
  }
}

///|
/// `setPBO( value )`, chained.
pub fn Node::set_pbo(self : Node, value : Bool) -> Node {
  storage_buffer_node_payload(self).is_pbo = value
  self
}

///|
/// `getPBO()`.
pub fn Node::get_pbo(self : Node) -> Bool {
  storage_buffer_node_payload(self).is_pbo
}

///|
/// `setAccess( value )`, chained: storage buffers and storage textures.
pub fn Node::set_access(self : Node, value : String) -> Node {
  match StorageBufferNode::of(self) {
    Some(s) => s.access = value
    None =>
      match StorageTextureNode::of(self) {
        Some(s) => s.access = value
        None => abort("TypeError: \{self.type_()}.setAccess is not a function")
      }
  }
  self
}

///|
/// `toReadOnly()`: storage buffers and storage textures.
pub fn Node::to_read_only(self : Node) -> Node {
  self.set_access(node_access_read_only)
}

///|
/// `getAttributeData()`: the buffer attribute and its varying for the WebGL fallback.
pub fn StorageBufferNode::get_attribute_data(node : Node) -> (Node, Node) {
  let s = storage_buffer_node_payload(node)
  if s._attribute is None {
    let attribute = buffer_attribute(s.storage_attribute)
    s._attribute = Some(attribute)
    s._varying = Some(varying(attribute))
  }
  (s._attribute.unwrap(), s._varying.unwrap())
}

///|
/// `storage( value, type = null, count = 0 )`; `type_` is a type name or a struct type
/// node.
pub fn storage(
  value : @core.BufferAttribute,
  type_? : &IntoTsl,
  count~ : Int32 = 0,
) -> Node {
  let buffer_type : StorageBufferType = match type_ {
    None => NoType
    Some(t) =>
      match t.to_tsl() {
        String(s) => Type(s)
        Node(n) => Struct(n)
        _ => NoType
      }
  }
  StorageBufferNode::new(value, buffer_type~, buffer_count=count)
}
