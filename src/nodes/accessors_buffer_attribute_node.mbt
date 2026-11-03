// nodes/accessors/BufferAttributeNode.js: a geometry-independent vertex attribute from
// a typed array, an interleaved buffer or a buffer attribute. The family method
// `getObjectAttribute`, overridden by ReferenceBufferAttributeNode, dispatches through
// `BufferAttributeNodeClass`.

///|
/// What a buffer attribute node reads: `value`.
pub(all) enum BufferAttributeValue {
  /// `null` (ReferenceBufferAttributeNode).
  NoValue
  /// A `BufferAttribute` or an `InterleavedBufferAttribute`.
  Attribute(@core.GeometryAttribute)
  Interleaved(@core.InterleavedBuffer)
  /// A typed array.
  Array(@core.TypedArray)
}

///|
/// The values `bufferAttribute( array, ... )` accepts.
pub(open) trait IntoBufferAttributeValue {
  fn to_buffer_attribute_value(Self) -> BufferAttributeValue
}

///|
pub impl IntoBufferAttributeValue for BufferAttributeValue with fn to_buffer_attribute_value(
  self,
) {
  self
}

///|
pub impl IntoBufferAttributeValue for @core.BufferAttribute with fn to_buffer_attribute_value(
  self,
) {
  Attribute(Buffer(self))
}

///|
pub impl IntoBufferAttributeValue for @core.InterleavedBufferAttribute with fn to_buffer_attribute_value(
  self,
) {
  Attribute(Interleaved(self))
}

///|
pub impl IntoBufferAttributeValue for @core.GeometryAttribute with fn to_buffer_attribute_value(
  self,
) {
  Attribute(self)
}

///|
pub impl IntoBufferAttributeValue for @core.InterleavedBuffer with fn to_buffer_attribute_value(
  self,
) {
  Interleaved(self)
}

///|
pub impl IntoBufferAttributeValue for @core.TypedArray with fn to_buffer_attribute_value(
  self,
) {
  Array(self)
}

///|
/// A buffer attribute passes to TSL functions as itself (`instance( matrices, colors )`).
pub impl IntoTsl for @core.BufferAttribute with fn to_tsl(self) {
  Js(@core.JsValue::of(self))
}

///|
/// The JS identity of a value (the key of `globalCache.getData( value )`).
fn buffer_attribute_value_js(value : BufferAttributeValue) -> @core.JsValue {
  match value {
    NoValue => @core.JsValue::null()
    Attribute(Buffer(a)) => @core.JsValue::of(a)
    Attribute(Interleaved(a)) => @core.JsValue::of(a)
    Attribute(GL(a)) => @core.JsValue::of(a)
    Interleaved(b) => @core.JsValue::of(b)
    Array(a) => @core.JsValue::of(a)
  }
}

///|
/// `_bufferLib`: typed array -> the `InterleavedBuffer` made for it.
let _buffer_attribute_node_buffer_lib : @webgl.WeakMap[
  @core.TypedArray,
  @core.InterleavedBuffer,
] = @webgl.WeakMap::new()

///|
/// `_getBufferAttribute( value, itemSize )`.
fn buffer_attribute_node_get_buffer(
  value : @core.TypedArray,
  item_size : Int32,
) -> @core.InterleavedBuffer {
  match _buffer_attribute_node_buffer_lib.get(value) {
    Some(b) => b
    None => {
      let b = @core.InterleavedBuffer::new(value, item_size)
      _buffer_attribute_node_buffer_lib.set(value, b)
      b
    }
  }
}

///|
/// `globalCache.getData( value )` / `setData( value, { node } )`: per global cache,
/// the first node built for a value.
let _buffer_attribute_node_global_data : @webgl.WeakMap[
  NodeCache,
  @webgl.WeakMap[@core.JsValue, Node],
] = @webgl.WeakMap::new()

///|
/// `bufferData.node` of `getHash`: the node registered for `value` in the global
/// cache, registering `node` first.
pub fn buffer_attribute_global_node(
  builder : NodeBuilder,
  value : @core.JsValue,
  node : Node,
) -> Node {
  let data = match
    _buffer_attribute_node_global_data.get(builder.global_cache) {
    Some(d) => d
    None => {
      let d = @webgl.WeakMap::new()
      _buffer_attribute_node_global_data.set(builder.global_cache, d)
      d
    }
  }
  match data.get(value) {
    Some(n) => n
    None => {
      data.set(value, node)
      node
    }
  }
}

///|
/// `attribute.isInstancedBufferAttribute = this.instanced` for the interleaved
/// attributes buffer attribute nodes create (core's type has no such field).
let _buffer_attribute_node_instanced : @webgl.WeakMap[
  @core.InterleavedBufferAttribute,
  Bool,
] = @webgl.WeakMap::new()

///|
/// `attribute.isInstancedBufferAttribute`.
pub fn buffer_attribute_is_instanced(
  attribute : @core.GeometryAttribute,
) -> Bool {
  match attribute {
    Buffer(a) => a.kind is (InstancedAttribute | StorageInstancedAttribute)
    Interleaved(a) => _buffer_attribute_node_instanced.get(a) == Some(true)
    GL(_) => false
  }
}

///|
/// Virtual methods of the `BufferAttributeNode` family.
pub(open) trait BufferAttributeNodeClass {
  fn buffer_attribute_parent(Self) -> &BufferAttributeNodeClass? = _
  /// `getObjectAttribute( object )`.
  fn get_object_attribute(Self, Node, BuilderObject) -> @core.GeometryAttribute? = _
}

///|
impl BufferAttributeNodeClass with fn buffer_attribute_parent(_) {
  None
}

///|
impl BufferAttributeNodeClass with fn get_object_attribute(self, node, object) {
  match self.buffer_attribute_parent() {
    Some(p) => p.get_object_attribute(node, object)
    None => buffer_attribute_node_payload(node).attribute
  }
}

///|
pub(all) struct BufferAttributeNode {
  input : InputNode
  mut buffer_value : BufferAttributeValue
  mut buffer_type : String?
  mut buffer_stride : Int32
  mut buffer_offset : Int32
  mut usage : Int32
  mut instanced : Bool
  mut attribute : @core.GeometryAttribute?
  mut class_ : &BufferAttributeNodeClass
}

///|
priv struct BufferAttributeNodeUnset {}

///|
impl BufferAttributeNodeClass for BufferAttributeNodeUnset

///|
pub impl BufferAttributeNodeClass for BufferAttributeNode

///|
pub impl NodeClass for BufferAttributeNode with fn class_name(_) {
  "BufferAttributeNode"
}

///|
pub impl NodeClass for BufferAttributeNode with fn parent(self) {
  Some(self.input)
}

///|
pub impl NodeClass for BufferAttributeNode with fn has_flag(self, flag) {
  flag == "isBufferNode" || self.input.has_flag(flag)
}

///|
pub impl NodeClass for BufferAttributeNode with fn get_hash(self, node, builder) {
  let id = if self.buffer_stride == 0 && self.buffer_offset == 0 {
    buffer_attribute_global_node(
      builder,
      buffer_attribute_value_js(self.buffer_value),
      node,
    ).id
  } else {
    node.id
  }
  id.to_string()
}

///|
pub impl NodeClass for BufferAttributeNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  if self.buffer_type is None {
    self.buffer_type = Some(
      builder.get_type_from_attribute(self.attribute.unwrap()),
    )
  }
  self.buffer_type
}

///|
pub impl NodeClass for BufferAttributeNode with fn setup(self, node, builder) {
  BufferAttributeNode::setup_base(self, node, builder)
  None
}

///|
pub impl NodeClass for BufferAttributeNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for BufferAttributeNode with fn generate(_, node, builder, _) {
  let node_type = node.get_node_type(builder)
  let node_name = match builder.context.get("nodeName") {
    String(s) => Some(s)
    _ => None
  }
  if !(builder.context.get("nodeName") is Undefined) {
    // deleting when consumed
    builder.context.delete("nodeName")
  }
  let node_attribute = builder.get_buffer_attribute_from_node(
    node,
    node_type.unwrap_or("null"),
    name?=node_name,
  )
  let property_name = builder.get_property_name(Attribute(node_attribute))
  if builder.shader_stage == Some("vertex") ||
    builder.shader_stage == Some("compute") {
    node.name = Some(property_name)
    Some(property_name)
  } else {
    let varying_name = match node_name {
      Some(n) if n != "" => Some(n + "Varying")
      _ => None
    }
    let node_varying = varying(node, name?=varying_name)
    Some(node_varying.build(builder, output?=node_type))
  }
}

///|
pub impl InputNodeClass for BufferAttributeNode with fn input_parent(self) {
  Some(self.input)
}

///|
pub impl InputNodeClass for BufferAttributeNode with fn get_input_type(_, _, _) {
  Some("bufferAttribute")
}

///|
/// BufferAttributeNode's `setup( builder )`.
pub fn BufferAttributeNode::setup_base(
  self : BufferAttributeNode,
  node : Node,
  builder : NodeBuilder,
) -> Unit {
  if self.attribute is Some(_) {
    return
  }
  let type_ = node.get_node_type(builder)
  let item_size = builder.get_type_length(type_)
  let value = self.buffer_value
  let stride = if self.buffer_stride != 0 {
    self.buffer_stride
  } else {
    item_size
  }
  let offset = self.buffer_offset
  let buffer = match value {
    Interleaved(b) => b
    Attribute(Buffer(a)) => buffer_attribute_node_get_buffer(a.array, stride)
    Array(a) => buffer_attribute_node_get_buffer(a, stride)
    _ => abort("TypeError: BufferAttributeNode value has no array")
  }
  let buffer_attribute = @core.InterleavedBufferAttribute::new(
    buffer, item_size, offset,
  )
  buffer.set_usage(self.usage) |> ignore
  self.attribute = Some(Interleaved(buffer_attribute))
  // @TODO: Add a possible: InstancedInterleavedBufferAttribute
  _buffer_attribute_node_instanced.set(buffer_attribute, self.instanced)
}

///|
/// The constructor body: `super( value, bufferType )` has run in `Node::alloc`.
pub fn BufferAttributeNode::construct(
  node : Node,
  value : BufferAttributeValue,
  buffer_type : String?,
  buffer_stride : Int32,
  buffer_offset : Int32,
) -> BufferAttributeNode {
  let input = InputNode::construct(node, Js(buffer_attribute_value_js(value)))
  node.global = true
  let (usage, instanced, attribute) = match value {
    Attribute(Buffer(a)) if a.item_size <= 4 =>
      (
        a.usage,
        a.kind is (InstancedAttribute | StorageInstancedAttribute),
        Some(@core.GeometryAttribute::Buffer(a)),
      )
    Attribute(Interleaved(a)) =>
      (a.data.usage, false, Some(@core.GeometryAttribute::Interleaved(a)))
    _ => (@core.StaticDrawUsage, false, None)
  }
  {
    input,
    buffer_value: value,
    buffer_type,
    buffer_stride,
    buffer_offset,
    usage,
    instanced,
    attribute,
    class_: BufferAttributeNodeUnset::{ },
  }
}

///|
/// `new BufferAttributeNode( value, bufferType = null, bufferStride = 0,
/// bufferOffset = 0 )`.
pub fn BufferAttributeNode::new(
  value : &IntoBufferAttributeValue,
  buffer_type? : String,
  buffer_stride~ : Int32 = 0,
  buffer_offset~ : Int32 = 0,
) -> Node {
  let node = Node::alloc(node_type?=buffer_type)
  let b = BufferAttributeNode::construct(
    node,
    value.to_buffer_attribute_value(),
    buffer_type,
    buffer_stride,
    buffer_offset,
  )
  b.class_ = b
  b.input.class_ = b
  node.set_class(b)
}

///|
pub fn BufferAttributeNode::of(node : Node) -> BufferAttributeNode? {
  match node.class_payload("BufferAttributeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn buffer_attribute_node_payload(node : Node) -> BufferAttributeNode {
  match BufferAttributeNode::of(node) {
    Some(b) => b
    None => abort("TypeError: \{node.type_()} is not a BufferAttributeNode")
  }
}

///|
/// `setUsage( value )`, chained.
pub fn Node::set_usage(self : Node, value : Int32) -> Node {
  let b = buffer_attribute_node_payload(self)
  b.usage = value
  match b.attribute {
    Some(Buffer(a)) => a.usage = value
    _ => ()
  }
  self
}

///|
/// `setInstanced( value )`, chained.
pub fn Node::set_instanced(self : Node, value : Bool) -> Node {
  buffer_attribute_node_payload(self).instanced = value
  self
}

///|
/// `getObjectAttribute( object )`, dispatched to the most derived class.
pub fn BufferAttributeNode::get_object_attribute(
  node : Node,
  object : BuilderObject,
) -> @core.GeometryAttribute? {
  buffer_attribute_node_payload(node).class_.get_object_attribute(node, object)
}

///|
/// `createBufferAttribute( array, type, stride, offset, usage, instanced )`.
fn buffer_attribute_node_create(
  array : BufferAttributeValue,
  type_ : String?,
  stride : Int32,
  offset : Int32,
  usage : Int32,
  instanced : Bool,
) -> Node {
  let item_size = match array {
    Attribute(Buffer(a)) => Some(a.item_size)
    Attribute(Interleaved(a)) => Some(a.item_size)
    _ => None
  }
  if type_ == Some("mat3") || (type_ is None && item_size == Some(9)) {
    return mat3_of(
      [0, 3, 6].map(fn(o) {
        BufferAttributeNode::new(
          array,
          buffer_type="vec3",
          buffer_stride=9,
          buffer_offset=o,
        )
        .set_usage(usage)
        .set_instanced(instanced)
      }),
    )
  } else if type_ == Some("mat4") || (type_ is None && item_size == Some(16)) {
    return mat4_of(
      [0, 4, 8, 12].map(fn(o) {
        BufferAttributeNode::new(
          array,
          buffer_type="vec4",
          buffer_stride=16,
          buffer_offset=o,
        )
        .set_usage(usage)
        .set_instanced(instanced)
      }),
    )
  }
  BufferAttributeNode::new(
    array,
    buffer_type?=type_,
    buffer_stride=stride,
    buffer_offset=offset,
  ).set_usage(usage)
}

///|
/// `bufferAttribute( array, type = null, stride = 0, offset = 0 )`.
pub fn buffer_attribute(
  array : &IntoBufferAttributeValue,
  type_? : String,
  stride~ : Int32 = 0,
  offset~ : Int32 = 0,
) -> Node {
  buffer_attribute_node_create(
    array.to_buffer_attribute_value(),
    type_,
    stride,
    offset,
    @core.StaticDrawUsage,
    false,
  )
}

///|
/// `dynamicBufferAttribute( array, type = null, stride = 0, offset = 0 )`.
pub fn dynamic_buffer_attribute(
  array : &IntoBufferAttributeValue,
  type_? : String,
  stride~ : Int32 = 0,
  offset~ : Int32 = 0,
) -> Node {
  buffer_attribute_node_create(
    array.to_buffer_attribute_value(),
    type_,
    stride,
    offset,
    @core.DynamicDrawUsage,
    false,
  )
}

///|
/// `instancedBufferAttribute( array, type = null, stride = 0, offset = 0 )`.
pub fn instanced_buffer_attribute(
  array : &IntoBufferAttributeValue,
  type_? : String,
  stride~ : Int32 = 0,
  offset~ : Int32 = 0,
) -> Node {
  buffer_attribute_node_create(
    array.to_buffer_attribute_value(),
    type_,
    stride,
    offset,
    @core.StaticDrawUsage,
    true,
  )
}

///|
/// `instancedDynamicBufferAttribute( array, type = null, stride = 0, offset = 0 )`.
pub fn instanced_dynamic_buffer_attribute(
  array : &IntoBufferAttributeValue,
  type_? : String,
  stride~ : Int32 = 0,
  offset~ : Int32 = 0,
) -> Node {
  buffer_attribute_node_create(
    array.to_buffer_attribute_value(),
    type_,
    stride,
    offset,
    @core.DynamicDrawUsage,
    true,
  )
}

///|
/// `toAttribute()`, chained on a buffer node: `bufferAttribute( value, bufferType )`.
pub fn Node::to_attribute(self : Node) -> Node {
  let value : BufferAttributeValue = match StorageBufferNode::of(self) {
    Some(s) => Attribute(Buffer(s.storage_attribute))
    None =>
      match InputNode::get_value(self) {
        Js(v) => Array(v.cast())
        _ => NoValue
      }
  }
  let buffer_type = match BufferNode::of(self) {
    Some(b) => b.buffer_type
    None => None
  }
  buffer_attribute(value, type_?=buffer_type)
}
