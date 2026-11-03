// Test helpers around the recording mock in audio_mock_test.mbt. Scenarios drive a mock
// context and end with `emit_log`, which prints `@@AUDIO_LOG <name> <json>` for the
// audio_diff harness when AUDIO_DIFF=1 and returns the log for ordinary assertions.

///|
extern "js" fn ffi_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.AUDIO_DIFF === '1'"

///|
extern "js" fn ffi_create_mock(
  module_ : @core.JsValue,
  options : String,
) -> @audio.AudioContext = "(m, o) => m.createMockAudio(JSON.parse(o))"

///|
extern "js" fn ffi_set_time(ctx : @audio.AudioContext, t : Double) -> Unit = "(c, t) => c.__setTime(t)"

///|
extern "js" fn ffi_set_now(ctx : @audio.AudioContext, ms : Double) -> Unit = "(c, t) => c.__setNow(t)"

///|
extern "js" fn ffi_buffer(
  ctx : @audio.AudioContext,
  duration : Double,
) -> @audio.AudioBuffer = "(c, d) => c.__buffer(d)"

///|
extern "js" fn ffi_media_element(ctx : @audio.AudioContext) -> @core.JsValue = "(c) => c.__mediaElement()"

///|
extern "js" fn ffi_media_stream(ctx : @audio.AudioContext) -> @core.JsValue = "(c) => c.__mediaStream()"

///|
extern "js" fn ffi_end(
  ctx : @audio.AudioContext,
  node : @audio.AudioNode,
) -> Unit = "(c, n) => c.__end(n)"

///|
extern "js" fn ffi_note(
  ctx : @audio.AudioContext,
  label : String,
  value : @core.JsValue,
) -> Unit = "(c, l, v) => c.__note(l, v)"

///|
extern "js" fn ffi_install_window(
  ctx : @audio.AudioContext,
  kind : String,
) -> Unit = "(c, k) => c.__installWindow(k)"

///|
extern "js" fn ffi_capture_console(ctx : @audio.AudioContext) -> Unit = "(c) => c.__captureConsole()"

///|
extern "js" fn ffi_finish(ctx : @audio.AudioContext) -> FixedArray[String] = "(c) => c.__finish().slice()"

///|
extern "js" fn ffi_json(log : FixedArray[String]) -> String = "(l) => JSON.stringify(l)"

///|
extern "js" fn ffi_create_filter(ctx : @audio.AudioContext) -> @audio.AudioNode = "(c) => c.createBiquadFilter()"

///|
extern "js" fn ffi_create_oscillator(
  ctx : @audio.AudioContext,
) -> @audio.AudioNode = "(c) => c.createOscillator()"

///|
extern "js" fn ffi_same(a : @core.JsValue, b : @core.JsValue) -> Bool = "(a, b) => a === b"

///|
/// A fresh recording mock, installed as the shared context, with `performance.now()` at 0
/// and three.js warnings recorded in the log. `options` is the JSON of the mock's options.
fn mock_audio(options~ : String = "{}") -> @audio.AudioContext {
  let ctx = ffi_create_mock(ffi_mock_audio_module(), options)
  @audio.AudioContext::set_context(ctx)
  ffi_set_now(ctx, 0)
  ffi_capture_console(ctx)
  ctx
}

///|
fn note(
  ctx : @audio.AudioContext,
  label : String,
  value : @core.JsValue,
) -> Unit {
  ffi_note(ctx, label, value)
}

///|
fn note_num(ctx : @audio.AudioContext, label : String, value : Double) -> Unit {
  ffi_note(ctx, label, @core.JsValue::of(value))
}

///|
fn note_bool(ctx : @audio.AudioContext, label : String, value : Bool) -> Unit {
  ffi_note(ctx, label, @core.JsValue::of(value))
}

///|
fn note_str(ctx : @audio.AudioContext, label : String, value : String) -> Unit {
  ffi_note(ctx, label, @core.JsValue::of(value))
}

///|
/// Notes the playback state upstream keeps on an `Audio`.
fn note_state(
  ctx : @audio.AudioContext,
  label : String,
  a : @audio.Audio,
) -> Unit {
  note_bool(ctx, label + ".isPlaying", a.is_playing)
  note_num(ctx, label + "._progress", a._progress)
  note_num(ctx, label + "._startedAt", a._started_at)
  note_bool(ctx, label + "._connected", a._connected)
}

///|
/// Ends the scenario: restores the patched globals and returns the log.
fn emit_log(name : String, ctx : @audio.AudioContext) -> Array[String] {
  let log = ffi_finish(ctx)
  if ffi_diff_enabled() {
    println("@@AUDIO_LOG " + name + " " + ffi_json(log))
  }
  Array::from_fixed_array(log)
}

///|
/// Ends a unit test that is not a differential scenario: restores the globals, returns the log.
fn finish_log(ctx : @audio.AudioContext) -> Array[String] {
  Array::from_fixed_array(ffi_finish(ctx))
}
