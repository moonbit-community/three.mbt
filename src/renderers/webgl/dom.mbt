// The DOM surface the WebGL renderer touches: the canvas, 2D contexts for texture
// resizing, animation frames, timers and `instanceof` checks on image sources.

///|
/// `HTMLCanvasElement` or `OffscreenCanvas`; the renderer uses only what both share,
/// plus `style` and `setAttribute` guarded as upstream guards them.
#external
pub type HTMLCanvasElement

///|
/// `CanvasRenderingContext2D` / `OffscreenCanvasRenderingContext2D`.
#external
pub type CanvasRenderingContext2D

///|
/// Something with `requestAnimationFrame` / `cancelAnimationFrame`: `self` (the window or
/// worker global) or an `XRSession`.
#external
pub type AnimationFrameProvider

///|
/// `createElementNS( 'canvas' )` with `style.display = 'block'`, upstream's
/// `createCanvasElement` from src/utils.js.
pub extern "js" fn create_canvas_element() -> HTMLCanvasElement =
  #|() => { const c = document.createElementNS('http://www.w3.org/1999/xhtml', 'canvas'); c.style.display = 'block'; return c; }

///|
/// `document.createElementNS( 'http://www.w3.org/1999/xhtml', name )`.
pub extern "js" fn create_element_ns(name : String) -> @core.JsValue = "(n) => document.createElementNS('http://www.w3.org/1999/xhtml', n)"

///|
/// `typeof OffscreenCanvas !== 'undefined' && new OffscreenCanvas( 1, 1 ).getContext( '2d' ) !== null`,
/// with exceptions read as `false`.
pub extern "js" fn offscreen_canvas_2d_supported() -> Bool =
  #|() => { try { return typeof OffscreenCanvas !== 'undefined' && (new OffscreenCanvas(1, 1).getContext('2d')) !== null; } catch (e) { return false; } }

///|
/// `new OffscreenCanvas( width, height )`.
pub extern "js" fn new_offscreen_canvas(
  width : Int32,
  height : Int32,
) -> HTMLCanvasElement = "(w, h) => new OffscreenCanvas(w, h)"

///|
/// `canvas.width`.
pub extern "js" fn HTMLCanvasElement::width(self : HTMLCanvasElement) -> Int32 = "(c) => c.width"

///|
/// `canvas.height`.
pub extern "js" fn HTMLCanvasElement::height(self : HTMLCanvasElement) -> Int32 = "(c) => c.height"

///|
/// `canvas.width = value`.
pub extern "js" fn HTMLCanvasElement::set_width(
  self : HTMLCanvasElement,
  value : Int32,
) -> Unit = "(c, v) => { c.width = v; }"

///|
/// `canvas.height = value`.
pub extern "js" fn HTMLCanvasElement::set_height(
  self : HTMLCanvasElement,
  value : Int32,
) -> Unit = "(c, v) => { c.height = v; }"

///|
/// `canvas.style.width = value`.
pub extern "js" fn HTMLCanvasElement::set_style_width(
  self : HTMLCanvasElement,
  value : String,
) -> Unit = "(c, v) => { c.style.width = v; }"

///|
/// `canvas.style.height = value`.
pub extern "js" fn HTMLCanvasElement::set_style_height(
  self : HTMLCanvasElement,
  value : String,
) -> Unit = "(c, v) => { c.style.height = v; }"

///|
/// `'setAttribute' in canvas`; `OffscreenCanvas` has none (#22811).
pub extern "js" fn HTMLCanvasElement::has_set_attribute(
  self : HTMLCanvasElement,
) -> Bool = "(c) => 'setAttribute' in c"

///|
/// `canvas.setAttribute( name, value )`.
pub extern "js" fn HTMLCanvasElement::set_attribute(
  self : HTMLCanvasElement,
  name : String,
  value : String,
) -> Unit = "(c, n, v) => c.setAttribute(n, v)"

///|
/// `canvas.addEventListener( type, listener, false )`. Keep the closure to remove it.
pub extern "js" fn HTMLCanvasElement::add_event_listener(
  self : HTMLCanvasElement,
  type_ : String,
  listener : (@core.JsValue) -> Unit,
) -> Unit = "(c, t, l) => c.addEventListener(t, l, false)"

///|
/// `canvas.removeEventListener( type, listener, false )`.
pub extern "js" fn HTMLCanvasElement::remove_event_listener(
  self : HTMLCanvasElement,
  type_ : String,
  listener : (@core.JsValue) -> Unit,
) -> Unit = "(c, t, l) => c.removeEventListener(t, l, false)"

///|
extern "js" fn ffi_canvas_get_context(
  canvas : HTMLCanvasElement,
  name : String,
  attributes : @core.JsValue,
) -> @core.JsValue = "(c, n, a) => a === undefined ? c.getContext(n) : c.getContext(n, a)"

///|
/// `canvas.getContext( 'webgl2', attributes )`; `attributes` undefined passes none.
pub fn HTMLCanvasElement::get_context_webgl2(
  self : HTMLCanvasElement,
  attributes : @core.JsValue,
) -> WebGL2RenderingContext? {
  gl_option(ffi_canvas_get_context(self, "webgl2", attributes))
}

///|
/// `canvas.getContext( '2d' )`.
pub fn HTMLCanvasElement::get_context_2d(
  self : HTMLCanvasElement,
) -> CanvasRenderingContext2D? {
  gl_option(ffi_canvas_get_context(self, "2d", @core.JsValue::undefined()))
}

///|
/// `context.drawImage( image, dx, dy, dWidth, dHeight )`.
pub extern "js" fn CanvasRenderingContext2D::draw_image(
  self : CanvasRenderingContext2D,
  image : @core.JsValue,
  dx : Double,
  dy : Double,
  width : Double,
  height : Double,
) -> Unit = "(c, i, x, y, w, h) => c.drawImage(i, x, y, w, h)"

///|
/// `typeof self !== 'undefined' ? self : null`.
pub fn global_self() -> AnimationFrameProvider? {
  gl_option(ffi_global_self())
}

///|
extern "js" fn ffi_global_self() -> @core.JsValue = "() => typeof self !== 'undefined' ? self : null"

///|
/// `context.requestAnimationFrame( callback )`; `frame` is `undefined` outside WebXR.
pub extern "js" fn AnimationFrameProvider::request_animation_frame(
  self : AnimationFrameProvider,
  callback : (Double, @core.JsValue) -> Unit,
) -> @core.JsValue = "(c, f) => c.requestAnimationFrame(f)"

///|
/// `context.cancelAnimationFrame( requestId )`.
pub extern "js" fn AnimationFrameProvider::cancel_animation_frame(
  self : AnimationFrameProvider,
  request_id : @core.JsValue,
) -> Unit = "(c, id) => c.cancelAnimationFrame(id)"

///|
/// `setTimeout( callback, delay )`.
pub extern "js" fn set_timeout(callback : () -> Unit, delay : Double) -> Unit = "(f, d) => { setTimeout(f, d); }"

///|
/// `typeof navigator === 'undefined' ? undefined : navigator.userAgent`.
pub fn navigator_user_agent() -> String? {
  gl_option(ffi_navigator_user_agent())
}

///|
extern "js" fn ffi_navigator_user_agent() -> @core.JsValue = "() => typeof navigator === 'undefined' ? undefined : navigator.userAgent"

///|
/// `event.preventDefault()`.
pub extern "js" fn dom_event_prevent_default(event : @core.JsValue) -> Unit = "(e) => e.preventDefault()"

///|
/// `typeof HTMLImageElement !== 'undefined' && value instanceof HTMLImageElement`.
pub extern "js" fn is_html_image_element(value : @core.JsValue) -> Bool = "(v) => typeof HTMLImageElement !== 'undefined' && v instanceof HTMLImageElement"

///|
/// `typeof HTMLCanvasElement !== 'undefined' && value instanceof HTMLCanvasElement`.
pub extern "js" fn is_html_canvas_element(value : @core.JsValue) -> Bool = "(v) => typeof HTMLCanvasElement !== 'undefined' && v instanceof HTMLCanvasElement"

///|
/// `typeof ImageBitmap !== 'undefined' && value instanceof ImageBitmap`.
pub extern "js" fn is_image_bitmap(value : @core.JsValue) -> Bool = "(v) => typeof ImageBitmap !== 'undefined' && v instanceof ImageBitmap"

///|
/// `typeof VideoFrame !== 'undefined' && value instanceof VideoFrame`.
pub extern "js" fn is_video_frame(value : @core.JsValue) -> Bool = "(v) => typeof VideoFrame !== 'undefined' && v instanceof VideoFrame"

///|
/// `typeof WebGLRenderingContext !== 'undefined' && value instanceof WebGLRenderingContext`
/// (a WebGL 1 context, which the renderer rejects).
pub extern "js" fn is_webgl1_context(value : @core.JsValue) -> Bool = "(v) => typeof WebGLRenderingContext !== 'undefined' && v instanceof WebGLRenderingContext"

///|
/// `key in value` for a JS object.
pub extern "js" fn js_has_key(value : @core.JsValue, key : String) -> Bool = "(v, k) => v !== null && v !== undefined && (k in v)"

///|
/// `__THREE_DEVTOOLS__.dispatchEvent( new CustomEvent( 'observe', { detail } ) )` when the
/// devtools hook is installed.
pub extern "js" fn three_devtools_observe(detail : @core.JsValue) -> Unit = "(d) => { if (typeof __THREE_DEVTOOLS__ !== 'undefined') __THREE_DEVTOOLS__.dispatchEvent(new CustomEvent('observe', { detail: d })); }"
