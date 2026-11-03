// `GeometryAttribute` has no upstream file: it stands in for the duck typing of
// `geometry.attributes[ name ]`, forwarding what upstream calls on any attribute.

///|
/// What `setAttribute` and friends accept.
pub(open) trait ToGeometryAttribute {
  fn to_geometry_attribute(Self) -> GeometryAttribute
}

///|
pub impl ToGeometryAttribute for GeometryAttribute with fn to_geometry_attribute(
  self,
) {
  self
}

///|
pub impl ToGeometryAttribute for BufferAttribute with fn to_geometry_attribute(
  self,
) {
  Buffer(self)
}

///|
pub impl ToGeometryAttribute for InterleavedBufferAttribute with fn to_geometry_attribute(
  self,
) {
  Interleaved(self)
}

///|
pub impl ToGeometryAttribute for GLBufferAttribute with fn to_geometry_attribute(
  self,
) {
  GL(self)
}

///|
pub extend GeometryAttribute with ToGeometryAttribute::{to_geometry_attribute}

///|
pub extend BufferAttribute with ToGeometryAttribute::{to_geometry_attribute}

///|
pub extend InterleavedBufferAttribute with ToGeometryAttribute::{
  to_geometry_attribute,
}

///|
pub extend GLBufferAttribute with ToGeometryAttribute::{to_geometry_attribute}

///|
/// `attribute.count`.
pub fn GeometryAttribute::count(self : GeometryAttribute) -> Int32 {
  match self {
    Buffer(a) => a.count
    Interleaved(a) => a.count()
    GL(a) => a.count
  }
}

///|
/// `attribute.itemSize`.
pub fn GeometryAttribute::item_size(self : GeometryAttribute) -> Int32 {
  match self {
    Buffer(a) => a.item_size
    Interleaved(a) => a.item_size
    GL(a) => a.item_size
  }
}

///|
/// `attribute.normalized`.
pub fn GeometryAttribute::normalized(self : GeometryAttribute) -> Bool {
  match self {
    Buffer(a) => a.normalized
    Interleaved(a) => a.normalized
    GL(a) => a.normalized
  }
}

///|
/// `attribute.name`.
pub fn GeometryAttribute::name(self : GeometryAttribute) -> String {
  match self {
    Buffer(a) => a.name
    Interleaved(a) => a.name
    GL(a) => a.name
  }
}

///|
/// `attribute.array`. A `GLBufferAttribute` has none.
pub fn GeometryAttribute::array(self : GeometryAttribute) -> TypedArray {
  match self {
    Buffer(a) => a.array
    Interleaved(a) => a.array()
    GL(_) => abort("GLBufferAttribute has no array")
  }
}

///|
/// Upstream's `needsUpdate` setter.
pub fn GeometryAttribute::set_needs_update(
  self : GeometryAttribute,
  value : Bool,
) -> Unit {
  match self {
    Buffer(a) => a.set_needs_update(value)
    Interleaved(a) => a.set_needs_update(value)
    GL(a) => a.set_needs_update(value)
  }
}

///|
pub fn GeometryAttribute::apply_matrix4(
  self : GeometryAttribute,
  m : @math.Matrix4,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.apply_matrix4(m))
    Interleaved(a) => ignore(a.apply_matrix4(m))
    GL(_) => abort("GLBufferAttribute has no applyMatrix4")
  }
}

///|
pub fn GeometryAttribute::apply_normal_matrix(
  self : GeometryAttribute,
  m : @math.Matrix3,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.apply_normal_matrix(m))
    Interleaved(a) => ignore(a.apply_normal_matrix(m))
    GL(_) => abort("GLBufferAttribute has no applyNormalMatrix")
  }
}

///|
pub fn GeometryAttribute::transform_direction(
  self : GeometryAttribute,
  m : @math.Matrix4,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.transform_direction(m))
    Interleaved(a) => ignore(a.transform_direction(m))
    GL(_) => abort("GLBufferAttribute has no transformDirection")
  }
}

///|
pub fn GeometryAttribute::get_x(
  self : GeometryAttribute,
  index : Int32,
) -> Double {
  match self {
    Buffer(a) => a.get_x(index)
    Interleaved(a) => a.get_x(index)
    GL(_) => abort("GLBufferAttribute has no getX")
  }
}

///|
pub fn GeometryAttribute::get_y(
  self : GeometryAttribute,
  index : Int32,
) -> Double {
  match self {
    Buffer(a) => a.get_y(index)
    Interleaved(a) => a.get_y(index)
    GL(_) => abort("GLBufferAttribute has no getY")
  }
}

///|
pub fn GeometryAttribute::get_z(
  self : GeometryAttribute,
  index : Int32,
) -> Double {
  match self {
    Buffer(a) => a.get_z(index)
    Interleaved(a) => a.get_z(index)
    GL(_) => abort("GLBufferAttribute has no getZ")
  }
}

///|
pub fn GeometryAttribute::get_w(
  self : GeometryAttribute,
  index : Int32,
) -> Double {
  match self {
    Buffer(a) => a.get_w(index)
    Interleaved(a) => a.get_w(index)
    GL(_) => abort("GLBufferAttribute has no getW")
  }
}

///|
/// `attribute.version`, which an interleaved attribute reads from its buffer.
pub fn GeometryAttribute::version(self : GeometryAttribute) -> Int32 {
  match self {
    Buffer(a) => a.version
    Interleaved(a) => a.data.version
    GL(a) => a.version
  }
}

///|
pub fn GeometryAttribute::get_component(
  self : GeometryAttribute,
  index : Int32,
  component : Int32,
) -> Double {
  match self {
    Buffer(a) => a.get_component(index, component)
    Interleaved(a) => a.get_component(index, component)
    GL(_) => abort("GLBufferAttribute has no getComponent")
  }
}

///|
pub fn GeometryAttribute::set_component(
  self : GeometryAttribute,
  index : Int32,
  component : Int32,
  value : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_component(index, component, value))
    Interleaved(a) => ignore(a.set_component(index, component, value))
    GL(_) => abort("GLBufferAttribute has no setComponent")
  }
}

///|
pub fn GeometryAttribute::set_x(
  self : GeometryAttribute,
  index : Int32,
  x : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_x(index, x))
    Interleaved(a) => ignore(a.set_x(index, x))
    GL(_) => abort("GLBufferAttribute has no setX")
  }
}

///|
pub fn GeometryAttribute::set_y(
  self : GeometryAttribute,
  index : Int32,
  y : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_y(index, y))
    Interleaved(a) => ignore(a.set_y(index, y))
    GL(_) => abort("GLBufferAttribute has no setY")
  }
}

///|
pub fn GeometryAttribute::set_z(
  self : GeometryAttribute,
  index : Int32,
  z : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_z(index, z))
    Interleaved(a) => ignore(a.set_z(index, z))
    GL(_) => abort("GLBufferAttribute has no setZ")
  }
}

///|
pub fn GeometryAttribute::set_w(
  self : GeometryAttribute,
  index : Int32,
  w : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_w(index, w))
    Interleaved(a) => ignore(a.set_w(index, w))
    GL(_) => abort("GLBufferAttribute has no setW")
  }
}

///|
pub fn GeometryAttribute::set_xy(
  self : GeometryAttribute,
  index : Int32,
  x : Double,
  y : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_xy(index, x, y))
    Interleaved(a) => ignore(a.set_xy(index, x, y))
    GL(_) => abort("GLBufferAttribute has no setXY")
  }
}

///|
pub fn GeometryAttribute::set_xyz(
  self : GeometryAttribute,
  index : Int32,
  x : Double,
  y : Double,
  z : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_xyz(index, x, y, z))
    Interleaved(a) => ignore(a.set_xyz(index, x, y, z))
    GL(_) => abort("GLBufferAttribute has no setXYZ")
  }
}

///|
pub fn GeometryAttribute::set_xyzw(
  self : GeometryAttribute,
  index : Int32,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> Unit {
  match self {
    Buffer(a) => ignore(a.set_xyzw(index, x, y, z, w))
    Interleaved(a) => ignore(a.set_xyzw(index, x, y, z, w))
    GL(_) => abort("GLBufferAttribute has no setXYZW")
  }
}

///|
/// `attribute.clone( data )`. A `GLBufferAttribute` has no `clone` upstream.
pub fn GeometryAttribute::clone(
  self : GeometryAttribute,
  data? : AttributeCloneData,
) -> GeometryAttribute {
  match self {
    Buffer(a) => Buffer(a.clone())
    Interleaved(a) => a.clone(data?)
    GL(_) => abort("GLBufferAttribute has no clone")
  }
}

///|
/// `attribute.toJSON( data )`. A `GLBufferAttribute` has no `toJSON` upstream.
pub fn GeometryAttribute::to_json(
  self : GeometryAttribute,
  data? : Map[String, Json],
) -> Json {
  match self {
    Buffer(a) => a.to_json()
    Interleaved(a) => a.to_json(data?)
    GL(_) => abort("GLBufferAttribute has no toJSON")
  }
}

///|
pub impl @math.BufferAttributeLike for GeometryAttribute with fn get_x(
  self,
  index,
) {
  GeometryAttribute::get_x(self, index)
}

///|
pub impl @math.BufferAttributeLike for GeometryAttribute with fn get_y(
  self,
  index,
) {
  GeometryAttribute::get_y(self, index)
}

///|
pub impl @math.BufferAttributeLike for GeometryAttribute with fn get_z(
  self,
  index,
) {
  GeometryAttribute::get_z(self, index)
}

///|
pub impl @math.BufferAttributeLike for GeometryAttribute with fn get_w(
  self,
  index,
) {
  GeometryAttribute::get_w(self, index)
}

///|
let _box3_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// Upstream `Box3.setFromBufferAttribute`, which math cannot define because the
/// attribute types live here.
pub fn box3_set_from_buffer_attribute(
  box_ : @math.Box3,
  attribute : GeometryAttribute,
) -> @math.Box3 {
  ignore(box_.make_empty())
  for i in 0..<attribute.count() {
    ignore(
      box_.expand_by_point(_box3_vector.from_buffer_attribute(attribute, i)),
    )
  }
  box_
}
