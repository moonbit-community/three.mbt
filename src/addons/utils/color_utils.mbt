// Upstream examples/jsm/utils/ColorUtils.js.

///|
extern "js" fn color_utils_pow(a : Double, b : Double) -> Double = "Math.pow"

///|
extern "js" fn color_utils_log(x : Double) -> Double = "Math.log"

///|
/// `setKelvin( color, kelvin )`: sets `color` to the sRGB color of a black body at
/// `kelvin` (clamped to 1000..40000), after Tanner Helland's fit.
pub fn set_kelvin(color : @math.Color, kelvin : Double) -> @math.Color {
  // Algorithm by Tanner Helland (2012). Inputs are divided by 100.
  let temp = @math.clamp(kelvin, 1000.0, 40000.0) / 100.0
  // Red channel
  let r = if temp <= 66.0 {
    255.0
  } else {
    329.698727446 * color_utils_pow(temp - 60.0, -0.1332047592)
  }
  // Green channel
  let g = if temp <= 66.0 {
    99.4708025861 * color_utils_log(temp) - 161.1195681661
  } else {
    288.1221695283 * color_utils_pow(temp - 60.0, -0.0755148492)
  }
  // Blue channel
  let b = if temp >= 66.0 {
    255.0
  } else if temp <= 19.0 {
    0.0
  } else {
    138.5177312231 * color_utils_log(temp - 10.0) - 305.0447927307
  }
  color.set_rgb(
    @math.clamp(r, 0.0, 255.0) / 255.0,
    @math.clamp(g, 0.0, 255.0) / 255.0,
    @math.clamp(b, 0.0, 255.0) / 255.0,
    color_space=@math.SRGBColorSpace,
  )
}
