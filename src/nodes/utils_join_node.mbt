// nodes/utils/JoinNode.js

///|
pub(all) struct JoinNode {
  mut nodes : Array[Node]
}

///|
pub impl NodeClass for JoinNode with fn class_name(_) {
  "JoinNode"
}

///|
pub impl NodeClass for JoinNode with fn children(self, _, out) {
  for i, n in self.nodes {
    out.push({ property: "nodes", index: Some(Index(i)), child_node: n, })
  }
}

///|
pub impl NodeClass for JoinNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  match node.node_type {
    Some(t) => builder.get_vector_type(Some(t))
    None => {
      let mut count = 0
      for cur in self.nodes {
        count += builder.get_type_length(cur.get_node_type(builder))
      }
      Some(builder.get_type_from_length(count))
    }
  }
}

///|
pub impl NodeClass for JoinNode with fn generate(self, node, builder, output) {
  let type_ = node.get_node_type(builder)
  let max_length = builder.get_type_length(type_)
  let primitive_type = builder.get_component_type(type_)
  let snippet_values = []
  let mut length = 0
  let type_name = type_.unwrap_or("null")
  for input in self.nodes {
    if length >= max_length {
      @core.error(
        "TSL: Length of parameters exceeds maximum length of function '\{type_name}()' type.",
      )
      break
    }
    let mut input_type = input.get_node_type(builder)
    let mut input_type_length = builder.get_type_length(input_type)
    if length + input_type_length > max_length {
      @core.error(
        "TSL: Length of '\{type_name}()' data exceeds maximum length of output type.",
      )
      input_type_length = max_length - length
      input_type = Some(builder.get_type_from_length(input_type_length))
    }
    length += input_type_length
    let mut input_snippet = input.build(builder, output?=input_type)
    let input_primitive_type = builder.get_component_type(input_type)
    if input_primitive_type != primitive_type {
      let target_type = builder.get_type_from_length(
        input_type_length,
        component_type?=primitive_type,
      )
      input_snippet = builder.format(
        input_snippet,
        input_type,
        Some(target_type),
      )
    }
    snippet_values.push(input_snippet)
  }
  let snippet = "\{builder.get_type(type_.unwrap())}( \{snippet_values.join(", ")} )"
  Some(builder.format(snippet, type_, output))
}

///|
pub fn JoinNode::construct(_node : Node, nodes : Array[Node]) -> JoinNode {
  { nodes, }
}

///|
/// `new JoinNode( nodes = [], nodeType = null )`.
pub fn JoinNode::new(nodes~ : Array[Node] = [], node_type? : String) -> Node {
  let n = Node::alloc(node_type?)
  n.set_class(JoinNode::construct(n, nodes))
}

///|
pub fn JoinNode::of(node : Node) -> JoinNode? {
  match node.class_payload("JoinNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
