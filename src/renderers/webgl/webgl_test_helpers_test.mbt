// Helpers for tests that drive modules through the recording mock context
// (webgl_mock_gl_test.mbt). `emit_log` prints `@@WEBGL_LOG <name> <json>` when the
// harness runs the tests with `WEBGL_DIFF=1`; run_diff.mjs compares those lines with
// upstream three.js driven through the same mock. See PORTING.md.

///|
let mock_module : @core.JsValue = ffi_mock_gl_module(())

///|
extern "js" fn ffi_mock_create(
  module_ : @core.JsValue,
  options : String,
) -> @webgl.WebGL2RenderingContext = "(m, o) => m.createMockGL(JSON.parse(o))"

///|
/// A mock context; `options` is the JSON options object of `createMockGL`.
fn mock_gl(options~ : String = "{}") -> @webgl.WebGL2RenderingContext {
  ffi_mock_create(mock_module, options)
}

///|
extern "js" fn ffi_mock_log(
  gl : @webgl.WebGL2RenderingContext,
) -> FixedArray[String] = "(gl) => gl.__log.slice()"

///|
/// The calls recorded so far, one `name(args)` string each.
fn mock_log(gl : @webgl.WebGL2RenderingContext) -> Array[String] {
  Array::from_fixed_array(ffi_mock_log(gl))
}

///|
/// Clears the recorded calls.
#warnings("-unused_value")
extern "js" fn mock_clear(gl : @webgl.WebGL2RenderingContext) -> Unit = "(gl) => gl.__clear()"

///|
/// Records `# label <JSON of value>`, for results that are not GL calls.
extern "js" fn mock_note(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : @core.JsValue,
) -> Unit = "(gl, l, v) => gl.__note(l, v)"

///|
/// `mock_note` for a number.
fn note_num(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Double,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for an integer.
fn note_int(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Int32,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for a boolean.
fn note_bool(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Bool,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for a string.
fn note_str(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : String,
) -> Unit {
  mock_note(gl, label, @core.JsValue::of(value))
}

///|
/// `mock_note` for an optional integer; `None` is noted as `null`.
fn note_opt_int(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : Int32?,
) -> Unit {
  match value {
    Some(v) => note_int(gl, label, v)
    None => mock_note(gl, label, @core.JsValue::null())
  }
}

///|
extern "js" fn diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.WEBGL_DIFF === '1'"

///|
extern "js" fn ffi_log_json(gl : @webgl.WebGL2RenderingContext) -> String = "(gl) => JSON.stringify(gl.__log)"

///|
/// Prints the log for run_diff.mjs when `WEBGL_DIFF=1`; returns the log either way.
fn emit_log(name : String, gl : @webgl.WebGL2RenderingContext) -> Array[String] {
  if diff_enabled() {
    println("@@WEBGL_LOG " + name + " " + ffi_log_json(gl))
  }
  mock_log(gl)
}

///|
extern "js" fn ffi_mock_animation_context(
  module_ : @core.JsValue,
  gl : @webgl.WebGL2RenderingContext,
) -> @webgl.AnimationFrameProvider = "(m, gl) => m.createMockAnimationContext(gl)"

///|
/// A `requestAnimationFrame` provider that records into `gl`'s log.
fn mock_animation_context(
  gl : @webgl.WebGL2RenderingContext,
) -> @webgl.AnimationFrameProvider {
  ffi_mock_animation_context(mock_module, gl)
}

///|
/// Runs the pending animation frames with `time`.
extern "js" fn mock_tick(
  context : @webgl.AnimationFrameProvider,
  time : Double,
) -> Unit = "(c, t) => c.__tick(t)"
