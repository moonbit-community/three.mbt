// nodes/core/VaryingNode.js

///|
/// Computes its node in the vertex stage and passes it to the fragment stage.
pub(all) struct VaryingNode {
  mut node : Node
  mut interpolation_type : String?
  mut interpolation_sampling : String?
}

///|
pub impl NodeClass for VaryingNode with fn class_name(_) {
  "VaryingNode"
}

///|
pub impl NodeClass for VaryingNode with fn has_flag(_, flag) {
  flag == "isVaryingNode"
}

///|
pub impl NodeClass for VaryingNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for VaryingNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for VaryingNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for VaryingNode with fn get_hash(_, node, builder) {
  match node.name {
    Some(name) if name != "" => name
    _ => node.get_hash_base(builder)
  }
}

///|
pub impl NodeClass for VaryingNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.node.get_node_type(builder)
}

///|
pub impl NodeClass for VaryingNode with fn setup(self, node, builder) {
  if builder.context.get_bool("inlineVaryings") == Some(true) &&
    builder.shader_stage == Some("fragment") {
    let mut inner = self.node
    while SubBuildNode::of(inner) is Some(sub) {
      inner = sub.node
    }
    if !inner.has_flag("isIndexNode") &&
      (
        !inner.has_flag("isAttributeNode") ||
        AttributeNode::get_context_attribute(inner, builder) is Some(_)
      ) {
      return Some(self.node)
    }
  }
  VaryingNode::setup_varying(node, builder) |> ignore
  builder.flow_node_from_shader_stage(node_shader_stage_vertex, self.node)
  |> ignore
  None
}

///|
pub impl NodeClass for VaryingNode with fn analyze(self, node, builder, _) {
  if builder.get_node_properties(node).get_node("outputNode") is Some(_) {
    return node.analyze_base(builder, None)
  }
  VaryingNode::setup_varying(node, builder) |> ignore
  builder.flow_node_from_shader_stage(node_shader_stage_vertex, self.node)
  |> ignore
}

///|
pub impl NodeClass for VaryingNode with fn generate(_, node, builder, _) {
  let properties = builder.get_node_properties(node)
  if properties.get_node("outputNode") is Some(output_node) {
    return Some(output_node.build(builder, output?=node.get_node_type(builder)))
  }
  let property_key = builder.get_sub_build_property(property="property")
  let varying = VaryingNode::setup_varying(node, builder)
  let flow_block = if builder.shader_stage == Some(node_shader_stage_vertex) {
    builder.flow_block
  } else {
    None
  }
  let same = match (properties.get(property_key), flow_block) {
    (Some(Null), None) => true
    (Some(Other(v)), Some(b)) => {
      let stored : FlowBlock = v.cast()
      physical_equal(stored, b)
    }
    _ => false
  }
  if !same {
    let type_ = node.get_node_type(builder)
    let property_name = builder.get_property_name(
      Varying(varying),
      shader_stage=node_shader_stage_vertex,
    )
    let vertex_node = properties.get_node("node").unwrap()
    if builder.shader_stage == Some(node_shader_stage_vertex) {
      let snippet = vertex_node.build(builder, output?=type_)
      builder.add_line_flow_code("\{property_name} = \{snippet}", node~)
      |> ignore
    } else {
      builder.flow_node_from_shader_stage(
        node_shader_stage_vertex,
        vertex_node,
        output?=type_,
        property_name~,
      )
      |> ignore
    }
    properties.set(
      property_key,
      match flow_block {
        Some(b) => Other(@core.JsValue::of(b))
        None => Null
      },
    )
  }
  Some(builder.get_property_name(Varying(varying)))
}

///|
pub fn VaryingNode::construct(
  node : Node,
  input_node : Node,
  name : String?,
) -> VaryingNode {
  let varying = VaryingNode::{
    node: sub_build(input_node, "VERTEX"),
    interpolation_type: None,
    interpolation_sampling: None,
  }
  node.name = name
  node.global = true
  varying
}

///|
/// `new VaryingNode( node, name = null )`.
pub fn VaryingNode::new(node : Node, name? : String) -> Node {
  let this = Node::alloc()
  this.set_class(VaryingNode::construct(this, node, name))
}

///|
pub fn VaryingNode::of(node : Node) -> VaryingNode? {
  match node.class_payload("VaryingNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn varying_node_payload(node : Node, method_name : String) -> VaryingNode {
  match VaryingNode::of(node) {
    Some(v) => v
    None => abort("\{method_name}: \{node.type_()} is not a VaryingNode")
  }
}

///|
/// `setInterpolation( type, sampling = null )`, chained.
pub fn Node::set_interpolation(
  self : Node,
  type_ : String,
  sampling? : String,
) -> Node {
  let varying = varying_node_payload(self, "setInterpolation")
  varying.interpolation_type = Some(type_)
  varying.interpolation_sampling = sampling
  self
}

///|
/// `setupVarying( builder )`: the `NodeVarying` of this node, created once.
pub fn VaryingNode::setup_varying(
  node : Node,
  builder : NodeBuilder,
) -> NodeVarying {
  let self_ = varying_node_payload(node, "setupVarying")
  let properties = builder.get_node_properties(node)
  let varying : NodeVarying = match properties.get("varying") {
    Some(Other(v)) => v.cast()
    _ => {
      let name = node.name
      let type_ = node.get_node_type(builder)
      let interpolation_type = self_.interpolation_type
      let interpolation_sampling = self_.interpolation_sampling
      let varying = builder.get_varying_from_node(
        node,
        name?,
        type_?,
        interpolation_type?,
        interpolation_sampling?,
      )
      properties.set("varying", Other(@core.JsValue::of(varying)))
      properties.set_node("node", sub_build(self_.node, "VERTEX"))
      varying
    }
  }
  if !varying.needs_interpolation {
    varying.needs_interpolation = builder.shader_stage == Some("fragment")
  }
  varying
}

///|
/// `varying( node, name = null )`.
pub fn varying(node : &IntoTsl, name? : String) -> Node {
  VaryingNode::new(node_object(node.to_tsl()), name?)
}

///|
/// `vertexStage( node )`.
pub fn vertex_stage(node : &IntoTsl) -> Node {
  varying(node)
}

///|
/// `toVarying( name )`.
pub fn Node::to_varying(self : Node, name? : String) -> Node {
  varying(self, name?)
}

///|
/// `toVertexStage()`.
pub fn Node::to_vertex_stage(self : Node) -> Node {
  vertex_stage(self)
}
