// Upstream src/lights/DirectionalLightShadow.js.

///|
/// `new DirectionalLightShadow()`.
#external
pub type DirectionalLightShadow

///|
pub fn DirectionalLightShadow::new() -> LightShadow {
  LightShadow::with_kind(
    OrthographicCamera::new(
      left=-5.0,
      right=5.0,
      top=5.0,
      bottom=-5.0,
      near=0.5,
      far=500.0,
    ),
    DirectionalLightShadow,
  )
}
