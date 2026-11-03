///|
let _directional_light_helper_v1 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _directional_light_helper_v2 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _directional_light_helper_v3 : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
/// Shows a directional light's plane and the line to its target. A plain `Object3D`
/// whose `matrix` is the light's `matrix_world`. `color` `None` follows the light.
pub(all) struct DirectionalLightHelper {
  mut light : @core.Object3D
  mut color : @math.Color?
  mut light_plane : @core.Object3D
  mut target_line : @core.Object3D
}

///|
pub impl @core.Object3DExtension for DirectionalLightHelper with fn type_name(_) {
  "DirectionalLightHelper"
}

///|
/// Upstream's `new DirectionalLightHelper()` throws on the missing light.
pub impl @core.Object3DExtension for DirectionalLightHelper with fn construct(_) {
  abort("DirectionalLightHelper: new DirectionalLightHelper() needs a light")
}

///|
pub impl @core.Object3DExtension for DirectionalLightHelper with fn dispose(
  self,
  object,
) {
  object.dispose_kind()
  geometry_of(self.light_plane).dispose()
  material_of(self.light_plane).dispose()
  geometry_of(self.target_line).dispose()
  material_of(self.target_line).dispose()
}

///|
/// `new DirectionalLightHelper( light, size, color )`.
pub fn DirectionalLightHelper::new(
  light : @core.Object3D,
  size~ : Double = 1.0,
  color? : @math.Color,
) -> @core.Object3D {
  let object = @core.Object3D::new()
  object.matrix = light.matrix_world
  object.matrix_auto_update = false
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(
        [
          -size,
          size,
          0.0,
          size,
          size,
          0.0,
          size,
          -size,
          0.0,
          -size,
          -size,
          0.0,
          -size,
          size,
          0.0,
        ],
        3,
      ),
    ),
  )
  let material = @core.LineBasicMaterial::new()
  material.fog = Some(false)
  material.tone_mapped = false
  let light_plane = @core.Line::new(geometry~, material=Single(material))
  ignore(object.add(light_plane))
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([0.0, 0.0, 0.0, 0.0, 0.0, 1.0], 3),
    ),
  )
  let target_line = @core.Line::new(geometry~, material=Single(material))
  ignore(object.add(target_line))
  let helper : DirectionalLightHelper = {
    light,
    color,
    light_plane,
    target_line,
  }
  ignore(object.set_extension(helper))
  DirectionalLightHelper::update(object)
  object
}

///|
/// The `DirectionalLightHelper` payload of `object`, if it is one.
pub fn DirectionalLightHelper::of(
  object : @core.Object3D,
) -> DirectionalLightHelper? {
  helper_payload(object, "DirectionalLightHelper")
}

///|
/// `helper.update()`: follows the light, its target and its color.
pub fn DirectionalLightHelper::update(helper : @core.Object3D) -> Unit {
  let payload : DirectionalLightHelper = require_payload(
    helper, "DirectionalLightHelper",
  )
  let light = payload.light
  helper.matrix_world_needs_update = true
  light.update_world_matrix(true, false)
  light.light_target().update_world_matrix(true, false)
  ignore(
    _directional_light_helper_v1.set_from_matrix_position(light.matrix_world),
  )
  ignore(
    _directional_light_helper_v2.set_from_matrix_position(
      light.light_target().matrix_world,
    ),
  )
  ignore(
    _directional_light_helper_v3.sub_vectors(
      _directional_light_helper_v2, _directional_light_helper_v1,
    ),
  )
  payload.light_plane.look_at(_directional_light_helper_v2)
  match payload.color {
    Some(color) => {
      ignore(color_of(material_of(payload.light_plane)).copy(color))
      ignore(color_of(material_of(payload.target_line)).copy(color))
    }
    None => {
      let light_color = light.as_light().color
      ignore(color_of(material_of(payload.light_plane)).copy(light_color))
      ignore(color_of(material_of(payload.target_line)).copy(light_color))
    }
  }
  payload.target_line.look_at(_directional_light_helper_v2)
  payload.target_line.scale.z = _directional_light_helper_v3.length()
}

///|
#deprecated
pub extend DirectionalLightHelper with @core.Object3DExtension::{
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
