// The parts of upstream src/utils.js that core needs. Logging stays on `println`
// (see PORTING.md) so that one file changes when a real `utils` exists.

///|
extern "js" fn utils_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
extern "js" fn utils_math_round(a : Double) -> Double = "Math.round"

///|
extern "js" fn utils_is_finite(a : Double) -> Bool = "isFinite"

///|
extern "js" fn utils_performance_now() -> Double = "() => performance.now()"

///|
/// Upstream `log`.
pub fn log(message : String) -> Unit {
  println("THREE." + message)
}

///|
/// Upstream `warn`.
pub fn warn(message : String) -> Unit {
  println("THREE." + message)
}

///|
/// Upstream `error`.
pub fn error(message : String) -> Unit {
  println("THREE." + message)
}

///|
let utils_warned : Map[String, Bool] = Map([])

///|
/// Upstream `warnOnce`.
pub fn warn_once(message : String) -> Unit {
  if utils_warned.contains(message) {
    return
  }
  utils_warned[message] = true
  warn(message)
}

///|
/// Upstream `arrayNeedsUint32`: true if any value is `>= 65535`.
pub fn array_needs_uint32(array : Array[Double]) -> Bool {
  // assumes larger values usually on last
  for i = array.length() - 1; i >= 0; i = i - 1 {
    if array[i] >= 65535.0 {
      return true // account for PRIMITIVE_RESTART_FIXED_INDEX, #24565
    }
  }
  false
}

///|
fn json_numbers(values : Array[Double]) -> Json {
  @math.json_numbers(values)
}

///|
fn json_int(value : Int32) -> Json {
  Json::number(value.to_double())
}
