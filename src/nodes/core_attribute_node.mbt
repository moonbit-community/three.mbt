// nodes/core/AttributeNode.js. `getAttributeName`, overridden by VertexColorNode,
// dispatches through `AttributeNodeClass`.

///|
/// Virtual methods of the `AttributeNode` family.
pub(open) trait AttributeNodeClass {
  /// The superclass payload in the family, `None` for `AttributeNode`.
  fn attribute_parent(Self) -> &AttributeNodeClass? = _
  /// `getAttributeName( builder )`.
  fn get_attribute_name(Self, Node, NodeBuilder?) -> String = _
}

///|
impl AttributeNodeClass with fn attribute_parent(_) {
  None
}

///|
impl AttributeNodeClass with fn get_attribute_name(self, node, builder) {
  match self.attribute_parent() {
    Some(p) => p.get_attribute_name(node, builder)
    None => attribute_node_payload(node)._attribute_name
  }
}

///|
pub(all) struct AttributeNode {
  mut _attribute_name : String
  /// The most derived payload of the family, set at the end of construction.
  mut class_ : &AttributeNodeClass
}

///|
priv struct AttributeNodeUnset {}

///|
impl AttributeNodeClass for AttributeNodeUnset

///|
pub impl AttributeNodeClass for AttributeNode

///|
pub impl NodeClass for AttributeNode with fn class_name(_) {
  "AttributeNode"
}

///|
pub impl NodeClass for AttributeNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for AttributeNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for AttributeNode with fn get_hash(self, node, builder) {
  self.class_.get_attribute_name(node, Some(builder))
}

///|
pub impl NodeClass for AttributeNode with fn get_shared(_, node, builder) {
  match AttributeNode::get_context_attribute(node, builder) {
    Some(n) => n
    None => node.get_shared_base(builder)
  }
}

///|
pub impl NodeClass for AttributeNode with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  match AttributeNode::get_context_attribute(node, builder) {
    Some(context_attribute) => return context_attribute.get_node_type(builder)
    None => ()
  }
  match node.node_type {
    Some(t) => Some(t)
    None => {
      let attribute_name = self.class_.get_attribute_name(node, Some(builder))
      if builder.has_geometry_attribute(attribute_name) {
        let attribute = attribute_node_geometry_attribute(
          builder, attribute_name,
        )
        Some(builder.get_type_from_attribute(attribute))
      } else {
        Some("float")
      }
    }
  }
}

///|
pub impl NodeClass for AttributeNode with fn generate(self, node, builder, _) {
  let attribute_name = self.class_.get_attribute_name(node, Some(builder))
  let node_type = node.get_node_type(builder)
  let geometry_attribute = builder.has_geometry_attribute(attribute_name)
  if geometry_attribute {
    let attribute = attribute_node_geometry_attribute(builder, attribute_name)
    let attribute_type = builder.get_type_from_attribute(attribute)
    let node_attribute = builder.get_attribute(attribute_name, attribute_type)
    if builder.shader_stage == Some("vertex") {
      Some(builder.format(node_attribute.name, Some(attribute_type), node_type))
    } else {
      let node_varying = varying(node)
      Some(node_varying.build(builder, output?=node_type))
    }
  } else {
    @core.warn(
      "AttributeNode: Vertex attribute \"\{attribute_name}\" not found on geometry.",
    )
    Some(builder.generate_const(node_type.unwrap_or("null")))
  }
}

///|
pub impl NodeClass for AttributeNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("global", @core.JsValue::of(node.global))
  data.set("_attributeName", @core.JsValue::of(self._attribute_name))
}

///|
pub impl NodeClass for AttributeNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  node.global = data.get("global").cast()
  self._attribute_name = data.get("_attributeName").cast()
}

///|
pub fn AttributeNode::construct(
  node : Node,
  attribute_name : String,
) -> AttributeNode {
  node.global = true
  { _attribute_name: attribute_name, class_: AttributeNodeUnset::{ }, }
}

///|
/// `new AttributeNode( attributeName, nodeType = null )`.
pub fn AttributeNode::new(attribute_name : String, node_type? : String) -> Node {
  let node = Node::alloc(node_type?)
  let attribute = AttributeNode::construct(node, attribute_name)
  attribute.class_ = attribute
  node.set_class(attribute)
}

///|
pub fn AttributeNode::of(node : Node) -> AttributeNode? {
  match node.class_payload("AttributeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn attribute_node_payload(node : Node) -> AttributeNode {
  match AttributeNode::of(node) {
    Some(a) => a
    None => abort("AttributeNode: \{node.type_()} is not an AttributeNode")
  }
}

///|
/// `getAttributeName( builder )`, dispatched to the most derived class.
pub fn AttributeNode::get_attribute_name(
  node : Node,
  builder? : NodeBuilder,
) -> String {
  attribute_node_payload(node).class_.get_attribute_name(node, builder)
}

///|
/// `setAttributeName( attributeName )`, chained.
pub fn Node::set_attribute_name(self : Node, attribute_name : String) -> Node {
  attribute_node_payload(self)._attribute_name = attribute_name
  self
}

///|
/// The `getAttribute( name, builder )` callback of `builder.context`.
pub(all) struct ContextGetAttribute {
  f : (String, NodeBuilder) -> Node?
}

///|
/// `builder.context.getAttribute`, if set.
pub fn NodeContext::get_attribute(self : NodeContext) -> ContextGetAttribute? {
  match self.get("getAttribute") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `getContextAttribute( builder )`: the node `context.getAttribute` gives, or `null`.
pub fn AttributeNode::get_context_attribute(
  node : Node,
  builder : NodeBuilder,
) -> Node? {
  match builder.context.get_attribute() {
    Some(get_attribute) =>
      (get_attribute.f)(
        AttributeNode::get_attribute_name(node, builder~),
        builder,
      )
    None => None
  }
}

///|
/// `builder.geometry.getAttribute( name )`.
fn attribute_node_geometry_attribute(
  builder : NodeBuilder,
  name : String,
) -> @core.GeometryAttribute {
  builder.geometry.unwrap().get_attribute(name).unwrap()
}

///|
/// `attribute( name, nodeType = null )`.
pub fn attribute(name : String, node_type? : String) -> Node {
  AttributeNode::new(name, node_type?)
}
