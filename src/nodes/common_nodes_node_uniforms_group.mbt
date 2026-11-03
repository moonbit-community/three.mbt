// renderers/common/nodes/NodeUniformsGroup.js

///|
let _node_uniforms_group_id : Ref[Int32] = Ref(0)

///|
/// The `NodeUniformsGroup` class payload.
pub(all) struct NodeUniformsGroup {
  parent_ : UniformsGroup
  mut id : Int32
  mut group_node : Node?
}

///|
pub impl BindingClass for NodeUniformsGroup with fn class_name(_) {
  "NodeUniformsGroup"
}

///|
pub impl BindingClass for NodeUniformsGroup with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeUniformsGroup with fn has_flag(self, flag) {
  flag == "isNodeUniformsGroup" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for NodeUniformsGroup with fn group_node(self) {
  self.group_node
}

///|
/// `new this.constructor()` (which takes the next id) then `Object.assign`.
pub impl BindingClass for NodeUniformsGroup with fn copy_class(self) {
  _node_uniforms_group_id.val += 1
  NodeUniformsGroup::{
    parent_: self.parent_.copy_payload(),
    id: self.id,
    group_node: self.group_node,
  }
}

///|
/// `new NodeUniformsGroup( name, groupNode )`.
pub fn NodeUniformsGroup::new(name : String, group_node : Node) -> Binding {
  let binding = Binding::new(name~)
  let id = _node_uniforms_group_id.val
  _node_uniforms_group_id.val += 1
  binding.class_ = NodeUniformsGroup::{
    parent_: UniformsGroup::construct(),
    id,
    group_node: Some(group_node),
  }
  binding
}

///|
pub fn NodeUniformsGroup::of(binding : Binding) -> NodeUniformsGroup? {
  match binding.class_payload("NodeUniformsGroup") {
    Some(p) => Some(p.cast())
    None => None
  }
}
