// Reading upstream's JSON formats. Upstream reads plain objects (`data.foo`); here an
// absent key is `undefined` and a malformed value aborts where upstream would throw.

///|
/// `data.key`, with `null` for `undefined` so that the readers below report it.
fn json_field(data : Map[String, Json], key : String) -> Json {
  match data.get(key) {
    Some(value) => value
    None => Json::null()
  }
}

///|
fn json_object(json : Json, what : String) -> Map[String, Json] {
  guard json is Object(object) else { abort("\{what}: expected an object") }
  object
}

///|
fn json_array(json : Json, what : String) -> Array[Json] {
  guard json is Array(array) else { abort("\{what}: expected an array") }
  array
}

///|
/// A number upstream assigns as it is. `null`, which `JSON.stringify` writes for NaN and
/// the infinities, reads as NaN so that it is written back as `null`.
fn json_number(json : Json, what : String) -> Double {
  guard @math.json_to_number(json) is Some(value) else {
    abort("\{what}: expected a number")
  }
  value
}

///|
fn json_string(json : Json, what : String) -> String {
  guard json is String(value) else { abort("\{what}: expected a string") }
  value
}

///|
fn json_bool(json : Json, what : String) -> Bool {
  match json {
    True => true
    False => false
    _ => abort("\{what}: expected a boolean")
  }
}

///|
fn json_numbers(json : Json, what : String) -> Array[Double] {
  json_array(json, what).map(value => json_number(value, what))
}

///|
/// The numbers of a JSON array as a typed array constructor converts them: `null` is 0.
fn json_typed_numbers(json : Json, what : String) -> Array[Double] {
  json_array(json, what).map(value => {
    match value {
      Null => 0.0
      _ => json_number(value, what)
    }
  })
}

///|
/// `data.key !== undefined`, as a number.
fn json_opt_number(data : Map[String, Json], key : String) -> Double? {
  match data.get(key) {
    None => None
    Some(value) => Some(json_number(value, key))
  }
}

///|
fn json_opt_int(data : Map[String, Json], key : String) -> Int32? {
  match data.get(key) {
    None => None
    Some(value) => Some(json_number(value, key).to_int())
  }
}

///|
fn json_opt_bool(data : Map[String, Json], key : String) -> Bool? {
  match data.get(key) {
    None => None
    Some(value) => Some(json_bool(value, key))
  }
}

///|
fn json_opt_string(data : Map[String, Json], key : String) -> String? {
  match data.get(key) {
    None => None
    Some(value) => Some(json_string(value, key))
  }
}

///|
/// JS truthiness of `data.key`.
fn json_truthy(value : Json?) -> Bool {
  match value {
    None | Some(Null) | Some(False) => false
    Some(Number(n, ..)) => n != 0.0 && !n.is_nan()
    Some(String(s)) => s != ""
    Some(_) => true
  }
}

///|
/// The numbers of a JSON array as upstream hands them to a typed array constructor.
fn json_typed_array(
  type_ : Json,
  array : Json,
  what : String,
) -> @core.TypedArray {
  @core.TypedArray::new_by_name(
    json_string(type_, what),
    json_typed_numbers(array, what),
  )
}

///|
/// `JSON.parse( text )` for loader callbacks: returns the parsed value or the thrown error.
fn loaders_parse_json(text : JsValue) -> Result[Json, JsValue] {
  let result = js_try_json_parse(text)
  if result.ok() {
    Ok(result.value().to_json())
  } else {
    Err(result.error())
  }
}
