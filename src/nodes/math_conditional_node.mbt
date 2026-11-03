// nodes/math/ConditionalNode.js: `select( cond, a, b )` and the if/else blocks of
// `If`/`Switch` (StackNode builds it).

///|
/// `condNode ? ifNode : elseNode`, or an if/else block.
pub(all) struct ConditionalNode {
  mut cond_node : Node
  mut if_node : Node
  mut else_node : Node?
}

///|
pub impl NodeClass for ConditionalNode with fn class_name(_) {
  "ConditionalNode"
}

///|
pub impl NodeClass for ConditionalNode with fn children(self, _, out) {
  push_child(out, "condNode", Some(self.cond_node))
  push_child(out, "ifNode", Some(self.if_node))
  push_child(out, "elseNode", self.else_node)
}

///|
pub impl NodeClass for ConditionalNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for ConditionalNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ConditionalNode with fn generate_node_type(
  _,
  node,
  builder,
  _,
) {
  let properties = builder.get_node_properties(node)
  let if_node = match properties.get_node("ifNode") {
    Some(n) => n
    None => {
      // fallback setup
      builder.flow_build_stage(node, "setup") |> ignore
      return node.get_node_type(builder)
    }
  }
  let cond_node = properties.get_node("condNode").unwrap()
  let else_node = properties.get_node("elseNode")
  let mut type_ = if_node.get_node_type(builder)
  if else_node is Some(else_node) {
    let else_type = else_node.get_node_type(builder)
    if builder.get_type_length(else_type) > builder.get_type_length(type_) {
      type_ = else_type
    }
  }
  let cond_length = builder.get_type_length(cond_node.get_node_type(builder))
  if cond_length > 1 &&
    !builder.is_reference(type_) &&
    (
      builder.get_type_length(type_) == 1 ||
      builder.is_vector(builder.get_vector_type(type_))
    ) {
    let length = operator_node_max_int(
      cond_length,
      builder.get_type_length(type_),
    )
    type_ = Some(
      builder.get_type_from_length(
        length,
        component_type=builder.get_component_type(type_).unwrap_or(""),
      ),
    )
  }
  type_
}

///|
pub impl NodeClass for ConditionalNode with fn setup(self, node, builder) {
  let properties = builder.get_node_properties(node)
  properties.set_node("condNode", self.cond_node)
  properties.set_node("ifNode", self.if_node)
  properties.set_node_or_null("elseNode", self.else_node)
  None
}

///|
/// `'return ' + snippet + ';'` of a branch without an output, commented out (with a
/// warning) outside a layout function.
fn conditional_node_return(snippet : String, function_node : Node?) -> String {
  let snippet = "return " + snippet + ";"
  if function_node is None {
    @core.warn(
      "TSL: Return statement used in an inline 'Fn()'. Define a layout struct to allow return values.",
    )
    "// " + snippet
  } else {
    snippet
  }
}

///|
pub impl NodeClass for ConditionalNode with fn generate(
  _,
  node,
  builder,
  output,
) {
  let type_ = node.get_node_type(builder)
  let node_data = builder.get_data_from_node(node)
  if node_data.property_name is Some(property_name) {
    return Some(builder.format(property_name, type_, output))
  }
  let properties = builder.get_node_properties(node)
  let cond_node = properties.get_node("condNode").unwrap()
  let if_node = properties.get_node("ifNode").unwrap()
  let else_node = properties.get_node("elseNode")
  let function_node = builder.current_function_node
  let needs_output = output != Some("void")
  let node_property = if needs_output {
    property(operator_node_str(type_)).build(builder)
  } else {
    ""
  }
  node_data.property_name = Some(node_property)
  // A vector condition selects per-component - see getVectorSelect().
  let cond_type = cond_node.get_node_type(builder)
  let cond_length = builder.get_type_length(cond_type)
  if cond_length > 1 {
    let vector_type = builder.get_vector_type(type_)
    if builder.is_reference(type_) || !builder.is_vector(vector_type) {
      abort(
        "TSL: select() with a vector condition (\"\{operator_node_str(cond_type)}\") requires scalar or vector values, received \"\{operator_node_str(type_)}\".",
      )
    }
    // No "else": unselected lanes fall back to the type's zero value.
    let else_snippet = match else_node {
      Some(e) => e.build(builder, output?=type_)
      None => builder.generate_const(operator_node_str(type_))
    }
    let bool_type = builder.change_component_type(
      operator_node_str(type_),
      "bool",
    )
    let cond_snippet = cond_node.build(builder, output=bool_type)
    let if_snippet = if_node.build(builder, output?=type_)
    let math_snippet = builder.get_vector_select(
      cond_snippet,
      if_snippet,
      else_snippet,
      type_?,
    )
    if !needs_output {
      return Some("")
    }
    builder.add_flow_code(
      "\n\{builder.tab}\{node_property} = \{operator_node_str(math_snippet)};\n\n",
    )
    |> ignore
    return Some(builder.format(node_property, type_, output))
  }
  let node_snippet = cond_node.build(builder, output="bool")
  let is_uniform_flow = conditional_node_truthy(
    builder.context.get("uniformFlow"),
  )
  if is_uniform_flow && else_node is Some(else_node) {
    let if_snippet = if_node.build(builder, output?=type_)
    let else_snippet = else_node.build(builder, output?=type_)
    let math_snippet = builder.get_ternary(
      node_snippet, if_snippet, else_snippet,
    )
    // TODO: If node property already exists return something else
    return Some(builder.format(operator_node_str(math_snippet), type_, output))
  }
  builder
  .add_flow_code("\n\{builder.tab}if ( \{node_snippet} ) {\n\n")
  .add_flow_tab()
  |> ignore
  // An immutable condition, i.e. a constant, is the guard of the blocks: blocks of the
  // same parent and guard run together.
  let cond_data = builder.get_data_from_node(cond_node)
  let guard_ = if cond_data.property_name == Some(node_snippet) &&
    cond_data.assign != Some(true) {
    Some(node_snippet)
  } else {
    None
  }
  let flow_block = builder.flow_block
  builder.flow_block = Some({ parent: flow_block, guard_, })
  let mut if_snippet = if_node.build(builder, output?=type_)
  builder.flow_block = flow_block
  if if_snippet != "" {
    if needs_output {
      if_snippet = node_property + " = " + if_snippet + ";"
    } else {
      if_snippet = conditional_node_return(if_snippet, function_node)
    }
  }
  builder
  .remove_flow_tab()
  .add_flow_code(builder.tab + "\t" + if_snippet + "\n\n" + builder.tab + "}")
  |> ignore
  match else_node {
    Some(else_node) => {
      builder.add_flow_code(" else {\n\n").add_flow_tab() |> ignore
      builder.flow_block = Some({
        parent: flow_block,
        guard_: guard_.map(fn(g) { "!" + g }),
      })
      let mut else_snippet = else_node.build(builder, output?=type_)
      builder.flow_block = flow_block
      if else_snippet != "" {
        if needs_output {
          else_snippet = node_property + " = " + else_snippet + ";"
        } else {
          else_snippet = conditional_node_return(else_snippet, function_node)
        }
      }
      builder
      .remove_flow_tab()
      .add_flow_code(
        builder.tab + "\t" + else_snippet + "\n\n" + builder.tab + "}\n\n",
      )
      |> ignore
    }
    None => builder.add_flow_code("\n\n") |> ignore
  }
  Some(builder.format(node_property, type_, output))
}

///|
/// JS truthiness of a context value.
fn conditional_node_truthy(value : ContextValue) -> Bool {
  match value {
    Undefined | Null => false
    Bool(b) => b
    Number(n) => n != 0.0 && n == n
    String(s) => s != ""
    _ => true
  }
}

///|
pub fn ConditionalNode::construct(
  _node : Node,
  cond_node : Node,
  if_node : Node,
  else_node : Node?,
) -> ConditionalNode {
  { cond_node, if_node, else_node, }
}

///|
/// `new ConditionalNode( condNode, ifNode, elseNode = null )`.
pub fn ConditionalNode::new(
  cond_node : Node,
  if_node : Node,
  else_node? : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(
    ConditionalNode::construct(node, cond_node, if_node, else_node),
  )
}

///|
pub fn ConditionalNode::of(node : Node) -> ConditionalNode? {
  match node.class_payload("ConditionalNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `nodeProxy( ConditionalNode ).setParameterLength( 2, 3 )`.
fn conditional_node_select(p : Array[TslValue]) -> Node {
  let p = tsl_verify_params("ConditionalNode", p, 2, 3)
  let nodes = p.map(tsl_proxy_arg)
  ConditionalNode::new(
    operator_node_required(nodes[0]),
    operator_node_required(nodes[1]),
    else_node?=nodes.get(2).unwrap_or(None),
  )
}

///|
/// `select( condNode, ifNode, elseNode = null )`: `condNode ? ifNode : elseNode`.
pub fn select(
  cond_node : &IntoTsl,
  if_node : &IntoTsl,
  else_node? : &IntoTsl,
) -> Node {
  match else_node {
    Some(e) =>
      conditional_node_select([cond_node.to_tsl(), if_node.to_tsl(), e.to_tsl()])
    None => conditional_node_select([cond_node.to_tsl(), if_node.to_tsl()])
  }
}

///|
/// `cond.select( ifNode, elseNode )`.
pub fn Node::select(
  self : Node,
  if_node : &IntoTsl,
  else_node? : &IntoTsl,
) -> Node {
  match else_node {
    Some(e) =>
      self.chain(conditional_node_select, [if_node.to_tsl(), e.to_tsl()])
    None => self.chain(conditional_node_select, [if_node.to_tsl()])
  }
}

///|
pub fn Node::select_assign(
  self : Node,
  if_node : &IntoTsl,
  else_node? : &IntoTsl,
) -> Unit {
  match else_node {
    Some(e) =>
      self.chain_assign(conditional_node_select, [if_node.to_tsl(), e.to_tsl()])
    None => self.chain_assign(conditional_node_select, [if_node.to_tsl()])
  }
}
