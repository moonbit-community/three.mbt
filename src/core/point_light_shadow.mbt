// Upstream src/lights/PointLightShadow.js.

///|
/// `new PointLightShadow()`.
#external
pub type PointLightShadow

///|
pub fn PointLightShadow::new() -> LightShadow {
  LightShadow::with_kind(
    PerspectiveCamera::new(fov=90.0, aspect=1.0, near=0.5, far=500.0),
    PointLightShadow,
  )
}
