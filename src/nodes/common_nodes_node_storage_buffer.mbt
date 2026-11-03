// renderers/common/nodes/NodeStorageBuffer.js: a storage buffer whose attribute is the
// value of a `StorageBufferNode` (upstream passes the node as `nodeUniform`).

///|
let _node_storage_buffer_id : Ref[Int32] = Ref(0)

///|
/// The `NodeStorageBuffer` class payload.
pub(all) struct NodeStorageBuffer {
  parent_ : StorageBuffer
  /// The `StorageBufferNode`; `None` only in a binding made by `new this.constructor()`.
  mut node_uniform : Node?
  mut access : String
  mut group_node : Node?
}

///|
pub impl BindingClass for NodeStorageBuffer with fn class_name(_) {
  "NodeStorageBuffer"
}

///|
pub impl BindingClass for NodeStorageBuffer with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeStorageBuffer with fn group_node(self) {
  self.group_node
}

///|
/// `new this.constructor()` (which takes the next label id) then `Object.assign`.
pub impl BindingClass for NodeStorageBuffer with fn copy_class(self) {
  _node_storage_buffer_id.val += 1
  NodeStorageBuffer::{
    parent_: self.parent_.copy_payload(),
    node_uniform: self.node_uniform,
    access: self.access,
    group_node: self.group_node,
  }
}

///|
pub impl BindingClass for NodeStorageBuffer with fn attribute(self, _) {
  match self.node_uniform {
    Some(node) => _node_storage_buffer_attribute(node)
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'value')")
  }
}

///|
pub impl BindingClass for NodeStorageBuffer with fn buffer(self, _) {
  match self.node_uniform {
    Some(node) =>
      match _node_storage_buffer_attribute(node) {
        Some(attribute) => Some(attribute.array)
        None =>
          abort("TypeError: Cannot read properties of null (reading 'array')")
      }
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'value')")
  }
}

///|
/// `node.value`: the storage node's `BufferAttribute` (`TslValue::Js`).
fn _node_storage_buffer_attribute(node : Node) -> @core.BufferAttribute? {
  match InputNode::get_value(node) {
    Js(v) => if v.is_null() || v.is_undefined() { None } else { Some(v.cast()) }
    Null | Undefined => None
    _ => abort("NodeStorageBuffer: the storage node value is not an attribute")
  }
}

///|
/// `new NodeStorageBuffer( nodeUniform, groupNode )`.
pub fn NodeStorageBuffer::new(
  node_uniform : Node,
  group_node : Node?,
) -> Binding {
  let label = _node_uniform_buffer_label(
    Some(node_uniform),
    _node_storage_buffer_id,
  )
  let binding = Binding::new(name="StorageBuffer_" + label)
  binding.class_ = NodeStorageBuffer::{
    parent_: StorageBuffer::construct(None),
    node_uniform: Some(node_uniform),
    access: _node_storage_buffer_node_access(node_uniform),
    group_node,
  }
  binding
}

///|
pub fn NodeStorageBuffer::of(binding : Binding) -> NodeStorageBuffer? {
  match binding.class_payload("NodeStorageBuffer") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `storageBufferNode.access`.
fn _node_storage_buffer_node_access(node : Node) -> String {
  match StorageBufferNode::of(node) {
    Some(s) => s.access
    None =>
      abort("NodeStorageBuffer: \{node.type_()} is not a StorageBufferNode")
  }
}
