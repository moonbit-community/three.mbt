// nodes/gpgpu/AtomicFunctionNode.js

///|
/// An atomic operation on a storage or workgroup pointer.
pub(all) struct AtomicFunctionNode {
  mut method_ : String
  mut pointer_node : Node
  mut value_node : Node?
}

///|
pub impl NodeClass for AtomicFunctionNode with fn class_name(_) {
  "AtomicFunctionNode"
}

///|
pub impl NodeClass for AtomicFunctionNode with fn children(self, _, out) {
  push_child(out, "pointerNode", Some(self.pointer_node))
  push_child(out, "valueNode", self.value_node)
}

///|
pub impl NodeClass for AtomicFunctionNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for AtomicFunctionNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for AtomicFunctionNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.get_input_type(builder)
}

///|
pub impl NodeClass for AtomicFunctionNode with fn generate(
  self,
  node,
  builder,
  _,
) {
  let method_ = self.method_
  if builder.shader_stage == Some("vertex") {
    @core.error(
      "TSL: \"\{self.method_}\" is not supported in the vertex stage.",
    )
  }
  let properties = builder.get_node_properties(node)
  let parents = match properties.get("parents") {
    Some(Nodes(list)) => Some(list)
    _ => None
  }
  let type_ = node.get_node_type(builder)
  let input_type = self.get_input_type(builder)
  let a = self.pointer_node
  let b = self.value_node
  let params = []
  params.push("&\{a.build(builder, output?=input_type)}")
  if b is Some(b) {
    params.push(b.build(builder, output?=input_type))
  }
  let method_snippet = "\{builder.get_method(method_, output?=type_)}( \{params.join(", ")} )"
  let is_void = match parents {
    Some(list) => list.length() == 1 && list[0].has_flag("isStackNode")
    None => false
  }
  if is_void {
    builder.add_line_flow_code(method_snippet, node~) |> ignore
    None
  } else {
    // The result is stored in a constant, declared in the block where the operation is generated.
    let node_var = builder.get_var_from_node(
      node,
      None,
      type_,
      None,
      true,
      true,
      "variable",
    )
    let property_name = builder.get_property_name(Var(node_var))
    builder.add_line_flow_code(
      "\{builder.generate_let_statement(type_.unwrap_or("null"), property_name, None)} = \{method_snippet}",
      node~,
    )
    |> ignore
    Some(property_name)
  }
}

///|
/// `getInputType( builder )`: the pointer's type.
fn AtomicFunctionNode::get_input_type(
  self : AtomicFunctionNode,
  builder : NodeBuilder,
) -> String? {
  self.pointer_node.get_node_type(builder)
}

///|
pub fn AtomicFunctionNode::construct(
  node : Node,
  method_ : String,
  pointer_node : Node,
  value_node : Node?,
) -> AtomicFunctionNode {
  node.parents = true
  { method_, pointer_node, value_node, }
}

///|
/// `new AtomicFunctionNode( method, pointerNode, valueNode )`.
pub fn AtomicFunctionNode::new(
  method_ : String,
  pointer_node : Node,
  value_node : Node?,
) -> Node {
  let node = Node::alloc(node_type="uint")
  node.set_class(
    AtomicFunctionNode::construct(node, method_, pointer_node, value_node),
  )
}

///|
pub fn AtomicFunctionNode::of(node : Node) -> AtomicFunctionNode? {
  match node.class_payload("AtomicFunctionNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub fn AtomicFunctionNode::atomic_load() -> String {
  "atomicLoad"
}

///|
pub fn AtomicFunctionNode::atomic_store() -> String {
  "atomicStore"
}

///|
pub fn AtomicFunctionNode::atomic_add() -> String {
  "atomicAdd"
}

///|
pub fn AtomicFunctionNode::atomic_sub() -> String {
  "atomicSub"
}

///|
pub fn AtomicFunctionNode::atomic_max() -> String {
  "atomicMax"
}

///|
pub fn AtomicFunctionNode::atomic_min() -> String {
  "atomicMin"
}

///|
pub fn AtomicFunctionNode::atomic_and() -> String {
  "atomicAnd"
}

///|
pub fn AtomicFunctionNode::atomic_or() -> String {
  "atomicOr"
}

///|
pub fn AtomicFunctionNode::atomic_xor() -> String {
  "atomicXor"
}

///|
/// `atomicFunc( method, pointerNode, valueNode )`: the operation, added to the stack.
pub fn atomic_func(
  method_ : String,
  pointer_node : &IntoTsl,
  value_node : &IntoTsl?,
) -> Node {
  // `nodeProxy( AtomicFunctionNode )` converts every argument; `null` stays `null`.
  let pointer = node_object(pointer_node.to_tsl())
  let value = match value_node {
    Some(v) =>
      match node_object_value(v.to_tsl()) {
        Node(n) => Some(n)
        _ => None
      }
    None => None
  }
  AtomicFunctionNode::new(method_, pointer, value).to_stack()
}

///|
pub fn atomic_load(pointer_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_load(), pointer_node, None)
}

///|
pub fn atomic_store(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(
    AtomicFunctionNode::atomic_store(),
    pointer_node,
    Some(value_node),
  )
}

///|
pub fn atomic_add(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_add(), pointer_node, Some(value_node))
}

///|
pub fn atomic_sub(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_sub(), pointer_node, Some(value_node))
}

///|
pub fn atomic_max(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_max(), pointer_node, Some(value_node))
}

///|
pub fn atomic_min(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_min(), pointer_node, Some(value_node))
}

///|
pub fn atomic_and(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_and(), pointer_node, Some(value_node))
}

///|
pub fn atomic_or(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_or(), pointer_node, Some(value_node))
}

///|
pub fn atomic_xor(pointer_node : &IntoTsl, value_node : &IntoTsl) -> Node {
  atomic_func(AtomicFunctionNode::atomic_xor(), pointer_node, Some(value_node))
}
