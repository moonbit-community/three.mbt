// nodes/accessors/PointUVNode.js

///|
pub(all) struct PointUVNode {}

///|
pub impl NodeClass for PointUVNode with fn class_name(_) {
  "PointUVNode"
}

///|
pub impl NodeClass for PointUVNode with fn has_flag(_, flag) {
  flag == "isPointUVNode"
}

///|
pub impl NodeClass for PointUVNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for PointUVNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for PointUVNode with fn generate(_, _, _, _) {
  Some("vec2( gl_PointCoord.x, 1.0 - gl_PointCoord.y )")
}

///|
/// `new PointUVNode()`.
pub fn PointUVNode::new() -> Node {
  let node = Node::alloc(node_type="vec2")
  node.set_class(PointUVNode::{ })
}

///|
pub fn PointUVNode::of(node : Node) -> PointUVNode? {
  match node.class_payload("PointUVNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `pointUV`.
pub let point_uv : Node = module_nodes(
  "nodes/accessors/PointUVNode.js:pointUV",
  fn() { PointUVNode::new() },
)
