///|
test "ColorManagement: enabled" {
  assert_true(@math.color_management.enabled)
}

///|
test "ColorManagement: _getMatrix" {
  let eps = 0.0001
  let linear_display_p3_color_space = "test-display-p3-linear"
  @math.color_management.define(
    Map::from_array([
      (
        linear_display_p3_color_space,
        @math.ColorSpaceDefinition::{
          primaries: [0.680, 0.320, 0.265, 0.690, 0.150, 0.060],
          white_point: [0.3127, 0.3290],
          transfer: @math.LinearTransfer,
          to_xyz: @math.Matrix3::new().set(
            0.4865709, 0.2656677, 0.1982173, 0.2289746, 0.6917385, 0.0792869, 0.0000000,
            0.0451134, 1.0439444,
          ),
          from_xyz: @math.Matrix3::new().set(
            2.4934969, -0.9313836, -0.4027108, -0.8294890, 1.7626641, 0.0236247,
            0.0358458, -0.0761724, 0.9568845,
          ),
          luminance_coefficients: [0.2289, 0.6917, 0.0793],
          working_color_space_config: None,
          output_color_space_config: None,
        },
      ),
    ]),
  )
  let matrix = @math.Matrix3::new()
  let vector = @math.Vector3::new(0.0, 0.0, 0.0)
  let color = @math.Color::new(1.0, 1.0, 1.0)
  let conversions = [
    (@math.LinearSRGBColorSpace, linear_display_p3_color_space),
    (linear_display_p3_color_space, @math.LinearSRGBColorSpace),
  ]
  for conversion in conversions {
    let (source, target) = conversion
    ignore(@math.color_management._get_matrix(matrix, source, target))
    for rgb in [[1.0, 1.0, 1.0], [1.0, 0.0, 0.0], [0.2, 0.5, 0.8]] {
      ignore(vector.from_array(rgb).apply_matrix3(matrix))
      ignore(
        @math.color_management.convert(color.from_array(rgb), source, target),
      )
      assert_true(
        (vector.x - color.r).abs() < eps &&
        (vector.y - color.g).abs() < eps &&
        (vector.z - color.b).abs() < eps,
      )
    }
  }
  @math.color_management.spaces.remove(linear_display_p3_color_space)
}

// Not in upstream's test file.

///|
test "ColorManagement: built-in color spaces" {
  let cm = @math.color_management
  assert_eq(cm.get_transfer(@math.NoColorSpace), @math.LinearTransfer)
  assert_eq(cm.get_transfer(@math.LinearSRGBColorSpace), @math.LinearTransfer)
  assert_eq(cm.get_transfer(@math.SRGBColorSpace), @math.SRGBTransfer)
  assert_eq(cm.get_tone_mapping_mode(@math.SRGBColorSpace), "standard")
  assert_eq(
    cm._get_drawing_buffer_color_space(@math.LinearSRGBColorSpace),
    @math.SRGBColorSpace,
  )
  assert_eq(cm._get_unpack_color_space(), @math.SRGBColorSpace)
  assert_eq(cm.get_primaries(@math.SRGBColorSpace), [
    0.640, 0.330, 0.300, 0.600, 0.150, 0.060,
  ])
  assert_true(
    physical_equal(
      cm.get_primaries(@math.SRGBColorSpace),
      cm.get_primaries(@math.LinearSRGBColorSpace),
    ),
  )
  let coefficients = cm.get_luminance_coefficients(
    @math.Vector3::new(0.0, 0.0, 0.0),
  )
  assert_eq(coefficients.x, 0.2126)
  assert_eq(coefficients.y, 0.7152)
  assert_eq(coefficients.z, 0.0722)
}

///|
test "ColorManagement: convert is a no-op without a color space" {
  let cm = @math.color_management
  let color = @math.Color::new(0.5, 0.25, 0.125)
  ignore(cm.convert(color, @math.NoColorSpace, @math.SRGBColorSpace))
  ignore(cm.convert(color, @math.SRGBColorSpace, @math.NoColorSpace))
  ignore(cm.convert(color, @math.SRGBColorSpace, @math.SRGBColorSpace))
  assert_true(color.equals(@math.Color::new(0.5, 0.25, 0.125)))
}
