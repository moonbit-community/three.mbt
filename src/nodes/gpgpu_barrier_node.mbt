// nodes/gpgpu/BarrierNode.js

///|
/// A `workgroupBarrier()`, `storageBarrier()` or `textureBarrier()` statement.
pub(all) struct BarrierNode {
  mut scope : String
}

///|
pub impl NodeClass for BarrierNode with fn class_name(_) {
  "BarrierNode"
}

///|
/// Upstream has no `static get type()`, so it inherits `Node`'s.
pub impl NodeClass for BarrierNode with fn type_name(_) {
  "Node"
}

///|
pub impl NodeClass for BarrierNode with fn has_flag(_, flag) {
  flag == "isBarrierNode"
}

///|
pub impl NodeClass for BarrierNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for BarrierNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for BarrierNode with fn setup(_, _, builder) {
  builder.allow_early_returns = false
  builder.allow_global_variables = false
  None
}

///|
pub impl NodeClass for BarrierNode with fn generate(self, node, builder, _) {
  let scope = self.scope
  let renderer = builder.renderer
  let shader_stage = builder.shader_stage
  let barrier_method = "\{scope}Barrier"
  if shader_stage != Some("compute") {
    @core.error(
      "TSL: \"\{barrier_method}\" is not supported in the \{shader_stage.unwrap_or("undefined")} stage and can only be executed in compute.",
    )
  }
  if renderer.backend.has_flag("isWebGLBackend") {
    builder.add_flow_code("\t// \{barrier_method}() \n") |> ignore
  } else {
    builder.add_line_flow_code("\{barrier_method}()", node~) |> ignore
  }
  None
}

///|
pub fn BarrierNode::construct(_node : Node, scope : String) -> BarrierNode {
  { scope, }
}

///|
/// `new BarrierNode( scope )`.
pub fn BarrierNode::new(scope : String) -> Node {
  let node = Node::alloc()
  node.set_class(BarrierNode::construct(node, scope))
}

///|
pub fn BarrierNode::of(node : Node) -> BarrierNode? {
  match node.class_payload("BarrierNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `workgroupBarrier()`.
pub fn workgroup_barrier() -> Unit {
  BarrierNode::new("workgroup").to_stack() |> ignore
}

///|
/// `storageBarrier()`.
pub fn storage_barrier() -> Unit {
  BarrierNode::new("storage").to_stack() |> ignore
}

///|
/// `textureBarrier()`.
pub fn texture_barrier() -> Unit {
  BarrierNode::new("texture").to_stack() |> ignore
}
