// Upstream src/geometries/CircleGeometry.js.

///|
#external
pub type CircleGeometry

///|
pub fn CircleGeometry::new(
  radius~ : Double = 1.0,
  segments~ : Double = 32.0,
  theta_start~ : Double = 0.0,
  theta_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let geometry = new_geometry("CircleGeometry", {
    "radius": @math.json_number(radius),
    "segments": @math.json_number(segments),
    "thetaStart": @math.json_number(theta_start),
    "thetaLength": @math.json_number(theta_length),
  })
  let segments = js_math_max(3.0, segments)
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let uv = @math.Vector2::new(0.0, 0.0)
  // center point
  push3(vertices, 0.0, 0.0, 0.0)
  push3(normals, 0.0, 0.0, 1.0)
  push2(uvs, 0.5, 0.5)
  for s = 0.0, i = 3; s <= segments; s = s + 1.0, i = i + 3 {
    let segment = theta_start + s / segments * theta_length
    // vertex
    vertex.x = radius * @cmath.cos(segment)
    vertex.y = radius * @cmath.sin(segment)
    push3(vertices, vertex.x, vertex.y, vertex.z)
    // normal
    push3(normals, 0.0, 0.0, 1.0)
    // uvs
    uv.x = (vertices[i] / radius + 1.0) / 2.0
    uv.y = (vertices[i + 1] / radius + 1.0) / 2.0
    push2(uvs, uv.x, uv.y)
  }
  // indices
  for i = 1.0; i <= segments; i = i + 1.0 {
    push3(indices, i, i + 1.0, 0.0)
  }
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
pub fn CircleGeometry::from_json(data : Json) -> @core.BufferGeometry {
  CircleGeometry::new(
    radius?=json_number(data, "radius"),
    segments?=json_number(data, "segments"),
    theta_start?=json_number(data, "thetaStart"),
    theta_length?=json_number(data, "thetaLength"),
  )
}
