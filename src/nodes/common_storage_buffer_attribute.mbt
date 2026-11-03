// renderers/common/StorageBufferAttribute.js: a core `BufferAttribute` of kind
// `StorageAttribute`.

///|
/// Marker for `StorageBufferAttribute`; `new` returns a core `BufferAttribute`.
#external
pub type StorageBufferAttribute

///|
/// `new StorageBufferAttribute( count, itemSize, typeClass = Float32Array )`.
pub fn StorageBufferAttribute::new(
  count : Int32,
  item_size : Int32,
  type_class~ : @math.TypedArrayKind = Float32Array,
) -> @core.BufferAttribute {
  StorageBufferAttribute::from_array(
    @core.TypedArray::new(type_class, count * item_size),
    item_size,
  )
}

///|
/// `new StorageBufferAttribute( array, itemSize )` with a typed array.
pub fn StorageBufferAttribute::from_array(
  array : @core.TypedArray,
  item_size : Int32,
) -> @core.BufferAttribute {
  let attribute = @core.BufferAttribute::new(array, item_size)
  attribute.kind = StorageAttribute
  attribute
}

///|
/// `attribute.isStorageBufferAttribute` (also true for indirect storage attributes).
pub fn is_storage_buffer_attribute(attribute : @core.BufferAttribute) -> Bool {
  attribute.kind is StorageAttribute
}
