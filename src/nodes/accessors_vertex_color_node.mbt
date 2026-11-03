// nodes/accessors/VertexColorNode.js: the `color`, `color1`, ... attribute, white when
// the geometry lacks it.

///|
pub(all) struct VertexColorNode {
  attribute_node : AttributeNode
  mut index : Int32
}

///|
pub impl NodeClass for VertexColorNode with fn class_name(_) {
  "VertexColorNode"
}

///|
pub impl NodeClass for VertexColorNode with fn parent(self) {
  Some(self.attribute_node)
}

///|
pub impl NodeClass for VertexColorNode with fn has_flag(self, flag) {
  flag == "isVertexColorNode" || self.attribute_node.has_flag(flag)
}

///|
pub impl NodeClass for VertexColorNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let attribute_name = self.get_attribute_name(node, Some(builder))
  let geometry_attribute = builder.has_geometry_attribute(attribute_name)
  if geometry_attribute {
    self.attribute_node.generate(node, builder, output)
  } else {
    Some(
      builder.generate_const(
        node.node_type.unwrap_or("null"),
        value=Vector4(@math.Vector4::new(1.0, 1.0, 1.0, 1.0)),
      ),
    )
  }
}

///|
pub impl NodeClass for VertexColorNode with fn serialize(self, node, data) {
  self.attribute_node.serialize(node, data)
  data.set("index", @core.JsValue::of(self.index))
}

///|
pub impl NodeClass for VertexColorNode with fn deserialize(self, node, data) {
  self.attribute_node.deserialize(node, data)
  self.index = data.get("index").cast()
}

///|
pub impl AttributeNodeClass for VertexColorNode with fn attribute_parent(self) {
  Some(self.attribute_node)
}

///|
pub impl AttributeNodeClass for VertexColorNode with fn get_attribute_name(
  self,
  _,
  _,
) {
  let index = self.index
  "color" + (if index > 0 { index.to_string() } else { "" })
}

///|
/// `new VertexColorNode( index )`.
pub fn VertexColorNode::new(index : Int32) -> Node {
  let node = Node::alloc(node_type="vec4")
  // `super( null, 'vec4' )`: the attribute name comes from `getAttributeName`.
  let attribute_node = AttributeNode::construct(node, "")
  let v = VertexColorNode::{ attribute_node, index, }
  attribute_node.class_ = v
  node.set_class(v)
}

///|
pub fn VertexColorNode::of(node : Node) -> VertexColorNode? {
  match node.class_payload("VertexColorNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `vertexColor( index = 0 )`.
pub fn vertex_color(index~ : Int32 = 0) -> Node {
  VertexColorNode::new(index)
}
