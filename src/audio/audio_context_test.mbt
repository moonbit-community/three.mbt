// Upstream test/unit/src/audio/AudioContext.tests.js, with `window` mocked as upstream does.

///|
test "AudioContext: getContext" {
  let ctx = mock_audio()
  @audio.AudioContext::set_context(
    @audio.AudioContext::of_js(@core.JsValue::undefined()),
  )
  ffi_install_window(ctx, "standard")
  let context = @audio.AudioContext::get_context()
  // AudioContext.getContext creates a context.
  assert_true(ffi_same(context.to_js(), ctx.to_js()))
  let log = finish_log(ctx)
  assert_true(log.contains("new window.AudioContext()"))
}

///|
test "AudioContext: setContext" {
  let first = mock_audio()
  ignore(finish_log(first))
  let second = ffi_create_mock(ffi_mock_audio_module(), "{}")
  @audio.AudioContext::set_context(second)
  let context = @audio.AudioContext::get_context()
  // AudioContext.setContext updates the context.
  assert_true(ffi_same(context.to_js(), second.to_js()))
  assert_false(ffi_same(context.to_js(), first.to_js()))
}
