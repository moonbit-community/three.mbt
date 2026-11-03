// Upstream src/geometries/EdgesGeometry.js.

///|
#external
pub type EdgesGeometry

///|
let _edges_v0 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _edges_v1 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _edges_normal : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _edges_triangle : @math.Triangle = @math.Triangle::new()

///|
priv struct EdgeData {
  index0 : Int32
  index1 : Int32
  normal : @math.Vector3
}

///|
fn edges_vector_hash(v : @math.Vector3, precision : Double) -> String {
  let x = js_number_string(js_math_round(v.x * precision))
  let y = js_number_string(js_math_round(v.y * precision))
  let z = js_number_string(js_math_round(v.z * precision))
  "\{x},\{y},\{z}"
}

///|
pub fn EdgesGeometry::new(
  geometry? : @core.BufferGeometry,
  threshold_angle~ : Double = 1.0,
) -> @core.BufferGeometry {
  let self = new_geometry(
    "EdgesGeometry",
    {
      "geometry": lazy_placeholder,
      "thresholdAngle": @math.json_number(threshold_angle),
    },
    lazy_values=source_geometry_parameter(geometry),
  )
  guard geometry is Some(geometry) else { return self }
  let precision_points = 4.0
  let precision = @cmath.pow(10.0, precision_points)
  let threshold_dot = @cmath.cos(@math.DEG2RAD * threshold_angle)
  let index_attr = geometry.get_index()
  let position_attr = geometry.get_attribute("position").unwrap()
  let index_count = match index_attr {
    Some(index) => index.count()
    None => position_attr.count()
  }
  let index_arr = [0, 0, 0]
  let hashes = ["", "", ""]
  let edge_data : Map[String, EdgeData?] = Map([])
  let vertices : Array[Double] = []
  let triangle = _edges_triangle
  let verts = [triangle.a, triangle.b, triangle.c]
  for i = 0; i < index_count; i = i + 3 {
    match index_attr {
      Some(index) => {
        index_arr[0] = index.get_x(i).to_int()
        index_arr[1] = index.get_x(i + 1).to_int()
        index_arr[2] = index.get_x(i + 2).to_int()
      }
      None => {
        index_arr[0] = i
        index_arr[1] = i + 1
        index_arr[2] = i + 2
      }
    }
    let { a, b, c, } = triangle
    a.from_buffer_attribute(position_attr, index_arr[0]) |> ignore
    b.from_buffer_attribute(position_attr, index_arr[1]) |> ignore
    c.from_buffer_attribute(position_attr, index_arr[2]) |> ignore
    triangle.get_normal(_edges_normal) |> ignore
    // create hashes for the edge from the vertices
    hashes[0] = edges_vector_hash(a, precision)
    hashes[1] = edges_vector_hash(b, precision)
    hashes[2] = edges_vector_hash(c, precision)
    // skip degenerate triangles
    if hashes[0] == hashes[1] ||
      hashes[1] == hashes[2] ||
      hashes[2] == hashes[0] {
      continue
    }
    // iterate over every edge
    for j = 0; j < 3; j = j + 1 {
      // get the first and next vertex making up the edge
      let j_next = (j + 1) % 3
      let vec_hash0 = hashes[j]
      let vec_hash1 = hashes[j_next]
      let v0 = verts[j]
      let v1 = verts[j_next]
      let hash = "\{vec_hash0}_\{vec_hash1}"
      let reverse_hash = "\{vec_hash1}_\{vec_hash0}"
      if edge_data.get(reverse_hash) is Some(Some(sibling)) {
        // if we found a sibling edge add it into the vertex array if
        // it meets the angle threshold and delete the edge from the map.
        if _edges_normal.dot(sibling.normal) <= threshold_dot {
          push3(vertices, v0.x, v0.y, v0.z)
          push3(vertices, v1.x, v1.y, v1.z)
        }
        edge_data[reverse_hash] = None
      } else if !edge_data.contains(hash) {
        // if we've already got an edge here then skip adding a new one
        edge_data[hash] = Some({
          index0: index_arr[j],
          index1: index_arr[j_next],
          normal: _edges_normal.clone(),
        })
      }
    }
  }
  // iterate over all remaining, unmatched edges and add them to the vertex array
  for _, edge in edge_data {
    if edge is Some({ index0, index1, .. }) {
      _edges_v0.from_buffer_attribute(position_attr, index0) |> ignore
      _edges_v1.from_buffer_attribute(position_attr, index1) |> ignore
      push3(vertices, _edges_v0.x, _edges_v0.y, _edges_v0.z)
      push3(vertices, _edges_v1.x, _edges_v1.y, _edges_v1.z)
    }
  }
  self.set_attribute("position", @core.Float32BufferAttribute::new(vertices, 3))
  |> ignore
  self
}
