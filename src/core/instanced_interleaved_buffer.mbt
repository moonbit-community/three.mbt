// Upstream src/core/InstancedInterleavedBuffer.js. The data sits in `InterleavedBuffer`,
// whose `copy`, `clone` and `to_json` handle it.

///|
/// `new InstancedInterleavedBuffer( array, stride, meshPerAttribute )`.
#external
pub type InstancedInterleavedBuffer

///|
pub fn InstancedInterleavedBuffer::new(
  array : TypedArray,
  stride : Int32,
  mesh_per_attribute~ : Int32 = 1,
) -> InterleavedBuffer {
  let buffer = InterleavedBuffer::new(array, stride)
  buffer.is_instanced_interleaved_buffer = true
  buffer.mesh_per_attribute = mesh_per_attribute
  buffer
}
