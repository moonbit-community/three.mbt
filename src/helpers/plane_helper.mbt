///|
/// Visualizes a `Plane`: a `Line` outline with a translucent `Mesh` child. `plane` is
/// `None` as upstream's `undefined`.
pub(all) struct PlaneHelper {
  mut plane : @math.Plane?
  mut size : Double
}

///|
pub impl @core.Object3DExtension for PlaneHelper with fn type_name(_) {
  "PlaneHelper"
}

///|
pub impl @core.Object3DExtension for PlaneHelper with fn construct(_) {
  PlaneHelper::new()
}

///|
pub impl @core.Object3DExtension for PlaneHelper with fn update_matrix_world(
  self,
  object,
  force,
) {
  guard self.plane is Some(plane) else {
    abort("PlaneHelper.updateMatrixWorld: plane is undefined")
  }
  ignore(object.position.set(0.0, 0.0, 0.0))
  ignore(object.scale.set(0.5 * self.size, 0.5 * self.size, 1.0))
  object.look_at(plane.normal)
  ignore(object.translate_z(-plane.constant))
  object.update_matrix_world_kind(force)
}

///|
pub impl @core.Object3DExtension for PlaneHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
  geometry_of(object.children[0]).dispose()
  material_of(object.children[0]).dispose()
}

///|
/// `new PlaneHelper( plane, size, hex )`.
pub fn PlaneHelper::new(
  plane? : @math.Plane,
  size~ : Double = 1.0,
  color~ : @math.Color = @math.Color::from_hex(0xffff00),
) -> @core.Object3D {
  let positions : Array[Double] = [
    1.0, -1.0, 0.0, -1.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, -1.0, 1.0, 0.0,
    -1.0, -1.0, 0.0, 1.0, -1.0, 0.0, 1.0, 1.0, 0.0,
  ]
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(positions, 3),
    ),
  )
  geometry.compute_bounding_sphere()
  let helper : PlaneHelper = { plane, size, }
  let object = @core.Line::new(
    geometry~,
    material=Single(line_basic_material(color)),
  ).set_extension(helper)
  let positions2 : Array[Double] = [
    1.0, 1.0, 0.0, -1.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, 1.0, 0.0, -1.0, -1.0, 0.0,
    1.0, -1.0, 0.0,
  ]
  let geometry2 = @core.BufferGeometry::new()
  ignore(
    geometry2.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(positions2, 3),
    ),
  )
  geometry2.compute_bounding_sphere()
  let material2 = @core.MeshBasicMaterial::new()
  ignore(color_of(material2).copy(color))
  material2.opacity = 0.2
  material2.transparent = true
  material2.depth_write = false
  material2.tone_mapped = false
  ignore(
    object.add(@core.Mesh::new(geometry=geometry2, material=Single(material2))),
  )
  object
}

///|
/// The `PlaneHelper` payload of `object`, if it is one.
pub fn PlaneHelper::of(object : @core.Object3D) -> PlaneHelper? {
  helper_payload(object, "PlaneHelper")
}

///|
#deprecated
pub extend PlaneHelper with @core.Object3DExtension::{
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
