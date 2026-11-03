// Upstream test/unit/src/audio/PositionalAudio.tests.js.

///|
test "PositionalAudio: Extending" {
  let ctx = mock_audio()
  let object = @audio.PositionalAudio::new(@audio.AudioListener::new())
  // PositionalAudio extends from Audio
  assert_true(object.object.has_extension_flag("isAudio"))
  assert_true(object.object.has_extension_flag("isPositionalAudio"))
  assert_true(object.panner is Some(_))
  assert_eq(object.object.type_, "Audio")
  ignore(finish_log(ctx))
}

///|
test "PositionalAudio: Instancing" {
  let ctx = mock_audio()
  let object = @audio.PositionalAudio::new(@audio.AudioListener::new())
  ignore(object.set_ref_distance(3))
  assert_eq(object.get_ref_distance(), 3)
  let log = finish_log(ctx)
  assert_true(log.contains("set PannerNode#5.panningModel = \"HRTF\""))
  assert_true(log.contains("PannerNode#5.connect(GainNode#4) -> GainNode#4"))
}
