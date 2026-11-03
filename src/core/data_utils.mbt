// Half-float conversion from upstream src/extras/DataUtils.js. It lives in `core`
// because Float16BufferAttribute needs it and `extras` sits above `core`.

///|
priv struct HalfFloatTables {
  float_view : TypedArray
  uint32_view : TypedArray
  base_table : TypedArray
  shift_table : TypedArray
  mantissa_table : TypedArray
  exponent_table : TypedArray
  offset_table : TypedArray
}

///|
let _data_utils_tables : HalfFloatTables = data_utils_generate_tables()

///|
fn data_utils_generate_tables() -> HalfFloatTables {
  // float32 to float16 helpers
  let buffer = ArrayBuffer::new(4)
  let float_view = TypedArray::view_by_name("Float32Array", buffer)
  let uint32_view = TypedArray::view_by_name("Uint32Array", buffer)
  let base_table = TypedArray::uint32(512)
  let shift_table = TypedArray::uint32(512)
  for i in 0..<256 {
    let e = i - 127
    if e < -27 {
      // very small number (0, -0)
      base_table[i] = 0x0000
      base_table[i | 0x100] = 0x8000
      shift_table[i] = 24
      shift_table[i | 0x100] = 24
    } else if e < -14 {
      // small number (denorm)
      base_table[i] = (0x0400 >> (-e - 14)).to_double()
      base_table[i | 0x100] = ((0x0400 >> (-e - 14)) | 0x8000).to_double()
      shift_table[i] = (-e - 1).to_double()
      shift_table[i | 0x100] = (-e - 1).to_double()
    } else if e <= 15 {
      // normal number
      base_table[i] = ((e + 15) << 10).to_double()
      base_table[i | 0x100] = (((e + 15) << 10) | 0x8000).to_double()
      shift_table[i] = 13
      shift_table[i | 0x100] = 13
    } else if e < 128 {
      // large number (Infinity, -Infinity)
      base_table[i] = 0x7c00
      base_table[i | 0x100] = 0xfc00
      shift_table[i] = 24
      shift_table[i | 0x100] = 24
    } else {
      // stay (NaN, Infinity, -Infinity)
      base_table[i] = 0x7c00
      base_table[i | 0x100] = 0xfc00
      shift_table[i] = 13
      shift_table[i | 0x100] = 13
    }
  }
  // float16 to float32 helpers
  let mantissa_table = TypedArray::uint32(2048)
  let exponent_table = TypedArray::uint32(64)
  let offset_table = TypedArray::uint32(64)
  for i in 1..<1024 {
    let mut m = i << 13 // zero pad mantissa bits
    let mut e = 0 // zero exponent
    // normalized
    while (m & 0x00800000) == 0 {
      m = m << 1
      e = e - 0x00800000 // decrement exponent
    }
    m = m & (0x00800000).lnot() // clear leading 1 bit
    e = e + 0x38800000 // adjust bias
    mantissa_table[i] = (m | e).to_double()
  }
  for i in 1024..<2048 {
    mantissa_table[i] = (0x38000000 + ((i - 1024) << 13)).to_double()
  }
  for i in 1..<31 {
    exponent_table[i] = (i << 23).to_double()
  }
  exponent_table[31] = 0x47800000
  exponent_table[32] = 2147483648.0 // 0x80000000
  for i in 33..<63 {
    exponent_table[i] = 2147483648.0 + ((i - 32) << 23).to_double()
  }
  exponent_table[63] = 3347054592.0 // 0xc7800000
  for i in 1..<64 {
    if i != 32 {
      offset_table[i] = 1024
    }
  }
  {
    float_view,
    uint32_view,
    base_table,
    shift_table,
    mantissa_table,
    exponent_table,
    offset_table,
  }
}

///|
extern "js" fn data_utils_half_from_bits(
  f : Double,
  base_table : TypedArray,
  shift_table : TypedArray,
) -> Double =
  #|(f, base, shift) => {
  #|  const e = ( f >> 23 ) & 0x1ff;
  #|  return base[ e ] + ( ( f & 0x007fffff ) >> shift[ e ] );
  #|}

///|
extern "js" fn data_utils_bits_from_half(
  val : Double,
  mantissa_table : TypedArray,
  offset_table : TypedArray,
  exponent_table : TypedArray,
) -> Double =
  #|(val, mantissa, offset, exponent) => {
  #|  const m = val >> 10;
  #|  return mantissa[ offset[ m ] + ( val & 0x3ff ) ] + exponent[ m ];
  #|}

///|
/// Returns the half float bits of `val`.
pub fn to_half_float(val : Double) -> Double {
  if val.abs() > 65504.0 {
    warn("DataUtils.toHalfFloat(): Value out of range.")
  }
  let tables = _data_utils_tables
  tables.float_view[0] = @math.clamp(val, -65504.0, 65504.0)
  data_utils_half_from_bits(
    tables.uint32_view[0],
    tables.base_table,
    tables.shift_table,
  )
}

///|
/// Returns the number encoded by the half float bits `val`.
pub fn from_half_float(val : Double) -> Double {
  let tables = _data_utils_tables
  tables.uint32_view[0] = data_utils_bits_from_half(
    val,
    tables.mantissa_table,
    tables.offset_table,
    tables.exponent_table,
  )
  tables.float_view[0]
}
