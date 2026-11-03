// Upstream src/geometries/CapsuleGeometry.js.

///|
#external
pub type CapsuleGeometry

///|
pub fn CapsuleGeometry::new(
  radius~ : Double = 1.0,
  height~ : Double = 1.0,
  cap_segments~ : Double = 4.0,
  radial_segments~ : Double = 8.0,
  height_segments~ : Double = 1.0,
) -> @core.BufferGeometry {
  let geometry = new_geometry("CapsuleGeometry", {
    "radius": @math.json_number(radius),
    "height": @math.json_number(height),
    "capSegments": @math.json_number(cap_segments),
    "radialSegments": @math.json_number(radial_segments),
    "heightSegments": @math.json_number(height_segments),
  })
  let height = js_math_max(0.0, height)
  let cap_segments = js_math_max(1.0, cap_segments.floor())
  let radial_segments = js_math_max(3.0, radial_segments.floor())
  let height_segments = js_math_max(1.0, height_segments.floor())
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let half_height = height / 2.0
  let cap_arc_length = _geometry_pi / 2.0 * radius
  let cylinder_part_length = height
  let total_arc_length = 2.0 * cap_arc_length + cylinder_part_length
  let num_vertical_segments = cap_segments * 2.0 + height_segments
  let vertices_per_row = radial_segments + 1.0
  let normal = @math.Vector3::new(0.0, 0.0, 0.0)
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  // generate vertices, normals, and uvs
  for iy = 0.0; iy <= num_vertical_segments; iy = iy + 1.0 {
    let mut current_arc_length = 0.0
    let mut profile_y = 0.0
    let mut profile_radius = 0.0
    let mut normal_y_component = 0.0
    if iy <= cap_segments {
      // bottom cap
      let segment_progress = iy / cap_segments
      let angle = segment_progress * _geometry_pi / 2.0
      profile_y = -half_height - radius * @cmath.cos(angle)
      profile_radius = radius * @cmath.sin(angle)
      normal_y_component = -radius * @cmath.cos(angle)
      current_arc_length = segment_progress * cap_arc_length
    } else if iy <= cap_segments + height_segments {
      // middle section
      let segment_progress = (iy - cap_segments) / height_segments
      profile_y = -half_height + segment_progress * height
      profile_radius = radius
      normal_y_component = 0.0
      current_arc_length = cap_arc_length +
        segment_progress * cylinder_part_length
    } else {
      // top cap
      let segment_progress = (iy - cap_segments - height_segments) /
        cap_segments
      let angle = segment_progress * _geometry_pi / 2.0
      profile_y = half_height + radius * @cmath.sin(angle)
      profile_radius = radius * @cmath.cos(angle)
      normal_y_component = radius * @cmath.sin(angle)
      current_arc_length = cap_arc_length +
        cylinder_part_length +
        segment_progress * cap_arc_length
    }
    let v = js_math_max(
      0.0,
      js_math_min(1.0, current_arc_length / total_arc_length),
    )
    // special case for the poles
    let mut u_offset = 0.0
    if iy == 0.0 {
      u_offset = 0.5 / radial_segments
    } else if iy == num_vertical_segments {
      u_offset = -0.5 / radial_segments
    }
    for ix = 0.0; ix <= radial_segments; ix = ix + 1.0 {
      let u = ix / radial_segments
      let theta = u * _geometry_pi * 2.0
      let sin_theta = @cmath.sin(theta)
      let cos_theta = @cmath.cos(theta)
      // vertex
      vertex.x = -profile_radius * cos_theta
      vertex.y = profile_y
      vertex.z = profile_radius * sin_theta
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // normal
      normal.set(
        -profile_radius * cos_theta,
        normal_y_component,
        profile_radius * sin_theta,
      )
      |> ignore
      normal.normalize() |> ignore
      push3(normals, normal.x, normal.y, normal.z)
      // uv
      push2(uvs, u + u_offset, v)
    }
    if iy > 0.0 {
      let prev_index_row = (iy - 1.0) * vertices_per_row
      for ix = 0.0; ix < radial_segments; ix = ix + 1.0 {
        let i1 = prev_index_row + ix
        let i2 = prev_index_row + ix + 1.0
        let i3 = iy * vertices_per_row + ix
        let i4 = iy * vertices_per_row + ix + 1.0
        push3(indices, i1, i2, i3)
        push3(indices, i2, i4, i3)
      }
    }
  }
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
pub fn CapsuleGeometry::from_json(data : Json) -> @core.BufferGeometry {
  CapsuleGeometry::new(
    radius?=json_number(data, "radius"),
    height?=json_number(data, "height"),
    cap_segments?=json_number(data, "capSegments"),
    radial_segments?=json_number(data, "radialSegments"),
    height_segments?=json_number(data, "heightSegments"),
  )
}
