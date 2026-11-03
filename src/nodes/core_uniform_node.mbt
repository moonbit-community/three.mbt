// nodes/core/UniformNode.js

///|
pub(all) struct UniformNode {
  input : InputNode
  /// The `UniformGroupNode` (default `objectGroup`).
  mut group_node : Node
}

///|
pub impl NodeClass for UniformNode with fn class_name(_) {
  "UniformNode"
}

///|
pub impl NodeClass for UniformNode with fn parent(self) {
  Some(self.input)
}

///|
pub impl NodeClass for UniformNode with fn has_flag(self, flag) {
  flag == "isUniformNode" || self.input.has_flag(flag)
}

///|
pub impl NodeClass for UniformNode with fn children(self, node, out) {
  self.input.children(node, out)
  push_child(out, "groupNode", Some(self.group_node))
}

///|
pub impl NodeClass for UniformNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for UniformNode with fn set_name(_, node, name) {
  node.name = Some(name)
  Some(node)
}

///|
pub impl NodeClass for UniformNode with fn label(_, node, name) {
  @core.warn("TSL: \"label()\" has been deprecated. Use \"setName()\" instead.")
  Some(node.set_name(name))
}

///|
pub impl NodeClass for UniformNode with fn on_update(
  self,
  node,
  callback,
  update_type,
) {
  let wrapped = fn(n : Node, frame : NodeFrame) -> Bool? {
    let value = callback(n, frame)
    if value is Some(v) {
      InputNode::set_value(n, Bool(v))
    }
    None
  }
  match self.input.on_update(node, wrapped, update_type) {
    Some(n) => Some(n)
    None => Some(node.on_update_base(wrapped, update_type))
  }
}

///|
pub impl NodeClass for UniformNode with fn generate(_, node, builder, output) {
  let type_ = node.get_node_type(builder)
  let shared_node = UniformNode::get_shared_node(node, builder)
  let shared_node_type = InputNode::get_input_type(shared_node, builder)
  let name = match node.name {
    Some(n) if n != "" => Some(n)
    _ =>
      match builder.context.get("nodeName") {
        String(s) => Some(s)
        _ => None
      }
  }
  let node_uniform = builder.get_uniform_from_node(
    shared_node,
    shared_node_type.unwrap_or("null"),
    shader_stage?=builder.shader_stage,
    name?,
  )
  let uniform_name = builder.get_property_name(Uniform(node_uniform))
  if !(builder.context.get("nodeName") is Undefined) {
    builder.context.delete("nodeName")
  }
  let mut snippet = uniform_name
  if type_ == Some("bool") {
    let node_data = builder.get_data_from_node(node)
    let property_name = match node_data.property_name {
      Some(p) => p
      None => {
        let node_var = builder.get_var_from_node(
          node,
          None,
          Some("bool"),
          None,
          false,
          false,
          "variable",
        )
        let property_name = builder.get_property_name(Var(node_var))
        node_data.property_name = Some(property_name)
        snippet = builder.format(uniform_name, shared_node_type, type_)
        builder.add_line_flow_code("\{property_name} = \{snippet}", node~)
        |> ignore
        property_name
      }
    }
    snippet = property_name
  }
  Some(builder.format(snippet, type_, output))
}

///|
pub impl InputNodeClass for UniformNode with fn input_parent(self) {
  Some(self.input)
}

///|
pub impl InputNodeClass for UniformNode with fn get_input_type(
  self,
  node,
  builder,
) {
  let type_ = InputNodeClass::get_input_type(self.input, node, builder)
  if type_ == Some("bool") {
    Some("uint")
  } else {
    type_
  }
}

///|
pub impl InputNodeClass for UniformNode with fn get_uniform_hash(
  _,
  node,
  builder,
) {
  node.get_hash(builder)
}

///|
pub fn UniformNode::construct(node : Node, value : TslValue) -> UniformNode {
  let input = InputNode::construct(node, value)
  node.name = Some("")
  { input, group_node: object_group, }
}

///|
/// `new UniformNode( value, nodeType = null )`.
pub fn UniformNode::new(value : TslValue, node_type? : String) -> Node {
  let node = Node::alloc(node_type?)
  let uniform = UniformNode::construct(node, value)
  uniform.input.class_ = uniform
  node.set_class(uniform)
}

///|
pub fn UniformNode::of(node : Node) -> UniformNode? {
  match node.class_payload("UniformNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn uniform_node_payload(node : Node, method_name : String) -> UniformNode {
  match UniformNode::of(node) {
    Some(u) => u
    None => abort("\{method_name}: \{node.type_()} is not a UniformNode")
  }
}

///|
/// `setGroup( group )`, chained.
pub fn Node::set_group(self : Node, group : Node) -> Node {
  uniform_node_payload(self, "setGroup").group_node = group
  self
}

///|
/// `getGroup()`.
pub fn Node::get_group(self : Node) -> Node {
  uniform_node_payload(self, "getGroup").group_node
}

///|
/// `getUniformHash( builder )`, dispatched to the most derived class.
pub fn UniformNode::get_uniform_hash(
  node : Node,
  builder : NodeBuilder,
) -> String {
  uniform_node_payload(node, "getUniformHash").input.class_.get_uniform_hash(
    node, builder,
  )
}

///|
/// `getSharedNode( builder )`: the first uniform node built with this hash.
pub fn UniformNode::get_shared_node(node : Node, builder : NodeBuilder) -> Node {
  let hash = UniformNode::get_uniform_hash(node, builder)
  match builder.get_node_from_hash(hash) {
    Some(shared_node) => shared_node
    None => {
      builder.set_hash_node(node, hash)
      node
    }
  }
}

///|
/// `uniform( value, type )`.
pub fn uniform(value : &IntoTsl, type_? : String) -> Node {
  let mut value = value.to_tsl()
  let node_type = get_const_node_type(
    match type_ {
      Some(t) if t != "" => String(t)
      _ => value
    },
  )
  if node_type is Some(t) && value is String(s) && s == t {
    value = get_value_from_type(node_type, [])
  }
  if value is Node(n) {
    let mut v = InputNode::of(n).map(fn(i) { i.value }).unwrap_or(Undefined)
    n.traverse(fn(c) {
      if c.has_flag("isConstNode") {
        v = InputNode::get_value(c)
      }
    })
    value = v
  }
  UniformNode::new(value, node_type?)
}
