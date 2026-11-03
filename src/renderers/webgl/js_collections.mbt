// JS `WeakMap`, `WeakRef` and `FinalizationRegistry`, for state upstream keys by object
// identity. Keys must be JS objects: structs, enums with payloads, closures and external
// values qualify; `Int`, `String`, `Bool` and payload-less enum constructors do not.
// Values must not be `Option`, `Unit` or anything else whose JS form can be `undefined`.

///|
#external
type JsWeakMap

///|
extern "js" fn js_weak_map_new() -> JsWeakMap = "() => new WeakMap()"

///|
extern "js" fn js_weak_map_get(
  map : JsWeakMap,
  key : @core.JsValue,
) -> @core.JsValue = "(m, k) => m.get(k)"

///|
extern "js" fn js_weak_map_set(
  map : JsWeakMap,
  key : @core.JsValue,
  value : @core.JsValue,
) -> Unit = "(m, k, v) => { m.set(k, v); }"

///|
extern "js" fn js_weak_map_has(map : JsWeakMap, key : @core.JsValue) -> Bool = "(m, k) => m.has(k)"

///|
extern "js" fn js_weak_map_delete(map : JsWeakMap, key : @core.JsValue) -> Unit = "(m, k) => { m.delete(k); }"

///|
/// A JS `WeakMap` from `K` (by identity, `JsValue::of(key)`) to `V`.
#warnings("-unused_type_variable")
pub struct WeakMap[K, V] {
  priv map : JsWeakMap
}

///|
/// `new WeakMap()`.
pub fn[K, V] WeakMap::new() -> WeakMap[K, V] {
  { map: js_weak_map_new(), }
}

///|
/// `map.get( key )`; `undefined` is `None`.
pub fn[K, V] WeakMap::get(self : WeakMap[K, V], key : K) -> V? {
  let value = js_weak_map_get(self.map, @core.JsValue::of(key))
  if value.is_undefined() {
    None
  } else {
    Some(value.cast())
  }
}

///|
/// `map.set( key, value )`.
pub fn[K, V] WeakMap::set(self : WeakMap[K, V], key : K, value : V) -> Unit {
  js_weak_map_set(self.map, @core.JsValue::of(key), @core.JsValue::of(value))
}

///|
/// `map.has( key )`.
pub fn[K, V] WeakMap::has(self : WeakMap[K, V], key : K) -> Bool {
  js_weak_map_has(self.map, @core.JsValue::of(key))
}

///|
/// `map.delete( key )`.
pub fn[K, V] WeakMap::delete(self : WeakMap[K, V], key : K) -> Unit {
  js_weak_map_delete(self.map, @core.JsValue::of(key))
}

///|
/// A JS `WeakRef` to a `T`.
#external
pub type WeakRef[T]

///|
extern "js" fn ffi_weak_ref_new(target : @core.JsValue) -> @core.JsValue = "(t) => new WeakRef(t)"

///|
extern "js" fn ffi_weak_ref_deref(ref_ : @core.JsValue) -> @core.JsValue = "(r) => r.deref()"

///|
/// `new WeakRef( target )`.
pub fn[T] WeakRef::new(target : T) -> WeakRef[T] {
  ffi_weak_ref_new(@core.JsValue::of(target)).cast()
}

///|
/// `ref.deref()`; a collected target is `None`.
pub fn[T] WeakRef::deref(self : WeakRef[T]) -> T? {
  let value = ffi_weak_ref_deref(@core.JsValue::of(self))
  if value.is_undefined() {
    None
  } else {
    Some(value.cast())
  }
}

///|
/// A JS `FinalizationRegistry` whose held values are `H`.
#external
pub type FinalizationRegistry[H]

///|
extern "js" fn ffi_finalization_registry_new(
  callback : (@core.JsValue) -> Unit,
) -> @core.JsValue = "(f) => new FinalizationRegistry(f)"

///|
extern "js" fn ffi_finalization_registry_register(
  registry : @core.JsValue,
  target : @core.JsValue,
  held : @core.JsValue,
  token : @core.JsValue,
) -> Unit = "(r, t, h, k) => r.register(t, h, k)"

///|
extern "js" fn ffi_finalization_registry_unregister(
  registry : @core.JsValue,
  token : @core.JsValue,
) -> Unit = "(r, k) => { r.unregister(k); }"

///|
/// `new FinalizationRegistry( callback )`.
pub fn[H] FinalizationRegistry::new(
  callback : (H) -> Unit,
) -> FinalizationRegistry[H] {
  ffi_finalization_registry_new(fn(held) { callback(held.cast()) }).cast()
}

///|
/// `registry.register( target, held, token )`.
pub fn[H, T, K] FinalizationRegistry::register(
  self : FinalizationRegistry[H],
  target : T,
  held : H,
  token : K,
) -> Unit {
  ffi_finalization_registry_register(
    @core.JsValue::of(self),
    @core.JsValue::of(target),
    @core.JsValue::of(held),
    @core.JsValue::of(token),
  )
}

///|
/// `registry.unregister( token )`.
pub fn[H, K] FinalizationRegistry::unregister(
  self : FinalizationRegistry[H],
  token : K,
) -> Unit {
  ffi_finalization_registry_unregister(
    @core.JsValue::of(self),
    @core.JsValue::of(token),
  )
}
