// Upstream src/geometries/IcosahedronGeometry.js.

///|
#external
pub type IcosahedronGeometry

///|
pub fn IcosahedronGeometry::new(
  radius~ : Double = 1.0,
  detail~ : Double = 0.0,
) -> @core.BufferGeometry {
  let t = (1.0 + (5.0 : Double).sqrt()) / 2.0
  let vertices = [
    -1.0,
    t,
    0.0,
    1.0,
    t,
    0.0,
    -1.0,
    -t,
    0.0,
    1.0,
    -t,
    0.0,
    0.0,
    -1.0,
    t,
    0.0,
    1.0,
    t,
    0.0,
    -1.0,
    -t,
    0.0,
    1.0,
    -t,
    t,
    0.0,
    -1.0,
    t,
    0.0,
    1.0,
    -t,
    0.0,
    -1.0,
    -t,
    0.0,
    1.0,
  ]
  let indices = [
    0.0, 11.0, 5.0, 0.0, 5.0, 1.0, 0.0, 1.0, 7.0, 0.0, 7.0, 10.0, 0.0, 10.0, 11.0,
    1.0, 5.0, 9.0, 5.0, 11.0, 4.0, 11.0, 10.0, 2.0, 10.0, 7.0, 6.0, 7.0, 1.0, 8.0,
    3.0, 9.0, 4.0, 3.0, 4.0, 2.0, 3.0, 2.0, 6.0, 3.0, 6.0, 8.0, 3.0, 8.0, 9.0, 4.0,
    9.0, 5.0, 2.0, 4.0, 11.0, 6.0, 2.0, 10.0, 8.0, 6.0, 7.0, 9.0, 8.0, 1.0,
  ]
  polyhedron_subclass("IcosahedronGeometry", vertices, indices, radius, detail)
}

///|
pub fn IcosahedronGeometry::from_json(data : Json) -> @core.BufferGeometry {
  IcosahedronGeometry::new(
    radius?=json_number(data, "radius"),
    detail?=json_number(data, "detail"),
  )
}
