// nodes/core/StackNode.js

///|
/// `isAssignableExpression( builder, node )`: an assignable node never assigned.
fn stack_node_is_assignable_expression(
  builder : NodeBuilder,
  node : Node,
) -> Bool {
  if node.assignable != true {
    return false
  }
  let data = builder.get_data_from_node(node)
  data.force_declaration != Some(true) && data.assign != Some(true)
}

///|
/// A list of statements (the body of a function or a branch) and its output.
pub(all) struct StackNode {
  /// The node this payload belongs to (`this`).
  node : Node
  nodes : Array[Node]
  mut output_node : Node?
  mut parent : StackNode?
  mut _current_cond : Node?
  mut _expression_node : Node?
  mut _current_node : Node?
  /// `_nodeDataLibrary`: node id -> `delta` of the nodes added after it.
  _node_data_library : Map[Int32, Int32]
  /// `subBuild`, set on function output stacks by `ShaderCallNodeInternal`.
  mut sub_build : String?
}

///|
pub impl NodeClass for StackNode with fn class_name(_) {
  "StackNode"
}

///|
pub impl NodeClass for StackNode with fn has_flag(_, flag) {
  flag == "isStackNode"
}

///|
pub impl NodeClass for StackNode with fn children(self, _, out) {
  for i, n in self.nodes {
    out.push({ property: "nodes", index: Some(Index(i)), child_node: n, })
  }
  push_child(out, "outputNode", self.output_node)
  push_child(out, "parent", self.parent.map(fn(p) { p.node }))
}

///|
pub impl NodeClass for StackNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for StackNode with fn get_element_type(self, _, builder) {
  match self.output_node {
    Some(n) => n.get_element_type(builder)
    None => Some("void")
  }
}

///|
pub impl NodeClass for StackNode with fn generate_node_type(self, _, builder, _) {
  match self.output_node {
    Some(n) => n.get_node_type(builder)
    None => Some("void")
  }
}

///|
pub impl NodeClass for StackNode with fn get_member_type(self, _, builder, name) {
  match self.output_node {
    Some(n) => n.get_member_type(builder, name)
    None => "void"
  }
}

///|
pub impl NodeClass for StackNode with fn setup(_, node, builder) {
  let node_properties = builder.get_node_properties(node)
  let mut index = 0
  for child_node in node.get_children() {
    if stack_node_is_assignable_expression(builder, child_node) {
      continue
    }
    node_properties.set_node("node" + index.to_string(), child_node)
    index += 1
  }
  node_properties.get_node("outputNode")
}

///|
pub impl NodeClass for StackNode with fn build(self, node, builder, output) {
  node._setup_inspector(builder)
  let previous_stack = get_current_stack()
  let build_stage = builder.build_stage
  set_current_stack(Some(self))
  builder.set_active_stack(self)
  // `this.nodes.length` is read on each iteration: nodes added while building (before
  // or after the current node) are visited, as upstream's loop does.
  let mut i = 0
  while i < self.nodes.length() {
    let child = self.nodes[i]
    i += 1
    let previous_node = self._current_node
    self._current_node = Some(child)
    if stack_node_is_assignable_expression(builder, child) {
      continue
    }
    if build_stage == Some("setup") {
      child.build_output(builder, NoOutput) |> ignore
    } else if build_stage == Some("analyze") {
      child.build_output(builder, Parent(node)) |> ignore
    } else if build_stage == Some("generate") {
      let stages = builder.get_data_from_node(child, shader_stage="any").stages
      let parents = match (stages, builder.shader_stage) {
        (Some(stages), Some(stage)) => stages.get(stage)
        _ => None
      }
      if child.has_flag("isVarNode") &&
        parents is Some(parents) &&
        parents.length() == 1 &&
        parents[0] is Some(parent) &&
        parent.has_flag("isStackNode") {
        // skip var nodes that are only used in .toVarying()
        continue
      }
      child.build_output(builder, Type("void")) |> ignore
    }
    self._current_node = previous_node
  }
  let mut result : BuildResult = Null
  match self.output_node {
    Some(output_node) => {
      let build_result = output_node.build_output(builder, output)
      if builder.build_stage != Some("generate") ||
        output_node.get_node_type(builder) != Some("void") {
        result = build_result
      }
    }
    None => result = node.build_base(builder, output)
  }
  set_current_stack(previous_stack)
  builder.remove_active_stack(self)
  result
}

///|
/// The constructor body, building the payload of `node`.
pub fn StackNode::construct(node : Node, parent : StackNode?) -> StackNode {
  {
    node,
    nodes: [],
    output_node: None,
    parent,
    _current_cond: None,
    _expression_node: None,
    _current_node: None,
    _node_data_library: Map([]),
    sub_build: None,
  }
}

///|
/// `new StackNode( parent = null )`, returning the payload; `.node` is the node.
pub fn StackNode::create(parent? : StackNode) -> StackNode {
  let node = Node::alloc()
  let stack = StackNode::construct(node, parent)
  node.set_class(stack) |> ignore
  stack
}

///|
/// `new StackNode( parent = null )`.
pub fn StackNode::new(parent? : StackNode) -> Node {
  StackNode::create(parent?).node
}

///|
pub fn StackNode::of(node : Node) -> StackNode? {
  match node.class_payload("StackNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `stack.subBuild = value`.
pub fn StackNode::set_sub_build(self : StackNode, sub_build : String?) -> Unit {
  self.sub_build = sub_build
}

///|
/// `stack.subBuild` (`undefined` unless set).
pub fn StackNode::get_sub_build(self : StackNode) -> String? {
  self.sub_build
}

///|
/// `stack( parent = null )`.
pub fn stack(parent? : StackNode) -> Node {
  StackNode::new(parent?)
}

///|
/// `addToStack( node, index = -1 )`.
pub fn StackNode::add_to_stack(
  self : StackNode,
  node : Node,
  index~ : Int32 = -1,
) -> StackNode {
  let mut index = index
  if index == -1 {
    match self._current_node {
      Some(current_node) => {
        let delta = self._node_data_library.get(current_node.id).unwrap_or(0) +
          1
        self._node_data_library.set(current_node.id, delta)
        index = stack_node_index_of(self.nodes, current_node) + delta
      }
      None => index = self.nodes.length()
    }
  }
  stack_node_splice_insert(self.nodes, index, node)
  self
}

///|
/// `addToStackBefore( node, beforeNode = this._currentNode )`.
pub fn StackNode::add_to_stack_before(
  self : StackNode,
  node : Node,
  before_node? : Node,
) -> StackNode {
  let before_node = match before_node {
    Some(b) => Some(b)
    None => self._current_node
  }
  let index = match before_node {
    Some(b) => stack_node_index_of(self.nodes, b)
    None => 0
  }
  self.add_to_stack(node, index~)
}

///|
fn stack_node_index_of(nodes : Array[Node], node : Node) -> Int32 {
  for i, n in nodes {
    if physical_equal(n, node) {
      return i
    }
  }
  -1
}

///|
/// `array.splice( index, 0, node )`: a negative index counts from the end.
fn stack_node_splice_insert(
  nodes : Array[Node],
  index : Int32,
  node : Node,
) -> Unit {
  let length = nodes.length()
  let index = if index < 0 {
    let i = length + index
    if i < 0 {
      0
    } else {
      i
    }
  } else if index > length {
    length
  } else {
    index
  }
  nodes.insert(index, node)
}

///|
fn stack_node_unit_fn(body : () -> Unit) -> ShaderFn {
  {
    f: fn(_, _) {
      body()
      None
    },
  }
}

///|
fn stack_node_value_fn(body : () -> Node) -> ShaderFn {
  { f: fn(_, _) { Some(body()) }, }
}

///|
fn StackNode::if_shader(
  self : StackNode,
  bool_node : &IntoTsl,
  body : ShaderFn,
) -> StackNode {
  let method_node = shader_node(body)
  self._current_cond = Some(select(bool_node, method_node))
  self.add_to_stack(self._current_cond.unwrap())
}

///|
fn StackNode::else_if_shader(
  self : StackNode,
  bool_node : &IntoTsl,
  body : ShaderFn,
) -> StackNode {
  let method_node = shader_node(body)
  let if_node = select(bool_node, method_node)
  ConditionalNode::of(self._current_cond.unwrap()).unwrap().else_node = Some(
    if_node,
  )
  self._current_cond = Some(if_node)
  self
}

///|
fn StackNode::else_shader(self : StackNode, body : ShaderFn) -> Unit {
  ConditionalNode::of(self._current_cond.unwrap()).unwrap().else_node = Some(
    shader_node(body),
  )
}

///|
/// `If( boolNode, method )`.
pub fn StackNode::if_(
  self : StackNode,
  bool_node : &IntoTsl,
  body : () -> Unit,
) -> StackNode {
  self.if_shader(bool_node, stack_node_unit_fn(body))
}

///|
/// `If( boolNode, method )` with a body returning the branch output.
pub fn StackNode::if_value(
  self : StackNode,
  bool_node : &IntoTsl,
  body : () -> Node,
) -> StackNode {
  self.if_shader(bool_node, stack_node_value_fn(body))
}

///|
/// `ElseIf( boolNode, method )`.
pub fn StackNode::else_if(
  self : StackNode,
  bool_node : &IntoTsl,
  body : () -> Unit,
) -> StackNode {
  self.else_if_shader(bool_node, stack_node_unit_fn(body))
}

///|
/// `ElseIf( boolNode, method )` with a body returning the branch output.
pub fn StackNode::else_if_value(
  self : StackNode,
  bool_node : &IntoTsl,
  body : () -> Node,
) -> StackNode {
  self.else_if_shader(bool_node, stack_node_value_fn(body))
}

///|
/// `Else( method )`, the end of a chain.
pub fn StackNode::else_(self : StackNode, body : () -> Unit) -> Unit {
  self.else_shader(stack_node_unit_fn(body))
}

///|
/// `Else( method )` with a body returning the branch output.
pub fn StackNode::else_value(self : StackNode, body : () -> Node) -> Unit {
  self.else_shader(stack_node_value_fn(body))
}

///|
/// `Switch( expression )`.
pub fn StackNode::switch_(self : StackNode, expression : &IntoTsl) -> StackNode {
  self._expression_node = Some(node_object(expression.to_tsl()))
  self
}

///|
/// `Case( ...values, method )`: a branch taken when the expression equals any value.
pub fn StackNode::case_(
  self : StackNode,
  values : Array[&IntoTsl],
  body : () -> Unit,
) -> StackNode {
  let case_nodes : Array[Node] = []
  if values.length() >= 1 {
    let expression_node = self._expression_node.unwrap()
    for value in values {
      case_nodes.push(expression_node.equal(node_object(value.to_tsl())))
    }
  } else {
    @core.error(
      "TSL: Invalid parameter length. Case() requires at least two parameters.",
    )
  }
  let method_node = shader_node(stack_node_unit_fn(body))
  let mut case_node : TslValue = match case_nodes.get(0) {
    Some(n) => Node(n)
    None => Undefined
  }
  for i in 1..<case_nodes.length() {
    case_node = Node(case_node.as_node().unwrap().or(case_nodes[i]))
  }
  let cond_node = select(case_node, method_node)
  match self._current_cond {
    None => {
      self._current_cond = Some(cond_node)
      self.add_to_stack(cond_node)
    }
    Some(current_cond) => {
      ConditionalNode::of(current_cond).unwrap().else_node = Some(cond_node)
      self._current_cond = Some(cond_node)
      self
    }
  }
}

///|
/// `Default( method )`, the end of a `Switch`.
pub fn StackNode::default(self : StackNode, body : () -> Unit) -> Unit {
  self.else_(body)
}
