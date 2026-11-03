// nodes/core/SubBuildNode.js

///|
/// Builds its node inside a named sub-build layer (`'VERTEX'` for varyings).
pub(all) struct SubBuildNode {
  mut node : Node
}

///|
pub impl NodeClass for SubBuildNode with fn class_name(_) {
  "SubBuildNode"
}

///|
pub impl NodeClass for SubBuildNode with fn type_name(_) {
  "SubBuild"
}

///|
pub impl NodeClass for SubBuildNode with fn has_flag(_, flag) {
  flag == "isSubBuildNode"
}

///|
pub impl NodeClass for SubBuildNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for SubBuildNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for SubBuildNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  if node.node_type is Some(t) {
    return Some(t)
  }
  builder.add_sub_build(node.name.unwrap_or("null"))
  let node_type = self.node.get_node_type(builder)
  builder.remove_sub_build() |> ignore
  node_type
}

///|
pub impl NodeClass for SubBuildNode with fn build(self, node, builder, output) {
  node._setup_inspector(builder)
  builder.add_sub_build(node.name.unwrap_or("null"))
  let data = self.node.build_output(builder, output)
  builder.remove_sub_build() |> ignore
  data
}

///|
pub fn SubBuildNode::construct(
  node : Node,
  input_node : Node,
  name : String,
) -> SubBuildNode {
  node.name = Some(name)
  { node: input_node, }
}

///|
/// `new SubBuildNode( node, name, nodeType = null )`.
pub fn SubBuildNode::new(
  node : Node,
  name : String,
  node_type? : String,
) -> Node {
  let this = Node::alloc(node_type?)
  this.set_class(SubBuildNode::construct(this, node, name))
}

///|
pub fn SubBuildNode::of(node : Node) -> SubBuildNode? {
  match node.class_payload("SubBuildNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `subBuild( node, name, type = null )`.
pub fn sub_build(node : &IntoTsl, name : String, type_? : String) -> Node {
  SubBuildNode::new(node_object(node.to_tsl()), name, node_type?=type_)
}
