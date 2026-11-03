// Upstream src/geometries/TorusGeometry.js.

///|
#external
pub type TorusGeometry

///|
pub fn TorusGeometry::new(
  radius~ : Double = 1.0,
  tube~ : Double = 0.4,
  radial_segments~ : Double = 12.0,
  tubular_segments~ : Double = 48.0,
  arc~ : Double = _geometry_two_pi,
  theta_start~ : Double = 0.0,
  theta_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let geometry = new_geometry("TorusGeometry", {
    "radius": @math.json_number(radius),
    "tube": @math.json_number(tube),
    "radialSegments": @math.json_number(radial_segments),
    "tubularSegments": @math.json_number(tubular_segments),
    "arc": @math.json_number(arc),
    "thetaStart": @math.json_number(theta_start),
    "thetaLength": @math.json_number(theta_length),
  })
  let radial_segments = radial_segments.floor()
  let tubular_segments = tubular_segments.floor()
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let center = @math.Vector3::new(0.0, 0.0, 0.0)
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  // generate vertices, normals and uvs
  for j = 0.0; j <= radial_segments; j = j + 1.0 {
    let v = theta_start + j / radial_segments * theta_length
    for i = 0.0; i <= tubular_segments; i = i + 1.0 {
      let u = i / tubular_segments * arc
      // vertex
      vertex.x = (radius + tube * @cmath.cos(v)) * @cmath.cos(u)
      vertex.y = (radius + tube * @cmath.cos(v)) * @cmath.sin(u)
      vertex.z = tube * @cmath.sin(v)
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // normal
      center.x = radius * @cmath.cos(u)
      center.y = radius * @cmath.sin(u)
      normal.sub_vectors(vertex, center).normalize() |> ignore
      push3(normals, normal.x, normal.y, normal.z)
      // uv
      uvs.push(i / tubular_segments)
      uvs.push(j / radial_segments)
    }
  }
  // generate indices
  for j = 1.0; j <= radial_segments; j = j + 1.0 {
    for i = 1.0; i <= tubular_segments; i = i + 1.0 {
      // indices
      let a = (tubular_segments + 1.0) * j + i - 1.0
      let b = (tubular_segments + 1.0) * (j - 1.0) + i - 1.0
      let c = (tubular_segments + 1.0) * (j - 1.0) + i
      let d = (tubular_segments + 1.0) * j + i
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
pub fn TorusGeometry::from_json(data : Json) -> @core.BufferGeometry {
  TorusGeometry::new(
    radius?=json_number(data, "radius"),
    tube?=json_number(data, "tube"),
    radial_segments?=json_number(data, "radialSegments"),
    tubular_segments?=json_number(data, "tubularSegments"),
    arc?=json_number(data, "arc"),
    theta_start?=json_number(data, "thetaStart"),
    theta_length?=json_number(data, "thetaLength"),
  )
}
