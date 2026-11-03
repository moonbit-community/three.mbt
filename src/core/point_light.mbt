// Upstream src/lights/PointLight.js. `PointLight` is the payload struct, so
// `PointLight::new` returns the `Object3D` that holds it. `copy`, `toJSON` and `dispose`
// are in light.mbt.

///|
extern "js" fn _point_light_math_pi() -> Double = "() => Math.PI"

///|
/// `new PointLight( color, intensity, distance, decay )`.
pub fn PointLight::new(
  color? : @math.Color,
  intensity~ : Double = 1.0,
  distance~ : Double = 0.0,
  decay~ : Double = 2.0,
) -> Object3D {
  // Upstream draws the light's uuid (and id) before the shadow camera's.
  let light = Object3D::new(type_="PointLight")
  let shadow = PointLightShadow::new()
  light.kind = Light(
    light_data_new(
      color,
      intensity,
      Some(shadow),
      PointLight({ distance, decay, }),
    ),
  )
  light
}

///|
/// `source.distance` and `source.decay` of a `PointLight` or `SpotLight`.
fn PointLight::copy_fields(self : PointLight, source : Light) -> Unit {
  match source.kind {
    PointLight(point) => {
      self.distance = point.distance
      self.decay = point.decay
    }
    SpotLight(spot) => {
      self.distance = spot.distance
      self.decay = spot.decay
    }
    _ => abort("PointLight.copy: source has no distance or decay")
  }
}

///|
/// Compute the light's luminous power (in lumens) from its intensity (in candela).
/// For an isotropic light source, luminous power (lm) = 4 pi luminous intensity (cd).
fn point_light_power(light : Light) -> Double {
  light.intensity * 4.0 * _point_light_math_pi()
}

///|
/// Set the light's intensity (in candela) from the desired luminous power (in lumens).
fn point_light_set_power(light : Light, power : Double) -> Unit {
  light.intensity = power / (4.0 * _point_light_math_pi())
}
