// Upstream test/unit/addons/utils/BufferGeometryUtils.tests.js.

///|
fn bgut_get_geometry() -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  // square
  let vertices = @core.TypedArray::float32([
    -1.0, -1.0, 0.0, // Bottom left
     1.0, -1.0, 0.0, // Bottom right
     1.0, 1.0, 0.0, // Top right
     -1.0, 1.0, 0.0, // Top left
  ])
  let morph_vertices = @core.TypedArray::float32([
    0.0, -1.0, 0.0, // Bottom
     1.0, 0.0, 0.0, // Right
     0.0, 1.0, 0.0, // Top
     -1.0, 0.0, 0.0, // Left
  ])
  ignore(
    geometry.set_attribute("position", @core.BufferAttribute::new(vertices, 3)),
  )
  geometry.morph_attributes["position"] = [
    Buffer(@core.BufferAttribute::new(morph_vertices, 3)),
  ]
  geometry
}

///|
fn bgut_components(attribute : @core.GeometryAttribute) -> Array[Double] {
  let components = []
  for i in 0..<attribute.count() {
    for j in 0..<attribute.item_size() {
      components.push(attribute.get_component(i, j))
    }
  }
  components
}

///|
fn bgut_buffer(attribute : @core.GeometryAttribute) -> @core.BufferAttribute {
  guard attribute is Buffer(a) else { abort("not a BufferAttribute") }
  a
}

///|
fn bgut_interleaved(
  attribute : @core.GeometryAttribute,
) -> @core.InterleavedBufferAttribute {
  guard attribute is Interleaved(a) else {
    abort("not an InterleavedBufferAttribute")
  }
  a
}

///|
fn bgut_clone_attribute(
  geometry : @core.BufferGeometry,
) -> @core.GeometryAttribute {
  Buffer(bgut_buffer(geometry.attributes["position"]).clone())
}

///|
test "remapAttribute preserves raw values and metadata" {
  let attribute = @core.BufferAttribute::new(
    @core.TypedArray::int16([-32768, 32767, -1, 1]),
    2,
    normalized=true,
  )
  attribute.name = "weights"
  ignore(attribute.set_usage(@core.DynamicDrawUsage))
  attribute.gpu_type = @core.IntType
  let result = bgut_buffer(
    @utils.BufferGeometryUtils::remap_attribute(Buffer(attribute), [1, 0, 1]),
  )
  assert_eq(result.array.to_array(), [-1.0, 1.0, -32768.0, 32767.0, -1.0, 1.0])
  assert_true(result.normalized)
  assert_eq(result.name, attribute.name)
  assert_eq(result.usage, @core.DynamicDrawUsage)
  assert_eq(result.gpu_type, @core.IntType)
  let half = @core.Float16BufferAttribute::new([0x8000, 0x3c00, 0x0001], 1)
  let remapped_half = bgut_buffer(
    @utils.BufferGeometryUtils::remap_attribute(Buffer(half), [2, 0, 1]),
  )
  assert_true(remapped_half.is_float16_buffer_attribute())
  assert_eq(remapped_half.array.to_array(), [1.0, 32768.0, 15360.0])
  assert_true(!physical_equal(result.array, attribute.array))
}

///|
test "remapAttribute preserves shared interleaved buffers" {
  let data = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1, 2, 3, 4, 5, 6]),
    3,
  ).set_usage(@core.DynamicDrawUsage)
  let position = @core.InterleavedBufferAttribute::new(data, 2, 0)
  let weight = @core.InterleavedBufferAttribute::new(data, 1, 2)
  let buffers = @utils.RemapBuffers::new()
  let source = [1, 0, 1]
  let p = bgut_interleaved(
    @utils.BufferGeometryUtils::remap_attribute(
      Interleaved(position),
      source,
      buffers~,
    ),
  )
  let w = bgut_interleaved(
    @utils.BufferGeometryUtils::remap_attribute(
      Interleaved(weight),
      source,
      buffers~,
    ),
  )
  assert_true(physical_equal(p.data, w.data))
  assert_true(!physical_equal(p.data, data))
  assert_eq(p.data.usage, @core.DynamicDrawUsage)
  assert_eq(p.data.array.to_array(), [4.0, 5, 6, 1, 2, 3, 4, 5, 6])
  assert_eq(w.get_x(2), 6.0)
}

///|
test "mergeVertices remaps half-float morphs without conversion" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.BufferAttribute::new(
        @core.TypedArray::float32([1, 0, 0, 2, 0, 0, 1, 0, 0]),
        3,
      ),
    ),
  )
  let morph = @core.Float16BufferAttribute::new(
    [0x8000, 0x0001, 0x3c00, 0x4000, 0x4200, 0x4400, 0, 0, 0],
    3,
  )
  morph.name = "pose"
  ignore(morph.set_usage(@core.DynamicDrawUsage))
  geometry.morph_attributes["position"] = [Buffer(morph)]
  ignore(geometry.set_index([1, 0, 2]))
  let result = @utils.BufferGeometryUtils::merge_vertices(geometry)
  assert_eq(result.index.unwrap().array().to_array(), [0.0, 1, 1])
  let output = bgut_buffer(result.morph_attributes["position"][0])
  assert_true(output.is_float16_buffer_attribute())
  assert_eq(output.array.to_array(), [16384.0, 16896, 17408, 32768, 1, 15360])
  assert_eq(output.name, "pose")
  assert_eq(output.usage, @core.DynamicDrawUsage)
  assert_eq(morph.count, 3)
}

///|
test "mergeGeometries rejects missing morph attributes" {
  let geometry1 = bgut_get_geometry()
  let geometry2 = bgut_get_geometry()
  geometry2.morph_attributes.remove("position")
  assert_true(
    @utils.BufferGeometryUtils::merge_geometries([geometry1, geometry2]) is None,
  )
  assert_true(
    @utils.BufferGeometryUtils::merge_geometries([geometry2, geometry1]) is None,
  )
}

///|
test "mergeGeometries rejects inconsistent morph target counts" {
  for counts in [(2, 1), (1, 2), (0, 1), (1, 0)] {
    let (count1, count2) = counts
    let geometry1 = bgut_get_geometry()
    let geometry2 = bgut_get_geometry()
    geometry1.morph_attributes["position"] = Array::makei(count1, _ => {
      bgut_clone_attribute(geometry1)
    })
    geometry2.morph_attributes["position"] = Array::makei(count2, _ => {
      bgut_clone_attribute(geometry2)
    })
    assert_true(
      @utils.BufferGeometryUtils::merge_geometries([geometry1, geometry2])
      is None,
    )
  }
}

///|
test "mergeGeometries merges compatible morph targets" {
  let geometry1 = bgut_get_geometry()
  let geometry2 = bgut_get_geometry()
  for i, geometry in [geometry1, geometry2] {
    ignore(geometry.set_attribute("normal", bgut_clone_attribute(geometry)))
    geometry.morph_attributes["position"].push(bgut_clone_attribute(geometry))
    geometry.morph_attributes["normal"] = [
      Buffer(bgut_buffer(geometry.attributes["normal"]).clone()),
    ]
    for _, attributes in geometry.morph_attributes {
      for j, attribute in attributes {
        attribute.array().fill(((i + 1) * 10 + j).to_double())
      }
    }
  }
  let merged = @utils.BufferGeometryUtils::merge_geometries([
    geometry1, geometry2,
  ]).unwrap()
  assert_eq(merged.attributes["position"].count(), 8)
  assert_eq(merged.morph_attributes.keys().collect(), ["position", "normal"])
  for name, attributes in geometry1.morph_attributes {
    assert_eq(merged.morph_attributes[name].length(), attributes.length())
    for i in 0..<merged.morph_attributes[name].length() {
      assert_eq(
        merged.morph_attributes[name][i].count(),
        merged.attributes[name].count(),
      )
      assert_eq(
        merged.morph_attributes[name][i].array().to_array(),
        [
          ..geometry1.morph_attributes[name][i].array().to_array(),
          ..geometry2.morph_attributes[name][i].array().to_array(),
        ],
      )
    }
  }
}

///|
test "mergeGeometries merges geometries without morph attributes" {
  let geometry = bgut_get_geometry()
  geometry.morph_attributes.remove("position")
  let merged = @utils.BufferGeometryUtils::merge_geometries([geometry, geometry]).unwrap()
  assert_eq(merged.attributes["position"].count(), 8)
  assert_eq(merged.morph_attributes.length(), 0)
}

///|
test "mergeGeometries merges geometries with empty morph target arrays" {
  let geometry = bgut_get_geometry()
  geometry.morph_attributes["position"] = []
  let merged = @utils.BufferGeometryUtils::merge_geometries([geometry, geometry]).unwrap()
  assert_eq(merged.attributes["position"].count(), 8)
  assert_eq(merged.morph_attributes.length(), 0)
}

///|
test "mergeVertices can handle morphAttributes without crashing" {
  let geometry = bgut_get_geometry()
  let indexed_geometry = @utils.BufferGeometryUtils::merge_vertices(geometry)
  let original = geometry.morph_attributes["position"][0]
  let merged = indexed_geometry.morph_attributes["position"][0]
  assert_eq(merged.array().to_array(), original.array().to_array())
  assert_eq(merged.item_size(), original.item_size())
  assert_eq(merged.count(), original.count())
  assert_true(indexed_geometry.index is Some(_))
}

///|
test "mergeVertices preserves distinct vertices with zero tolerance" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.BufferAttribute::new(
        @core.TypedArray::float32([11, 0, 0, 12, 0, 0, 11, 0, 0]),
        3,
      ),
    ),
  )
  let indexed_geometry = @utils.BufferGeometryUtils::merge_vertices(
    geometry,
    tolerance=0.0,
  )
  assert_eq(indexed_geometry.get_attribute("position").unwrap().count(), 2)
  assert_eq(indexed_geometry.index.unwrap().array().to_array(), [0.0, 1, 0])
}

///|
test "mergeVertices preserves interleaved attributes" {
  let geometry = @core.BufferGeometry::new()
  let interleaved_buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([
      0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1,
    ]),
    6,
  )
  ignore(
    geometry.set_attribute(
      "position",
      @core.InterleavedBufferAttribute::new(interleaved_buffer, 3, 0),
    ),
  )
  ignore(
    geometry.set_attribute(
      "normal",
      @core.InterleavedBufferAttribute::new(interleaved_buffer, 3, 3),
    ),
  )
  let morph_buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([0, 1, 0, 9, 1, 1, 0, 9, 0, 1, 0, 9]),
    4,
  )
  geometry.morph_attributes["position"] = [
    Interleaved(@core.InterleavedBufferAttribute::new(morph_buffer, 3, 0)),
  ]
  let indexed_geometry = @utils.BufferGeometryUtils::merge_vertices(geometry)
  let position = indexed_geometry.get_attribute("position").unwrap()
  let normal = indexed_geometry.get_attribute("normal").unwrap()
  let morph_position = indexed_geometry.morph_attributes["position"][0]
  assert_eq(indexed_geometry.index.unwrap().array().to_array(), [0.0, 1, 0])
  let p = bgut_interleaved(position)
  let n = bgut_interleaved(normal)
  assert_true(physical_equal(p.data, n.data))
  assert_eq(p.data.stride, 6)
  assert_eq(n.offset, 3)
  assert_eq(bgut_interleaved(morph_position).data.stride, 4)
  assert_eq(bgut_components(position), [0.0, 0, 0, 1, 0, 0])
  assert_eq(bgut_components(normal), [0.0, 0, 1, 0, 0, 1])
  assert_eq(bgut_components(morph_position), [0.0, 1, 0, 1, 1, 0])
}

///|
test "deinterleaveGeometry deinterleaves attributes and morph attributes" {
  let geometry = @core.BufferGeometry::new()
  let interleaved_buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1]),
    6,
  )
  ignore(
    geometry.set_attribute(
      "position",
      @core.InterleavedBufferAttribute::new(interleaved_buffer, 3, 0),
    ),
  )
  ignore(
    geometry.set_attribute(
      "normal",
      @core.InterleavedBufferAttribute::new(interleaved_buffer, 3, 3),
    ),
  )
  let morph_buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([0, 1, 0, 0, 2, 0, 1, 1, 0, 1, 2, 0]),
    6,
  )
  geometry.morph_attributes["position"] = [
    Interleaved(@core.InterleavedBufferAttribute::new(morph_buffer, 3, 0)),
    Interleaved(@core.InterleavedBufferAttribute::new(morph_buffer, 3, 3)),
  ]
  @utils.BufferGeometryUtils::deinterleave_geometry(geometry)
  let position = bgut_buffer(geometry.get_attribute("position").unwrap())
  let normal = bgut_buffer(geometry.get_attribute("normal").unwrap())
  let morph_position0 = bgut_buffer(geometry.morph_attributes["position"][0])
  let morph_position1 = bgut_buffer(geometry.morph_attributes["position"][1])
  assert_eq(position.array.to_array(), [0.0, 0, 0, 1, 0, 0])
  assert_eq(normal.array.to_array(), [0.0, 0, 1, 0, 0, 1])
  assert_eq(morph_position0.array.to_array(), [0.0, 1, 0, 1, 1, 0])
  assert_eq(morph_position1.array.to_array(), [0.0, 2, 0, 1, 2, 0])
}

///|
test "toTrianglesDrawMode converts strips and fans" {
  let strip = @core.BufferGeometry::new()
  ignore(
    strip.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(Array::make(15, 0.0), 3),
    ),
  )
  ignore(
    @utils.BufferGeometryUtils::to_triangles_draw_mode(
      strip,
      @core.TriangleStripDrawMode,
    ),
  )
  assert_eq(strip.index.unwrap().array().to_array(), [
    0.0, 1, 2, 3, 2, 1, 2, 3, 4,
  ])
  let fan = @core.BufferGeometry::new()
  ignore(fan.set_index([4, 3, 2, 1]))
  ignore(
    @utils.BufferGeometryUtils::to_triangles_draw_mode(
      fan,
      @core.TriangleFanDrawMode,
    ),
  )
  assert_eq(fan.index.unwrap().array().to_array(), [4.0, 3, 2, 4, 2, 1])
}

///|
test "estimateBytesUsed counts attributes and index" {
  let geometry = @geometries.BoxGeometry::new()
  // 24 vertices: position, normal (3 floats) and uv (2 floats); 36 Uint16 indices
  assert_eq(
    @utils.BufferGeometryUtils::estimate_bytes_used(geometry),
    24 * 8 * 4 + 36 * 2,
  )
}

///|
test "mergeGroups sorts and merges groups" {
  let geometry = @geometries.BoxGeometry::new()
  for i, group in geometry.groups {
    group.material_index = i % 2
  }
  ignore(@utils.BufferGeometryUtils::merge_groups(geometry))
  assert_eq(geometry.groups.length(), 2)
  assert_eq(geometry.groups[0].start, 0)
  assert_eq(geometry.groups[0].count, 18.0)
  assert_eq(geometry.groups[1].material_index, 1)
  assert_eq(geometry.index.unwrap().count(), 36)
}

///|
test "toCreasedNormals keeps box faces flat" {
  let geometry = @utils.BufferGeometryUtils::to_creased_normals(
    @geometries.BoxGeometry::new(),
  )
  assert_true(geometry.index is None)
  let normal = geometry.get_attribute("normal").unwrap()
  assert_eq(normal.count(), 36)
  assert_eq([normal.get_x(0), normal.get_y(0), normal.get_z(0)], [1.0, 0, 0])
}
