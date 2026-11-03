///|
test "Mesh type" {
  let object = @core.Mesh::new()
  assert_eq(object.type_, "Mesh")
  assert_true(object.is_mesh())
  assert_false(object.is_skinned_mesh())
}

///|
test "Mesh copy/material" {
  let mesh1 = @core.Mesh::new()
  test_mesh_data(mesh1).material = Multiple([@core.Material::new()])
  let copy1 = mesh1.clone()
  assert_false(
    test_same_slot(
      test_mesh_data(mesh1).material,
      test_mesh_data(copy1).material,
    ),
  )
  let mesh2 = @core.Mesh::new()
  let copy2 = mesh2.clone()
  assert_true(
    test_same_slot(
      test_mesh_data(mesh2).material,
      test_mesh_data(copy2).material,
    ),
  )
}

///|
test "Mesh copy/morphTargets" {
  let mesh = @core.Mesh::new(geometry=test_morph_geometry())
  let influences = test_mesh_data(mesh).morph_target_influences.unwrap()
  influences[0] = 0.5
  let copy = test_mesh_data(mesh.clone())
  assert_eq(copy.morph_target_influences, Some([0.5]))
  assert_false(
    physical_equal(copy.morph_target_influences.unwrap(), influences),
  )
  assert_eq(
    copy.morph_target_dictionary,
    Some(Map::from_array([("target", 0)])),
  )
}

///|
test "Mesh updateMorphTargets uses index names when unnamed" {
  let geometry = test_morph_geometry()
  let target = @core.Float32BufferAttribute::new(
    [0.0, 0.0, 1.0, 0.0, 0.0, 1.0],
    3,
  )
  geometry.morph_attributes["position"].push(Buffer(target))
  let mesh = test_mesh_data(@core.Mesh::new(geometry~))
  assert_eq(mesh.morph_target_influences, Some([0.0, 0.0]))
  assert_eq(
    mesh.morph_target_dictionary,
    Some(Map::from_array([("target", 0), ("1", 1)])),
  )
}

///|
test "Mesh getVertexPosition with morph targets" {
  let mesh = @core.Mesh::new(geometry=test_morph_geometry())
  test_mesh_data(mesh).morph_target_influences.unwrap()[0] = 0.5
  let position = mesh.get_vertex_position(1, vec3(0, 0, 0))
  // absolute targets: 1 + 0.5 * ( 0 - 1 ), 1 + 0.5 * ( 1 - 1 ), 1 + 0.5 * ( 0 - 1 )
  assert_true(position.equals(vec3(0.5, 1, 0.5)))
  test_mesh_data(mesh).geometry.morph_targets_relative = true
  let relative = mesh.get_vertex_position(1, vec3(0, 0, 0))
  assert_true(relative.equals(vec3(1, 1.5, 1)))
}

///|
test "Mesh raycast" {
  let mesh = @core.Mesh::new(
    geometry=test_plane_geometry(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  let raycaster = @core.Raycaster::new()
  ignore(raycaster.ray.origin.set(0.25, 0.25, 1))
  ignore(raycaster.ray.direction.set(0, 0, -1))
  let intersections = []
  mesh.raycast(raycaster, intersections)
  // the point lies on the shared edge of the two triangles
  assert_eq(intersections.length(), 2)
  let intersection = intersections[0]
  assert_true(physical_equal(intersection.object, mesh))
  assert_eq(intersection.distance, 1.0)
  assert_eq(intersection.face_index, Some(0))
  let face = intersection.face.unwrap()
  assert_eq((face.a, face.b, face.c), (0, 2, 1))
  assert_true(intersection.point.equals(vec3(0.25, 0.25, 0)))
  let uv = intersection.uv.unwrap()
  assert_eq((uv.x, uv.y), (0.75, 0.75))
}

///|
test "Mesh raycast/range" {
  let material = @core.MeshBasicMaterial::new()
  material.side = @core.DoubleSide
  let mesh = @core.Mesh::new(
    geometry=test_box_geometry(),
    material=Single(material),
  )
  let raycaster = @core.Raycaster::new()
  let intersections = []
  ignore(raycaster.ray.origin.set(0, 0, 0))
  ignore(raycaster.ray.direction.set(1, 0, 0))
  raycaster.near = 100
  raycaster.far = 200
  fn cast(x : Double) -> Int32 {
    ignore(mesh.matrix_world.identity())
    mesh.position.x = x
    mesh.update_matrix_world(force=true)
    intersections.clear()
    mesh.raycast(raycaster, intersections)
    intersections.length()
  }

  assert_true(cast(150) > 0)
  assert_true(cast(raycaster.near) > 0)
  assert_true(cast(raycaster.far) > 0)
  mesh.scale.y = 9999
  assert_true(cast(150) > 0)
  assert_eq(cast(-9999), 0)
  assert_eq(cast(9999), 0)
}

///|
test "Mesh raycast with groups and a material array" {
  let geometry = test_plane_geometry()
  geometry.add_group(0, 3, material_index=1)
  geometry.add_group(3, 3, material_index=0)
  let front = @core.MeshBasicMaterial::new()
  let back = @core.MeshBasicMaterial::new()
  back.side = @core.BackSide
  let mesh = @core.Mesh::new(geometry~, material=Multiple([front, back]))
  let raycaster = @core.Raycaster::new(
    origin=vec3(0.25, 0, 1),
    direction=vec3(0, 0, -1),
  )
  let intersections = []
  mesh.raycast(raycaster, intersections)
  assert_eq(intersections.length(), 1)
  assert_eq(intersections[0].face_index, Some(1))
  assert_eq(intersections[0].face.unwrap().material_index, 0)
}

///|
test "Mesh raycast honours drawRange" {
  let geometry = test_plane_geometry()
  geometry.set_draw_range(0, 3)
  let mesh = @core.Mesh::new(geometry~)
  let raycaster = @core.Raycaster::new(
    origin=vec3(0.25, 0, 1),
    direction=vec3(0, 0, -1),
  )
  let intersections = []
  mesh.raycast(raycaster, intersections)
  assert_eq(intersections.length(), 0)
}
