// Upstream src/lights/AmbientLight.js.

///|
/// `new AmbientLight( color, intensity )`.
#external
pub type AmbientLight

///|
pub fn AmbientLight::new(
  color? : @math.Color,
  intensity~ : Double = 1.0,
) -> Object3D {
  Object3D::new(
    kind=Light(light_data_new(color, intensity, None, AmbientLight)),
    type_="AmbientLight",
  )
}
