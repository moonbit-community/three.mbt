// renderers/common/DataMap.js

///|
/// Per-object data keyed by identity (a JS `WeakMap`). Upstream's `{}` is the record
/// `make()` returns; the classes extending `DataMap` keep one per key kind.
pub struct DataMap[K, V] {
  mut data : @webgl.WeakMap[K, V]
  priv make : () -> V
}

///|
/// `new DataMap()`, with the constructor of the empty record.
pub fn[K, V] DataMap::new(make : () -> V) -> DataMap[K, V] {
  { data: @webgl.WeakMap::new(), make, }
}

///|
/// `get( object )`: the object's record, created on first use.
pub fn[K, V] DataMap::get(self : DataMap[K, V], object : K) -> V {
  match self.data.get(object) {
    Some(map) => map
    None => {
      let map = (self.make)()
      self.data.set(object, map)
      map
    }
  }
}

///|
/// `delete( object )`: the removed record; `None` is `null`.
pub fn[K, V] DataMap::delete(self : DataMap[K, V], object : K) -> V? {
  let mut map = None
  if self.data.has(object) {
    map = self.data.get(object)
    self.data.delete(object)
  }
  map
}

///|
/// `has( object )`.
pub fn[K, V] DataMap::has(self : DataMap[K, V], object : K) -> Bool {
  self.data.has(object)
}

///|
/// `dispose()`.
pub fn[K, V] DataMap::dispose(self : DataMap[K, V]) -> Unit {
  self.data = @webgl.WeakMap::new()
}

///|
#external
priv type RefSetHandle

///|
extern "js" fn ref_set_new() -> RefSetHandle = "() => new Set()"

///|
extern "js" fn ref_set_add(set : RefSetHandle, value : @core.JsValue) -> Unit = "(s, v) => { s.add(v); }"

///|
extern "js" fn ref_set_delete(
  set : RefSetHandle,
  value : @core.JsValue,
) -> Unit = "(s, v) => { s.delete(v); }"

///|
extern "js" fn ref_set_has(set : RefSetHandle, value : @core.JsValue) -> Bool = "(s, v) => s.has(v)"

///|
extern "js" fn ref_set_clear(set : RefSetHandle) -> Unit = "(s) => { s.clear(); }"

///|
extern "js" fn ref_set_size(set : RefSetHandle) -> Int32 = "(s) => s.size"

///|
extern "js" fn ref_set_each(
  set : RefSetHandle,
  f : (@core.JsValue) -> Unit,
) -> Unit = "(s, f) => { for (const v of s) f(v); }"

///|
/// A JS `Set` of object identities in insertion order (the `_tracked` sets of weak
/// references, `bindGroups` of texture data, ...). `each` iterates live, as `for...of`
/// does: values deleted during the loop are skipped, values added are visited.
#warnings("-unused_type_variable")
pub struct RefSet[T] {
  priv set : RefSetHandle
}

///|
/// `new Set()`.
pub fn[T] RefSet::new() -> RefSet[T] {
  { set: ref_set_new(), }
}

///|
/// `set.add( value )`.
pub fn[T] RefSet::add(self : RefSet[T], value : T) -> Unit {
  ref_set_add(self.set, @core.JsValue::of(value))
}

///|
/// `set.delete( value )`.
pub fn[T] RefSet::delete(self : RefSet[T], value : T) -> Unit {
  ref_set_delete(self.set, @core.JsValue::of(value))
}

///|
/// `set.has( value )`.
pub fn[T] RefSet::has(self : RefSet[T], value : T) -> Bool {
  ref_set_has(self.set, @core.JsValue::of(value))
}

///|
/// `set.clear()`.
pub fn[T] RefSet::clear(self : RefSet[T]) -> Unit {
  ref_set_clear(self.set)
}

///|
/// `set.size`.
pub fn[T] RefSet::size(self : RefSet[T]) -> Int32 {
  ref_set_size(self.set)
}

///|
/// `for ( const value of set ) f( value )`.
pub fn[T] RefSet::each(self : RefSet[T], f : (T) -> Unit) -> Unit {
  ref_set_each(self.set, fn(v) { f(v.cast()) })
}
