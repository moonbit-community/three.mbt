// renderers/common/IndirectStorageBufferAttribute.js: a storage attribute with a
// `Uint32Array`, flagged in a side table (core has no kind for it).

///|
let _indirect_storage_buffer_attributes : @webgl.WeakMap[
  @core.BufferAttribute,
  Bool,
] = @webgl.WeakMap::new()

///|
/// Marker for `IndirectStorageBufferAttribute`; `new` returns a core `BufferAttribute`.
#external
pub type IndirectStorageBufferAttribute

///|
/// `new IndirectStorageBufferAttribute( count, itemSize )`.
pub fn IndirectStorageBufferAttribute::new(
  count : Int32,
  item_size : Int32,
) -> @core.BufferAttribute {
  let attribute = StorageBufferAttribute::new(
    count,
    item_size,
    type_class=Uint32Array,
  )
  _indirect_storage_buffer_attributes.set(attribute, true)
  attribute
}

///|
/// `new IndirectStorageBufferAttribute( array, itemSize )` with a typed array.
pub fn IndirectStorageBufferAttribute::from_array(
  array : @core.TypedArray,
  item_size : Int32,
) -> @core.BufferAttribute {
  let attribute = StorageBufferAttribute::from_array(array, item_size)
  _indirect_storage_buffer_attributes.set(attribute, true)
  attribute
}

///|
/// `attribute.isIndirectStorageBufferAttribute`.
pub fn is_indirect_storage_buffer_attribute(
  attribute : @core.BufferAttribute,
) -> Bool {
  _indirect_storage_buffer_attributes.has(attribute)
}
