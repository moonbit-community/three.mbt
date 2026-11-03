// JS Promise bindings shared by the add-ons that upstream writes as promise chains
// (WorkerPool, GLTFLoader, DRACOLoader, KTX2Loader). Each method is one upstream
// expression, so `.then` chains take the same microtasks as upstream. Values cross
// as JS values: a MoonBit struct is a JS object, an `Array` a JS array, `None` is
// `undefined`; `JsValue::null()` stands for upstream's `null`.

///|
using @core {type JsValue}

///|
/// A JS `Promise`.
#external
pub type AddonPromise

///|
extern "js" fn addon_promise_then_raw(
  p : AddonPromise,
  f : (JsValue) -> JsValue,
) -> AddonPromise = "(p, f) => p.then(f)"

///|
extern "js" fn addon_promise_then2_raw(
  p : AddonPromise,
  f : (JsValue) -> JsValue,
  r : (JsValue) -> JsValue,
) -> AddonPromise = "(p, f, r) => p.then(f, r)"

///|
extern "js" fn addon_promise_catch_raw(
  p : AddonPromise,
  r : (JsValue) -> JsValue,
) -> AddonPromise = "(p, r) => p.catch(r)"

///|
extern "js" fn addon_promise_resolve_raw(v : JsValue) -> AddonPromise = "(v) => Promise.resolve(v)"

///|
extern "js" fn addon_promise_reject_raw(v : JsValue) -> AddonPromise = "(v) => Promise.reject(v)"

///|
extern "js" fn addon_promise_all_raw(values : JsValue) -> AddonPromise = "(a) => Promise.all(a)"

///|
extern "js" fn addon_promise_new_raw(
  executor : ((JsValue) -> Unit, (JsValue) -> Unit) -> Unit,
) -> AddonPromise = "(f) => new Promise((resolve, reject) => f(resolve, reject))"

///|
extern "js" fn addon_is_thenable(v : JsValue) -> Bool =
  #|(v) => v !== null && v !== undefined && typeof v.then === 'function'

///|
/// `promise.then( f )`. `f` may return an `AddonPromise`, which the result adopts.
pub fn[A, B] AddonPromise::then_(
  self : AddonPromise,
  f : (A) -> B,
) -> AddonPromise {
  addon_promise_then_raw(self, fn(v) { JsValue::of(f(v.cast())) })
}

///|
/// `promise.then( f, r )`.
pub fn[A, B] AddonPromise::then2(
  self : AddonPromise,
  f : (A) -> B,
  r : (JsValue) -> B,
) -> AddonPromise {
  addon_promise_then2_raw(self, fn(v) { JsValue::of(f(v.cast())) }, fn(e) {
    JsValue::of(r(e))
  })
}

///|
/// `promise.catch( r )`.
pub fn[B] AddonPromise::catch_(
  self : AddonPromise,
  r : (JsValue) -> B,
) -> AddonPromise {
  addon_promise_catch_raw(self, fn(e) { JsValue::of(r(e)) })
}

///|
/// `Promise.resolve( value )`; a promise `value` is returned as it is, as in JS.
pub fn[T] AddonPromise::resolve(value : T) -> AddonPromise {
  addon_promise_resolve_raw(JsValue::of(value))
}

///|
/// `Promise.resolve()`.
pub fn AddonPromise::resolve_undefined() -> AddonPromise {
  addon_promise_resolve_raw(JsValue::undefined())
}

///|
/// `Promise.reject( error )`.
pub fn AddonPromise::reject(error : JsValue) -> AddonPromise {
  addon_promise_reject_raw(error)
}

///|
/// `Promise.all( promises )`; resolves to a JS array, read as `Array[JsValue]`.
pub fn AddonPromise::all(promises : Array[AddonPromise]) -> AddonPromise {
  addon_promise_all_raw(JsValue::of(promises))
}

///|
/// `Promise.all( values )` where entries may be plain values or promises.
pub fn AddonPromise::all_values(values : Array[JsValue]) -> AddonPromise {
  addon_promise_all_raw(JsValue::of(values))
}

///|
/// `new Promise( ( resolve, reject ) => executor( resolve, reject ) )`.
pub fn AddonPromise::new(
  executor : ((JsValue) -> Unit, (JsValue) -> Unit) -> Unit,
) -> AddonPromise {
  addon_promise_new_raw(executor)
}

///|
pub fn AddonPromise::to_js(self : AddonPromise) -> JsValue {
  JsValue::of(self)
}

///|
/// Views a JS value that is a promise (or thenable) as one.
pub fn AddonPromise::from_js(value : JsValue) -> AddonPromise {
  value.cast()
}

///|
/// `value && typeof value.then === 'function'`.
pub fn AddonPromise::is_promise(value : JsValue) -> Bool {
  addon_is_thenable(value)
}

///|
extern "js" fn addon_throw_raw(error : JsValue) -> Unit = "(e) => { throw e; }"

///|
/// `new Error( message )`.
pub extern "js" fn addon_new_error(message : String) -> JsValue = "(m) => new Error(m)"

///|
/// `throw error`: a JS exception, so it rejects the enclosing `.then` or reaches
/// the caller's `try`, as upstream.
pub fn[T] addon_throw(error : JsValue) -> T {
  addon_throw_raw(error)
  panic()
}

///|
/// `throw new Error( message )`.
pub fn[T] addon_throw_error(message : String) -> T {
  addon_throw(addon_new_error(message))
}

///|
extern "js" fn addon_try_raw(f : () -> Unit) -> JsValue =
  #|(f) => { try { f(); return undefined; } catch (e) { return { error: e }; } }

///|
/// `try { f() } catch ( e ) { ... }`: `Some(e)` when `f` threw.
pub fn addon_try(f : () -> Unit) -> JsValue? {
  let r = addon_try_raw(f)
  if r.is_undefined() {
    None
  } else {
    Some(r.get("error"))
  }
}
