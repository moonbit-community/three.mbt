// nodes/core/ContextNode.js

///|
/// Builds its node with `value` merged into the builder context.
pub(all) struct ContextNode {
  mut node : Node?
  mut value : NodeContext
}

///|
pub impl NodeClass for ContextNode with fn class_name(_) {
  "ContextNode"
}

///|
pub impl NodeClass for ContextNode with fn has_flag(_, flag) {
  flag == "isContextNode"
}

///|
pub impl NodeClass for ContextNode with fn children(self, _, out) {
  push_child(out, "node", self.node)
  for key, value in self.value.values {
    if !key.has_prefix("_") && value is Node(child_node) {
      out.push({ property: "value", index: Some(Key(key)), child_node, })
    }
  }
}

///|
pub impl NodeClass for ContextNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ContextNode with fn get_scope(self, _) {
  self.node.unwrap().get_scope()
}

///|
pub impl NodeClass for ContextNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.node.unwrap().get_node_type(builder)
}

///|
pub impl NodeClass for ContextNode with fn get_member_type(
  self,
  _,
  builder,
  name,
) {
  self.node.unwrap().get_member_type(builder, name)
}

///|
pub impl NodeClass for ContextNode with fn analyze(self, node, builder, _) {
  let usage_count = builder.increase_usage(node)
  if usage_count == 1 {
    let previous_context = builder.add_context(self.value)
    self.node.unwrap().build_output(builder, Parent(node)) |> ignore
    builder.set_context(previous_context)
  }
}

///|
pub impl NodeClass for ContextNode with fn setup(self, _, builder) {
  let previous_context = builder.add_context(self.value)
  self.node.unwrap().build_output(builder, NoOutput) |> ignore
  builder.set_context(previous_context)
  None
}

///|
pub impl NodeClass for ContextNode with fn generate(self, _, builder, output) {
  let previous_context = builder.add_context(self.value)
  let snippet = self.node.unwrap().build(builder, output?)
  builder.set_context(previous_context)
  Some(snippet)
}

///|
pub fn ContextNode::construct(
  _node : Node,
  input_node : Node?,
  value : NodeContext,
) -> ContextNode {
  { node: input_node, value, }
}

///|
/// `new ContextNode( node = null, value = {} )`.
pub fn ContextNode::new(node? : Node, value? : NodeContext) -> Node {
  let this = Node::alloc()
  let value = match value {
    Some(v) => v
    None => NodeContext::new()
  }
  this.set_class(ContextNode::construct(this, node, value))
}

///|
pub fn ContextNode::of(node : Node) -> ContextNode? {
  match node.class_payload("ContextNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `getFlowContextData()`: the merged `value` of every context node in the tree.
pub fn ContextNode::get_flow_context_data(node : Node) -> NodeContext {
  let mut data = NodeContext::new()
  node.traverse(fn(n) {
    if ContextNode::of(n) is Some(c) {
      data = NodeContext::merge(data, c.value)
    }
  })
  data
}

///|
/// A context object from `(key, value)` pairs, as an upstream object literal.
pub fn node_context(pairs : Array[(String, ContextValue)]) -> NodeContext {
  let context = NodeContext::new()
  for pair in pairs {
    context.set(pair.0, pair.1)
  }
  context
}

///|
/// `context( nodeOrValue = null, value = {} )`.
pub fn context(node? : Node, value? : NodeContext) -> Node {
  ContextNode::new(node?, value?)
}

///|
/// `context( value )`, chained.
pub fn Node::context(self : Node, value? : NodeContext) -> Node {
  context(node=self, value?)
}

///|
/// `uniformFlow( node )`.
pub fn uniform_flow(node : Node) -> Node {
  context(node~, value=node_context([("uniformFlow", Bool(true))]))
}

///|
pub fn Node::uniform_flow(self : Node) -> Node {
  uniform_flow(self)
}

///|
/// `setName( node, name )`: names the node through the context (`nodeName`).
pub fn set_name(node : Node, name : String) -> Node {
  context(node~, value=node_context([("nodeName", String(name))]))
}

///|
/// `setName( name )`, chained; `UniformNode` overrides it.
pub fn Node::set_name(self : Node, name : String) -> Node {
  match self.class_.set_name(self, name) {
    Some(n) => n
    None => set_name(self, name)
  }
}

///|
/// `label( node, name )`, deprecated: `setName`.
pub fn label(node : Node, name : String) -> Node {
  @core.warn("TSL: \"label()\" has been deprecated. Use \"setName()\" instead.")
  set_name(node, name)
}

///|
/// `label( name )`, chained; `UniformNode` overrides it.
pub fn Node::label(self : Node, name : String) -> Node {
  match self.class_.label(self, name) {
    Some(n) => n
    None => label(self, name)
  }
}

///|
/// `context.getShadow( lightNode, builder )`.
pub(all) struct ContextGetShadow {
  f : (Node, NodeBuilder) -> Node
}

///|
/// `context.getAO( inputNode, builder )` and `context.getGI( inputNode, builder )`.
pub(all) struct ContextGetLayer {
  f : (Node?, NodeBuilder) -> Node?
}

///|
/// `builder.context.getShadow`, if set.
pub fn NodeContext::get_shadow(self : NodeContext) -> ContextGetShadow? {
  match self.get("getShadow") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `builder.context.getAO`, if set.
pub fn NodeContext::get_ao(self : NodeContext) -> ContextGetLayer? {
  match self.get("getAO") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `builder.context.getGI`, if set.
pub fn NodeContext::get_gi(self : NodeContext) -> ContextGetLayer? {
  match self.get("getGI") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
fn context_node_transparent(builder : NodeBuilder) -> Bool {
  match builder.material {
    Some(m) => m.transparent
    None => false
  }
}

///|
/// `builtinShadowContext( shadowNode, light, node = null )`.
pub fn builtin_shadow_context(
  shadow_node : Node,
  light : @core.Object3D,
  node? : Node,
) -> Node {
  let get_shadow = ContextGetShadow::{
    f: fn(light_node, _) {
      let light_payload = AnalyticLightNode::of(light_node).unwrap()
      let shadow_color_node = light_payload.shadow_color_node.unwrap()
      match light_payload.light {
        Some(shadow_light) if physical_equal(light, shadow_light) =>
          shadow_color_node.mul(shadow_node)
        _ => shadow_color_node
      }
    },
  }
  context(
    node?,
    value=node_context([("getShadow", Other(@core.JsValue::of(get_shadow)))]),
  )
}

///|
/// `builtinAOContext( aoNode, node = null )`.
pub fn builtin_ao_context(ao_node : Node, node? : Node) -> Node {
  let get_ao = ContextGetLayer::{
    f: fn(input_node, builder) {
      if context_node_transparent(builder) {
        return input_node
      }
      match input_node {
        Some(n) => Some(n.mul(ao_node))
        None => Some(ao_node)
      }
    },
  }
  context(
    node?,
    value=node_context([("getAO", Other(@core.JsValue::of(get_ao)))]),
  )
}

///|
/// `builtinGIContext( aoNode, giNode, node = null )`.
pub fn builtin_gi_context(ao_node : Node, gi_node : Node, node? : Node) -> Node {
  let ao = ao_node.max(1.0e-3)
  let get_ao = ContextGetLayer::{
    f: fn(input_node, builder) {
      if context_node_transparent(builder) {
        return input_node
      }
      match input_node {
        Some(n) => Some(n.mul(ao))
        None => Some(ao)
      }
    },
  }
  let get_gi = ContextGetLayer::{
    f: fn(input_node, builder) {
      if context_node_transparent(builder) {
        return input_node
      }
      let gi = gi_node.div(ao)
      match input_node {
        Some(n) => Some(n.add(gi))
        None => Some(gi)
      }
    },
  }
  context(
    node?,
    value=node_context([
      ("getAO", Other(@core.JsValue::of(get_ao))),
      ("getGI", Other(@core.JsValue::of(get_gi))),
    ]),
  )
}

///|
pub fn Node::builtin_shadow_context(
  self : Node,
  shadow_node : Node,
  light : @core.Object3D,
) -> Node {
  builtin_shadow_context(shadow_node, light, node=self)
}

///|
pub fn Node::builtin_ao_context(self : Node, ao_value : Node) -> Node {
  builtin_ao_context(ao_value, node=self)
}

///|
pub fn Node::builtin_gi_context(
  self : Node,
  ao_value : Node,
  gi_value : Node,
) -> Node {
  builtin_gi_context(ao_value, gi_value, node=self)
}
