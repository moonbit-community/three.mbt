// Upstream src/objects/LineSegments.js. The stepping is in `hook_line_raycast`.

///|
let _line_segments_start : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _line_segments_end : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// `new LineSegments( geometry, material )`.
#external
pub type LineSegments

///|
pub fn LineSegments::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
) -> Object3D {
  line_make(geometry, material, LineSegments, "LineSegments")
}

///|
/// The `LineSegments` override of `computeLineDistances`.
fn line_segments_compute_line_distances(line : Line) -> Unit {
  let geometry = line.geometry
  // we assume non-indexed geometry
  if geometry.index is None {
    guard geometry.attributes.get("position") is Some(position_attribute) else {
      abort(
        "LineSegments.computeLineDistances: geometry has no position attribute",
      )
    }
    let line_distances : Array[Double] = []
    for i = 0; i < position_attribute.count(); i = i + 2 {
      ignore(_line_segments_start.from_buffer_attribute(position_attribute, i))
      ignore(
        _line_segments_end.from_buffer_attribute(position_attribute, i + 1),
      )
      let previous = if i == 0 { 0.0 } else { line_distances[i - 1] }
      line_distances.push(previous)
      line_distances.push(
        previous + _line_segments_start.distance_to(_line_segments_end),
      )
    }
    ignore(
      geometry.set_attribute(
        "lineDistance",
        Float32BufferAttribute::new(line_distances, 1),
      ),
    )
  } else {
    warn(
      "LineSegments.computeLineDistances(): Computation only possible with non-indexed BufferGeometry.",
    )
  }
}
