// nodes/core/InspectorNode.js

///|
/// Hands its node to the renderer's inspector once per frame (`toInspector`).
pub(all) struct InspectorNode {
  mut node : Node
  /// Modifies the node the inspector presents.
  mut callback : ((Node) -> Node)?
}

///|
pub impl NodeClass for InspectorNode with fn class_name(_) {
  "InspectorNode"
}

///|
pub impl NodeClass for InspectorNode with fn has_flag(_, flag) {
  flag == "isInspectorNode"
}

///|
pub impl NodeClass for InspectorNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for InspectorNode with fn update(_, node, frame) {
  let renderer = frame.renderer.unwrap()
  if !renderer.backend_is_webgpu() && !renderer.inspector().is_base() {
    @core.warn_once("TSL: \".toInspector()\" is only available with WebGPU.")
  }
  renderer.inspector().inspect(node)
  None
}

///|
pub impl NodeClass for InspectorNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.node.get_node_type(builder)
}

///|
pub fn InspectorNode::construct(
  node : Node,
  input_node : Node,
  name : String,
  callback : ((Node) -> Node)?,
) -> InspectorNode {
  let inspector = InspectorNode::{ node: input_node, callback: None, }
  node.name = Some(name)
  inspector.callback = callback
  node.update_type = NodeUpdateType::frame()
  inspector
}

///|
/// `new InspectorNode( node, name = '', callback = null )`.
pub fn InspectorNode::new(
  node : Node,
  name~ : String = "",
  callback? : (Node) -> Node,
) -> Node {
  let this = Node::alloc()
  this.set_class(InspectorNode::construct(this, node, name, callback))
}

///|
pub fn InspectorNode::of(node : Node) -> InspectorNode? {
  match node.class_payload("InspectorNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `getName()`: the inspector name, else the node's name.
pub fn InspectorNode::get_name(node : Node) -> String? {
  match node.name {
    Some(n) if n != "" => Some(n)
    _ => InspectorNode::of(node).unwrap().node.name
  }
}

///|
/// `inspect( node, name = '', callback = null )`: attaches an `InspectorNode`. The
/// trailing `_` keeps it from shadowing the prelude `inspect` in tests.
pub fn inspect_(
  node : &IntoTsl,
  name~ : String = "",
  callback? : (Node) -> Node,
) -> Node {
  let node = node_object(node.to_tsl())
  node._inspector_node = Some(InspectorNode::new(node, name~, callback?))
  node
}

///|
/// `toInspector( name, callback )`.
pub fn Node::to_inspector(
  self : Node,
  name~ : String = "",
  callback? : (Node) -> Node,
) -> Node {
  inspect_(self, name~, callback?)
}
