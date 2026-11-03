// Upstream src/geometries/DodecahedronGeometry.js.

///|
#external
pub type DodecahedronGeometry

///|
pub fn DodecahedronGeometry::new(
  radius~ : Double = 1.0,
  detail~ : Double = 0.0,
) -> @core.BufferGeometry {
  let t = (1.0 + (5.0 : Double).sqrt()) / 2.0
  let r = 1.0 / t
  let vertices = [
    // (±1, ±1, ±1)
    -1.0,
    -1.0,
    -1.0,
    -1.0,
    -1.0,
    1.0,
    -1.0,
    1.0,
    -1.0,
    -1.0,
    1.0,
    1.0,
    1.0,
    -1.0,
    -1.0,
    1.0,
    -1.0,
    1.0,
    1.0,
    1.0,
    -1.0,
    1.0,
    1.0,
    1.0,
    // (0, ±1/φ, ±φ)
    0.0,
    -r,
    -t,
    0.0,
    -r,
    t,
    0.0,
    r,
    -t,
    0.0,
    r,
    t,
    // (±1/φ, ±φ, 0)
    -r,
    -t,
    0.0,
    -r,
    t,
    0.0,
    r,
    -t,
    0.0,
    r,
    t,
    0.0,
    // (±φ, 0, ±1/φ)
    -t,
    0.0,
    -r,
    t,
    0.0,
    -r,
    -t,
    0.0,
    r,
    t,
    0.0,
    r,
  ]
  let indices = [
    3.0, 11.0, 7.0, 3.0, 7.0, 15.0, 3.0, 15.0, 13.0, 7.0, 19.0, 17.0, 7.0, 17.0,
    6.0, 7.0, 6.0, 15.0, 17.0, 4.0, 8.0, 17.0, 8.0, 10.0, 17.0, 10.0, 6.0, 8.0, 0.0,
    16.0, 8.0, 16.0, 2.0, 8.0, 2.0, 10.0, 0.0, 12.0, 1.0, 0.0, 1.0, 18.0, 0.0, 18.0,
    16.0, 6.0, 10.0, 2.0, 6.0, 2.0, 13.0, 6.0, 13.0, 15.0, 2.0, 16.0, 18.0, 2.0,
    18.0, 3.0, 2.0, 3.0, 13.0, 18.0, 1.0, 9.0, 18.0, 9.0, 11.0, 18.0, 11.0, 3.0,
    4.0, 14.0, 12.0, 4.0, 12.0, 0.0, 4.0, 0.0, 8.0, 11.0, 9.0, 5.0, 11.0, 5.0, 19.0,
    11.0, 19.0, 7.0, 19.0, 5.0, 14.0, 19.0, 14.0, 4.0, 19.0, 4.0, 17.0, 1.0, 12.0,
    14.0, 1.0, 14.0, 5.0, 1.0, 5.0, 9.0,
  ]
  polyhedron_subclass("DodecahedronGeometry", vertices, indices, radius, detail)
}

///|
pub fn DodecahedronGeometry::from_json(data : Json) -> @core.BufferGeometry {
  DodecahedronGeometry::new(
    radius?=json_number(data, "radius"),
    detail?=json_number(data, "detail"),
  )
}
