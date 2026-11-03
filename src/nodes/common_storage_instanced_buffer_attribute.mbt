// renderers/common/StorageInstancedBufferAttribute.js: a core `BufferAttribute` of kind
// `StorageInstancedAttribute`.

///|
/// Marker for `StorageInstancedBufferAttribute`; `new` returns a core `BufferAttribute`.
#external
pub type StorageInstancedBufferAttribute

///|
/// `new StorageInstancedBufferAttribute( count, itemSize, typeClass = Float32Array )`.
pub fn StorageInstancedBufferAttribute::new(
  count : Int32,
  item_size : Int32,
  type_class~ : @math.TypedArrayKind = Float32Array,
) -> @core.BufferAttribute {
  StorageInstancedBufferAttribute::from_array(
    @core.TypedArray::new(type_class, count * item_size),
    item_size,
  )
}

///|
/// `new StorageInstancedBufferAttribute( array, itemSize )` with a typed array.
pub fn StorageInstancedBufferAttribute::from_array(
  array : @core.TypedArray,
  item_size : Int32,
) -> @core.BufferAttribute {
  let attribute = @core.InstancedBufferAttribute::new(array, item_size)
  attribute.kind = StorageInstancedAttribute
  attribute
}

///|
/// `attribute.isStorageInstancedBufferAttribute`.
pub fn is_storage_instanced_buffer_attribute(
  attribute : @core.BufferAttribute,
) -> Bool {
  attribute.kind is StorageInstancedAttribute
}
