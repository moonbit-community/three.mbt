// nodes/core/StructNode.js

///|
/// A value of a struct type created with `struct_`.
pub(all) struct StructNode {
  mut struct_type_node : Node
  /// `values`: member name -> node, or `null`.
  mut values : Map[String, Node]?
}

///|
pub impl NodeClass for StructNode with fn class_name(_) {
  "StructNode"
}

///|
pub impl NodeClass for StructNode with fn has_flag(_, flag) {
  flag == "isStructNode"
}

///|
/// `_getChildren()` moves the struct type to the end, so it is generated last.
pub impl NodeClass for StructNode with fn children(self, _, out) {
  if self.values is Some(values) {
    push_child_object(out, "values", values)
  }
  push_child(out, "structTypeNode", Some(self.struct_type_node))
}

///|
pub impl NodeClass for StructNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for StructNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for StructNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.struct_type_node.get_node_type(builder)
}

///|
pub impl NodeClass for StructNode with fn get_member_type(
  self,
  _,
  builder,
  name,
) {
  self.struct_type_node.get_member_type(builder, name)
}

///|
pub impl NodeClass for StructNode with fn generate(self, node, builder, _) {
  let node_var = builder.get_var_from_node(
    node,
    None,
    None,
    None,
    false,
    false,
    "variable",
  )
  let struct_type = node_var.type_
  let property_name = builder.get_property_name(Var(node_var))
  let members_layout = StructTypeNode::of(self.struct_type_node).unwrap().members_layout
  let values = match self.values {
    Some(values) => Some(members_layout.map(fn(m) { values.get(m.name) }))
    None => None
  }
  let snippet = builder.generate_struct(struct_type, members_layout, values?)
  builder.add_line_flow_code("\{property_name} = \{snippet}", node~) |> ignore
  Some(node_var.name)
}

///|
pub fn StructNode::construct(
  _node : Node,
  struct_type_node : Node,
  values : Map[String, Node]?,
) -> StructNode {
  { struct_type_node, values, }
}

///|
/// `new StructNode( structTypeNode, values )`.
pub fn StructNode::new(
  struct_type_node : Node,
  values : Map[String, Node]?,
) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(StructNode::construct(node, struct_type_node, values))
}

///|
pub fn StructNode::of(node : Node) -> StructNode? {
  match node.class_payload("StructNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// What `struct( membersLayout, name )` returns (`nodeProxyConstructor`).
pub(all) struct StructFn {
  /// The `StructTypeNode`.
  node : Node
  /// The member names, in layout order (`Object.keys( membersLayout )`).
  names : Array[String]
}

///|
/// `struct( membersLayout, name = null )`.
pub fn struct_(
  members_layout : Array[StructMember],
  name? : String,
) -> StructFn {
  let struct_type = StructTypeNode::new(members_layout, name?)
  { node: struct_type, names: members_layout.map(fn(m) { m.name }), }
}

///|
/// `S( a, b, ... )`: a struct value from positional members; `S()` has no values.
pub fn StructFn::call(self : StructFn, params : Array[&IntoTsl]) -> Node {
  if params.length() == 0 {
    return StructNode::new(self.node, None)
  }
  let values = Map([])
  for i, param in params {
    let key = if i < self.names.length() { self.names[i] } else { "undefined" }
    values.set(key, node_object(param.to_tsl()))
  }
  StructNode::new(self.node, Some(values))
}

///|
/// `S( { a, b } )`: values are taken as given, not through `nodeObject`.
pub fn StructFn::call_named(
  self : StructFn,
  values : Map[String, Node],
) -> Node {
  StructNode::new(self.node, Some(values))
}
