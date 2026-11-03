// nodes/accessors/ReferenceAttributeNode.js: a vertex attribute read from a property of
// the rendered object (`instanceMatrix`, `instanceColor`, ...), so one shader serves
// every object. `getValueFromReference`, overridden by PreviousInstanceMatrixNode,
// dispatches through `ReferenceAttributeNodeClass`.

///|
/// `_columns`: attribute -> offset -> the interleaved column attribute.
let _reference_attribute_columns : @webgl.WeakMap[
  @core.BufferAttribute,
  Map[Int32, @core.InterleavedBufferAttribute],
] = @webgl.WeakMap::new()

///|
/// `getAttributeColumn( attribute, type, offset )`. Upstream passes the attribute as
/// the interleaved buffer; here an `InterleavedBuffer` shares its array, with the item
/// size as the stride.
fn reference_attribute_get_column(
  attribute : @core.BufferAttribute,
  type_ : String,
  offset : Int32,
) -> @core.InterleavedBufferAttribute {
  let columns = match _reference_attribute_columns.get(attribute) {
    Some(c) => c
    None => {
      let c = {}
      _reference_attribute_columns.set(attribute, c)
      c
    }
  }
  match columns.get(offset) {
    Some(c) => c
    None => {
      let buffer = attribute_interleaved_buffer(attribute)
      let c = @core.InterleavedBufferAttribute::new(
        buffer,
        get_length_from_type(type_),
        offset,
      )
      columns.set(offset, c)
      c
    }
  }
}

///|
/// The interleaved buffer standing for a buffer attribute that upstream passes as the
/// `data` of an `InterleavedBufferAttribute` (instance matrix columns): one per
/// attribute, so all its columns share one GPU buffer as upstream's do.
pub fn attribute_interleaved_buffer(
  attribute : @core.BufferAttribute,
) -> @core.InterleavedBuffer {
  match _attribute_interleaved_buffers.get(attribute) {
    Some(b) => b
    None => {
      let b = @core.InterleavedBuffer::new(attribute.array, attribute.item_size)
      b.usage = attribute.usage
      b.is_instanced_interleaved_buffer = attribute.kind
        is (InstancedAttribute | StorageInstancedAttribute)
      _attribute_interleaved_buffers.set(attribute, b)
      _attribute_interleaved_sources.set(b, attribute)
      @webgl.set_interleaved_buffer_source(b, attribute)
      b
    }
  }
}

///|
let _attribute_interleaved_buffers : @webgl.WeakMap[
  @core.BufferAttribute,
  @core.InterleavedBuffer,
] = @webgl.WeakMap::new()

///|
let _attribute_interleaved_sources : @webgl.WeakMap[
  @core.InterleavedBuffer,
  @core.BufferAttribute,
] = @webgl.WeakMap::new()

///|
/// The buffer attribute an `attribute_interleaved_buffer` stands for.
pub fn attribute_interleaved_source(
  buffer : @core.InterleavedBuffer,
) -> @core.BufferAttribute? {
  _attribute_interleaved_sources.get(buffer)
}

///|
/// `interleavedBufferAttribute.data` as an attribute buffer: the buffer attribute an
/// `attribute_interleaved_buffer` stands for, else the interleaved buffer.
pub fn interleaved_attribute_buffer(
  attribute : @core.InterleavedBufferAttribute,
) -> AttributeBuffer {
  match attribute_interleaved_source(attribute.data) {
    Some(source) => Buffer(source)
    None => Interleaved(attribute.data)
  }
}

///|
/// Virtual methods of the `ReferenceAttributeNode` family.
pub(open) trait ReferenceAttributeNodeClass {
  fn reference_attribute_parent(Self) -> &ReferenceAttributeNodeClass? = _
  /// `getValueFromReference( object )`.
  fn get_value_from_reference(Self, Node, @core.Object3D?) -> @core.BufferAttribute? = _
}

///|
impl ReferenceAttributeNodeClass with fn reference_attribute_parent(_) {
  None
}

///|
impl ReferenceAttributeNodeClass with fn get_value_from_reference(
  self,
  node,
  object,
) {
  match self.reference_attribute_parent() {
    Some(p) => p.get_value_from_reference(node, object)
    None =>
      match object {
        Some(o) =>
          reference_attribute_object_value(
            o,
            reference_attribute_node_payload(node).properties[:],
          )
        None => None
      }
  }
}

///|
/// A property path of an object that names a buffer attribute.
fn reference_attribute_object_value(
  object : @core.Object3D,
  properties : ArrayView[String],
) -> @core.BufferAttribute? {
  match (object.kind, properties) {
    (Mesh({ kind: InstancedMesh(m), .. }), ["instanceMatrix"]) =>
      Some(m.instance_matrix)
    (Mesh({ kind: InstancedMesh(m), .. }), ["instanceColor"]) =>
      m.instance_color
    (_, ["geometry", "attributes", name]) =>
      match object.get_geometry() {
        Some(g) =>
          match g.get_attribute(name) {
            Some(Buffer(a)) => Some(a)
            _ => None
          }
        None => None
      }
    _ => None
  }
}

///|
pub(all) struct ReferenceAttributeNode {
  property : String
  properties : Array[String]
  object : @core.Object3D?
  mut class_ : &ReferenceAttributeNodeClass
}

///|
priv struct ReferenceAttributeNodeUnset {}

///|
impl ReferenceAttributeNodeClass for ReferenceAttributeNodeUnset

///|
pub impl ReferenceAttributeNodeClass for ReferenceAttributeNode

///|
pub impl NodeClass for ReferenceAttributeNode with fn class_name(_) {
  "ReferenceAttributeNode"
}

///|
pub impl NodeClass for ReferenceAttributeNode with fn generate_node_type(
  _,
  node,
  builder,
  _,
) {
  if node.node_type is Some(_) {
    return node.node_type
  }
  match ReferenceAttributeNode::get_attribute(node, builder_object(builder)) {
    Some(attribute) => Some(builder.get_type_from_attribute(Buffer(attribute)))
    None => Some("float")
  }
}

///|
pub impl NodeClass for ReferenceAttributeNode with fn setup(_, node, builder) {
  let r = reference_attribute_node_payload(node)
  let attribute = match
    ReferenceAttributeNode::get_attribute(node, builder_object(builder)) {
    Some(a) => a
    None =>
      abort(
        "THREE.ReferenceAttributeNode: Attribute \"\{r.property}\" not found.",
      )
  }
  let type_ = node.get_node_type(builder).unwrap_or("float")
  if attribute.kind is (StorageAttribute | StorageInstancedAttribute) {
    let index = if attribute.kind is StorageInstancedAttribute {
      instance_index
    } else {
      vertex_index
    }
    let count = if attribute.count > 1 { attribute.count } else { 1 }
    return Some(
      storage(attribute, type_~, count~)
      .on_object_update(fn(self_, frame) {
        match ReferenceAttributeNode::get_attribute(node, frame.object) {
          Some(a) => InputNode::set_value(self_, Js(@core.JsValue::of(a)))
          None => InputNode::set_value(self_, Undefined)
        }
        None
      })
      .element(index),
    )
  }
  if type_ == "mat4" {
    return Some(
      mat4_of(
        [0, 4, 8, 12].map(fn(offset) {
          ReferenceBufferAttributeNode::new(node, "vec4", 16, offset)
        }),
      ),
    )
  } else if type_ == "mat3" {
    return Some(
      mat3_of(
        [0, 3, 6].map(fn(offset) {
          ReferenceBufferAttributeNode::new(node, "vec3", 9, offset)
        }),
      ),
    )
  }
  Some(ReferenceBufferAttributeNode::new(node, type_, 0, 0))
}

///|
/// `builder.object` as an object.
fn builder_object(builder : NodeBuilder) -> @core.Object3D? {
  match builder.object {
    Object3D(o) => Some(o)
    _ => None
  }
}

///|
/// The constructor body: `super( nodeType )` has run in `Node::alloc`.
pub fn ReferenceAttributeNode::construct(
  _node : Node,
  property : String,
  object : @core.Object3D?,
) -> ReferenceAttributeNode {
  {
    property,
    properties: property.split(".").map(fn(s) { s.to_owned() }).collect(),
    object,
    class_: ReferenceAttributeNodeUnset::{ },
  }
}

///|
/// `new ReferenceAttributeNode( property, nodeType = null, object = null )`.
pub fn ReferenceAttributeNode::new(
  property : String,
  node_type? : String,
  object? : @core.Object3D,
) -> Node {
  let node = Node::alloc(node_type?)
  let r = ReferenceAttributeNode::construct(node, property, object)
  r.class_ = r
  node.set_class(r)
}

///|
pub fn ReferenceAttributeNode::of(node : Node) -> ReferenceAttributeNode? {
  match node.class_payload("ReferenceAttributeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn reference_attribute_node_payload(node : Node) -> ReferenceAttributeNode {
  match ReferenceAttributeNode::of(node) {
    Some(r) => r
    None => abort("TypeError: \{node.type_()} is not a ReferenceAttributeNode")
  }
}

///|
/// `getAttribute( object )`: from `this.object`, or the given object.
pub fn ReferenceAttributeNode::get_attribute(
  node : Node,
  object : @core.Object3D?,
) -> @core.BufferAttribute? {
  let r = reference_attribute_node_payload(node)
  r.class_.get_value_from_reference(
    node,
    match r.object {
      Some(o) => Some(o)
      None => object
    },
  )
}

///|
/// `referenceAttribute( name, type = null, object = null )`.
pub fn reference_attribute(
  name : String,
  type_? : String,
  object? : @core.Object3D,
) -> Node {
  ReferenceAttributeNode::new(name, node_type?=type_, object?)
}

///|
/// `ReferenceBufferAttributeNode`: the attribute (or a column of it) of the rendered
/// object.
pub(all) struct ReferenceBufferAttributeNode {
  buffer_attribute : BufferAttributeNode
  reference_node : Node
}

///|
pub impl NodeClass for ReferenceBufferAttributeNode with fn class_name(_) {
  "ReferenceBufferAttributeNode"
}

///|
pub impl NodeClass for ReferenceBufferAttributeNode with fn parent(self) {
  Some(self.buffer_attribute)
}

///|
pub impl NodeClass for ReferenceBufferAttributeNode with fn has_flag(self, flag) {
  flag == "isReferenceBufferAttributeNode" ||
  self.buffer_attribute.has_flag(flag)
}

///|
pub impl NodeClass for ReferenceBufferAttributeNode with fn children(
  self,
  node,
  out,
) {
  self.buffer_attribute.children(node, out)
  push_child(out, "referenceNode", Some(self.reference_node))
}

///|
pub impl NodeClass for ReferenceBufferAttributeNode with fn get_hash(_, node, _) {
  node.id.to_string()
}

///|
pub impl NodeClass for ReferenceBufferAttributeNode with fn setup(
  self,
  node,
  builder,
) {
  self.buffer_attribute.attribute = self.get_object_attribute(
    node,
    builder.object,
  )
  None
}

///|
pub impl InputNodeClass for ReferenceBufferAttributeNode with fn input_parent(
  self,
) {
  Some(self.buffer_attribute)
}

///|
pub impl BufferAttributeNodeClass for ReferenceBufferAttributeNode with fn buffer_attribute_parent(
  self,
) {
  Some(self.buffer_attribute)
}

///|
pub impl BufferAttributeNodeClass for ReferenceBufferAttributeNode with fn get_object_attribute(
  self,
  _,
  object,
) {
  let object = match object {
    Object3D(o) => Some(o)
    _ => None
  }
  let attribute = ReferenceAttributeNode::get_attribute(
    self.reference_node,
    object,
  )
  match attribute {
    None => None
    Some(a) =>
      if self.buffer_attribute.buffer_stride == 0 {
        Some(Buffer(a))
      } else {
        Some(
          Interleaved(
            reference_attribute_get_column(
              a,
              self.buffer_attribute.buffer_type.unwrap_or("float"),
              self.buffer_attribute.buffer_offset,
            ),
          ),
        )
      }
  }
}

///|
/// `new ReferenceBufferAttributeNode( referenceNode, bufferType, bufferStride = 0,
/// bufferOffset = 0 )`.
pub fn ReferenceBufferAttributeNode::new(
  reference_node : Node,
  buffer_type : String,
  buffer_stride : Int32,
  buffer_offset : Int32,
) -> Node {
  let node = Node::alloc(node_type=buffer_type)
  let buffer_attribute = BufferAttributeNode::construct(
    node,
    NoValue,
    Some(buffer_type),
    buffer_stride,
    buffer_offset,
  )
  let r = ReferenceBufferAttributeNode::{ buffer_attribute, reference_node, }
  buffer_attribute.class_ = r
  buffer_attribute.input.class_ = r
  node.set_class(r)
}

///|
pub fn ReferenceBufferAttributeNode::of(
  node : Node,
) -> ReferenceBufferAttributeNode? {
  match node.class_payload("ReferenceBufferAttributeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
