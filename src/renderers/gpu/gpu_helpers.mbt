// Hand-written half of the WebGPU bindings: the JS object builders the generated code
// uses, Promise glue, the `GPUBufferSource` argument trait, and the uses upstream makes
// that are not plain calls (feature tests, `instanceof`, `getContext( 'webgpu' )`,
// BigUint64Array reads of query results).

///|
/// What `writeBuffer` / `writeTexture` accept as data: core typed arrays and array buffers
/// pass as the JS value, `JsValue` as is.
pub(open) trait GPUBufferSource {
  fn to_buffer_source(Self) -> @core.JsValue
}

///|
pub impl GPUBufferSource for @core.TypedArray with fn to_buffer_source(self) {
  @core.JsValue::of(self)
}

///|
pub impl GPUBufferSource for @core.ArrayBuffer with fn to_buffer_source(self) {
  @core.JsValue::of(self)
}

///|
pub impl GPUBufferSource for @core.JsValue with fn to_buffer_source(self) {
  self
}

///|
extern "js" fn gpu_object() -> @core.JsValue = "() => ({})"

///|
extern "js" fn gpu_set(
  o : @core.JsValue,
  key : String,
  value : @core.JsValue,
) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
extern "js" fn gpu_u32(v : Int32) -> @core.JsValue = "(v) => v >>> 0"

///|
extern "js" fn gpu_array_new() -> @core.JsValue = "() => []"

///|
extern "js" fn gpu_array_push(a : @core.JsValue, v : @core.JsValue) -> Unit = "(a, v) => { a.push(v); }"

///|
extern "js" fn gpu_array_length(a : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn gpu_array_get(a : @core.JsValue, i : Int32) -> @core.JsValue = "(a, i) => a[i]"

///|
fn[T] gpu_array_map(
  array : Array[T],
  f : (T) -> @core.JsValue,
) -> @core.JsValue {
  let a = gpu_array_new()
  for x in array {
    gpu_array_push(a, f(x))
  }
  a
}

///|
fn[T] gpu_array_of(array : Array[T]) -> @core.JsValue {
  gpu_array_map(array, fn(x) { @core.JsValue::of(x) })
}

///|
fn[T] gpu_array_from(a : @core.JsValue) -> Array[T] {
  Array::makei(gpu_array_length(a), fn(i) { gpu_array_get(a, i).cast() })
}

///|
/// An optional argument: `None` is `undefined`.
fn[T] gpu_optional(v : T?, f : (T) -> @core.JsValue) -> @core.JsValue {
  match v {
    Some(x) => f(x)
    None => @core.JsValue::undefined()
  }
}

///|
/// `null` and `undefined` are `None`.
fn[T] gpu_option(v : @core.JsValue) -> T? {
  if v.is_null() || v.is_undefined() {
    None
  } else {
    Some(v.cast())
  }
}

///|
extern "js" fn ffi_promise_then(
  p : @core.JsValue,
  ok : (@core.JsValue) -> Unit,
  err : @core.JsValue,
) -> Unit = "(p, ok, err) => { p.then((v) => { ok(v); }, err); }"

///|
fn gpu_then(
  p : @core.JsValue,
  ok : (@core.JsValue) -> Unit,
  on_error : ((@core.JsValue) -> Unit)?,
) -> Unit {
  let err = match on_error {
    Some(f) => @core.JsValue::of(fn(e : @core.JsValue) { f(e) })
    None => @core.JsValue::undefined()
  }
  ffi_promise_then(p, ok, err)
}

///|
/// `promise.then( on_done, on_error )` for the raw `_promise` forms.
pub fn promise_then(
  promise : @core.JsValue,
  on_done : (@core.JsValue) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> Unit {
  gpu_then(promise, on_done, on_error)
}

///|
/// Whether two optional handles are the same object (`a === b`).
pub fn[T] same_handle(a : T?, b : T?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => physical_equal(x, y)
    (None, None) => true
    _ => false
  }
}

///|
extern "js" fn ffi_navigator_gpu() -> @core.JsValue =
  #|() => (typeof navigator !== 'undefined' && navigator.gpu !== undefined) ? navigator.gpu : null

///|
/// `navigator.gpu`; `None` without WebGPU (or without `navigator`).
pub fn gpu() -> GPU? {
  gpu_option(ffi_navigator_gpu())
}

///|
extern "js" fn ffi_get_webgpu_context(canvas : @core.JsValue) -> @core.JsValue = "(c) => c.getContext('webgpu')"

///|
/// `canvas.getContext( 'webgpu' )`.
pub fn get_webgpu_context(canvas : @core.JsValue) -> GPUCanvasContext? {
  gpu_option(ffi_get_webgpu_context(canvas))
}

///|
/// `value instanceof GPURenderBundleEncoder`.
pub extern "js" fn is_render_bundle_encoder(value : @core.JsValue) -> Bool =
  #|(v) => typeof GPURenderBundleEncoder !== 'undefined' && v instanceof GPURenderBundleEncoder

///|
/// `pass.setBlendConstant !== undefined` (render passes have it, bundle encoders do not).
pub extern "js" fn has_set_blend_constant(pass : @core.JsValue) -> Bool = "(p) => p.setBlendConstant !== undefined"

///|
/// `GPUTextureUsage.TRANSIENT_ATTACHMENT !== undefined`.
pub extern "js" fn has_texture_usage_transient_attachment() -> Bool =
  #|() => typeof GPUTextureUsage !== 'undefined' && GPUTextureUsage.TRANSIENT_ATTACHMENT !== undefined

///|
/// `typeof queue.copyElementImageToTexture === 'function'` (HTML-in-canvas).
pub extern "js" fn GPUQueue::has_copy_element_image_to_texture(
  self : GPUQueue,
) -> Bool = "(q) => typeof q.copyElementImageToTexture === 'function'"

///|
/// `queue.copyElementImageToTexture.length`: 2 for the dictionary form.
pub extern "js" fn GPUQueue::copy_element_image_to_texture_length(
  self : GPUQueue,
) -> Int32 = "(q) => q.copyElementImageToTexture.length"

///|
/// `queue.copyElementImageToTexture( source, destination )`.
pub extern "js" fn GPUQueue::copy_element_image_to_texture(
  self : GPUQueue,
  source : @core.JsValue,
  destination : @core.JsValue,
) -> Unit = "(q, s, d) => q.copyElementImageToTexture(s, d)"

///|
/// `queue.copyElementImageToTexture( image, width, height, destination )`, the older form.
pub extern "js" fn GPUQueue::copy_element_image_to_texture_sized(
  self : GPUQueue,
  image : @core.JsValue,
  width : Int32,
  height : Int32,
  destination : @core.JsValue,
) -> Unit = "(q, i, w, h, d) => q.copyElementImageToTexture(i, w, h, d)"

///|
/// `error.constructor.name` (`GPUValidationError`, `GPUOutOfMemoryError`, ...).
pub extern "js" fn GPUError::type_name(self : GPUError) -> String =
  #|(e) => e && e.constructor ? e.constructor.name : 'GPUError'

///|
extern "js" fn ffi_error_message(err : @core.JsValue) -> @core.JsValue =
  #|(e) => (e && e.message) ? e.message : undefined

///|
/// `( err && err.message )` of a rejection reason; `None` when empty.
pub fn error_message(err : @core.JsValue) -> String? {
  gpu_option(ffi_error_message(err))
}

///|
/// `new BigUint64Array( buffer )[ index ] === BigInt( 0 )`, for occlusion query results.
pub extern "js" fn big_uint64_is_zero(
  buffer : @core.ArrayBuffer,
  index : Int32,
) -> Bool = "(b, i) => new BigUint64Array(b)[i] === BigInt(0)"

///|
/// `Number( times[ end ] - times[ start ] )` over `new BigUint64Array( buffer )`.
pub extern "js" fn big_uint64_difference(
  buffer : @core.ArrayBuffer,
  start : Int32,
  end : Int32,
) -> Double = "(b, s, e) => { const t = new BigUint64Array(b); return Number(t[e] - t[s]); }"

///|
/// `JSON.stringify( value )`, as upstream hashes bind group layout entries.
pub extern "js" fn json_stringify(value : @core.JsValue) -> String = "(v) => JSON.stringify(v)"
