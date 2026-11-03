///|
fn test_batched_data(object : @core.Object3D) -> @core.BatchedMesh {
  guard test_mesh_data(object).kind is BatchedMesh(batched) else {
    abort("not a BatchedMesh")
  }
  batched
}

///|
test "BatchedMesh setInstanceCount" {
  let box_ = test_box_geometry()
  let material = @core.MeshBasicMaterial::new()
  let batched_mesh = @core.BatchedMesh::new(
    4,
    5000,
    max_index_count=10000,
    material=Single(material),
  )
  let box_geometry_id = batched_mesh.add_geometry(box_)
  let box_instance_ids = []
  for _ in 0..<4 {
    box_instance_ids.push(batched_mesh.add_instance(box_geometry_id))
  }
  ignore(batched_mesh.delete_instance(box_instance_ids[2]))
  ignore(batched_mesh.delete_instance(box_instance_ids[3]))
  batched_mesh.set_instance_count(2)
  assert_eq(batched_mesh.instance_count(), 2)
  assert_eq(batched_mesh.max_instance_count(), 2)
}

///|
test "BatchedMesh setGeometrySize" {
  let material = @core.MeshBasicMaterial::new()
  let camera = @core.PerspectiveCamera::new()
  camera.update_matrix_world()
  let batched_mesh = @core.BatchedMesh::new(
    4,
    1000,
    max_index_count=2000,
    material=Single(material),
  )
  let batched = test_batched_data(batched_mesh)
  batched.per_object_frustum_culled = false
  batched.sort_objects = false
  ignore(batched_mesh.add_geometry(test_box_geometry()))
  let geometry_id = batched_mesh.add_geometry(test_box_geometry())
  ignore(batched_mesh.add_instance(geometry_id))
  let renderer = @core.JsValue::object()
  let scene = @core.Object3D::new()
  (batched_mesh.on_before_render)(
    renderer,
    scene,
    camera,
    test_mesh_data(batched_mesh).geometry,
    material,
    None,
  )
  batched_mesh.set_geometry_size(70000, 2000)
  (batched_mesh.on_before_render)(
    renderer,
    scene,
    camera,
    test_mesh_data(batched_mesh).geometry,
    material,
    None,
  )
  let start = batched_mesh.get_geometry_range_at(geometry_id).start
  assert_eq(batched._multi_draw_starts[0], (start * 4).to_double())
}

///|
test "panic BatchedMesh setGeometrySize refuses to shrink below reserved data" {
  let batched_mesh = @core.BatchedMesh::new(4, 1000)
  ignore(batched_mesh.add_geometry(test_box_geometry()))
  batched_mesh.set_geometry_size(10, 2000)
}

///|
test "BatchedMesh counts" {
  let object = @core.BatchedMesh::new(2, 100)
  assert_true(object.is_batched_mesh())
  assert_eq(object.type_, "Mesh")
  assert_eq(object.unused_vertex_count(), 100)
  assert_eq(object.unused_index_count(), 200)
  let id = object.add_geometry(test_box_geometry())
  assert_eq(object.unused_vertex_count(), 76)
  assert_eq(object.unused_index_count(), 164)
  let range = object.get_geometry_range_at(id)
  assert_eq((range.vertex_count, range.index_count), (24, 36))
  assert_eq((range.start, range.count), (0, 36))
}

///|
test "BatchedMesh reserved space and ids are reused" {
  let object = @core.BatchedMesh::new(4, 100)
  let a = object.add_geometry(test_box_geometry(), reserved_vertex_count=30)
  let b = object.add_geometry(test_box_geometry())
  assert_eq((a, b), (0, 1))
  assert_eq(object.get_geometry_range_at(b).vertex_start, 30)
  assert_eq(object.get_geometry_range_at(b).index_start, 36)
  ignore(object.delete_geometry(a))
  let c = object.add_geometry(test_box_geometry())
  assert_eq(c, 0)
  let i0 = object.add_instance(c)
  let i1 = object.add_instance(b)
  ignore(object.delete_instance(i0))
  assert_eq(object.instance_count(), 1)
  assert_eq(object.add_instance(b), i0)
  assert_eq(i1, 1)
}

///|
test "panic BatchedMesh invalid instance id" {
  let object = @core.BatchedMesh::new(2, 100)
  ignore(object.get_visible_at(0))
}

///|
test "panic BatchedMesh requires consistent attributes" {
  let object = @core.BatchedMesh::new(2, 100)
  ignore(object.add_geometry(test_plane_geometry()))
  ignore(object.add_geometry(test_box_geometry()))
}

///|
test "BatchedMesh matrices and colors" {
  let object = @core.BatchedMesh::new(4, 100)
  let id = object.add_geometry(test_box_geometry())
  let instance = object.add_instance(id)
  ignore(
    object.set_matrix_at(
      instance,
      @math.Matrix4::new().make_translation(1, 2, 3),
    ),
  )
  let matrix = object.get_matrix_at(instance, @math.Matrix4::new())
  assert_eq(matrix.elements[13], 2)
  let color = @math.Color::new(0, 0, 0)
  ignore(object.get_color_at(instance, color))
  assert_eq((color.r, color.g, color.b), (1, 1, 1))
  let v4 = object.get_color_at_vector4(instance, @math.Vector4::new(0, 0, 0, 0))
  assert_eq(v4.w, 1)
  ignore(object.set_color_at(instance, @math.Color::new(0.5, 0, 0)))
  ignore(object.get_color_at(instance, color))
  assert_eq((color.r, color.g, color.b), (0.5, 0, 0))
  ignore(
    object.set_color_at_vector4(instance, @math.Vector4::new(0, 0.5, 0, 0.25)),
  )
  let v4 = object.get_color_at_vector4(instance, @math.Vector4::new(0, 0, 0, 0))
  assert_eq((v4.x, v4.y, v4.z, v4.w), (0, 0.5, 0, 0.25))
}

///|
test "BatchedMesh visibility and geometry ids" {
  let object = @core.BatchedMesh::new(4, 100)
  let a = object.add_geometry(test_box_geometry())
  let b = object.add_geometry(test_box_geometry())
  let instance = object.add_instance(a)
  assert_true(object.get_visible_at(instance))
  ignore(object.set_visible_at(instance, false))
  assert_false(object.get_visible_at(instance))
  ignore(object.set_geometry_id_at(instance, b))
  assert_eq(object.get_geometry_id_at(instance), b)
}

///|
test "BatchedMesh bounds" {
  let object = @core.BatchedMesh::new(4, 100)
  let id = object.add_geometry(test_box_geometry())
  let a = object.add_instance(id)
  let b = object.add_instance(id)
  ignore(
    object.set_matrix_at(b, @math.Matrix4::new().make_translation(4, 0, 0)),
  )
  let box_at = object.get_bounding_box_at(id, @math.Box3::new()).unwrap()
  assert_true(box_at.max.equals(vec3(0.5, 0.5, 0.5)))
  assert_true(object.get_bounding_box_at(5, @math.Box3::new()) is None)
  let sphere_at = object
    .get_bounding_sphere_at(id, @math.Sphere::new())
    .unwrap()
  assert_true(approx(sphere_at.radius, 0.75.sqrt()))
  object.compute_bounding_box()
  let box_ = test_batched_data(object).bounding_box.unwrap()
  assert_true(box_.max.equals(vec3(4.5, 0.5, 0.5)))
  object.compute_bounding_sphere()
  let sphere = test_batched_data(object).bounding_sphere.unwrap()
  assert_true(approx(sphere.center.x, 2))
  ignore(a)
}

///|
test "BatchedMesh raycast reports the batch id" {
  let object = @core.BatchedMesh::new(4, 100)
  let id = object.add_geometry(test_box_geometry())
  let a = object.add_instance(id)
  let b = object.add_instance(id)
  ignore(
    object.set_matrix_at(b, @math.Matrix4::new().make_translation(4, 0, 0)),
  )
  let raycaster = @core.Raycaster::new(
    origin=vec3(4.25, 0.1, 5),
    direction=vec3(0, 0, -1),
  )
  let intersects = []
  object.raycast(raycaster, intersects)
  assert_eq(intersects.length(), 1)
  assert_eq(intersects[0].batch_id, Some(b))
  assert_true(physical_equal(intersects[0].object, object))
  assert_true(approx(intersects[0].distance, 4.5))
  ignore(object.set_visible_at(b, false))
  intersects.clear()
  object.raycast(raycaster, intersects)
  assert_eq(intersects.length(), 0)
  ignore(a)
}

///|
fn test_sorted_batch() -> (@core.Object3D, @core.Object3D, @core.Material) {
  let material = @core.MeshBasicMaterial::new()
  let object = @core.BatchedMesh::new(3, 100, material=Single(material))
  let id = object.add_geometry(test_box_geometry())
  for z in [-10.0, -30.0, -20.0] {
    let instance = object.add_instance(id)
    ignore(
      object.set_matrix_at(
        instance,
        @math.Matrix4::new().make_translation(0, 0, z),
      ),
    )
  }
  object.update_matrix_world()
  let camera = @core.PerspectiveCamera::new(far=2000)
  camera.update_matrix_world()
  (object, camera, material)
}

///|
test "BatchedMesh sorts opaque front to back and transparent back to front" {
  let (object, camera, material) = test_sorted_batch()
  let batched = test_batched_data(object)
  let geometry = test_mesh_data(object).geometry
  object._update_draw_parameters(camera, geometry, material)
  assert_eq(batched._multi_draw_count, 3)
  let indirect = batched._indirect_texture.unwrap()
  guard indirect.source.data is DataImage({ data: Some(data), .. }) else {
    fail("not a data image")
  }
  assert_eq((data[0], data[1], data[2]), (0, 2, 1))
  material.transparent = true
  object._update_draw_parameters(camera, geometry, material)
  assert_eq((data[0], data[1], data[2]), (1, 2, 0))
}

///|
test "BatchedMesh custom sort and merged draws" {
  let (object, camera, material) = test_sorted_batch()
  let batched = test_batched_data(object)
  let geometry = test_mesh_data(object).geometry
  ignore(object.set_custom_sort(Some(fn(list, _) { list.rev_in_place() })))
  object._update_draw_parameters(
    camera,
    geometry,
    material,
    draw_format="merged",
  )
  // every instance draws the same range, so they merge into one draw
  assert_eq(batched._merged_draw_count, 1)
  assert_eq(batched._merged_draw_instance_counts[0], 3)
  assert_eq(batched._multi_draw_count, 3)
}

///|
test "BatchedMesh frustum culling drops instances behind the camera" {
  let (object, camera, material) = test_sorted_batch()
  ignore(
    object.set_matrix_at(0, @math.Matrix4::new().make_translation(0, 0, 50)),
  )
  object._update_draw_parameters(
    camera,
    test_mesh_data(object).geometry,
    material,
  )
  assert_eq(test_batched_data(object)._multi_draw_count, 2)
}

///|
test "BatchedMesh onBeforeRender skips draw setup for WebGPU" {
  let (object, camera, material) = test_sorted_batch()
  let renderer = @core.JsValue::object()
  renderer.set("isWebGPURenderer", @core.JsValue::of(true))
  let batched = test_batched_data(object)
  let version = batched._indirect_texture.unwrap().version
  (object.on_before_render)(
    renderer,
    @core.Object3D::new(),
    camera,
    test_mesh_data(object).geometry,
    material,
    None,
  )
  assert_eq(batched._multi_draw_count, 0)
  assert_eq(batched._indirect_texture.unwrap().version, version + 1)
}

///|
test "BatchedMesh optimize compacts deleted geometry" {
  let object = @core.BatchedMesh::new(4, 100)
  let a = object.add_geometry(test_box_geometry())
  let b = object.add_geometry(test_box_geometry())
  ignore(object.delete_geometry(a))
  ignore(object.optimize())
  let range = object.get_geometry_range_at(b)
  assert_eq((range.vertex_start, range.index_start, range.start), (0, 0, 0))
  assert_eq(object.unused_vertex_count(), 76)
  // indices were shifted back with the vertices
  let index = test_mesh_data(object).geometry.index.unwrap()
  assert_eq(index.get_x(1), 1)
}

///|
test "BatchedMesh copy" {
  let object = @core.BatchedMesh::new(4, 100)
  let id = object.add_geometry(test_box_geometry())
  let instance = object.add_instance(id)
  ignore(
    object.set_matrix_at(
      instance,
      @math.Matrix4::new().make_translation(1, 2, 3),
    ),
  )
  ignore(object.set_color_at(instance, @math.Color::new(0.5, 0, 0)))
  let copy = object.clone()
  assert_true(copy.is_batched_mesh())
  assert_eq(copy.instance_count(), 1)
  assert_eq(copy.max_instance_count(), 4)
  assert_eq(copy.get_matrix_at(instance, @math.Matrix4::new()).elements[12], 1)
  let copy_data = test_batched_data(copy)
  let source_data = test_batched_data(object)
  assert_false(
    physical_equal(copy_data._geometry_info, source_data._geometry_info),
  )
  assert_false(
    physical_equal(copy_data._instance_info[0], source_data._instance_info[0]),
  )
  assert_false(
    physical_equal(
      test_mesh_data(copy).geometry,
      test_mesh_data(object).geometry,
    ),
  )
}

///|
test "BatchedMesh dispose" {
  let object = @core.BatchedMesh::new(4, 100)
  object.dispose()
  assert_true(test_batched_data(object)._matrices_texture is None)
  assert_true(test_batched_data(object)._indirect_texture is None)
}
