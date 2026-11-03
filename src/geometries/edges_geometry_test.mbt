///|
fn create_indexed_buffer_geometry(
  vert_list : Array[@math.Vector3],
  idx_list : Array[Int32],
) -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  let index_table : Map[Int32, Int32] = Map([])
  let num_tris = idx_list.length() / 3
  let mut num_verts = 0
  let indices = @core.TypedArray::uint32(num_tris * 3)
  let vertices = @core.TypedArray::float32(vert_list.length() * 3)
  for i in 0..<num_tris {
    for j in 0..<3 {
      let idx = idx_list[3 * i + j]
      if !index_table.contains(idx) {
        let v = vert_list[idx]
        vertices.set(3 * num_verts, v.x)
        vertices.set(3 * num_verts + 1, v.y)
        vertices.set(3 * num_verts + 2, v.z)
        index_table[idx] = num_verts
        num_verts += 1
      }
      indices.set(3 * i + j, index_table[idx].to_double())
    }
  }
  let vertices = vertices.subarray(end=3 * num_verts)
  geometry.set_index(@core.BufferAttribute::new(indices, 1)) |> ignore
  geometry.set_attribute("position", @core.BufferAttribute::new(vertices, 3))
  |> ignore
  geometry
}

///|
fn add_draw_calls(geometry : @core.BufferGeometry) -> @core.BufferGeometry {
  let num_tris = geometry.index.unwrap().count() / 3
  for i in 0..<num_tris {
    geometry.add_group(i * 3, 3)
  }
  geometry
}

///|
fn test_edges(
  vert_list : Array[@math.Vector3],
  idx_list : Array[Int32],
  num_after : Int32,
) -> Unit raise {
  let geom_ib = create_indexed_buffer_geometry(vert_list, idx_list)
  let geom_dc = add_draw_calls(geom_ib.clone())
  for geometry in [geom_ib, geom_dc] {
    assert_eq(geometry.index.unwrap().count(), idx_list.length())
    let edges = @geometries.EdgesGeometry::new(geometry~)
    assert_eq(position_count(edges) / 2, num_after)
  }
}

///|
fn edges_vert_list() -> Array[@math.Vector3] {
  [
    @math.Vector3::new(0, 0, 0),
    @math.Vector3::new(1, 0, 0),
    @math.Vector3::new(1, 1, 0),
    @math.Vector3::new(0, 1, 0),
    @math.Vector3::new(1, 1, 1),
  ]
}

///|
test "EdgesGeometry: type" {
  assert_eq(@geometries.EdgesGeometry::new().type_, "EdgesGeometry")
}

///|
test "EdgesGeometry: singularity" {
  test_edges(edges_vert_list(), [1, 1, 1], 0)
}

///|
test "EdgesGeometry: needle" {
  test_edges(edges_vert_list(), [0, 0, 1], 0)
}

///|
test "EdgesGeometry: single triangle" {
  test_edges(edges_vert_list(), [0, 1, 2], 3)
}

///|
test "EdgesGeometry: two isolated triangles" {
  let vert_list = [
    @math.Vector3::new(0, 0, 0),
    @math.Vector3::new(1, 0, 0),
    @math.Vector3::new(1, 1, 0),
    @math.Vector3::new(0, 0, 1),
    @math.Vector3::new(1, 0, 1),
    @math.Vector3::new(1, 1, 1),
  ]
  test_edges(vert_list, [0, 1, 2, 3, 4, 5], 6)
}

///|
test "EdgesGeometry: two flat triangles" {
  test_edges(edges_vert_list(), [0, 1, 2, 0, 2, 3], 4)
}

///|
test "EdgesGeometry: two flat triangles, inverted" {
  test_edges(edges_vert_list(), [0, 1, 2, 0, 3, 2], 5)
}

///|
test "EdgesGeometry: two non-coplanar triangles" {
  test_edges(edges_vert_list(), [0, 1, 2, 0, 4, 2], 5)
}

///|
test "EdgesGeometry: three triangles, coplanar first" {
  test_edges(edges_vert_list(), [0, 2, 3, 0, 1, 2, 0, 4, 2], 7)
}

///|
test "EdgesGeometry: three triangles, coplanar last" {
  test_edges(edges_vert_list(), [0, 1, 2, 0, 4, 2, 0, 2, 3], 6) // Should be 7
}

///|
test "EdgesGeometry: tetrahedron" {
  test_edges(edges_vert_list(), [0, 1, 2, 0, 1, 4, 0, 4, 2, 1, 2, 4], 6)
}

///|
test "EdgesGeometry: parameters.geometry is serialized when toJSON runs" {
  let source = @geometries.BoxGeometry::new()
  let geometry = @geometries.EdgesGeometry::new(geometry=source)
  let box = @geometries.BoxGeometry::new().copy(geometry)
  source.name = "renamed"
  source.translate(1, 0, 0) |> ignore
  assert_eq(json_get(geometry.to_json(), "geometry"), Some(source.to_json()))
  assert_eq(json_get(box.to_json(), "geometry"), Some(source.to_json()))
  assert_eq(
    json_get(@geometries.EdgesGeometry::new().to_json(), "geometry"),
    Some(Json::null()),
  )
}
