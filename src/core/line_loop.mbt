// Upstream src/objects/LineLoop.js. The closing segment is in `hook_line_raycast`.

///|
/// `new LineLoop( geometry, material )`.
#external
pub type LineLoop

///|
pub fn LineLoop::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
) -> Object3D {
  line_make(geometry, material, LineLoop, "LineLoop")
}
