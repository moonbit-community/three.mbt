// Upstream src/lights/SpotLightShadow.js. `SpotLightShadow` is the payload struct, so
// `SpotLightShadow::new` returns the `LightShadow` that holds it. `copy` and `toJSON`
// are in light_shadow.mbt.

///|
/// `new SpotLightShadow()`.
pub fn SpotLightShadow::new() -> LightShadow {
  LightShadow::with_kind(
    PerspectiveCamera::new(fov=50.0, aspect=1.0, near=0.5, far=500.0),
    SpotLightShadow({ focus: 1.0, aspect: 1.0, }),
  )
}

///|
/// The first half of upstream's `updateMatrices`; `light` is a `SpotLight`.
fn SpotLightShadow::update_camera(
  self : SpotLightShadow,
  shadow : LightShadow,
  light : Object3D,
) -> Unit {
  let spot_light = light.as_spot_light()
  let camera = shadow.camera.as_perspective_camera()
  let fov = @math.RAD2DEG * 2.0 * spot_light.angle * self.focus
  let aspect = shadow.map_size.width() / shadow.map_size.height() * self.aspect
  // `light.distance || camera.far`: 0 and NaN are falsy
  let far = if spot_light.distance == 0.0 ||
    spot_light.distance != spot_light.distance {
    camera.far
  } else {
    spot_light.distance
  }
  if fov != camera.fov || aspect != camera.aspect || far != camera.far {
    camera.fov = fov
    camera.aspect = aspect
    camera.far = far
    shadow.camera.update_projection_matrix()
  }
}
