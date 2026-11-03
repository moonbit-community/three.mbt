// Unit tests of the uniform buffer packing (values recorded from upstream r187; the
// full byte-level comparison is the g7diff scenarios).

///|
test "UniformsGroup std140 layout" {
  let group = @nodes.NodeUniformsGroup::new("object", @nodes.object_group)
  let specs : Array[(String, &@nodes.IntoTsl)] = [
    ("float", 1.5),
    ("vec2", @math.Vector2::new(1, 2)),
    ("vec3", @math.Vector3::new(3, 4, 5)),
    ("color", @math.Color::new(0.1, 0.2, 0.3)),
    ("vec4", @math.Vector4::new(6, 7, 8, 9)),
    ("mat3", @math.Matrix3::new()),
    ("float", 2.0),
    ("mat4", @math.Matrix4::new()),
    ("vec2", @math.Vector2::new(10, 11)),
  ]
  for i, spec in specs {
    let node_uniform = @nodes.NodeUniform::new(
      "u\{i}",
      spec.0,
      @nodes.uniform(spec.1),
    )
    let uniform = match spec.0 {
      "float" => @nodes.NumberNodeUniform::new(node_uniform)
      "vec2" => @nodes.Vector2NodeUniform::new(node_uniform)
      "vec3" => @nodes.Vector3NodeUniform::new(node_uniform)
      "color" => @nodes.ColorNodeUniform::new(node_uniform)
      "vec4" => @nodes.Vector4NodeUniform::new(node_uniform)
      "mat3" => @nodes.Matrix3NodeUniform::new(node_uniform)
      _ => @nodes.Matrix4NodeUniform::new(node_uniform)
    }
    group.add_uniform(uniform) |> ignore
  }
  assert_eq(group.byte_length(), 208)
  assert_eq(group.uniforms().map(fn(u) { u.offset }), [
    0, 2, 4, 8, 12, 16, 28, 32, 48,
  ])
  assert_true(group.update())
  let buffer = group.buffer().unwrap()
  assert_eq(buffer.get(0), 1.5)
  assert_eq(buffer.get(2), 1.0)
  assert_eq(buffer.get(28), 2.0)
  assert_eq(buffer.get(48), 10.0)
  assert_eq(group.update_ranges().length(), 9)
  group.clear_update_ranges()
  assert_true(!group.update())
  assert_eq(group.update_ranges().length(), 0)
}

///|
test "ChainMap and DataMap" {
  let map : @nodes.ChainMap[Int32] = @nodes.ChainMap::new()
  let a = @core.JsValue::object()
  let b = @core.JsValue::object()
  map.set([a, b], 1) |> ignore
  map.set([a], 2) |> ignore
  assert_eq(map.get([a, b]), Some(1))
  assert_eq(map.get([a]), Some(2))
  assert_eq(map.get([b, a]), None)
  assert_true(map.delete([a, b]))
  assert_true(!map.delete([a, b]))
  assert_eq(map.get([a]), Some(2))
  assert_eq(@nodes.get_float_length(17), 32)
  assert_eq(@nodes.get_vector_length(3), 16)
  assert_eq(@nodes.get_stride_length(5), 8)
}
