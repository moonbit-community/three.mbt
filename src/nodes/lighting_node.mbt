// nodes/lighting/LightingNode.js: the base of light and environment nodes.

///|
pub(all) struct LightingNode {}

///|
pub impl NodeClass for LightingNode with fn class_name(_) {
  "LightingNode"
}

///|
pub impl NodeClass for LightingNode with fn has_flag(_, flag) {
  flag == "isLightingNode"
}

///|
pub impl NodeClass for LightingNode with fn is_cacheable(_, _, _) {
  false
}

///|
/// The constructor body: `super( 'vec3' )` has run in `Node::alloc`.
pub fn LightingNode::construct(_node : Node) -> LightingNode {
  LightingNode::{ }
}

///|
/// `new LightingNode()`.
pub fn LightingNode::new() -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(LightingNode::construct(node))
}

///|
pub fn LightingNode::of(node : Node) -> LightingNode? {
  match node.class_payload("LightingNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
