// JS helpers shared by the files of this package. Keyframe tracks keep their times and
// values in real typed arrays (`@core.TypedArray`), as upstream does, so that writes
// round to Float32. The interpolants of `@math` take `Array[Double]`; on the JS backend
// a MoonBit array is a plain JS array, so a typed array can stand in for one as long as
// only indexing and `length` are used. `typed_as_array` gives that view.

///|
/// Views a typed array as an `Array[Double]`, sharing its storage. Only indexing and
/// `length()` are valid on the result.
fn typed_as_array(array : @core.TypedArray) -> Array[Double] = "%identity"

///|
/// `new Float32Array( size )` viewed as an `Array[Double]`.
fn float32_buffer(size : Int32) -> Array[Double] {
  typed_as_array(@core.TypedArray::float32(size))
}

///|
/// `array.constructor === Float32Array ? array : new Float32Array( array )`.
extern "js" fn js_to_float32(init : @core.JsValue) -> @core.TypedArray =
  #|(a) => (a instanceof Float32Array ? a : new Float32Array(a))

///|
fn[A : @core.TypedArrayInit] to_float32(array : A) -> @core.TypedArray {
  js_to_float32(array.to_js_init())
}

///|
extern "js" fn js_convert_array(
  init : @core.JsValue,
  type_name : String,
) -> @core.TypedArray =
  #|(a, n) => (a.constructor === globalThis[n] ? a : new globalThis[n](a))

///|
extern "js" fn js_is_typed_array(value : @core.JsValue) -> Bool =
  #|(v) => ArrayBuffer.isView(v) && !(v instanceof DataView)

///|
extern "js" fn js_math_sign(x : Double) -> Double = "Math.sign"

///|
extern "js" fn js_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn js_math_floor(x : Double) -> Double = "Math.floor"

///|
extern "js" fn js_math_abs(x : Double) -> Double = "Math.abs"

///|
/// `x & 1` on a JS number.
extern "js" fn js_and1(x : Double) -> Int32 = "(x) => x & 1"

///|
extern "js" fn js_is_nan(x : Double) -> Bool = "(x) => isNaN(x)"

///|
/// `Boolean( x )`.
extern "js" fn js_truthy(x : Double) -> Bool = "(x) => !!x"

///|
/// `String( x )`.
extern "js" fn js_number_to_string(x : Double) -> String = "(x) => String(x)"

///|
extern "js" fn js_json_stringify(value : @core.JsValue) -> String = "(v) => JSON.stringify(v)"

///|
extern "js" fn js_json_parse(text : String) -> @core.JsValue = "(s) => JSON.parse(s)"

///|
/// `Number( value )` of a JSON value, as `new Float32Array( [ value ] )` converts it.
extern "js" fn js_float32_of_js(value : @core.JsValue) -> @core.TypedArray = "(a) => new Float32Array(a)"

///|
/// `Boolean( value )`.
extern "js" fn js_value_truthy(value : @core.JsValue) -> Bool = "(v) => !!v"

///|
/// `String( value )`.
extern "js" fn js_value_to_string(value : @core.JsValue) -> String = "(v) => String(v)"

///|
extern "js" fn js_last_index_of(s : String, sub : String) -> Int32 = "(s, t) => s.lastIndexOf(t)"

///|
extern "js" fn js_substring(s : String, start : Int32, end : Int32) -> String =
  #|(s, a, b) => (b < 0 ? s.substring(a) : s.substring(a, b))

///|
/// The canonical array index a property key names, as JS reads `array[ key ]`.
fn array_index_of_key(key : String) -> Int32? {
  let n = key.length()
  if n == 0 || n > 10 {
    return None
  }
  let mut value = 0L
  for c in key {
    if c < '0' || c > '9' {
      return None
    }
    value = value * 10L + (c.to_int() - '0'.to_int()).to_int64()
  }
  if value >= 4294967295L {
    return None
  }
  // "01" is not canonical
  if n > 1 && key.has_prefix("0") {
    return None
  }
  Some(value.to_int())
}

// --- String keyframe values -------------------------------------------------------
//
// Mixer buffers are `Array[Double]`. Upstream keeps strings in a plain `Array` buffer;
// here a string is stored as its index in a table that only grows, so equal strings
// compare equal and the buffer stays numeric.

///|
let animation_string_ids : Map[String, Int32] = Map([])

///|
let animation_strings : Array[String] = []

///|
fn intern_string(s : String) -> Double {
  match animation_string_ids.get(s) {
    Some(id) => id.to_double()
    None => {
      let id = animation_strings.length()
      animation_strings.push(s)
      animation_string_ids[s] = id
      id.to_double()
    }
  }
}

///|
/// The string a buffer slot holds; a number written by a numeric track becomes
/// `String( number )`, as upstream's assignment would.
fn interned_string(id : Double) -> String {
  if id == undefined_slot_value {
    return "undefined"
  }
  let index = id.to_int()
  if index.to_double() == id && index >= 0 && index < animation_strings.length() {
    animation_strings[index]
  } else {
    js_number_to_string(id)
  }
}

///|
/// Stands for `undefined` in the boolean and string buffers of a `PropertyMixer`
/// (upstream's `new Array( n )`). Restoring a binding that was never saved writes it.
let undefined_slot_value : Double = @double.neg_infinity

// --- Expando properties ------------------------------------------------------------
//
// Upstream writes `object[ key ] = value` for keys an object does not define (for
// example `.position[w]`): the value is stored and read back, without effect. MoonBit
// structs cannot grow fields, so such values live in a side `WeakMap`.

///|
extern "js" fn js_new_weak_map() -> @core.JsValue = "() => new WeakMap()"

///|
let animation_expandos : @core.JsValue = js_new_weak_map()

///|
extern "js" fn js_expando_get(
  table : @core.JsValue,
  object : @core.JsValue,
  key : String,
) -> Double =
  #|(t, o, k) => { const m = t.get(o); return m === undefined || !(k in m) ? NaN : m[k]; }

///|
extern "js" fn js_expando_set(
  table : @core.JsValue,
  object : @core.JsValue,
  key : String,
  value : Double,
) -> Unit =
  #|(t, o, k, v) => { let m = t.get(o); if (m === undefined) { m = Object.create(null); t.set(o, m); } m[k] = v; }

///|
fn expando_get(object : @core.JsValue, key : String) -> Double {
  js_expando_get(animation_expandos, object, key)
}

///|
fn expando_set(object : @core.JsValue, key : String, value : Double) -> Unit {
  js_expando_set(animation_expandos, object, key, value)
}

///|
/// Reads `buffer[ index ]`; past the end a `Float64Array` yields `undefined`, which is NaN.
fn buffer_get(buffer : Array[Double], index : Int32) -> Double {
  if index >= 0 && index < buffer.length() {
    buffer[index]
  } else {
    @double.not_a_number
  }
}

///|
/// Writes `buffer[ index ]`; past the end a `Float64Array` ignores the write.
fn buffer_set(buffer : Array[Double], index : Int32, value : Double) -> Unit {
  if index >= 0 && index < buffer.length() {
    buffer[index] = value
  }
}

///|
/// A stable merge sort; `compare` returns a JS comparator value (NaN counts as 0).
fn[T] stable_sort(array : Array[T], compare : (T, T) -> Double) -> Unit {
  let n = array.length()
  if n < 2 {
    return
  }
  let mut src = array.copy()
  let mut dst = array.copy()
  let mut width = 1
  while width < n {
    let mut lo = 0
    while lo < n {
      let mid = if lo + width < n { lo + width } else { n }
      let hi = if lo + 2 * width < n { lo + 2 * width } else { n }
      let mut i = lo
      let mut j = mid
      let mut k = lo
      while k < hi {
        if i < mid && (j >= hi || !(compare(src[i], src[j]) > 0.0)) {
          dst[k] = src[i]
          i += 1
        } else {
          dst[k] = src[j]
          j += 1
        }
        k += 1
      }
      lo = hi
    }
    let t = src
    src = dst
    dst = t
    width *= 2
  }
  for i = 0; i < n; i = i + 1 {
    array[i] = src[i]
  }
}

///|
/// A number as `JSON.stringify` writes it: NaN and infinities become `null`.
fn json_number(x : Double) -> Json {
  if x.is_nan() || x.is_inf() {
    Json::null()
  } else {
    Json::number(x)
  }
}
