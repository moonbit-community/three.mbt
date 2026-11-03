// renderers/common/nodes/NodeUniformBuffer.js: a uniform buffer whose data and update
// ranges live on a `BufferNode` (upstream passes the node as `nodeUniform`).

///|
let _node_uniform_buffer_id : Ref[Int32] = Ref(0)

///|
/// The `NodeUniformBuffer` class payload.
pub(all) struct NodeUniformBuffer {
  parent_ : UniformBuffer
  /// The `BufferNode`; `None` only in a binding made by `new this.constructor()`.
  mut node_uniform : Node?
  mut group_node : Node?
}

///|
pub impl BindingClass for NodeUniformBuffer with fn class_name(_) {
  "NodeUniformBuffer"
}

///|
pub impl BindingClass for NodeUniformBuffer with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeUniformBuffer with fn has_flag(self, flag) {
  flag == "isNodeUniformBuffer" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for NodeUniformBuffer with fn group_node(self) {
  self.group_node
}

///|
/// `new this.constructor()` (which takes the next label id) then `Object.assign`.
pub impl BindingClass for NodeUniformBuffer with fn copy_class(self) {
  _node_uniform_buffer_id.val += 1
  NodeUniformBuffer::{
    parent_: self.parent_.copy_payload(),
    node_uniform: self.node_uniform,
    group_node: self.group_node,
  }
}

///|
pub impl BindingClass for NodeUniformBuffer with fn update_ranges(self, _) {
  _node_uniform_buffer_node_ranges(self.node_uniform)
}

///|
pub impl BindingClass for NodeUniformBuffer with fn set_update_ranges(
  self,
  _,
  value,
) {
  _node_uniform_buffer_set_node_ranges(self.node_uniform, value)
}

///|
pub impl BindingClass for NodeUniformBuffer with fn add_update_range(
  self,
  _,
  start,
  count,
) {
  _node_uniform_buffer_node_add_range(self.node_uniform, start, count)
}

///|
pub impl BindingClass for NodeUniformBuffer with fn clear_update_ranges(self, _) {
  _node_uniform_buffer_node_clear_ranges(self.node_uniform)
}

///|
pub impl BindingClass for NodeUniformBuffer with fn buffer(self, _) {
  match self.node_uniform {
    Some(node) => _node_uniform_buffer_typed_value(node)
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'value')")
  }
}

///|
/// `node.value` as a typed array (`TslValue::Js`); `None` for `null`.
fn _node_uniform_buffer_typed_value(node : Node) -> @core.TypedArray? {
  match InputNode::get_value(node) {
    Js(v) => if v.is_null() || v.is_undefined() { None } else { Some(v.cast()) }
    Null | Undefined => None
    _ => abort("NodeUniformBuffer: the buffer node value is not a typed array")
  }
}

///|
/// The `label` of `'UniformBuffer_' + label`: the node's name, or the next id.
fn _node_uniform_buffer_label(node : Node?, id : Ref[Int32]) -> String {
  match node {
    Some({ name: Some(name), .. }) if name != "" => name
    _ => {
      let label = id.val
      id.val += 1
      label.to_string()
    }
  }
}

///|
/// `new NodeUniformBuffer( nodeUniform, groupNode )`.
pub fn NodeUniformBuffer::new(
  node_uniform : Node,
  group_node : Node?,
) -> Binding {
  let label = _node_uniform_buffer_label(
    Some(node_uniform),
    _node_uniform_buffer_id,
  )
  let binding = Binding::new(name="UniformBuffer_" + label)
  binding.class_ = NodeUniformBuffer::{
    parent_: UniformBuffer::construct(None),
    node_uniform: Some(node_uniform),
    group_node,
  }
  binding
}

///|
pub fn NodeUniformBuffer::of(binding : Binding) -> NodeUniformBuffer? {
  match binding.class_payload("NodeUniformBuffer") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `binding.nodeUniform` of `NodeUniformBuffer` and `NodeStorageBuffer`: the buffer node.
pub fn Binding::node_uniform(self : Binding) -> Node? {
  match NodeUniformBuffer::of(self) {
    Some(b) => b.node_uniform
    None =>
      match NodeStorageBuffer::of(self) {
        Some(b) => b.node_uniform
        None => None
      }
  }
}

// The `BufferNode` members upstream reads through `nodeUniform`.

///|
fn _node_uniform_buffer_node(node : Node?) -> BufferNode {
  match node {
    Some(n) =>
      match BufferNode::of(n) {
        Some(b) => b
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'length')",
          )
      }
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'updateRanges')",
      )
  }
}

///|
fn _node_uniform_buffer_node_ranges(node : Node?) -> Array[@core.UpdateRange] {
  _node_uniform_buffer_node(node).update_ranges
}

///|
fn _node_uniform_buffer_set_node_ranges(
  node : Node?,
  value : Array[@core.UpdateRange],
) -> Unit {
  _node_uniform_buffer_node(node).update_ranges = value
}

///|
fn _node_uniform_buffer_node_add_range(
  node : Node?,
  start : Int32,
  count : Int32,
) -> Unit {
  match node {
    Some(n) => n.add_update_range(start, count)
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'addUpdateRange')",
      )
  }
}

///|
fn _node_uniform_buffer_node_clear_ranges(node : Node?) -> Unit {
  match node {
    Some(n) => n.clear_update_ranges()
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'clearUpdateRanges')",
      )
  }
}
