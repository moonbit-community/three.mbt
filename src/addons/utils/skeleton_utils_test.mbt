// Checks of skeleton_utils.mbt (upstream has no unit tests for SkeletonUtils).

///|
/// A root group holding a skinned mesh bound to a two-bone chain `<prefix>hip` ->
/// `<prefix>spine`.
fn skut_rig(prefix : String) -> (@core.Object3D, @core.Object3D) {
  let root = @core.Group::new()
  let hip = @core.Bone::new()
  hip.name = prefix + "hip"
  let spine = @core.Bone::new()
  spine.name = prefix + "spine"
  ignore(spine.position.set(0.0, 1.0, 0.0))
  ignore(hip.add(spine))
  let mesh = @core.SkinnedMesh::new(geometry=@geometries.BoxGeometry::new())
  mesh.name = prefix + "mesh"
  ignore(root.add(hip))
  ignore(root.add(mesh))
  root.update_matrix_world(force=true)
  mesh.bind(@core.Skeleton::new(bones=[hip, spine]))
  (root, mesh)
}

///|
fn skut_skeleton(mesh : @core.Object3D) -> @core.Skeleton {
  guard mesh.kind is Mesh({ kind: SkinnedMesh({ skeleton: Some(s), .. }), .. }) else {
    abort("not a bound SkinnedMesh")
  }
  s
}

///|
test "clone rebinds skinned meshes to the cloned bones" {
  let (root, mesh) = skut_rig("")
  let clone = @utils.SkeletonUtils::clone(root)
  let cloned_mesh = clone.get_object_by_name("mesh").unwrap()
  let cloned_hip = clone.get_object_by_name("hip").unwrap()
  let bones = skut_skeleton(cloned_mesh).bones
  assert_eq(bones.length(), 2)
  assert_true(physical_equal(bones[0], cloned_hip))
  assert_true(!physical_equal(bones[0], skut_skeleton(mesh).bones[0]))
  assert_eq(bones[1].name, "spine")
  assert_true(!physical_equal(skut_skeleton(cloned_mesh), skut_skeleton(mesh)))
}

///|
test "retarget copies source rotations through the name map" {
  let (_, target) = skut_rig("t_")
  let (_, source) = skut_rig("s_")
  let source_spine = skut_skeleton(source).bones[1]
  ignore(source_spine.rotation.set(0.0, 0.0, 0.5))
  let options = @utils.RetargetOptions::new(
    names={ "t_hip": "s_hip", "t_spine": "s_spine" },
    hip="s_hip",
  )
  @utils.SkeletonUtils::retarget(Object(target), Object(source), options~)
  let spine = skut_skeleton(target).bones[1]
  assert_true((spine.rotation.z - 0.5).abs() < 1.0e-9)
  // positions are kept except for the hip
  assert_eq(spine.position.y, 1.0)
}

///|
test "retarget with a Skeleton target forces the target matrix" {
  let (_, target) = skut_rig("t_")
  let (_, source) = skut_rig("s_")
  let options = @utils.RetargetOptions::new()
  @utils.SkeletonUtils::retarget(
    Skeleton(skut_skeleton(target)),
    Object(source),
    options~,
  )
  assert_true(options.use_target_matrix)
  assert_true(!options.preserve_bone_matrix)
}

///|
test "retargetClip records quaternion and hip position tracks" {
  let (_, target) = skut_rig("")
  let (_, source) = skut_rig("")
  let clip = @animation.AnimationClip::new(name="turn", tracks=[
    @animation.QuaternionKeyframeTrack::new(
      ".bones[spine].quaternion",
      [0.0, 1.0],
      [0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.479425538604203, 0.8775825618903728],
    ),
  ])
  let options = @utils.RetargetOptions::new(fps=4.0)
  let result = @utils.SkeletonUtils::retarget_clip(
    target,
    Object(source),
    clip,
    options~,
  )
  let names = result.tracks.map(track => track.name)
  assert_eq(names, [
    ".bones[hip].position", ".bones[hip].quaternion", ".bones[spine].quaternion",
  ])
  assert_eq(result.tracks[2].times.length(), 4)
  assert_eq(result.name, "turn")
}
