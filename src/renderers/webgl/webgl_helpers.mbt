// Small helpers shared by every module in this package.

///|
/// `array.sort( compare )` with JS semantics: stable, and `compare` may return any number
/// (NaN reads as 0). `Array::sort_by` in core is unstable, so render lists, lights and
/// update ranges sort through this instead.
pub fn[T] stable_sort_by(array : Array[T], compare : (T, T) -> Double) -> Unit {
  let n = array.length()
  if n < 2 {
    return
  }
  let buffer = array.copy()
  stable_sort_range(array, buffer, 0, n, compare)
}

///|
fn[T] stable_sort_range(
  array : Array[T],
  buffer : Array[T],
  lo : Int32,
  hi : Int32,
  compare : (T, T) -> Double,
) -> Unit {
  if hi - lo < 2 {
    return
  }
  if hi - lo <= 8 {
    // insertion sort keeps equal elements in order
    for i in (lo + 1)..<hi {
      let item = array[i]
      let mut j = i - 1
      while j >= lo && compare(array[j], item) > 0.0 {
        array[j + 1] = array[j]
        j -= 1
      }
      array[j + 1] = item
    }
    return
  }
  let mid = lo + (hi - lo) / 2
  stable_sort_range(array, buffer, lo, mid, compare)
  stable_sort_range(array, buffer, mid, hi, compare)
  for i in lo..<hi {
    buffer[i] = array[i]
  }
  let mut i = lo
  let mut j = mid
  let mut k = lo
  while i < mid && j < hi {
    // take from the right only when strictly smaller
    if compare(buffer[i], buffer[j]) > 0.0 {
      array[k] = buffer[j]
      j += 1
    } else {
      array[k] = buffer[i]
      i += 1
    }
    k += 1
  }
  while i < mid {
    array[k] = buffer[i]
    i += 1
    k += 1
  }
  while j < hi {
    array[k] = buffer[j]
    j += 1
    k += 1
  }
}

///|
/// JS `Math.min`, which propagates NaN.
pub extern "js" fn js_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
/// JS `Math.max`, which propagates NaN.
pub extern "js" fn js_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// `array.length = n` for an array at least `n` long.
pub fn[T] truncate_array(array : Array[T], n : Int32) -> Unit {
  while array.length() > n {
    ignore(array.pop())
  }
}

///|
/// Returns an uninitialized value of any type: JS `undefined`. Only for fields that
/// upstream also leaves `undefined` until a later initialization step assigns them, such
/// as the modules `WebGLRenderer` creates in `initGLContext`. Reading one before it is
/// assigned fails as upstream would.
pub fn[T] uninitialized() -> T {
  @core.JsValue::undefined().cast()
}

///|
extern "js" fn ffi_js_try(f : () -> Unit) -> @core.JsValue =
  #|(f) => { try { f(); return undefined; } catch (e) { return String(e); } }

///|
/// `try { f() } catch ( e ) { ... }` for JS exceptions thrown by a binding, which MoonBit
/// cannot catch: returns `Some(String( e ))` when `f` threw. `WebGLState` wraps texture
/// uploads in this.
pub fn js_try(f : () -> Unit) -> String? {
  gl_option(ffi_js_try(f))
}
