// Upstream examples/jsm/loaders/EXRLoader.js. Upstream's `parse` is one closure whose
// helpers share `const` state (`getBitsReturn`, `hufTableBuffer`, the lazy B44 and DWA
// tables, the selected `EXRHeader`); that state is `ExrParse`, created per call as
// upstream creates it, and the helpers are its methods. Pixel data stays in JS typed
// arrays and DataViews, so typed-array rounding and wrapping, out-of-range reads
// (`undefined`) and DataView `RangeError`s behave as upstream. Integer reads that feed
// bitwise operators go through `get_int` (`a[ i ] | 0`), which is what those operators
// make of `undefined`. Upstream's `throw new Error( ... )` throws the same JS error.
//
// Referred to the original Industrial Light & Magic OpenEXR implementation and the
// TinyEXR / Syoyo Fujita implementation; see upstream for their copyright notices.

///|
/// A loader for the OpenEXR texture format.
pub(all) struct EXRLoader {
  mut base : @loaders.DataTextureLoader
  /// The texture type, `HalfFloatType` (default) or `FloatType`.
  mut type_ : Int32
  /// Texture output format: `RGBAFormat` (default), `RGFormat` or `RedFormat`.
  mut output_format : Int32
  /// For multi-part EXR files, the index of the part to load.
  mut part : Int32
}

///|
pub fn EXRLoader::new(manager? : @loaders.LoadingManager) -> EXRLoader {
  let loader : EXRLoader = {
    base: @loaders.DataTextureLoader::new(manager?),
    type_: @core.HalfFloatType,
    output_format: @core.RGBAFormat,
    part: 0,
  }
  loader.base = @loaders.DataTextureLoader::new(manager?, parse=buffer => {
    loader.parse(buffer)
  })
  loader
}

///|
pub impl @loaders.LoaderLike for EXRLoader with fn loader(self) {
  self.base.base
}

///|
pub impl @loaders.LoaderSettings for EXRLoader

///|
pub extend EXRLoader with @loaders.LoaderLike::{loader}

///|
pub extend EXRLoader with @loaders.LoaderSettings::{
  set_cross_origin,
  set_with_credentials,
  set_path,
  set_resource_path,
  set_request_header,
  set_priority,
  set_cache,
  abort,
}

///|
/// Starts loading `url` and returns the texture; `on_load` also gets the parsed data,
/// whose `extra` holds upstream's `header` object.
pub fn EXRLoader::load(
  self : EXRLoader,
  url : String,
  on_load? : (@core.Texture, @loaders.DataTexData) -> Unit,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
  on_error? : (@core.JsValue) -> Unit,
) -> @core.Texture {
  self.base.load(url, on_load?, on_progress?, on_error?)
}

///|
/// Upstream `loadAsync`.
pub async fn EXRLoader::load_async(
  self : EXRLoader,
  url : String,
  on_progress? : (@loaders.ProgressEvent) -> Unit,
) -> @core.Texture raise @loaders.LoaderError {
  self.base.load_async(url, on_progress?)
}

///|
/// Sets the texture type.
pub fn EXRLoader::set_data_type(self : EXRLoader, value : Int32) -> EXRLoader {
  self.type_ = value
  self
}

///|
/// Sets the texture output format.
pub fn EXRLoader::set_output_format(
  self : EXRLoader,
  value : Int32,
) -> EXRLoader {
  self.output_format = value
  self
}

///|
/// For multi-part EXR files, sets which part to load.
pub fn EXRLoader::set_part(self : EXRLoader, value : Int32) -> EXRLoader {
  self.part = value
  self
}

// --- JS bindings ------------------------------------------------------------------

///|
/// A JS `DataView`.
#external
priv type ExrDataView

///|
extern "js" fn ExrDataView::of_buffer(
  buffer : @core.ArrayBuffer,
) -> ExrDataView = "(b) => new DataView(b)"

///|
/// `new DataView( buffer, offset, length )`.
extern "js" fn ExrDataView::new(
  buffer : @core.ArrayBuffer,
  offset : Int32,
  length : Double,
) -> ExrDataView = "(b, o, l) => new DataView(b, o, l)"

///|
extern "js" fn ExrDataView::buffer(self : ExrDataView) -> @core.ArrayBuffer = "(v) => v.buffer"

///|
extern "js" fn ExrDataView::get_uint32(
  self : ExrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Double = "(v, o, l) => v.getUint32(o, l)"

///|
extern "js" fn ExrDataView::get_int32(
  self : ExrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Int32 = "(v, o, l) => v.getInt32(o, l)"

///|
extern "js" fn ExrDataView::get_uint16(
  self : ExrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Int32 = "(v, o, l) => v.getUint16(o, l)"

///|
extern "js" fn ExrDataView::get_uint8(
  self : ExrDataView,
  offset : Int32,
) -> Int32 = "(v, o) => v.getUint8(o)"

///|
extern "js" fn ExrDataView::get_int8(
  self : ExrDataView,
  offset : Int32,
) -> Int32 = "(v, o) => v.getInt8(o)"

///|
extern "js" fn ExrDataView::get_float32(
  self : ExrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Double = "(v, o, l) => v.getFloat32(o, l)"

///|
/// `Number( dataView.getBigInt64( offset, littleEndian ) )`.
extern "js" fn ExrDataView::get_big_int64_number(
  self : ExrDataView,
  offset : Int32,
  little_endian : Bool,
) -> Double = "(v, o, l) => Number(v.getBigInt64(o, l))"

///|
extern "js" fn ExrDataView::set_uint16(
  self : ExrDataView,
  offset : Int32,
  value : Double,
  little_endian : Bool,
) -> Unit = "(v, o, x, l) => v.setUint16(o, x, l)"

///|
extern "js" fn ExrDataView::set_uint32(
  self : ExrDataView,
  offset : Int32,
  value : Double,
  little_endian : Bool,
) -> Unit = "(v, o, x, l) => v.setUint32(o, x, l)"

///|
extern "js" fn ExrDataView::set_float32(
  self : ExrDataView,
  offset : Int32,
  value : Double,
  little_endian : Bool,
) -> Unit = "(v, o, x, l) => v.setFloat32(o, x, l)"

///|
extern "js" fn exr_array_buffer_byte_length(
  buffer : @core.ArrayBuffer,
) -> Int32 = "(b) => b.byteLength"

///|
/// `buffer.slice( start, end )`.
extern "js" fn exr_array_buffer_slice(
  buffer : @core.ArrayBuffer,
  start : Int32,
  end : Double,
) -> @core.ArrayBuffer = "(b, s, e) => b.slice(s, e)"

///|
/// `array.slice( start, end )` with an end that may exceed the `Int` range.
extern "js" fn exr_typed_slice(
  array : @core.TypedArray,
  start : Int32,
  end : Double,
) -> @core.TypedArray = "(a, s, e) => a.slice(s, e)"

///|
/// `new globalThis[ name ]( length )`, with a length that may be fractional or huge.
extern "js" fn exr_new_typed(
  name : String,
  length : Double,
) -> @core.TypedArray = "(n, l) => new globalThis[n](l)"

///|
/// `new globalThis[ name ]( buffer, byteOffset, length )`.
extern "js" fn exr_typed_view(
  name : String,
  buffer : @core.ArrayBuffer,
  byte_offset : Int32,
  length : Int32,
) -> @core.TypedArray = "(n, b, o, l) => new globalThis[n](b, o, l)"

///|
extern "js" fn exr_typed_of_buffer(
  name : String,
  buffer : @core.ArrayBuffer,
) -> @core.TypedArray = "(n, b) => new globalThis[n](b)"

///|
/// `array.fill( value )` with `start`/`end`.
extern "js" fn exr_typed_fill(
  array : @core.TypedArray,
  value : Double,
  start : Int32,
  end : Int32,
) -> Unit = "(a, v, s, e) => { a.fill(v, s, e); }"

///|
/// `new TextDecoder().decode( bytes )`.
extern "js" fn exr_text_decode(bytes : @core.TypedArray) -> String = "(b) => new TextDecoder().decode(b)"

///|
extern "js" fn exr_new_uint8_from_buffer(
  buffer : @core.JsValue,
) -> @core.TypedArray = "(b) => new Uint8Array(b)"

///|
extern "js" fn exr_data_view_from_js(buffer : @core.JsValue) -> ExrDataView = "(b) => new DataView(b)"

///|
extern "js" fn exr_throw_error(message : String) -> Unit = "(m) => { throw new Error(m); }"

///|
extern "js" fn exr_throw_type_error(message : String) -> Unit = "(m) => { throw new TypeError(m); }"

///|
extern "js" fn exr_console_warn(message : String) -> Unit = "(m) => console.warn(m)"

///|
extern "js" fn exr_console_error(message : String, value : Int32) -> Unit = "(m, v) => console.error(m, v)"

///|
/// JS `String( number )`, for numbers in error messages.
extern "js" fn exr_number_string(value : Double) -> String = "(v) => String(v)"

///|
extern "js" fn exr_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn exr_math_log(x : Double) -> Double = "Math.log"

///|
extern "js" fn exr_math_log2(x : Double) -> Double = "Math.log2"

///|
extern "js" fn exr_math_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn exr_math_abs(x : Double) -> Double = "Math.abs"

///|
extern "js" fn exr_math_max(x : Double, y : Double) -> Double = "Math.max"

///|
extern "js" fn exr_math_min(x : Double, y : Double) -> Double = "Math.min"

///|
extern "js" fn exr_math_floor(x : Double) -> Double = "Math.floor"

///|
extern "js" fn exr_math_ceil(x : Double) -> Double = "Math.ceil"

///|
extern "js" fn exr_math_trunc(x : Double) -> Double = "Math.trunc"

///|
/// `x | 0`.
extern "js" fn exr_to_int32(x : Double) -> Int32 = "(x) => x | 0"

// --- constants -----------------------------------------------------------------------

///|
const EXR_USHORT_RANGE : Int32 = 1 << 16

///|
const EXR_BITMAP_SIZE : Int32 = EXR_USHORT_RANGE >> 3

///|
const EXR_HUF_ENCBITS : Int32 = 16 // literal (value) bit length

///|
const EXR_HUF_DECBITS : Int32 = 14 // decoding bit size (>= 8)

///|
const EXR_HUF_ENCSIZE : Int32 = (1 << EXR_HUF_ENCBITS) + 1 // encoding table size

///|
const EXR_HUF_DECSIZE : Int32 = 1 << EXR_HUF_DECBITS // decoding table size

///|
const EXR_HUF_DECMASK : Int32 = EXR_HUF_DECSIZE - 1

///|
const EXR_NBITS : Int32 = 16

///|
const EXR_A_OFFSET : Int32 = 1 << (EXR_NBITS - 1)

///|
const EXR_MOD_MASK : Int32 = (1 << EXR_NBITS) - 1

///|
const EXR_SHORT_ZEROCODE_RUN : Int32 = 59

///|
const EXR_LONG_ZEROCODE_RUN : Int32 = 63

///|
const EXR_SHORTEST_LONG_RUN : Int32 = 2 +
  EXR_LONG_ZEROCODE_RUN -
  EXR_SHORT_ZEROCODE_RUN

///|
const EXR_ULONG_SIZE : Int32 = 8

///|
const EXR_FLOAT32_SIZE : Int32 = 4

///|
const EXR_INT32_SIZE : Int32 = 4

///|
const EXR_INT16_SIZE : Int32 = 2

///|
const EXR_INT8_SIZE : Int32 = 1

///|
const EXR_STATIC_HUFFMAN : Int32 = 0

///|
const EXR_DEFLATE : Int32 = 1

///|
const EXR_UNKNOWN : Int32 = 0

///|
const EXR_LOSSY_DCT : Int32 = 1

///|
const EXR_RLE : Int32 = 2

// --- header values ---------------------------------------------------------------------

///|
/// One entry of a `chlist` attribute.
priv struct ExrChannel {
  name : String
  pixel_type : Int32
  p_linear : Int32
  x_sampling : Int32
  y_sampling : Int32
}

///|
priv struct ExrBox2i {
  x_min : Int32
  y_min : Int32
  x_max : Int32
  y_max : Int32
}

///|
/// `tiledesc`; the modes are `undefined` (`None`) for codes outside upstream's lists.
priv struct ExrTiledesc {
  x_size : Double
  y_size : Double
  level_mode : String?
  rounding_mode : String?
}

///|
/// A parsed header attribute value (upstream's `parseValue` results).
priv enum ExrValue {
  Str(String)
  Chlist(Array[ExrChannel])
  Chromaticities(Array[Double])
  Compression(String)
  Box2i(ExrBox2i)
  Envmap(String)
  Tiledesc(ExrTiledesc)
  LineOrder(String)
  Float(Double)
  Numbers(Array[Double])
  Int(Int32)
}

///|
priv struct ExrSpec {
  single_tile : Bool
  long_name : Bool
  deep_format : Bool
  multi_part : Bool
}

///|
/// A part header: the attributes in file order, then upstream's added keys.
priv struct ExrHeader {
  attributes : Map[String, ExrValue]
  mut version : Int32
  mut spec : ExrSpec
  mut chunk_offsets : Array[Double]?
}

///|
extern "js" fn exr_js_object() -> @core.JsValue = "() => ({})"

///|
extern "js" fn exr_js_set(
  o : @core.JsValue,
  k : String,
  v : @core.JsValue,
) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
extern "js" fn exr_js_array(
  values : FixedArray[@core.JsValue],
) -> @core.JsValue = "(a) => Array.from(a)"

///|
extern "js" fn exr_js_bool(value : Bool) -> @core.JsValue = "(b) => b"

///|
fn exr_js_numbers(values : Array[Double]) -> @core.JsValue {
  exr_js_array(FixedArray::from_array(values.map(v => @core.JsValue::of(v))[:]))
}

///|
fn exr_js_mode(value : String?) -> @core.JsValue {
  match value {
    Some(v) => @core.JsValue::of(v)
    None => @core.JsValue::undefined()
  }
}

///|
fn ExrValue::to_js(self : ExrValue) -> @core.JsValue {
  match self {
    Str(s) | Compression(s) | Envmap(s) | LineOrder(s) => @core.JsValue::of(s)
    Chlist(channels) =>
      exr_js_array(
        FixedArray::from_array(
          channels.map(c => {
            let o = exr_js_object()
            exr_js_set(o, "name", @core.JsValue::of(c.name))
            exr_js_set(o, "pixelType", @core.JsValue::of(c.pixel_type))
            exr_js_set(o, "pLinear", @core.JsValue::of(c.p_linear))
            exr_js_set(o, "xSampling", @core.JsValue::of(c.x_sampling))
            exr_js_set(o, "ySampling", @core.JsValue::of(c.y_sampling))
            o
          })[:],
        ),
      )
    Chromaticities(v) => {
      let o = exr_js_object()
      let keys = [
        "redX", "redY", "greenX", "greenY", "blueX", "blueY", "whiteX", "whiteY",
      ]
      for i, k in keys {
        exr_js_set(o, k, @core.JsValue::of(v[i]))
      }
      o
    }
    Box2i(b) => {
      let o = exr_js_object()
      exr_js_set(o, "xMin", @core.JsValue::of(b.x_min))
      exr_js_set(o, "yMin", @core.JsValue::of(b.y_min))
      exr_js_set(o, "xMax", @core.JsValue::of(b.x_max))
      exr_js_set(o, "yMax", @core.JsValue::of(b.y_max))
      o
    }
    Tiledesc(t) => {
      let o = exr_js_object()
      exr_js_set(o, "xSize", @core.JsValue::of(t.x_size))
      exr_js_set(o, "ySize", @core.JsValue::of(t.y_size))
      exr_js_set(o, "levelMode", exr_js_mode(t.level_mode))
      exr_js_set(o, "roundingMode", exr_js_mode(t.rounding_mode))
      o
    }
    Float(f) => @core.JsValue::of(f)
    Numbers(v) => exr_js_numbers(v)
    Int(i) => @core.JsValue::of(i)
  }
}

///|
/// The header as upstream's object (`texData.header`).
fn ExrHeader::to_js(self : ExrHeader) -> @core.JsValue {
  let o = exr_js_object()
  for k, v in self.attributes {
    exr_js_set(o, k, v.to_js())
  }
  exr_js_set(o, "version", @core.JsValue::of(self.version))
  let spec = exr_js_object()
  exr_js_set(spec, "singleTile", exr_js_bool(self.spec.single_tile))
  exr_js_set(spec, "longName", exr_js_bool(self.spec.long_name))
  exr_js_set(spec, "deepFormat", exr_js_bool(self.spec.deep_format))
  exr_js_set(spec, "multiPart", exr_js_bool(self.spec.multi_part))
  exr_js_set(o, "spec", spec)
  if self.chunk_offsets is Some(offsets) {
    exr_js_set(o, "_chunkOffsets", exr_js_numbers(offsets))
  }
  o
}

///|
fn ExrHeader::channels(self : ExrHeader) -> Array[ExrChannel] {
  match self.attributes.get("channels") {
    Some(Chlist(channels)) => channels
    _ => {
      exr_throw_type_error("EXRHeader.channels is not iterable")
      panic()
    }
  }
}

///|
/// `EXRHeader.compression` as JS would print it.
fn ExrHeader::compression(self : ExrHeader) -> String {
  match self.attributes.get("compression") {
    Some(Compression(c)) => c
    Some(v) => exr_js_string_of(v.to_js())
    None => "undefined"
  }
}

///|
extern "js" fn exr_js_string_of(value : @core.JsValue) -> String = "(v) => String(v)"

///|
fn ExrHeader::data_window(self : ExrHeader) -> ExrBox2i {
  match self.attributes.get("dataWindow") {
    Some(Box2i(b)) => b
    _ => {
      exr_throw_type_error(
        "Cannot read properties of undefined (reading 'xMax')",
      )
      panic()
    }
  }
}

///|
fn ExrHeader::tiles(self : ExrHeader) -> ExrTiledesc {
  match self.attributes.get("tiles") {
    Some(Tiledesc(t)) => t
    _ => {
      exr_throw_type_error(
        "Cannot read properties of undefined (reading 'ySize')",
      )
      panic()
    }
  }
}

///|
/// `EXRHeader.chunkCount`, used as a loop bound (`undefined` runs no iteration).
fn ExrHeader::chunk_count(self : ExrHeader) -> Double {
  match self.attributes.get("chunkCount") {
    Some(Int(n)) => n.to_double()
    Some(Float(n)) => n
    _ => 0.0
  }
}

// --- per-parse state -----------------------------------------------------------------------

///|
/// A Huffman decoding table entry (`{ len, lit, p }`).
priv struct ExrHufDec {
  mut len : Int32
  mut lit : Int32
  mut p : Array[Int32]?
}

///|
/// The `const`s and `let`s inside upstream's `parse`.
priv struct ExrParse {
  mut get_bits_l : Int32
  mut get_bits_c : Int32
  mut get_bits_lc : Int32
  huf_table_buffer : Array[Int32]
  mut get_char_c : Int32
  mut get_char_lc : Int32
  mut get_code_c : Int32
  mut get_code_lc : Int32
  mut wdec14_a : Int32
  mut wdec14_b : Int32
  mut b44_log_table : @core.TypedArray? // lazily initialized for pLinear B44 channels
  mut dwa_to_linear_table : @core.TypedArray? // lazily initialized for DWA lossy DCT channels
  f32 : @core.TypedArray
  u32 : @core.TypedArray
  log_base : Double
  /// The selected part header (`EXRHeader`), set once the headers are parsed.
  mut header : ExrHeader?
}

///|
fn ExrParse::new() -> ExrParse {
  let f32 = @core.TypedArray::float32(1)
  {
    get_bits_l: 0,
    get_bits_c: 0,
    get_bits_lc: 0,
    huf_table_buffer: Array::make(59, 0),
    get_char_c: 0,
    get_char_lc: 0,
    get_code_c: 0,
    get_code_lc: 0,
    wdec14_a: 0,
    wdec14_b: 0,
    b44_log_table: None,
    dwa_to_linear_table: None,
    f32,
    u32: exr_typed_of_buffer("Uint32Array", f32.buffer()),
    log_base: exr_math_pow(2.7182818, 2.2),
    header: None,
  }
}

///|
fn ExrParse::exr_header(self : ExrParse) -> ExrHeader {
  self.header.unwrap()
}

// --- Huffman ------------------------------------------------------------------------------

///|
fn exr_reverse_lut_from_bitmap(
  bitmap : @core.TypedArray,
  lut : @core.TypedArray,
) -> Int32 {
  let mut k = 0
  for i in 0..<EXR_USHORT_RANGE {
    if i == 0 || (bitmap.get_int(i >> 3) & (1 << (i & 7))) != 0 {
      lut[k] = i.to_double()
      k += 1
    }
  }
  let n = k - 1
  while k < EXR_USHORT_RANGE {
    lut[k] = 0
    k += 1
  }
  n
}

///|
fn exr_huf_clear_dec_table(hdec : Array[ExrHufDec]) -> Unit {
  for i in 0..<EXR_HUF_DECSIZE {
    hdec[i] = { len: 0, lit: 0, p: None, }
  }
}

///|
fn ExrParse::get_bits(
  self : ExrParse,
  n_bits : Int32,
  c : Int32,
  lc : Int32,
  u_int8_array : @core.TypedArray,
  in_offset : Ref[Int32],
) -> Unit {
  let mut c = c
  let mut lc = lc
  while lc < n_bits {
    c = (c << 8) | exr_parse_uint8_array(u_int8_array, in_offset)
    lc += 8
  }
  lc -= n_bits
  self.get_bits_l = (c >> lc) & ((1 << n_bits) - 1)
  self.get_bits_c = c
  self.get_bits_lc = lc
}

///|
fn ExrParse::huf_canonical_code_table(
  self : ExrParse,
  hcode : Array[Int32],
) -> Unit {
  let buffer = self.huf_table_buffer
  for i in 0..<=58 {
    buffer[i] = 0
  }
  for i in 0..<EXR_HUF_ENCSIZE {
    let l = hcode[i]
    // upstream's holes (`undefined`) are 0 here; that index is never read back
    if l < 59 {
      buffer[l] += 1
    }
  }
  let mut c = 0
  for i = 58; i > 0; i = i - 1 {
    let nc = (c + buffer[i]) >> 1
    buffer[i] = c
    c = nc
  }
  for i in 0..<EXR_HUF_ENCSIZE {
    let l = hcode[i]
    if l > 0 {
      hcode[i] = l | (buffer[l] << 6)
      buffer[l] += 1
    }
  }
}

///|
fn ExrParse::huf_unpack_enc_table(
  self : ExrParse,
  u_int8_array : @core.TypedArray,
  in_offset : Ref[Int32],
  ni : Double,
  im : Int32,
  i_m : Int32,
  hcode : Array[Int32],
) -> Bool {
  let p = in_offset
  let mut c = 0
  let mut lc = 0
  let mut im = im
  while im <= i_m {
    if (p.val - in_offset.val).to_double() > ni {
      return false
    }
    self.get_bits(6, c, lc, u_int8_array, p)
    let l = self.get_bits_l
    c = self.get_bits_c
    lc = self.get_bits_lc
    hcode[im] = l
    if l == EXR_LONG_ZEROCODE_RUN {
      if (p.val - in_offset.val).to_double() > ni {
        exr_throw_error(
          "THREE.EXRLoader: Something wrong with hufUnpackEncTable",
        )
      }
      self.get_bits(8, c, lc, u_int8_array, p)
      let mut zerun = self.get_bits_l + EXR_SHORTEST_LONG_RUN
      c = self.get_bits_c
      lc = self.get_bits_lc
      if im + zerun > i_m + 1 {
        exr_throw_error(
          "THREE.EXRLoader: Something wrong with hufUnpackEncTable",
        )
      }
      while zerun != 0 {
        zerun -= 1
        hcode[im] = 0
        im += 1
      }
      im -= 1
    } else if l >= EXR_SHORT_ZEROCODE_RUN {
      let mut zerun = l - EXR_SHORT_ZEROCODE_RUN + 2
      if im + zerun > i_m + 1 {
        exr_throw_error(
          "THREE.EXRLoader: Something wrong with hufUnpackEncTable",
        )
      }
      while zerun != 0 {
        zerun -= 1
        hcode[im] = 0
        im += 1
      }
      im -= 1
    }
    im += 1
  }
  self.huf_canonical_code_table(hcode)
  true
}

///|
fn exr_huf_length(code : Int32) -> Int32 {
  code & 63
}

///|
fn exr_huf_code(code : Int32) -> Int32 {
  code >> 6
}

///|
fn exr_huf_build_dec_table(
  hcode : Array[Int32],
  im : Int32,
  i_m : Int32,
  hdecod : Array[ExrHufDec],
) -> Bool {
  for im = im; im <= i_m; im = im + 1 {
    let c = exr_huf_code(hcode[im])
    let l = exr_huf_length(hcode[im])
    if c >> l != 0 {
      exr_throw_error("THREE.EXRLoader: Invalid table entry")
    }
    if l > EXR_HUF_DECBITS {
      let pl = hdecod[c >> (l - EXR_HUF_DECBITS)]
      if pl.len != 0 {
        exr_throw_error("THREE.EXRLoader: Invalid table entry")
      }
      pl.lit += 1
      match pl.p {
        Some(p) => {
          let np = Array::make(pl.lit, 0)
          for i in 0..<(pl.lit - 1) {
            np[i] = p[i]
          }
          pl.p = Some(np)
        }
        None => pl.p = Some(Array::make(1, 0))
      }
      pl.p.unwrap()[pl.lit - 1] = im
    } else if l != 0 {
      let mut pl_offset = 0
      for i = 1 << (EXR_HUF_DECBITS - l); i > 0; i = i - 1 {
        let pl = hdecod[(c << (EXR_HUF_DECBITS - l)) + pl_offset]
        if pl.len != 0 || pl.p is Some(_) {
          exr_throw_error("THREE.EXRLoader: Invalid table entry")
        }
        pl.len = l
        pl.lit = im
        pl_offset += 1
      }
    }
  }
  true
}

///|
fn ExrParse::get_char(
  self : ExrParse,
  c : Int32,
  lc : Int32,
  u_int8_array : @core.TypedArray,
  in_offset : Ref[Int32],
) -> Unit {
  let c = (c << 8) | exr_parse_uint8_array(u_int8_array, in_offset)
  let lc = lc + 8
  self.get_char_c = c
  self.get_char_lc = lc
}

///|
/// Upstream `getCode`: on a `false` return it leaves `getCodeReturn` as it was, and
/// callers read it anyway.
fn ExrParse::get_code(
  self : ExrParse,
  po : Int32,
  rlc : Int32,
  c : Int32,
  lc : Int32,
  u_int8_array : @core.TypedArray,
  in_offset : Ref[Int32],
  out_buffer : @core.TypedArray,
  out_buffer_offset : Ref[Int32],
  out_buffer_end_offset : Double,
) -> Bool {
  let mut c = c
  let mut lc = lc
  if po == rlc {
    if lc < 8 {
      self.get_char(c, lc, u_int8_array, in_offset)
      c = self.get_char_c
      lc = self.get_char_lc
    }
    lc -= 8
    let mut cs = c >> lc
    cs = cs & 0xff // new Uint8Array( [ cs ] )[ 0 ]
    if (out_buffer_offset.val + cs).to_double() > out_buffer_end_offset {
      return false
    }
    let s = out_buffer[out_buffer_offset.val - 1]
    while cs > 0 {
      cs -= 1
      out_buffer[out_buffer_offset.val] = s
      out_buffer_offset.val += 1
    }
  } else if out_buffer_offset.val.to_double() < out_buffer_end_offset {
    out_buffer[out_buffer_offset.val] = po.to_double()
    out_buffer_offset.val += 1
  } else {
    return false
  }
  self.get_code_c = c
  self.get_code_lc = lc
  true
}

///|
fn exr_uint16(value : Int32) -> Int32 {
  value & 0xFFFF
}

///|
fn exr_int16(value : Int32) -> Int32 {
  let ref_ = exr_uint16(value)
  if ref_ > 0x7FFF {
    ref_ - 0x10000
  } else {
    ref_
  }
}

///|
fn ExrParse::wdec14(self : ExrParse, l : Int32, h : Int32) -> Unit {
  let ls = exr_int16(l)
  let hs = exr_int16(h)
  let hi = hs
  let ai = ls + (hi & 1) + (hi >> 1)
  let as_ = ai
  let bs = ai - hi
  self.wdec14_a = as_
  self.wdec14_b = bs
}

///|
fn ExrParse::wdec16(self : ExrParse, l : Int32, h : Int32) -> Unit {
  let m = exr_uint16(l)
  let d = exr_uint16(h)
  let bb = (m - (d >> 1)) & EXR_MOD_MASK
  let aa = (d + bb - EXR_A_OFFSET) & EXR_MOD_MASK
  self.wdec14_a = aa
  self.wdec14_b = bb
}

///|
fn ExrParse::wav2_decode(
  self : ExrParse,
  buffer : @core.TypedArray,
  j : Int32,
  nx : Int32,
  ox : Int32,
  ny : Int32,
  oy : Int32,
  mx : Int32,
) -> Int32 {
  let w14 = mx < 1 << 14
  let n = if nx > ny { ny } else { nx }
  let mut p = 1
  let mut p2 = 0
  let mut py = 0
  while p <= n {
    p = p << 1
  }
  p = p >> 1
  p2 = p
  p = p >> 1
  while p >= 1 {
    py = 0
    let ey = py + oy * (ny - p2)
    let oy1 = oy * p
    let oy2 = oy * p2
    let ox1 = ox * p
    let ox2 = ox * p2
    let mut i00 = 0
    let mut i01 = 0
    let mut i10 = 0
    let mut i11 = 0
    while py <= ey {
      let mut px = py
      let ex = py + ox * (nx - p2)
      while px <= ex {
        let p01 = px + ox1
        let p10 = px + oy1
        let p11 = p10 + ox1
        if w14 {
          self.wdec14(buffer.get_int(px + j), buffer.get_int(p10 + j))
          i00 = self.wdec14_a
          i10 = self.wdec14_b
          self.wdec14(buffer.get_int(p01 + j), buffer.get_int(p11 + j))
          i01 = self.wdec14_a
          i11 = self.wdec14_b
          self.wdec14(i00, i01)
          buffer[px + j] = self.wdec14_a.to_double()
          buffer[p01 + j] = self.wdec14_b.to_double()
          self.wdec14(i10, i11)
          buffer[p10 + j] = self.wdec14_a.to_double()
          buffer[p11 + j] = self.wdec14_b.to_double()
        } else {
          self.wdec16(buffer.get_int(px + j), buffer.get_int(p10 + j))
          i00 = self.wdec14_a
          i10 = self.wdec14_b
          self.wdec16(buffer.get_int(p01 + j), buffer.get_int(p11 + j))
          i01 = self.wdec14_a
          i11 = self.wdec14_b
          self.wdec16(i00, i01)
          buffer[px + j] = self.wdec14_a.to_double()
          buffer[p01 + j] = self.wdec14_b.to_double()
          self.wdec16(i10, i11)
          buffer[p10 + j] = self.wdec14_a.to_double()
          buffer[p11 + j] = self.wdec14_b.to_double()
        }
        px += ox2
      }
      if (nx & p) != 0 {
        let p10 = px + oy1
        if w14 {
          self.wdec14(buffer.get_int(px + j), buffer.get_int(p10 + j))
        } else {
          self.wdec16(buffer.get_int(px + j), buffer.get_int(p10 + j))
        }
        i00 = self.wdec14_a
        buffer[p10 + j] = self.wdec14_b.to_double()
        buffer[px + j] = i00.to_double()
      }
      py += oy2
    }
    if (ny & p) != 0 {
      let mut px = py
      let ex = py + ox * (nx - p2)
      while px <= ex {
        let p01 = px + ox1
        if w14 {
          self.wdec14(buffer.get_int(px + j), buffer.get_int(p01 + j))
        } else {
          self.wdec16(buffer.get_int(px + j), buffer.get_int(p01 + j))
        }
        i00 = self.wdec14_a
        buffer[p01 + j] = self.wdec14_b.to_double()
        buffer[px + j] = i00.to_double()
        px += ox2
      }
    }
    p2 = p
    p = p >> 1
  }
  py
}

///|
fn ExrParse::huf_decode(
  self : ExrParse,
  encoding_table : Array[Int32],
  decoding_table : Array[ExrHufDec],
  u_int8_array : @core.TypedArray,
  in_offset : Ref[Int32],
  ni : Double,
  rlc : Int32,
  no : Double,
  out_buffer : @core.TypedArray,
  out_offset : Ref[Int32],
) -> Bool {
  let mut c = 0
  let mut lc = 0
  let out_buffer_end_offset = no
  let in_offset_end = exr_math_trunc(
    in_offset.val.to_double() + (ni + 7.0) / 8.0,
  )
  while in_offset.val.to_double() < in_offset_end {
    self.get_char(c, lc, u_int8_array, in_offset)
    c = self.get_char_c
    lc = self.get_char_lc
    while lc >= EXR_HUF_DECBITS {
      let index = (c >> (lc - EXR_HUF_DECBITS)) & EXR_HUF_DECMASK
      let pl = decoding_table[index]
      if pl.len != 0 {
        lc -= pl.len
        ignore(
          self.get_code(
            pl.lit,
            rlc,
            c,
            lc,
            u_int8_array,
            in_offset,
            out_buffer,
            out_offset,
            out_buffer_end_offset,
          ),
        )
        c = self.get_code_c
        lc = self.get_code_lc
      } else {
        guard pl.p is Some(plp) else {
          exr_throw_error("THREE.EXRLoader: hufDecode issues")
          panic()
        }
        let mut j = 0
        while j < pl.lit {
          let l = exr_huf_length(encoding_table[plp[j]])
          while lc < l && in_offset.val.to_double() < in_offset_end {
            self.get_char(c, lc, u_int8_array, in_offset)
            c = self.get_char_c
            lc = self.get_char_lc
          }
          if lc >= l {
            if exr_huf_code(encoding_table[plp[j]]) ==
              ((c >> (lc - l)) & ((1 << l) - 1)) {
              lc -= l
              ignore(
                self.get_code(
                  plp[j],
                  rlc,
                  c,
                  lc,
                  u_int8_array,
                  in_offset,
                  out_buffer,
                  out_offset,
                  out_buffer_end_offset,
                ),
              )
              c = self.get_code_c
              lc = self.get_code_lc
              break
            }
          }
          j += 1
        }
        if j == pl.lit {
          exr_throw_error("THREE.EXRLoader: hufDecode issues")
        }
      }
    }
  }
  let i = (8 - exr_to_int32(ni)) & 7
  c = c >> i
  lc -= i
  while lc > 0 {
    let pl = decoding_table[(c << (EXR_HUF_DECBITS - lc)) & EXR_HUF_DECMASK]
    if pl.len != 0 {
      lc -= pl.len
      ignore(
        self.get_code(
          pl.lit,
          rlc,
          c,
          lc,
          u_int8_array,
          in_offset,
          out_buffer,
          out_offset,
          out_buffer_end_offset,
        ),
      )
      c = self.get_code_c
      lc = self.get_code_lc
    } else {
      exr_throw_error("THREE.EXRLoader: hufDecode issues")
    }
  }
  true
}

///|
fn ExrParse::huf_uncompress(
  self : ExrParse,
  u_int8_array : @core.TypedArray,
  in_data_view : ExrDataView,
  in_offset : Ref[Int32],
  n_compressed : Double,
  out_buffer : @core.TypedArray,
  n_raw : Double,
) -> Unit {
  let out_offset = Ref(0)
  let initial_in_offset = in_offset.val
  let im = exr_parse_uint32(in_data_view, in_offset)
  let i_m = exr_parse_uint32(in_data_view, in_offset)
  in_offset.val += 4
  let n_bits = exr_parse_uint32(in_data_view, in_offset)
  in_offset.val += 4
  if im < 0.0 ||
    im >= EXR_HUF_ENCSIZE.to_double() ||
    i_m < 0.0 ||
    i_m >= EXR_HUF_ENCSIZE.to_double() {
    exr_throw_error("THREE.EXRLoader: Something wrong with HUF_ENCSIZE")
  }
  let im = im.to_int()
  let i_m = i_m.to_int()
  let freq = Array::make(EXR_HUF_ENCSIZE, 0)
  let hdec : Array[ExrHufDec] = Array::makei(EXR_HUF_DECSIZE, _ => {
    len: 0,
    lit: 0,
    p: None,
  })
  exr_huf_clear_dec_table(hdec)
  let ni = n_compressed - (in_offset.val - initial_in_offset).to_double()
  ignore(self.huf_unpack_enc_table(u_int8_array, in_offset, ni, im, i_m, freq))
  if n_bits >
    8.0 * (n_compressed - (in_offset.val - initial_in_offset).to_double()) {
    exr_throw_error("THREE.EXRLoader: Something wrong with hufUncompress")
  }
  ignore(exr_huf_build_dec_table(freq, im, i_m, hdec))
  ignore(
    self.huf_decode(
      freq, hdec, u_int8_array, in_offset, n_bits, i_m, n_raw, out_buffer, out_offset,
    ),
  )
}

///|
fn exr_apply_lut(
  lut : @core.TypedArray,
  data : @core.TypedArray,
  n_data : Int32,
) -> Unit {
  for i in 0..<n_data {
    data[i] = lut[data.get_int(i)]
  }
}

///|
fn exr_predictor(source : @core.TypedArray) -> Unit {
  for t in 1..<source.length() {
    let d = source.get_int(t - 1) + source.get_int(t) - 128
    source[t] = d.to_double()
  }
}

///|
fn exr_interleave_scalar(
  source : @core.TypedArray,
  out : @core.TypedArray,
) -> Unit {
  let mut t1 = 0
  let mut t2 = (source.length() + 1) / 2
  let mut s = 0
  let stop = source.length() - 1
  while true {
    if s > stop {
      break
    }
    out[s] = source[t1]
    s += 1
    t1 += 1
    if s > stop {
      break
    }
    out[s] = source[t2]
    s += 1
    t2 += 1
  }
}

///|
fn exr_decode_run_length(source : @core.ArrayBuffer) -> Array[Int32] {
  let mut size = exr_array_buffer_byte_length(source)
  let out = []
  let mut p = 0
  let reader = ExrDataView::of_buffer(source)
  while size > 0 {
    let l = reader.get_int8(p)
    p += 1
    if l < 0 {
      let count = -l
      size -= count + 1
      for i in 0..<count {
        ignore(i)
        out.push(reader.get_uint8(p))
        p += 1
      }
    } else {
      let count = l
      size -= 2
      let value = reader.get_uint8(p)
      p += 1
      for i in 0..<(count + 1) {
        ignore(i)
        out.push(value)
      }
    }
  }
  out
}

// --- DWA ------------------------------------------------------------------------------------

///|
/// A DWA channel record (`channelData[ i ]`).
priv struct ExrDwaChannel {
  name : String
  mut compression : Int32
  mut decoded : Bool
  type_ : Int32
  p_linear : Int32
  width : Int32
  height : Int32
  mut offset : Int32
}

///|
fn ExrParse::lossy_dct_decode(
  self : ExrParse,
  csc_set : Array[Int32?],
  row_ptrs : Array[Array[Int32]],
  channel_data : Array[ExrDwaChannel],
  ac_buffer : @core.TypedArray?,
  dc_buffer : @core.TypedArray?,
  out_buffer : @core.TypedArray,
) -> Unit {
  let mut data_view = ExrDataView::of_buffer(out_buffer.buffer())
  fn idx(comp : Int32) -> Int32 {
    match csc_set[comp] {
      Some(i) if i < channel_data.length() => i
      _ => {
        exr_throw_type_error(
          "Cannot read properties of undefined (reading 'type')",
        )
        panic()
      }
    }
  }

  let width = channel_data[idx(0)].width
  let height = channel_data[idx(0)].height
  let num_comp = 3
  let num_full_blocks_x = exr_math_floor(width.to_double() / 8.0).to_int()
  let num_blocks_x = exr_math_ceil(width.to_double() / 8.0).to_int()
  let num_blocks_y = exr_math_ceil(height.to_double() / 8.0).to_int()
  let leftover_x = width - (num_blocks_x - 1) * 8
  let leftover_y = height - (num_blocks_y - 1) * 8
  let curr_ac_comp = Ref(0)
  let curr_dc_comp = Array::make(num_comp, 0)
  let dct_data : Array[@core.TypedArray] = []
  let half_zig_block : Array[@core.TypedArray] = []
  let row_block : Array[@core.TypedArray] = []
  let row_offsets : Array[Array[Int32]] = []
  for comp in 0..<num_comp {
    row_offsets.push(row_ptrs[idx(comp)])
    curr_dc_comp[comp] = if comp < 1 {
      0
    } else {
      curr_dc_comp[comp - 1] + num_blocks_x * num_blocks_y
    }
    dct_data.push(@core.TypedArray::float32(64))
    half_zig_block.push(@core.TypedArray::uint16(64))
    row_block.push(@core.TypedArray::uint16(num_blocks_x * 64))
  }
  let ac_buffer = exr_or_undefined_array(ac_buffer)
  let dc_buffer = exr_or_undefined_array(dc_buffer)
  for blocky in 0..<num_blocks_y {
    let mut max_y = 8
    if blocky == num_blocks_y - 1 {
      max_y = leftover_y
    }
    let mut max_x = 8
    for blockx in 0..<num_blocks_x {
      if blockx == num_blocks_x - 1 {
        max_x = leftover_x
      }
      for comp in 0..<num_comp {
        half_zig_block[comp].fill(0)
        // set block DC component
        half_zig_block[comp][0] = dc_buffer[curr_dc_comp[comp]]
        curr_dc_comp[comp] += 1
        // set block AC components
        exr_un_rle_ac(curr_ac_comp, ac_buffer, half_zig_block[comp])
        // UnZigZag block to float
        exr_un_zig_zag(half_zig_block[comp], dct_data[comp])
        // decode float dct
        exr_dct_inverse(dct_data[comp])
      }
      if num_comp == 3 {
        exr_csc709_inverse(dct_data)
      }
      for comp in 0..<num_comp {
        self.convert_to_half(dct_data[comp], row_block[comp], blockx * 64)
      }
    } // blockx
    let mut offset = 0
    for comp in 0..<num_comp {
      let type_ = channel_data[idx(comp)].type_
      for y = 8 * blocky; y < 8 * blocky + max_y; y = y + 1 {
        offset = row_offsets[comp][y]
        for blockx in 0..<num_full_blocks_x {
          let src = blockx * 64 + (y & 0x7) * 8
          for x in 0..<8 {
            data_view.set_uint16(
              offset + x * EXR_INT16_SIZE * type_,
              row_block[comp][src + x],
              true,
            )
          }
          offset += 8 * EXR_INT16_SIZE * type_
        }
      }
      // handle partial X blocks
      if num_full_blocks_x != num_blocks_x {
        for y = 8 * blocky; y < 8 * blocky + max_y; y = y + 1 {
          let offset = row_offsets[comp][y] +
            8 * num_full_blocks_x * EXR_INT16_SIZE * type_
          let src = num_full_blocks_x * 64 + (y & 0x7) * 8
          for x in 0..<max_x {
            data_view.set_uint16(
              offset + x * EXR_INT16_SIZE * type_,
              row_block[comp][src + x],
              true,
            )
          }
        }
      }
    } // comp
  } // blocky
  let half_row = @core.TypedArray::uint16(width)
  data_view = ExrDataView::of_buffer(out_buffer.buffer())
  // convert channels back to float, if needed
  for comp in 0..<num_comp {
    channel_data[idx(comp)].decoded = true
    let type_ = channel_data[idx(comp)].type_
    if channel_data[comp].type_ != 2 {
      continue
    }
    for y in 0..<height {
      let offset = row_offsets[comp][y]
      for x in 0..<width {
        half_row[x] = data_view
          .get_uint16(offset + x * EXR_INT16_SIZE * type_, true)
          .to_double()
      }
      for x in 0..<width {
        data_view.set_float32(
          offset + x * EXR_INT16_SIZE * type_,
          @core.from_half_float(half_row[x]),
          true,
        )
      }
    }
  }
}

///|
/// Stands in for an `undefined` buffer: every read is `undefined`.
fn exr_or_undefined_array(array : @core.TypedArray?) -> @core.TypedArray {
  match array {
    Some(a) => a
    None => {
      exr_throw_type_error("Cannot read properties of undefined (reading '0')")
      panic()
    }
  }
}

///|
fn ExrParse::lossy_dct_channel_decode(
  self : ExrParse,
  channel_index : Int32,
  row_ptrs : Array[Array[Int32]],
  channel_data : Array[ExrDwaChannel],
  ac_buffer : @core.TypedArray?,
  dc_buffer : @core.TypedArray?,
  out_buffer : @core.TypedArray,
) -> Unit {
  let data_view = ExrDataView::of_buffer(out_buffer.buffer())
  let cd = channel_data[channel_index]
  let width = cd.width
  let height = cd.height
  let num_blocks_x = exr_math_ceil(width.to_double() / 8.0).to_int()
  let num_blocks_y = exr_math_ceil(height.to_double() / 8.0).to_int()
  let num_full_blocks_x = exr_math_floor(width.to_double() / 8.0).to_int()
  let leftover_x = width - (num_blocks_x - 1) * 8
  let leftover_y = height - (num_blocks_y - 1) * 8
  let curr_ac_comp = Ref(0)
  let mut curr_dc_comp = 0
  let dct_data = @core.TypedArray::float32(64)
  let half_zig_block = @core.TypedArray::uint16(64)
  let row_block = @core.TypedArray::uint16(num_blocks_x * 64)
  for blocky in 0..<num_blocks_y {
    let mut max_y = 8
    if blocky == num_blocks_y - 1 {
      max_y = leftover_y
    }
    for blockx in 0..<num_blocks_x {
      half_zig_block.fill(0)
      half_zig_block[0] = exr_or_undefined_array(dc_buffer)[curr_dc_comp]
      curr_dc_comp += 1
      exr_un_rle_ac(
        curr_ac_comp,
        exr_or_undefined_array(ac_buffer),
        half_zig_block,
      )
      exr_un_zig_zag(half_zig_block, dct_data)
      exr_dct_inverse(dct_data)
      self.convert_to_half(dct_data, row_block, blockx * 64)
    }
    // Write decoded data to output buffer
    for y = 8 * blocky; y < 8 * blocky + max_y; y = y + 1 {
      let mut offset = row_ptrs[channel_index][y]
      for blockx in 0..<num_full_blocks_x {
        let src = blockx * 64 + (y & 0x7) * 8
        for x in 0..<8 {
          data_view.set_uint16(
            offset + x * EXR_INT16_SIZE * cd.type_,
            row_block[src + x],
            true,
          )
        }
        offset += 8 * EXR_INT16_SIZE * cd.type_
      }
      if num_blocks_x != num_full_blocks_x {
        let src = num_full_blocks_x * 64 + (y & 0x7) * 8
        for x in 0..<leftover_x {
          data_view.set_uint16(
            offset + x * EXR_INT16_SIZE * cd.type_,
            row_block[src + x],
            true,
          )
        }
      }
    }
  }
  cd.decoded = true
}

///|
fn exr_un_rle_ac(
  curr_ac_comp : Ref[Int32],
  ac_buffer : @core.TypedArray,
  half_zig_block : @core.TypedArray,
) -> Unit {
  let mut dct_comp = 1
  while dct_comp < 64 {
    let ac_value = ac_buffer.get_int(curr_ac_comp.val)
    if ac_value == 0xff00 {
      dct_comp = 64
    } else if ac_value >> 8 == 0xff {
      dct_comp += ac_value & 0xff
    } else {
      half_zig_block[dct_comp] = ac_value.to_double()
      dct_comp += 1
    }
    curr_ac_comp.val += 1
  }
}

///|
/// The zig-zag order: `dst[ i ] = fromHalfFloat( src[ EXR_ZIG_ZAG[ i ] ] )`.
let exr_zig_zag : Array[Int32] = [
  0, 1, 5, 6, 14, 15, 27, 28, 2, 4, 7, 13, 16, 26, 29, 42, 3, 8, 12, 17, 25, 30,
  41, 43, 9, 11, 18, 24, 31, 40, 44, 53, 10, 19, 23, 32, 39, 45, 52, 54, 20, 22,
  33, 38, 46, 51, 55, 60, 21, 34, 37, 47, 50, 56, 59, 61, 35, 36, 48, 49, 57, 58,
  62, 63,
]

///|
fn exr_un_zig_zag(src : @core.TypedArray, dst : @core.TypedArray) -> Unit {
  for i in 0..<64 {
    dst[i] = @core.from_half_float(src[exr_zig_zag[i]])
  }
}

///|
fn exr_dct_inverse(data : @core.TypedArray) -> Unit {
  let a = 0.5 * exr_math_cos(3.14159 / 4.0)
  let b = 0.5 * exr_math_cos(3.14159 / 16.0)
  let c = 0.5 * exr_math_cos(3.14159 / 8.0)
  let d = 0.5 * exr_math_cos(3.0 * 3.14159 / 16.0)
  let e = 0.5 * exr_math_cos(5.0 * 3.14159 / 16.0)
  let f = 0.5 * exr_math_cos(3.0 * 3.14159 / 8.0)
  let g = 0.5 * exr_math_cos(7.0 * 3.14159 / 16.0)
  let alpha = Array::make(4, 0.0)
  let beta = Array::make(4, 0.0)
  let theta = Array::make(4, 0.0)
  let gamma = Array::make(4, 0.0)
  for row in 0..<8 {
    let row_ptr = row * 8
    alpha[0] = c * data[row_ptr + 2]
    alpha[1] = f * data[row_ptr + 2]
    alpha[2] = c * data[row_ptr + 6]
    alpha[3] = f * data[row_ptr + 6]
    beta[0] = b * data[row_ptr + 1] +
      d * data[row_ptr + 3] +
      e * data[row_ptr + 5] +
      g * data[row_ptr + 7]
    beta[1] = d * data[row_ptr + 1] -
      g * data[row_ptr + 3] -
      b * data[row_ptr + 5] -
      e * data[row_ptr + 7]
    beta[2] = e * data[row_ptr + 1] -
      b * data[row_ptr + 3] +
      g * data[row_ptr + 5] +
      d * data[row_ptr + 7]
    beta[3] = g * data[row_ptr + 1] -
      e * data[row_ptr + 3] +
      d * data[row_ptr + 5] -
      b * data[row_ptr + 7]
    theta[0] = a * (data[row_ptr + 0] + data[row_ptr + 4])
    theta[3] = a * (data[row_ptr + 0] - data[row_ptr + 4])
    theta[1] = alpha[0] + alpha[3]
    theta[2] = alpha[1] - alpha[2]
    gamma[0] = theta[0] + theta[1]
    gamma[1] = theta[3] + theta[2]
    gamma[2] = theta[3] - theta[2]
    gamma[3] = theta[0] - theta[1]
    data[row_ptr + 0] = gamma[0] + beta[0]
    data[row_ptr + 1] = gamma[1] + beta[1]
    data[row_ptr + 2] = gamma[2] + beta[2]
    data[row_ptr + 3] = gamma[3] + beta[3]
    data[row_ptr + 4] = gamma[3] - beta[3]
    data[row_ptr + 5] = gamma[2] - beta[2]
    data[row_ptr + 6] = gamma[1] - beta[1]
    data[row_ptr + 7] = gamma[0] - beta[0]
  }
  for column in 0..<8 {
    alpha[0] = c * data[16 + column]
    alpha[1] = f * data[16 + column]
    alpha[2] = c * data[48 + column]
    alpha[3] = f * data[48 + column]
    beta[0] = b * data[8 + column] +
      d * data[24 + column] +
      e * data[40 + column] +
      g * data[56 + column]
    beta[1] = d * data[8 + column] -
      g * data[24 + column] -
      b * data[40 + column] -
      e * data[56 + column]
    beta[2] = e * data[8 + column] -
      b * data[24 + column] +
      g * data[40 + column] +
      d * data[56 + column]
    beta[3] = g * data[8 + column] -
      e * data[24 + column] +
      d * data[40 + column] -
      b * data[56 + column]
    theta[0] = a * (data[column] + data[32 + column])
    theta[3] = a * (data[column] - data[32 + column])
    theta[1] = alpha[0] + alpha[3]
    theta[2] = alpha[1] - alpha[2]
    gamma[0] = theta[0] + theta[1]
    gamma[1] = theta[3] + theta[2]
    gamma[2] = theta[3] - theta[2]
    gamma[3] = theta[0] - theta[1]
    data[0 + column] = gamma[0] + beta[0]
    data[8 + column] = gamma[1] + beta[1]
    data[16 + column] = gamma[2] + beta[2]
    data[24 + column] = gamma[3] + beta[3]
    data[32 + column] = gamma[3] - beta[3]
    data[40 + column] = gamma[2] - beta[2]
    data[48 + column] = gamma[1] - beta[1]
    data[56 + column] = gamma[0] - beta[0]
  }
}

///|
fn exr_csc709_inverse(data : Array[@core.TypedArray]) -> Unit {
  for i in 0..<64 {
    let y = data[0][i]
    let cb = data[1][i]
    let cr = data[2][i]
    data[0][i] = y + 1.5747 * cr
    data[1][i] = y - 0.1873 * cb - 0.4682 * cr
    data[2][i] = y + 1.8556 * cb
  }
}

///|
/// float -> half bits with round-to-nearest-even, like Imath's float_to_half
/// (DataUtils.toHalfFloat truncates, which is what put DWA output 1-5 ulp off OpenEXR).
fn ExrParse::float_to_half_bits(self : ExrParse, f : Double) -> Int32 {
  self.f32[0] = f
  let x = self.u32.get_int(0).reinterpret_as_uint()
  let sign = (x >> 16) & 0x8000
  let a = x & 0x7fffffff
  if a >= 0x47800000 {
    // overflow, Inf, NaN
    return (sign | (if a > 0x7f800000 { 0x7e00 } else { 0x7c00 })).reinterpret_as_int()
  }
  if a < 0x38800000 { // subnormal or zero in half
    self.f32[0] = exr_math_abs(f) + 0.5 // 0.5 = 2^-1: forces rounding to a 2^-24 grid
    return (sign | (self.u32.get_int(0).reinterpret_as_uint() - 0x3f000000)).reinterpret_as_int()
  }
  let r = a + 0xfff + ((a >> 13) & 1)
  (sign | ((r - 0x38000000) >> 13)).reinterpret_as_int()
}

///|
fn ExrParse::convert_to_half(
  self : ExrParse,
  src : @core.TypedArray,
  dst : @core.TypedArray,
  idx : Int32,
) -> Unit {
  let table = match self.dwa_to_linear_table {
    Some(table) => table
    None => {
      // Mirrors OpenEXR dwaLookups.cpp: gamma 2.2 below 1, log curve above,
      // applied to the half bits after rounding so results match bit for bit.
      let table = @core.TypedArray::uint16(65536)
      for i in 1..<65536 {
        if (i & 0x7c00) == 0x7c00 {
          continue // NaN / Inf -> 0
        }
        let h = @core.from_half_float(i.to_double())
        let v = exr_math_abs(h)
        let linear = if v <= 1.0 {
          exr_math_pow(v, 2.2)
        } else {
          exr_math_pow(self.log_base, v - 1.0)
        }
        table[i] = self
          .float_to_half_bits(if h < 0.0 { -linear } else { linear })
          .to_double()
      }
      self.dwa_to_linear_table = Some(table)
      table
    }
  }
  for i in 0..<64 {
    dst[idx + i] = table[self.float_to_half_bits(src[i])]
  }
}

// --- decoders --------------------------------------------------------------------------------

///|
/// How the decoder reads its blocks (upstream's bound `decode` function).
priv enum ExrDecodeKind {
  Scanline
  Tiles
  MultiPartScanline
  DeepScanline
}

///|
/// A channel of a deep part.
priv struct ExrDeepChannel {
  name : String
  pixel_type : Int32
  bytes_per_sample : Int32
}

///|
/// Upstream's `EXRDecoder` object; also the `info` of the `uncompress*` functions.
priv struct ExrDecoder {
  mut size : Double
  viewer : ExrDataView
  array : @core.TypedArray
  mut offset : Ref[Int32]
  width : Int32
  height : Int32
  input_channels : Array[ExrChannel]
  channel_byte_offsets : Map[String, Int32]
  mut should_expand : Bool
  mut y_cb_cr : Bool
  mut total_bytes : Int32
  mut columns : Int32
  mut lines : Int32
  mut type_ : Int32
  mut uncompress : (ExrParse, ExrDecoder) -> ExrDataView
  mut getter : ((ExrDataView, Ref[Int32]) -> Double)?
  mut format : Int32
  mut color_space : String
  mut block_height : Int32
  mut block_width : Int32
  mut output_channels : Int32
  mut decode_channels : Map[String, Int32]
  mut byte_array : @core.TypedArray?
  mut out_line_width : Int32
  mut tile_count : Int32
  mut deep_channels : Array[ExrDeepChannel]
  mut deep_bytes_per_sample : Int32
  mut chunk_offsets : Array[Double]
  mut multi_part : Bool
  mut decode : ExrDecodeKind
}

///|
/// `offset.value += n` for a JS number `n`; saturates where upstream's offset would
/// leave the `Int` range (every DataView read then throws, as upstream's would).
fn exr_advance(offset : Ref[Int32], n : Double) -> Unit {
  offset.val = (offset.val.to_double() + n).to_int()
}

///|
fn exr_uncompress_raw(_ : ExrParse, info : ExrDecoder) -> ExrDataView {
  ExrDataView::new(info.array.buffer(), info.offset.val, info.size)
}

///|
fn exr_uncompress_rle(_ : ExrParse, info : ExrDecoder) -> ExrDataView {
  let compressed = exr_array_buffer_slice(
    info.viewer.buffer(),
    info.offset.val,
    info.offset.val.to_double() + info.size,
  )
  let raw_buffer = @core.TypedArray::uint8(exr_decode_run_length(compressed))
  let tmp_buffer = @core.TypedArray::uint8(raw_buffer.length())
  exr_predictor(raw_buffer) // revert predictor
  exr_interleave_scalar(raw_buffer, tmp_buffer) // interleave pixels
  ExrDataView::of_buffer(tmp_buffer.buffer())
}

///|
/// `uncompressZIP( { array, offset, size } )`.
fn exr_uncompress_zip_parts(
  array : @core.TypedArray,
  offset : Int32,
  size : Double,
) -> ExrDataView {
  let compressed = exr_typed_slice(array, offset, offset.to_double() + size)
  let raw_buffer = @libs.unzlib_sync(compressed)
  let tmp_buffer = @core.TypedArray::uint8(raw_buffer.length())
  exr_predictor(raw_buffer) // revert predictor
  exr_interleave_scalar(raw_buffer, tmp_buffer) // interleave pixels
  ExrDataView::of_buffer(tmp_buffer.buffer())
}

///|
fn exr_uncompress_zip(_ : ExrParse, info : ExrDecoder) -> ExrDataView {
  exr_uncompress_zip_parts(info.array, info.offset.val, info.size)
}

///|
/// A PIZ channel record (`pizChannelData[ i ]`).
priv struct ExrPizChannel {
  start : Int32
  mut end : Int32
  nx : Int32
  ny : Int32
  size : Int32
}

///|
fn exr_uncompress_piz(state : ExrParse, info : ExrDecoder) -> ExrDataView {
  let in_data_view = info.viewer
  let in_offset = Ref(info.offset.val)
  let out_buffer = @core.TypedArray::uint16(
    info.columns * info.lines * (info.input_channels.length() * info.type_),
  )
  let bitmap = @core.TypedArray::uint8(EXR_BITMAP_SIZE)
  // Setup channel info
  let mut out_buffer_end = 0
  let piz_channel_data : Array[ExrPizChannel] = []
  for i in 0..<info.input_channels.length() {
    ignore(i)
    let cd = {
      start: out_buffer_end,
      end: out_buffer_end,
      nx: info.columns,
      ny: info.lines,
      size: info.type_,
    }
    piz_channel_data.push(cd)
    out_buffer_end += cd.nx * cd.ny * cd.size
  }
  // Read range compression data
  let min_non_zero = exr_parse_uint16(in_data_view, in_offset)
  let max_non_zero = exr_parse_uint16(in_data_view, in_offset)
  if max_non_zero >= EXR_BITMAP_SIZE {
    exr_throw_error(
      "THREE.EXRLoader: Something is wrong with PIZ_COMPRESSION BITMAP_SIZE",
    )
  }
  if min_non_zero <= max_non_zero {
    for i in 0..<(max_non_zero - min_non_zero + 1) {
      bitmap[i + min_non_zero] = exr_parse_uint8(in_data_view, in_offset).to_double()
    }
  }
  // Reverse LUT
  let lut = @core.TypedArray::uint16(EXR_USHORT_RANGE)
  let max_value = exr_reverse_lut_from_bitmap(bitmap, lut)
  let length = exr_parse_uint32(in_data_view, in_offset)
  // Huffman decoding
  state.huf_uncompress(
    info.array,
    in_data_view,
    in_offset,
    length,
    out_buffer,
    out_buffer_end.to_double(),
  )
  // Wavelet decoding
  for i in 0..<info.input_channels.length() {
    let cd = piz_channel_data[i]
    for j in 0..<piz_channel_data[i].size {
      ignore(
        state.wav2_decode(
          out_buffer,
          cd.start + j,
          cd.nx,
          cd.size,
          cd.ny,
          cd.nx * cd.size,
          max_value,
        ),
      )
    }
  }
  // Expand the pixel data to their original range
  exr_apply_lut(lut, out_buffer, out_buffer_end)
  // Rearrange the pixel data into the format expected by the caller.
  let mut tmp_offset = 0
  let tmp_buffer = @core.TypedArray::uint8(out_buffer.buffer().byte_length())
  for y in 0..<info.lines {
    ignore(y)
    for c in 0..<info.input_channels.length() {
      let cd = piz_channel_data[c]
      let n = cd.nx * cd.size
      let cp = exr_typed_view(
        "Uint8Array",
        out_buffer.buffer(),
        cd.end * EXR_INT16_SIZE,
        n * EXR_INT16_SIZE,
      )
      tmp_buffer.set_from(cp, offset=tmp_offset)
      tmp_offset += n * EXR_INT16_SIZE
      cd.end += n
    }
  }
  ExrDataView::of_buffer(tmp_buffer.buffer())
}

///|
fn exr_uncompress_pxr(_ : ExrParse, info : ExrDecoder) -> ExrDataView {
  let compressed = exr_typed_slice(
    info.array,
    info.offset.val,
    info.offset.val.to_double() + info.size,
  )
  let raw_buffer = @libs.unzlib_sync(compressed)
  let byte_size = info.input_channels.length() *
    info.lines *
    info.columns *
    info.total_bytes
  let tmp_buffer = @core.ArrayBuffer::new(byte_size)
  let viewer = ExrDataView::of_buffer(tmp_buffer)
  let mut tmp_buffer_end = 0
  let mut write_ptr = 0
  let ptr = Array::make(4, 0)
  for y in 0..<info.lines {
    ignore(y)
    for c in 0..<info.input_channels.length() {
      let mut pixel = 0
      let type_ = info.input_channels[c].pixel_type
      match type_ {
        1 => {
          ptr[0] = tmp_buffer_end
          ptr[1] = ptr[0] + info.columns
          tmp_buffer_end = ptr[1] + info.columns
          for j in 0..<info.columns {
            ignore(j)
            let diff = (raw_buffer.get_int(ptr[0]) << 8) |
              raw_buffer.get_int(ptr[1])
            ptr[0] += 1
            ptr[1] += 1
            pixel += diff
            viewer.set_uint16(write_ptr, pixel.to_double(), true)
            write_ptr += 2
          }
        }
        2 => {
          ptr[0] = tmp_buffer_end
          ptr[1] = ptr[0] + info.columns
          ptr[2] = ptr[1] + info.columns
          tmp_buffer_end = ptr[2] + info.columns
          for j in 0..<info.columns {
            ignore(j)
            let diff = (raw_buffer.get_int(ptr[0]) << 24) |
              (raw_buffer.get_int(ptr[1]) << 16) |
              (raw_buffer.get_int(ptr[2]) << 8)
            ptr[0] += 1
            ptr[1] += 1
            ptr[2] += 1
            pixel += diff
            viewer.set_uint32(
              write_ptr,
              pixel.reinterpret_as_uint().to_double(),
              true,
            )
            write_ptr += 4
          }
        }
        _ => ()
      }
    }
  }
  viewer
}

///|
fn exr_uncompress_b44(state : ExrParse, info : ExrDecoder) -> ExrDataView {
  let src = info.array
  let mut src_offset = info.offset.val
  let width = info.columns
  let height = info.lines
  let channels = info.input_channels
  let total_bytes = info.total_bytes
  // B44A allows 3-byte flat blocks; B44 always uses 14-byte blocks
  let is_b44a = state.exr_header().compression() == "B44A_COMPRESSION"
  // Output buffer organised as:
  // for each scanline y: [ ch0 pixels (w×2 bytes) | ch1 pixels | … ]
  let out_buffer = @core.TypedArray::uint8(height * width * total_bytes)
  // Reusable 4×4 block buffer
  let block = @core.TypedArray::uint16(16)
  // chByteOffset mirrors channelByteOffsets accumulation in setupDecoder
  let mut ch_byte_offset = 0
  for c in 0..<channels.length() {
    let channel = channels[c]
    let pixel_size = channel.pixel_type * 2 // HALF=2, FLOAT=4
    // Effective dimensions for this channel (subsampled channels are smaller)
    let chan_width = exr_math_ceil(
      width.to_double() / channel.x_sampling.to_double(),
    )
    let chan_height = exr_math_ceil(
      height.to_double() / channel.y_sampling.to_double(),
    )
    let is_full_res = channel.x_sampling == 1 && channel.y_sampling == 1
    if channel.pixel_type != 1 {
      // Non-HALF channels are stored raw, scanline by scanline
      let mut y = 0
      while y.to_double() < chan_height {
        if is_full_res {
          let line_base = y * width * total_bytes + ch_byte_offset * width
          let mut x = 0
          while x.to_double() < chan_width * pixel_size.to_double() {
            out_buffer[line_base + x] = src[src_offset]
            src_offset += 1
            x += 1
          }
        } else {
          src_offset += (chan_width * pixel_size.to_double()).to_int()
        }
        y += 1
      }
      ch_byte_offset += pixel_size
      continue
    }
    // HALF channel — process 4×4 blocks at effective channel dimensions
    let num_blocks_x = exr_math_ceil(chan_width / 4.0)
    let num_blocks_y = exr_math_ceil(chan_height / 4.0)
    let chan_width = chan_width.to_int()
    let chan_height = chan_height.to_int()
    let mut by = 0
    while by.to_double() < num_blocks_y {
      let mut bx = 0
      while bx.to_double() < num_blocks_x {
        // B44A only: flat-block when shift ≥ 13 (byte[2] ≥ 52)
        if is_b44a && src.get_int(src_offset + 2) >= 52 {
          // 3-byte flat block — all 16 pixels share one value
          let t = (src.get_int(src_offset) << 8) | src.get_int(src_offset + 1)
          let h = if (t & 0x8000) != 0 { t & 0x7fff } else { t.lnot() & 0xffff }
          block.fill(h.to_double())
          src_offset += 3
        } else {
          // 14-byte B44 block
          let s = fn(k : Int32) { src.get_int(src_offset + k) }
          let s0 = (s(0) << 8) | s(1)
          let shift = s(2) >> 2
          let bias = 0x20 << shift
          // Reconstruct 16 ordered-magnitude values from 6-bit running deltas.
          // Prediction structure (row = 4 pixels wide):
          //   column 0 top-to-bottom: s0 → s4 → s8  → s12
          //   then row-wise:          s0 → s1 → s2  → s3
          //                           s4 → s5 → s6  → s7  etc.
          let m = 1 << shift
          let s4 = (s0 + (((s(2) << 4) | (s(3) >> 4)) & 0x3f) * m - bias) &
            0xffff
          let s8 = (s4 + (((s(3) << 2) | (s(4) >> 6)) & 0x3f) * m - bias) &
            0xffff
          let s12 = (s8 + (s(4) & 0x3f) * m - bias) & 0xffff
          let s1 = (s0 + ((s(5) >> 2) & 0x3f) * m - bias) & 0xffff
          let s5 = (s4 + (((s(5) << 4) | (s(6) >> 4)) & 0x3f) * m - bias) &
            0xffff
          let s9 = (s8 + (((s(6) << 2) | (s(7) >> 6)) & 0x3f) * m - bias) &
            0xffff
          let s13 = (s12 + (s(7) & 0x3f) * m - bias) & 0xffff
          let s2 = (s1 + ((s(8) >> 2) & 0x3f) * m - bias) & 0xffff
          let s6 = (s5 + (((s(8) << 4) | (s(9) >> 4)) & 0x3f) * m - bias) &
            0xffff
          let s10 = (s9 + (((s(9) << 2) | (s(10) >> 6)) & 0x3f) * m - bias) &
            0xffff
          let s14 = (s13 + (s(10) & 0x3f) * m - bias) & 0xffff
          let s3 = (s2 + ((s(11) >> 2) & 0x3f) * m - bias) & 0xffff
          let s7 = (s6 + (((s(11) << 4) | (s(12) >> 4)) & 0x3f) * m - bias) &
            0xffff
          let s11 = (s10 + (((s(12) << 2) | (s(13) >> 6)) & 0x3f) * m - bias) &
            0xffff
          let s15 = (s14 + (s(13) & 0x3f) * m - bias) & 0xffff
          // Convert ordered-magnitude → half-float:
          // positive (bit15=1): clear sign bit; negative (bit15=0): invert all bits
          let t = [
            s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15,
          ]
          for i in 0..<16 {
            block[i] = (if (t[i] & 0x8000) != 0 {
              t[i] & 0x7fff
            } else {
              t[i].lnot() & 0xffff
            }).to_double()
          }
          src_offset += 14
        }
        // pLinear channels: data was stored as exp(x/8), convert back with 8·log(x)
        if channel.p_linear != 0 {
          let table = match state.b44_log_table {
            Some(table) => table
            None => {
              let table = @core.TypedArray::uint16(65536)
              for i in 0..<65536 {
                if (i & 0x7c00) == 0x7c00 || i > 0x8000 {
                  table[i] = 0
                } else {
                  let f = @core.from_half_float(i.to_double())
                  table[i] = if f <= 0.0 {
                    0.0
                  } else {
                    @core.to_half_float(8.0 * exr_math_log(f))
                  }
                }
              }
              state.b44_log_table = Some(table)
              table
            }
          }
          for i in 0..<16 {
            block[i] = table[block.get_int(i)]
          }
        }
        // Scatter the 16 pixels into the scanline-interleaved output buffer.
        // For subsampled channels (e.g. RY/BY with xSampling=ySampling=2) each decoded
        // pixel is replicated across its xSampling×ySampling footprint so the output
        // buffer has uniform full-resolution scanlines that parseScanline can read directly.
        for py in 0..<4 {
          let chan_y = by * 4 + py
          if chan_y >= chan_height {
            continue
          }
          for px in 0..<4 {
            let chan_x = bx * 4 + px
            if chan_x >= chan_width {
              continue
            }
            let val = block.get_int(py * 4 + px)
            for dy in 0..<channel.y_sampling {
              let full_y = chan_y * channel.y_sampling + dy
              if full_y >= height {
                continue
              }
              for dx in 0..<channel.x_sampling {
                let full_x = chan_x * channel.x_sampling + dx
                if full_x >= width {
                  continue
                }
                let out_idx = full_y * width * total_bytes +
                  ch_byte_offset * width +
                  full_x * 2
                out_buffer[out_idx] = (val & 0xff).to_double()
                out_buffer[out_idx + 1] = ((val >> 8) & 0xff).to_double()
              }
            }
          }
        }
        bx += 1
      }
      by += 1
    }
    ch_byte_offset += 2 // HALF = 2 bytes per pixel
  }
  ExrDataView::of_buffer(out_buffer.buffer())
}

///|
/// A DWA channel rule (`channelRules[ i ]`).
priv struct ExrDwaRule {
  name : String
  index : Int32
  type_ : Int32
  compression : Int32
}

///|
fn exr_uncompress_dwa(state : ExrParse, info : ExrDecoder) -> ExrDataView {
  let in_data_view = info.viewer
  let in_offset = Ref(info.offset.val)
  let out_buffer = @core.TypedArray::uint8(
    info.columns *
    info.lines *
    (info.input_channels.length() * info.type_ * EXR_INT16_SIZE),
  )
  // Read compression header information
  let version = exr_parse_int64(in_data_view, in_offset)
  let _unknown_uncompressed_size = exr_parse_int64(in_data_view, in_offset)
  let _unknown_compressed_size = exr_parse_int64(in_data_view, in_offset)
  let ac_compressed_size = exr_parse_int64(in_data_view, in_offset)
  let dc_compressed_size = exr_parse_int64(in_data_view, in_offset)
  let rle_compressed_size = exr_parse_int64(in_data_view, in_offset)
  let _rle_uncompressed_size = exr_parse_int64(in_data_view, in_offset)
  let rle_raw_size = exr_parse_int64(in_data_view, in_offset)
  let total_ac_uncompressed_count = exr_parse_int64(in_data_view, in_offset)
  let _total_dc_uncompressed_count = exr_parse_int64(in_data_view, in_offset)
  let ac_compression = exr_parse_int64(in_data_view, in_offset)
  if version < 2.0 {
    exr_throw_error(
      "THREE.EXRLoader: " +
      state.exr_header().compression() +
      " version " +
      exr_number_string(version) +
      " is unsupported",
    )
  }
  // Read channel ruleset information
  let channel_rules : Array[ExrDwaRule] = []
  let mut rule_size = exr_parse_uint16(in_data_view, in_offset) - EXR_INT16_SIZE
  while rule_size > 0 {
    let name = exr_parse_null_terminated_string(
      in_data_view.buffer(),
      in_offset,
    )
    let value = exr_parse_uint8(in_data_view, in_offset)
    let compression = (value >> 2) & 3
    let csc = (value >> 4) - 1
    let index = csc << 24 >> 24 // new Int8Array( [ csc ] )[ 0 ]
    let type_ = exr_parse_uint8(in_data_view, in_offset)
    channel_rules.push({ name, index, type_, compression, })
    rule_size -= exr_string_length(name) + 3
  }
  // Classify channels
  let channels = state.exr_header().channels()
  let channel_data : Array[ExrDwaChannel] = []
  for i in 0..<info.input_channels.length() {
    let channel = channels[i]
    channel_data.push({
      name: channel.name,
      compression: EXR_UNKNOWN,
      decoded: false,
      type_: channel.pixel_type,
      p_linear: channel.p_linear,
      width: info.columns,
      height: info.lines,
      offset: 0,
    })
  }
  let csc_set : Array[Int32?] = Array::make(16, None)
  for offset in 0..<info.input_channels.length() {
    let cd = channel_data[offset]
    let dot_index = exr_last_index_of_dot(cd.name)
    let suffix = if dot_index >= 0 {
      exr_substring_from(cd.name, dot_index + 1)
    } else {
      cd.name
    }
    for i in 0..<channel_rules.length() {
      let rule = channel_rules[i]
      if suffix == rule.name && cd.type_ == rule.type_ {
        cd.compression = rule.compression
        if rule.index >= 0 {
          csc_set[rule.index] = Some(offset)
        }
        cd.offset = offset
      }
    }
  }
  let mut ac_buffer : @core.TypedArray? = None
  let mut dc_buffer : @core.TypedArray? = None
  let mut rle_buffer : Array[Int32]? = None
  // Read DCT - AC component data
  if ac_compressed_size > 0.0 {
    if ac_compression == EXR_STATIC_HUFFMAN.to_double() {
      let buffer = exr_new_typed("Uint16Array", total_ac_uncompressed_count)
      ac_buffer = Some(buffer)
      state.huf_uncompress(
        info.array,
        in_data_view,
        in_offset,
        ac_compressed_size,
        buffer,
        total_ac_uncompressed_count,
      )
    } else if ac_compression == EXR_DEFLATE.to_double() {
      let compressed = exr_typed_slice(
        info.array,
        in_offset.val,
        in_offset.val.to_double() + total_ac_uncompressed_count,
      )
      let data = @libs.unzlib_sync(compressed)
      ac_buffer = Some(exr_typed_of_buffer("Uint16Array", data.buffer()))
      exr_advance(in_offset, total_ac_uncompressed_count)
    }
  }
  // Read DCT - DC component data
  if dc_compressed_size > 0.0 {
    dc_buffer = Some(
      exr_typed_of_buffer(
        "Uint16Array",
        exr_uncompress_zip_parts(info.array, in_offset.val, dc_compressed_size).buffer(),
      ),
    )
    exr_advance(in_offset, dc_compressed_size)
  }
  // Read RLE compressed data
  if rle_raw_size > 0.0 {
    let compressed = exr_typed_slice(
      info.array,
      in_offset.val,
      in_offset.val.to_double() + rle_compressed_size,
    )
    let data = @libs.unzlib_sync(compressed)
    rle_buffer = Some(exr_decode_run_length(data.buffer()))
    exr_advance(in_offset, rle_compressed_size)
  }
  // Prepare outbuffer data offset
  let mut out_buffer_end = 0
  let row_offsets : Array[Array[Int32]] = Array::makei(channel_data.length(), _ => {
    []
  })
  for y in 0..<info.lines {
    ignore(y)
    for chan in 0..<channel_data.length() {
      row_offsets[chan].push(out_buffer_end)
      out_buffer_end += channel_data[chan].width * info.type_ * EXR_INT16_SIZE
    }
  }
  // Decode lossy DCT data if we have a valid color space conversion set with the first RGB channel present
  if csc_set[0] is Some(i0) && i0 < channel_data.length() {
    state.lossy_dct_decode(
      csc_set, row_offsets, channel_data, ac_buffer, dc_buffer, out_buffer,
    )
  }
  // Decode other channels
  for i in 0..<channel_data.length() {
    let cd = channel_data[i]
    if cd.decoded {
      continue
    }
    match cd.compression {
      EXR_RLE => {
        let mut row = 0
        let mut rle_offset = 0
        let rle_buffer = match rle_buffer {
          Some(b) => b
          None => {
            exr_throw_type_error(
              "Cannot read properties of undefined (reading '0')",
            )
            panic()
          }
        }
        for y in 0..<info.lines {
          ignore(y)
          let mut row_offset_bytes = row_offsets[i][row]
          for x in 0..<cd.width {
            ignore(x)
            for byte in 0..<(EXR_INT16_SIZE * cd.type_) {
              out_buffer[row_offset_bytes] = rle_buffer
                .get(rle_offset + byte * cd.width * cd.height)
                .unwrap_or(0)
                .to_double()
              row_offset_bytes += 1
            }
            rle_offset += 1
          }
          row += 1
        }
      }
      EXR_LOSSY_DCT =>
        state.lossy_dct_channel_decode(
          i, row_offsets, channel_data, ac_buffer, dc_buffer, out_buffer,
        )
      _ => exr_throw_error("THREE.EXRLoader: unsupported channel compression")
    }
  }
  ExrDataView::of_buffer(out_buffer.buffer())
}

///|
extern "js" fn exr_string_length(s : String) -> Int32 = "(s) => s.length"

///|
extern "js" fn exr_last_index_of_dot(s : String) -> Int32 = "(s) => s.lastIndexOf('.')"

///|
extern "js" fn exr_substring_from(s : String, start : Int32) -> String = "(s, i) => s.substring(i)"

// --- primitive readers ---------------------------------------------------------------------

///|
fn exr_parse_null_terminated_string(
  buffer : @core.ArrayBuffer,
  offset : Ref[Int32],
) -> String {
  let uint_buffer = exr_typed_of_buffer("Uint8Array", buffer)
  // A JS number, as upstream's: an Int32 index would wrap after 2^32 steps past the end
  // and find a 0 byte, where upstream (`undefined != 0` is true) never stops.
  let mut end_offset = 0.0
  while exr_typed_get_number(uint_buffer, offset.val.to_double() + end_offset) !=
        0.0 {
    end_offset += 1.0
  }
  let end_offset = end_offset.to_int()
  let string_value = exr_text_decode(
    uint_buffer.slice(start=offset.val, end=offset.val + end_offset),
  )
  offset.val = offset.val + end_offset + 1
  string_value
}

///|
/// `array[ index ]` with a JS number index (`undefined` past the end).
extern "js" fn exr_typed_get_number(
  array : @core.TypedArray,
  index : Double,
) -> Double = "(a, i) => a[i]"

///|
fn exr_parse_fixed_length_string(
  buffer : @core.ArrayBuffer,
  offset : Ref[Int32],
  size : Double,
) -> String {
  let string_value = exr_text_decode(
    exr_typed_slice(
      exr_typed_of_buffer("Uint8Array", buffer),
      offset.val,
      offset.val.to_double() + size,
    ),
  )
  exr_advance(offset, size)
  string_value
}

///|
fn exr_parse_rational(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> Array[Double] {
  let x = exr_parse_int32(data_view, offset)
  let y = exr_parse_uint32(data_view, offset)
  [x.to_double(), y]
}

///|
fn exr_parse_timecode(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> Array[Double] {
  let x = exr_parse_uint32(data_view, offset)
  let y = exr_parse_uint32(data_view, offset)
  [x, y]
}

///|
fn exr_parse_int32(data_view : ExrDataView, offset : Ref[Int32]) -> Int32 {
  let int32 = data_view.get_int32(offset.val, true)
  offset.val = offset.val + EXR_INT32_SIZE
  int32
}

///|
fn exr_parse_uint32(data_view : ExrDataView, offset : Ref[Int32]) -> Double {
  let uint32 = data_view.get_uint32(offset.val, true)
  offset.val = offset.val + EXR_INT32_SIZE
  uint32
}

///|
fn exr_parse_uint8_array(
  u_int8_array : @core.TypedArray,
  offset : Ref[Int32],
) -> Int32 {
  let uint8 = u_int8_array.get_int(offset.val)
  offset.val = offset.val + EXR_INT8_SIZE
  uint8
}

///|
fn exr_parse_uint8(data_view : ExrDataView, offset : Ref[Int32]) -> Int32 {
  let uint8 = data_view.get_uint8(offset.val)
  offset.val = offset.val + EXR_INT8_SIZE
  uint8
}

///|
fn exr_parse_int64(data_view : ExrDataView, offset : Ref[Int32]) -> Double {
  let int = data_view.get_big_int64_number(offset.val, true)
  offset.val += EXR_ULONG_SIZE
  int
}

///|
fn exr_parse_float32(data_view : ExrDataView, offset : Ref[Int32]) -> Double {
  let float = data_view.get_float32(offset.val, true)
  offset.val += EXR_FLOAT32_SIZE
  float
}

///|
fn exr_decode_float32(data_view : ExrDataView, offset : Ref[Int32]) -> Double {
  @core.to_half_float(exr_parse_float32(data_view, offset))
}

///|
fn exr_parse_uint16(data_view : ExrDataView, offset : Ref[Int32]) -> Int32 {
  let uint16 = data_view.get_uint16(offset.val, true)
  offset.val += EXR_INT16_SIZE
  uint16
}

///|
fn exr_parse_uint16_number(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> Double {
  exr_parse_uint16(data_view, offset).to_double()
}

///|
fn exr_parse_float16(data_view : ExrDataView, offset : Ref[Int32]) -> Double {
  @core.from_half_float(exr_parse_uint16(data_view, offset).to_double())
}

///|
fn exr_parse_chlist(
  data_view : ExrDataView,
  buffer : @core.ArrayBuffer,
  offset : Ref[Int32],
  size : Double,
) -> Array[ExrChannel] {
  let start_offset = offset.val
  let channels = []
  while offset.val.to_double() < start_offset.to_double() + size - 1.0 {
    let name = exr_parse_null_terminated_string(buffer, offset)
    let pixel_type = exr_parse_int32(data_view, offset)
    let p_linear = exr_parse_uint8(data_view, offset)
    offset.val += 3 // reserved, three chars
    let x_sampling = exr_parse_int32(data_view, offset)
    let y_sampling = exr_parse_int32(data_view, offset)
    channels.push({ name, pixel_type, p_linear, x_sampling, y_sampling, })
  }
  offset.val += 1
  channels
}

///|
fn exr_parse_chromaticities(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> Array[Double] {
  Array::makei(8, _ => exr_parse_float32(data_view, offset))
}

///|
let exr_compression_codes : Array[String] = [
  "NO_COMPRESSION", "RLE_COMPRESSION", "ZIPS_COMPRESSION", "ZIP_COMPRESSION", "PIZ_COMPRESSION",
  "PXR24_COMPRESSION", "B44_COMPRESSION", "B44A_COMPRESSION", "DWAA_COMPRESSION",
  "DWAB_COMPRESSION",
]

///|
fn exr_parse_compression(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> String? {
  let compression = exr_parse_uint8(data_view, offset)
  exr_compression_codes.get(compression)
}

///|
fn exr_parse_box2i(data_view : ExrDataView, offset : Ref[Int32]) -> ExrBox2i {
  let x_min = exr_parse_int32(data_view, offset)
  let y_min = exr_parse_int32(data_view, offset)
  let x_max = exr_parse_int32(data_view, offset)
  let y_max = exr_parse_int32(data_view, offset)
  { x_min, y_min, x_max, y_max, }
}

///|
fn exr_parse_line_order(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> String? {
  let line_orders = ["INCREASING_Y", "DECREASING_Y", "RANDOM_Y"]
  let line_order = exr_parse_uint8(data_view, offset)
  line_orders.get(line_order)
}

///|
fn exr_parse_envmap(data_view : ExrDataView, offset : Ref[Int32]) -> String? {
  let envmaps = ["ENVMAP_LATLONG", "ENVMAP_CUBE"]
  let envmap = exr_parse_uint8(data_view, offset)
  envmaps.get(envmap)
}

///|
fn exr_parse_tiledesc(
  data_view : ExrDataView,
  offset : Ref[Int32],
) -> ExrTiledesc {
  let level_modes = ["ONE_LEVEL", "MIPMAP_LEVELS", "RIPMAP_LEVELS"]
  let rounding_modes = ["ROUND_DOWN", "ROUND_UP"]
  let x_size = exr_parse_uint32(data_view, offset)
  let y_size = exr_parse_uint32(data_view, offset)
  let modes = exr_parse_uint8(data_view, offset)
  {
    x_size,
    y_size,
    level_mode: level_modes.get(modes & 0xf),
    rounding_mode: rounding_modes.get(modes >> 4),
  }
}

///|
fn exr_parse_v2f(data_view : ExrDataView, offset : Ref[Int32]) -> Array[Double] {
  let x = exr_parse_float32(data_view, offset)
  let y = exr_parse_float32(data_view, offset)
  [x, y]
}

///|
fn exr_parse_v3f(data_view : ExrDataView, offset : Ref[Int32]) -> Array[Double] {
  let x = exr_parse_float32(data_view, offset)
  let y = exr_parse_float32(data_view, offset)
  let z = exr_parse_float32(data_view, offset)
  [x, y, z]
}

///|
/// Upstream `parseValue`; `None` is `undefined` (an unknown type, or a code outside
/// upstream's lists).
fn exr_parse_value(
  data_view : ExrDataView,
  buffer : @core.ArrayBuffer,
  offset : Ref[Int32],
  type_ : String,
  size : Double,
) -> ExrValue? {
  match type_ {
    "string" | "stringvector" | "iccProfile" =>
      Some(Str(exr_parse_fixed_length_string(buffer, offset, size)))
    "chlist" => Some(Chlist(exr_parse_chlist(data_view, buffer, offset, size)))
    "chromaticities" =>
      Some(Chromaticities(exr_parse_chromaticities(data_view, offset)))
    "compression" =>
      exr_parse_compression(data_view, offset).map(c => Compression(c))
    "box2i" => Some(Box2i(exr_parse_box2i(data_view, offset)))
    "envmap" => exr_parse_envmap(data_view, offset).map(e => Envmap(e))
    "tiledesc" => Some(Tiledesc(exr_parse_tiledesc(data_view, offset)))
    "lineOrder" =>
      exr_parse_line_order(data_view, offset).map(l => LineOrder(l))
    "float" => Some(Float(exr_parse_float32(data_view, offset)))
    "v2f" => Some(Numbers(exr_parse_v2f(data_view, offset)))
    "v3f" => Some(Numbers(exr_parse_v3f(data_view, offset)))
    "int" => Some(Int(exr_parse_int32(data_view, offset)))
    "rational" => Some(Numbers(exr_parse_rational(data_view, offset)))
    "timecode" => Some(Numbers(exr_parse_timecode(data_view, offset)))
    "preview" | "deepImageState" | "idmanifest" => {
      // Known metadata-only types: silently skip, they carry no pixel data.
      exr_advance(offset, size)
      Some(Str("skipped"))
    }
    _ => {
      exr_advance(offset, size)
      None
    }
  }
}

///|
fn exr_round_log2(x : Double, mode : String?) -> Double {
  let log2 = exr_math_log2(x)
  if mode == Some("ROUND_DOWN") {
    exr_math_floor(log2)
  } else {
    exr_math_ceil(log2)
  }
}

///|
fn exr_calculate_tile_levels(
  tiledesc : ExrTiledesc,
  w : Int32,
  h : Int32,
) -> Double {
  let mut num = 0.0
  match tiledesc.level_mode {
    Some("ONE_LEVEL") => num = 1.0
    Some("MIPMAP_LEVELS") =>
      num = exr_round_log2(
          exr_math_max(w.to_double(), h.to_double()),
          tiledesc.rounding_mode,
        ) +
        1.0
    Some("RIPMAP_LEVELS") =>
      exr_throw_error(
        "THREE.EXRLoader: RIPMAP_LEVELS tiles currently unsupported.",
      )
    _ => ()
  }
  num
}

///|
fn exr_calculate_tiles(
  count : Double,
  data_size : Int32,
  size : Double,
  rounding_mode : String?,
) -> Array[Int32] {
  let tiles = []
  let mut i = 0
  while i.to_double() < count {
    let b = 1 << i
    let mut s = data_size / b
    if rounding_mode == Some("ROUND_UP") && s * b < data_size {
      s += 1
    }
    let l = if s > 1 { s } else { 1 }
    tiles.push(exr_to_int32((l.to_double() + size - 1.0) / size))
    i += 1
  }
  tiles
}

///|
/// Stores `getter( viewer, tmpOffset )` at `outIndex`, as upstream's
/// `EXRDecoder.byteArray[ outIndex ] = EXRDecoder.getter( viewer, tmpOffset )`.
fn ExrDecoder::store(
  self : ExrDecoder,
  out_index : Double,
  viewer : ExrDataView,
  tmp_offset : Ref[Int32],
) -> Unit {
  guard self.getter is Some(getter) else {
    exr_throw_type_error("EXRDecoder.getter is not a function")
    return
  }
  let value = getter(viewer, tmp_offset)
  match self.byte_array {
    Some(byte_array) => exr_typed_set_at(byte_array, out_index, value)
    None =>
      exr_throw_type_error(
        "Cannot set properties of undefined (setting '" +
        exr_number_string(out_index) +
        "')",
      )
  }
}

///|
/// `array[ index ] = value` for a JS number index (out-of-range writes are dropped).
extern "js" fn exr_typed_set_at(
  array : @core.TypedArray,
  index : Double,
  value : Double,
) -> Unit = "(a, i, v) => { a[i] = v; }"

///|
/// Upstream's `( line + blockHeight > height ) ? ( height - line ) : blockHeight`.
fn exr_block_extent(start : Double, block : Int32, size : Int32) -> Double {
  if start + block.to_double() > size.to_double() {
    size.to_double() - start
  } else {
    block.to_double()
  }
}

///|
fn ExrParse::parse_tiles(self : ExrParse, decoder : ExrDecoder) -> Unit {
  let exr_decoder = decoder
  let offset = exr_decoder.offset
  let tmp_offset = Ref(0)
  let header = self.exr_header()
  for tile in 0..<exr_decoder.tile_count {
    ignore(tile)
    let tile_x = exr_parse_int32(exr_decoder.viewer, offset)
    let tile_y = exr_parse_int32(exr_decoder.viewer, offset)
    offset.val += 8 // skip levels - only parsing top-level
    exr_decoder.size = exr_parse_uint32(exr_decoder.viewer, offset)
    // JS numbers: corrupt tile coordinates must not wrap
    let start_x = tile_x.to_double() * exr_decoder.block_width.to_double()
    let start_y = tile_y.to_double() * exr_decoder.block_height.to_double()
    let columns = exr_block_extent(
      start_x,
      exr_decoder.block_width,
      exr_decoder.width,
    )
    let lines = exr_block_extent(
      start_y,
      exr_decoder.block_height,
      exr_decoder.height,
    )
    exr_decoder.columns = columns.to_int()
    exr_decoder.lines = lines.to_int()
    let bytes_block_line = columns * exr_decoder.total_bytes.to_double()
    let is_compressed = exr_decoder.size < lines * bytes_block_line
    let viewer = if is_compressed {
      (exr_decoder.uncompress)(self, exr_decoder)
    } else {
      exr_uncompress_raw(self, exr_decoder)
    }
    exr_advance(offset, exr_decoder.size)
    for line in 0..<exr_decoder.lines {
      let line_offset = line * exr_decoder.columns * exr_decoder.total_bytes
      for channel_id in 0..<exr_decoder.input_channels.length() {
        let name = header.channels()[channel_id].name
        guard exr_decoder.decode_channels.get(name) is Some(c_off) else {
          continue
        }
        let l_off = exr_decoder.channel_byte_offsets[name] * exr_decoder.columns
        tmp_offset.val = line_offset + l_off
        let out_line_offset = (
            exr_decoder.height.to_double() - (1.0 + start_y + line.to_double())
          ) *
          exr_decoder.out_line_width.to_double()
        for x in 0..<exr_decoder.columns {
          let out_index = out_line_offset +
            (x.to_double() + start_x) * exr_decoder.output_channels.to_double() +
            c_off.to_double()
          exr_decoder.store(out_index, viewer, tmp_offset)
        }
      }
    }
  }
}

///|
fn ExrParse::parse_scanline(self : ExrParse, decoder : ExrDecoder) -> Unit {
  let exr_decoder = decoder
  let offset = exr_decoder.offset
  let tmp_offset = Ref(0)
  let header = self.exr_header()
  let mut scanline_block_idx = 0
  while scanline_block_idx.to_double() <
        exr_decoder.height.to_double() / exr_decoder.block_height.to_double() {
    let line = exr_parse_int32(exr_decoder.viewer, offset).to_double() -
      header.data_window().y_min.to_double() // line_no
    exr_decoder.size = exr_parse_uint32(exr_decoder.viewer, offset) // data_len
    // JS numbers: a corrupt line number must not wrap
    let lines = exr_block_extent(
      line,
      exr_decoder.block_height,
      exr_decoder.height,
    )
    exr_decoder.lines = lines.to_int()
    let bytes_per_line = exr_decoder.columns * exr_decoder.total_bytes
    let is_compressed = exr_decoder.size < lines * bytes_per_line.to_double()
    let viewer = if is_compressed {
      (exr_decoder.uncompress)(self, exr_decoder)
    } else {
      exr_uncompress_raw(self, exr_decoder)
    }
    exr_advance(offset, exr_decoder.size)
    for line_y in 0..<exr_decoder.lines {
      let true_y = line + line_y.to_double()
      let line_offset = line_y * bytes_per_line
      let out_line_offset = (exr_decoder.height.to_double() - 1.0 - true_y) *
        exr_decoder.out_line_width.to_double()
      for channel_id in 0..<exr_decoder.input_channels.length() {
        let name = header.channels()[channel_id].name
        guard exr_decoder.decode_channels.get(name) is Some(c_off) else {
          continue
        }
        let l_off = exr_decoder.channel_byte_offsets[name] * exr_decoder.columns
        tmp_offset.val = line_offset + l_off
        for x in 0..<exr_decoder.columns {
          let out_index = out_line_offset +
            (x * exr_decoder.output_channels + c_off).to_double()
          exr_decoder.store(out_index, viewer, tmp_offset)
        }
      }
    }
    scanline_block_idx += 1
  }
}

///|
fn ExrParse::parse_multi_part_scanline(
  self : ExrParse,
  decoder : ExrDecoder,
) -> Unit {
  let exr_decoder = decoder
  let chunk_offsets = exr_decoder.chunk_offsets
  let tmp_offset = Ref(0)
  let header = self.exr_header()
  for chunk_idx in 0..<chunk_offsets.length() {
    let offset = Ref(chunk_offsets[chunk_idx].to_int())
    offset.val += EXR_INT32_SIZE // skip part number
    let line = exr_parse_int32(exr_decoder.viewer, offset).to_double() -
      header.data_window().y_min.to_double()
    exr_decoder.size = exr_parse_uint32(exr_decoder.viewer, offset)
    // JS numbers: a corrupt line number must not wrap
    let lines = exr_block_extent(
      line,
      exr_decoder.block_height,
      exr_decoder.height,
    )
    exr_decoder.lines = lines.to_int()
    let bytes_per_line = exr_decoder.columns * exr_decoder.total_bytes
    let is_compressed = exr_decoder.size < lines * bytes_per_line.to_double()
    let saved_offset = exr_decoder.offset
    exr_decoder.offset = offset
    let viewer = if is_compressed {
      (exr_decoder.uncompress)(self, exr_decoder)
    } else {
      exr_uncompress_raw(self, exr_decoder)
    }
    exr_decoder.offset = saved_offset
    for line_y in 0..<exr_decoder.lines {
      let true_y = line + line_y.to_double()
      let line_offset = line_y * bytes_per_line
      let out_line_offset = (exr_decoder.height.to_double() - 1.0 - true_y) *
        exr_decoder.out_line_width.to_double()
      for channel_id in 0..<exr_decoder.input_channels.length() {
        let name = header.channels()[channel_id].name
        guard exr_decoder.decode_channels.get(name) is Some(c_off) else {
          continue
        }
        let l_off = exr_decoder.channel_byte_offsets[name] * exr_decoder.columns
        tmp_offset.val = line_offset + l_off
        for x in 0..<exr_decoder.columns {
          let out_index = out_line_offset +
            (x * exr_decoder.output_channels + c_off).to_double()
          exr_decoder.store(out_index, viewer, tmp_offset)
        }
      }
    }
  }
}

///|
fn exr_decompress_deep_data(
  array : @core.TypedArray,
  compressed_offset : Int32,
  compressed_size : Double,
  compression : String,
) -> ExrDataView? {
  if compressed_size == 0.0 {
    return None
  }
  let compressed = exr_typed_slice(
    array,
    compressed_offset,
    compressed_offset.to_double() + compressed_size,
  )
  match compression {
    "NO_COMPRESSION" =>
      Some(
        ExrDataView::new(
          compressed.buffer(),
          compressed.byte_offset(),
          compressed.byte_length().to_double(),
        ),
      )
    "RLE_COMPRESSION" => {
      let raw_buffer = @core.TypedArray::uint8(
        exr_decode_run_length(
          exr_array_buffer_slice(
            compressed.buffer(),
            compressed.byte_offset(),
            (compressed.byte_offset() + compressed.byte_length()).to_double(),
          ),
        ),
      )
      let tmp_buffer = @core.TypedArray::uint8(raw_buffer.length())
      exr_predictor(raw_buffer)
      exr_interleave_scalar(raw_buffer, tmp_buffer)
      Some(ExrDataView::of_buffer(tmp_buffer.buffer()))
    }
    "ZIPS_COMPRESSION" => {
      let raw_buffer = @libs.unzlib_sync(compressed)
      let tmp_buffer = @core.TypedArray::uint8(raw_buffer.length())
      exr_predictor(raw_buffer)
      exr_interleave_scalar(raw_buffer, tmp_buffer)
      Some(ExrDataView::of_buffer(tmp_buffer.buffer()))
    }
    _ => {
      exr_throw_error(
        "THREE.EXRLoader: " + compression + " is unsupported for deep data",
      )
      None
    }
  }
}

///|
fn ExrParse::parse_deep_scanline(self : ExrParse, decoder : ExrDecoder) -> Unit {
  let exr_decoder = decoder
  let header = self.exr_header()
  let chunk_offsets = exr_decoder.chunk_offsets
  let width = exr_decoder.width
  let height = exr_decoder.height
  let deep_channels = exr_decoder.deep_channels
  let compression = header.compression()
  let is_multi_part = exr_decoder.multi_part
  // Build a map from channel name to decode output slot
  let decode_channels = exr_decoder.decode_channels
  let output_channels = exr_decoder.output_channels
  let is_half_output = match exr_decoder.byte_array {
    Some(a) => a.type_name() == "Uint16Array"
    None => false
  }
  // Find the alpha channel index in deepChannels (for compositing)
  let mut alpha_channel_idx = -1
  for i in 0..<deep_channels.length() {
    if deep_channels[i].name == "A" {
      alpha_channel_idx = i
      break
    }
  }
  for chunk_idx in 0..<chunk_offsets.length() {
    let chunk_offset = Ref(chunk_offsets[chunk_idx].to_int())
    // Multi-part files have a part number prefix per chunk
    if is_multi_part {
      chunk_offset.val += EXR_INT32_SIZE
    }
    let line = exr_parse_int32(exr_decoder.viewer, chunk_offset).to_double() -
      header.data_window().y_min.to_double()
    // Read deep scanline sizes
    let sct_compressed_size = exr_parse_int64(exr_decoder.viewer, chunk_offset)
    let data_compressed_size = exr_parse_int64(exr_decoder.viewer, chunk_offset)
    ignore(exr_parse_int64(exr_decoder.viewer, chunk_offset)) // uncompressed data size (unused)
    // Decompress sample count table
    let sct_view = exr_decompress_deep_data(
      exr_decoder.array,
      chunk_offset.val,
      sct_compressed_size,
      compression,
    )
    exr_advance(chunk_offset, sct_compressed_size)
    guard sct_view is Some(sct_view) else { continue }
    // Parse cumulative sample counts
    let cumulative_counts = @core.TypedArray::uint32(width)
    for x in 0..<width {
      cumulative_counts[x] = sct_view.get_uint32(x * 4, true)
    }
    let total_samples = cumulative_counts[width - 1]
    if total_samples == 0.0 {
      exr_advance(chunk_offset, data_compressed_size)
      continue
    }
    // Decompress pixel data
    let pixel_view = exr_decompress_deep_data(
      exr_decoder.array,
      chunk_offset.val,
      data_compressed_size,
      compression,
    )
    // Compute channel byte offsets within the decompressed pixel data.
    // Deep data layout: channels are contiguous, each has totalSamples values.
    let channel_offsets = []
    let mut byte_pos = 0.0
    for i in 0..<deep_channels.length() {
      channel_offsets.push(byte_pos)
      byte_pos += total_samples * deep_channels[i].bytes_per_sample.to_double()
    }
    // Flatten deep samples: front-to-back composite with premultiplied alpha
    let out_line_offset = (height.to_double() - 1.0 - line) *
      exr_decoder.out_line_width.to_double()
    for x in 0..<width {
      let start_sample = if x == 0 { 0.0 } else { cumulative_counts[x - 1] }
      let end_sample = cumulative_counts[x]
      let num_samples = end_sample - start_sample
      if num_samples == 0.0 {
        continue
      }
      let pixel_view = match pixel_view {
        Some(v) => v
        None => {
          exr_throw_type_error(
            "Cannot read properties of null (reading 'getUint16')",
          )
          panic()
        }
      }
      // Composite samples front-to-back (premultiplied alpha)
      let composited = @core.TypedArray::float32(output_channels)
      let mut composited_alpha = 0.0
      let mut s = 0.0
      while s < num_samples {
        let sample_idx = start_sample + s
        let factor = 1.0 - composited_alpha
        if factor <= 0.0 {
          break
        }
        // Read alpha for this sample
        let mut sample_alpha = 1.0
        if alpha_channel_idx >= 0 {
          let a_bps = deep_channels[alpha_channel_idx].bytes_per_sample
          let a_off = (channel_offsets[alpha_channel_idx] +
          sample_idx * a_bps.to_double()).to_int()
          sample_alpha = if a_bps == 2 {
            @core.from_half_float(
              pixel_view.get_uint16(a_off, true).to_double(),
            )
          } else {
            pixel_view.get_float32(a_off, true)
          }
        }
        // Read and composite each output channel
        for ci in 0..<deep_channels.length() {
          let ch = deep_channels[ci]
          guard decode_channels.get(ch.name) is Some(c_off) else { continue }
          let bps = ch.bytes_per_sample
          let data_off = (channel_offsets[ci] + sample_idx * bps.to_double()).to_int()
          let value = if bps == 2 {
            @core.from_half_float(
              pixel_view.get_uint16(data_off, true).to_double(),
            )
          } else {
            pixel_view.get_float32(data_off, true)
          }
          composited[c_off] = composited[c_off] + value * factor
        }
        composited_alpha += sample_alpha * factor
        s += 1.0
      }
      // If alpha channel is being output, set it
      if decode_channels.get("A") is Some(a) {
        composited[a] = composited_alpha
      }
      // Write to output buffer
      let out_index = out_line_offset + (x * output_channels).to_double()
      guard exr_decoder.byte_array is Some(byte_array) else {
        exr_throw_type_error("Cannot set properties of undefined")
        panic()
      }
      for c in 0..<output_channels {
        exr_typed_set_at(
          byte_array,
          out_index + c.to_double(),
          if is_half_output {
            @core.to_half_float(composited[c])
          } else {
            composited[c]
          },
        )
      }
    }
  }
}

// --- headers ---------------------------------------------------------------------------------

///|
fn exr_parse_part_header(
  data_view : ExrDataView,
  buffer : @core.ArrayBuffer,
  offset : Ref[Int32],
) -> ExrHeader? {
  let attributes = Map([])
  let mut has_attributes = false
  while true {
    let attribute_name = exr_parse_null_terminated_string(buffer, offset)
    if attribute_name == "" {
      break
    }
    has_attributes = true
    let attribute_type = exr_parse_null_terminated_string(buffer, offset)
    let attribute_size = exr_parse_uint32(data_view, offset)
    let attribute_value = exr_parse_value(
      data_view, buffer, offset, attribute_type, attribute_size,
    )
    match attribute_value {
      None =>
        exr_console_warn(
          "THREE.EXRLoader: Skipped unknown header attribute type '" +
          attribute_type +
          "'.",
        )
      Some(value) => attributes[attribute_name] = value
    }
  }
  if has_attributes {
    Some({
      attributes,
      version: 0,
      spec: {
        single_tile: false,
        long_name: false,
        deep_format: false,
        multi_part: false,
      },
      chunk_offsets: None,
    })
  } else {
    None
  }
}

///|
fn exr_parse_header(
  data_view : ExrDataView,
  buffer : @core.ArrayBuffer,
  offset : Ref[Int32],
) -> Array[ExrHeader] {
  if data_view.get_uint32(0, true) != 20000630 { // magic
    exr_throw_error(
      "THREE.EXRLoader: Provided file doesn't appear to be in OpenEXR format.",
    )
  }
  let version = data_view.get_uint8(4)
  let spec = data_view.get_uint8(5) // fullMask
  let flags = {
    single_tile: (spec & 2) != 0,
    long_name: (spec & 4) != 0,
    deep_format: (spec & 8) != 0,
    multi_part: (spec & 16) != 0,
  }
  // start of header
  offset.val = 8 // start at 8 - after pre-amble
  let headers = []
  if flags.multi_part {
    // Multi-part files: parse all part headers.
    // Each part header ends with an empty attribute name (null byte).
    // The header section ends when a null byte is read with no preceding attributes.
    while true {
      guard exr_parse_part_header(data_view, buffer, offset) is Some(header) else {
        break
      }
      header.version = version
      header.spec = flags
      headers.push(header)
    }
    if headers.length() == 0 {
      exr_throw_error("THREE.EXRLoader: No valid part headers found.")
    }
  } else {
    // Single-part (standard or deep): one header
    guard exr_parse_part_header(data_view, buffer, offset) is Some(header) else {
      // upstream sets `version` on the `null` it got back
      exr_throw_type_error("Cannot set properties of null (setting 'version')")
      panic()
    }
    header.version = version
    header.spec = flags
    headers.push(header)
  }
  headers
}

///|
/// `max - min + 1` as a JS number.
fn exr_window_size(min : Int32, max : Int32) -> Double {
  max.to_double() - min.to_double() + 1.0
}

///|
fn ExrParse::setup_decoder(
  self : ExrParse,
  exr_header : ExrHeader,
  data_view : ExrDataView,
  u_int8_array : @core.TypedArray,
  offset : Ref[Int32],
  output_type : Int32,
  output_format : Int32,
) -> ExrDecoder {
  let data_window = exr_header.data_window()
  let exr_decoder : ExrDecoder = {
    size: 0.0,
    viewer: data_view,
    array: u_int8_array,
    offset,
    width: exr_window_size(data_window.x_min, data_window.x_max).to_int(),
    height: exr_window_size(data_window.y_min, data_window.y_max).to_int(),
    input_channels: exr_header.channels(),
    channel_byte_offsets: Map([]),
    should_expand: false,
    y_cb_cr: false,
    total_bytes: 0,
    columns: 0,
    lines: 0,
    type_: 0,
    uncompress: exr_uncompress_raw,
    getter: None,
    format: 0,
    color_space: @core.LinearSRGBColorSpace,
    block_height: 0,
    block_width: 0,
    output_channels: 0,
    decode_channels: Map([]),
    byte_array: None,
    out_line_width: 0,
    tile_count: 0,
    deep_channels: [],
    deep_bytes_per_sample: 0,
    chunk_offsets: [],
    multi_part: false,
    decode: Scanline,
  }
  match exr_header.compression() {
    "NO_COMPRESSION" => {
      exr_decoder.block_height = 1
      exr_decoder.uncompress = exr_uncompress_raw
    }
    "RLE_COMPRESSION" => {
      exr_decoder.block_height = 1
      exr_decoder.uncompress = exr_uncompress_rle
    }
    "ZIPS_COMPRESSION" => {
      exr_decoder.block_height = 1
      exr_decoder.uncompress = exr_uncompress_zip
    }
    "ZIP_COMPRESSION" => {
      exr_decoder.block_height = 16
      exr_decoder.uncompress = exr_uncompress_zip
    }
    "PIZ_COMPRESSION" => {
      exr_decoder.block_height = 32
      exr_decoder.uncompress = exr_uncompress_piz
    }
    "PXR24_COMPRESSION" => {
      exr_decoder.block_height = 16
      exr_decoder.uncompress = exr_uncompress_pxr
    }
    "B44_COMPRESSION" | "B44A_COMPRESSION" => {
      exr_decoder.block_height = 32
      exr_decoder.uncompress = exr_uncompress_b44
    }
    "DWAA_COMPRESSION" => {
      exr_decoder.block_height = 32
      exr_decoder.uncompress = exr_uncompress_dwa
    }
    "DWAB_COMPRESSION" => {
      exr_decoder.block_height = 256
      exr_decoder.uncompress = exr_uncompress_dwa
    }
    compression =>
      exr_throw_error("THREE.EXRLoader: " + compression + " is unsupported")
  }
  let channels : Map[String, Bool] = Map([])
  for channel in exr_header.channels() {
    match channel.name {
      "BY" | "RY" | "Y" | "R" | "G" | "B" | "A" => {
        channels[channel.name] = true
        exr_decoder.type_ = channel.pixel_type
      }
      _ => ()
    }
  }
  // RGB images will be converted to RGBA format, preventing software emulation in select devices.
  let mut fill_alpha = false
  let mut invalid_output = false
  let has = fn(name : String) { channels.contains(name) }
  // Validate if input texture contain supported channels
  if has("Y") && has("RY") && has("BY") {
    exr_decoder.output_channels = 4
    exr_decoder.y_cb_cr = true
  } else if has("R") && has("G") && has("B") {
    exr_decoder.output_channels = 4
  } else if has("Y") {
    exr_decoder.output_channels = 1
  } else {
    exr_throw_error("THREE.EXRLoader: file contains unsupported data channels.")
  }
  // Setup output texture configuration
  match exr_decoder.output_channels {
    4 =>
      if output_format == @core.RGBAFormat {
        fill_alpha = !has("A")
        exr_decoder.format = @core.RGBAFormat
        exr_decoder.color_space = @core.LinearSRGBColorSpace
        exr_decoder.output_channels = 4
        exr_decoder.decode_channels = { "R": 0, "G": 1, "B": 2, "A": 3 }
      } else if output_format == @core.RGFormat {
        exr_decoder.format = @core.RGFormat
        exr_decoder.color_space = @core.LinearSRGBColorSpace
        exr_decoder.output_channels = 2
        exr_decoder.decode_channels = { "R": 0, "G": 1 }
      } else if output_format == @core.RedFormat {
        exr_decoder.format = @core.RedFormat
        exr_decoder.color_space = @core.LinearSRGBColorSpace
        exr_decoder.output_channels = 1
        exr_decoder.decode_channels = { "R": 0 }
      } else {
        invalid_output = true
      }
    1 =>
      if output_format == @core.RGBAFormat {
        fill_alpha = true
        exr_decoder.format = @core.RGBAFormat
        exr_decoder.color_space = @core.LinearSRGBColorSpace
        exr_decoder.output_channels = 4
        exr_decoder.should_expand = true
        exr_decoder.decode_channels = { "Y": 0 }
      } else if output_format == @core.RGFormat {
        exr_decoder.format = @core.RGFormat
        exr_decoder.color_space = @core.LinearSRGBColorSpace
        exr_decoder.output_channels = 2
        exr_decoder.should_expand = true
        exr_decoder.decode_channels = { "Y": 0 }
      } else if output_format == @core.RedFormat {
        exr_decoder.format = @core.RedFormat
        exr_decoder.color_space = @core.LinearSRGBColorSpace
        exr_decoder.output_channels = 1
        exr_decoder.decode_channels = { "Y": 0 }
      } else {
        invalid_output = true
      }
    _ => invalid_output = true
  }
  if invalid_output {
    exr_throw_error(
      "THREE.EXRLoader: invalid output format for specified file.",
    )
  }
  // Luminance/chroma images always decode to RGBA; override whatever the output-format switch selected.
  if exr_decoder.y_cb_cr {
    exr_decoder.format = @core.RGBAFormat
    exr_decoder.output_channels = 4
    exr_decoder.decode_channels = { "Y": 0, "RY": 1, "BY": 2 }
    fill_alpha = true
  }
  if exr_decoder.type_ == 1 {
    // half
    match output_type {
      @core.FloatType => exr_decoder.getter = Some(exr_parse_float16)
      @core.HalfFloatType => exr_decoder.getter = Some(exr_parse_uint16_number)
      _ => ()
    }
  } else if exr_decoder.type_ == 2 {
    // float
    match output_type {
      @core.FloatType => exr_decoder.getter = Some(exr_parse_float32)
      @core.HalfFloatType => exr_decoder.getter = Some(exr_decode_float32)
      _ => ()
    }
  } else {
    exr_throw_error(
      "THREE.EXRLoader: unsupported pixelType " +
      exr_decoder.type_.to_string() +
      " for " +
      exr_header.compression() +
      ".",
    )
  }
  exr_decoder.columns = exr_decoder.width
  // JS numbers, so an absurd data window fails to allocate as upstream's does
  let size_number = exr_window_size(data_window.x_min, data_window.x_max) *
    exr_window_size(data_window.y_min, data_window.y_max) *
    exr_decoder.output_channels.to_double()
  let size = size_number.to_int()
  match output_type {
    @core.FloatType => {
      let byte_array = exr_new_typed("Float32Array", size_number)
      exr_decoder.byte_array = Some(byte_array)
      // Fill initially with 1s for the alpha value if the texture is not RGBA, RGB values will be overwritten
      if fill_alpha {
        exr_typed_fill(byte_array, 1, 0, size)
      }
    }
    @core.HalfFloatType => {
      let byte_array = exr_new_typed("Uint16Array", size_number)
      exr_decoder.byte_array = Some(byte_array)
      if fill_alpha {
        exr_typed_fill(byte_array, 0x3C00, 0, size) // Uint16Array holds half float data, 0x3C00 is 1
      }
    }
    _ => exr_console_error("THREE.EXRLoader: unsupported type: ", output_type)
  }
  let mut byte_offset = 0
  for channel in exr_header.channels() {
    if exr_decoder.decode_channels.contains(channel.name) {
      exr_decoder.channel_byte_offsets[channel.name] = byte_offset
    }
    byte_offset += channel.pixel_type * 2
  }
  exr_decoder.total_bytes = byte_offset
  exr_decoder.out_line_width = exr_decoder.width * exr_decoder.output_channels
  if exr_header.spec.deep_format {
    // Deep format: offset tables are already parsed in the main flow.
    // Compute per-channel byte sizes for the deep pixel data layout.
    exr_decoder.deep_channels = []
    let mut deep_bytes_per_sample = 0
    for channel in exr_header.channels() {
      // UINT=0→4bytes, HALF=1→2bytes, FLOAT=2→4bytes
      let bytes_per_sample = if channel.pixel_type == 0 {
        4
      } else {
        channel.pixel_type * 2
      }
      exr_decoder.deep_channels.push({
        name: channel.name,
        pixel_type: channel.pixel_type,
        bytes_per_sample,
      })
      deep_bytes_per_sample += bytes_per_sample
    }
    exr_decoder.deep_bytes_per_sample = deep_bytes_per_sample
    exr_decoder.chunk_offsets = exr_header.chunk_offsets.unwrap_or([])
    exr_decoder.multi_part = exr_header.spec.multi_part
    exr_decoder.decode = DeepScanline
  } else if exr_header.spec.single_tile {
    let tiles = exr_header.tiles()
    exr_decoder.block_height = tiles.y_size.to_int()
    exr_decoder.block_width = tiles.x_size.to_int()
    let num_x_levels = exr_calculate_tile_levels(
      tiles,
      exr_decoder.width,
      exr_decoder.height,
    )
    // const numYLevels = calculateTileLevels( EXRHeader.tiles, EXRDecoder.width, EXRDecoder.height );
    let num_x_tiles = exr_calculate_tiles(
      num_x_levels,
      exr_decoder.width,
      tiles.x_size,
      tiles.rounding_mode,
    )
    let num_y_tiles = exr_calculate_tiles(
      num_x_levels,
      exr_decoder.height,
      tiles.y_size,
      tiles.rounding_mode,
    )
    exr_decoder.tile_count = num_x_tiles.get(0).unwrap_or(0) *
      num_y_tiles.get(0).unwrap_or(0)
    let mut l = 0
    while l.to_double() < num_x_levels {
      for y in 0..<num_y_tiles[l] {
        ignore(y)
        for x in 0..<num_x_tiles[l] {
          ignore(x)
          ignore(exr_parse_int64(data_view, offset)) // tileOffset
        }
      }
      l += 1
    }
    exr_decoder.decode = Tiles
  } else if exr_header.spec.multi_part {
    // Multi-part scanline: offsets already parsed in main flow.
    exr_decoder.block_width = exr_decoder.width
    exr_decoder.chunk_offsets = exr_header.chunk_offsets.unwrap_or([])
    exr_decoder.decode = MultiPartScanline
  } else {
    exr_decoder.block_width = exr_decoder.width
    let block_count = exr_math_ceil(
      exr_decoder.height.to_double() / exr_decoder.block_height.to_double(),
    )
    let mut i = 0
    while i.to_double() < block_count {
      ignore(exr_parse_int64(data_view, offset)) // scanlineOffset
      i += 1
    }
    exr_decoder.decode = Scanline
  }
  exr_decoder
}

///|
fn ExrParse::decode(self : ExrParse, decoder : ExrDecoder) -> Unit {
  match decoder.decode {
    Scanline => self.parse_scanline(decoder)
    Tiles => self.parse_tiles(decoder)
    MultiPartScanline => self.parse_multi_part_scanline(decoder)
    DeepScanline => self.parse_deep_scanline(decoder)
  }
}

///|
extern "js" fn exr_tex_extra(header : @core.JsValue) -> @core.JsValue = "(h) => ({ header: h })"

///|
/// Parses EXR data (an `ArrayBuffer`). Throws upstream's errors.
pub fn EXRLoader::parse(
  self : EXRLoader,
  buffer : @core.JsValue,
) -> @loaders.DataTexData {
  let state = ExrParse::new()
  // start parsing file [START]
  let offset = Ref(0)
  let buffer_data_view = exr_data_view_from_js(buffer)
  let u_int8_array = exr_new_uint8_from_buffer(buffer)
  let array_buffer = buffer_data_view.buffer()
  // get header information and validate format.
  let exr_headers = exr_parse_header(buffer_data_view, array_buffer, offset)
  // select part to decode
  let part_index = exr_math_max(
    0.0,
    exr_math_min(self.part.to_double(), (exr_headers.length() - 1).to_double()),
  ).to_int()
  let exr_header = exr_headers[part_index]
  state.header = Some(exr_header)
  // for multi-part deep files, skip offset tables for other parts
  if exr_header.spec.multi_part || exr_header.spec.deep_format {
    for p in 0..<exr_headers.length() {
      let chunk_count = exr_headers[p].chunk_count()
      if p == part_index {
        // store offset table for the selected part
        let offsets = []
        exr_header.chunk_offsets = Some(offsets)
        let mut i = 0
        while i.to_double() < chunk_count {
          offsets.push(exr_parse_int64(buffer_data_view, offset))
          i += 1
        }
      } else {
        // skip other parts' offset tables
        let mut i = 0
        while i.to_double() < chunk_count {
          ignore(exr_parse_int64(buffer_data_view, offset))
          i += 1
        }
      }
    }
  }
  // get input compression information and prepare decoding.
  let exr_decoder = state.setup_decoder(
    exr_header,
    buffer_data_view,
    u_int8_array,
    offset,
    self.type_,
    self.output_format,
  )
  // parse input data
  state.decode(exr_decoder)
  // output texture post-processing
  if exr_decoder.should_expand && exr_decoder.byte_array is Some(byte_array) {
    if self.output_format == @core.RGBAFormat {
      let mut i = 0
      while i < byte_array.length() {
        byte_array[i + 1] = byte_array[i]
        byte_array[i + 2] = byte_array[i + 1]
        i += 4
      }
    } else if self.output_format == @core.RGFormat {
      let mut i = 0
      while i < byte_array.length() {
        byte_array[i + 1] = byte_array[i]
        i += 2
      }
    }
  }
  // Luminance/chroma → RGB conversion (second pass).
  // Y/RY/BY were decoded into output slots 0/1/2; convert in-place using Rec.709 coefficients:
  //   R = ( 1 + RY ) * Y,  B = ( 1 + BY ) * Y,  G = ( Y − R·0.2126 − B·0.0722 ) / 0.7152
  if exr_decoder.y_cb_cr && exr_decoder.byte_array is Some(byte_array) {
    let n_pixels = exr_decoder.width * exr_decoder.height
    if self.type_ == @core.HalfFloatType {
      for i in 0..<n_pixels {
        let base = i * 4
        let y = @core.from_half_float(byte_array[base])
        let ry = @core.from_half_float(byte_array[base + 1])
        let by = @core.from_half_float(byte_array[base + 2])
        let r = (1.0 + ry) * y
        let b = (1.0 + by) * y
        let g = (y - r * 0.2126 - b * 0.0722) / 0.7152
        byte_array[base] = @core.to_half_float(exr_math_max(0, r))
        byte_array[base + 1] = @core.to_half_float(exr_math_max(0, g))
        byte_array[base + 2] = @core.to_half_float(exr_math_max(0, b))
      }
    } else {
      for i in 0..<n_pixels {
        let base = i * 4
        let y = byte_array[base]
        let ry = byte_array[base + 1]
        let by = byte_array[base + 2]
        let r = (1.0 + ry) * y
        let b = (1.0 + by) * y
        byte_array[base] = exr_math_max(0, r)
        byte_array[base + 1] = exr_math_max(
          0,
          (y - r * 0.2126 - b * 0.0722) / 0.7152,
        )
        byte_array[base + 2] = exr_math_max(0, b)
      }
    }
  }
  let tex_data = @loaders.DataTexData::new()
  tex_data.extra = Some(exr_tex_extra(exr_header.to_js()))
  tex_data.width = Some(exr_decoder.width)
  tex_data.height = Some(exr_decoder.height)
  tex_data.data = exr_decoder.byte_array
  tex_data.format = Some(exr_decoder.format)
  tex_data.color_space = Some(exr_decoder.color_space)
  tex_data.type_ = Some(self.type_)
  tex_data.min_filter = Some(@core.LinearFilter)
  tex_data.mag_filter = Some(@core.LinearFilter)
  tex_data.generate_mipmaps = Some(false)
  tex_data.flip_y = Some(false)
  tex_data
}
