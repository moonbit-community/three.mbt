// Upstream src/lights/webgpu/IESSpotLight.js. `copy` is in spot_light.mbt.

///|
/// `new IESSpotLight( color, intensity, distance, angle, penumbra, decay )`.
#external
pub type IESSpotLight

///|
pub fn IESSpotLight::new(
  color? : @math.Color,
  intensity~ : Double = 1.0,
  distance~ : Double = 0.0,
  angle~ : Double = _spot_light_default_angle,
  penumbra~ : Double = 0.0,
  decay~ : Double = 2.0,
) -> Object3D {
  spot_light_new(
    color,
    intensity,
    distance,
    angle,
    penumbra,
    decay,
    IESSpotLight,
  )
}
