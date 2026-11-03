///|
fn get_clips(
  pos1 : @math.Vector3,
  pos2 : @math.Vector3,
  scale1 : @math.Vector3,
  scale2 : @math.Vector3,
  dur : Double,
) -> Array[@animation.AnimationClip] {
  let clips = []
  let mut track = @animation.VectorKeyframeTrack::new(".scale", [0.0, dur], [
    scale1.x,
    scale1.y,
    scale1.z,
    scale2.x,
    scale2.y,
    scale2.z,
  ])
  clips.push(
    @animation.AnimationClip::new(name="scale", duration=dur, tracks=[track]),
  )
  track = @animation.VectorKeyframeTrack::new(".position", [0.0, dur], [
    pos1.x,
    pos1.y,
    pos1.z,
    pos2.x,
    pos2.y,
    pos2.z,
  ])
  clips.push(
    @animation.AnimationClip::new(name="position", duration=dur, tracks=[track]),
  )
  clips
}

///|
test "AnimationMixer: Instancing" {
  let object = @animation.AnimationMixer::new(@core.Object3D::new())
  assert_eq(object.time, 0.0)
}

///|
test "AnimationMixer: stopAllAction" {
  let obj = @core.Object3D::new()
  let anim_mixer = @animation.AnimationMixer::new(obj)
  let zero3 = @math.Vector3::new(0.0, 0.0, 0.0)
  let one3 = @math.Vector3::new(1.0, 1.0, 1.0)
  let two3 = @math.Vector3::new(2.0, 2.0, 2.0)
  let clips = get_clips(zero3, one3, two3, one3, 1.0)
  let action_a = anim_mixer.clip_action(clips[0])
  let action_b = anim_mixer.clip_action(clips[1])
  action_a.play() |> ignore
  action_b.play() |> ignore
  anim_mixer.update(0.1) |> ignore
  anim_mixer.stop_all_action() |> ignore
  assert_true(!action_a.is_running() && !action_b.is_running())
  assert_true(
    obj.position.x == 0.0 && obj.position.y == 0.0 && obj.position.z == 0.0,
  )
  assert_true(obj.scale.x == 1.0 && obj.scale.y == 1.0 && obj.scale.z == 1.0)
}

///|
test "AnimationMixer: getRoot" {
  let obj = @core.Object3D::new()
  let anim_mixer = @animation.AnimationMixer::new(obj)
  assert_true(
    anim_mixer.get_root() is Object3D(root) && physical_equal(obj, root),
  )
}

///|
test "AnimationMixer: stats and uncache" {
  let obj = @core.Object3D::new()
  let mixer = @animation.AnimationMixer::new(obj)
  let clips = get_clips(
    @math.Vector3::new(0.0, 0.0, 0.0),
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(1.0, 1.0, 1.0),
    @math.Vector3::new(2.0, 2.0, 2.0),
    1.0,
  )
  obj.animations.push(clips[0].as_resource())
  let a = mixer.clip_action_by_name("scale").unwrap()
  a.fade_in(0.5).play() |> ignore
  mixer.update(0.25) |> ignore
  let stats = mixer.stats()
  assert_eq(stats.actions_in_use, 1)
  assert_eq(stats.bindings_in_use, 1)
  assert_eq(stats.control_interpolants_in_use, 1)
  assert_true(
    mixer.existing_action(clips[0]) is Some(e) && physical_equal(e, a),
  )
  mixer.uncache_clip(clips[0])
  assert_eq(mixer.stats().actions_total, 0)
  assert_eq(mixer.stats().bindings_total, 0)
  assert_eq(obj.scale.x, 1.0)
}
