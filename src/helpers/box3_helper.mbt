///|
/// Visualizes a `Box3`. A `LineSegments`; `box` is `None` as upstream's `undefined`.
pub(all) struct Box3Helper {
  mut box : @math.Box3?
}

///|
pub impl @core.Object3DExtension for Box3Helper with fn type_name(_) {
  "Box3Helper"
}

///|
pub impl @core.Object3DExtension for Box3Helper with fn construct(_) {
  Box3Helper::new()
}

///|
pub impl @core.Object3DExtension for Box3Helper with fn update_matrix_world(
  self,
  object,
  force,
) {
  guard self.box is Some(box) else {
    abort("Box3Helper.updateMatrixWorld: box is undefined")
  }
  if box.is_empty() {
    return
  }
  ignore(box.get_center(object.position))
  ignore(box.get_size(object.scale))
  ignore(object.scale.multiply_scalar(0.5))
  object.update_matrix_world_kind(force)
}

///|
pub impl @core.Object3DExtension for Box3Helper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
#deprecated
pub extend Box3Helper with @core.Object3DExtension::{
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

///|
/// `new Box3Helper( box, color )`.
pub fn Box3Helper::new(
  box? : @math.Box3,
  color~ : @math.Color = @math.Color::from_hex(0xffff00),
) -> @core.Object3D {
  let indices : Array[Int32] = [
    0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7,
  ]
  let positions : Array[Double] = [
    1.0, 1.0, 1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, -1.0,
    -1.0, 1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, -1.0,
  ]
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_index(
      @core.BufferAttribute::new(@core.TypedArray::uint16(indices), 1),
    ),
  )
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(positions, 3),
    ),
  )
  let helper : Box3Helper = { box, }
  let object = @core.LineSegments::new(
    geometry~,
    material=Single(line_basic_material(color)),
  ).set_extension(helper)
  geometry_of(object).compute_bounding_sphere()
  object
}

///|
/// The `Box3Helper` payload of `object`, if it is one.
pub fn Box3Helper::of(object : @core.Object3D) -> Box3Helper? {
  helper_payload(object, "Box3Helper")
}
