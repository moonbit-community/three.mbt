// renderers/common/ChainMap.js

///|
#external
priv type ChainMapWeakMap

///|
extern "js" fn chain_map_weak_map_new() -> ChainMapWeakMap = "() => new WeakMap()"

///|
extern "js" fn chain_map_get(
  map : ChainMapWeakMap,
  key : @core.JsValue,
) -> @core.JsValue = "(m, k) => m.get(k)"

///|
extern "js" fn chain_map_has(
  map : ChainMapWeakMap,
  key : @core.JsValue,
) -> Bool = "(m, k) => m.has(k)"

///|
extern "js" fn chain_map_set(
  map : ChainMapWeakMap,
  key : @core.JsValue,
  value : @core.JsValue,
) -> Unit = "(m, k, v) => { m.set(k, v); }"

///|
extern "js" fn chain_map_delete(
  map : ChainMapWeakMap,
  key : @core.JsValue,
) -> Bool = "(m, k) => m.delete(k)"

///|
/// A map keyed by arrays of objects, as nested JS `WeakMap`s, one chain per key
/// length. Keys are `JsValue::of(object)`; values must not have `undefined` as their
/// JS form (no `Option` or `Unit`).
#warnings("-unused_type_variable")
pub struct ChainMap[V] {
  /// `weakMaps[ keys.length ]`.
  priv weak_maps : Map[Int32, ChainMapWeakMap]
}

///|
/// `new ChainMap()`.
pub fn[V] ChainMap::new() -> ChainMap[V] {
  { weak_maps: Map([]), }
}

///|
fn[V] ChainMap::_get_weak_map(
  self : ChainMap[V],
  keys : Array[@core.JsValue],
) -> ChainMapWeakMap {
  let length = keys.length()
  match self.weak_maps.get(length) {
    Some(weak_map) => weak_map
    None => {
      let weak_map = chain_map_weak_map_new()
      self.weak_maps.set(length, weak_map)
      weak_map
    }
  }
}

///|
/// `get( keys )`; `None` is `undefined`.
pub fn[V] ChainMap::get(self : ChainMap[V], keys : Array[@core.JsValue]) -> V? {
  let mut map = self._get_weak_map(keys)
  for i in 0..<(keys.length() - 1) {
    let next = chain_map_get(map, keys[i])
    if next.is_undefined() {
      return None
    }
    map = next.cast()
  }
  let value = chain_map_get(map, keys[keys.length() - 1])
  if value.is_undefined() {
    None
  } else {
    Some(value.cast())
  }
}

///|
/// `set( keys, value )`.
pub fn[V] ChainMap::set(
  self : ChainMap[V],
  keys : Array[@core.JsValue],
  value : V,
) -> ChainMap[V] {
  let mut map = self._get_weak_map(keys)
  for i in 0..<(keys.length() - 1) {
    let key = keys[i]
    if !chain_map_has(map, key) {
      chain_map_set(map, key, @core.JsValue::of(chain_map_weak_map_new()))
    }
    map = chain_map_get(map, key).cast()
  }
  chain_map_set(map, keys[keys.length() - 1], @core.JsValue::of(value))
  self
}

///|
/// `delete( keys )`: whether an entry was removed.
pub fn[V] ChainMap::delete(
  self : ChainMap[V],
  keys : Array[@core.JsValue],
) -> Bool {
  let mut map = self._get_weak_map(keys)
  for i in 0..<(keys.length() - 1) {
    let next = chain_map_get(map, keys[i])
    if next.is_undefined() {
      return false
    }
    map = next.cast()
  }
  chain_map_delete(map, keys[keys.length() - 1])
}
