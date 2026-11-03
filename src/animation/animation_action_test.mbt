///|
fn create_animation() -> (
  @core.Object3D,
  @animation.AnimationMixer,
  @animation.KeyframeTrack,
  @animation.AnimationClip,
  @animation.AnimationAction,
) {
  let root = @core.Object3D::new()
  let mixer = @animation.AnimationMixer::new(root)
  let track = @animation.NumberKeyframeTrack::new(".rotation[x]", [0, 1000], [
    0, 360,
  ])
  let clip = @animation.AnimationClip::new(name="clip1", duration=1000.0, tracks=[
    track,
  ])
  let animation_action = mixer.clip_action(clip)
  (root, mixer, track, clip, animation_action)
}

///|
fn create_two_animations() -> (
  @animation.AnimationMixer,
  @animation.AnimationAction,
  @animation.AnimationAction,
) {
  let root = @core.Object3D::new()
  let mixer = @animation.AnimationMixer::new(root)
  let track = @animation.NumberKeyframeTrack::new(".rotation[x]", [0, 1000], [
    0, 360,
  ])
  let clip = @animation.AnimationClip::new(name="clip1", duration=1000.0, tracks=[
    track,
  ])
  let animation_action = mixer.clip_action(clip)
  let clip2 = @animation.AnimationClip::new(name="clip2", duration=1000.0, tracks=[
    track,
  ])
  let animation_action2 = mixer.clip_action(clip2)
  (mixer, animation_action, animation_action2)
}

///|
test "AnimationAction: Instancing" {
  let mixer = @animation.AnimationMixer::new(@core.Object3D::new())
  let clip = @animation.AnimationClip::new(name="nonname", duration=-1.0)
  let animation_action = @animation.AnimationAction::new(mixer, clip)
  assert_eq(animation_action.time, 0.0)
}

///|
test "AnimationAction: play" {
  let (_, _, _, _, animation_action) = create_animation()
  let animation_action2 = animation_action.play()
  assert_true(physical_equal(animation_action, animation_action2))
}

///|
test "AnimationAction: stop" {
  let (_, _, _, _, animation_action) = create_animation()
  let animation_action2 = animation_action.stop()
  assert_true(physical_equal(animation_action, animation_action2))
}

///|
test "AnimationAction: reset" {
  let (_, _, _, _, animation_action) = create_animation()
  let animation_action2 = animation_action.stop()
  assert_true(physical_equal(animation_action, animation_action2))
  assert_eq(animation_action2.paused, false)
  assert_eq(animation_action2.enabled, true)
  assert_eq(animation_action2.time, 0.0)
  assert_eq(animation_action2._loop_count, -1.0)
  assert_eq(animation_action2._start_time, None)
}

///|
test "AnimationAction: isRunning" {
  let (_, _, _, _, animation_action) = create_animation()
  assert_false(animation_action.is_running())
  animation_action.play() |> ignore
  assert_true(animation_action.is_running())
  animation_action.stop() |> ignore
  assert_false(animation_action.is_running())
  animation_action.play() |> ignore
  animation_action.paused = true
  assert_false(animation_action.is_running())
  animation_action.paused = false
  animation_action.enabled = false
  assert_false(animation_action.is_running())
  animation_action.enabled = true
  assert_true(animation_action.is_running())
}

///|
test "AnimationAction: isScheduled" {
  let (_, mixer, _, _, animation_action) = create_animation()
  assert_false(animation_action.is_scheduled())
  animation_action.play() |> ignore
  assert_true(animation_action.is_scheduled())
  mixer.update(1.0) |> ignore
  assert_true(animation_action.is_scheduled())
  animation_action.stop() |> ignore
  assert_false(animation_action.is_scheduled())
}

///|
test "AnimationAction: startAt" {
  let (_, mixer, _, _, animation_action) = create_animation()
  animation_action.start_at(2.0) |> ignore
  animation_action.play() |> ignore
  assert_false(animation_action.is_running())
  assert_true(animation_action.is_scheduled())
  mixer.update(1.0) |> ignore
  assert_false(animation_action.is_running())
  assert_true(animation_action.is_scheduled())
  mixer.update(1.0) |> ignore
  assert_true(animation_action.is_running())
  assert_true(animation_action.is_scheduled())
  animation_action.stop() |> ignore
  assert_false(animation_action.is_running())
  assert_false(animation_action.is_scheduled())
}

///|
test "AnimationAction: setLoop LoopOnce" {
  let (_, mixer, _, _, animation_action) = create_animation()
  animation_action.set_loop(@core.LoopOnce) |> ignore
  animation_action.play() |> ignore
  assert_true(animation_action.is_running())
  mixer.update(500.0) |> ignore
  assert_true(animation_action.is_running())
  mixer.update(500.0) |> ignore
  assert_false(animation_action.is_running())
  mixer.update(500.0) |> ignore
  assert_false(animation_action.is_running())
}

///|
test "AnimationAction: setLoop LoopRepeat" {
  let (root, mixer, _, _, animation_action) = create_animation()
  animation_action.set_loop(@core.LoopRepeat, repetitions=3.0) |> ignore
  animation_action.play() |> ignore
  assert_true(animation_action.is_running())
  mixer.update(750.0) |> ignore
  assert_eq(root.rotation.x, 270.0)
  assert_true(animation_action.is_running())
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 270.0)
  assert_true(animation_action.is_running())
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 270.0)
  assert_true(animation_action.is_running())
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
  assert_false(animation_action.is_running())
}

///|
test "AnimationAction: setLoop LoopPingPong" {
  let (root, mixer, _, _, animation_action) = create_animation()
  animation_action.set_loop(@core.LoopPingPong, repetitions=3.0) |> ignore
  animation_action.play() |> ignore
  assert_true(animation_action.is_running())
  mixer.update(750.0) |> ignore
  assert_eq(root.rotation.x, 270.0)
  assert_true(animation_action.is_running())
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  assert_true(animation_action.is_running())
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 270.0)
  assert_true(animation_action.is_running())
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
  assert_false(animation_action.is_running())
}

///|
test "AnimationAction: setEffectiveWeight" {
  let (_, _, _, _, animation_action) = create_animation()
  assert_eq(animation_action.get_effective_weight(), 1.0)
  animation_action.set_effective_weight(0.3) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.3)
}

///|
test "AnimationAction: setEffectiveWeight - disabled" {
  let (_, _, _, _, animation_action) = create_animation()
  assert_eq(animation_action.get_effective_weight(), 1.0)
  animation_action.enabled = false
  animation_action.set_effective_weight(0.3) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.0)
}

///|
test "AnimationAction: setEffectiveWeight - over duration" {
  let (root, mixer, _, _, animation_action) = create_animation()
  animation_action.set_effective_weight(0.5) |> ignore
  animation_action.play() |> ignore
  mixer.update(500.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
}

///|
test "AnimationAction: getEffectiveWeight" {
  let (_, _, _, _, animation_action) = create_animation()
  assert_eq(animation_action.get_effective_weight(), 1.0)
  animation_action.set_effective_weight(0.3) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.3)
  let (_, _, _, _, animation_action) = create_animation()
  assert_eq(animation_action.get_effective_weight(), 1.0)
  animation_action.enabled = false
  animation_action.set_effective_weight(0.3) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.0)
}

///|
test "AnimationAction: fadeIn" {
  let (_, mixer, _, _, animation_action) = create_animation()
  animation_action.fade_in(1000.0) |> ignore
  animation_action.play() |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.25)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.5)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.75)
  mixer.update(500.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
}

///|
test "AnimationAction: fadeOut" {
  let (_, mixer, _, _, animation_action) = create_animation()
  animation_action.fade_out(1000.0) |> ignore
  animation_action.play() |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.75)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.5)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.25)
  mixer.update(500.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.0)
}

///|
test "AnimationAction: crossFadeFrom" {
  let (mixer, animation_action, animation_action2) = create_two_animations()
  animation_action.cross_fade_from(animation_action2, 1000.0, warp=false)
  |> ignore
  animation_action.play() |> ignore
  animation_action2.play() |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
  assert_eq(animation_action2.get_effective_weight(), 1.0)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.25)
  assert_eq(animation_action2.get_effective_weight(), 0.75)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.5)
  assert_eq(animation_action2.get_effective_weight(), 0.5)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.75)
  assert_eq(animation_action2.get_effective_weight(), 0.25)
  mixer.update(500.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
  assert_eq(animation_action2.get_effective_weight(), 0.0)
}

///|
test "AnimationAction: crossFadeTo" {
  let (mixer, animation_action, animation_action2) = create_two_animations()
  animation_action2.cross_fade_to(animation_action, 1000.0, warp=false)
  |> ignore
  animation_action.play() |> ignore
  animation_action2.play() |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
  assert_eq(animation_action2.get_effective_weight(), 1.0)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.25)
  assert_eq(animation_action2.get_effective_weight(), 0.75)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.5)
  assert_eq(animation_action2.get_effective_weight(), 0.5)
  mixer.update(250.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 0.75)
  assert_eq(animation_action2.get_effective_weight(), 0.25)
  mixer.update(500.0) |> ignore
  assert_eq(animation_action.get_effective_weight(), 1.0)
  assert_eq(animation_action2.get_effective_weight(), 0.0)
}

///|
test "AnimationAction: getMixer" {
  let (_, mixer, _, _, animation_action) = create_animation()
  let mixer2 = animation_action.get_mixer()
  assert_true(physical_equal(mixer, mixer2))
}

///|
test "AnimationAction: getClip" {
  let (_, _, _, clip, animation_action) = create_animation()
  let clip2 = animation_action.get_clip()
  assert_true(physical_equal(clip, clip2))
}

///|
test "AnimationAction: getRoot" {
  let (root, _, _, _, animation_action) = create_animation()
  let root2 = animation_action.get_root()
  assert_true(root2 is Object3D(r) && physical_equal(root, r))
}

///|
test "AnimationAction: StartAt when already executed once" {
  let root = @core.Object3D::new()
  let mixer = @animation.AnimationMixer::new(root)
  let track = @animation.NumberKeyframeTrack::new(".rotation[x]", [0, 750], [
    0, 270,
  ])
  let clip = @animation.AnimationClip::new(name="clip1", duration=750.0, tracks=[
    track,
  ])
  let animation_action = mixer.clip_action(clip)
  animation_action.set_loop(@core.LoopOnce) |> ignore
  animation_action.clamp_when_finished = true
  animation_action.play() |> ignore
  mixer.add_event_listener("finished", _ => {
    animation_action.time_scale *= -1.0
    animation_action.paused = false
    animation_action.start_at(mixer.time + 2000.0).play() |> ignore
  })
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 180.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 270.0)
  //first loop done
  mixer.update(2000.0) |> ignore
  // startAt Done
  assert_eq(root.rotation.x, 270.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 180.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
  mixer.update(1.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
  mixer.update(1000.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 180.0)
}

///|
test "AnimationAction: LoopRepeat with timeScale reversal during first loop" {
  // Regression test for #19151
  let root = @core.Object3D::new()
  let mixer = @animation.AnimationMixer::new(root)
  let track = @animation.NumberKeyframeTrack::new(".rotation[x]", [0, 1000], [
    0, 360,
  ])
  let clip = @animation.AnimationClip::new(name="clip1", duration=1000.0, tracks=[
    track,
  ])
  let animation_action = mixer.clip_action(clip)
  animation_action.set_loop(@core.LoopRepeat, repetitions=@double.infinity)
  |> ignore
  animation_action.play() |> ignore
  mixer.update(500.0) |> ignore
  assert_eq(root.rotation.x, 180.0)
  mixer.time_scale = -1.0
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
}

///|
test "AnimationAction: LoopPingPong with timeScale reversal during first loop" {
  // Regression test for #19151
  let root = @core.Object3D::new()
  let mixer = @animation.AnimationMixer::new(root)
  let track = @animation.NumberKeyframeTrack::new(".rotation[x]", [0, 1000], [
    0, 360,
  ])
  let clip = @animation.AnimationClip::new(name="clip1", duration=1000.0, tracks=[
    track,
  ])
  let animation_action = mixer.clip_action(clip)
  animation_action.set_loop(@core.LoopPingPong, repetitions=@double.infinity)
  |> ignore
  animation_action.play() |> ignore
  mixer.update(500.0) |> ignore
  assert_eq(root.rotation.x, 180.0)
  mixer.time_scale = -1.0
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 90.0)
  mixer.update(250.0) |> ignore
  assert_eq(root.rotation.x, 0.0)
}

///|
test "AnimationAction: events carry the action" {
  let (_, mixer, _, _, animation_action) = create_animation()
  let seen = []
  mixer.add_event_listener("loop", event => {
    let action = @animation.animation_event_action(event).unwrap()
    assert_true(physical_equal(action, animation_action)) catch {
      _ => panic()
    }
    seen.push(@animation.animation_event_loop_delta(event).unwrap())
    assert_true(
      event.target is Some(target) &&
      @animation.AnimationMixer::from_event_target(target) is Some(m) &&
      physical_equal(m, mixer),
    ) catch {
      _ => panic()
    }
  })
  animation_action.play() |> ignore
  mixer.update(2500.0) |> ignore
  assert_eq(seen, [2.0])
}
