// Upstream src/extras/Earcut.js. The algorithm is in earcut_lib.mbt.

///|
#external
pub type Earcut

///|
/// Triangulates the given shape definition by returning an array of triangles.
pub fn Earcut::triangulate(
  data : Array[Double],
  hole_indices : Array[Int32],
  dim~ : Int32 = 2,
) -> Array[Int32] {
  earcut(data, hole_indices, dim~)
}
