// Upstream src/lights/HemisphereLight.js. `HemisphereLight` is the payload struct, so
// `HemisphereLight::new` returns the `Object3D` that holds it. `toJSON` is in light.mbt.

///|
/// `new HemisphereLight( skyColor, groundColor, intensity )`.
pub fn HemisphereLight::new(
  sky_color? : @math.Color,
  ground_color? : @math.Color,
  intensity~ : Double = 1.0,
) -> Object3D {
  let light = Object3D::new(
    kind=Light(
      light_data_new(
        sky_color,
        intensity,
        None,
        HemisphereLight({ ground_color: light_new_color(ground_color), }),
      ),
    ),
    type_="HemisphereLight",
  )
  ignore(light.position.copy(object3d_default_up))
  light.update_matrix()
  light
}

///|
fn HemisphereLight::copy_fields(self : HemisphereLight, source : Light) -> Unit {
  guard source.kind is HemisphereLight(hemisphere) else {
    abort("HemisphereLight.copy: source has no groundColor")
  }
  ignore(self.ground_color.copy(hemisphere.ground_color))
}
