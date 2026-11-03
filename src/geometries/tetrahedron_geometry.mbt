// Upstream src/geometries/TetrahedronGeometry.js.

///|
#external
pub type TetrahedronGeometry

///|
pub fn TetrahedronGeometry::new(
  radius~ : Double = 1.0,
  detail~ : Double = 0.0,
) -> @core.BufferGeometry {
  let vertices = [
    1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0,
  ]
  let indices = [2.0, 1.0, 0.0, 0.0, 3.0, 2.0, 1.0, 3.0, 0.0, 2.0, 3.0, 1.0]
  polyhedron_subclass("TetrahedronGeometry", vertices, indices, radius, detail)
}

///|
pub fn TetrahedronGeometry::from_json(data : Json) -> @core.BufferGeometry {
  TetrahedronGeometry::new(
    radius?=json_number(data, "radius"),
    detail?=json_number(data, "detail"),
  )
}
