///|
let _spot_light_helper_vector : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
/// Shows a spot light's cone. A plain `Object3D` holding a `LineSegments` cone.
/// `color` `None` follows the light.
pub(all) struct SpotLightHelper {
  mut light : @core.Object3D
  mut color : @math.Color?
  mut cone : @core.Object3D
}

///|
pub impl @core.Object3DExtension for SpotLightHelper with fn type_name(_) {
  "SpotLightHelper"
}

///|
/// Upstream's `new SpotLightHelper()` throws on the missing light.
pub impl @core.Object3DExtension for SpotLightHelper with fn construct(_) {
  abort("SpotLightHelper: new SpotLightHelper() needs a light")
}

///|
pub impl @core.Object3DExtension for SpotLightHelper with fn dispose(
  self,
  object,
) {
  object.dispose_kind()
  geometry_of(self.cone).dispose()
  material_of(self.cone).dispose()
}

///|
/// `new SpotLightHelper( light, color )`.
pub fn SpotLightHelper::new(
  light : @core.Object3D,
  color? : @math.Color,
) -> @core.Object3D {
  let object = @core.Object3D::new()
  object.matrix_auto_update = false
  let geometry = @core.BufferGeometry::new()
  let positions : Array[Double] = [
    0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0,
    0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0, -1.0, 1.0,
  ]
  let l = 32
  for i = 0, j = 1; i < l; i = i + 1, j = j + 1 {
    let p1 = i.to_double() / l.to_double() * @cmath.PI * 2.0
    let p2 = j.to_double() / l.to_double() * @cmath.PI * 2.0
    positions.push(@cmath.cos(p1))
    positions.push(@cmath.sin(p1))
    positions.push(1.0)
    positions.push(@cmath.cos(p2))
    positions.push(@cmath.sin(p2))
    positions.push(1.0)
  }
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(positions, 3),
    ),
  )
  let material = @core.LineBasicMaterial::new()
  material.fog = Some(false)
  material.tone_mapped = false
  let cone = @core.LineSegments::new(geometry~, material=Single(material))
  ignore(object.add(cone))
  let helper : SpotLightHelper = { light, color, cone, }
  ignore(object.set_extension(helper))
  SpotLightHelper::update(object)
  object
}

///|
/// The `SpotLightHelper` payload of `object`, if it is one.
pub fn SpotLightHelper::of(object : @core.Object3D) -> SpotLightHelper? {
  helper_payload(object, "SpotLightHelper")
}

///|
/// `helper.update()`: follows the light, its target, distance, angle and color.
pub fn SpotLightHelper::update(helper : @core.Object3D) -> Unit {
  let payload : SpotLightHelper = require_payload(helper, "SpotLightHelper")
  let light = payload.light
  light.update_world_matrix(true, false)
  light.light_target().update_world_matrix(true, false)
  // update the local matrix based on the parent and light target transforms
  match helper.parent {
    Some(parent) => {
      parent.update_world_matrix(true, false)
      ignore(
        helper.matrix
        .copy(parent.matrix_world)
        .invert()
        .multiply(light.matrix_world),
      )
    }
    None => ignore(helper.matrix.copy(light.matrix_world))
  }
  helper.matrix_world_needs_update = true
  let spot = light.as_spot_light()
  // `distance ? distance : 1000`: 0 and NaN fall back
  let distance = spot.distance
  let cone_length = if distance != 0.0 && distance == distance {
    distance
  } else {
    1000.0
  }
  let cone_width = cone_length * @cmath.tan(spot.angle)
  ignore(payload.cone.scale.set(cone_width, cone_width, cone_length))
  ignore(
    _spot_light_helper_vector.set_from_matrix_position(
      light.light_target().matrix_world,
    ),
  )
  payload.cone.look_at(_spot_light_helper_vector)
  match payload.color {
    Some(color) => ignore(color_of(material_of(payload.cone)).copy(color))
    None =>
      ignore(color_of(material_of(payload.cone)).copy(light.as_light().color))
  }
}

///|
#deprecated
pub extend SpotLightHelper with @core.Object3DExtension::{
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
