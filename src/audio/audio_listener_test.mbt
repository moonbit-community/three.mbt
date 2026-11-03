// Upstream test/unit/src/audio/AudioListener.tests.js.

///|
test "AudioListener: Extending" {
  let ctx = mock_audio()
  let object = @audio.AudioListener::new()
  // AudioListener extends from Object3D
  assert_true(object.object.has_extension_flag("isAudioListener"))
  let back = @audio.AudioListener::from_object(object.object).unwrap()
  assert_true(physical_equal(back, object))
  assert_true(@audio.AudioListener::from_object(@core.Object3D::new()) is None)
  ignore(finish_log(ctx))
}

///|
test "AudioListener: Instancing" {
  let ctx = mock_audio()
  let object = @audio.AudioListener::new()
  assert_true(object.filter is None)
  assert_eq(object.time_delta, 0)
  let log = finish_log(ctx)
  assert_eq(log, [
    "AudioContext#0.createGain() -> GainNode#3", "get AudioContext#0.destination -> AudioDestinationNode#1",
    "GainNode#3.connect(AudioDestinationNode#1) -> AudioDestinationNode#1", "performance.now() -> 0",
  ])
}

///|
test "AudioListener: type" {
  let ctx = mock_audio()
  let object = @audio.AudioListener::new()
  assert_eq(object.object.type_, "AudioListener")
  ignore(finish_log(ctx))
}

///|
test "AudioListener: updateMatrixWorld runs through the extension" {
  let ctx = mock_audio()
  let listener = @audio.AudioListener::new()
  let parent = @core.Object3D::new()
  ignore(parent.add(listener.object))
  ignore(parent.position.set(1, 2, 3))
  ffi_set_now(ctx, 10)
  parent.update_matrix_world()
  assert_eq(listener.time_delta, 0.01)
  assert_eq(listener.object.matrix_world.elements[13], 2)
  let log = finish_log(ctx)
  assert_true(
    log.contains(
      "AudioListener#2.positionY.linearRampToValueAtTime(2, 0.01) -> AudioListener#2.positionY",
    ),
  )
  assert_true(
    log.contains(
      "AudioListener#2.forwardZ.linearRampToValueAtTime(-1, 0.01) -> AudioListener#2.forwardZ",
    ),
  )
}
