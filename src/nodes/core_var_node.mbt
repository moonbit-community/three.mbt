// nodes/core/VarNode.js

///|
/// Declares its node as a shader variable (`toVar`) or constant (`toConst`).
pub(all) struct VarNode {
  mut node : Node
  // `Const` passes `readOnly` through `nodeProxy`, which makes `true` the bool
  // constant node, so the value is kept as given (a truthy node, not `true`).
  /// `readOnly`.
  mut read_only : TslValue
}

///|
pub impl NodeClass for VarNode with fn class_name(_) {
  "VarNode"
}

///|
pub impl NodeClass for VarNode with fn has_flag(_, flag) {
  flag == "isVarNode"
}

///|
pub impl NodeClass for VarNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
  push_tsl_child(out, "readOnly", self.read_only)
}

///|
pub impl NodeClass for VarNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for VarNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for VarNode with fn get_member_type(self, _, builder, name) {
  self.node.get_member_type(builder, name)
}

///|
pub impl NodeClass for VarNode with fn get_element_type(self, _, builder) {
  self.node.get_element_type(builder)
}

///|
pub impl NodeClass for VarNode with fn generate_node_type(self, _, builder, _) {
  self.node.get_node_type(builder)
}

///|
pub impl NodeClass for VarNode with fn get_array_count(self, _, builder) {
  self.node.get_array_count(builder)
}

///|
pub impl NodeClass for VarNode with fn declares_assignable(_, _) {
  false
}

///|
pub impl NodeClass for VarNode with fn is_function_scope(self, node) {
  self.read_only is Bool(false) && node.assignable == false
}

///|
pub impl NodeClass for VarNode with fn build(self, node, builder, output) {
  node._setup_inspector(builder)
  let ref_node = node.get_shared(builder)
  if !physical_equal(node, ref_node) {
    return ref_node.build_output(builder, output)
  }
  let data = builder.get_data_from_node(node)
  node._update_assignable(builder, data, value_node=self.node)
  if node.assignable &&
    data.force_declaration != Some(true) &&
    data.assign != Some(true) {
    return self.node.build_output(builder, output)
  }
  node.build_base(builder, output)
}

///|
pub impl NodeClass for VarNode with fn generate(self, node, builder, _) {
  let input_node = self.node
  let name = node.name
  let node_type = node.get_node_type(builder)
  if node_type == Some("void") {
    if node.is_assignable(builder) != true {
      @core.error("TSL: \".toVar()\" can not be used with void type.")
    }
    let snippet = input_node.build(builder)
    return Some(snippet)
  }
  let vector_type = builder.get_vector_type(node_type)
  let snippet = input_node.build(builder, output?=vector_type)
  let node_var = builder.get_var_from_node(
    node,
    name,
    vector_type,
    None,
    var_node_truthy(self.read_only),
    node.assignable,
    "variable",
  )
  let property_name = builder.get_property_name(Var(node_var))
  let mut declaration_prefix = property_name
  if node_var.read_only {
    let count = input_node.get_array_count(builder)
    declaration_prefix = if builder.is_deterministic(input_node) {
      builder.generate_const_statement(node_var.type_, property_name, count?)
    } else {
      builder.generate_let_statement(node_var.type_, property_name, count)
    }
  } else if node_var.local_ {
    declaration_prefix = builder.generate_var_statement(
      node_var.type_,
      property_name,
      node_var.count,
    )
  }
  builder.add_line_flow_code("\{declaration_prefix} = \{snippet}", node~)
  |> ignore
  Some(property_name)
}

///|
pub fn VarNode::construct(
  node : Node,
  input_node : Node,
  name : String?,
  read_only : TslValue,
) -> VarNode {
  let var_ = VarNode::{ node: input_node, read_only: Bool(false), }
  node.name = name
  node.global = true
  var_.read_only = read_only
  node.parents = true
  node.assignable = false
  var_
}

///|
/// `new VarNode( node, name = null, readOnly = false )`.
pub fn VarNode::new(
  node : Node,
  name? : String,
  read_only~ : TslValue = Bool(false),
) -> Node {
  let this = Node::alloc()
  this.set_class(VarNode::construct(this, node, name, read_only))
}

///|
pub fn VarNode::of(node : Node) -> VarNode? {
  match node.class_payload("VarNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn var_node_truthy(value : TslValue) -> Bool {
  match value {
    Undefined | Null => false
    Bool(b) => b
    Number(x) => x != 0.0 && x == x
    String(s) => s != ""
    _ => true
  }
}

///|
/// `setAssignable( value )`, chained.
pub fn Node::set_assignable(self : Node, value : Bool) -> Node {
  guard VarNode::of(self) is Some(_) else {
    abort("setAssignable: \{self.type_()} is not a VarNode")
  }
  self.assignable = value
  self
}

///|
/// `getAssignable()`.
pub fn Node::get_assignable(self : Node) -> Bool {
  guard VarNode::of(self) is Some(_) else {
    abort("getAssignable: \{self.type_()} is not a VarNode")
  }
  self.assignable
}

///|
/// `createVar( node, name, readOnly )`: `nodeProxy( VarNode )`.
fn var_node_create(node : &IntoTsl, name : String?, read_only : Bool?) -> Node {
  let read_only = match read_only {
    Some(b) => TslValue::Node(node_object(Bool(b)))
    None => Bool(false)
  }
  VarNode::new(node_object(node.to_tsl()), name?, read_only~)
}

///|
/// `Var( node, name = null )`.
pub fn var_(node : &IntoTsl, name? : String) -> Node {
  var_node_create(node, name, None).to_stack()
}

///|
/// `Const( node, name = null )`.
pub fn const_(node : &IntoTsl, name? : String) -> Node {
  var_node_create(node, name, Some(true)).to_stack()
}

///|
/// `toVar( name )`.
pub fn Node::to_var(self : Node, name? : String) -> Node {
  var_(self, name?)
}

///|
/// `toConst( name )`.
pub fn Node::to_const(self : Node, name? : String) -> Node {
  const_(self, name?)
}
