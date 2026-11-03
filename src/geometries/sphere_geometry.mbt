// Upstream src/geometries/SphereGeometry.js.

///|
#external
pub type SphereGeometry

///|
pub fn SphereGeometry::new(
  radius~ : Double = 1.0,
  width_segments~ : Double = 32.0,
  height_segments~ : Double = 16.0,
  phi_start~ : Double = 0.0,
  phi_length~ : Double = _geometry_two_pi,
  theta_start~ : Double = 0.0,
  theta_length~ : Double = _geometry_pi,
) -> @core.BufferGeometry {
  let geometry = new_geometry("SphereGeometry", {
    "radius": @math.json_number(radius),
    "widthSegments": @math.json_number(width_segments),
    "heightSegments": @math.json_number(height_segments),
    "phiStart": @math.json_number(phi_start),
    "phiLength": @math.json_number(phi_length),
    "thetaStart": @math.json_number(theta_start),
    "thetaLength": @math.json_number(theta_length),
  })
  let width_segments = js_math_max(3.0, width_segments.floor())
  let height_segments = js_math_max(2.0, height_segments.floor())
  let theta_end = js_math_min(theta_start + theta_length, _geometry_pi)
  let mut index = 0.0
  let grid : Array[Array[Double]] = []
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // generate vertices, normals and uvs
  for iy = 0.0; iy <= height_segments; iy = iy + 1.0 {
    let vertices_row = []
    let v = iy / height_segments
    let theta = theta_start + v * theta_length
    let y = radius * @cmath.cos(theta)
    let ring_radius = (radius * radius - y * y).sqrt()
    // special case for the poles
    let mut u_offset = 0.0
    if iy == 0.0 && theta_start == 0.0 {
      u_offset = 0.5 / width_segments
    } else if iy == height_segments && theta_end == _geometry_pi {
      u_offset = -0.5 / width_segments
    }
    for ix = 0.0; ix <= width_segments; ix = ix + 1.0 {
      let u = ix / width_segments
      let phi = phi_start + u * phi_length
      // vertex
      vertex.x = -ring_radius * @cmath.cos(phi)
      vertex.y = y
      vertex.z = ring_radius * @cmath.sin(phi)
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // normal
      normal.copy(vertex).normalize() |> ignore
      push3(normals, normal.x, normal.y, normal.z)
      // uv
      push2(uvs, u + u_offset, 1.0 - v)
      vertices_row.push(index)
      index += 1.0
    }
    grid.push(vertices_row)
  }
  // indices
  for iy = 0.0; iy < height_segments; iy = iy + 1.0 {
    for ix = 0.0; ix < width_segments; ix = ix + 1.0 {
      let row = iy.to_int()
      let column = ix.to_int()
      let a = grid[row][column + 1]
      let b = grid[row][column]
      let c = grid[row + 1][column]
      let d = grid[row + 1][column + 1]
      if iy != 0.0 || theta_start > 0.0 {
        push3(indices, a, b, d)
      }
      if iy != height_segments - 1.0 || theta_end < _geometry_pi {
        push3(indices, b, c, d)
      }
    }
  }
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
pub fn SphereGeometry::from_json(data : Json) -> @core.BufferGeometry {
  SphereGeometry::new(
    radius?=json_number(data, "radius"),
    width_segments?=json_number(data, "widthSegments"),
    height_segments?=json_number(data, "heightSegments"),
    phi_start?=json_number(data, "phiStart"),
    phi_length?=json_number(data, "phiLength"),
    theta_start?=json_number(data, "thetaStart"),
    theta_length?=json_number(data, "thetaLength"),
  )
}
