// nodes/core/AssignNode.js. The chained `a.assign( b )` (`Node::assign`) is in
// tsl_core.mbt; `assign( a, b )` here is the node constructor.

///|
/// `targetNode = sourceNode`.
pub(all) struct AssignNode {
  mut target_node : Node
  mut source_node : Node
}

///|
pub impl NodeClass for AssignNode with fn class_name(_) {
  "AssignNode"
}

///|
pub impl NodeClass for AssignNode with fn has_flag(_, flag) {
  flag == "isAssignNode"
}

///|
pub impl NodeClass for AssignNode with fn children(self, _, out) {
  push_child(out, "targetNode", Some(self.target_node))
  push_child(out, "sourceNode", Some(self.source_node))
}

///|
pub impl NodeClass for AssignNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for AssignNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for AssignNode with fn generate_node_type(
  self,
  _,
  builder,
  output,
) {
  if output != Some("void") {
    self.target_node.get_node_type(builder)
  } else {
    Some("void")
  }
}

///|
pub impl NodeClass for AssignNode with fn setup(self, node, builder) {
  let target_node = self.target_node
  let source_node = self.source_node
  let scope = target_node.get_scope()
  let scope_data = builder.get_data_from_node(scope)
  scope_data.assign = Some(true)
  let properties = builder.get_node_properties(node)
  properties.set_node("sourceNode", source_node)
  properties.set_node(
    "targetNode",
    target_node.context(value=node_context([("assign", Bool(true))])),
  )
  None
}

///|
pub impl NodeClass for AssignNode with fn generate(_, node, builder, output) {
  let properties = builder.get_node_properties(node)
  let target_node = properties.get_node("targetNode").unwrap()
  let source_node = properties.get_node("sourceNode").unwrap()
  let needs_split_assign = AssignNode::needs_split_assign(node, builder)
  let target = target_node.build(builder)
  let target_type = target_node.get_node_type(builder)
  let source = source_node.build(builder, output?=target_type)
  let source_type = source_node.get_node_type(builder)
  let node_data = builder.get_data_from_node(node)
  let mut snippet : String? = None
  if node_data.property_name is Some(_) {
    if output != Some("void") {
      snippet = Some(target)
    }
  } else if needs_split_assign {
    let source_var = builder.get_var_from_node(
      node,
      None,
      target_type,
      None,
      false,
      false,
      "variable",
    )
    let source_property = builder.get_property_name(Var(source_var))
    builder.add_line_flow_code("\{source_property} = \{source}", node~)
    |> ignore
    let split_node = ContextNode::of(target_node).unwrap().node.unwrap()
    let split = SplitNode::of(split_node).unwrap()
    let split_target_node = split.node.context(
      value=node_context([("assign", Bool(true))]),
    )
    let target_root = split_target_node.build(builder)
    let components = split.components
    for i in 0..<components.length() {
      let component = components.unsafe_substring(start=i, end=i + 1)
      builder.add_line_flow_code(
        "\{target_root}.\{component} = \{source_property}[ \{i} ]",
        node~,
      )
      |> ignore
    }
    if output != Some("void") {
      snippet = Some(target)
    }
  } else {
    let s = "\{target} = \{source}"
    snippet = Some(s)
    if output == Some("void") || source_type == Some("void") {
      builder.add_line_flow_code(s, node~) |> ignore
      if output != Some("void") {
        snippet = Some(target)
      }
    }
  }
  node_data.property_name = Some(target)
  match snippet {
    Some(s) => Some(builder.format(s, target_type, output))
    // `format( undefined, type, 'void' )` returns the snippet: `void` is a reference.
    None => None
  }
}

///|
pub fn AssignNode::construct(
  _node : Node,
  target_node : Node,
  source_node : Node,
) -> AssignNode {
  { target_node, source_node, }
}

///|
/// `new AssignNode( targetNode, sourceNode )`.
pub fn AssignNode::new(target_node : Node, source_node : Node) -> Node {
  let this = Node::alloc()
  this.set_class(AssignNode::construct(this, target_node, source_node))
}

///|
pub fn AssignNode::of(node : Node) -> AssignNode? {
  match node.class_payload("AssignNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `needsSplitAssign( builder )`: a swizzle target the backend cannot assign.
pub fn AssignNode::needs_split_assign(
  node : Node,
  builder : NodeBuilder,
) -> Bool {
  let target_node = AssignNode::of(node).unwrap().target_node
  if builder.is_available("swizzleAssign") == false &&
    SplitNode::of(target_node) is Some(split) &&
    split.components.length() > 1 {
    let target_length = builder.get_type_length(
      split.node.get_node_type(builder),
    )
    let all = vector_components.join("")
    let prefix = all.unsafe_substring(
      start=0,
      end=assign_node_clamp(target_length, all.length()),
    )
    return prefix != split.components
  }
  false
}

///|
/// The end index `String.prototype.slice( 0, end )` uses.
fn assign_node_clamp(end : Int32, length : Int32) -> Int32 {
  if end < 0 {
    let e = length + end
    if e < 0 {
      0
    } else {
      e
    }
  } else if end > length {
    length
  } else {
    end
  }
}

///|
/// `assign( targetNode, sourceNode )`: the `AssignNode` (`nodeProxy`).
pub fn assign(target_node : &IntoTsl, source_node : &IntoTsl) -> Node {
  AssignNode::new(
    node_object(target_node.to_tsl()),
    node_object(source_node.to_tsl()),
  )
}
