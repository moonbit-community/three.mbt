// nodes/accessors/ReferenceBaseNode.js: the uniform-only form of ReferenceNode (no
// textures, buffers or arrays). Its TSL functions are `reference_base` and
// `reference_base_buffer` (ReferenceNode's take the plain names).

///|
pub(all) struct ReferenceBaseNode {
  property : String
  uniform_type : String?
  object : ReferenceObject?
  count : Int32?
  properties : Array[String]
  mut reference : ReferenceObject?
  mut node : Node?
  mut group : Node?
}

///|
pub impl NodeClass for ReferenceBaseNode with fn class_name(_) {
  "ReferenceBaseNode"
}

///|
pub impl NodeClass for ReferenceBaseNode with fn children(self, _, out) {
  push_child(out, "node", self.node)
  push_child(out, "group", self.group)
}

///|
pub impl NodeClass for ReferenceBaseNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ReferenceBaseNode with fn element(_, node, index_node) {
  Some(ReferenceElementNode::new(node, index_node))
}

///|
pub impl NodeClass for ReferenceBaseNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  if self.node is None {
    node.update_reference(Builder(builder)) |> ignore
    ReferenceBaseNode::update_value(node)
  }
  self.node.unwrap().get_node_type(builder)
}

///|
pub impl NodeClass for ReferenceBaseNode with fn update_reference(
  self,
  _,
  state,
) {
  self.reference = match self.object {
    Some(o) => Some(o)
    None => reference_state_object(state).map(fn(o) { Object3D(o) })
  }
  self.reference_identity()
}

///|
pub impl NodeClass for ReferenceBaseNode with fn setup(self, node, _) {
  ReferenceBaseNode::update_value(node)
  self.node
}

///|
pub impl NodeClass for ReferenceBaseNode with fn update(_, node, _) {
  ReferenceBaseNode::update_value(node)
  None
}

///|
fn ReferenceBaseNode::reference_identity(
  self : ReferenceBaseNode,
) -> @core.JsValue {
  match self.reference {
    Some(r) => r.identity()
    None => @core.JsValue::null()
  }
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn ReferenceBaseNode::construct(
  node : Node,
  property : String,
  uniform_type : String?,
  object : ReferenceObject?,
  count : Int32?,
) -> ReferenceBaseNode {
  node.update_type = NodeUpdateType::object()
  {
    property,
    uniform_type,
    object,
    count,
    properties: property.split(".").map(fn(s) { s.to_owned() }).collect(),
    reference: object,
    node: None,
    group: None,
  }
}

///|
/// `new ReferenceBaseNode( property, uniformType, object = null, count = null )`.
pub fn ReferenceBaseNode::new(
  property : String,
  uniform_type : String?,
  object? : ReferenceObject,
  count? : Int32,
) -> Node {
  let node = Node::alloc()
  node.set_class(
    ReferenceBaseNode::construct(node, property, uniform_type, object, count),
  )
}

///|
pub fn ReferenceBaseNode::of(node : Node) -> ReferenceBaseNode? {
  match node.class_payload("ReferenceBaseNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn reference_base_node_payload(node : Node) -> ReferenceBaseNode {
  match ReferenceBaseNode::of(node) {
    Some(r) => r
    None => abort("TypeError: \{node.type_()} is not a ReferenceBaseNode")
  }
}

///|
/// `setGroup( group )` of a reference base node.
pub fn ReferenceBaseNode::set_group(node : Node, group : Node) -> Node {
  reference_base_node_payload(node).group = Some(group)
  node
}

///|
/// `setNodeType( uniformType )`.
pub fn ReferenceBaseNode::set_node_type(
  node : Node,
  uniform_type : String?,
) -> Unit {
  let r = reference_base_node_payload(node)
  let n = uniform(TslValue::Null, type_?=uniform_type)
  match r.group {
    Some(g) => n.set_group(g) |> ignore
    None => ()
  }
  r.node = Some(n)
}

///|
/// `getValueFromReference( object = this.reference )`.
pub fn ReferenceBaseNode::get_value_from_reference(
  node : Node,
  object? : ReferenceObject,
) -> TslValue {
  let r = reference_base_node_payload(node)
  let object = match object {
    Some(o) => Some(o)
    None => r.reference
  }
  match object {
    Some(o) => reference_object_value(o, r.properties)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading '\{r.properties[0]}')",
      )
  }
}

///|
/// `updateValue()`.
pub fn ReferenceBaseNode::update_value(node : Node) -> Unit {
  let r = reference_base_node_payload(node)
  if r.node is None {
    ReferenceBaseNode::set_node_type(node, r.uniform_type)
  }
  reference_set_node_value(
    r.node.unwrap(),
    ReferenceBaseNode::get_value_from_reference(node),
  )
}

///|
/// ReferenceBaseNode's `reference( name, type, object )`.
pub fn reference_base(
  name : String,
  type_ : String,
  object? : ReferenceObject,
) -> Node {
  ReferenceBaseNode::new(name, Some(type_), object?)
}

///|
/// ReferenceBaseNode's `referenceBuffer( name, type, count, object )`.
pub fn reference_base_buffer(
  name : String,
  type_ : String,
  count : Int32,
  object? : ReferenceObject,
) -> Node {
  ReferenceBaseNode::new(name, Some(type_), object?, count~)
}
