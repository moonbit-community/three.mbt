///|
const COLOR_TEST_EPS : Double = 0.0001

///|
/// `Color::new( 1, 1, 1 )`, upstream's `new Color()`.
fn color_test_white() -> @math.Color {
  @math.Color::new(1.0, 1.0, 1.0)
}

///|
/// Upstream's `0xNN / 255`.
fn color_test_byte(value : Int32) -> Double {
  value.to_double() / 255.0
}

///|
/// Upstream's `assert.numEqual`.
fn color_test_num_equal(actual : Double, expected : Double) -> Bool {
  (actual - expected).abs() < 0.1
}

///|
/// Upstream's test setup; `color_test_enable_management` is its `testDone`.
fn color_test_disable_management() -> Unit {
  @math.color_management.enabled = false
}

///|
fn color_test_enable_management() -> Unit {
  @math.color_management.enabled = true
}

///|
extern "js" fn color_test_to_fixed3(x : Double) -> String =
  #|(x) => x.toFixed(3)

///|
test "Color: Instancing" {
  color_test_disable_management()
  defer color_test_enable_management()

  // default ctor
  let c = color_test_white()
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 1.0)
  assert_eq(c.b, 1.0)

  // rgb ctor
  let c = @math.Color::new(1.0, 1.0, 1.0)
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 1.0)
  assert_eq(c.b, 1.0)
}

///|
test "Color: Color.NAMES" {
  assert_eq(@math.color_names.get("aliceblue"), Some(0xF0F8FF))
  assert_eq(@math.color_names.length(), 148)
}

///|
test "Color: set" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = color_test_white()
  let b = @math.Color::new(0.5, 0.0, 0.0)
  let c = @math.Color::from_hex(0xFF0000)
  let d = @math.Color::new(0.0, 1.0, 0.0)
  let e = @math.Color::new(0.5, 0.5, 0.5)
  ignore(a.copy(b))
  assert_true(a.equals(b))
  ignore(a.set_hex(0xFF0000))
  assert_true(a.equals(c))
  ignore(a.set_style("rgb(0,255,0)"))
  assert_true(a.equals(d))
  ignore(a.set(0.5, 0.5, 0.5))
  assert_true(a.equals(e))
}

///|
test "Color: setScalar" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_scalar(0.5))
  assert_eq(c.r, 0.5)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.5)
}

///|
test "Color: setHex" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_hex(0xFA8072))
  assert_eq(c.get_hex(), 0xFA8072)
  assert_eq(c.r, color_test_byte(0xFA))
  assert_eq(c.g, color_test_byte(0x80))
  assert_eq(c.b, color_test_byte(0x72))
}

///|
test "Color: setRGB" {
  @math.color_management.enabled = true
  let c = color_test_white()
  ignore(c.set_rgb(0.3, 0.5, 0.7))
  assert_eq(c.r, 0.3)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.7)
  ignore(c.set_rgb(0.3, 0.5, 0.7, color_space=@math.SRGBColorSpace))
  assert_eq(color_test_to_fixed3(c.r), "0.073")
  assert_eq(color_test_to_fixed3(c.g), "0.214")
  assert_eq(color_test_to_fixed3(c.b), "0.448")
}

///|
test "Color: setHSL" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let hsl = @math.Hsl::new(0.0, 0.0, 0.0)
  ignore(c.set_hsl(0.75, 1.0, 0.25))
  ignore(c.get_hsl(hsl))
  assert_eq(hsl.h, 0.75)
  assert_eq(hsl.s, 1.00)
  assert_eq(hsl.l, 0.25)
}

///|
test "Color: setStyle" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = color_test_white()
  let b = @math.Color::new(8.0 / 255.0, 25.0 / 255.0, 178.0 / 255.0)
  ignore(a.set_style("rgb(8,25,178)"))
  assert_true(a.equals(b))
  let b = @math.Color::new(8.0 / 255.0, 25.0 / 255.0, 178.0 / 255.0)
  ignore(a.set_style("rgba(8,25,178,200)"))
  assert_true(a.equals(b))
  let hsl = @math.Hsl::new(0.0, 0.0, 0.0)
  ignore(a.set_style("hsl(270,50%,75%)"))
  ignore(a.get_hsl(hsl))
  assert_eq(hsl.h, 0.75)
  assert_eq(hsl.s, 0.5)
  assert_eq(hsl.l, 0.75)
  let hsl = @math.Hsl::new(0.0, 0.0, 0.0)
  ignore(a.set_style("hsl(270,50%,75%)"))
  ignore(a.get_hsl(hsl))
  assert_eq(hsl.h, 0.75)
  assert_eq(hsl.s, 0.5)
  assert_eq(hsl.l, 0.75)
  ignore(a.set_style("#F8A"))
  assert_eq(a.r, color_test_byte(0xFF))
  assert_eq(a.g, color_test_byte(0x88))
  assert_eq(a.b, color_test_byte(0xAA))
  ignore(a.set_style("#F8ABC1"))
  assert_eq(a.r, color_test_byte(0xF8))
  assert_eq(a.g, color_test_byte(0xAB))
  assert_eq(a.b, color_test_byte(0xC1))
  ignore(a.set_style("aliceblue"))
  assert_eq(a.r, color_test_byte(0xF0))
  assert_eq(a.g, color_test_byte(0xF8))
  assert_eq(a.b, color_test_byte(0xFF))
}

///|
test "Color: setColorName" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let res = c.set_color_name("aliceblue")
  assert_eq(c.get_hex(), 0xF0F8FF)
  assert_true(physical_equal(c, res))
}

///|
test "Color: clone" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = @math.Color::from_style("teal")
  let c2 = c.clone()
  assert_eq(c2.get_hex(), 0x008080)
}

///|
test "Color: copy" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::from_style("teal")
  let b = color_test_white()
  ignore(b.copy(a))
  assert_eq(b.r, color_test_byte(0x00))
  assert_eq(b.g, color_test_byte(0x80))
  assert_eq(b.b, color_test_byte(0x80))
}

///|
test "Color: copySRGBToLinear" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let c2 = color_test_white()
  ignore(c2.set_rgb(0.3, 0.5, 0.9))
  ignore(c.copy_srgb_to_linear(c2))
  assert_true(color_test_num_equal(c.r, 0.09))
  assert_true(color_test_num_equal(c.g, 0.25))
  assert_true(color_test_num_equal(c.b, 0.81))
}

///|
test "Color: copyLinearToSRGB" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let c2 = color_test_white()
  ignore(c2.set_rgb(0.09, 0.25, 0.81))
  ignore(c.copy_linear_to_srgb(c2))
  assert_true(color_test_num_equal(c.r, 0.3))
  assert_true(color_test_num_equal(c.g, 0.5))
  assert_true(color_test_num_equal(c.b, 0.9))
}

///|
test "Color: convertSRGBToLinear" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_rgb(0.3, 0.5, 0.9))
  ignore(c.convert_srgb_to_linear())
  assert_true(color_test_num_equal(c.r, 0.09))
  assert_true(color_test_num_equal(c.g, 0.25))
  assert_true(color_test_num_equal(c.b, 0.81))
}

///|
test "Color: convertLinearToSRGB" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_rgb(4.0, 9.0, 16.0))
  ignore(c.convert_linear_to_srgb())
  assert_true(color_test_num_equal(c.r, 1.82))
  assert_true(color_test_num_equal(c.g, 2.58))
  assert_true(color_test_num_equal(c.b, 3.29))
}

///|
test "Color: getHex" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = @math.Color::from_style("red")
  let res = c.get_hex()
  assert_eq(res, 0xFF0000)
}

///|
test "Color: getHexString" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = @math.Color::from_style("tomato")
  let res = c.get_hex_string()
  assert_eq(res, "ff6347")
}

///|
test "Color: getHSL" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = @math.Color::from_hex(0x80ffff)
  let hsl = @math.Hsl::new(0.0, 0.0, 0.0)
  ignore(c.get_hsl(hsl))
  assert_eq(hsl.h, 0.5)
  assert_eq(hsl.s, 1.0)
  assert_eq((hsl.l * 100.0).round() / 100.0, 0.75)
}

///|
test "Color: getRGB" {
  @math.color_management.enabled = true
  let c = @math.Color::from_style("plum")
  let t = @math.Color::new(0.0, 0.0, 0.0)
  ignore(c.get_rgb(t))
  assert_eq(color_test_to_fixed3(t.r), "0.723")
  assert_eq(color_test_to_fixed3(t.g), "0.352")
  assert_eq(color_test_to_fixed3(t.b), "0.723")
  ignore(c.get_rgb(t, color_space=@math.SRGBColorSpace))
  assert_eq(color_test_to_fixed3(t.r), color_test_to_fixed3(221.0 / 255.0))
  assert_eq(color_test_to_fixed3(t.g), color_test_to_fixed3(160.0 / 255.0))
  assert_eq(color_test_to_fixed3(t.b), color_test_to_fixed3(221.0 / 255.0))
}

///|
test "Color: getStyle" {
  @math.color_management.enabled = true
  let c = @math.Color::from_style("plum")
  assert_eq(c.get_style(), "rgb(221,160,221)")
}

///|
test "Color: offsetHSL" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::from_style("hsl(120,50%,50%)")
  let b = @math.Color::new(0.36, 0.84, 0.648)
  ignore(a.offset_hsl(0.1, 0.1, 0.1))
  assert_true((a.r - b.r).abs() <= COLOR_TEST_EPS)
  assert_true((a.g - b.g).abs() <= COLOR_TEST_EPS)
  assert_true((a.b - b.b).abs() <= COLOR_TEST_EPS)
}

///|
test "Color: add" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::from_hex(0x0000FF)
  let b = @math.Color::from_hex(0xFF0000)
  let c = @math.Color::from_hex(0xFF00FF)
  ignore(a.add(b))
  assert_true(a.equals(c))
}

///|
test "Color: addColors" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::from_hex(0x0000FF)
  let b = @math.Color::from_hex(0xFF0000)
  let c = @math.Color::from_hex(0xFF00FF)
  let d = color_test_white()
  ignore(d.add_colors(a, b))
  assert_true(d.equals(c))
}

///|
test "Color: addScalar" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::new(0.1, 0.0, 0.0)
  let b = @math.Color::new(0.6, 0.5, 0.5)
  ignore(a.add_scalar(0.5))
  assert_true(a.equals(b))
}

///|
test "Color: sub" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::from_hex(0x0000CC)
  let b = @math.Color::from_hex(0xFF0000)
  let c = @math.Color::from_hex(0x0000AA)
  ignore(a.sub(b))
  assert_eq(a.get_hex(), 0xCC)
  ignore(a.sub(c))
  assert_eq(a.get_hex(), 0x22)
}

///|
test "Color: multiply" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::new(1.0, 0.0, 0.5)
  let b = @math.Color::new(0.5, 1.0, 0.5)
  let c = @math.Color::new(0.5, 0.0, 0.25)
  ignore(a.multiply(b))
  assert_true(a.equals(c))
}

///|
test "Color: multiplyScalar" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::new(0.25, 0.0, 0.5)
  let b = @math.Color::new(0.5, 0.0, 1.0)
  ignore(a.multiply_scalar(2.0))
  assert_true(a.equals(b))
}

///|
test "Color: lerp" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let c2 = color_test_white()
  ignore(c.set_rgb(0.0, 0.0, 0.0))
  ignore(c.lerp(c2, 0.2))
  assert_eq(c.r, 0.2)
  assert_eq(c.g, 0.2)
  assert_eq(c.b, 0.2)
}

///|
test "Color: equals" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::new(0.5, 0.0, 1.0)
  let b = @math.Color::new(0.5, 1.0, 0.0)
  assert_eq(a.r, b.r)
  assert_not_eq(a.g, b.g)
  assert_not_eq(a.b, b.b)
  assert_false(a.equals(b))
  assert_false(b.equals(a))
  ignore(a.copy(b))
  assert_eq(a.r, b.r)
  assert_eq(a.g, b.g)
  assert_eq(a.b, b.b)
  assert_true(a.equals(b))
  assert_true(b.equals(a))
}

///|
test "Color: fromArray" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = color_test_white()
  let array = [0.5, 0.6, 0.7, 0.0, 1.0, 0.0]
  ignore(a.from_array(array))
  assert_eq(a.r, 0.5)
  assert_eq(a.g, 0.6)
  assert_eq(a.b, 0.7)
  ignore(a.from_array(array, offset=3))
  assert_eq(a.r, 0.0)
  assert_eq(a.g, 1.0)
  assert_eq(a.b, 0.0)
}

///|
test "Color: toArray" {
  color_test_disable_management()
  defer color_test_enable_management()
  let r = 0.5
  let g = 1.0
  let b = 0.0
  let a = @math.Color::new(r, g, b)
  let array = a.to_array()
  assert_eq(array[0], r)
  assert_eq(array[1], g)
  assert_eq(array[2], b)
  let array = []
  ignore(a.to_array(array~))
  assert_eq(array[0], r)
  assert_eq(array[1], g)
  assert_eq(array[2], b)

  // upstream leaves array[ 0 ] undefined; Array[Double] holds 0.0
  let array = []
  ignore(a.to_array(array~, offset=1))
  assert_eq(array[0], 0.0)
  assert_eq(array[1], r)
  assert_eq(array[2], g)
  assert_eq(array[3], b)
}

///|
test "Color: toJSON" {
  color_test_disable_management()
  defer color_test_enable_management()
  let a = @math.Color::new(0.0, 0.0, 0.0)
  let b = @math.Color::new(0.0, 0.5, 0.0)
  let c = @math.Color::new(1.0, 0.0, 0.0)
  let d = @math.Color::new(1.0, 1.0, 1.0)
  assert_eq(a.to_json(), 0x000000)
  assert_eq(b.to_json(), 0x008000)
  assert_eq(c.to_json(), 0xFF0000)
  assert_eq(d.to_json(), 0xFFFFFF)
}

///|
test "Color: copyHex" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let c2 = @math.Color::from_hex(0xF5FFFA)
  ignore(c.copy(c2))
  assert_eq(c.get_hex(), c2.get_hex())
}

///|
test "Color: copyColorString" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  let c2 = @math.Color::from_style("ivory")
  ignore(c.copy(c2))
  assert_eq(c.get_hex(), c2.get_hex())
}

///|
test "Color: setWithNum" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_hex(0xFF0000))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setWithString" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("silver"))
  assert_eq(c.get_hex(), 0xC0C0C0)
}

///|
test "Color: setStyleRGBRed" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgb(255,0,0)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleRGBARed" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgba(255,0,0,0.5)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleRGBRedWithSpaces" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgb( 255 , 0,   0 )"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleRGBARedWithSpaces" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgba( 255,  0,  0  , 1 )"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleRGBPercent" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgb(100%,50%,10%)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.1)
}

///|
test "Color: setStyleRGBAPercent" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgba(100%,50%,10%, 0.5)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.1)
}

///|
test "Color: setStyleRGBPercentWithSpaces" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgb( 100% ,50%  , 10% )"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.1)
}

///|
test "Color: setStyleRGBAPercentWithSpaces" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgba( 100% ,50%  ,  10%, 0.5 )"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.1)
}

///|
test "Color: setStyleRGBPercentWithDecimals" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("rgb(100%,50.5%,10.25%)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.505)
  assert_eq(c.b, 0.1025)
}

///|
test "Color: setStyleHSLRed" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsl(360,100%,50%)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleHSLARed" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsla(360,100%,50%,0.5)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleHSLRedWithSpaces" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsl(360,  100% , 50% )"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleHSLNegativeHue" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsl(-120,100%,50%)"))
  assert_eq(c.r, 0.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 1.0)
}

///|
test "Color: setStyleHSLARedWithSpaces" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsla( 360,  100% , 50%,  0.5 )"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleHSLRedWithDecimals" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsl(360,100.0%,50.0%)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleHSLARedWithDecimals" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("hsla(360,100.0%,50.0%,0.5)"))
  assert_eq(c.r, 1.0)
  assert_eq(c.g, 0.0)
  assert_eq(c.b, 0.0)
}

///|
test "Color: setStyleHexSkyBlue" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("#87CEEB"))
  assert_eq(c.get_hex(), 0x87CEEB)
}

///|
test "Color: setStyleHexSkyBlueMixed" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("#87cEeB"))
  assert_eq(c.get_hex(), 0x87CEEB)
}

///|
test "Color: setStyleHex2Olive" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("#F00"))
  assert_eq(c.get_hex(), 0xFF0000)
}

///|
test "Color: setStyleHex2OliveMixed" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("#f00"))
  assert_eq(c.get_hex(), 0xFF0000)
}

///|
test "Color: setStyleColorName" {
  color_test_disable_management()
  defer color_test_enable_management()
  let c = color_test_white()
  ignore(c.set_style("powderblue"))
  assert_eq(c.get_hex(), 0xB0E0E6)
}

// Not in upstream's test file: expected values are upstream's output.

///|
struct ColorTestAttribute {
  values : Array[Double]
}

///|
impl @math.BufferAttributeLike for ColorTestAttribute with fn get_x(self, index) {
  self.values[index * 3]
}

///|
impl @math.BufferAttributeLike for ColorTestAttribute with fn get_y(self, index) {
  self.values[index * 3 + 1]
}

///|
impl @math.BufferAttributeLike for ColorTestAttribute with fn get_z(self, index) {
  self.values[index * 3 + 2]
}

///|
impl @math.BufferAttributeLike for ColorTestAttribute with fn get_w(
  _self,
  _index,
) {
  1.0
}

///|
test "Color: fromBufferAttribute" {
  let attribute = ColorTestAttribute::{
    values: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6],
  }
  let c = color_test_white().from_buffer_attribute(attribute, 1)
  assert_eq(c.r, 0.4)
  assert_eq(c.g, 0.5)
  assert_eq(c.b, 0.6)
}

///|
test "Color: getStyle with a color space" {
  let a = @math.Color::new(0.2, 0.4, 0.6)
  assert_eq(a.get_style(), "rgb(124,170,203)")
  assert_eq(
    a.get_style(color_space=@math.LinearSRGBColorSpace),
    "color(srgb-linear 0.200 0.400 0.600)",
  )
  assert_eq(a.get_hex_string(color_space=@math.LinearSRGBColorSpace), "336699")
}

///|
test "Color: lerpHSL" {
  let a = @math.Color::new(0.2, 0.4, 0.6)
  let b = @math.Color::new(0.9, 0.1, 0.3)
  assert_eq(a.lerp_hsl(b, 0.25).get_hex(), 8353494)
}

///|
test "Color: lerpColors" {
  let a = @math.Color::new(0.2, 0.4, 0.6)
  let b = @math.Color::new(0.9, 0.1, 0.3)
  let c = color_test_white().lerp_colors(a, b, 0.25)
  assert_eq(c.r, 0.375)
  assert_eq(c.g, 0.325)
  assert_eq(c.b, 0.525)
}

///|
test "Color: sRGB transfer functions" {
  // `Math.pow` is not correctly rounded and differs by an ulp between V8 versions
  // (Node 22 gives b.g = 0.665189483970395), so compare within 1e-15.
  let close = fn(x : Double, y : Double) raise {
    assert_true((x - y).abs() < 1.0e-15)
  }
  let a = @math.Color::new(0.2, 0.4, 0.6).convert_srgb_to_linear()
  close(a.r, 0.033104766565152086)
  close(a.g, 0.13286832154414627)
  close(a.b, 0.31854677811435356)
  let b = @math.Color::new(0.2, 0.4, 0.6).convert_linear_to_srgb()
  close(b.r, 0.4845349934378071)
  close(b.g, 0.6651894839703951)
  close(b.b, 0.7977406370381005)
}
