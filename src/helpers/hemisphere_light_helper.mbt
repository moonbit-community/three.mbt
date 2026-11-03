///|
let _hemisphere_light_helper_vector : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _hemisphere_light_helper_color1 : @math.Color = @math.Color::new(
  1.0, 1.0, 1.0,
)

///|
let _hemisphere_light_helper_color2 : @math.Color = @math.Color::new(
  1.0, 1.0, 1.0,
)

///|
/// Shows a hemisphere light as a wireframe octahedron colored by sky and ground. A
/// plain `Object3D` whose `matrix` is the light's `matrix_world`.
pub(all) struct HemisphereLightHelper {
  mut light : @core.Object3D
  mut color : @math.Color?
  mut material : @core.Material
}

///|
pub impl @core.Object3DExtension for HemisphereLightHelper with fn type_name(_) {
  "HemisphereLightHelper"
}

///|
/// Upstream's `new HemisphereLightHelper()` throws on the missing light.
pub impl @core.Object3DExtension for HemisphereLightHelper with fn construct(_) {
  abort("HemisphereLightHelper: new HemisphereLightHelper() needs a light")
}

///|
pub impl @core.Object3DExtension for HemisphereLightHelper with fn dispose(
  _,
  object,
) {
  object.dispose_kind()
  geometry_of(object.children[0]).dispose()
  material_of(object.children[0]).dispose()
}

///|
/// `new HemisphereLightHelper( light, size, color )`.
pub fn HemisphereLightHelper::new(
  light : @core.Object3D,
  size~ : Double = 1.0,
  color? : @math.Color,
) -> @core.Object3D {
  let object = @core.Object3D::new()
  object.matrix = light.matrix_world
  object.matrix_auto_update = false
  let geometry = @geometries.OctahedronGeometry::new(radius=size)
  ignore(geometry.rotate_y(@cmath.PI * 0.5))
  let material = @core.MeshBasicMaterial::new()
  material.wireframe = Some(true)
  material.fog = Some(false)
  material.tone_mapped = false
  if color is None {
    material.vertex_colors = true
  }
  guard geometry.get_attribute("position") is Some(position) else {
    abort("HemisphereLightHelper: no position attribute")
  }
  let colors = @core.TypedArray::float32(position.count() * 3)
  ignore(geometry.set_attribute("color", @core.BufferAttribute::new(colors, 3)))
  ignore(object.add(@core.Mesh::new(geometry~, material=Single(material))))
  let helper : HemisphereLightHelper = { light, color, material, }
  ignore(object.set_extension(helper))
  HemisphereLightHelper::update(object)
  object
}

///|
/// The `HemisphereLightHelper` payload of `object`, if it is one.
pub fn HemisphereLightHelper::of(
  object : @core.Object3D,
) -> HemisphereLightHelper? {
  helper_payload(object, "HemisphereLightHelper")
}

///|
/// `helper.update()`: follows the light's position and colors.
pub fn HemisphereLightHelper::update(helper : @core.Object3D) -> Unit {
  let payload : HemisphereLightHelper = require_payload(
    helper, "HemisphereLightHelper",
  )
  let light = payload.light
  let mesh = helper.children[0]
  match payload.color {
    Some(color) => ignore(color_of(payload.material).copy(color))
    None => {
      guard geometry_of(mesh).get_attribute("color") is Some(colors) else {
        abort("HemisphereLightHelper.update: no color attribute")
      }
      ignore(_hemisphere_light_helper_color1.copy(light.as_light().color))
      guard light.as_light().kind is HemisphereLight(hemisphere) else {
        abort("HemisphereLightHelper.update: not a HemisphereLight")
      }
      ignore(_hemisphere_light_helper_color2.copy(hemisphere.ground_color))
      let l = colors.count()
      for i in 0..<l {
        let color = if i.to_double() < l.to_double() / 2.0 {
          _hemisphere_light_helper_color1
        } else {
          _hemisphere_light_helper_color2
        }
        colors.set_xyz(i, color.r, color.g, color.b)
      }
      colors.set_needs_update(true)
    }
  }
  helper.matrix_world_needs_update = true
  light.update_world_matrix(true, false)
  mesh.look_at(
    _hemisphere_light_helper_vector
    .set_from_matrix_position(light.matrix_world)
    .negate(),
  )
}

///|
#deprecated
pub extend HemisphereLightHelper with @core.Object3DExtension::{
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
