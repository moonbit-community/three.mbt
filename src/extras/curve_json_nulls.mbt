// `null` read from a curve's JSON. `JSON.stringify` writes NaN and the infinities as
// `null`, and upstream's `fromJSON` assigns that `null` to the field: arithmetic then
// treats it as 0 (`getPoint` and friends), while `toJSON` writes `null` again. A Double
// holds one or the other, so a field read as `null` holds 0 and is remembered here, by
// the vector or curve data object and the field's key, until `toJSON` writes it: still 0
// there, it is written as `null`. Curve copies carry the marks, as upstream copies the
// `null` itself.

///|
extern "js" fn curve_json_nulls_new() -> @core.JsValue = "() => new WeakMap()"

///|
let _curve_json_nulls : @core.JsValue = curve_json_nulls_new()

///|
extern "js" fn curve_json_nulls_mark(
  map : @core.JsValue,
  target : @core.JsValue,
  key : String,
) -> Unit = "(m, t, k) => { let s = m.get(t); if (s === undefined) { s = new Set(); m.set(t, s); } s.add(k); }"

///|
extern "js" fn curve_json_nulls_has(
  map : @core.JsValue,
  target : @core.JsValue,
  key : String,
) -> Bool = "(m, t, k) => { const s = m.get(t); return s !== undefined && s.has(k); }"

///|
extern "js" fn curve_json_nulls_copy(
  map : @core.JsValue,
  source : @core.JsValue,
  target : @core.JsValue,
) -> Unit = "(m, f, t) => { const s = m.get(f); if (s === undefined) m.delete(t); else m.set(t, new Set(s)); }"

///|
/// Remembers that `target`'s field `key` was read as `null`.
fn[T] curve_null_mark(target : T, key : String) -> Unit {
  curve_json_nulls_mark(_curve_json_nulls, @core.JsValue::of(target), key)
}

///|
/// `source`'s `null` marks, given to `target` (replacing its own), as a copy does.
fn[T] curve_null_copy(source : T, target : T) -> Unit {
  curve_json_nulls_copy(
    _curve_json_nulls,
    @core.JsValue::of(source),
    @core.JsValue::of(target),
  )
}

///|
/// `value` of `target`'s field `key` as upstream's `toJSON` writes it.
fn[T] curve_json_field(target : T, key : String, value : Double) -> Json {
  if value == 0.0 &&
    curve_json_nulls_has(_curve_json_nulls, @core.JsValue::of(target), key) {
    Json::null()
  } else {
    @math.json_number(value)
  }
}

///|
/// `data[ key ]` assigned to `target`'s field `key`: a number, or 0 for `null`.
fn[T] curve_json_double_of(target : T, json : Json, key : String) -> Double {
  let value = curve_json_get(json, key)
  if value is Null {
    curve_null_mark(target, key)
  }
  curve_json_number(value)
}

///|
/// A vector's components as upstream's `toJSON` writes them.
fn[V : CurveVector] curve_json_vector_numbers(vector : V) -> Json {
  Json::array(
    vector
    .to_array()
    .mapi((i, value) => curve_json_field(vector, i.to_string(), value)),
  )
}

///|
/// `vector.fromArray( json )`, remembering the components given as `null`.
fn[V : CurveVector] curve_json_vector_from(vector : V, json : Json) -> V {
  ignore(vector.from_array(curve_json_doubles(json)))
  if json is Array(values) {
    for i, value in values {
      if value is Null {
        curve_null_mark(vector, i.to_string())
      }
    }
  }
  vector
}

///|
/// `vector.clone()`, with its `null` marks.
fn[V : CurveVector] curve_clone_vector(vector : V) -> V {
  let copy = vector.clone()
  curve_null_copy(vector, copy)
  copy
}

///|
/// `target.copy( source )`, with the `null` marks.
fn[V : CurveVector] curve_copy_vector(target : V, source : V) -> Unit {
  ignore(target.copy(source))
  curve_null_copy(source, target)
}
