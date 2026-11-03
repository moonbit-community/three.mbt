// nodes/core/NodeUtils.js. `mergeContext` is `NodeContext::merge` (core_node_builder.mbt).

///|
extern "js" fn js_imul(a : Double, b : Double) -> Double = "(a, b) => Math.imul(a, b)"

///|
extern "js" fn js_xor(a : Double, b : Double) -> Double = "(a, b) => a ^ b"

///|
extern "js" fn js_and(a : Double, b : Double) -> Double = "(a, b) => a & b"

///|
extern "js" fn js_ushr(a : Double, b : Int32) -> Double = "(a, b) => a >>> b"

///|
/// The cyrb53 finalizer over already-mixed `h1`, `h2`.
fn cyrb53_finish(h1 : Double, h2 : Double) -> Double {
  let mut h1 = h1
  let mut h2 = h2
  h1 = js_imul(js_xor(h1, js_ushr(h1, 16)), 2246822507.0)
  h1 = js_xor(h1, js_imul(js_xor(h2, js_ushr(h2, 13)), 3266489909.0))
  h2 = js_imul(js_xor(h2, js_ushr(h2, 16)), 2246822507.0)
  h2 = js_xor(h2, js_imul(js_xor(h1, js_ushr(h1, 13)), 3266489909.0))
  4294967296.0 * js_and(2097151.0, h2) + js_ushr(h1, 0)
}

///|
/// `cyrb53( string )`.
pub fn hash_string(str : String) -> Double {
  let mut h1 = js_xor(3735928559.0, 0.0)
  let mut h2 = js_xor(1103547991.0, 0.0)
  for i in 0..<str.length() {
    let ch = str.unsafe_get(i).to_int().to_double()
    h1 = js_imul(js_xor(h1, ch), 2654435761.0)
    h2 = js_imul(js_xor(h2, ch), 1597334677.0)
  }
  cyrb53_finish(h1, h2)
}

///|
/// `cyrb53( array )`: JS `^` truncates each value to 32 bits.
pub fn hash_array(array : Array[Double]) -> Double {
  let mut h1 = js_xor(3735928559.0, 0.0)
  let mut h2 = js_xor(1103547991.0, 0.0)
  for val in array {
    h1 = js_imul(js_xor(h1, val), 2654435761.0)
    h2 = js_imul(js_xor(h2, val), 1597334677.0)
  }
  cyrb53_finish(h1, h2)
}

///|
/// `hash( ...params )`.
pub fn hash(params : Array[Double]) -> Double {
  hash_array(params)
}

///|
let _node_utils_type_from_length : Map[Int32, String] = {
  1: "float",
  2: "vec2",
  3: "vec3",
  4: "vec4",
  9: "mat3",
  16: "mat4",
}

///|
/// `dataFromObject`, a `WeakMap< Object, Object >`.
let _node_utils_data_from_object : @webgl.WeakMap[@core.JsValue, @core.JsValue] = @webgl.WeakMap::new()

///|
extern "js" fn node_utils_regex_test(pattern : String, value : String) -> Bool = "(p, v) => new RegExp(p).test(v)"

///|
extern "js" fn node_utils_js_truthy(value : @core.JsValue) -> Bool = "(v) => !!v"

///|
extern "js" fn node_utils_js_value_type(value : @core.JsValue) -> @core.JsValue =
  #|(v) => {
  #|  if ( v === undefined || v === null ) return null;
  #|  const t = typeof v;
  #|  if ( v.isNode === true ) return 'node';
  #|  if ( t === 'number' ) return 'float';
  #|  if ( t === 'boolean' ) return 'bool';
  #|  if ( t === 'string' ) return 'string';
  #|  if ( t === 'function' ) return 'shader';
  #|  if ( v.isVector2 === true ) return 'vec2';
  #|  if ( v.isVector3 === true ) return 'vec3';
  #|  if ( v.isVector4 === true ) return 'vec4';
  #|  if ( v.isMatrix2 === true ) return 'mat2';
  #|  if ( v.isMatrix3 === true ) return 'mat3';
  #|  if ( v.isMatrix4 === true ) return 'mat4';
  #|  if ( v.isColor === true ) return 'color';
  #|  if ( v instanceof ArrayBuffer ) return 'ArrayBuffer';
  #|  return null;
  #|}

///|
extern "js" fn node_utils_js_is_plain_object(value : @core.JsValue) -> Bool = "(v) => v !== undefined && v !== null && Object.getPrototypeOf( v ) === Object.prototype"

///|
extern "js" fn node_utils_js_nullish(value : @core.JsValue) -> Bool = "(v) => v === undefined || v === null"

///|
extern "js" fn node_utils_js_number(value : String) -> Double = "(v) => Number(v)"

///|
/// `Math.floor( hex )` truncated to 32 bits, as `Color.setHex`'s `>>` sees it.
extern "js" fn node_utils_hex(value : Double) -> Int32 = "(v) => Math.floor(v) | 0"

///|
extern "js" fn node_utils_array_buffer_to_base64(
  buffer : @core.JsValue,
) -> String =
  #|(arrayBuffer) => {
  #|  let chars = '';
  #|  const array = new Uint8Array( arrayBuffer );
  #|  for ( let i = 0; i < array.length; i ++ ) {
  #|    chars += String.fromCharCode( array[ i ] );
  #|  }
  #|  return btoa( chars );
  #|}

///|
extern "js" fn node_utils_base64_to_array_buffer(
  base64 : String,
) -> @core.ArrayBuffer = "(base64) => Uint8Array.from( atob( base64 ), c => c.charCodeAt( 0 ) ).buffer"

///|
/// JS truthiness of a TSL value (`Boolean( value )`).
fn tsl_truthy(value : TslValue) -> Bool {
  match value {
    Undefined | Null => false
    Number(d) => d != 0.0 && d == d
    Bool(b) => b
    String(s) => s != ""
    Js(v) => node_utils_js_truthy(v)
    _ => true
  }
}

///|
/// JS `Number( value )` of a primitive TSL value; `undefined` is `NaN`.
fn tsl_to_number(value : TslValue) -> Double {
  match value {
    Number(d) => d
    Bool(b) => if b { 1.0 } else { 0.0 }
    String(s) => node_utils_js_number(s)
    Null => 0.0
    _ => node_utils_nan()
  }
}

///|
/// `getTypeFromLength( length )`; `None` is `undefined`.
pub fn get_type_from_length(length : Int32) -> String? {
  _node_utils_type_from_length.get(length)
}

///|
/// `getTypedArrayFromType( type )`: the typed array class for a data type.
pub fn get_typed_array_from_type(type_ : String) -> @math.TypedArrayKind {
  // Handle component type for vectors and matrices
  if node_utils_regex_test("[iu]?vec\\d", type_) {
    // Handle int vectors
    if type_.has_prefix("ivec") {
      return Int32Array
    }
    // Handle uint vectors
    if type_.has_prefix("uvec") {
      return Uint32Array
    }
    // Default to float vectors
    return Float32Array
  }
  // Handle matrices (always float)
  if node_utils_regex_test("mat\\d", type_) {
    return Float32Array
  }
  // Basic types
  if node_utils_regex_test("float", type_) {
    return Float32Array
  }
  if node_utils_regex_test("uint", type_) {
    return Uint32Array
  }
  if node_utils_regex_test("int", type_) {
    return Int32Array
  }
  abort("THREE.NodeUtils: Unsupported type: \{type_}")
}

///|
/// The first of `lengths` whose pattern matches `type_`, else the upstream error and
/// 0 (upstream returns `undefined`).
fn node_utils_length_by_pattern(
  type_ : String,
  lengths : Array[(String, Int32)],
) -> Int32 {
  for entry in lengths {
    if node_utils_regex_test(entry.0, type_) {
      return entry.1
    }
  }
  @core.error("TSL: Unsupported type: \{type_}")
  0
}

///|
/// `getLengthFromType( type )`: the number of components.
pub fn get_length_from_type(type_ : String) -> Int32 {
  node_utils_length_by_pattern(type_, [
    ("float|int|uint|bool", 1),
    ("vec2", 2),
    ("vec3", 3),
    ("vec4", 4),
    ("mat2", 4),
    ("mat3", 9),
    ("mat4", 16),
  ])
}

///|
/// `getMemoryLengthFromType( type )`: the GPU memory length in 4-byte elements.
pub fn get_memory_length_from_type(type_ : String) -> Int32 {
  node_utils_length_by_pattern(type_, [
    ("float|int|uint|bool", 1),
    ("vec2", 2),
    ("vec3", 3),
    ("vec4", 4),
    ("mat2", 4),
    ("mat3", 12),
    ("mat4", 16),
  ])
}

///|
/// `getAlignmentFromType( type )`: the alignment in 4-byte elements.
pub fn get_alignment_from_type(type_ : String) -> Int32 {
  node_utils_length_by_pattern(type_, [
    ("float|int|uint|bool", 1),
    ("vec2", 2),
    ("vec3", 4),
    ("vec4", 4),
    ("mat2", 2),
    ("mat3", 4),
    ("mat4", 4),
  ])
}

///|
/// `getValueType( value )`: the data type of a TSL value; `None` is `null`.
pub fn get_value_type(value : TslValue) -> String? {
  match value {
    Undefined | Null => None
    Node(_) => Some("node")
    Number(_) => Some("float")
    Bool(_) => Some("bool")
    String(_) => Some("string")
    Shader(_) => Some("shader")
    Vector2(_) => Some("vec2")
    Vector3(_) => Some("vec3")
    Vector4(_) => Some("vec4")
    Matrix2(_) => Some("mat2")
    Matrix3(_) => Some("mat3")
    Matrix4(_) => Some("mat4")
    Color(_) => Some("color")
    Texture(_) | Array(_) | Object(_) => None
    Js(v) => {
      let t = node_utils_js_value_type(v)
      if node_utils_js_nullish(t) {
        None
      } else {
        Some(t.cast())
      }
    }
  }
}

///|
/// `getTextureType( texture )`: the node data type of a texture.
pub fn get_texture_type(texture : @core.Texture) -> String {
  if texture.is_depth_texture() {
    return "float"
  }
  let format = texture.format
  let length = if format == @core.RedFormat ||
    format == @core.RedIntegerFormat ||
    format == @core.DepthFormat ||
    format == @core.DepthStencilFormat ||
    format == @core.AlphaFormat {
    1
  } else if format == @core.RGFormat || format == @core.RGIntegerFormat {
    2
  } else if format == @core.RGBFormat || format == @core.RGBIntegerFormat {
    3
  } else {
    4
  }
  let component_type = if texture.type_ == @core.UnsignedIntType {
    "uint"
  } else if texture.type_ == @core.IntType {
    "int"
  } else {
    "float"
  }
  if length == 1 {
    return component_type
  }
  let base_type = get_type_from_length(length).unwrap()
  if component_type != "float" {
    component_type.unsafe_substring(start=0, end=1) + base_type
  } else {
    base_type
  }
}

///|
/// `getValueFromType( type, ...params )`: the value (`Vector3`, `Color`, number, ...)
/// for a data type; `Null` is `null`.
pub fn get_value_from_type(
  type_ : String?,
  params : Array[TslValue],
) -> TslValue {
  let last4 = match type_ {
    Some(t) =>
      Some(
        if t.length() > 4 {
          t.unsafe_substring(start=t.length() - 4, end=t.length())
        } else {
          t
        },
      )
    None => None
  }
  let mut params = params
  if params.length() == 1 {
    // ensure same behaviour as in NodeBuilder.format()
    let p = params[0]
    if last4 == Some("vec2") {
      params = [p, p]
    } else if last4 == Some("vec3") {
      params = [p, p, p]
    } else if last4 == Some("vec4") {
      params = [p, p, p, p]
    }
  }
  let param = fn(i : Int32) -> TslValue {
    if i < params.length() {
      params[i]
    } else {
      Undefined
    }
  }
  // `new Vector3( x = 0, ... )`: `undefined` takes the default
  let component = fn(i : Int32) -> Double {
    match param(i) {
      Undefined => 0.0
      v => tsl_to_number(v)
    }
  }
  if type_ == Some("color") {
    TslValue::Color(node_utils_new_color(param(0), param(1), param(2)))
  } else if last4 == Some("vec2") {
    Vector2(@math.Vector2::new(component(0), component(1)))
  } else if last4 == Some("vec3") {
    Vector3(@math.Vector3::new(component(0), component(1), component(2)))
  } else if last4 == Some("vec4") {
    // `new Vector4( x = 0, y = 0, z = 0, w = 1 )`
    let w = match param(3) {
      Undefined => 1.0
      v => tsl_to_number(v)
    }
    Vector4(@math.Vector4::new(component(0), component(1), component(2), w))
  } else if last4 == Some("mat2") {
    let m = @math.Matrix2::new()
    if !(param(0) is Undefined) {
      let n = fn(i) { tsl_to_number(param(i)) }
      m.set(n(0), n(1), n(2), n(3)) |> ignore
    }
    Matrix2(m)
  } else if last4 == Some("mat3") {
    let m = @math.Matrix3::new()
    if !(param(0) is Undefined) {
      let n = fn(i) { tsl_to_number(param(i)) }
      m.set(n(0), n(1), n(2), n(3), n(4), n(5), n(6), n(7), n(8)) |> ignore
    }
    Matrix3(m)
  } else if last4 == Some("mat4") {
    let m = @math.Matrix4::new()
    if !(param(0) is Undefined) {
      let n = fn(i) { tsl_to_number(param(i)) }
      m.set(
        n(0),
        n(1),
        n(2),
        n(3),
        n(4),
        n(5),
        n(6),
        n(7),
        n(8),
        n(9),
        n(10),
        n(11),
        n(12),
        n(13),
        n(14),
        n(15),
      )
      |> ignore
    }
    Matrix4(m)
  } else if type_ == Some("bool") {
    if tsl_truthy(param(0)) {
      param(0)
    } else {
      Bool(false)
    }
  } else if type_ == Some("float") ||
    type_ == Some("int") ||
    type_ == Some("uint") {
    if tsl_truthy(param(0)) {
      param(0)
    } else {
      Number(0.0)
    }
  } else if type_ == Some("string") {
    if tsl_truthy(param(0)) {
      param(0)
    } else {
      String("")
    }
  } else if type_ == Some("ArrayBuffer") {
    match param(0) {
      String(s) => Js(@core.JsValue::of(base64_to_array_buffer(s)))
      _ => abort("getValueFromType: ArrayBuffer needs a Base64 string")
    }
  } else {
    Null
  }
}

///|
/// `new Color( r, g, b )`.
fn node_utils_new_color(
  r : TslValue,
  g : TslValue,
  b : TslValue,
) -> @math.Color {
  let color = @math.Color::new(1.0, 1.0, 1.0)
  if g is Undefined && b is Undefined {
    // r is THREE.Color, hex or string
    match r {
      Color(c) => color.copy(c) |> ignore
      Number(hex) => color.set_hex(node_utils_hex(hex)) |> ignore
      String(style) => color.set_style(style) |> ignore
      _ => ()
    }
  } else {
    color.set_rgb(tsl_to_number(r), tsl_to_number(g), tsl_to_number(b))
    |> ignore
  }
  color
}

///|
/// `getDataFromObject( object )`: data shared between rendering steps.
pub fn get_data_from_object(object : @core.JsValue) -> @core.JsValue {
  match _node_utils_data_from_object.get(object) {
    Some(data) => data
    None => {
      let data = @core.JsValue::object()
      _node_utils_data_from_object.set(object, data)
      data
    }
  }
}

///|
/// `arrayBufferToBase64( arrayBuffer )`.
pub fn array_buffer_to_base64(array_buffer : @core.JsValue) -> String {
  node_utils_array_buffer_to_base64(array_buffer)
}

///|
/// `base64ToArrayBuffer( base64 )`.
pub fn base64_to_array_buffer(base64 : String) -> @core.ArrayBuffer {
  node_utils_base64_to_array_buffer(base64)
}

///|
/// `isArrayAsParameter( params )`: whether call parameters are positional (not a
/// single plain object).
pub fn is_array_as_parameter(params : Array[TslValue]) -> Bool {
  if params.length() == 0 {
    return false
  }
  match params[0] {
    Undefined | Null | Object(_) => false
    Js(v) => !node_utils_js_nullish(v) && !node_utils_js_is_plain_object(v)
    _ => true
  }
}

///|
extern "js" fn node_utils_nan() -> Double = "() => NaN"
