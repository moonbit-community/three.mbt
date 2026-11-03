///|
test "BufferGeometryLoader parser - attributes - circlable" {
  let loader = @loaders.BufferGeometryLoader::new()
  let geometry = @core.BufferGeometry::new()
  let attr = @core.BufferAttribute::new(
    @core.TypedArray::float32([7.0, 8, 9, 10, 11, 12]),
    2,
    normalized=true,
  )
  attr.name = "attribute"
  attr.set_usage(@core.DynamicDrawUsage) |> ignore
  geometry.set_attribute("attr", attr) |> ignore
  let geometry2 = loader.parse(geometry.to_json())
  guard geometry2.get_attribute("attr") is Some(Buffer(attr2)) else {
    fail(
      "Serialized attribute can be deserialized under the same attribute key.",
    )
  }
  assert_eq(attr2.array.to_array(), attr.array.to_array())
  assert_eq(attr2.array.type_name(), "Float32Array")
  assert_eq(attr2.item_size, attr.item_size)
  assert_eq(attr2.count, attr.count)
  assert_eq(attr2.normalized, attr.normalized)
  assert_eq(attr2.usage, attr.usage)
  assert_eq(attr2.name, attr.name)
  assert_eq(attr2.gpu_type, attr.gpu_type)
}

///|
test "BufferGeometryLoader parser - interleaved attributes - views into a shared array buffer" {
  let buffer = @core.TypedArray::float32([
    1.0, 2, 3, 0, 4, 5, 6, 0, 7, 8, 9, 0, 10, 11, 12, 0,
  ]).buffer()
  let position = @core.InterleavedBufferAttribute::new(
    @core.InterleavedBuffer::new(
      @core.TypedArray::view_by_name(
        "Float32Array",
        buffer,
        byte_offset=0,
        length=8,
      ),
      4,
    ),
    3,
    0,
  )
  let normal = @core.InterleavedBufferAttribute::new(
    @core.InterleavedBuffer::new(
      @core.TypedArray::view_by_name(
        "Float32Array",
        buffer,
        byte_offset=32,
        length=8,
      ),
      4,
    ),
    3,
    0,
  )
  let geometry = @core.BufferGeometry::new()
  geometry.set_attribute("position", position) |> ignore
  geometry.set_attribute("normal", normal) |> ignore
  let geometry2 = @loaders.BufferGeometryLoader::new().parse(geometry.to_json())
  guard geometry2.get_attribute("position") is Some(Interleaved(position2)) &&
    geometry2.get_attribute("normal") is Some(Interleaved(normal2)) else {
    fail("interleaved attributes were not deserialized")
  }
  assert_eq(position2.data.array.to_array(), [1.0, 2, 3, 0, 4, 5, 6, 0])
  assert_eq(normal2.data.array.to_array(), [7.0, 8, 9, 0, 10, 11, 12, 0])
  assert_eq(normal2.count(), 2)
}

///|
test "BufferGeometryLoader parser - index, groups, morph attributes, bounding sphere" {
  let json = @json.parse(
    (
      #|{"metadata":{},"name":"g","userData":{"k":1},
      #| "data":{"index":{"type":"Uint16Array","array":[0,1,2]},
      #| "attributes":{"position":{"itemSize":3,"type":"Float32Array","array":[0,0,0,1,0,0,0,1,0],"normalized":false},
      #|   "offset":{"itemSize":1,"type":"Float32Array","array":[1,2],"normalized":false,"isInstancedBufferAttribute":true,"meshPerAttribute":3}},
      #| "morphAttributes":{"position":[{"itemSize":3,"type":"Float32Array","array":[1,1,1,1,1,1,1,1,1],"normalized":false,"isInstancedBufferAttribute":true}]},
      #| "morphTargetsRelative":true,
      #| "drawcalls":[{"start":0,"count":3}],
      #| "boundingSphere":{"center":[1,2,3],"radius":4}},
      #| "isInstancedBufferGeometry":true}
    ),
  )
  let geometry = @loaders.BufferGeometryLoader::new().parse(json)
  assert_true(geometry.is_instanced_buffer_geometry)
  assert_eq(geometry.name, "g")
  assert_eq(geometry.user_data.get("k").cast(), 1.0)
  guard geometry.get_index() is Some(index) else { fail("no index") }
  assert_eq(index.array().type_name(), "Uint16Array")
  guard geometry.get_attribute("offset") is Some(Buffer(offset)) else {
    fail("no offset")
  }
  assert_true(offset.is_instanced_buffer_attribute())
  // `meshPerAttribute` is not restored, as upstream
  assert_eq(offset.mesh_per_attribute, 1)
  guard geometry.morph_attributes.get("position") is Some([Buffer(morph)]) else {
    fail("no morph attribute")
  }
  // morph attributes are always plain `BufferAttribute`s
  assert_false(morph.is_instanced_buffer_attribute())
  assert_true(geometry.morph_targets_relative)
  assert_eq(geometry.groups.length(), 1)
  assert_eq(geometry.groups[0].material_index, 0)
  guard geometry.bounding_sphere is Some(sphere) else { fail("no sphere") }
  assert_eq(sphere.radius, 4.0)
  assert_eq(sphere.center.z, 3.0)
}
