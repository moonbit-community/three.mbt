// Real JS typed arrays. Reads and writes go through the JS object, so Float32
// rounding, Uint8 clamping and integer wrapping all behave as in upstream, and the
// value can be handed to `gl.bufferData` directly.

///|
/// A JS typed array (`Float32Array`, `Uint16Array`, ...).
#external
pub type TypedArray

///|
/// A JS `ArrayBuffer`.
#external
pub type ArrayBuffer

///|
/// What `new Float32Array( init )` accepts: a length, an array or another typed array.
pub(open) trait TypedArrayInit {
  fn to_js_init(Self) -> JsValue
}

///|
pub impl TypedArrayInit for Int32 with fn to_js_init(self) {
  JsValue::of(self)
}

///|
/// `T` is a number type: `Array[Double]` or `Array[Int]`.
pub impl[T] TypedArrayInit for Array[T] with fn to_js_init(self) {
  JsValue::of(FixedArray::from_array(self[:]))
}

///|
pub impl TypedArrayInit for TypedArray with fn to_js_init(self) {
  JsValue::of(self)
}

///|
pub extend TypedArray with TypedArrayInit::{to_js_init}

///|
extern "js" fn typed_array_new_by_name(
  name : String,
  init : JsValue,
) -> TypedArray = "(n, i) => new globalThis[n](i)"

///|
extern "js" fn typed_array_view_by_name(
  name : String,
  buffer : ArrayBuffer,
  byte_offset : Int32,
  length : Int32,
) -> TypedArray =
  #|(n, b, o, l) => l < 0 ? new globalThis[n](b, o) : new globalThis[n](b, o, l)

///|
fn typed_array_kind_name(kind : @math.TypedArrayKind) -> String {
  match kind {
    Float32Array => "Float32Array"
    Uint32Array => "Uint32Array"
    Uint16Array => "Uint16Array"
    Uint8Array => "Uint8Array"
    Uint8ClampedArray => "Uint8ClampedArray"
    Int32Array => "Int32Array"
    Int16Array => "Int16Array"
    Int8Array => "Int8Array"
    Other => abort("TypedArray: TypedArrayKind.Other has no constructor")
  }
}

///|
/// `new Kind( init )`.
pub fn[A : TypedArrayInit] TypedArray::new(
  kind : @math.TypedArrayKind,
  init : A,
) -> TypedArray {
  typed_array_new_by_name(typed_array_kind_name(kind), init.to_js_init())
}

///|
/// `new globalThis[ name ]( init )`; reaches kinds `TypedArrayKind` lacks, such as
/// `Float64Array`.
pub fn[A : TypedArrayInit] TypedArray::new_by_name(
  name : String,
  init : A,
) -> TypedArray {
  typed_array_new_by_name(name, init.to_js_init())
}

///|
/// `new globalThis[ name ]( buffer, byte_offset, length )`.
pub fn TypedArray::view_by_name(
  name : String,
  buffer : ArrayBuffer,
  byte_offset~ : Int32 = 0,
  length? : Int32,
) -> TypedArray {
  typed_array_view_by_name(name, buffer, byte_offset, length.unwrap_or(-1))
}

///|
/// `new Float32Array( init )`.
pub fn[A : TypedArrayInit] TypedArray::float32(init : A) -> TypedArray {
  TypedArray::new(Float32Array, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::float64(init : A) -> TypedArray {
  TypedArray::new_by_name("Float64Array", init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::uint32(init : A) -> TypedArray {
  TypedArray::new(Uint32Array, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::uint16(init : A) -> TypedArray {
  TypedArray::new(Uint16Array, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::uint8(init : A) -> TypedArray {
  TypedArray::new(Uint8Array, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::uint8_clamped(init : A) -> TypedArray {
  TypedArray::new(Uint8ClampedArray, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::int32(init : A) -> TypedArray {
  TypedArray::new(Int32Array, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::int16(init : A) -> TypedArray {
  TypedArray::new(Int16Array, init)
}

///|
pub fn[A : TypedArrayInit] TypedArray::int8(init : A) -> TypedArray {
  TypedArray::new(Int8Array, init)
}

///|
/// `array.constructor.name`.
pub extern "js" fn TypedArray::type_name(self : TypedArray) -> String = "(a) => a.constructor.name"

///|
/// Stands in for `array.constructor`; kinds `TypedArrayKind` lacks map to `Other`.
pub fn TypedArray::kind(self : TypedArray) -> @math.TypedArrayKind {
  match self.type_name() {
    "Float32Array" => Float32Array
    "Uint32Array" => Uint32Array
    "Uint16Array" => Uint16Array
    "Uint8Array" => Uint8Array
    "Uint8ClampedArray" => Uint8ClampedArray
    "Int32Array" => Int32Array
    "Int16Array" => Int16Array
    "Int8Array" => Int8Array
    _ => Other
  }
}

///|
pub extern "js" fn TypedArray::length(self : TypedArray) -> Int32 = "(a) => a.length"

///|
#alias("_[_]")
pub extern "js" fn TypedArray::get(self : TypedArray, index : Int32) -> Double = "(a, i) => a[i]"

///|
#alias("_[_]=_")
pub extern "js" fn TypedArray::set(
  self : TypedArray,
  index : Int32,
  value : Double,
) -> Unit = "(a, i, v) => { a[i] = v; }"

///|
/// `array[ index ] | 0`, for index data.
pub extern "js" fn TypedArray::get_int(
  self : TypedArray,
  index : Int32,
) -> Int32 = "(a, i) => a[i] | 0"

///|
extern "js" fn typed_array_set_from(
  array : TypedArray,
  source : JsValue,
  offset : Int32,
) -> Unit = "(a, s, o) => a.set(s, o)"

///|
/// `array.set( source, offset )`.
pub fn[A : TypedArrayInit] TypedArray::set_from(
  self : TypedArray,
  source : A,
  offset~ : Int32 = 0,
) -> Unit {
  typed_array_set_from(self, source.to_js_init(), offset)
}

///|
extern "js" fn typed_array_slice(
  array : TypedArray,
  start : Int32,
  end : JsValue,
) -> TypedArray = "(a, s, e) => a.slice(s, e)"

///|
/// `array.slice( start, end )`; a copy with its own buffer.
pub fn TypedArray::slice(
  self : TypedArray,
  start~ : Int32 = 0,
  end? : Int32,
) -> TypedArray {
  typed_array_slice(
    self,
    start,
    match end {
      Some(end) => JsValue::of(end)
      None => JsValue::undefined()
    },
  )
}

///|
extern "js" fn typed_array_subarray(
  array : TypedArray,
  start : Int32,
  end : JsValue,
) -> TypedArray = "(a, s, e) => a.subarray(s, e)"

///|
/// `array.subarray( start, end )`; a view over the same buffer.
pub fn TypedArray::subarray(
  self : TypedArray,
  start~ : Int32 = 0,
  end? : Int32,
) -> TypedArray {
  typed_array_subarray(
    self,
    start,
    match end {
      Some(end) => JsValue::of(end)
      None => JsValue::undefined()
    },
  )
}

///|
extern "js" fn typed_array_to_fixed(array : TypedArray) -> FixedArray[Double] = "(a) => Array.from(a)"

///|
/// `Array.from( array )`.
pub fn TypedArray::to_array(self : TypedArray) -> Array[Double] {
  Array::from_fixed_array(typed_array_to_fixed(self))
}

///|
/// `new array.constructor( array )`.
pub extern "js" fn TypedArray::clone(self : TypedArray) -> TypedArray = "(a) => new a.constructor(a)"

///|
/// `new array.constructor( init )`.
pub fn[A : TypedArrayInit] TypedArray::new_like(
  self : TypedArray,
  init : A,
) -> TypedArray {
  typed_array_new_by_name(self.type_name(), init.to_js_init())
}

///|
/// `new array.constructor( buffer )`.
pub extern "js" fn TypedArray::new_like_from_buffer(
  self : TypedArray,
  buffer : ArrayBuffer,
) -> TypedArray = "(a, b) => new a.constructor(b)"

///|
pub extern "js" fn TypedArray::fill(self : TypedArray, value : Double) -> Unit = "(a, v) => a.fill(v)"

///|
pub extern "js" fn TypedArray::buffer(self : TypedArray) -> ArrayBuffer = "(a) => a.buffer"

///|
pub extern "js" fn TypedArray::byte_offset(self : TypedArray) -> Int32 = "(a) => a.byteOffset"

///|
pub extern "js" fn TypedArray::byte_length(self : TypedArray) -> Int32 = "(a) => a.byteLength"

///|
pub extern "js" fn TypedArray::bytes_per_element(self : TypedArray) -> Int32 = "(a) => a.BYTES_PER_ELEMENT"

///|
pub extern "js" fn ArrayBuffer::new(byte_length : Int32) -> ArrayBuffer = "(n) => new ArrayBuffer(n)"

///|
pub extern "js" fn ArrayBuffer::byte_length(self : ArrayBuffer) -> Int32 = "(b) => b.byteLength"

///|
/// The uuid upstream stores as `buffer._uuid`, generated on first use.
pub fn ArrayBuffer::uuid(self : ArrayBuffer) -> String {
  let holder = JsValue::of(self)
  let existing = holder.get("_uuid")
  if existing.is_undefined() {
    let uuid = @math.generate_uuid()
    holder.set("_uuid", JsValue::of(uuid))
    uuid
  } else {
    existing.cast()
  }
}
