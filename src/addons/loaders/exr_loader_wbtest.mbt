// Tests parse tiny EXR files (written by the a3_hdr harness's tiny.mjs; the ZIPS, PIZ and
// B44 ones re-encoded by OpenEXR's exrmetrics) against upstream's decoded values.

///|
fn exr_test_buffer(bytes : Array[Int32]) -> @core.JsValue {
  @core.JsValue::of(@core.TypedArray::uint8(bytes).buffer())
}

///|
extern "js" fn exr_test_try(f : () -> Unit) -> String = "(f) => { try { f(); return 'ok'; } catch (e) { return e.name + ': ' + e.message; } }"

///|
let exr_test_none : Array[Int32] = [
  118, 47, 49, 1, 2, 0, 0, 0, 99, 104, 97, 110, 110, 101, 108, 115, 0, 99, 104, 108,
  105, 115, 116, 0, 55, 0, 0, 0, 66, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0,
  0, 0, 71, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 82, 0, 1, 0, 0, 0,
  0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105,
  111, 110, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105, 111, 110, 0, 1, 0, 0,
  0, 0, 100, 97, 116, 97, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105,
  0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 100, 105, 115,
  112, 108, 97, 121, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105, 0, 16,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 108, 105, 110, 101, 79,
  114, 100, 101, 114, 0, 108, 105, 110, 101, 79, 114, 100, 101, 114, 0, 1, 0, 0,
  0, 0, 0, 231, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 18, 0, 0,
  0, 0, 60, 0, 64, 0, 56, 0, 56, 1, 0, 255, 123, 255, 123, 0, 188, 85, 53, 1, 0,
  0, 0, 18, 0, 0, 0, 1, 0, 255, 123, 0, 188, 0, 188, 85, 53, 0, 0, 0, 0, 0, 68, 0,
  60,
]

///|
let exr_test_zips : Array[Int32] = [
  118, 47, 49, 1, 2, 0, 0, 0, 99, 104, 97, 110, 110, 101, 108, 115, 0, 99, 104, 108,
  105, 115, 116, 0, 55, 0, 0, 0, 66, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0,
  0, 0, 71, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 82, 0, 1, 0, 0, 0,
  0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105,
  111, 110, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105, 111, 110, 0, 1, 0, 0,
  0, 2, 100, 97, 116, 97, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105,
  0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 100, 105, 115,
  112, 108, 97, 121, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105, 0, 16,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 108, 105, 110, 101, 79,
  114, 100, 101, 114, 0, 108, 105, 110, 101, 79, 114, 100, 101, 114, 0, 1, 0, 0,
  0, 0, 112, 105, 120, 101, 108, 65, 115, 112, 101, 99, 116, 82, 97, 116, 105, 111,
  0, 102, 108, 111, 97, 116, 0, 4, 0, 0, 0, 0, 0, 128, 63, 115, 99, 114, 101, 101,
  110, 87, 105, 110, 100, 111, 119, 67, 101, 110, 116, 101, 114, 0, 118, 50, 102,
  0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 115, 99, 114, 101, 101, 110, 87, 105, 110,
  100, 111, 119, 87, 105, 100, 116, 104, 0, 102, 108, 111, 97, 116, 0, 4, 0, 0, 0,
  0, 0, 128, 63, 116, 121, 112, 101, 0, 115, 116, 114, 105, 110, 103, 0, 13, 0, 0,
  0, 115, 99, 97, 110, 108, 105, 110, 101, 105, 109, 97, 103, 101, 0, 102, 1, 0,
  0, 0, 0, 0, 0, 128, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 18, 0, 0, 0, 0, 60, 0, 64,
  0, 56, 0, 56, 1, 0, 255, 123, 255, 123, 0, 188, 85, 53, 1, 0, 0, 0, 18, 0, 0, 0,
  1, 0, 255, 123, 0, 188, 0, 188, 85, 53, 0, 0, 0, 0, 0, 68, 0, 60,
]

///|
let exr_test_piz : Array[Int32] = [
  118, 47, 49, 1, 2, 0, 0, 0, 99, 104, 97, 110, 110, 101, 108, 115, 0, 99, 104, 108,
  105, 115, 116, 0, 55, 0, 0, 0, 66, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0,
  0, 0, 71, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 82, 0, 1, 0, 0, 0,
  0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105,
  111, 110, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105, 111, 110, 0, 1, 0, 0,
  0, 4, 100, 97, 116, 97, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105,
  0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 100, 105, 115,
  112, 108, 97, 121, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105, 0, 16,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 108, 105, 110, 101, 79,
  114, 100, 101, 114, 0, 108, 105, 110, 101, 79, 114, 100, 101, 114, 0, 1, 0, 0,
  0, 0, 112, 105, 120, 101, 108, 65, 115, 112, 101, 99, 116, 82, 97, 116, 105, 111,
  0, 102, 108, 111, 97, 116, 0, 4, 0, 0, 0, 0, 0, 128, 63, 115, 99, 114, 101, 101,
  110, 87, 105, 110, 100, 111, 119, 67, 101, 110, 116, 101, 114, 0, 118, 50, 102,
  0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 115, 99, 114, 101, 101, 110, 87, 105, 110,
  100, 111, 119, 87, 105, 100, 116, 104, 0, 102, 108, 111, 97, 116, 0, 4, 0, 0, 0,
  0, 0, 128, 63, 116, 121, 112, 101, 0, 115, 116, 114, 105, 110, 103, 0, 13, 0, 0,
  0, 115, 99, 97, 110, 108, 105, 110, 101, 105, 109, 97, 103, 101, 0, 94, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 36, 0, 0, 0, 0, 60, 0, 64, 0, 56, 0, 56, 1, 0, 255, 123,
  255, 123, 0, 188, 85, 53, 1, 0, 255, 123, 0, 188, 0, 188, 85, 53, 0, 0, 0, 0, 0,
  68, 0, 60,
]

///|
let exr_test_b44 : Array[Int32] = [
  118, 47, 49, 1, 2, 0, 0, 0, 99, 104, 97, 110, 110, 101, 108, 115, 0, 99, 104, 108,
  105, 115, 116, 0, 55, 0, 0, 0, 66, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0,
  0, 0, 71, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 82, 0, 1, 0, 0, 0,
  0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105,
  111, 110, 0, 99, 111, 109, 112, 114, 101, 115, 115, 105, 111, 110, 0, 1, 0, 0,
  0, 6, 100, 97, 116, 97, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105,
  0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 100, 105, 115,
  112, 108, 97, 121, 87, 105, 110, 100, 111, 119, 0, 98, 111, 120, 50, 105, 0, 16,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 108, 105, 110, 101, 79,
  114, 100, 101, 114, 0, 108, 105, 110, 101, 79, 114, 100, 101, 114, 0, 1, 0, 0,
  0, 0, 112, 105, 120, 101, 108, 65, 115, 112, 101, 99, 116, 82, 97, 116, 105, 111,
  0, 102, 108, 111, 97, 116, 0, 4, 0, 0, 0, 0, 0, 128, 63, 115, 99, 114, 101, 101,
  110, 87, 105, 110, 100, 111, 119, 67, 101, 110, 116, 101, 114, 0, 118, 50, 102,
  0, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 115, 99, 114, 101, 101, 110, 87, 105, 110,
  100, 111, 119, 87, 105, 100, 116, 104, 0, 102, 108, 111, 97, 116, 0, 4, 0, 0, 0,
  0, 0, 128, 63, 116, 121, 112, 101, 0, 115, 116, 114, 105, 110, 103, 0, 13, 0, 0,
  0, 115, 99, 97, 110, 108, 105, 110, 101, 105, 109, 97, 103, 101, 0, 94, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 36, 0, 0, 0, 0, 60, 0, 64, 0, 56, 0, 56, 1, 0, 255, 123,
  255, 123, 0, 188, 85, 53, 1, 0, 255, 123, 0, 188, 0, 188, 85, 53, 0, 0, 0, 0, 0,
  68, 0, 60,
]

///|
let exr_test_half : Array[Double] = [
  0.0, 48128.0, 1.0, 15360.0, 17408.0, 13653.0, 31743.0, 15360.0, 15360.0, 0.0, 48128.0,
  15360.0, 31743.0, 14336.0, 15360.0, 15360.0, 48128.0, 1.0, 16384.0, 15360.0, 13653.0,
  31743.0, 14336.0, 15360.0,
]

///|
let exr_test_float_rg : Array[Double] = [
  0.0, -1.0, 4.0, 0.333251953125, 1.0, 0.0, 65504.0, 0.5, -1.0, 5.960464477539063e-08,
  0.333251953125, 65504.0,
]

///|
test "EXRLoader parses NONE as upstream" {
  let half = EXRLoader::new().parse(exr_test_buffer(exr_test_none))
  assert_eq(half.width, Some(3))
  assert_eq(half.height, Some(2))
  assert_eq(half.format, Some(@core.RGBAFormat))
  assert_eq(half.type_, Some(@core.HalfFloatType))
  assert_eq(half.flip_y, Some(false))
  assert_eq(half.data.unwrap().type_name(), "Uint16Array")
  assert_eq(half.data.unwrap().to_array(), exr_test_half)
  let rg = EXRLoader::new()
    .set_data_type(@core.FloatType)
    .set_output_format(@core.RGFormat)
    .parse(exr_test_buffer(exr_test_none))
  assert_eq(rg.format, Some(@core.RGFormat))
  assert_eq(rg.data.unwrap().to_array(), exr_test_float_rg)
}

///|
test "EXRLoader parses ZIPS as upstream" {
  let half = EXRLoader::new().parse(exr_test_buffer(exr_test_zips))
  assert_eq(half.width, Some(3))
  assert_eq(half.height, Some(2))
  assert_eq(half.format, Some(@core.RGBAFormat))
  assert_eq(half.type_, Some(@core.HalfFloatType))
  assert_eq(half.flip_y, Some(false))
  assert_eq(half.data.unwrap().type_name(), "Uint16Array")
  assert_eq(half.data.unwrap().to_array(), exr_test_half)
  let rg = EXRLoader::new()
    .set_data_type(@core.FloatType)
    .set_output_format(@core.RGFormat)
    .parse(exr_test_buffer(exr_test_zips))
  assert_eq(rg.format, Some(@core.RGFormat))
  assert_eq(rg.data.unwrap().to_array(), exr_test_float_rg)
}

///|
test "EXRLoader parses PIZ as upstream" {
  let half = EXRLoader::new().parse(exr_test_buffer(exr_test_piz))
  assert_eq(half.width, Some(3))
  assert_eq(half.height, Some(2))
  assert_eq(half.format, Some(@core.RGBAFormat))
  assert_eq(half.type_, Some(@core.HalfFloatType))
  assert_eq(half.flip_y, Some(false))
  assert_eq(half.data.unwrap().type_name(), "Uint16Array")
  assert_eq(half.data.unwrap().to_array(), exr_test_half)
  let rg = EXRLoader::new()
    .set_data_type(@core.FloatType)
    .set_output_format(@core.RGFormat)
    .parse(exr_test_buffer(exr_test_piz))
  assert_eq(rg.format, Some(@core.RGFormat))
  assert_eq(rg.data.unwrap().to_array(), exr_test_float_rg)
}

///|
test "EXRLoader parses B44 as upstream" {
  let half = EXRLoader::new().parse(exr_test_buffer(exr_test_b44))
  assert_eq(half.width, Some(3))
  assert_eq(half.height, Some(2))
  assert_eq(half.format, Some(@core.RGBAFormat))
  assert_eq(half.type_, Some(@core.HalfFloatType))
  assert_eq(half.flip_y, Some(false))
  assert_eq(half.data.unwrap().type_name(), "Uint16Array")
  assert_eq(half.data.unwrap().to_array(), exr_test_half)
  let rg = EXRLoader::new()
    .set_data_type(@core.FloatType)
    .set_output_format(@core.RGFormat)
    .parse(exr_test_buffer(exr_test_b44))
  assert_eq(rg.format, Some(@core.RGFormat))
  assert_eq(rg.data.unwrap().to_array(), exr_test_float_rg)
}

///|
test "EXRLoader throws upstream's errors" {
  let bad = exr_test_none.copy()
  bad[0] = 0
  assert_eq(
    exr_test_try(() => ignore(EXRLoader::new().parse(exr_test_buffer(bad)))),
    "Error: THREE.EXRLoader: Provided file doesn't appear to be in OpenEXR format.",
  )
  assert_eq(
    exr_test_try(() => ignore(EXRLoader::new().parse(exr_test_buffer([1, 2])))),
    "RangeError: Offset is outside the bounds of the DataView",
  )
  assert_eq(
    exr_test_try(() => {
      ignore(
        EXRLoader::new()
        .set_output_format(@core.RGBFormat)
        .parse(exr_test_buffer(exr_test_none)),
      )
    }),
    "Error: THREE.EXRLoader: invalid output format for specified file.",
  )
}
