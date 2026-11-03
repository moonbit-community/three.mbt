// Upstream src/geometries/RingGeometry.js.

///|
#external
pub type RingGeometry

///|
pub fn RingGeometry::new(
  inner_radius~ : Double = 0.5,
  outer_radius~ : Double = 1.0,
  theta_segments~ : Double = 32.0,
  phi_segments~ : Double = 1.0,
  theta_start~ : Double = 0.0,
  theta_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let geometry = new_geometry("RingGeometry", {
    "innerRadius": @math.json_number(inner_radius),
    "outerRadius": @math.json_number(outer_radius),
    "thetaSegments": @math.json_number(theta_segments),
    "phiSegments": @math.json_number(phi_segments),
    "thetaStart": @math.json_number(theta_start),
    "thetaLength": @math.json_number(theta_length),
  })
  let theta_segments = js_math_max(3.0, theta_segments)
  let phi_segments = js_math_max(1.0, phi_segments)
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // some helper variables
  let mut radius = inner_radius
  let radius_step = (outer_radius - inner_radius) / phi_segments
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let uv = @math.Vector2::new(0.0, 0.0)
  // generate vertices, normals and uvs
  for j = 0.0; j <= phi_segments; j = j + 1.0 {
    for i = 0.0; i <= theta_segments; i = i + 1.0 {
      // values are generate from the inside of the ring to the outside
      let segment = theta_start + i / theta_segments * theta_length
      // vertex
      vertex.x = radius * @cmath.cos(segment)
      vertex.y = radius * @cmath.sin(segment)
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // normal
      push3(normals, 0.0, 0.0, 1.0)
      // uv
      uv.x = (vertex.x / outer_radius + 1.0) / 2.0
      uv.y = (vertex.y / outer_radius + 1.0) / 2.0
      push2(uvs, uv.x, uv.y)
    }
    // increase the radius for next row of vertices
    radius += radius_step
  }
  // indices
  for j = 0.0; j < phi_segments; j = j + 1.0 {
    let theta_segment_level = j * (theta_segments + 1.0)
    for i = 0.0; i < theta_segments; i = i + 1.0 {
      let segment = i + theta_segment_level
      let a = segment
      let b = segment + theta_segments + 1.0
      let c = segment + theta_segments + 2.0
      let d = segment + 1.0
      // faces
      push3(indices, a, b, d)
      push3(indices, b, c, d)
    }
  }
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
pub fn RingGeometry::from_json(data : Json) -> @core.BufferGeometry {
  RingGeometry::new(
    inner_radius?=json_number(data, "innerRadius"),
    outer_radius?=json_number(data, "outerRadius"),
    theta_segments?=json_number(data, "thetaSegments"),
    phi_segments?=json_number(data, "phiSegments"),
    theta_start?=json_number(data, "thetaStart"),
    theta_length?=json_number(data, "thetaLength"),
  )
}
