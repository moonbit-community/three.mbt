// renderers/common/nodes/NodeSampler.js

///|
/// The `NodeSampler` class payload.
pub(all) struct NodeSampler {
  parent_ : Sampler
  mut texture_node : Node?
  mut group_node : Node?
}

///|
pub impl BindingClass for NodeSampler with fn class_name(_) {
  "NodeSampler"
}

///|
pub impl BindingClass for NodeSampler with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for NodeSampler with fn group_node(self) {
  self.group_node
}

///|
pub impl BindingClass for NodeSampler with fn copy_class(self) {
  NodeSampler::{
    parent_: self.parent_.copy_payload(),
    texture_node: self.texture_node,
    group_node: self.group_node,
  }
}

///|
pub impl BindingClass for NodeSampler with fn update(self, binding) {
  _node_sampler_update(self.texture_node, binding, self.parent_)
}

///|
pub impl BindingClass for NodeSampler with fn clone(self, binding) {
  _node_sampler_clone(self.texture_node, binding, self.parent_)
}

///|
/// `textureNode.value` as a texture; `None` for `null` or another value.
fn _node_sampler_texture_value(texture_node : Node?) -> @core.Texture? {
  match texture_node {
    // TextureNode's `value` getter follows `referenceNode` (a sampled clone such as
    // `cubeTexture().sample( dir )` reads the texture later assigned to its base)
    Some(node) if node.has_flag("isTextureNode") =>
      TextureNode::get_value_opt(node)
    Some(node) =>
      match InputNode::get_value(node) {
        Texture(t) => Some(t)
        _ => None
      }
    None => abort("TypeError: Cannot read properties of null (reading 'value')")
  }
}

///|
/// The shared `update()` of `NodeSampler` and `NodeSampledTexture`.
fn _node_sampler_update(
  texture_node : Node?,
  binding : Binding,
  parent : &BindingClass,
) -> Bool {
  let value = _node_sampler_texture_value(texture_node)
  if !_sampler_same_texture(binding.texture(), value) {
    binding.set_texture(value)
    return true
  }
  parent.update(binding)
}

///|
/// The shared `clone()` of `NodeSampler` and `NodeSampledTexture`.
fn _node_sampler_clone(
  texture_node : Node?,
  binding : Binding,
  parent : &BindingClass,
) -> Binding {
  let clone = parent.clone(binding)
  // copy current node value to avoid stale references
  clone.set_texture(_node_sampler_texture_value(texture_node))
  clone
}

///|
/// `new NodeSampler( name, textureNode, groupNode )`.
pub fn NodeSampler::new(
  name : String,
  texture_node : Node?,
  group_node : Node?,
) -> Binding {
  let texture = match texture_node {
    Some(_) => _node_sampler_texture_value(texture_node)
    None => None
  }
  let binding = Binding::new(name~)
  binding.class_ = NodeSampler::{
    parent_: Sampler::construct(texture),
    texture_node,
    group_node,
  }
  binding
}

///|
pub fn NodeSampler::of(binding : Binding) -> NodeSampler? {
  match binding.class_payload("NodeSampler") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `binding.textureNode` of `NodeSampler` and `NodeSampledTexture`.
pub fn Binding::texture_node(self : Binding) -> Node? {
  match NodeSampler::of(self) {
    Some(s) => s.texture_node
    None =>
      match NodeSampledTexture::of(self) {
        Some(t) => t.texture_node
        None => None
      }
  }
}
