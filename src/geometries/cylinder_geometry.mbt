// Upstream src/geometries/CylinderGeometry.js.

///|
#external
pub type CylinderGeometry

///|
pub fn CylinderGeometry::new(
  radius_top~ : Double = 1.0,
  radius_bottom~ : Double = 1.0,
  height~ : Double = 1.0,
  radial_segments~ : Double = 32.0,
  height_segments~ : Double = 1.0,
  open_ended~ : Bool = false,
  theta_start~ : Double = 0.0,
  theta_length~ : Double = _geometry_two_pi,
) -> @core.BufferGeometry {
  let geometry = new_geometry("CylinderGeometry", {
    "radiusTop": @math.json_number(radius_top),
    "radiusBottom": @math.json_number(radius_bottom),
    "height": @math.json_number(height),
    "radialSegments": @math.json_number(radial_segments),
    "heightSegments": @math.json_number(height_segments),
    "openEnded": Json::boolean(open_ended),
    "thetaStart": @math.json_number(theta_start),
    "thetaLength": @math.json_number(theta_length),
  })
  let radial_segments = radial_segments.floor()
  let height_segments = height_segments.floor()
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let mut index = 0.0
  let index_array : Array[Array[Double]] = []
  let half_height = height / 2.0
  let mut group_start = 0.0
  fn generate_torso() -> Unit {
    let normal = @math.Vector3::new(0.0, 0.0, 0.0)
    let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
    let mut group_count = 0.0
    // this will be used to calculate the normal
    let slope = (radius_bottom - radius_top) / height
    // generate vertices, normals and uvs
    for y = 0.0; y <= height_segments; y = y + 1.0 {
      let index_row = []
      let v = y / height_segments
      // calculate the radius of the current row
      let radius = v * (radius_bottom - radius_top) + radius_top
      for x = 0.0; x <= radial_segments; x = x + 1.0 {
        let u = x / radial_segments
        let theta = u * theta_length + theta_start
        let sin_theta = @cmath.sin(theta)
        let cos_theta = @cmath.cos(theta)
        // vertex
        vertex.x = radius * sin_theta
        vertex.y = -v * height + half_height
        vertex.z = radius * cos_theta
        push3(vertices, vertex.x, vertex.y, vertex.z)
        // normal
        normal.set(sin_theta, slope, cos_theta).normalize() |> ignore
        push3(normals, normal.x, normal.y, normal.z)
        // uv
        push2(uvs, u, 1.0 - v)
        // save index of vertex in respective row
        index_row.push(index)
        index += 1.0
      }
      // now save vertices of the row in our index array
      index_array.push(index_row)
    }
    // generate indices
    for x = 0.0; x < radial_segments; x = x + 1.0 {
      for y = 0.0; y < height_segments; y = y + 1.0 {
        // we use the index array to access the correct indices
        let column = x.to_int()
        let row = y.to_int()
        let a = index_array[row][column]
        let b = index_array[row + 1][column]
        let c = index_array[row + 1][column + 1]
        let d = index_array[row][column + 1]
        // faces
        if radius_top > 0.0 || y != 0.0 {
          push3(indices, a, b, d)
          group_count += 3.0
        }
        if radius_bottom > 0.0 || y != height_segments - 1.0 {
          push3(indices, b, c, d)
          group_count += 3.0
        }
      }
    }
    // add a group to the geometry. this will ensure multi material support
    geometry.add_group(group_start.to_int(), group_count, material_index=0)
    // calculate new start value for groups
    group_start += group_count
  }

  fn generate_cap(top : Bool) -> Unit {
    // save the index of the first center vertex
    let center_index_start = index
    let uv = @math.Vector2::new(0.0, 0.0)
    let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
    let mut group_count = 0.0
    let radius = if top { radius_top } else { radius_bottom }
    let sign = if top { 1.0 } else { -1.0 }
    // first we generate the center vertex data of the cap.
    // because the geometry needs one set of uvs per face,
    // we must generate a center vertex per face/segment
    for x = 1.0; x <= radial_segments; x = x + 1.0 {
      // vertex
      push3(vertices, 0.0, half_height * sign, 0.0)
      // normal
      push3(normals, 0.0, sign, 0.0)
      // uv
      push2(uvs, 0.5, 0.5)
      // increase index
      index += 1.0
    }
    // save the index of the last center vertex
    let center_index_end = index
    // now we generate the surrounding vertices, normals and uvs
    for x = 0.0; x <= radial_segments; x = x + 1.0 {
      let u = x / radial_segments
      let theta = u * theta_length + theta_start
      let cos_theta = @cmath.cos(theta)
      let sin_theta = @cmath.sin(theta)
      // vertex
      vertex.x = radius * sin_theta
      vertex.y = half_height * sign
      vertex.z = radius * cos_theta
      push3(vertices, vertex.x, vertex.y, vertex.z)
      // normal
      push3(normals, 0.0, sign, 0.0)
      // uv
      uv.x = cos_theta * 0.5 + 0.5
      uv.y = sin_theta * 0.5 * sign + 0.5
      push2(uvs, uv.x, uv.y)
      // increase index
      index += 1.0
    }
    // generate indices
    for x = 0.0; x < radial_segments; x = x + 1.0 {
      let c = center_index_start + x
      let i = center_index_end + x
      if top {
        // face top
        push3(indices, i, i + 1.0, c)
      } else {
        // face bottom
        push3(indices, i + 1.0, i, c)
      }
      group_count += 3.0
    }
    // add a group to the geometry. this will ensure multi material support
    geometry.add_group(
      group_start.to_int(),
      group_count,
      material_index=if top { 1 } else { 2 },
    )
    // calculate new start value for groups
    group_start += group_count
  }

  // generate geometry
  generate_torso()
  if !open_ended {
    if radius_top > 0.0 {
      generate_cap(true)
    }
    if radius_bottom > 0.0 {
      generate_cap(false)
    }
  }
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
pub fn CylinderGeometry::from_json(data : Json) -> @core.BufferGeometry {
  CylinderGeometry::new(
    radius_top?=json_number(data, "radiusTop"),
    radius_bottom?=json_number(data, "radiusBottom"),
    height?=json_number(data, "height"),
    radial_segments?=json_number(data, "radialSegments"),
    height_segments?=json_number(data, "heightSegments"),
    open_ended?=json_bool(data, "openEnded"),
    theta_start?=json_number(data, "thetaStart"),
    theta_length?=json_number(data, "thetaLength"),
  )
}
