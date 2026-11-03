// Tests for upstream src/renderers/shaders/DFGLUTData.js. Upstream has none.

///|
test "getDFGLUT settings" {
  let lut = @shaders.get_dfg_lut()
  assert_eq(lut.name, "DFG_LUT")
  assert_eq(lut.format, @core.RGFormat)
  assert_eq(lut.type_, @core.HalfFloatType)
  assert_eq(lut.min_filter, @core.LinearFilter)
  assert_eq(lut.mag_filter, @core.LinearFilter)
  assert_eq(lut.wrap_s, @core.ClampToEdgeWrapping)
  assert_eq(lut.wrap_t, @core.ClampToEdgeWrapping)
  assert_eq(lut.generate_mipmaps, false)
  assert_eq(lut.version, 1)
}

///|
test "getDFGLUT data" {
  guard @shaders.get_dfg_lut().image() is DataImage(image) else {
    fail("image")
  }
  assert_eq(image.width, 16)
  assert_eq(image.height, 16)
  guard image.data is Some(data) else { fail("data") }
  assert_eq(data.type_name(), "Uint16Array")
  assert_eq(data.length(), 512)
  assert_eq(data.get_int(0), 0x30b5)
  assert_eq(data.get_int(511), 0x049f)
}

///|
test "getDFGLUT returns one texture" {
  assert_true(physical_equal(@shaders.get_dfg_lut(), @shaders.get_dfg_lut()))
}
