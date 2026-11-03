// Opaque JS values: the escape hatch for state whose type lives above `core`
// (renderers, DOM objects, nodes) and for JS objects with free-form keys.

///|
/// Any JS value. Core stores these without knowing the concrete type.
#external
pub type JsValue

///|
/// Wraps any MoonBit value without changing its JS representation.
pub fn[T] JsValue::of(value : T) -> JsValue = "%identity"

///|
/// Reinterprets the value; the caller guarantees the type, as `JsValue::of` erased it.
pub fn[T] JsValue::cast(self : JsValue) -> T = "%identity"

///|
/// Returns a new empty JS object, `{}`.
pub extern "js" fn JsValue::object() -> JsValue = "() => ({})"

///|
pub extern "js" fn JsValue::null() -> JsValue = "() => null"

///|
pub extern "js" fn JsValue::undefined() -> JsValue = "() => undefined"

///|
pub extern "js" fn JsValue::is_null(self : JsValue) -> Bool = "(v) => v === null"

///|
pub extern "js" fn JsValue::is_undefined(self : JsValue) -> Bool = "(v) => v === undefined"

///|
/// Reads a property, `self[key]`.
pub extern "js" fn JsValue::get(self : JsValue, key : String) -> JsValue = "(o, k) => o[k]"

///|
/// Writes a property, `self[key] = value`.
pub extern "js" fn JsValue::set(
  self : JsValue,
  key : String,
  value : JsValue,
) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
/// JS strict equality.
pub extern "js" fn JsValue::strict_equal(
  self : JsValue,
  other : JsValue,
) -> Bool = "(a, b) => a === b"

///|
/// Returns `Object.keys(self).length`.
pub extern "js" fn JsValue::key_count(self : JsValue) -> Int32 = "(o) => Object.keys(o).length"

///|
extern "js" fn js_json_stringify(value : JsValue) -> String = "(v) => JSON.stringify(v)"

///|
extern "js" fn js_json_parse(text : String) -> JsValue = "(s) => JSON.parse(s)"

///|
/// `JSON.parse( JSON.stringify( self ) )`, as upstream clones `userData`.
pub fn JsValue::json_clone(self : JsValue) -> JsValue {
  js_json_parse(js_json_stringify(self))
}

///|
/// Converts core `Json` to a plain JS value.
pub fn JsValue::from_json(json : Json) -> JsValue {
  js_json_parse(json.stringify())
}

///|
/// Converts a JSON-serializable JS value to core `Json`.
pub fn JsValue::to_json(self : JsValue) -> Json {
  @json.parse(js_json_stringify(self)) catch {
    _ => abort("JsValue::to_json: value is not JSON serializable")
  }
}
