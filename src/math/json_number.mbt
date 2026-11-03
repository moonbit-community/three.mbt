// Numbers in JSON as upstream writes and reads them. Upstream's `toJSON` methods return
// plain numbers and `JSON.stringify` writes NaN and the infinities as `null` (and -0 as
// 0); `fromJSON` then assigns that `null` to the property. `Json::stringify` would print
// the invalid tokens `Infinity` and `NaN`, so writers use `json_number`, whose `Json` is
// the value of upstream's text, and readers take `null` as NaN (`json_to_number`), which
// is written back as `null` again.

///|
let _json_number_nan : Double = 0.0 / 0.0

///|
/// A number as `JSON.stringify` writes it: NaN and the infinities become `null`, and -0
/// becomes 0, so that the `Json` is the value of upstream's text.
pub fn json_number(value : Double) -> Json {
  if value.is_nan() || value.is_inf() {
    Json::null()
  } else if value == 0.0 {
    Json::number(0.0)
  } else {
    Json::number(value)
  }
}

///|
/// `json_number` of each element.
pub fn json_numbers(values : Array[Double]) -> Json {
  Json::array(values.map(json_number))
}

///|
/// A number where upstream assigns a JSON value to a numeric property: a number, or NaN
/// for `null`. Other values give `None`.
pub fn json_to_number(json : Json) -> Double? {
  match json {
    Number(value, ..) => Some(value)
    Null => Some(_json_number_nan)
    _ => None
  }
}
