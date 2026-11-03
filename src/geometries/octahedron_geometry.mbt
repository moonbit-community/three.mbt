// Upstream src/geometries/OctahedronGeometry.js.

///|
#external
pub type OctahedronGeometry

///|
pub fn OctahedronGeometry::new(
  radius~ : Double = 1.0,
  detail~ : Double = 0.0,
) -> @core.BufferGeometry {
  let vertices = [
    1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, -1.0, 0.0, 0.0, 0.0, 1.0,
    0.0, 0.0, -1.0,
  ]
  let indices = [
    0.0, 2.0, 4.0, 0.0, 4.0, 3.0, 0.0, 3.0, 5.0, 0.0, 5.0, 2.0, 1.0, 2.0, 5.0, 1.0,
    5.0, 3.0, 1.0, 3.0, 4.0, 1.0, 4.0, 2.0,
  ]
  polyhedron_subclass("OctahedronGeometry", vertices, indices, radius, detail)
}

///|
pub fn OctahedronGeometry::from_json(data : Json) -> @core.BufferGeometry {
  OctahedronGeometry::new(
    radius?=json_number(data, "radius"),
    detail?=json_number(data, "detail"),
  )
}
