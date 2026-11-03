///|
let _arrow_helper_axis : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// The line and cone geometries every `ArrowHelper` shares, created by the first one.
let _arrow_helper_line_geometry : Ref[@core.BufferGeometry?] = Ref(None)

///|
let _arrow_helper_cone_geometry : Ref[@core.BufferGeometry?] = Ref(None)

///|
/// An arrow: a `Line` shaft and a `Mesh` cone under a plain `Object3D`.
pub(all) struct ArrowHelper {
  mut line : @core.Object3D
  mut cone : @core.Object3D
}

///|
pub impl @core.Object3DExtension for ArrowHelper with fn type_name(_) {
  "ArrowHelper"
}

///|
pub impl @core.Object3DExtension for ArrowHelper with fn construct(_) {
  ArrowHelper::new()
}

///|
/// Upstream's `copy( source )` ignores `recursive` and copies the parts in place.
pub impl @core.Object3DExtension for ArrowHelper with fn copy_from(
  self,
  target,
  source,
  _,
) {
  target.copy_kind(source, false)
  let source_helper : ArrowHelper = require_payload(source, "ArrowHelper")
  ignore(self.line.copy(source_helper.line))
  ignore(self.cone.copy(source_helper.cone))
}

///|
pub impl @core.Object3DExtension for ArrowHelper with fn dispose(self, object) {
  object.dispose_kind()
  geometry_of(self.line).dispose()
  material_of(self.line).dispose()
  geometry_of(self.cone).dispose()
  material_of(self.cone).dispose()
}

///|
#deprecated
pub extend ArrowHelper with @core.Object3DExtension::{
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
/// `new ArrowHelper( dir, origin, length, color, headLength, headWidth )`. `dir` must
/// be normalized; `head_length` defaults to `0.2 * length`, `head_width` to
/// `0.2 * head_length`.
pub fn ArrowHelper::new(
  dir~ : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 1.0),
  origin~ : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0),
  length~ : Double = 1.0,
  color~ : @math.Color = @math.Color::from_hex(0xffff00),
  head_length? : Double,
  head_width? : Double,
) -> @core.Object3D {
  let head_length = match head_length {
    Some(head_length) => head_length
    None => length * 0.2
  }
  let head_width = match head_width {
    Some(head_width) => head_width
    None => head_length * 0.2
  }
  let object = @core.Object3D::new()
  if _arrow_helper_line_geometry.val is None {
    let line_geometry = @core.BufferGeometry::new()
    ignore(
      line_geometry.set_attribute(
        "position",
        @core.Float32BufferAttribute::new([0.0, 0.0, 0.0, 0.0, 1.0, 0.0], 3),
      ),
    )
    _arrow_helper_line_geometry.val = Some(line_geometry)
    let cone_geometry = @geometries.ConeGeometry::new(
      radius=0.5,
      height=1.0,
      radial_segments=5.0,
      height_segments=1.0,
    )
    ignore(cone_geometry.translate(0.0, -0.5, 0.0))
    _arrow_helper_cone_geometry.val = Some(cone_geometry)
  }
  ignore(object.position.copy(origin))
  let line = @core.Line::new(
    geometry=_arrow_helper_line_geometry.val.unwrap(),
    material=Single(line_basic_material(color)),
  )
  line.matrix_auto_update = false
  ignore(object.add(line))
  let cone_material = @core.MeshBasicMaterial::new()
  ignore(color_of(cone_material).copy(color))
  cone_material.tone_mapped = false
  let cone = @core.Mesh::new(
    geometry=_arrow_helper_cone_geometry.val.unwrap(),
    material=Single(cone_material),
  )
  cone.matrix_auto_update = false
  ignore(object.add(cone))
  let helper : ArrowHelper = { line, cone, }
  ignore(object.set_extension(helper))
  ArrowHelper::set_direction(object, dir)
  ArrowHelper::set_length(object, length, head_length~, head_width~)
  object
}

///|
/// The `ArrowHelper` payload of `object`, if it is one.
pub fn ArrowHelper::of(object : @core.Object3D) -> ArrowHelper? {
  helper_payload(object, "ArrowHelper")
}

///|
/// `helper.setDirection( dir )`; `dir` must be normalized.
pub fn ArrowHelper::set_direction(
  helper : @core.Object3D,
  dir : @math.Vector3,
) -> Unit {
  // dir is assumed to be normalized
  if dir.y > 0.99999 {
    ignore(helper.quaternion.set(0.0, 0.0, 0.0, 1.0))
  } else if dir.y < -0.99999 {
    ignore(helper.quaternion.set(1.0, 0.0, 0.0, 0.0))
  } else {
    ignore(_arrow_helper_axis.set(dir.z, 0.0, -dir.x).normalize())
    let radians = @cmath.acos(dir.y)
    ignore(helper.quaternion.set_from_axis_angle(_arrow_helper_axis, radians))
  }
}

///|
/// `helper.setLength( length, headLength, headWidth )`.
pub fn ArrowHelper::set_length(
  helper : @core.Object3D,
  length : Double,
  head_length? : Double,
  head_width? : Double,
) -> Unit {
  let head_length = match head_length {
    Some(head_length) => head_length
    None => length * 0.2
  }
  let head_width = match head_width {
    Some(head_width) => head_width
    None => head_length * 0.2
  }
  let arrow : ArrowHelper = require_payload(helper, "ArrowHelper")
  ignore(
    arrow.line.scale.set(
      1.0,
      helpers_math_max(0.0001, length - head_length),
      1.0,
    ),
  ) // see #17458
  arrow.line.update_matrix()
  ignore(arrow.cone.scale.set(head_width, head_length, head_width))
  arrow.cone.position.y = length
  arrow.cone.update_matrix()
}

///|
/// `helper.setColor( color )`.
pub fn ArrowHelper::set_color(
  helper : @core.Object3D,
  color : @math.Color,
) -> Unit {
  let arrow : ArrowHelper = require_payload(helper, "ArrowHelper")
  ignore(color_of(material_of(arrow.line)).copy(color))
  ignore(color_of(material_of(arrow.cone)).copy(color))
}
