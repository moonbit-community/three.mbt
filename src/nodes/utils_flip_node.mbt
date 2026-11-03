// nodes/utils/FlipNode.js

///|
pub(all) struct FlipNode {
  mut source_node : Node
  /// The components to flip, sorted in `xyzw` order.
  mut components : String
}

///|
pub impl NodeClass for FlipNode with fn class_name(_) {
  "FlipNode"
}

///|
pub impl NodeClass for FlipNode with fn children(self, _, out) {
  push_child(out, "sourceNode", Some(self.source_node))
}

///|
pub impl NodeClass for FlipNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for FlipNode with fn generate_node_type(self, _, builder, _) {
  self.source_node.get_node_type(builder)
}

///|
pub impl NodeClass for FlipNode with fn generate(self, node, builder, _) {
  let components = self.components
  let source_type = node.get_node_type(builder)
  let source_snippet = self.source_node.build(builder)
  let source_cache = builder.get_var_from_node(
    node,
    None,
    None,
    None,
    false,
    false,
    "variable",
  )
  let source_property = builder.get_property_name(Var(source_cache))
  builder.add_line_flow_code(source_property + " = " + source_snippet, node~)
  |> ignore
  let length = builder.get_type_length(source_type)
  let snippet_values = []
  let mut component_index = 0
  for i in 0..<length {
    let component = if i < vector_components.length() {
      vector_components[i]
    } else {
      "undefined"
    }
    let current = if component_index < components.length() {
      Some(
        components.unsafe_substring(
          start=component_index,
          end=component_index + 1,
        ),
      )
    } else {
      None
    }
    if Some(component) == current {
      snippet_values.push("1.0 - " + (source_property + "." + component))
      component_index += 1
    } else {
      snippet_values.push(source_property + "." + component)
    }
  }
  Some(
    "\{builder.get_type(source_type.unwrap())}( \{snippet_values.join(", ")} )",
  )
}

///|
pub fn FlipNode::construct(
  _node : Node,
  source_node : Node,
  components : String,
) -> FlipNode {
  { source_node, components, }
}

///|
/// `new FlipNode( sourceNode, components )`.
pub fn FlipNode::new(source_node : Node, components : String) -> Node {
  let n = Node::alloc()
  n.set_class(FlipNode::construct(n, source_node, components))
}

///|
pub fn FlipNode::of(node : Node) -> FlipNode? {
  match node.class_payload("FlipNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
