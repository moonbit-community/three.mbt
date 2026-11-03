// Upstream src/geometries/WireframeGeometry.js.

///|
#external
pub type WireframeGeometry

///|
fn wireframe_vector_hash(v : @math.Vector3) -> String {
  "\{js_number_string(v.x)},\{js_number_string(v.y)},\{js_number_string(v.z)}"
}

///|
fn is_unique_edge(
  start : @math.Vector3,
  end : @math.Vector3,
  edges : Set[String],
) -> Bool {
  let start_hash = wireframe_vector_hash(start)
  let end_hash = wireframe_vector_hash(end)
  let hash1 = "\{start_hash}-\{end_hash}"
  let hash2 = "\{end_hash}-\{start_hash}" // coincident edge
  if edges.contains(hash1) || edges.contains(hash2) {
    false
  } else {
    edges.add(hash1)
    edges.add(hash2)
    true
  }
}

///|
pub fn WireframeGeometry::new(
  geometry? : @core.BufferGeometry,
) -> @core.BufferGeometry {
  let self = new_geometry(
    "WireframeGeometry",
    { "geometry": lazy_placeholder },
    lazy_values=source_geometry_parameter(geometry),
  )
  guard geometry is Some(geometry) else { return self }
  // buffer
  let vertices : Array[Double] = []
  let edges : Set[String] = Set([])
  // helper variables
  let start = @math.Vector3::new(0.0, 0.0, 0.0)
  let end = @math.Vector3::new(0.0, 0.0, 0.0)
  fn add_edge(
    position : @core.GeometryAttribute,
    index1 : Int32,
    index2 : Int32,
  ) -> Unit {
    start.from_buffer_attribute(position, index1) |> ignore
    end.from_buffer_attribute(position, index2) |> ignore
    if is_unique_edge(start, end, edges) {
      push3(vertices, start.x, start.y, start.z)
      push3(vertices, end.x, end.y, end.z)
    }
  }

  let position = geometry.attributes.get("position")
  if geometry.index is Some(indices) {
    // indexed BufferGeometry
    let groups : Array[(Int32, Double)] = if geometry.groups.is_empty() {
      [(0, indices.count().to_double())]
    } else {
      geometry.groups.map(group => (group.start, group.count))
    }
    // create a data structure that contains all edges without duplicates
    for group in groups {
      let (group_start, group_count) = group
      let l = group_start.to_double() + group_count
      for i = group_start; i.to_double() < l; i = i + 3 {
        for j = 0; j < 3; j = j + 1 {
          let index1 = indices.get_x(i + j)
          let index2 = indices.get_x(i + (j + 1) % 3)
          add_edge(position.unwrap(), index1.to_int(), index2.to_int())
        }
      }
    }
  } else {
    // non-indexed BufferGeometry
    let position = position.unwrap()
    let l = position.count().to_double() / 3.0
    for i = 0; i.to_double() < l; i = i + 1 {
      for j = 0; j < 3; j = j + 1 {
        // three edges per triangle, an edge is represented as (index1, index2)
        // e.g. the first triangle has the following edges: (0,1),(1,2),(2,0)
        add_edge(position, 3 * i + j, 3 * i + (j + 1) % 3)
      }
    }
  }
  // build geometry
  self.set_attribute("position", @core.Float32BufferAttribute::new(vertices, 3))
  |> ignore
  self
}
