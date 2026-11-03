// Upstream src/geometries/PlaneGeometry.js.

///|
#external
pub type PlaneGeometry

///|
pub fn PlaneGeometry::new(
  width~ : Double = 1.0,
  height~ : Double = 1.0,
  width_segments~ : Double = 1.0,
  height_segments~ : Double = 1.0,
) -> @core.BufferGeometry {
  let geometry = new_geometry("PlaneGeometry", {
    "width": @math.json_number(width),
    "height": @math.json_number(height),
    "widthSegments": @math.json_number(width_segments),
    "heightSegments": @math.json_number(height_segments),
  })
  let width_half = width / 2.0
  let height_half = height / 2.0
  let grid_x = width_segments.floor()
  let grid_y = height_segments.floor()
  let grid_x1 = grid_x + 1.0
  let grid_y1 = grid_y + 1.0
  let segment_width = width / grid_x
  let segment_height = height / grid_y
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  for iy = 0.0; iy < grid_y1; iy = iy + 1.0 {
    let y = iy * segment_height - height_half
    for ix = 0.0; ix < grid_x1; ix = ix + 1.0 {
      let x = ix * segment_width - width_half
      push3(vertices, x, -y, 0.0)
      push3(normals, 0.0, 0.0, 1.0)
      uvs.push(ix / grid_x)
      uvs.push(1.0 - iy / grid_y)
    }
  }
  for iy = 0.0; iy < grid_y; iy = iy + 1.0 {
    for ix = 0.0; ix < grid_x; ix = ix + 1.0 {
      let a = ix + grid_x1 * iy
      let b = ix + grid_x1 * (iy + 1.0)
      let c = ix + 1.0 + grid_x1 * (iy + 1.0)
      let d = ix + 1.0 + grid_x1 * iy
      push3(indices, a, b, d)
      push3(indices, b, c, d)
    }
  }
  buffers.apply(geometry)
  geometry
}

///|
pub fn PlaneGeometry::from_json(data : Json) -> @core.BufferGeometry {
  PlaneGeometry::new(
    width?=json_number(data, "width"),
    height?=json_number(data, "height"),
    width_segments?=json_number(data, "widthSegments"),
    height_segments?=json_number(data, "heightSegments"),
  )
}
