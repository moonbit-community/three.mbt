// nodes/gpgpu/ComputeBuiltinNode.js

///|
/// A compute shader built-in value (`numWorkgroups`, `workgroupId`, ...).
pub(all) struct ComputeBuiltinNode {
  mut _builtin_name : String
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn class_name(_) {
  "ComputeBuiltinNode"
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn get_hash(self, _, _) {
  self._builtin_name
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn generate_node_type(
  _,
  node,
  _,
  _,
) {
  node.node_type
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let builtin_name = self._builtin_name
  let node_type = node.get_node_type(builder)
  if builder.shader_stage == Some("compute") {
    Some(builder.format(builtin_name, node_type, output))
  } else {
    @core.warn(
      "TSL: Compute built-in value \"\{builtin_name}\" can not be accessed in the \{builder.shader_stage.unwrap_or("undefined")} stage",
    )
    Some(builder.generate_const(node_type.unwrap_or("null")))
  }
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("global", @core.JsValue::of(node.global))
  data.set("_builtinName", @core.JsValue::of(self._builtin_name))
}

///|
pub impl NodeClass for ComputeBuiltinNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  node.global = data.get("global").cast()
  self._builtin_name = data.get("_builtinName").cast()
}

///|
pub fn ComputeBuiltinNode::construct(
  _node : Node,
  builtin_name : String,
) -> ComputeBuiltinNode {
  { _builtin_name: builtin_name, }
}

///|
/// `new ComputeBuiltinNode( builtinName, nodeType )`.
pub fn ComputeBuiltinNode::new(
  builtin_name : String,
  node_type : String,
) -> Node {
  let node = Node::alloc(node_type~)
  node.set_class(ComputeBuiltinNode::construct(node, builtin_name))
}

///|
pub fn ComputeBuiltinNode::of(node : Node) -> ComputeBuiltinNode? {
  match node.class_payload("ComputeBuiltinNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn compute_builtin_payload(node : Node, name : String) -> ComputeBuiltinNode {
  match ComputeBuiltinNode::of(node) {
    Some(c) => c
    None => abort("TypeError: \{node.type_()}.\{name} is not a function")
  }
}

///|
/// `setBuiltinName( builtinName )`.
pub fn Node::set_builtin_name(self : Node, builtin_name : String) -> Node {
  compute_builtin_payload(self, "setBuiltinName")._builtin_name = builtin_name
  self
}

///|
/// `getBuiltinName( builder )`.
pub fn Node::get_builtin_name(self : Node, _builder : NodeBuilder) -> String {
  compute_builtin_payload(self, "getBuiltinName")._builtin_name
}

///|
/// `hasBuiltin( builder )`.
pub fn Node::has_builtin(self : Node, builder : NodeBuilder) -> Bool {
  builder.has_builtin(compute_builtin_payload(self, "hasBuiltin")._builtin_name)
}

///|
fn compute_builtin(name : String, node_type : String) -> Node {
  ComputeBuiltinNode::new(name, node_type)
}

///|
/// `numWorkgroups`: the number of workgroups in the dispatch.
pub let num_workgroups : Node = module_nodes(
  "nodes/gpgpu/ComputeBuiltinNode.js:numWorkgroups",
  fn() { compute_builtin("numWorkgroups", "uvec3") },
)

///|
/// `workgroupId`: the workgroup of the invocation.
pub let workgroup_id : Node = module_nodes(
  "nodes/gpgpu/ComputeBuiltinNode.js:workgroupId",
  fn() { compute_builtin("workgroupId", "uvec3") },
)

///|
/// `globalId`: the global invocation id.
pub let global_id : Node = module_nodes(
  "nodes/gpgpu/ComputeBuiltinNode.js:globalId",
  fn() { compute_builtin("globalId", "uvec3") },
)

///|
/// `localId`: the invocation id within its workgroup.
pub let local_id : Node = module_nodes(
  "nodes/gpgpu/ComputeBuiltinNode.js:localId",
  fn() { compute_builtin("localId", "uvec3") },
)

///|
/// `subgroupSize`: the number of invocations in a subgroup.
pub let subgroup_size : Node = module_nodes(
  "nodes/gpgpu/ComputeBuiltinNode.js:subgroupSize",
  fn() { compute_builtin("subgroupSize", "uint") },
)
