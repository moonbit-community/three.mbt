// renderers/common/nodes/NodeSampledTexture.js: `NodeSampledTexture`,
// `NodeSampledCubeTexture`, `NodeSampledTexture3D`.

///|
/// The `NodeSampledTexture` class payload.
pub(all) struct NodeSampledTexture {
  parent_ : SampledTexture
  mut texture_node : Node?
  mut group_node : Node?
  /// `null` by default.
  mut access : String?
}

///|
pub impl BindingClass for NodeSampledTexture with fn class_name(_) {
  "NodeSampledTexture"
}

///|
pub impl BindingClass for NodeSampledTexture with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeSampledTexture with fn group_node(self) {
  self.group_node
}

///|
pub impl BindingClass for NodeSampledTexture with fn copy_class(self) {
  self.copy_payload()
}

///|
pub impl BindingClass for NodeSampledTexture with fn update(self, binding) {
  _node_sampler_update(self.texture_node, binding, self.parent_)
}

///|
pub impl BindingClass for NodeSampledTexture with fn clone(self, binding) {
  _node_sampler_clone(self.texture_node, binding, self.parent_)
}

///|
/// `new this.constructor()` (which takes a `SampledTexture` id) then `Object.assign`.
pub fn NodeSampledTexture::copy_payload(
  self : NodeSampledTexture,
) -> NodeSampledTexture {
  {
    parent_: self.parent_.copy_payload(),
    texture_node: self.texture_node,
    group_node: self.group_node,
    access: self.access,
  }
}

///|
/// The payload of `super( name, textureNode, groupNode, access )` for subclasses.
pub fn NodeSampledTexture::construct(
  texture_node : Node?,
  group_node : Node?,
  access : String?,
) -> NodeSampledTexture {
  let texture = match texture_node {
    Some(_) => _node_sampler_texture_value(texture_node)
    None => None
  }
  {
    parent_: SampledTexture::construct(texture),
    texture_node,
    group_node,
    access,
  }
}

///|
/// `new NodeSampledTexture( name, textureNode, groupNode, access = null )`.
pub fn NodeSampledTexture::new(
  name : String,
  texture_node : Node?,
  group_node : Node?,
  access? : String,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = NodeSampledTexture::construct(
    texture_node, group_node, access,
  )
  binding
}

///|
pub fn NodeSampledTexture::of(binding : Binding) -> NodeSampledTexture? {
  match binding.class_payload("NodeSampledTexture") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `sampledTexture.store = value` (set by the node builders).
pub fn Binding::set_store(self : Binding, value : Bool) -> Unit {
  _sampled_texture(self).store = value
}

///|
/// `sampledTexture.mipLevel = value` (set by the node builders).
pub fn Binding::set_mip_level(self : Binding, value : Int32) -> Unit {
  _sampled_texture(self).mip_level = value
}

///|
/// The `NodeSampledCubeTexture` class payload.
pub(all) struct NodeSampledCubeTexture {
  parent_ : NodeSampledTexture
}

///|
pub impl BindingClass for NodeSampledCubeTexture with fn class_name(_) {
  "NodeSampledCubeTexture"
}

///|
pub impl BindingClass for NodeSampledCubeTexture with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeSampledCubeTexture with fn has_flag(self, flag) {
  flag == "isSampledCubeTexture" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for NodeSampledCubeTexture with fn copy_class(self) {
  NodeSampledCubeTexture::{ parent_: self.parent_.copy_payload(), }
}

///|
/// `new NodeSampledCubeTexture( name, textureNode, groupNode, access = null )`.
pub fn NodeSampledCubeTexture::new(
  name : String,
  texture_node : Node?,
  group_node : Node?,
  access? : String,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = NodeSampledCubeTexture::{
    parent_: NodeSampledTexture::construct(texture_node, group_node, access),
  }
  binding
}

///|
/// The `NodeSampledTexture3D` class payload.
pub(all) struct NodeSampledTexture3D {
  parent_ : NodeSampledTexture
}

///|
pub impl BindingClass for NodeSampledTexture3D with fn class_name(_) {
  "NodeSampledTexture3D"
}

///|
pub impl BindingClass for NodeSampledTexture3D with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeSampledTexture3D with fn has_flag(self, flag) {
  flag == "isSampledTexture3D" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for NodeSampledTexture3D with fn copy_class(self) {
  NodeSampledTexture3D::{ parent_: self.parent_.copy_payload(), }
}

///|
/// `new NodeSampledTexture3D( name, textureNode, groupNode, access = null )`.
pub fn NodeSampledTexture3D::new(
  name : String,
  texture_node : Node?,
  group_node : Node?,
  access? : String,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = NodeSampledTexture3D::{
    parent_: NodeSampledTexture::construct(texture_node, group_node, access),
  }
  binding
}
