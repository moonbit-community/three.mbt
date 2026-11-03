// Upstream src/extras/DataUtils.js. The conversions live in `core` because
// Float16BufferAttribute needs them.

///|
pub using @core {to_half_float, from_half_float}

///|
#external
pub type DataUtils

///|
pub fn DataUtils::to_half_float(val : Double) -> Double {
  @core.to_half_float(val)
}

///|
pub fn DataUtils::from_half_float(val : Double) -> Double {
  @core.from_half_float(val)
}
