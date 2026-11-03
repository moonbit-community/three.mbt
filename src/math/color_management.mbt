///|
let linear_rec709_to_xyz : Matrix3 = Matrix3::new().set(
  0.4123908, 0.3575843, 0.1804808, 0.2126390, 0.7151687, 0.0721923, 0.0193308, 0.1191948,
  0.9505322,
)

///|
let xyz_to_linear_rec709 : Matrix3 = Matrix3::new().set(
  3.2409699, -1.5373832, -0.4986108, -0.9692436, 1.8759675, 0.0415551, 0.0556301,
  -0.2039770, 1.0569715,
)

///|
/// The optional `workingColorSpaceConfig` of a color space.
pub(all) struct WorkingColorSpaceConfig {
  mut unpack_color_space : String
}

///|
/// The optional `outputColorSpaceConfig` of a color space.
pub(all) struct OutputColorSpaceConfig {
  mut drawing_buffer_color_space : String
  mut tone_mapping_mode : String?
}

///|
/// One entry of `ColorManagement.spaces`.
pub(all) struct ColorSpaceDefinition {
  mut primaries : Array[Double]
  mut white_point : Array[Double]
  mut transfer : String
  mut to_xyz : Matrix3
  mut from_xyz : Matrix3
  mut luminance_coefficients : Array[Double]
  mut working_color_space_config : WorkingColorSpaceConfig?
  mut output_color_space_config : OutputColorSpaceConfig?
}

///|
/// The type of the `color_management` singleton.
pub(all) struct ColorManagement {
  mut enabled : Bool
  mut working_color_space : String
  mut spaces : Map[String, ColorSpaceDefinition]
}

///|
fn ColorManagement::space(
  self : ColorManagement,
  color_space : String,
) -> ColorSpaceDefinition {
  match self.spaces.get(color_space) {
    Some(space) => space
    None => abort("THREE.ColorManagement: Unknown color space " + color_space)
  }
}

///|
pub fn ColorManagement::convert(
  self : ColorManagement,
  color : Color,
  source_color_space : String,
  target_color_space : String,
) -> Color {
  if self.enabled == false ||
    source_color_space == target_color_space ||
    source_color_space == NoColorSpace ||
    target_color_space == NoColorSpace {
    return color
  }
  let source = self.space(source_color_space)
  let target = self.space(target_color_space)
  if source.transfer == SRGBTransfer {
    color.r = srgb_to_linear(color.r)
    color.g = srgb_to_linear(color.g)
    color.b = srgb_to_linear(color.b)
  }
  // upstream compares these arrays by reference
  if !physical_equal(source.primaries, target.primaries) {
    ignore(color.apply_matrix3(source.to_xyz))
    ignore(color.apply_matrix3(target.from_xyz))
  }
  if target.transfer == SRGBTransfer {
    color.r = linear_to_srgb(color.r)
    color.g = linear_to_srgb(color.g)
    color.b = linear_to_srgb(color.b)
  }
  color
}

///|
pub fn ColorManagement::working_to_color_space(
  self : ColorManagement,
  color : Color,
  target_color_space : String,
) -> Color {
  self.convert(color, self.working_color_space, target_color_space)
}

///|
pub fn ColorManagement::color_space_to_working(
  self : ColorManagement,
  color : Color,
  source_color_space : String,
) -> Color {
  self.convert(color, source_color_space, self.working_color_space)
}

///|
pub fn ColorManagement::get_primaries(
  self : ColorManagement,
  color_space : String,
) -> Array[Double] {
  self.space(color_space).primaries
}

///|
pub fn ColorManagement::get_transfer(
  self : ColorManagement,
  color_space : String,
) -> String {
  if color_space == NoColorSpace {
    return LinearTransfer
  }
  self.space(color_space).transfer
}

///|
pub fn ColorManagement::get_tone_mapping_mode(
  self : ColorManagement,
  color_space : String,
) -> String {
  match
    self.space(color_space).output_color_space_config.unwrap().tone_mapping_mode {
    None | Some("") => "standard"
    Some(mode) => mode
  }
}

///|
pub fn ColorManagement::get_luminance_coefficients(
  self : ColorManagement,
  target : Vector3,
  color_space~ : String = self.working_color_space,
) -> Vector3 {
  target.from_array(self.space(color_space).luminance_coefficients)
}

///|
pub fn ColorManagement::define(
  self : ColorManagement,
  color_spaces : Map[String, ColorSpaceDefinition],
) -> Unit {
  for name, space in color_spaces {
    self.spaces[name] = space
  }
}

///|
pub fn ColorManagement::_get_matrix(
  self : ColorManagement,
  target_matrix : Matrix3,
  source_color_space : String,
  target_color_space : String,
) -> Matrix3 {
  target_matrix
  .copy(self.space(target_color_space).from_xyz)
  .multiply(self.space(source_color_space).to_xyz)
}

///|
pub fn ColorManagement::_get_drawing_buffer_color_space(
  self : ColorManagement,
  color_space : String,
) -> String {
  self.space(color_space).output_color_space_config.unwrap().drawing_buffer_color_space
}

///|
pub fn ColorManagement::_get_unpack_color_space(
  self : ColorManagement,
  color_space~ : String = self.working_color_space,
) -> String {
  self.space(color_space).working_color_space_config.unwrap().unpack_color_space
}

///|
fn create_color_management() -> ColorManagement {
  let color_management : ColorManagement = {
    enabled: true,
    working_color_space: LinearSRGBColorSpace,
    spaces: {},
  }

  // sRGB definitions
  let rec709_primaries = [0.640, 0.330, 0.300, 0.600, 0.150, 0.060]
  let rec709_luminance_coefficients = [0.2126, 0.7152, 0.0722]
  let d65 = [0.3127, 0.3290]
  color_management.define(
    Map::from_array([
      (
        LinearSRGBColorSpace,
        {
          primaries: rec709_primaries,
          white_point: d65,
          transfer: LinearTransfer,
          to_xyz: linear_rec709_to_xyz,
          from_xyz: xyz_to_linear_rec709,
          luminance_coefficients: rec709_luminance_coefficients,
          working_color_space_config: Some({
            unpack_color_space: SRGBColorSpace,
          }),
          output_color_space_config: Some({
            drawing_buffer_color_space: SRGBColorSpace,
            tone_mapping_mode: None,
          }),
        },
      ),
      (
        SRGBColorSpace,
        {
          primaries: rec709_primaries,
          white_point: d65,
          transfer: SRGBTransfer,
          to_xyz: linear_rec709_to_xyz,
          from_xyz: xyz_to_linear_rec709,
          luminance_coefficients: rec709_luminance_coefficients,
          working_color_space_config: None,
          output_color_space_config: Some({
            drawing_buffer_color_space: SRGBColorSpace,
            tone_mapping_mode: None,
          }),
        },
      ),
    ]),
  )
  color_management
}

///|
/// The `ColorManagement` singleton of upstream.
pub let color_management : ColorManagement = create_color_management()

///|
pub fn srgb_to_linear(c : Double) -> Double {
  if c < 0.04045 {
    c * 0.0773993808
  } else {
    @cmath.pow(c * 0.9478672986 + 0.0521327014, 2.4)
  }
}

///|
pub fn linear_to_srgb(c : Double) -> Double {
  if c < 0.0031308 {
    c * 12.92
  } else {
    1.055 * @cmath.pow(c, 0.41666) - 0.055
  }
}
