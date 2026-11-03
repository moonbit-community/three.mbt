// nodes/core/OverrideContextNode.js

///|
/// A context of `{ overrideNodes }`: mapped nodes build what their callback returns.
pub(all) struct OverrideContextNode {
  context : ContextNode
}

///|
pub impl NodeClass for OverrideContextNode with fn class_name(_) {
  "OverrideContextNode"
}

///|
pub impl NodeClass for OverrideContextNode with fn parent(self) {
  Some(self.context)
}

///|
pub impl NodeClass for OverrideContextNode with fn has_flag(self, flag) {
  flag == "isOverrideContextNode" || self.context.has_flag(flag)
}

///|
/// The `null` callback of an `overrideNodes` entry (cancels an outer override).
pub let override_callback_null : OverrideCallback = {
  f: fn(_) { abort("override_callback_null is never called") },
}

///|
/// `() => node`.
pub fn OverrideCallback::of_node(node : Node) -> OverrideCallback {
  { f: fn(_) { node }, }
}

///|
pub fn OverrideContextNode::construct(
  node : Node,
  override_nodes : OverrideNodes,
  flow_node : Node?,
  shader_stage : String?,
) -> OverrideContextNode {
  let value = node_context([("overrideNodes", Overrides(override_nodes))])
  if shader_stage == Some("fragment") {
    value.set("inlineVaryings", Bool(true))
  }
  { context: ContextNode::construct(node, flow_node, value), }
}

///|
/// `new OverrideContextNode( overrideNodes, flowNode = null, shaderStage = null )`.
pub fn OverrideContextNode::new(
  override_nodes : OverrideNodes,
  flow_node? : Node,
  shader_stage? : String,
) -> Node {
  let this = Node::alloc()
  this.set_class(
    OverrideContextNode::construct(
      this, override_nodes, flow_node, shader_stage,
    ),
  )
}

///|
pub fn OverrideContextNode::of(node : Node) -> OverrideContextNode? {
  match node.class_payload("OverrideContextNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `overrideNode( targetNode, callback = null, flowNode = null )`.
pub fn override_node(
  target_node : Node,
  callback : OverrideCallback?,
  flow_node? : Node,
) -> Node {
  let callback = callback.unwrap_or(override_callback_null)
  OverrideContextNode::new({ entries: [(target_node, callback)], }, flow_node?)
}

///|
/// `overrideNode( targetNode, node, flowNode )` with a node: `() => node`.
pub fn override_node_value(
  target_node : Node,
  node : Node,
  flow_node? : Node,
) -> Node {
  override_node(target_node, Some(OverrideCallback::of_node(node)), flow_node?)
}

///|
/// `overrideNode( node, callback )`, chained; `None` cancels an override.
pub fn Node::override_node(
  self : Node,
  node : Node,
  callback : OverrideCallback?,
) -> Node {
  override_node(node, callback, flow_node=self)
}

///|
/// `overrideNodes( overrides, flowNode = null, shaderStage = null )`.
pub fn override_nodes(
  overrides : Array[(Node, OverrideCallback?)],
  flow_node? : Node,
  shader_stage? : String,
) -> Node {
  let override_nodes_map = OverrideNodes::{ entries: [], }
  for entry in overrides {
    let (node, value) = entry
    let callback = match value {
      Some(callback) =>
        match shader_stage {
          Some(stage) =>
            override_context_node_stage_callback(node, callback, stage)
          None => callback
        }
      None => override_callback_null
    }
    override_nodes_map.set(node, callback)
  }
  OverrideContextNode::new(override_nodes_map, flow_node?, shader_stage?)
}

///|
/// `overrideNodes( overrides, shaderStage )`, chained.
pub fn Node::override_nodes(
  self : Node,
  overrides : Array[(Node, OverrideCallback?)],
  shader_stage? : String,
) -> Node {
  override_nodes(overrides, flow_node=self, shader_stage?)
}

///|
/// `getStageCallback( node, callback, shaderStage )`.
fn override_context_node_stage_callback(
  node : Node,
  callback : OverrideCallback,
  shader_stage : String,
) -> OverrideCallback {
  {
    f: fn(builder) {
      if builder.shader_stage == Some(shader_stage) {
        (callback.f)(builder)
      } else {
        node
      }
    },
  }
}
