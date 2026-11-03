// nodes/utils/SplitNode.js

///|
let _split_node_string_vector_components : String = vector_components.join("")

///|
pub(all) struct SplitNode {
  mut node : Node
  /// The swizzle, `'x'` .. `'wzyx'`.
  mut components : String
}

///|
pub impl NodeClass for SplitNode with fn class_name(_) {
  "SplitNode"
}

///|
pub impl NodeClass for SplitNode with fn has_flag(_, flag) {
  flag == "isSplitNode"
}

///|
pub impl NodeClass for SplitNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for SplitNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for SplitNode with fn get_scope(self, _) {
  self.node.get_scope()
}

///|
pub impl NodeClass for SplitNode with fn generate_node_type(self, _, builder, _) {
  Some(
    builder.get_type_from_length(
      self.components.length(),
      component_type?=self.get_component_type(builder),
    ),
  )
}

///|
pub impl NodeClass for SplitNode with fn generate(self, node, builder, output) {
  let source = self.node
  let node_type_length = builder.get_type_length(source.get_node_type(builder))
  let snippet = if node_type_length > 1 {
    let mut type_ : String? = None
    let components_length = self.get_vector_length()
    if components_length >= node_type_length {
      // needed expand the input node
      type_ = Some(
        builder.get_type_from_length(
          self.get_vector_length(),
          component_type?=self.get_component_type(builder),
        ),
      )
    }
    let node_snippet = source.build(builder, output?=type_)
    let n = self.components.length()
    if n == node_type_length &&
      n <= _split_node_string_vector_components.length() &&
      self.components ==
      _split_node_string_vector_components.unsafe_substring(start=0, end=n) {
      // unnecessary swizzle
      builder.format(node_snippet, type_, output)
    } else {
      builder.format(
        "\{node_snippet}.\{self.components}",
        node.get_node_type(builder),
        output,
      )
    }
  } else {
    // ignore .components if .node returns float/integer
    source.build(builder, output?)
  }
  Some(snippet)
}

///|
pub impl NodeClass for SplitNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("components", @core.JsValue::of(self.components))
}

///|
pub impl NodeClass for SplitNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self.components = data.get("components").cast()
}

///|
/// `getVectorLength()`: the vector length the components need.
pub fn SplitNode::get_vector_length(self : SplitNode) -> Int32 {
  let mut vector_length = self.components.length()
  for c in self.components {
    let index = match vector_components.search(c.to_string()) {
      Some(i) => i
      None => -1
    }
    if index + 1 > vector_length {
      vector_length = index + 1
    }
  }
  vector_length
}

///|
/// `getComponentType( builder )`.
pub fn SplitNode::get_component_type(
  self : SplitNode,
  builder : NodeBuilder,
) -> String? {
  builder.get_component_type(self.node.get_node_type(builder))
}

///|
pub fn SplitNode::construct(
  _node : Node,
  node : Node,
  components : String,
) -> SplitNode {
  { node, components, }
}

///|
/// `new SplitNode( node, components = 'x' )`.
pub fn SplitNode::new(node : Node, components~ : String = "x") -> Node {
  let n = Node::alloc()
  n.set_class(SplitNode::construct(n, node, components))
}

///|
pub fn SplitNode::of(node : Node) -> SplitNode? {
  match node.class_payload("SplitNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
