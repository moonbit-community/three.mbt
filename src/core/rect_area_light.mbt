// Upstream src/lights/RectAreaLight.js. `RectAreaLight` is the payload struct, so
// `RectAreaLight::new` returns the `Object3D` that holds it. `toJSON` is in light.mbt.

///|
extern "js" fn _rect_area_light_math_pi() -> Double = "() => Math.PI"

///|
/// `new RectAreaLight( color, intensity, width, height )`.
pub fn RectAreaLight::new(
  color? : @math.Color,
  intensity~ : Double = 1.0,
  width~ : Double = 10.0,
  height~ : Double = 10.0,
) -> Object3D {
  Object3D::new(
    kind=Light(
      light_data_new(color, intensity, None, RectAreaLight({ width, height, })),
    ),
    type_="RectAreaLight",
  )
}

///|
fn RectAreaLight::copy_fields(self : RectAreaLight, source : Light) -> Unit {
  guard source.kind is RectAreaLight(rect_area) else {
    abort("RectAreaLight.copy: source has no width or height")
  }
  self.width = rect_area.width
  self.height = rect_area.height
}

///|
/// Compute the light's luminous power (in lumens) from its intensity (in nits).
fn RectAreaLight::power(self : RectAreaLight, light : Light) -> Double {
  light.intensity * self.width * self.height * _rect_area_light_math_pi()
}

///|
/// Set the light's intensity (in nits) from the desired luminous power (in lumens).
fn RectAreaLight::set_power(
  self : RectAreaLight,
  light : Light,
  power : Double,
) -> Unit {
  light.intensity = power /
    (self.width * self.height * _rect_area_light_math_pi())
}
