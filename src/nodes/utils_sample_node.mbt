// nodes/utils/SampleNode.js: a node computed by a callback for a given uv, so passes
// can treat it like a texture.

///|
pub(all) struct SampleNode {
  /// `callback( uv )`.
  mut callback : (Node) -> Node
  mut uv_node : Node?
}

///|
pub impl NodeClass for SampleNode with fn class_name(_) {
  "SampleNode"
}

///|
pub impl NodeClass for SampleNode with fn has_flag(_, flag) {
  flag == "isSampleNode"
}

///|
pub impl NodeClass for SampleNode with fn children(self, _, out) {
  push_child(out, "uvNode", self.uv_node)
}

///|
pub impl NodeClass for SampleNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for SampleNode with fn setup(self, _, _) {
  Some(self.sample(uv()))
}

///|
/// `sample( uv )`: the callback's node for `uv`.
pub fn SampleNode::sample(self : SampleNode, uv_node : Node) -> Node {
  (self.callback)(uv_node)
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn SampleNode::construct(
  _node : Node,
  callback : (Node) -> Node,
  uv_node : Node?,
) -> SampleNode {
  { callback, uv_node, }
}

///|
/// `new SampleNode( callback, uvNode = null )`.
pub fn SampleNode::new(callback : (Node) -> Node, uv_node? : Node) -> Node {
  let node = Node::alloc()
  node.set_class(SampleNode::construct(node, callback, uv_node))
}

///|
pub fn SampleNode::of(node : Node) -> SampleNode? {
  match node.class_payload("SampleNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `sample( callback, uv = null )`.
pub fn sample(callback : (Node) -> Node, uv_node? : &IntoTsl) -> Node {
  let uv_node = match uv_node {
    Some(u) => tsl_proxy_arg(u.to_tsl())
    None => None
  }
  SampleNode::new(callback, uv_node?)
}
