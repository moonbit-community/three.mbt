///|
fn test_instanced_data(object : @core.Object3D) -> @core.InstancedMesh {
  guard test_mesh_data(object).kind is InstancedMesh(instanced) else {
    abort("not an InstancedMesh")
  }
  instanced
}

///|
test "InstancedMesh basics" {
  let object = @core.InstancedMesh::new(0)
  assert_true(object.is_mesh())
  assert_true(object.is_instanced_mesh())
  assert_eq(object.type_, "Mesh")
}

///|
test "InstancedMesh dispose" {
  let object = @core.InstancedMesh::new(1)
  object.dispose()
}

///|
test "InstancedMesh starts with identity matrices" {
  let object = @core.InstancedMesh::new(2)
  assert_eq(test_mesh_data(object).count, 2)
  assert_eq(test_instanced_data(object).instance_matrix.array.length(), 32)
  let matrix = object.get_matrix_at(1, @math.Matrix4::new().make_scale(2, 2, 2))
  assert_true(matrix_equals4(matrix, @math.Matrix4::new()))
}

///|
test "InstancedMesh setMatrixAt writes Float32 data in place" {
  let object = @core.InstancedMesh::new(3)
  let array = test_instanced_data(object).instance_matrix.array
  ignore(
    object.set_matrix_at(1, @math.Matrix4::new().make_translation(1, 2, 3)),
  )
  assert_true(
    physical_equal(array, test_instanced_data(object).instance_matrix.array),
  )
  assert_eq(array[16 + 12], 1)
  assert_eq(array[16 + 13], 2)
  assert_eq(array[16 + 14], 3)
  assert_eq(array[0 + 12], 0)
  let matrix = object.get_matrix_at(1, @math.Matrix4::new())
  assert_eq(matrix.elements[14], 3)
}

///|
test "InstancedMesh colors" {
  let object = @core.InstancedMesh::new(2)
  let color = @math.Color::new(0, 0, 0)
  ignore(object.get_color_at(1, color))
  assert_eq((color.r, color.g, color.b), (1, 1, 1))
  ignore(object.set_color_at(1, @math.Color::new(0.5, 0.25, 0)))
  let instance_color = test_instanced_data(object).instance_color.unwrap()
  assert_eq(instance_color.array.to_array(), [1, 1, 1, 0.5, 0.25, 0])
  assert_eq(instance_color.mesh_per_attribute, 1)
  assert_true(instance_color.is_instanced_buffer_attribute())
  ignore(object.get_color_at(1, color))
  assert_eq((color.r, color.g, color.b), (0.5, 0.25, 0))
}

///|
test "InstancedMesh morphs" {
  let object = @core.InstancedMesh::new(2)
  let source = @core.Mesh::new(geometry=test_morph_geometry())
  let influences = test_mesh_data(source).morph_target_influences.unwrap()
  influences[0] = 0.25
  ignore(object.set_morph_at(1, source))
  let texture = test_instanced_data(object).morph_texture.unwrap()
  guard texture.source.data
    is DataImage({ data: Some(data), width, height, .. }) else {
    fail("not a data image")
  }
  assert_eq((width, height), (2, 2))
  assert_eq(data.to_array(), [0, 0, 0.75, 0.25])
  influences[0] = 0
  object.get_morph_at(1, source)
  assert_eq(influences[0], 0.25)
}

///|
test "InstancedMesh does not take morph targets from the geometry" {
  let object = @core.InstancedMesh::new(geometry=test_morph_geometry(), 1)
  assert_true(test_mesh_data(object).morph_target_influences is None)
}

///|
test "InstancedMesh bounds" {
  let object = @core.InstancedMesh::new(geometry=test_box_geometry(), 2)
  ignore(
    object.set_matrix_at(1, @math.Matrix4::new().make_translation(10, 0, 0)),
  )
  object.compute_bounding_box()
  let box_ = test_instanced_data(object).bounding_box.unwrap()
  assert_true(box_.min.equals(vec3(-0.5, -0.5, -0.5)))
  assert_true(box_.max.equals(vec3(10.5, 0.5, 0.5)))
  object.compute_bounding_sphere()
  let sphere = test_instanced_data(object).bounding_sphere.unwrap()
  assert_true(approx(sphere.center.x, 5))
}

///|
test "InstancedMesh raycast reports the instance" {
  let object = @core.InstancedMesh::new(geometry=test_box_geometry(), 3)
  ignore(
    object.set_matrix_at(1, @math.Matrix4::new().make_translation(10, 0, 0)),
  )
  ignore(
    object.set_matrix_at(2, @math.Matrix4::new().make_translation(0, 10, 0)),
  )
  let raycaster = @core.Raycaster::new(
    origin=vec3(10.25, 0.1, 5),
    direction=vec3(0, 0, -1),
  )
  let intersects = []
  object.raycast(raycaster, intersects)
  assert_eq(intersects.length(), 1)
  assert_eq(intersects[0].instance_id, Some(1))
  assert_true(physical_equal(intersects[0].object, object))
  assert_true(approx(intersects[0].distance, 4.5))
}

///|
test "InstancedMesh copy" {
  let object = @core.InstancedMesh::new(geometry=test_box_geometry(), 2)
  ignore(
    object.set_matrix_at(1, @math.Matrix4::new().make_translation(1, 2, 3)),
  )
  ignore(object.set_color_at(0, @math.Color::new(1, 0, 0)))
  let copy = object.clone()
  assert_true(copy.is_instanced_mesh())
  assert_eq(test_mesh_data(copy).count, 2)
  let matrix = copy.get_matrix_at(1, @math.Matrix4::new())
  assert_eq(matrix.elements[13], 2)
  let source_data = test_instanced_data(object)
  let copy_data = test_instanced_data(copy)
  assert_false(
    physical_equal(
      source_data.instance_color.unwrap().array,
      copy_data.instance_color.unwrap().array,
    ),
  )
}
