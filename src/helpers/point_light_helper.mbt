///|
/// Shows a point light as a wireframe sphere. A `Mesh` whose `matrix` is the light's
/// `matrix_world`. `color` `None` follows the light.
pub(all) struct PointLightHelper {
  mut light : @core.Object3D
  mut color : @math.Color?
}

///|
pub impl @core.Object3DExtension for PointLightHelper with fn type_name(_) {
  "PointLightHelper"
}

///|
/// Upstream's `new PointLightHelper()` throws on the missing light.
pub impl @core.Object3DExtension for PointLightHelper with fn construct(_) {
  abort("PointLightHelper: new PointLightHelper() needs a light")
}

///|
pub impl @core.Object3DExtension for PointLightHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
/// `new PointLightHelper( light, sphereSize, color )`.
pub fn PointLightHelper::new(
  light : @core.Object3D,
  sphere_size~ : Double = 1.0,
  color? : @math.Color,
) -> @core.Object3D {
  let geometry = @geometries.SphereGeometry::new(
    radius=sphere_size,
    width_segments=4.0,
    height_segments=2.0,
  )
  let material = @core.MeshBasicMaterial::new()
  material.wireframe = Some(true)
  material.fog = Some(false)
  material.tone_mapped = false
  let helper : PointLightHelper = { light, color, }
  let object = @core.Mesh::new(geometry~, material=Single(material)).set_extension(
    helper,
  )
  object.matrix = light.matrix_world
  object.matrix_auto_update = false
  PointLightHelper::update(object)
  object
}

///|
/// The `PointLightHelper` payload of `object`, if it is one.
pub fn PointLightHelper::of(object : @core.Object3D) -> PointLightHelper? {
  helper_payload(object, "PointLightHelper")
}

///|
/// `helper.update()`: follows the light's position and color.
pub fn PointLightHelper::update(helper : @core.Object3D) -> Unit {
  let payload : PointLightHelper = require_payload(helper, "PointLightHelper")
  helper.matrix_world_needs_update = true
  payload.light.update_world_matrix(true, false)
  match payload.color {
    Some(color) => ignore(color_of(material_of(helper)).copy(color))
    None =>
      ignore(color_of(material_of(helper)).copy(payload.light.as_light().color))
  }
}

///|
#deprecated
pub extend PointLightHelper with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}
