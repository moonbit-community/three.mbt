///|
test "AnimationClip: Instancing" {
  let clip = @animation.AnimationClip::new(name="clip1", duration=1000.0)
  assert_eq(clip.duration, 1000.0)
}

///|
test "AnimationClip: name" {
  let clip = @animation.AnimationClip::new(name="clip1", duration=1000.0)
  assert_eq(clip.name, "clip1")
}

///|
test "AnimationClip: resetDuration, trim, optimize, clone" {
  let a = @animation.NumberKeyframeTrack::new(".opacity", [0, 1, 2, 3], [
    0, 0, 0, 1,
  ])
  let b = @animation.VectorKeyframeTrack::new(".position", [0, 5], [
    0, 0, 0, 1, 1, 1,
  ])
  let clip = @animation.AnimationClip::new(name="c", tracks=[a, b])
  assert_eq(clip.duration, 5.0)
  clip.duration = 2.0
  clip.trim() |> ignore
  assert_eq(a.times.to_array(), [0.0, 1.0, 2.0])
  assert_eq(b.times.to_array(), [0.0])
  assert_true(clip.validate())
  clip.optimize() |> ignore
  assert_eq(a.times.to_array(), [0.0, 2.0])
  let clone = clip.clone()
  assert_true(clone.uuid != clip.uuid)
  assert_eq(clone.tracks[0].times.to_array(), [0.0, 2.0])
}

///|
test "AnimationClip: toJSON / parse round trip and SerializableResource" {
  let clip = @animation.AnimationClip::new(name="walk", tracks=[
    @animation.QuaternionKeyframeTrack::new(".quaternion", [0, 1], [
      0, 0, 0, 1, 0, 0, 1, 0,
    ]),
    @animation.BooleanKeyframeTrack::new(".visible", [0.0, 0.5], [true, false]),
    @animation.StringKeyframeTrack::new(".name", [0], ["n"]),
  ])
  let json = clip.to_json()
  let parsed = @animation.AnimationClip::parse(json)
  assert_eq(parsed.uuid, clip.uuid)
  assert_eq(parsed.to_json().stringify(), json.stringify())
  let object = @core.Object3D::new()
  object.animations.push(clip.as_resource())
  let found = @animation.AnimationClip::find_by_name_in_object(object, "walk")
  assert_true(found is Some(c) && physical_equal(c, clip))
  // Object3D.toJSON serializes the clip through the trait
  let object_json = object.to_json()
  guard object_json is Object(map) && map.get("animations") is Some(Array(list)) else {
    fail("no animations")
  }
  assert_eq(list.length(), 1)
}

///|
test "AnimationClip: morph target sequences" {
  let names = ["Walk_001", "Walk_002", "Run_001", "Run_002", "Run_003", "idle"]
  let clips = @animation.AnimationClip::create_clips_from_morph_target_sequences(
    names, 10.0, false,
  )
  assert_eq(clips.length(), 2)
  assert_eq(clips[0].name, "Walk_")
  assert_eq(clips[1].name, "Run_")
  assert_eq(clips[1].tracks.length(), 3)
  assert_eq(clips[1].tracks[0].name, ".morphTargetInfluences[Run_001]")
  assert_eq(clips[1].tracks[0].times.to_array().length(), 4)
  assert_eq(clips[1].duration, 0.30000001192092896)
}
