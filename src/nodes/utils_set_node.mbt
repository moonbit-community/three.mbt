// nodes/utils/SetNode.js

///|
pub(all) struct SetNode {
  mut source_node : Node
  /// The swizzle to replace, sorted in `xyzw` order.
  mut components : String
  mut target_node : Node
}

///|
pub impl NodeClass for SetNode with fn class_name(_) {
  "SetNode"
}

///|
pub impl NodeClass for SetNode with fn children(self, _, out) {
  push_child(out, "sourceNode", Some(self.source_node))
  push_child(out, "targetNode", Some(self.target_node))
}

///|
pub impl NodeClass for SetNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for SetNode with fn generate_node_type(self, _, builder, _) {
  self.source_node.get_node_type(builder)
}

///|
pub impl NodeClass for SetNode with fn generate(self, node, builder, _) {
  let source_node = self.source_node
  let components = self.components
  let target_node = self.target_node
  let source_type = node.get_node_type(builder)
  let component_type = builder.get_component_type(
    target_node.get_node_type(builder),
  )
  let target_type = builder.get_type_from_length(
    components.length(),
    component_type?,
  )
  let target_snippet = target_node.build(builder, output=target_type)
  let source_snippet = source_node.build(builder, output?=source_type)
  let length = builder.get_type_length(source_type)
  let snippet_values = []
  let first = if components.length() > 0 {
    Some(components.unsafe_substring(start=0, end=1))
  } else {
    None
  }
  let mut i = 0
  while i < length {
    let component = if i < vector_components.length() {
      Some(vector_components[i])
    } else {
      None
    }
    if component == first {
      snippet_values.push(target_snippet)
      i += components.length() - 1
    } else {
      snippet_values.push(
        source_snippet + "." + component.unwrap_or("undefined"),
      )
    }
    i += 1
  }
  Some(
    "\{builder.get_type(source_type.unwrap())}( \{snippet_values.join(", ")} )",
  )
}

///|
pub fn SetNode::construct(
  _node : Node,
  source_node : Node,
  components : String,
  target_node : Node,
) -> SetNode {
  { source_node, components, target_node, }
}

///|
/// `new SetNode( sourceNode, components, targetNode )`.
pub fn SetNode::new(
  source_node : Node,
  components : String,
  target_node : Node,
) -> Node {
  let n = Node::alloc()
  n.set_class(SetNode::construct(n, source_node, components, target_node))
}

///|
pub fn SetNode::of(node : Node) -> SetNode? {
  match node.class_payload("SetNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
