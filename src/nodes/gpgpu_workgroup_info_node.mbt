// nodes/gpgpu/WorkgroupInfoNode.js

///|
/// An element of a `workgroupArray`, `array[ index ]`.
pub(all) struct WorkgroupInfoElementNode {
  array_element : ArrayElementNode
}

///|
pub impl NodeClass for WorkgroupInfoElementNode with fn class_name(_) {
  "WorkgroupInfoElementNode"
}

///|
/// Upstream has no `static get type()`, so it inherits `ArrayElementNode`'s.
pub impl NodeClass for WorkgroupInfoElementNode with fn type_name(_) {
  "ArrayElementNode"
}

///|
pub impl NodeClass for WorkgroupInfoElementNode with fn parent(self) {
  Some(self.array_element)
}

///|
pub impl NodeClass for WorkgroupInfoElementNode with fn has_flag(self, flag) {
  flag == "isWorkgroupInfoElementNode" || self.array_element.has_flag(flag)
}

///|
pub impl NodeClass for WorkgroupInfoElementNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for WorkgroupInfoElementNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let is_assign_context = builder.is_context_assign()
  let mut snippet = self.array_element
    .generate(node, builder, None)
    .unwrap_or("")
  if is_assign_context != true {
    let type_ = node.get_node_type(builder)
    snippet = builder.format(snippet, type_, output)
  }
  // TODO: Possibly activate clip distance index on index access rather than from clipping context
  Some(snippet)
}

///|
/// `new WorkgroupInfoElementNode( workgroupInfoNode, indexNode )`.
pub fn WorkgroupInfoElementNode::new(
  workgroup_info_node : Node,
  index_node : Node,
) -> Node {
  let node = Node::alloc()
  let array_element = ArrayElementNode::construct(
    node, workgroup_info_node, index_node,
  )
  node.set_class(WorkgroupInfoElementNode::{ array_element, })
}

///|
pub fn WorkgroupInfoElementNode::of(node : Node) -> WorkgroupInfoElementNode? {
  match node.class_payload("WorkgroupInfoElementNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// A buffer shared by the invocations of a workgroup (`var<workgroup>`).
pub(all) struct WorkgroupInfoNode {
  mut buffer_type : String
  mut buffer_count : Int32
  mut is_atomic : Bool
  mut element_type : String
  mut scope : String
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn class_name(_) {
  "WorkgroupInfoNode"
}

///|
/// Upstream has no `static get type()`, so it inherits `Node`'s.
pub impl NodeClass for WorkgroupInfoNode with fn type_name(_) {
  "Node"
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn has_flag(_, flag) {
  flag == "isWorkgroupInfoNode"
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn set_name(_, node, name) {
  node.name = Some(name)
  Some(node)
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn label(_, node, name) {
  @core.warn("TSL: \"label()\" has been deprecated. Use \"setName()\" instead.")
  Some(node.set_name(name))
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn set_atomic(self, node, value) {
  self.is_atomic = value
  Some(node)
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn get_element_type(self, _, _) {
  Some(self.element_type)
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn element(_, node, index_node) {
  Some(WorkgroupInfoElementNode::new(node, index_node))
}

///|
pub impl NodeClass for WorkgroupInfoNode with fn generate(
  self,
  node,
  builder,
  _,
) {
  if builder.shader_stage != Some("compute") {
    @core.error(
      "TSL: \"workgroupArray()\" can only be executed within the compute shader stage",
    )
  }
  let name = match node.name {
    Some(n) if n != "" => n
    _ => "\{self.scope}Array_\{node.id}"
  }
  Some(
    builder.get_scoped_array(
      name,
      self.scope.to_lower(),
      self.buffer_type,
      self.buffer_count,
      self.is_atomic,
    ),
  )
}

///|
/// `getInputType()`: `'<scope>Array'`.
pub fn WorkgroupInfoNode::get_input_type(self : WorkgroupInfoNode) -> String {
  "\{self.scope}Array"
}

///|
pub fn WorkgroupInfoNode::construct(
  node : Node,
  scope : String,
  buffer_type : String,
  buffer_count : Int32,
) -> WorkgroupInfoNode {
  node.name = Some("")
  {
    buffer_type,
    buffer_count,
    is_atomic: false,
    element_type: buffer_type,
    scope,
  }
}

///|
/// `new WorkgroupInfoNode( scope, bufferType, bufferCount = 0 )`.
pub fn WorkgroupInfoNode::new(
  scope : String,
  buffer_type : String,
  buffer_count~ : Int32 = 0,
) -> Node {
  let node = Node::alloc(node_type=buffer_type)
  node.set_class(
    WorkgroupInfoNode::construct(node, scope, buffer_type, buffer_count),
  )
}

///|
pub fn WorkgroupInfoNode::of(node : Node) -> WorkgroupInfoNode? {
  match node.class_payload("WorkgroupInfoNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn workgroup_info_payload(node : Node, name : String) -> WorkgroupInfoNode {
  match WorkgroupInfoNode::of(node) {
    Some(w) => w
    None => abort("TypeError: \{node.type_()}.\{name} is not a function")
  }
}

///|
/// `setScope( scope )`.
pub fn Node::set_scope(self : Node, scope : String) -> Node {
  workgroup_info_payload(self, "setScope").scope = scope
  self
}

///|
/// `workgroupArray( type, count )`: a workgroup-shared array.
pub fn workgroup_array(type_ : String, count~ : Int32 = 0) -> Node {
  WorkgroupInfoNode::new("Workgroup", type_, buffer_count=count)
}
