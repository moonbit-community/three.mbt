// AudioAnalyser has no upstream unit test; the analyser scenario in
// audio_differential_test.mbt compares it with upstream.

///|
test "AudioAnalyser: frequency data" {
  let ctx = mock_audio()
  let sound = @audio.Audio::new(@audio.AudioListener::new())
  let analyser = @audio.AudioAnalyser::new(sound, fft_size=8)
  assert_eq(analyser.data.length(), 4)
  let data = analyser.get_frequency_data()
  assert_true(physical_equal(data, analyser.data))
  assert_eq(data.to_array(), [114, 151, 188, 225])
  // second call: (i * 37 + 2 * 101 + 13) % 256
  assert_eq(analyser.get_average_frequency(), (215.0 + 252 + 33 + 70) / 4)
  ignore(finish_log(ctx))
}
