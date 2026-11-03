// Upstream src/geometries/BoxGeometry.js.

///|
#external
pub type BoxGeometry

///|
pub fn BoxGeometry::new(
  width~ : Double = 1.0,
  height~ : Double = 1.0,
  depth~ : Double = 1.0,
  width_segments~ : Double = 1.0,
  height_segments~ : Double = 1.0,
  depth_segments~ : Double = 1.0,
) -> @core.BufferGeometry {
  let geometry = new_geometry("BoxGeometry", {
    "width": @math.json_number(width),
    "height": @math.json_number(height),
    "depth": @math.json_number(depth),
    "widthSegments": @math.json_number(width_segments),
    "heightSegments": @math.json_number(height_segments),
    "depthSegments": @math.json_number(depth_segments),
  })
  // segments
  let width_segments = width_segments.floor()
  let height_segments = height_segments.floor()
  let depth_segments = depth_segments.floor()
  // buffers
  let buffers = BufferGeometryBuffers::new()
  let { indices, vertices, normals, uvs, } = buffers
  // helper variables
  let mut number_of_vertices = 0.0
  let mut group_start = 0.0
  fn build_plane(
    u : Int32,
    v : Int32,
    w : Int32,
    udir : Double,
    vdir : Double,
    width : Double,
    height : Double,
    depth : Double,
    grid_x : Double,
    grid_y : Double,
    material_index : Int32,
  ) -> Unit {
    let segment_width = width / grid_x
    let segment_height = height / grid_y
    let width_half = width / 2.0
    let height_half = height / 2.0
    let depth_half = depth / 2.0
    let grid_x1 = grid_x + 1.0
    let grid_y1 = grid_y + 1.0
    let mut vertex_counter = 0.0
    let mut group_count = 0.0
    let vector = @math.Vector3::new(0.0, 0.0, 0.0)
    // generate vertices, normals and uvs
    for iy = 0.0; iy < grid_y1; iy = iy + 1.0 {
      let y = iy * segment_height - height_half
      for ix = 0.0; ix < grid_x1; ix = ix + 1.0 {
        let x = ix * segment_width - width_half
        // set values to correct vector component
        vector.set_component(u, x * udir) |> ignore
        vector.set_component(v, y * vdir) |> ignore
        vector.set_component(w, depth_half) |> ignore
        // now apply vector to vertex buffer
        push3(vertices, vector.x, vector.y, vector.z)
        // set values to correct vector component
        vector.set_component(u, 0.0) |> ignore
        vector.set_component(v, 0.0) |> ignore
        vector.set_component(w, if depth > 0.0 { 1.0 } else { -1.0 }) |> ignore
        // now apply vector to normal buffer
        push3(normals, vector.x, vector.y, vector.z)
        // uvs
        uvs.push(ix / grid_x)
        uvs.push(1.0 - iy / grid_y)
        // counters
        vertex_counter += 1.0
      }
    }
    // indices
    for iy = 0.0; iy < grid_y; iy = iy + 1.0 {
      for ix = 0.0; ix < grid_x; ix = ix + 1.0 {
        let a = number_of_vertices + ix + grid_x1 * iy
        let b = number_of_vertices + ix + grid_x1 * (iy + 1.0)
        let c = number_of_vertices + (ix + 1.0) + grid_x1 * (iy + 1.0)
        let d = number_of_vertices + (ix + 1.0) + grid_x1 * iy
        // faces
        push3(indices, a, b, d)
        push3(indices, b, c, d)
        // increase counter
        group_count += 6.0
      }
    }
    // add a group to the geometry. this will ensure multi material support
    geometry.add_group(group_start.to_int(), group_count, material_index~)
    // calculate new start value for groups
    group_start += group_count
    // update total number of vertices
    number_of_vertices += vertex_counter
  }

  // build each side of the box geometry
  build_plane(
    2, 1, 0, -1.0, -1.0, depth, height, width, depth_segments, height_segments, 0,
  ) // px
  build_plane(
    2,
    1,
    0,
    1.0,
    -1.0,
    depth,
    height,
    -width,
    depth_segments,
    height_segments,
    1,
  ) // nx
  build_plane(
    0, 2, 1, 1.0, 1.0, width, depth, height, width_segments, depth_segments, 2,
  ) // py
  build_plane(
    0,
    2,
    1,
    1.0,
    -1.0,
    width,
    depth,
    -height,
    width_segments,
    depth_segments,
    3,
  ) // ny
  build_plane(
    0, 1, 2, 1.0, -1.0, width, height, depth, width_segments, height_segments, 4,
  ) // pz
  build_plane(
    0,
    1,
    2,
    -1.0,
    -1.0,
    width,
    height,
    -depth,
    width_segments,
    height_segments,
    5,
  ) // nz
  // build geometry
  buffers.apply(geometry)
  geometry
}

///|
pub fn BoxGeometry::from_json(data : Json) -> @core.BufferGeometry {
  BoxGeometry::new(
    width?=json_number(data, "width"),
    height?=json_number(data, "height"),
    depth?=json_number(data, "depth"),
    width_segments?=json_number(data, "widthSegments"),
    height_segments?=json_number(data, "heightSegments"),
    depth_segments?=json_number(data, "depthSegments"),
  )
}
