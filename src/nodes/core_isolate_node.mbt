// nodes/core/IsolateNode.js

///|
/// Builds its node with its own node cache (inheriting the parent cache if `parent`).
pub(all) struct IsolateNode {
  mut node : Node
  mut parent : Bool
}

///|
pub impl NodeClass for IsolateNode with fn class_name(_) {
  "IsolateNode"
}

///|
pub impl NodeClass for IsolateNode with fn has_flag(_, flag) {
  flag == "isIsolateNode"
}

///|
pub impl NodeClass for IsolateNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for IsolateNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for IsolateNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  let previous_cache = builder.get_cache()
  let cache = builder.get_cache_from_node(node, parent=self.parent)
  builder.set_cache(cache)
  let node_type = self.node.get_node_type(builder)
  builder.set_cache(previous_cache)
  node_type
}

///|
pub impl NodeClass for IsolateNode with fn build(self, node, builder, output) {
  node._setup_inspector(builder)
  let previous_cache = builder.get_cache()
  let cache = builder.get_cache_from_node(node, parent=self.parent)
  builder.set_cache(cache)
  let data = self.node.build_output(builder, output)
  builder.set_cache(previous_cache)
  data
}

///|
pub fn IsolateNode::construct(
  _node : Node,
  input_node : Node,
  parent : Bool,
) -> IsolateNode {
  { node: input_node, parent, }
}

///|
/// `new IsolateNode( node, parent = true )`.
pub fn IsolateNode::new(node : Node, parent~ : Bool = true) -> Node {
  let this = Node::alloc()
  this.set_class(IsolateNode::construct(this, node, parent))
}

///|
pub fn IsolateNode::of(node : Node) -> IsolateNode? {
  match node.class_payload("IsolateNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn isolate_node_payload(node : Node, method_name : String) -> IsolateNode {
  match IsolateNode::of(node) {
    Some(i) => i
    None => abort("\{method_name}: \{node.type_()} is not an IsolateNode")
  }
}

///|
/// `setParent( parent )`, chained.
pub fn Node::set_parent(self : Node, parent : Bool) -> Node {
  isolate_node_payload(self, "setParent").parent = parent
  self
}

///|
/// `getParent()`.
pub fn Node::get_parent(self : Node) -> Bool {
  isolate_node_payload(self, "getParent").parent
}

///|
/// `isolate( node )`.
pub fn isolate(node : &IntoTsl) -> Node {
  IsolateNode::new(node_object(node.to_tsl()))
}

///|
/// `cache( node, parent = true )`, deprecated: `isolate`.
pub fn cache(node : &IntoTsl, parent~ : Bool = true) -> Node {
  @core.warn("TSL: \"cache()\" has been deprecated. Use \"isolate()\" instead.")
  isolate(node).set_parent(parent)
}

///|
pub fn Node::isolate(self : Node) -> Node {
  isolate(self)
}

///|
pub fn Node::cache(self : Node, parent~ : Bool = true) -> Node {
  cache(self, parent~)
}
