// Upstream test/unit/src/audio/Audio.tests.js. Upstream mocks the listener; here a
// recording mock context backs a real AudioListener.

///|
test "Audio: Extending" {
  let ctx = mock_audio()
  let object = @audio.Audio::new(@audio.AudioListener::new())
  // Audio extends from Object3D: its Object3D carries it as the extension
  assert_true(object.object.has_extension_flag("isAudio"))
  let back = @audio.Audio::from_object(object.object).unwrap()
  assert_true(physical_equal(back, object))
  assert_true(@audio.Audio::from_object(@core.Object3D::new()) is None)
  ignore(finish_log(ctx))
}

///|
test "Audio: Instancing" {
  let ctx = mock_audio()
  let object = @audio.Audio::new(@audio.AudioListener::new())
  assert_eq(object.source_type, "empty")
  assert_false(object.is_playing)
  assert_true(object.has_playback_control)
  assert_true(object.panner is None)
  ignore(finish_log(ctx))
}

///|
test "Audio: type" {
  let ctx = mock_audio()
  let object = @audio.Audio::new(@audio.AudioListener::new())
  assert_eq(object.object.type_, "Audio")
  ignore(finish_log(ctx))
}

///|
test "Audio: playback round trip" {
  let ctx = mock_audio()
  let sound = @audio.Audio::new(@audio.AudioListener::new())
  ignore(sound.set_buffer(ffi_buffer(ctx, 2)))
  ffi_set_time(ctx, 1)
  ignore(sound.play())
  assert_true(sound.is_playing)
  ffi_set_time(ctx, 1.5)
  ignore(sound.pause())
  assert_false(sound.is_playing)
  assert_eq(sound._progress, 0.5)
  ignore(sound.stop())
  assert_eq(sound._progress, 0)
  let log = finish_log(ctx)
  assert_true(log.contains("AudioBufferSourceNode#6.start(1, 0, undefined)"))
  assert_true(log.contains("AudioBufferSourceNode#6.stop()"))
  assert_true(log.contains("AudioBufferSourceNode#6.stop(1.5)"))
}

///|
test "Audio: toJSON keeps type" {
  let ctx = mock_audio()
  let sound = @audio.Audio::new(@audio.AudioListener::new())
  guard sound.object.to_json() is Object(output) &&
    output.get("object") is Some(Object(object)) else {
    fail("no object")
  }
  assert_eq(object.get("type").unwrap(), Json::string("Audio"))
  ignore(finish_log(ctx))
}
