// Upstream examples/jsm/utils/SortUtils.js: a hybrid radix sort (8-bit digits from the
// most significant byte, insertion sort for blocks of 32 or fewer) on 32-bit unsigned
// keys. Upstream takes a typed or plain array; `radix_sort` takes an `Array[T]` with a
// key function, `radix_sort_numbers` and `radix_sort_typed` the identity key on numbers.

///|
const SORT_UTILS_POWER : Int32 = 3

///|
const SORT_UTILS_BIT_MAX : Int32 = 32

///|
const SORT_UTILS_BIN_BITS : Int32 = 8 // 1 << POWER

///|
const SORT_UTILS_BIN_SIZE : Int32 = 256 // 1 << BIN_BITS

///|
const SORT_UTILS_BIN_MAX : Int32 = 255 // BIN_SIZE - 1

///|
const SORT_UTILS_ITERATIONS : Int32 = 4 // BIT_MAX / BIN_BITS

///|
/// `bins`: one histogram per depth plus one, shared by every call as upstream's
/// module-level `Uint32Array` views of one buffer.
let _sort_utils_bins : Array[Array[Int32]] = Array::makei(
  SORT_UTILS_ITERATIONS + 1,
  fn(_) { Array::make(SORT_UTILS_BIN_SIZE, 0) },
)

///|
/// `x >>> s`: `ToUint32( x )` shifted right, as a JS number.
extern "js" fn sort_utils_ushr(x : Double, s : Int32) -> Double = "(x, s) => x >>> s"

///|
/// `x >>> s & BIN_MAX`.
extern "js" fn sort_utils_digit(x : Double, s : Int32) -> Int32 = "(x, s) => (x >>> s) & 255"

///|
/// `radixSort( arr, { get, aux, reversed } )`: sorts `arr` in place by `get( el ) >>> 0`.
/// `aux` is the scratch array upstream allocates when it is not given.
pub fn[T] radix_sort(
  arr : Array[T],
  get~ : (T) -> Double,
  aux? : Array[T],
  reversed~ : Bool = false,
) -> Unit {
  let len = arr.length()
  let aux = match aux {
    Some(aux) => aux
    // `new arr.constructor( len )`; every slot is written before it is read
    None => arr.copy()
  }
  let data = [arr, aux]
  let compare : (Double, Double) -> Bool = if reversed {
    fn(a, b) { a < b }
  } else {
    fn(a, b) { a > b }
  }
  let accumulate : (Array[Int32]) -> Unit = if reversed {
    fn(bin) {
      for j = SORT_UTILS_BIN_SIZE - 2; j >= 0; j = j - 1 {
        bin[j] += bin[j + 1]
      }
    }
  } else {
    fn(bin) {
      for j = 1; j < SORT_UTILS_BIN_SIZE; j = j + 1 {
        bin[j] += bin[j - 1]
      }
    }
  }
  fn insertion_sort_block(depth : Int32, start : Int32, len : Int32) -> Unit {
    let a = data[depth & 1]
    let b = data[(depth + 1) & 1]
    for j = start + 1; j < start + len; j = j + 1 {
      let p = a[j]
      let t = sort_utils_ushr(get(p), 0)
      let mut i = j
      while i > start {
        if compare(sort_utils_ushr(get(a[i - 1]), 0), t) {
          // `a[ i ] = a[ -- i ]`
          a[i] = a[i - 1]
          i -= 1
        } else {
          break
        }
      }
      a[i] = p
    }
    if (depth & 1) == 1 {
      for i = start; i < start + len; i = i + 1 {
        b[i] = a[i]
      }
    }
  }

  fn radix_sort_block(depth : Int32, start : Int32, len : Int32) -> Unit {
    let a = data[depth & 1]
    let b = data[(depth + 1) & 1]
    let shift = (3 - depth) << SORT_UTILS_POWER
    let end = start + len
    let cache = _sort_utils_bins[depth]
    let bin = _sort_utils_bins[depth + 1]
    bin.fill(0)
    for j = start; j < end; j = j + 1 {
      bin[sort_utils_digit(get(a[j]), shift)] += 1
    }
    accumulate(bin)
    for j = 0; j < SORT_UTILS_BIN_SIZE; j = j + 1 {
      cache[j] = bin[j]
    }
    for j = end - 1; j >= start; j = j - 1 {
      let d = sort_utils_digit(get(a[j]), shift)
      bin[d] -= 1
      b[start + bin[d]] = a[j]
    }
    if depth == SORT_UTILS_ITERATIONS - 1 {
      return
    }
    // recurse( cache, depth, start )
    let mut prev = 0
    if reversed {
      for j = SORT_UTILS_BIN_MAX; j >= 0; j = j - 1 {
        let cur = cache[j]
        let diff = cur - prev
        if diff != 0 {
          if diff > 32 {
            radix_sort_block(depth + 1, start + prev, diff)
          } else {
            insertion_sort_block(depth + 1, start + prev, diff)
          }
          prev = cur
        }
      }
    } else {
      for j = 0; j < SORT_UTILS_BIN_SIZE; j = j + 1 {
        let cur = cache[j]
        let diff = cur - prev
        if diff != 0 {
          if diff > 32 {
            radix_sort_block(depth + 1, start + prev, diff)
          } else {
            insertion_sort_block(depth + 1, start + prev, diff)
          }
          prev = cur
        }
      }
    }
  }

  radix_sort_block(0, 0, len)
}

///|
/// `radixSort( arr, options )` with upstream's default `get`, `( el ) => el`.
pub fn radix_sort_numbers(
  arr : Array[Double],
  get? : (Double) -> Double,
  aux? : Array[Double],
  reversed~ : Bool = false,
) -> Unit {
  let get = match get {
    Some(get) => get
    None => fn(el) { el }
  }
  radix_sort(arr, get~, aux?, reversed~)
}

///|
/// `radixSort( typedArray, options )`; `aux` must have the same type, as upstream's
/// default `new arr.constructor( len )`.
pub fn radix_sort_typed(
  arr : @core.TypedArray,
  get? : (Double) -> Double,
  aux? : @core.TypedArray,
  reversed~ : Bool = false,
) -> Unit {
  let values = arr.to_array()
  let scratch = match aux {
    Some(aux) => aux.to_array()
    None => values.copy()
  }
  radix_sort_numbers(values, get?, aux=scratch, reversed~)
  for i, v in values {
    arr.set(i, v)
  }
  if aux is Some(aux) {
    for i, v in scratch {
      aux.set(i, v)
    }
  }
}
