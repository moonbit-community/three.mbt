///|
fn buffer_attribute_equals(
  a : @core.GeometryAttribute,
  b : @core.GeometryAttribute,
) -> Bool {
  if a.count() != b.count() || a.item_size() != b.item_size() {
    return false
  }
  for i in 0..<(a.count() * a.item_size()) {
    if (a.array()[i] - b.array()[i]).abs() > 0.0001 {
      return false
    }
  }
  true
}

///|
fn geometry_with_position(vertices : Array[Double]) -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.BufferAttribute::new(@core.TypedArray::float32(vertices), 3),
    ),
  )
  geometry
}

///|
fn get_bb_for_vertices(vertices : Array[Double]) -> @math.Box3 {
  let geometry = geometry_with_position(vertices)
  geometry.compute_bounding_box()
  geometry.bounding_box.unwrap()
}

///|
fn get_bs_for_vertices(vertices : Array[Double]) -> @math.Sphere {
  let geometry = geometry_with_position(vertices)
  geometry.compute_bounding_sphere()
  geometry.bounding_sphere.unwrap()
}

///|
fn get_normals_for_vertices(vertices : Array[Double]) -> @core.TypedArray {
  let geometry = geometry_with_position(vertices)
  geometry.compute_vertex_normals()
  geometry.attributes.get("normal").unwrap().array()
}

///|
fn position_of(geometry : @core.BufferGeometry) -> @core.TypedArray {
  geometry.attributes.get("position").unwrap().array()
}

///|
test "BufferGeometry type" {
  assert_eq(@core.BufferGeometry::new().type_, "BufferGeometry")
}

///|
test "BufferGeometry setIndex/getIndex" {
  let a = @core.BufferGeometry::new()
  ignore(a.set_index([1, 2, 3]))
  assert_eq(a.get_index().unwrap().array().type_name(), "Uint16Array")
  assert_eq(a.get_index().unwrap().array().to_array(), [1.0, 2, 3])
  ignore(a.set_index([65535.0, 65536, 65537]))
  assert_eq(a.get_index().unwrap().array().type_name(), "Uint32Array")
  assert_eq(a.get_index().unwrap().array().to_array(), [65535.0, 65536, 65537])
  let none : @core.GeometryAttribute? = None
  ignore(a.set_index(none))
  assert_true(a.get_index() is None)
}

///|
test "BufferGeometry set / delete Attribute" {
  let geometry = @core.BufferGeometry::new()
  assert_false(geometry.has_attribute("position"))
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([1.0, 2, 3], 1),
    ),
  )
  assert_true(geometry.has_attribute("position"))
  ignore(geometry.delete_attribute("position"))
  assert_false(geometry.has_attribute("position"))
}

///|
test "BufferGeometry addGroup" {
  let a = @core.BufferGeometry::new()
  a.add_group(0, 1, material_index=0)
  a.add_group(1, 2, material_index=2)
  assert_eq(a.groups.length(), 2)
  assert_eq(a.groups[1].start, 1)
  assert_eq(a.groups[1].count, 2)
  assert_eq(a.groups[1].material_index, 2)
  a.clear_groups()
  assert_eq(a.groups.length(), 0)
}

///|
test "BufferGeometry setDrawRange" {
  let a = @core.BufferGeometry::new()
  assert_false(a.draw_range.count < 1.0e300)
  a.set_draw_range(1, 7)
  assert_eq(a.draw_range.start, 1)
  assert_eq(a.draw_range.count, 7)
}

///|
test "BufferGeometry applyMatrix4" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.BufferAttribute::new(@core.TypedArray::float32(6), 3),
    ),
  )
  let matrix = @math.Matrix4::new().set(
    1, 0, 0, 1.5, 0, 1, 0, -2, 0, 0, 1, 3, 0, 0, 0, 1,
  )
  ignore(geometry.apply_matrix4(matrix))
  let position = position_of(geometry)
  let m = matrix.elements
  assert_true(
    position[0] == m[12] && position[1] == m[13] && position[2] == m[14],
  )
  assert_true(
    position[3] == m[12] && position[4] == m[13] && position[5] == m[14],
  )
  guard geometry.attributes.get("position") is Some(Buffer(attribute)) else {
    fail("no position")
  }
  assert_eq(attribute.version, 1)
}

///|
test "BufferGeometry applyMatrix4 transforms normal and tangent and bounds" {
  let geometry = geometry_with_position([1.0, 0, 0])
  ignore(
    geometry.set_attribute(
      "normal",
      @core.Float32BufferAttribute::new([0.0, 0, 1], 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "tangent",
      @core.Float32BufferAttribute::new([1.0, 0, 0, 1], 4),
    ),
  )
  geometry.compute_bounding_box()
  geometry.compute_bounding_sphere()
  ignore(
    geometry.apply_matrix4(
      @math.Matrix4::new().make_rotation_y(test_pi() / 2.0),
    ),
  )
  let normal = geometry.attributes.get("normal").unwrap()
  assert_true(approx(normal.get_x(0), 1))
  assert_true(approx(normal.get_z(0), 0))
  let tangent = geometry.attributes.get("tangent").unwrap()
  assert_true(approx(tangent.get_z(0), -1))
  assert_true(approx(geometry.bounding_box.unwrap().min.z, -1))
  assert_true(approx(geometry.bounding_sphere.unwrap().center.z, -1))
}

///|
test "BufferGeometry applyQuaternion" {
  let geometry = geometry_with_position([1.0, 2, 3, 4, 5, 6])
  ignore(geometry.apply_quaternion(@math.Quaternion::new(0.5, 0.5, 0.5, 0.5)))
  // geometry was rotated around the (1, 1, 1) axis.
  assert_eq(position_of(geometry).to_array(), [3.0, 1, 2, 6, 4, 5])
}

///|
test "BufferGeometry rotateX/Y/Z" {
  let geometry = geometry_with_position([1.0, 2, 3, 4, 5, 6])
  let pos = position_of(geometry)
  ignore(geometry.rotate_x(test_pi()))
  // object was rotated around x so all items should be flipped but the x ones
  assert_eq(pos.to_array(), [1.0, -2, -3, 4, -5, -6])
  ignore(geometry.rotate_y(test_pi()))
  // vertices were rotated around y so all items should be flipped again but the y ones
  assert_eq(pos.to_array(), [-1.0, -2, 3, -4, -5, 6])
  ignore(geometry.rotate_z(test_pi()))
  // vertices were rotated around z so all items should be flipped again but the z ones
  assert_eq(pos.to_array(), [1.0, 2, 3, 4, 5, 6])
}

///|
test "BufferGeometry translate" {
  let geometry = geometry_with_position([1.0, 2, 3, 4, 5, 6])
  ignore(geometry.translate(10, 20, 30))
  assert_eq(position_of(geometry).to_array(), [11.0, 22, 33, 14, 25, 36])
}

///|
test "BufferGeometry scale" {
  let geometry = geometry_with_position([-1.0, -1, -1, 2, 2, 2])
  ignore(geometry.scale(1, 2, 3))
  assert_eq(position_of(geometry).to_array(), [-1.0, -2, -3, 2, 4, 6])
}

///|
test "BufferGeometry lookAt" {
  let a = geometry_with_position([
    -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0,
    -1.0, -1.0, 1.0,
  ])
  let sqrt = 2.0.sqrt()
  let expected : @core.GeometryAttribute = Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32([
        1.0,
        0,
        -sqrt,
        -1,
        0,
        -sqrt,
        -1,
        sqrt,
        0,
        -1,
        sqrt,
        0,
        1,
        sqrt,
        0,
        1,
        0,
        -sqrt,
      ]),
      3,
    ),
  )
  ignore(a.look_at(vec3(0, 1, -1)))
  assert_true(
    buffer_attribute_equals(a.attributes.get("position").unwrap(), expected),
  )
}

///|
test "BufferGeometry center" {
  let geometry = geometry_with_position([-1.0, -1, -1, 1, 1, 1, 4, 4, 4])
  ignore(geometry.center())
  // the boundingBox should go from (-1, -1, -1) to (4, 4, 4) so it has a size of (5, 5, 5)
  // after centering it the vertices should be placed between (-2.5, -2.5, -2.5) and (2.5, 2.5, 2.5)
  assert_eq(position_of(geometry).to_array(), [
    -2.5, -2.5, -2.5, -0.5, -0.5, -0.5, 2.5, 2.5, 2.5,
  ])
}

///|
test "BufferGeometry setFromPoints" {
  let geometry = @core.BufferGeometry::new()
  ignore(geometry.set_from_points([vec3(1, 2, 3), vec3(4, 5, 6)]))
  assert_eq(position_of(geometry).to_array(), [1.0, 2, 3, 4, 5, 6])
  // an existing attribute is updated in place, up to its size
  let attribute = geometry.attributes.get("position").unwrap()
  ignore(geometry.set_from_points([vec3(7, 8, 9)]))
  assert_eq(position_of(geometry).to_array(), [7.0, 8, 9, 4, 5, 6])
  ignore(
    geometry.set_from_points([vec3(0, 0, 0), vec3(1, 1, 1), vec3(2, 2, 2)]),
  )
  assert_eq(position_of(geometry).to_array(), [0.0, 0, 0, 1, 1, 1])
  assert_true(physical_equal(attribute.array(), position_of(geometry)))
  let flat_ = @core.BufferGeometry::new()
  ignore(flat_.set_from_points2([@math.Vector2::new(1, 2)]))
  assert_eq(position_of(flat_).to_array(), [1.0, 2, 0])
}

///|
test "BufferGeometry computeBoundingBox" {
  let bb = get_bb_for_vertices([
    -1.0, -2, -3, 13, -2, -3.5, -1, -20, 0, -4, 5, 6,
  ])
  assert_true(bb.min.x == -4 && bb.min.y == -20 && bb.min.z == -3.5)
  assert_true(bb.max.x == 13 && bb.max.y == 5 && bb.max.z == 6)
  let bb = get_bb_for_vertices([-1.0, -1, -1])
  assert_true(
    bb.min.x == bb.max.x && bb.min.y == bb.max.y && bb.min.z == bb.max.z,
  )
  assert_true(bb.min.x == -1 && bb.min.y == -1 && bb.min.z == -1)
}

///|
test "BufferGeometry computeBoundingBox without position" {
  let geometry = @core.BufferGeometry::new()
  geometry.compute_bounding_box()
  assert_true(geometry.bounding_box.unwrap().is_empty())
  geometry.compute_bounding_sphere()
  assert_eq(geometry.bounding_sphere.unwrap().radius, -1)
}

///|
test "BufferGeometry computeBoundingSphere" {
  let bs = get_bs_for_vertices([-10.0, 0, 0, 10, 0, 0])
  assert_eq(bs.radius, 10)
  assert_true(bs.center.x == 0 && bs.center.y == 0 && bs.center.y == 0)
  let bs = get_bs_for_vertices([-5.0, 11, -3, 5, -11, 3])
  let radius = vec3(5, 11, 3).length()
  assert_eq(bs.radius, radius)
  assert_true(bs.center.x == 0 && bs.center.y == 0 && bs.center.y == 0)
}

///|
test "BufferGeometry computeBoundingBox and Sphere with morph targets" {
  let geometry = geometry_with_position([0.0, 0, 0, 1, 1, 1])
  geometry.morph_attributes["position"] = [
    Buffer(@core.Float32BufferAttribute::new([2.0, 2, 2, 3, 3, 3], 3)),
  ]
  geometry.compute_bounding_box()
  assert_eq(geometry.bounding_box.unwrap().max.x, 3)
  geometry.morph_targets_relative = true
  geometry.compute_bounding_box()
  // each expansion sees the box the previous one grew, as upstream
  assert_eq(geometry.bounding_box.unwrap().max.x, 5)
  geometry.compute_bounding_sphere()
  let sphere = geometry.bounding_sphere.unwrap()
  assert_eq(sphere.center.x, 2.5)
  assert_true(approx(sphere.radius, vec3(2.5, 2.5, 2.5).length()))
}

///|
test "BufferGeometry computeBoundingBox - Float16" {
  let vertices = [-1.0, -2, -3, 13, -2, -3.5, -1, -20, 0, -4, 5, 6]
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float16BufferAttribute::new(to_half_float_array(vertices), 3),
    ),
  )
  geometry.compute_bounding_box()
  let bb = geometry.bounding_box.unwrap()
  assert_true(bb.min.x == -4 && bb.min.y == -20 && bb.min.z == -3.5)
  assert_true(bb.max.x == 13 && bb.max.y == 5 && bb.max.z == 6)
}

///|
test "BufferGeometry computeBoundingSphere - Float16" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float16BufferAttribute::new(
        to_half_float_array([-10.0, 0, 0, 10, 0, 0]),
        3,
      ),
    ),
  )
  geometry.compute_bounding_sphere()
  let bs = geometry.bounding_sphere.unwrap()
  assert_eq(bs.radius, 10)
  assert_true(bs.center.x == 0 && bs.center.y == 0 && bs.center.y == 0)
}

///|
test "BufferGeometry GLBufferAttribute needs manual bounds" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.GLBufferAttribute::new(@core.JsValue::object(), 5126, 3, 4, 3),
    ),
  )
  geometry.compute_bounding_box()
  assert_false(geometry.bounding_box.unwrap().max.x < 1.0e300)
  geometry.compute_bounding_sphere()
  assert_false(geometry.bounding_sphere.unwrap().radius < 1.0e300)
}

///|
test "BufferGeometry computeVertexNormals" {
  // get normals for a counter clockwise created triangle
  let normals = get_normals_for_vertices([-1.0, 0, 0, 1, 0, 0, 0, 1, 0])
  assert_eq(normals.to_array(), [0.0, 0, 1, 0, 0, 1, 0, 0, 1])
  // get normals for a clockwise created triangle
  let normals = get_normals_for_vertices([1.0, 0, 0, -1, 0, 0, 0, 1, 0])
  assert_eq(normals.to_array(), [0.0, 0, -1, 0, 0, -1, 0, 0, -1])
  let normals = get_normals_for_vertices([0.0, 0, 1, 0, 0, -1, 1, 1, 0])
  // the triangle is rotated by 45 degrees to the right so the normals of the three vertices
  // should point to (1, -1, 0).normalized(). A vector at 90 degrees to the normals has a dot
  // product below the floating calculation error.
  let direction = vec3(1, 1, 0).normalize()
  let difference = direction.dot(vec3(normals[0], normals[1], normals[2]))
  assert_true(difference < 2.220446049250313e-16)
  // get normals for a line should be NAN because you need min a triangle to calculate normals
  let normals = get_normals_for_vertices([1.0, 0, 0, -1, 0, 0])
  for value in normals.to_array() {
    assert_true(value == 0 || value.is_nan())
  }
}

///|
test "BufferGeometry computeVertexNormals (indexed)" {
  let sqrt = 0.5 * 2.0.sqrt()
  let normal = @core.BufferAttribute::new(
    @core.TypedArray::float32([
      -1.0, 0, 0, -1, 0, 0, -1, 0, 0, sqrt, sqrt, 0, sqrt, sqrt, 0, sqrt, sqrt, 0,
    ]),
    3,
  )
  let position = @core.BufferAttribute::new(
    @core.TypedArray::float32([
      0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5, -0.5, 0.5,
      -0.5, -0.5, 0.5, 0.5,
    ]),
    3,
  )
  // the index buffer defines the same two triangles but in counter-clockwise order,
  // which should result in flipped normals.
  let flipped_normals = normal
    .clone()
    .apply_matrix4(@math.Matrix4::new().make_scale(-1, -1, -1))
  let index = @core.BufferAttribute::new(
    @core.TypedArray::uint16([0, 2, 1, 3, 5, 4]),
    1,
  )
  let a = @core.BufferGeometry::new()
  ignore(a.set_attribute("position", position))
  a.compute_vertex_normals()
  assert_true(
    buffer_attribute_equals(Buffer(normal), a.get_attribute("normal").unwrap()),
  )
  // a second time to see if the existing normals get properly deleted
  a.compute_vertex_normals()
  assert_true(
    buffer_attribute_equals(Buffer(normal), a.get_attribute("normal").unwrap()),
  )
  // indexed geometry
  let a = @core.BufferGeometry::new()
  ignore(a.set_attribute("position", position))
  ignore(a.set_index(index))
  a.compute_vertex_normals()
  assert_true(
    buffer_attribute_equals(
      Buffer(flipped_normals),
      a.get_attribute("normal").unwrap(),
    ),
  )
}

///|
test "BufferGeometry computeTangents" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry
    .set_attribute(
      "position",
      @core.Float32BufferAttribute::new([0.0, 0, 0, 1, 0, 0, 0, 1, 0], 3),
    )
    .set_attribute(
      "normal",
      @core.Float32BufferAttribute::new([0.0, 0, 1, 0, 0, 1, 0, 0, 1], 3),
    )
    .set_attribute(
      "uv",
      @core.Float32BufferAttribute::new([0.0, 0, 1, 0, 0, 1], 2),
    )
    .set_index([0, 1, 2]),
  )
  geometry.compute_tangents()
  assert_eq(geometry.get_attribute("tangent").unwrap().array().to_array(), [
    1.0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1,
  ])
  // missing attributes leave the geometry alone
  let incomplete = geometry_with_position([0.0, 0, 0])
  incomplete.compute_tangents()
  assert_false(incomplete.has_attribute("tangent"))
}

///|
test "BufferGeometry toNonIndexed" {
  let geometry = geometry_with_position([
    0.5, 0.5, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5,
  ])
  ignore(
    geometry.set_index(
      @core.BufferAttribute::new(
        @core.TypedArray::uint16([0, 2, 1, 2, 3, 1]),
        1,
      ),
    ),
  )
  geometry.add_group(0, 3, material_index=1)
  let non_indexed = geometry.to_non_indexed()
  assert_eq(position_of(non_indexed).to_array(), [
    0.5, 0.5, 0.5, 0.5, -0.5, 0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, -0.5,
    0.5, 0.5, -0.5,
  ])
  assert_eq(non_indexed.groups[0].material_index, 1)
  assert_true(physical_equal(non_indexed.to_non_indexed(), non_indexed))
}

///|
test "BufferGeometry toNonIndexed with interleaved attributes" {
  let buffer = @core.InterleavedBuffer::new(
    @core.TypedArray::float32([1.0, 2, 9, 3, 4, 9]),
    3,
  )
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry
    .set_attribute("uv", @core.InterleavedBufferAttribute::new(buffer, 2, 0))
    .set_index([1, 0]),
  )
  let non_indexed = geometry.to_non_indexed()
  assert_eq(non_indexed.get_attribute("uv").unwrap().array().to_array(), [
    3.0, 4, 1, 2,
  ])
}

///|
test "BufferGeometry toJSON" {
  let index = @core.BufferAttribute::new(
    @core.TypedArray::uint16([0, 1, 2, 3]),
    1,
  )
  let attribute1 = @core.BufferAttribute::new(
    @core.TypedArray::uint16([1, 3, 5, 7]),
    1,
  )
  attribute1.name = "attribute1"
  let a = @core.BufferGeometry::new()
  a.name = "JSONQUnit.test"
  ignore(a.set_attribute("attribute1", attribute1))
  ignore(a.set_index(index))
  a.add_group(0, 1, material_index=2)
  a.bounding_sphere = Some(
    @math.Sphere::new(center=vec3(test_x, test_y, test_z), radius=0.5),
  )
  let attribute_gold = Json::object({
    "itemSize": Json::number(1),
    "type": Json::string("Uint16Array"),
    "array": Json::array([1.0, 3, 5, 7].map(v => Json::number(v))),
    "normalized": Json::boolean(false),
    "name": Json::string("attribute1"),
    "usage": Json::number(@core.StaticDrawUsage.to_double()),
    "gpuType": Json::number(@core.FloatType.to_double()),
  })
  let data : Map[String, Json] = {
    "attributes": Json::object({ "attribute1": attribute_gold }),
    "index": Json::object({
      "type": Json::string("Uint16Array"),
      "array": Json::array([0.0, 1, 2, 3].map(v => Json::number(v))),
    }),
    "groups": Json::array([
      Json::object({
        "start": Json::number(0),
        "count": Json::number(1),
        "materialIndex": Json::number(2),
      }),
    ]),
    "boundingSphere": Json::object({
      "center": Json::array([2.0, 3, 4].map(v => Json::number(v))),
      "radius": Json::number(0.5),
    }),
  }
  let gold : Map[String, Json] = {
    "metadata": Json::object({
      "version": Json::number(4.7),
      "type": Json::string("BufferGeometry"),
      "generator": Json::string("BufferGeometry.toJSON"),
    }),
    "uuid": Json::string(a.uuid),
    "type": Json::string("BufferGeometry"),
    "name": Json::string("JSONQUnit.test"),
    "data": Json::object(data),
  }
  assert_eq(a.to_json(), Json::object(gold))
  // add morphAttributes
  a.morph_attributes["attribute1"] = [Buffer(attribute1.clone())]
  data["morphAttributes"] = Json::object({
    "attribute1": Json::array([attribute_gold]),
  })
  data["morphTargetsRelative"] = Json::boolean(false)
  assert_eq(a.to_json(), Json::object(gold))
}

///|
test "BufferGeometry toJSON with parameters" {
  let a = @core.BufferGeometry::new()
  a.type_ = "BoxGeometry"
  a.parameters = Some({ values: { "width": Json::number(2) }, shapes: [], })
  guard a.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json.get("type").unwrap(), Json::string("BoxGeometry"))
  assert_eq(json.get("width").unwrap(), Json::number(2))
  assert_false(json.contains("data"))
  // a transformed geometry serializes its data instead
  ignore(a.translate(1, 2, 3))
  guard a.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json.get("type").unwrap(), Json::string("BufferGeometry"))
  assert_true(json.contains("data"))
}

///|
test "BufferGeometry toJSON with interleaved attributes" {
  let buffer = @core.InterleavedBuffer::new(@core.TypedArray::float32(6), 3)
  let a = @core.BufferGeometry::new()
  ignore(
    a
    .set_attribute(
      "position",
      @core.InterleavedBufferAttribute::new(buffer, 2, 0),
    )
    .set_attribute("uv", @core.InterleavedBufferAttribute::new(buffer, 1, 2)),
  )
  guard a.to_json() is Object(json) else { fail("not an object") }
  guard json.get("data") is Some(Object(data)) else { fail("no data") }
  guard data.get("interleavedBuffers") is Some(Object(buffers)) else {
    fail("no interleavedBuffers")
  }
  assert_eq(buffers.length(), 1)
  assert_true(data.contains("arrayBuffers"))
}

///|
test "BufferGeometry clone" {
  let a = @core.BufferGeometry::new()
  ignore(
    a.set_attribute(
      "attribute1",
      @core.Float32BufferAttribute::new([1.0, 2, 3, 4, 5, 6], 3),
    ),
  )
  ignore(
    a.set_attribute(
      "attribute2",
      @core.Float32BufferAttribute::new([0.0, 1, 3, 5, 6], 1),
    ),
  )
  a.add_group(0, 1, material_index=2)
  a.compute_bounding_box()
  a.compute_bounding_sphere()
  a.set_draw_range(0, 1)
  let b = a.clone()
  assert_false(physical_equal(a, b))
  assert_true(a.id != b.id)
  assert_eq(a.attributes.length(), b.attributes.length())
  assert_true(
    buffer_attribute_equals(
      a.get_attribute("attribute1").unwrap(),
      b.get_attribute("attribute1").unwrap(),
    ),
  )
  assert_true(
    buffer_attribute_equals(
      a.get_attribute("attribute2").unwrap(),
      b.get_attribute("attribute2").unwrap(),
    ),
  )
  assert_eq(b.groups[0].material_index, a.groups[0].material_index)
  assert_true(a.bounding_box.unwrap().equals(b.bounding_box.unwrap()))
  assert_true(a.bounding_sphere.unwrap().equals(b.bounding_sphere.unwrap()))
  assert_eq(a.draw_range.start, b.draw_range.start)
  assert_eq(a.draw_range.count, b.draw_range.count)
}

///|
test "BufferGeometry clone keeps subclass type and parameters" {
  let a = @core.BufferGeometry::new()
  a.type_ = "BoxGeometry"
  a.parameters = Some({ values: { "width": Json::number(2) }, shapes: [], })
  let b = a.clone()
  assert_eq(b.type_, "BoxGeometry")
  assert_eq(b.parameters.unwrap().values.get("width").unwrap(), Json::number(2))
  // a plain target does not take them
  let c = @core.BufferGeometry::new().copy(a)
  assert_true(c.parameters is None)
}

///|
test "BufferGeometry copy" {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "attrName",
      @core.Float32BufferAttribute::new([1.0, 2, 3, 4, 5, 6], 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "attrName2",
      @core.Float32BufferAttribute::new([0.0, 1, 3, 5, 6], 1),
    ),
  )
  let copy = @core.BufferGeometry::new().copy(geometry)
  assert_true(!physical_equal(copy, geometry) && geometry.id != copy.id)
  for key, attribute in geometry.attributes {
    assert_eq(
      attribute.array().to_array(),
      copy.attributes.get(key).unwrap().array().to_array(),
    )
  }
}

///|
test "BufferGeometry copy shares interleaved buffers" {
  let buffer = @core.InterleavedBuffer::new(@core.TypedArray::float32(6), 3)
  let a = @core.BufferGeometry::new()
  ignore(
    a
    .set_attribute(
      "position",
      @core.InterleavedBufferAttribute::new(buffer, 2, 0),
    )
    .set_attribute("uv", @core.InterleavedBufferAttribute::new(buffer, 1, 2)),
  )
  let b = a.clone()
  guard b.get_attribute("position") is Some(Interleaved(p)) &&
    b.get_attribute("uv") is Some(Interleaved(u)) else {
    fail("not interleaved")
  }
  assert_true(physical_equal(p.data, u.data))
  assert_false(physical_equal(p.data, buffer))
}

///|
test "BufferGeometry dispose" {
  let object = @core.BufferGeometry::new()
  let mut disposed = false
  object.add_event_listener("dispose", _ => disposed = true)
  object.dispose()
  assert_true(disposed)
}

///|
test "box3_set_from_buffer_attribute" {
  let box_ = @core.box3_set_from_buffer_attribute(
    @math.Box3::new(),
    Buffer(@core.Float32BufferAttribute::new([1.0, 2, 3, -1, -2, -3], 3)),
  )
  assert_eq(box_.max.y, 2)
  assert_eq(box_.min.z, -3)
}

///|
test "GeometryAttribute forwards to every attribute class" {
  let buffer = @core.InterleavedBuffer::new(@core.TypedArray::float32(8), 4)
  let attributes : Array[@core.GeometryAttribute] = [
    Buffer(@core.BufferAttribute::new(@core.TypedArray::float32(8), 4)),
    Interleaved(@core.InterleavedBufferAttribute::new(buffer, 4, 0)),
  ]
  for attribute in attributes {
    attribute.set_x(1, 1)
    attribute.set_y(1, 2)
    attribute.set_z(1, 3)
    attribute.set_w(1, 4)
    assert_eq(attribute.get_x(1), 1)
    assert_eq(attribute.get_y(1), 2)
    assert_eq(attribute.get_z(1), 3)
    assert_eq(attribute.get_w(1), 4)
    attribute.set_xy(0, 5, 6)
    assert_eq(attribute.get_component(0, 1), 6)
    attribute.set_component(0, 1, 7)
    assert_eq(attribute.get_y(0), 7)
    attribute.set_xyz(0, 1, 2, 3)
    attribute.set_xyzw(0, 1, 2, 3, 4)
    assert_eq(attribute.get_w(0), 4)
    assert_eq(attribute.item_size(), 4)
    assert_false(attribute.normalized())
    assert_eq(attribute.name(), "")
    attribute.set_needs_update(true)
    assert_eq(attribute.version(), 1)
  }
}

///|
fn json_field_of(json : Json, key : String) -> Json? {
  guard json is Object(fields) else { return None }
  fields.get(key)
}

///|
test "BufferGeometry copy from a plain geometry leaves parameters empty" {
  // upstream `Object.assign( {}, undefined )`: `parameters = {}`, so no `data`
  let a = @core.BufferGeometry::new()
  a.type_ = "BoxGeometry"
  a.parameters = Some({ values: { "width": Json::number(2) }, shapes: [], })
  ignore(a.copy(@core.BufferGeometry::new()))
  assert_eq(a.parameters.unwrap().values.length(), 0)
  let json = a.to_json()
  assert_eq(json_field_of(json, "type"), Some(Json::string("BoxGeometry")))
  assert_eq(json_field_of(json, "data"), None)
  assert_eq(json_field_of(json, "width"), None)
  // a transformed plain source serializes its data, typed as a plain geometry
  let source = @core.BufferGeometry::new()
  ignore(source.translate(1, 0, 0))
  ignore(a.copy(source))
  let json = a.to_json()
  assert_eq(json_field_of(json, "type"), Some(Json::string("BufferGeometry")))
  assert_true(json_field_of(json, "data") is Some(_))
}

///|
test "GeometryParameters set_lazy serializes when to_json runs" {
  let source = [1.0]
  let a = @core.BufferGeometry::new()
  a.type_ = "FooGeometry"
  let parameters : @core.GeometryParameters = {
    values: { "a": Json::null(), "b": Json::number(2) },
    shapes: [],
  }
  parameters.set_lazy("a", () => Json::number(source[0]))
  parameters.set_lazy("c", () => Json::string("c"))
  a.parameters = Some(parameters)
  source[0] = 5
  assert_eq(parameters.get("a"), Some(Json::number(5)))
  assert_eq(parameters.get("b"), Some(Json::number(2)))
  assert_eq(parameters.get("d"), None)
  assert_eq(parameters.resolved_values().keys().collect(), ["a", "b", "c"])
  guard a.to_json() is Object(json) else { fail("not an object") }
  assert_eq(json.get("a"), Some(Json::number(5)))
  assert_eq(json.get("c"), Some(Json::string("c")))
  // `copy` and `clone` carry the reference, as `Object.assign` does
  let b = @core.BufferGeometry::new()
  b.parameters = Some({ values: Map([]), shapes: [], })
  ignore(b.copy(a))
  let c = a.clone()
  source[0] = 7
  assert_eq(b.parameters.unwrap().get("a"), Some(Json::number(7)))
  assert_eq(json_field_of(c.to_json(), "a"), Some(Json::number(7)))
}

///|
test "BufferGeometry set_to_json_hook runs on both forms and stays with the class" {
  let a = @core.BufferGeometry::new()
  a.type_ = "FooGeometry"
  a.parameters = Some({ values: { "width": Json::number(2) }, shapes: [], })
  a.set_to_json_hook((geometry, data) => {
    data["extra"] = Json::string(geometry.type_)
  })
  assert_eq(
    json_field_of(a.to_json(), "extra"),
    Some(Json::string("FooGeometry")),
  )
  // `clone` keeps the class, so the override
  let clone = a.clone()
  ignore(a.translate(1, 0, 0))
  let json = a.to_json()
  assert_true(json_field_of(json, "data") is Some(_))
  assert_eq(json_field_of(json, "extra"), Some(Json::string("FooGeometry")))
  assert_true(json_field_of(clone.to_json(), "extra") is Some(_))
  // `copy` keeps the target's class
  let target = @core.BufferGeometry::new()
  target.parameters = Some({ values: Map([]), shapes: [], })
  ignore(target.copy(a))
  assert_eq(json_field_of(target.to_json(), "extra"), None)
  ignore(a.copy(@core.BufferGeometry::new()))
  assert_true(json_field_of(a.to_json(), "extra") is Some(_))
}
