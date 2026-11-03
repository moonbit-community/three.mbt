// JS bindings the loaders need: Promise chains, fetch and its Request/Response types,
// AbortController, RegExp, image elements, timers and JSON. Upstream calls these
// globals directly; everything here mirrors one upstream expression.

///|
using @core {type JsValue}

///|
/// A JS `Promise`, used to rebuild upstream's `.then` chains step by step.
#external
priv type JsPromise

///|
extern "js" fn JsPromise::then_(
  self : JsPromise,
  on_fulfilled : (JsValue) -> JsValue,
) -> JsPromise = "(p, f) => p.then(f)"

///|
extern "js" fn JsPromise::then2(
  self : JsPromise,
  on_fulfilled : (JsValue) -> JsValue,
  on_rejected : (JsValue) -> JsValue,
) -> JsPromise = "(p, f, r) => p.then(f, r)"

///|
extern "js" fn JsPromise::catch_(
  self : JsPromise,
  on_rejected : (JsValue) -> JsValue,
) -> JsPromise = "(p, f) => p.catch(f)"

///|
extern "js" fn JsPromise::finally_(
  self : JsPromise,
  on_finally : () -> Unit,
) -> JsPromise = "(p, f) => p.finally(f)"

///|
extern "js" fn JsPromise::to_js(self : JsPromise) -> JsValue = "(p) => p"

///|
/// `cached.then` is truthy: the value is a thenable.
extern "js" fn js_is_thenable(value : JsValue) -> Bool = "(v) => v.then ? true : false"

///|
extern "js" fn js_as_promise(value : JsValue) -> JsPromise = "(v) => v"

///|
/// Throws `value`, as upstream `throw err` inside a promise callback.
extern "js" fn js_throw(value : JsValue) -> JsValue = "(e) => { throw e; }"

///|
/// `try { f() } catch ( e ) { ... }`: returns `undefined` when `f` did not throw.
extern "js" fn js_try(f : () -> Unit) -> JsTryResult =
  #|(f) => { try { f(); return { ok: true }; } catch (e) { return { ok: false, error: e }; } }

///|
#external
priv type JsTryResult

///|
extern "js" fn JsTryResult::ok(self : JsTryResult) -> Bool = "(r) => r.ok"

///|
extern "js" fn JsTryResult::error(self : JsTryResult) -> JsValue = "(r) => r.error"

///|
/// `new Error( message )`.
extern "js" fn js_new_error(message : String) -> JsValue = "(m) => new Error(m)"

///|
/// `e.message`.
extern "js" fn js_error_message(error : JsValue) -> JsValue = "(e) => e.message"

///|
/// `JSON.parse( text )` inside `try`.
extern "js" fn js_try_json_parse(text : JsValue) -> JsTryResult =
  #|(t) => { try { return { ok: true, value: JSON.parse(t) }; } catch (e) { return { ok: false, error: e }; } }

///|
extern "js" fn JsTryResult::value(self : JsTryResult) -> JsValue = "(r) => r.value"

///|
/// `setTimeout( f, 0 )`.
extern "js" fn js_set_timeout(f : () -> Unit, delay : Double) -> Unit = "(f, d) => { setTimeout(f, d); }"

///|
/// `url.normalize( 'NFC' )`.
extern "js" fn js_normalize_nfc(url : String) -> String = "(s) => s.normalize('NFC')"

///|
extern "js" fn js_string(value : JsValue) -> String = "(v) => String(v)"

///|
extern "js" fn js_from_string(value : String) -> JsValue = "(v) => v"

///|
/// Logs `value` after a message, as upstream's `console.error( message, value )`.
extern "js" fn js_console_error(message : String, value : JsValue) -> Unit = "(m, v) => console.error(m, v)"

///|
/// Upstream `error( e )` from `utils.js`, which prints an `Error` object.
fn loaders_error_value(value : JsValue) -> Unit {
  js_console_error("THREE.", value)
}

// --- AbortController ---------------------------------------------------------

///|
/// A JS `AbortController`.
#external
pub type AbortController

///|
pub extern "js" fn AbortController::new() -> AbortController = "() => new AbortController()"

///|
pub extern "js" fn AbortController::abort(self : AbortController) -> Unit = "(c) => c.abort()"

///|
/// `controller.signal`.
pub extern "js" fn AbortController::signal(self : AbortController) -> JsValue = "(c) => c.signal"

///|
/// `controller.signal.aborted`.
pub extern "js" fn AbortController::aborted(self : AbortController) -> Bool = "(c) => c.signal.aborted"

///|
pub extern "js" fn AbortController::same(
  self : AbortController,
  other : AbortController,
) -> Bool = "(a, b) => a === b"

///|
/// `( typeof AbortSignal.any === 'function' ) ? AbortSignal.any( [ a.signal, b.signal ] ) : a.signal`.
extern "js" fn js_abort_signal(
  own : AbortController,
  manager : AbortController,
) -> JsValue =
  #|(a, b) => (typeof AbortSignal.any === 'function') ? AbortSignal.any([a.signal, b.signal]) : a.signal

// --- RegExp -------------------------------------------------------------------

///|
/// A JS `RegExp`, as `LoadingManager.addHandler` takes.
#external
pub type RegExp

///|
/// `new RegExp( pattern, flags )`.
pub extern "js" fn RegExp::new(pattern : String, flags? : String) -> RegExp =
  #|(p, f) => new RegExp(p, f === undefined ? '' : f)

///|
/// `regex.test( text )`.
pub extern "js" fn RegExp::test_(self : RegExp, text : String) -> Bool = "(r, s) => r.test(s)"

///|
/// `regex.global`.
pub extern "js" fn RegExp::global(self : RegExp) -> Bool = "(r) => r.global"

///|
/// `regex.lastIndex = value`.
pub extern "js" fn RegExp::set_last_index(self : RegExp, value : Int32) -> Unit = "(r, v) => { r.lastIndex = v; }"

///|
extern "js" fn RegExp::same(self : RegExp, other : RegExp) -> Bool = "(a, b) => a === b"

// --- ProgressEvent ------------------------------------------------------------

///|
/// The `ProgressEvent` that `onProgress` callbacks receive.
#external
pub type ProgressEvent

///|
/// `new ProgressEvent( 'progress', { lengthComputable, loaded, total } )`.
extern "js" fn ProgressEvent::new(
  type_ : String,
  length_computable : Bool,
  loaded : Double,
  total : Double,
) -> ProgressEvent =
  #|(t, c, l, n) => new ProgressEvent(t, { lengthComputable: c, loaded: l, total: n })

///|
pub extern "js" fn ProgressEvent::loaded(self : ProgressEvent) -> Double = "(e) => e.loaded"

///|
pub extern "js" fn ProgressEvent::total(self : ProgressEvent) -> Double = "(e) => e.total"

///|
pub extern "js" fn ProgressEvent::length_computable(
  self : ProgressEvent,
) -> Bool = "(e) => e.lengthComputable"

///|
pub fn ProgressEvent::to_js(self : ProgressEvent) -> JsValue {
  JsValue::of(self)
}

// --- fetch --------------------------------------------------------------------

///|
/// Converts `requestHeader` to the JS object upstream passes on.
fn request_header_object(header : Map[String, String]) -> JsValue {
  let object = JsValue::object()
  for key, value in header {
    object.set(key, js_from_string(value))
  }
  object
}

///|
/// `new Request( url, { headers: new Headers( header ), credentials, priority, cache, signal } )`.
extern "js" fn js_new_request(
  url : String,
  header : JsValue,
  credentials : String,
  priority : String,
  cache : String,
  signal : JsValue,
) -> JsValue =
  #|(url, h, credentials, priority, cache, signal) => new Request(url, {
  #|  headers: new Headers(h), credentials, priority, cache, signal
  #|})

///|
extern "js" fn js_fetch(request : JsValue) -> JsPromise = "(r) => fetch(r)"

///|
/// `fetch( url, { credentials, headers, priority, cache, signal } )`, as `ImageBitmapLoader`.
extern "js" fn js_fetch_options(
  url : String,
  credentials : String,
  header : JsValue,
  priority : String,
  cache : String,
  signal : JsValue,
) -> JsPromise =
  #|(url, credentials, headers, priority, cache, signal) => {
  #|  const fetchOptions = {};
  #|  fetchOptions.credentials = credentials;
  #|  fetchOptions.headers = headers;
  #|  fetchOptions.priority = priority;
  #|  fetchOptions.cache = cache;
  #|  fetchOptions.signal = signal;
  #|  return fetch(url, fetchOptions);
  #|}

///|
extern "js" fn js_response_status(response : JsValue) -> Double = "(r) => r.status"

///|
/// The `HttpError` upstream throws for a status other than 200 and 0.
extern "js" fn js_http_error(response : JsValue) -> JsValue =
  #|(response) => {
  #|  const e = new Error(`fetch for "${response.url}" responded with ${response.status}: ${response.statusText}`);
  #|  e.response = response;
  #|  return e;
  #|}

///|
/// `typeof ReadableStream === 'undefined' || response.body === undefined || response.body.getReader === undefined`.
extern "js" fn js_response_has_no_reader(response : JsValue) -> Bool =
  #|(r) => typeof ReadableStream === 'undefined' || r.body === undefined || r.body.getReader === undefined

///|
extern "js" fn js_response_reader(response : JsValue) -> JsValue = "(r) => r.body.getReader()"

///|
/// `contentLength ? parseInt( contentLength ) : 0` with the `X-File-Size` fallback.
extern "js" fn js_response_total(response : JsValue) -> Double =
  #|(r) => {
  #|  const contentLength = r.headers.get('X-File-Size') || r.headers.get('Content-Length');
  #|  return contentLength ? parseInt(contentLength) : 0;
  #|}

///|
extern "js" fn js_reader_read(reader : JsValue) -> JsPromise = "(r) => r.read()"

///|
extern "js" fn js_chunk_done(chunk : JsValue) -> Bool = "(c) => c.done"

///|
extern "js" fn js_chunk_value(chunk : JsValue) -> JsValue = "(c) => c.value"

///|
extern "js" fn js_byte_length(value : JsValue) -> Double = "(v) => v.byteLength"

///|
/// `new Response( new ReadableStream( { start( controller ) { start( controller ); } } ) )`.
extern "js" fn js_stream_response(start : (JsValue) -> Unit) -> JsValue =
  #|(start) => new Response(new ReadableStream({ start(controller) { start(controller); } }))

///|
extern "js" fn js_controller_close(controller : JsValue) -> Unit = "(c) => c.close()"

///|
extern "js" fn js_controller_enqueue(
  controller : JsValue,
  value : JsValue,
) -> Unit = "(c, v) => c.enqueue(v)"

///|
extern "js" fn js_controller_error(
  controller : JsValue,
  error : JsValue,
) -> Unit = "(c, e) => c.error(e)"

///|
/// `response.arrayBuffer()`, `.blob()`, `.json()` or `.text()`.
extern "js" fn js_response_body(response : JsValue, name : String) -> JsValue = "(r, m) => r[m]()"

///|
/// The `'document'` branch: `response.text().then( text => new DOMParser().parseFromString( text, mimeType ) )`.
extern "js" fn js_response_document(
  response : JsValue,
  mime_type : String,
) -> JsValue =
  #|(r, mimeType) => r.text().then(text => {
  #|  const parser = new DOMParser();
  #|  return parser.parseFromString(text, mimeType);
  #|})

///|
/// The default branch with a mime type: sniffs the charset and decodes with `TextDecoder`.
extern "js" fn js_response_decode(
  response : JsValue,
  mime_type : String,
) -> JsValue =
  #|(r, mimeType) => {
  #|  const re = /charset="?([^;"\s]*)"?/i;
  #|  const exec = re.exec(mimeType);
  #|  const label = exec && exec[1] ? exec[1].toLowerCase() : undefined;
  #|  const decoder = new TextDecoder(label);
  #|  return r.arrayBuffer().then(ab => decoder.decode(ab));
  #|}

///|
/// `createImageBitmap( blob, Object.assign( {}, options, { colorSpaceConversion: 'none' } ) )`.
extern "js" fn js_create_image_bitmap(
  blob : JsValue,
  options : JsValue,
) -> JsValue =
  #|(blob, options) => createImageBitmap(blob, Object.assign({}, options, { colorSpaceConversion: 'none' }))

///|
extern "js" fn js_has_create_image_bitmap() -> Bool = "() => typeof createImageBitmap !== 'undefined'"

///|
extern "js" fn js_has_fetch() -> Bool = "() => typeof fetch !== 'undefined'"

// --- URL ----------------------------------------------------------------------

///|
/// `isBlobURL` from Cache.js.
extern "js" fn js_is_blob_url(key : String) -> Bool =
  #|(key) => {
  #|  try {
  #|    const urlString = key.slice(key.indexOf(':') + 1);
  #|    const url = new URL(urlString);
  #|    return url.protocol === 'blob:';
  #|  } catch (e) {
  #|    return false;
  #|  }
  #|}

// --- DOM images -----------------------------------------------------------------

///|
/// `createElementNS( 'img' )` from utils.js.
extern "js" fn js_create_image() -> JsValue = "() => document.createElementNS('http://www.w3.org/1999/xhtml', 'img')"

///|
extern "js" fn js_add_event_listener(
  target : JsValue,
  type_ : String,
  listener : (JsValue) -> Unit,
) -> Unit = "(t, n, f) => t.addEventListener(n, f, false)"

///|
extern "js" fn js_remove_event_listener(
  target : JsValue,
  type_ : String,
  listener : (JsValue) -> Unit,
) -> Unit = "(t, n, f) => t.removeEventListener(n, f, false)"

///|
extern "js" fn js_image_complete(image : JsValue) -> Bool = "(i) => i.complete === true"

///|
/// `image instanceof HTMLImageElement`.
extern "js" fn js_is_html_image_element(value : JsValue) -> Bool =
  #|(v) => typeof HTMLImageElement !== 'undefined' && v instanceof HTMLImageElement

// --- WeakMap ------------------------------------------------------------------

///|
/// A JS `WeakMap`, keyed by object identity as upstream's.
#external
priv type JsWeakMap

///|
extern "js" fn JsWeakMap::new() -> JsWeakMap = "() => new WeakMap()"

///|
extern "js" fn JsWeakMap::get(self : JsWeakMap, key : JsValue) -> JsValue = "(m, k) => m.get(k)"

///|
extern "js" fn JsWeakMap::set(
  self : JsWeakMap,
  key : JsValue,
  value : JsValue,
) -> Unit = "(m, k, v) => { m.set(k, v); }"

///|
extern "js" fn JsWeakMap::has(self : JsWeakMap, key : JsValue) -> Bool = "(m, k) => m.has(k)"

///|
extern "js" fn JsWeakMap::delete(self : JsWeakMap, key : JsValue) -> Unit = "(m, k) => { m.delete(k); }"

// --- url tests from ObjectLoader and LoaderUtils --------------------------------

///|
/// `/^(\/\/)|([a-z]+:(\/\/)?)/i.test( url )`.
extern "js" fn js_is_absolute_image_url(url : String) -> Bool =
  #|(u) => /^(\/\/)|([a-z]+:(\/\/)?)/i.test(u)

///|
/// `LoaderUtils.resolveURL` on JS strings, with its regular expressions.
extern "js" fn js_loader_utils_resolve_url(
  url : JsValue,
  path : String,
) -> String =
  #|(url, path) => {
  #|  if (typeof url !== 'string' || url === '') return '';
  #|  if (/^https?:\/\//i.test(path) && /^\//.test(url)) {
  #|    path = path.replace(/(^https?:\/\/[^\/]+).*/i, '$1');
  #|  }
  #|  if (/^(https?:)?\/\//i.test(url)) return url;
  #|  if (/^data:.*,.*$/i.test(url)) return url;
  #|  if (/^blob:.*$/i.test(url)) return url;
  #|  return path + url;
  #|}

///|
/// `buffer.slice( 0 )`.
extern "js" fn js_slice_buffer(buffer : JsValue) -> JsValue = "(b) => b.slice(0)"

// --- promises for loadAsync -------------------------------------------------------

///|
/// `new Promise( ( resolve, reject ) => executor( resolve, reject ) )` whose result
/// carries the rejection value, so that `load_async` can raise it as `LoaderError`.
extern "js" fn js_settle_promise(
  executor : ((JsValue) -> Unit, (JsValue) -> Unit) -> Unit,
) -> @js_async.Promise[JsTryResult] =
  #|(f) => new Promise((resolve) => f(
  #|  (value) => resolve({ ok: true, value }),
  #|  (error) => resolve({ ok: false, error })
  #|))
