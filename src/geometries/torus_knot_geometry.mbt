// Upstream src/geometries/TorusKnotGeometry.js.

///|
#external
pub type TorusKnotGeometry

///|
/// Calculates the current position on the torus curve.
fn calculate_position_on_curve(
  u : Double,
  p : Double,
  q : Double,
  radius : Double,
  position : @math.Vector3,
) -> Unit {
  let cu = @cmath.cos(u)
  let su = @cmath.sin(u)
  let qu_over_p = q / p * u
  let cs = @cmath.cos(qu_over_p)
  position.x = radius * (2.0 + cs) * 0.5 * cu
  position.y = radius * (2.0 + cs) * su * 0.5
  position.z = radius * @cmath.sin(qu_over_p) * 0.5
}

///|
pub fn TorusKnotGeometry::new(
  radius~ : Double = 1.0,
  tube~ : Double = 0.4,
  tubular_segments~ : Double = 64.0,
  radial_segments~ : Double = 8.0,
  p~ : Double = 2.0,
  q~ : Double = 3.0,
) -> @core.BufferGeometry {
  let geometry = new_geometry("TorusKnotGeometry", {
    "radius": @math.json_number(radius),
    "tube": @math.json_number(tube),
    "tubularSegments": @math.json_number(tubular_segments),
    "radialSegments": @math.json_number(radial_segments),
    "p": @math.json_number(p),
    "q": @math.json_number(q),
  })
  let tubular_segments = tubular_segments.floor()
  let radial_segments = radial_segments.floor()
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let p1 = @math.Vector3::new(0.0, 0.0, 0.0)
  let p2 = @math.Vector3::new(0.0, 0.0, 0.0)
  let b = @math.Vector3::new(0.0, 0.0, 0.0)
  let t = @math.Vector3::new(0.0, 0.0, 0.0)
  let n = @math.Vector3::new(0.0, 0.0, 0.0)
  // generate vertices, normals and uvs
  for i = 0.0; i <= tubular_segments; i = i + 1.0 {
    // the radian "u" is used to calculate the position on the torus curve of the current tubular segment
    let u = i / tubular_segments * p * _geometry_pi * 2.0
    // now we calculate two points. P1 is our current position on the curve, P2 is a little farther ahead.
    // these points are used to create a special "coordinate space", which is necessary to calculate the correct vertex positions
    calculate_position_on_curve(u, p, q, radius, p1)
    calculate_position_on_curve(u + 0.01, p, q, radius, p2)
    // calculate orthonormal basis
    t.sub_vectors(p2, p1) |> ignore
    n.add_vectors(p2, p1) |> ignore
    b.cross_vectors(t, n) |> ignore
    n.cross_vectors(b, t) |> ignore
    // normalize B, N. T can be ignored, we don't use it
    b.normalize() |> ignore
    n.normalize() |> ignore
    for j = 0.0; j <= radial_segments; j = j + 1.0 {
      // now calculate the vertices. they are nothing more than an extrusion of the torus curve.
      // because we extrude a shape in the xy-plane, there is no need to calculate a z-value.
      let v = j / radial_segments * _geometry_pi * 2.0
      let cx = -tube * @cmath.cos(v)
      let cy = tube * @cmath.sin(v)
      // now calculate the final vertex position.
      // first we orient the extrusion with our basis vectors, then we add it to the current position on the curve
      vertex.x = p1.x + (cx * n.x + cy * b.x)
      vertex.y = p1.y + (cx * n.y + cy * b.y)
      vertex.z = p1.z + (cx * n.z + cy * b.z)
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // normal (P1 is always the center/origin of the extrusion, thus we can use it to calculate the normal)
      normal.sub_vectors(vertex, p1).normalize() |> ignore
      push3(normals, normal.x, normal.y, normal.z)
      // uv
      uvs.push(i / tubular_segments)
      uvs.push(j / radial_segments)
    }
  }
  // generate indices
  for j = 1.0; j <= tubular_segments; j = j + 1.0 {
    for i = 1.0; i <= radial_segments; i = i + 1.0 {
      // indices
      let a = (radial_segments + 1.0) * (j - 1.0) + (i - 1.0)
      let b = (radial_segments + 1.0) * j + (i - 1.0)
      let c = (radial_segments + 1.0) * j + i
      let d = (radial_segments + 1.0) * (j - 1.0) + i
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
pub fn TorusKnotGeometry::from_json(data : Json) -> @core.BufferGeometry {
  TorusKnotGeometry::new(
    radius?=json_number(data, "radius"),
    tube?=json_number(data, "tube"),
    tubular_segments?=json_number(data, "tubularSegments"),
    radial_segments?=json_number(data, "radialSegments"),
    p?=json_number(data, "p"),
    q?=json_number(data, "q"),
  )
}
