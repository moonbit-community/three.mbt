///|
let _lut : Array[String] = [
  "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", "0a", "0b", "0c", "0d",
  "0e", "0f", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "1a", "1b",
  "1c", "1d", "1e", "1f", "20", "21", "22", "23", "24", "25", "26", "27", "28", "29",
  "2a", "2b", "2c", "2d", "2e", "2f", "30", "31", "32", "33", "34", "35", "36", "37",
  "38", "39", "3a", "3b", "3c", "3d", "3e", "3f", "40", "41", "42", "43", "44", "45",
  "46", "47", "48", "49", "4a", "4b", "4c", "4d", "4e", "4f", "50", "51", "52", "53",
  "54", "55", "56", "57", "58", "59", "5a", "5b", "5c", "5d", "5e", "5f", "60", "61",
  "62", "63", "64", "65", "66", "67", "68", "69", "6a", "6b", "6c", "6d", "6e", "6f",
  "70", "71", "72", "73", "74", "75", "76", "77", "78", "79", "7a", "7b", "7c", "7d",
  "7e", "7f", "80", "81", "82", "83", "84", "85", "86", "87", "88", "89", "8a", "8b",
  "8c", "8d", "8e", "8f", "90", "91", "92", "93", "94", "95", "96", "97", "98", "99",
  "9a", "9b", "9c", "9d", "9e", "9f", "a0", "a1", "a2", "a3", "a4", "a5", "a6", "a7",
  "a8", "a9", "aa", "ab", "ac", "ad", "ae", "af", "b0", "b1", "b2", "b3", "b4", "b5",
  "b6", "b7", "b8", "b9", "ba", "bb", "bc", "bd", "be", "bf", "c0", "c1", "c2", "c3",
  "c4", "c5", "c6", "c7", "c8", "c9", "ca", "cb", "cc", "cd", "ce", "cf", "d0", "d1",
  "d2", "d3", "d4", "d5", "d6", "d7", "d8", "d9", "da", "db", "dc", "dd", "de", "df",
  "e0", "e1", "e2", "e3", "e4", "e5", "e6", "e7", "e8", "e9", "ea", "eb", "ec", "ed",
  "ee", "ef", "f0", "f1", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f9", "fa", "fb",
  "fc", "fd", "fe", "ff",
]

///|
let _seed : Ref[Double] = { val: 1234567.0, }

///|
/// Multiply degrees by this to get radians (`Math.PI / 180`).
pub const DEG2RAD : Double = 0.017453292519943295

///|
/// Multiply radians by this to get degrees (`180 / Math.PI`).
pub const RAD2DEG : Double = 57.29577951308232

///|
/// `Math.LN2`.
let _ln2 : Double = 0.6931471805599453

///|
/// `Math.random`.
fn math_utils_random() -> Double = "Math" "random"

///|
/// `Math.max`: unlike `Double::max`, a NaN argument gives NaN.
fn math_utils_max(a : Double, b : Double) -> Double = "Math" "max"

///|
/// `Math.min`: unlike `Double::min`, a NaN argument gives NaN.
fn math_utils_min(a : Double, b : Double) -> Double = "Math" "min"

///|
/// ECMAScript ToInt32 (`x | 0`): wraps, where `Double::to_int` saturates.
extern "js" fn math_utils_to_int32(x : Double) -> Int32 =
  #|(x) => x | 0

///|
/// JS `t >>> n` on a 32-bit value, reinterpreted as `Int`.
fn math_utils_ushr(t : Int32, n : Int32) -> Int32 {
  (t.reinterpret_as_uint() >> n).reinterpret_as_int()
}

///|
/// Pads `array` with zeros up to `length`; JS assignment past the end grows it.
fn math_utils_grow(array : Array[Double], length : Int32) -> Unit {
  while array.length() < length {
    array.push(0.0)
  }
}

///|
/// Generates a UUID (universally unique identifier).
pub fn generate_uuid() -> String {
  // http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript/21963136#21963136
  let d0 = math_utils_to_int32(math_utils_random() * 4294967295.0)
  let d1 = math_utils_to_int32(math_utils_random() * 4294967295.0)
  let d2 = math_utils_to_int32(math_utils_random() * 4294967295.0)
  let d3 = math_utils_to_int32(math_utils_random() * 4294967295.0)
  _lut[d0 & 0xff] +
  _lut[(d0 >> 8) & 0xff] +
  _lut[(d0 >> 16) & 0xff] +
  _lut[(d0 >> 24) & 0xff] +
  "-" +
  _lut[d1 & 0xff] +
  _lut[(d1 >> 8) & 0xff] +
  "-" +
  _lut[((d1 >> 16) & 0x0f) | 0x40] +
  _lut[(d1 >> 24) & 0xff] +
  "-" +
  _lut[(d2 & 0x3f) | 0x80] +
  _lut[(d2 >> 8) & 0xff] +
  "-" +
  _lut[(d2 >> 16) & 0xff] +
  _lut[(d2 >> 24) & 0xff] +
  _lut[d3 & 0xff] +
  _lut[(d3 >> 8) & 0xff] +
  _lut[(d3 >> 16) & 0xff] +
  _lut[(d3 >> 24) & 0xff]
}

///|
/// Clamps `value` to the range `[min, max]`.
pub fn clamp(value : Double, min : Double, max : Double) -> Double {
  math_utils_max(min, math_utils_min(max, value))
}

///|
/// Euclidean modulo of `n` and `m`; the result has the sign of `m`.
pub fn euclidean_modulo(n : Double, m : Double) -> Double {
  // https://en.wikipedia.org/wiki/Modulo_operation
  (n % m + m) % m
}

///|
/// Linearly maps `x` from the range `[a1, a2]` to `[b1, b2]`.
pub fn map_linear(
  x : Double,
  a1 : Double,
  a2 : Double,
  b1 : Double,
  b2 : Double,
) -> Double {
  b1 + (x - a1) * (b2 - b1) / (a2 - a1)
}

///|
/// Returns the percentage in `[0, 1]` of `value` between `x` and `y`.
pub fn inverse_lerp(x : Double, y : Double, value : Double) -> Double {
  // https://www.gamedev.net/tutorials/programming/general-and-gameplay-programming/inverse-lerp-a-super-useful-yet-often-overlooked-function-r5230/
  if x != y {
    (value - x) / (y - x)
  } else {
    0.0
  }
}

///|
/// Linear interpolation between `x` and `y`.
pub fn lerp(x : Double, y : Double, t : Double) -> Double {
  (1.0 - t) * x + t * y
}

///|
/// Framerate-independent damping from `x` towards `y`.
pub fn damp(x : Double, y : Double, lambda : Double, dt : Double) -> Double {
  lerp(x, y, 1.0 - @cmath.exp(-lambda * dt))
}

///|
/// Returns a value that alternates between `0` and `length`.
pub fn pingpong(x : Double, length~ : Double = 1.0) -> Double {
  // https://www.desmos.com/calculator/vcsjnyz7x4
  length - (euclidean_modulo(x, length * 2.0) - length).abs()
}

///|
/// Smoothly interpolates between `0` and `1` as `x` moves from `min` to `max`.
pub fn smoothstep(x : Double, min : Double, max : Double) -> Double {
  if x <= min {
    return 0.0
  }
  if x >= max {
    return 1.0
  }
  let x = (x - min) / (max - min)
  x * x * (3.0 - 2.0 * x)
}

///|
/// A variation on `smoothstep` with zero 1st and 2nd derivatives at the ends.
pub fn smootherstep(x : Double, min : Double, max : Double) -> Double {
  if x <= min {
    return 0.0
  }
  if x >= max {
    return 1.0
  }
  let x = (x - min) / (max - min)
  x * x * x * (x * (x * 6.0 - 15.0) + 10.0)
}

///|
/// Random integer in the range `[low, high]`.
pub fn rand_int(low : Double, high : Double) -> Double {
  low + (math_utils_random() * (high - low + 1.0)).floor()
}

///|
/// Random float in the range `[low, high]`.
pub fn rand_float(low : Double, high : Double) -> Double {
  low + math_utils_random() * (high - low)
}

///|
/// Random float in the range `[-range / 2, range / 2]`.
pub fn rand_float_spread(range : Double) -> Double {
  range * (0.5 - math_utils_random())
}

///|
/// Deterministic pseudo-random float in `[0, 1)`; `s` reseeds the generator.
pub fn seeded_random(s? : Double) -> Double {
  if s is Some(s) {
    _seed.val = s
  }
  // Mulberry32 generator. As upstream, the seed itself stays an unwrapped
  // double; only its use as `t` goes through ToInt32.
  _seed.val += 1831565813.0
  let mut t = math_utils_to_int32(_seed.val)
  t = (t ^ math_utils_ushr(t, 15)) * (t | 1)
  t = t ^ (t + (t ^ math_utils_ushr(t, 7)) * (t | 61))
  (t ^ math_utils_ushr(t, 14)).reinterpret_as_uint().to_double() / 4294967296.0
}

///|
/// Converts degrees to radians.
pub fn deg_to_rad(degrees : Double) -> Double {
  degrees * DEG2RAD
}

///|
/// Converts radians to degrees.
pub fn rad_to_deg(radians : Double) -> Double {
  radians * RAD2DEG
}

///|
/// Returns `true` if `value` is a power of two.
pub fn is_power_of_two(value : Double) -> Bool {
  value > 0.0 &&
  !value.is_inf() &&
  value.floor() == value &&
  @cmath.pow(2.0, @cmath.log2(value).round()) == value
}

///|
/// Returns the smallest power of two that is greater than or equal to `value`.
pub fn ceil_power_of_two(value : Double) -> Double {
  @cmath.pow(2.0, (@cmath.ln(value) / _ln2).ceil())
}

///|
/// Returns the largest power of two that is less than or equal to `value`.
pub fn floor_power_of_two(value : Double) -> Double {
  @cmath.pow(2.0, (@cmath.ln(value) / _ln2).floor())
}

///|
/// Sets `q` from intrinsic Proper Euler Angles `a`, `b`, `c` in the given order.
pub fn set_quaternion_from_proper_euler(
  q : Quaternion,
  a : Double,
  b : Double,
  c : Double,
  order : String,
) -> Unit {
  let c2 = @cmath.cos(b / 2.0)
  let s2 = @cmath.sin(b / 2.0)
  let c13 = @cmath.cos((a + c) / 2.0)
  let s13 = @cmath.sin((a + c) / 2.0)
  let c1_3 = @cmath.cos((a - c) / 2.0)
  let s1_3 = @cmath.sin((a - c) / 2.0)
  let c3_1 = @cmath.cos((c - a) / 2.0)
  let s3_1 = @cmath.sin((c - a) / 2.0)
  match order {
    "XYX" => ignore(q.set(c2 * s13, s2 * c1_3, s2 * s1_3, c2 * c13))
    "YZY" => ignore(q.set(s2 * s1_3, c2 * s13, s2 * c1_3, c2 * c13))
    "ZXZ" => ignore(q.set(s2 * c1_3, s2 * s1_3, c2 * s13, c2 * c13))
    "XZX" => ignore(q.set(c2 * s13, s2 * s3_1, s2 * c3_1, c2 * c13))
    "YXY" => ignore(q.set(s2 * c3_1, c2 * s13, s2 * s3_1, c2 * c13))
    "ZYZ" => ignore(q.set(s2 * s3_1, s2 * c3_1, c2 * s13, c2 * c13))
    _ =>
      println(
        "MathUtils: .setQuaternionFromProperEuler() encountered an unknown order: " +
        order,
      )
  }
}

///|
/// Stands in for `array.constructor`, which selects the normalization scale.
pub(all) enum TypedArrayKind {
  Float32Array
  Uint32Array
  Uint16Array
  Uint8Array
  Uint8ClampedArray
  Int32Array
  Int16Array
  Int8Array
  Other
}

///|
/// Returns the scale of a normalized integer array, or `None` if it has none.
pub fn get_normalization_scale(array : TypedArrayKind) -> Double? {
  match array {
    Uint32Array => Some(4294967295.0)
    Uint16Array => Some(65535.0)
    Uint8Array | Uint8ClampedArray => Some(255.0)
    Int32Array => Some(2147483647.0)
    Int16Array => Some(32767.0)
    Int8Array => Some(127.0)
    Float32Array | Other => None
  }
}

///|
/// Denormalizes `value` according to the given array kind.
pub fn denormalize(value : Double, array : TypedArrayKind) -> Double {
  if array is Float32Array {
    return value
  }
  guard get_normalization_scale(array) is Some(scale) else {
    abort("THREE.MathUtils: Invalid component type.")
  }
  math_utils_max(value / scale, -1.0)
}

///|
/// Normalizes `value` according to the given array kind.
pub fn normalize(value : Double, array : TypedArrayKind) -> Double {
  if array is Float32Array {
    return value
  }
  guard get_normalization_scale(array) is Some(scale) else {
    abort("THREE.MathUtils: Invalid component type.")
  }
  (value * scale).round()
}
