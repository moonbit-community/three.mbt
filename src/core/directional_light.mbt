// Upstream src/lights/DirectionalLight.js. `DirectionalLight` is the payload struct, so
// `DirectionalLight::new` returns the `Object3D` that holds it. `copy`, `toJSON` and
// `dispose` are in light.mbt.

///|
/// `new DirectionalLight( color, intensity )`.
pub fn DirectionalLight::new(
  color? : @math.Color,
  intensity~ : Double = 1.0,
) -> Object3D {
  // Upstream draws the uuids (and ids) of the light, then `target`, then the shadow
  // camera, so the light is built first and its payload filled in afterwards.
  let light = Object3D::new(type_="DirectionalLight")
  ignore(light.position.copy(object3d_default_up))
  light.update_matrix()
  let target = Object3D::new()
  let shadow = DirectionalLightShadow::new()
  light.kind = Light(
    light_data_new(
      color,
      intensity,
      Some(shadow),
      DirectionalLight({ target, }),
    ),
  )
  light
}
