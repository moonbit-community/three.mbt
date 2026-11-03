///|
let _skeleton_helper_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _skeleton_helper_bone_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _skeleton_helper_matrix_world_inv : @math.Matrix4 = @math.Matrix4::new()

///|
/// Shows the bones under `root` as lines from each bone to its parent bone. A
/// `LineSegments` whose `matrix` is the root's `matrix_world`.
pub(all) struct SkeletonHelper {
  mut root : @core.Object3D
  mut bones : Array[@core.Object3D]
}

///|
pub impl @core.Object3DExtension for SkeletonHelper with fn type_name(_) {
  "SkeletonHelper"
}

///|
/// Upstream's `new SkeletonHelper()` throws on the missing object.
pub impl @core.Object3DExtension for SkeletonHelper with fn construct(_) {
  abort("SkeletonHelper: new SkeletonHelper() needs an object")
}

///|
pub impl @core.Object3DExtension for SkeletonHelper with fn has_flag(_, flag) {
  flag == "isSkeletonHelper"
}

///|
pub impl @core.Object3DExtension for SkeletonHelper with fn update_matrix_world(
  self,
  object,
  force,
) {
  let bones = self.bones
  let geometry = geometry_of(object)
  guard geometry.get_attribute("position") is Some(position) else {
    abort("SkeletonHelper.updateMatrixWorld: no position attribute")
  }
  ignore(
    _skeleton_helper_matrix_world_inv.copy(self.root.matrix_world).invert(),
  )
  let mut j = 0
  for bone in bones {
    if bone.parent is Some(parent) && parent.is_bone() {
      ignore(
        _skeleton_helper_bone_matrix.multiply_matrices(
          _skeleton_helper_matrix_world_inv,
          bone.matrix_world,
        ),
      )
      ignore(
        _skeleton_helper_vector.set_from_matrix_position(
          _skeleton_helper_bone_matrix,
        ),
      )
      position.set_xyz(
        j,
        _skeleton_helper_vector.x,
        _skeleton_helper_vector.y,
        _skeleton_helper_vector.z,
      )
      ignore(
        _skeleton_helper_bone_matrix.multiply_matrices(
          _skeleton_helper_matrix_world_inv,
          parent.matrix_world,
        ),
      )
      ignore(
        _skeleton_helper_vector.set_from_matrix_position(
          _skeleton_helper_bone_matrix,
        ),
      )
      position.set_xyz(
        j + 1,
        _skeleton_helper_vector.x,
        _skeleton_helper_vector.y,
        _skeleton_helper_vector.z,
      )
      j += 2
    }
  }
  guard geometry.get_attribute("position") is Some(position) else {
    abort("SkeletonHelper.updateMatrixWorld: no position attribute")
  }
  position.set_needs_update(true)
  object.update_matrix_world_kind(force)
}

///|
pub impl @core.Object3DExtension for SkeletonHelper with fn dispose(_, object) {
  object.dispose_kind()
  geometry_of(object).dispose()
  material_of(object).dispose()
}

///|
/// `new SkeletonHelper( object )`.
pub fn SkeletonHelper::new(object : @core.Object3D) -> @core.Object3D {
  let bones = get_bone_list(object)
  let geometry = @core.BufferGeometry::new()
  let vertices : Array[Double] = []
  let colors : Array[Double] = []
  for bone in bones {
    if bone.parent is Some(parent) && parent.is_bone() {
      for _ in 0..<6 {
        vertices.push(0.0)
        colors.push(0.0)
      }
    }
  }
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new(vertices, 3),
    ),
  )
  ignore(
    geometry.set_attribute(
      "color",
      @core.Float32BufferAttribute::new(colors, 3),
    ),
  )
  let material = @core.LineBasicMaterial::new()
  material.vertex_colors = true
  material.depth_test = false
  material.depth_write = false
  material.tone_mapped = false
  material.transparent = true
  let helper : SkeletonHelper = { root: object, bones, }
  let line = @core.LineSegments::new(geometry~, material=Single(material)).set_extension(
    helper,
  )
  line.matrix = object.matrix_world
  line.matrix_auto_update = false
  let color1 = @math.Color::from_hex(0x0000ff)
  let color2 = @math.Color::from_hex(0x00ff00)
  ignore(SkeletonHelper::set_colors(line, color1, color2))
  line
}

///|
/// The `SkeletonHelper` payload of `object`, if it is one.
pub fn SkeletonHelper::of(object : @core.Object3D) -> SkeletonHelper? {
  helper_payload(object, "SkeletonHelper")
}

///|
/// `helper.setColors( color1, color2 )`: the bone end and the parent end.
pub fn SkeletonHelper::set_colors(
  helper : @core.Object3D,
  color1 : @math.Color,
  color2 : @math.Color,
) -> @core.Object3D {
  let geometry = geometry_of(helper)
  guard geometry.get_attribute("color") is Some(color_attribute) else {
    abort("SkeletonHelper.setColors: no color attribute")
  }
  for i = 0; i < color_attribute.count(); i = i + 2 {
    color_attribute.set_xyz(i, color1.r, color1.g, color1.b)
    color_attribute.set_xyz(i + 1, color2.r, color2.g, color2.b)
  }
  color_attribute.set_needs_update(true)
  helper
}

///|
/// `object` if it is a bone, then the bones below it, depth first.
fn get_bone_list(object : @core.Object3D) -> Array[@core.Object3D] {
  let bone_list = []
  if object.is_bone() {
    bone_list.push(object)
  }
  for child in object.children {
    bone_list.push_iter(get_bone_list(child).iter())
  }
  bone_list
}

///|
#deprecated
pub extend SkeletonHelper with @core.Object3DExtension::{
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
