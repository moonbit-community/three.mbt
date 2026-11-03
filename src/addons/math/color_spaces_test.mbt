// Upstream test/unit/addons/math/ColorSpaces.tests.js.
// Reference: https://apps.colorjs.io/convert/

///|
extern "js" fn color_spaces_test_to_fixed3(x : Double) -> String =
  #|(x) => x.toFixed(3)

///|
fn color_spaces_test_define() -> Unit {
  @three_math.color_management.define(
    Map::from_array([
      (@addon_math.DisplayP3ColorSpace, @addon_math.display_p3_color_space_impl),
      (
        @addon_math.LinearDisplayP3ColorSpace,
        @addon_math.linear_display_p3_color_space_impl,
      ),
      (
        @addon_math.LinearRec2020ColorSpace,
        @addon_math.linear_rec2020_color_space_impl,
      ),
    ]),
  )
}

///|
fn color_spaces_test_rgb(c : @three_math.Color) -> (String, String, String) {
  (
    color_spaces_test_to_fixed3(c.r),
    color_spaces_test_to_fixed3(c.g),
    color_spaces_test_to_fixed3(c.b),
  )
}

///|
test "DisplayP3ColorSpace" {
  color_spaces_test_define()
  let c = @three_math.Color::new(0.0, 0.0, 0.0).set_rgb(0.3, 0.5, 0.7)
  ignore(
    @three_math.color_management.convert(
      c,
      @three_math.LinearSRGBColorSpace,
      @addon_math.DisplayP3ColorSpace,
    ),
  )
  // display-p3, in gamut
  assert_eq(color_spaces_test_rgb(c), ("0.614", "0.731", "0.843"))
  ignore(c.set_rgb(1.0, 0.5, 0.01, color_space=@addon_math.DisplayP3ColorSpace))
  // srgb-linear, out of gamut
  assert_eq(color_spaces_test_rgb(c), ("1.177", "0.181", "-0.036"))
  assert_eq(
    c.get_style(color_space=@addon_math.DisplayP3ColorSpace),
    "color(display-p3 1.000 0.500 0.010)",
  )
}

///|
test "LinearDisplayP3ColorSpace" {
  color_spaces_test_define()
  let c = @three_math.Color::new(0.0, 0.0, 0.0).set_rgb(0.3, 0.5, 0.7)
  ignore(
    @three_math.color_management.convert(
      c,
      @three_math.LinearSRGBColorSpace,
      @addon_math.LinearDisplayP3ColorSpace,
    ),
  )
  // display-p3-linear, in gamut
  assert_eq(color_spaces_test_rgb(c), ("0.336", "0.493", "0.679"))
  ignore(
    c.set_rgb(1.0, 0.5, 0.01, color_space=@addon_math.LinearDisplayP3ColorSpace),
  )
  // srgb-linear, out of gamut
  assert_eq(color_spaces_test_rgb(c), ("1.112", "0.479", "-0.048"))
  assert_eq(
    c.get_style(color_space=@addon_math.LinearDisplayP3ColorSpace),
    "color(display-p3-linear 1.000 0.500 0.010)",
  )
}

///|
test "LinearRec2020ColorSpace" {
  color_spaces_test_define()
  let c = @three_math.Color::new(0.0, 0.0, 0.0).set_rgb(0.3, 0.5, 0.7)
  ignore(
    @three_math.color_management.convert(
      c,
      @three_math.LinearSRGBColorSpace,
      @addon_math.LinearRec2020ColorSpace,
    ),
  )
  // rec2020-linear, in gamut
  assert_eq(color_spaces_test_rgb(c), ("0.383", "0.488", "0.676"))
  ignore(
    c.set_rgb(1.0, 0.5, 0.01, color_space=@addon_math.LinearRec2020ColorSpace),
  )
  // srgb-linear, out of gamut
  assert_eq(color_spaces_test_rgb(c), ("1.366", "0.442", "-0.057"))
  assert_eq(
    c.get_style(color_space=@addon_math.LinearRec2020ColorSpace),
    "color(rec2020-linear 1.000 0.500 0.010)",
  )
}

///|
test "ExtendedSRGBColorSpace" {
  let srgb = @three_math.color_management.spaces
    .get(@three_math.SRGBColorSpace)
    .unwrap()
  let ext = @addon_math.extended_srgb_color_space_impl
  assert_eq(@addon_math.ExtendedSRGBColorSpace, "extended-srgb")
  assert_true(physical_equal(ext.primaries, srgb.primaries))
  assert_true(physical_equal(ext.to_xyz, srgb.to_xyz))
  assert_eq(ext.transfer, srgb.transfer)
  let out = ext.output_color_space_config.unwrap()
  assert_eq(out.drawing_buffer_color_space, @three_math.SRGBColorSpace)
  assert_eq(out.tone_mapping_mode, Some("extended"))
}
