// Upstream examples/jsm/math/ColorSpaces.js. Like upstream, the module only defines
// the color spaces; apps register them with `@math.color_management.define`.
// Reference: http://www.russellcottrell.com/photo/matrixCalculator.htm

///|
let color_spaces_p3_primaries : Array[Double] = [
  0.680, 0.320, 0.265, 0.690, 0.150, 0.060,
]

///|
let color_spaces_p3_luminance_coefficients : Array[Double] = [
  0.2289, 0.6917, 0.0793,
]

///|
let color_spaces_rec2020_primaries : Array[Double] = [
  0.708, 0.292, 0.170, 0.797, 0.131, 0.046,
]

///|
let color_spaces_rec2020_luminance_coefficients : Array[Double] = [
  0.2627, 0.6780, 0.0593,
]

///|
let color_spaces_d65 : Array[Double] = [0.3127, 0.3290]

// Display P3 definitions

///|
let color_spaces_linear_display_p3_to_xyz : @math.Matrix3 = @math.Matrix3::new().set(
  0.4865709, 0.2656677, 0.1982173, 0.2289746, 0.6917385, 0.0792869, 0.0000000, 0.0451134,
  1.0439444,
)

///|
let color_spaces_xyz_to_linear_display_p3 : @math.Matrix3 = @math.Matrix3::new().set(
  2.4934969, -0.9313836, -0.4027108, -0.8294890, 1.7626641, 0.0236247, 0.0358458,
  -0.0761724, 0.9568845,
)

///|
/// Display-P3 color space.
pub const DisplayP3ColorSpace : String = "display-p3"

///|
/// Display-P3-Linear color space.
pub const LinearDisplayP3ColorSpace : String = "display-p3-linear"

///|
/// Implementation object for the Display-P3 color space.
pub let display_p3_color_space_impl : @math.ColorSpaceDefinition = {
  primaries: color_spaces_p3_primaries,
  white_point: color_spaces_d65,
  transfer: @math.SRGBTransfer,
  to_xyz: color_spaces_linear_display_p3_to_xyz,
  from_xyz: color_spaces_xyz_to_linear_display_p3,
  luminance_coefficients: color_spaces_p3_luminance_coefficients,
  working_color_space_config: None,
  output_color_space_config: Some({
    drawing_buffer_color_space: DisplayP3ColorSpace,
    tone_mapping_mode: None,
  }),
}

///|
/// Implementation object for the Display-P3-Linear color space.
pub let linear_display_p3_color_space_impl : @math.ColorSpaceDefinition = {
  primaries: color_spaces_p3_primaries,
  white_point: color_spaces_d65,
  transfer: @math.LinearTransfer,
  to_xyz: color_spaces_linear_display_p3_to_xyz,
  from_xyz: color_spaces_xyz_to_linear_display_p3,
  luminance_coefficients: color_spaces_p3_luminance_coefficients,
  working_color_space_config: Some({ unpack_color_space: DisplayP3ColorSpace, }),
  output_color_space_config: Some({
    drawing_buffer_color_space: DisplayP3ColorSpace,
    tone_mapping_mode: None,
  }),
}

// Rec. 2020 definitions

///|
let color_spaces_linear_rec2020_to_xyz : @math.Matrix3 = @math.Matrix3::new().set(
  0.6369580, 0.1446169, 0.1688810, 0.2627002, 0.6779981, 0.0593017, 0.0000000, 0.0280727,
  1.0609851,
)

///|
let color_spaces_xyz_to_linear_rec2020 : @math.Matrix3 = @math.Matrix3::new().set(
  1.7166512, -0.3556708, -0.2533663, -0.6666844, 1.6164812, 0.0157685, 0.0176399,
  -0.0427706, 0.9421031,
)

///|
/// Rec2020-Linear color space.
pub const LinearRec2020ColorSpace : String = "rec2020-linear"

///|
/// Implementation object for the Rec2020-Linear color space.
pub let linear_rec2020_color_space_impl : @math.ColorSpaceDefinition = {
  primaries: color_spaces_rec2020_primaries,
  white_point: color_spaces_d65,
  transfer: @math.LinearTransfer,
  to_xyz: color_spaces_linear_rec2020_to_xyz,
  from_xyz: color_spaces_xyz_to_linear_rec2020,
  luminance_coefficients: color_spaces_rec2020_luminance_coefficients,
  working_color_space_config: None,
  output_color_space_config: None,
}

///|
/// Extended-sRGB color space.
pub const ExtendedSRGBColorSpace : String = "extended-srgb"

///|
/// Implementation object for the Extended-sRGB color space.
pub let extended_srgb_color_space_impl : @math.ColorSpaceDefinition = {
  ..@math.color_management.spaces.get(@math.SRGBColorSpace).unwrap(),
  output_color_space_config: Some({
    drawing_buffer_color_space: @math.SRGBColorSpace,
    tone_mapping_mode: Some("extended"),
  }),
}
