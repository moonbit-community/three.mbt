// nodes/core/IndexNode.js

///|
/// A built-in index: vertex, instance, draw, subgroup or invocation.
pub(all) struct IndexNode {
  mut scope : String
}

///|
pub impl NodeClass for IndexNode with fn class_name(_) {
  "IndexNode"
}

///|
pub impl NodeClass for IndexNode with fn has_flag(_, flag) {
  flag == "isIndexNode"
}

///|
pub impl NodeClass for IndexNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for IndexNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for IndexNode with fn generate(self, node, builder, _) {
  let node_type = node.get_node_type(builder)
  let scope = self.scope
  let property_name = if scope == IndexNode::vertex() {
    Some(builder.get_vertex_index())
  } else if scope == IndexNode::instance() {
    Some(builder.get_instance_index())
  } else if scope == IndexNode::draw() {
    builder.get_draw_index()
  } else if scope == IndexNode::invocation_local() {
    Some(builder.get_invocation_local_index())
  } else if scope == IndexNode::invocation_subgroup() {
    Some(builder.get_invocation_subgroup_index())
  } else if scope == IndexNode::subgroup() {
    Some(builder.get_subgroup_index())
  } else {
    abort("THREE.IndexNode: Unknown scope: " + scope)
  }
  if builder.shader_stage == Some("vertex") ||
    builder.shader_stage == Some("compute") {
    property_name
  } else {
    let node_varying = varying(node)
    Some(node_varying.build(builder, output?=node_type))
  }
}

///|
/// `IndexNode.VERTEX`.
pub fn IndexNode::vertex() -> String {
  "vertex"
}

///|
/// `IndexNode.INSTANCE`.
pub fn IndexNode::instance() -> String {
  "instance"
}

///|
/// `IndexNode.SUBGROUP`.
pub fn IndexNode::subgroup() -> String {
  "subgroup"
}

///|
/// `IndexNode.INVOCATION_LOCAL`.
pub fn IndexNode::invocation_local() -> String {
  "invocationLocal"
}

///|
/// `IndexNode.INVOCATION_SUBGROUP`.
pub fn IndexNode::invocation_subgroup() -> String {
  "invocationSubgroup"
}

///|
/// `IndexNode.DRAW`.
pub fn IndexNode::draw() -> String {
  "draw"
}

///|
pub fn IndexNode::construct(_node : Node, scope : String) -> IndexNode {
  { scope, }
}

///|
/// `new IndexNode( scope )`.
pub fn IndexNode::new(scope : String) -> Node {
  let node = Node::alloc(node_type="uint")
  node.set_class(IndexNode::construct(node, scope))
}

///|
pub fn IndexNode::of(node : Node) -> IndexNode? {
  match node.class_payload("IndexNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub let vertex_index : Node = module_nodes(
  "nodes/core/IndexNode.js:vertexIndex",
  fn() { IndexNode::new(IndexNode::vertex()) },
)

///|
pub let instance_index : Node = module_nodes(
  "nodes/core/IndexNode.js:instanceIndex",
  fn() { IndexNode::new(IndexNode::instance()) },
)

///|
pub let subgroup_index : Node = module_nodes(
  "nodes/core/IndexNode.js:subgroupIndex",
  fn() { IndexNode::new(IndexNode::subgroup()) },
)

///|
pub let invocation_subgroup_index : Node = module_nodes(
  "nodes/core/IndexNode.js:invocationSubgroupIndex",
  fn() { IndexNode::new(IndexNode::invocation_subgroup()) },
)

///|
pub let invocation_local_index : Node = module_nodes(
  "nodes/core/IndexNode.js:invocationLocalIndex",
  fn() { IndexNode::new(IndexNode::invocation_local()) },
)

///|
pub let draw_index : Node = module_nodes("nodes/core/IndexNode.js:drawIndex", fn() {
  IndexNode::new(IndexNode::draw())
})
