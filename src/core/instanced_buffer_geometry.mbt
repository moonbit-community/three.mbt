// Upstream src/core/InstancedBufferGeometry.js. The data sits in `BufferGeometry`, whose
// `copy`, `clone` and `to_json` handle it.

///|
/// `new InstancedBufferGeometry()`.
#external
pub type InstancedBufferGeometry

///|
pub fn InstancedBufferGeometry::new() -> BufferGeometry {
  let geometry = BufferGeometry::new()
  geometry.type_ = "InstancedBufferGeometry"
  geometry.is_instanced_buffer_geometry = true
  geometry
}
