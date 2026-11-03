///|
let _box_helper_box : @math.Box3 = @math.Box3::new()

///|
/// Shows the world-axis-aligned bounding box around an object. A `LineSegments`.
pub(all) struct BoxHelper {
  mut object : @core.Object3D?
}

///|
pub impl @core.Object3DExtension for BoxHelper with fn type_name(_) {
  "BoxHelper"
}

///|
pub impl @core.Object3DExtension for BoxHelper with fn construct(_) {
  BoxHelper::new()
}

///|
pub impl @core.Object3DExtension for BoxHelper with fn copy_from(
  self,
  target,
  source,
  recursive,
) {
  target.copy_kind(source, recursive)
  self.object = match BoxHelper::of(source) {
    Some(helper) => helper.object
    None => None
  }
}

///|
pub impl @core.Object3DExtension for BoxHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
#deprecated
pub extend BoxHelper with @core.Object3DExtension::{
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
/// `new BoxHelper( object, color )`.
pub fn BoxHelper::new(
  object? : @core.Object3D,
  color~ : @math.Color = @math.Color::from_hex(0xffff00),
) -> @core.Object3D {
  let indices : Array[Int32] = [
    0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7,
  ]
  let positions = @core.TypedArray::float32(8 * 3)
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_index(
      @core.BufferAttribute::new(@core.TypedArray::uint16(indices), 1),
    ),
  )
  ignore(
    geometry.set_attribute("position", @core.BufferAttribute::new(positions, 3)),
  )
  let helper : BoxHelper = { object, }
  let line = @core.LineSegments::new(
    geometry~,
    material=Single(line_basic_material(color)),
  ).set_extension(helper)
  line.matrix_auto_update = false
  BoxHelper::update(line)
  line
}

///|
/// The `BoxHelper` payload of `object`, if it is one.
pub fn BoxHelper::of(object : @core.Object3D) -> BoxHelper? {
  helper_payload(object, "BoxHelper")
}

///|
/// `helper.update()`: fits the box to the object. Without an object it reuses the box
/// of the last update of any `BoxHelper`, as upstream does.
pub fn BoxHelper::update(helper : @core.Object3D) -> Unit {
  let payload : BoxHelper = require_payload(helper, "BoxHelper")
  if payload.object is Some(object) {
    ignore(@core.box3_set_from_object(_box_helper_box, object))
  }
  if _box_helper_box.is_empty() {
    return
  }
  let min = _box_helper_box.min
  let max = _box_helper_box.max

  //   5____4
  // 1/___0/|
  // | 6__|_7
  // 2/___3/
  //
  // 0: max.x, max.y, max.z
  // 1: min.x, max.y, max.z
  // 2: min.x, min.y, max.z
  // 3: max.x, min.y, max.z
  // 4: max.x, max.y, min.z
  // 5: min.x, max.y, min.z
  // 6: min.x, min.y, min.z
  // 7: max.x, min.y, min.z

  let geometry = geometry_of(helper)
  let position = geometry.attributes["position"]
  let array = position.array()
  array[0] = max.x
  array[1] = max.y
  array[2] = max.z
  array[3] = min.x
  array[4] = max.y
  array[5] = max.z
  array[6] = min.x
  array[7] = min.y
  array[8] = max.z
  array[9] = max.x
  array[10] = min.y
  array[11] = max.z
  array[12] = max.x
  array[13] = max.y
  array[14] = min.z
  array[15] = min.x
  array[16] = max.y
  array[17] = min.z
  array[18] = min.x
  array[19] = min.y
  array[20] = min.z
  array[21] = max.x
  array[22] = min.y
  array[23] = min.z
  position.set_needs_update(true)
  geometry.compute_bounding_sphere()
}

///|
/// `helper.setFromObject( object )`.
pub fn BoxHelper::set_from_object(
  helper : @core.Object3D,
  object : @core.Object3D,
) -> @core.Object3D {
  let payload : BoxHelper = require_payload(helper, "BoxHelper")
  payload.object = Some(object)
  BoxHelper::update(helper)
  helper
}
