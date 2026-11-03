///|
fn test_skinned_data(object : @core.Object3D) -> @core.SkinnedMesh {
  guard test_mesh_data(object).kind is SkinnedMesh(skinned) else {
    abort("not a SkinnedMesh")
  }
  skinned
}

///|
/// One vertex at `( 1, 0, 0 )` following the second bone completely.
fn test_skinned_mesh() -> (@core.Object3D, Array[@core.Object3D]) {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([1.0, 0.0, 0.0], 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "skinIndex",
      @core.Uint16BufferAttribute::new([1.0, 0.0, 0.0, 0.0], 4),
    ),
  )
  ignore(
    geometry.set_attribute(
      "skinWeight",
      @core.Float32BufferAttribute::new([2.0, 0.0, 0.0, 0.0], 4),
    ),
  )
  let mesh = @core.SkinnedMesh::new(geometry~)
  let root = @core.Bone::new()
  let child = @core.Bone::new()
  ignore(root.add(child))
  root.update_matrix_world()
  mesh.bind(@core.Skeleton::new(bones=[root, child]))
  (mesh, [root, child])
}

///|
test "SkinnedMesh type" {
  let object = @core.SkinnedMesh::new()
  assert_eq(object.type_, "SkinnedMesh")
  assert_true(object.is_mesh())
  assert_true(object.is_skinned_mesh())
  assert_eq(test_skinned_data(object).bind_mode, @core.AttachedBindMode)
}

///|
test "SkinnedMesh normalizeSkinWeights" {
  let (mesh, _) = test_skinned_mesh()
  mesh.normalize_skin_weights()
  let attribute = test_mesh_data(mesh).geometry.attributes["skinWeight"]
  assert_eq(attribute.get_x(0), 1)
}

///|
test "SkinnedMesh applyBoneTransform" {
  let (mesh, bones) = test_skinned_mesh()
  mesh.normalize_skin_weights()
  bones[1].position.y = 3
  bones[0].update_matrix_world()
  assert_true(mesh.apply_bone_transform(0, vec3(1, 0, 0)).equals(vec3(1, 3, 0)))
  let v4 = mesh.apply_bone_transform_vector4(0, @math.Vector4::new(1, 0, 0, 1))
  assert_eq((v4.x, v4.y, v4.z, v4.w), (1, 3, 0, 1))
}

///|
test "SkinnedMesh getVertexPosition and bounds follow the bones" {
  let (mesh, bones) = test_skinned_mesh()
  mesh.normalize_skin_weights()
  bones[1].position.z = 4
  bones[0].update_matrix_world()
  assert_true(mesh.get_vertex_position(0, vec3(0, 0, 0)).equals(vec3(1, 0, 4)))
  mesh.compute_bounding_box()
  let box_ = test_skinned_data(mesh).bounding_box.unwrap()
  assert_true(box_.min.equals(vec3(1, 0, 4)))
  mesh.compute_bounding_sphere()
  let sphere = test_skinned_data(mesh).bounding_sphere.unwrap()
  assert_true(sphere.center.equals(vec3(1, 0, 4)))
}

///|
test "SkinnedMesh updateMatrixWorld updates bindMatrixInverse" {
  let mesh = @core.SkinnedMesh::new()
  let skinned = test_skinned_data(mesh)
  mesh.position.x = 2
  mesh.update_matrix_world()
  assert_eq(skinned.bind_matrix_inverse.elements[12], -2)
  skinned.bind_mode = @core.DetachedBindMode
  ignore(skinned.bind_matrix.make_translation(3, 0, 0))
  mesh.update_matrix_world()
  assert_eq(skinned.bind_matrix_inverse.elements[12], -3)
}

///|
test "SkinnedMesh copy" {
  let (mesh, _) = test_skinned_mesh()
  mesh.compute_bounding_box()
  let copy = test_skinned_data(mesh.clone())
  let source = test_skinned_data(mesh)
  assert_true(physical_equal(copy.skeleton.unwrap(), source.skeleton.unwrap()))
  assert_false(
    physical_equal(copy.bounding_box.unwrap(), source.bounding_box.unwrap()),
  )
  assert_true(copy.bounding_box.unwrap().equals(source.bounding_box.unwrap()))
  assert_true(copy.bounding_sphere is None)
}
