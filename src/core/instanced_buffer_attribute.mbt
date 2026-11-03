// Upstream src/core/InstancedBufferAttribute.js. The data sits in `BufferAttribute`
// (`kind`, `mesh_per_attribute`); `copy`, `clone` and `to_json` handle it there.

///|
/// `new InstancedBufferAttribute( array, itemSize, normalized, meshPerAttribute )`.
#external
pub type InstancedBufferAttribute

///|
pub fn InstancedBufferAttribute::new(
  array : TypedArray,
  item_size : Int32,
  normalized~ : Bool = false,
  mesh_per_attribute~ : Int32 = 1,
) -> BufferAttribute {
  buffer_attribute_make(
    array,
    item_size,
    normalized,
    InstancedAttribute,
    mesh_per_attribute,
  )
}
