///|
test "Skeleton dispose" {
  let object = @core.Skeleton::new()
  object.dispose()
}

///|
fn test_two_bones() -> Array[@core.Object3D] {
  let root = @core.Bone::new()
  let child = @core.Bone::new()
  ignore(root.add(child))
  root.position.y = -5
  child.position.y = 5
  root.update_matrix_world()
  [root, child]
}

///|
test "Skeleton constructor computes inverses" {
  let bones = test_two_bones()
  let skeleton = @core.Skeleton::new(bones~)
  assert_false(physical_equal(skeleton.bones, bones))
  assert_eq(skeleton.bone_inverses.length(), 2)
  assert_eq(skeleton.bone_matrices.unwrap().length(), 32)
  let identity = @math.Matrix4::new()
  let product = @math.Matrix4::new().multiply_matrices(
    bones[0].matrix_world,
    skeleton.bone_inverses[0],
  )
  assert_true(matrix_equals4(product, identity))
}

///|
test "Skeleton mismatched inverses are replaced" {
  let skeleton = @core.Skeleton::new(bones=test_two_bones(), bone_inverses=[
    @math.Matrix4::new().make_translation(1, 2, 3),
  ])
  assert_eq(skeleton.bone_inverses.length(), 2)
  assert_true(matrix_equals4(skeleton.bone_inverses[0], @math.Matrix4::new()))
}

///|
test "Skeleton update writes the offset matrices" {
  let bones = test_two_bones()
  let skeleton = @core.Skeleton::new(bones~)
  bones[1].position.x = 2
  bones[0].update_matrix_world()
  skeleton.update()
  let matrices = skeleton.bone_matrices.unwrap()
  // the root did not move, so its slot is the identity
  for i in 0..<16 {
    assert_eq(matrices[i], @math.Matrix4::new().elements[i])
  }
  assert_eq(matrices[16 + 12], 2)
}

///|
test "Skeleton pose restores the bind pose" {
  let bones = test_two_bones()
  let skeleton = @core.Skeleton::new(bones~)
  bones[0].position.x = 7
  bones[1].position.x = 3
  bones[0].update_matrix_world()
  skeleton.pose()
  assert_true(bones[0].position.equals(vec3(0, -5, 0)))
  assert_true(bones[1].position.equals(vec3(0, 5, 0)))
}

///|
test "Skeleton computeBoneTexture" {
  let skeleton = @core.Skeleton::new(bones=test_two_bones())
  ignore(skeleton.compute_bone_texture())
  let texture = skeleton.bone_texture.unwrap()
  assert_eq(skeleton.bone_matrices.unwrap().length(), 4 * 4 * 4)
  guard texture.source.data is DataImage({ width, height, .. }) else {
    fail("not a data image")
  }
  assert_eq((width, height), (4, 4))
  let version = texture.version
  skeleton.update()
  assert_eq(texture.version, version + 1)
  skeleton.dispose()
  assert_true(skeleton.bone_texture is None)
}

///|
test "Skeleton getBoneByName" {
  let bones = test_two_bones()
  bones[1].name = "child"
  let skeleton = @core.Skeleton::new(bones~)
  assert_true(
    physical_equal(skeleton.get_bone_by_name("child").unwrap(), bones[1]),
  )
  assert_true(skeleton.get_bone_by_name("nothing") is None)
}

///|
test "Skeleton clone shares the inverses" {
  let skeleton = @core.Skeleton::new(bones=test_two_bones())
  let clone = skeleton.clone()
  assert_true(physical_equal(clone.bone_inverses, skeleton.bone_inverses))
  assert_false(physical_equal(clone.bones, skeleton.bones))
  assert_false(clone.uuid == skeleton.uuid)
}

///|
test "Skeleton toJSON and fromJSON" {
  let bones = test_two_bones()
  let skeleton = @core.Skeleton::new(bones~)
  let json = skeleton.to_json()
  guard json is Object(data) else { fail("not an object") }
  assert_eq(data["uuid"], Json::string(skeleton.uuid))
  let by_uuid = Map::from_array(bones.map(bone => (bone.uuid, bone)))
  let restored = @core.Skeleton::new().from_json(json, by_uuid)
  assert_eq(restored.uuid, skeleton.uuid)
  assert_eq(restored.bones.length(), 2)
  assert_true(physical_equal(restored.bones[1], bones[1]))
  assert_true(
    matrix_equals4(restored.bone_inverses[1], skeleton.bone_inverses[1]),
  )
}
