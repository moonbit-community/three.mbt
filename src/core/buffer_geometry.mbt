// Upstream src/core/BufferGeometry.js.

///|
let _buffer_geometry_id : Ref[Int32] = Ref(0)

///|
let _buffer_geometry_m1 : @math.Matrix4 = @math.Matrix4::new()

///|
let _buffer_geometry_obj : Object3D = Object3D::new()

///|
let _buffer_geometry_offset : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _buffer_geometry_box : @math.Box3 = @math.Box3::new()

///|
let _buffer_geometry_box_morph_targets : @math.Box3 = @math.Box3::new()

///|
let _buffer_geometry_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
extern "js" fn buffer_geometry_infinity() -> Double = "() => Infinity"

///|
pub fn BufferGeometry::new() -> BufferGeometry {
  let id = _buffer_geometry_id.val
  _buffer_geometry_id.val += 1
  {
    id,
    dispatcher: EventDispatcher::new(),
    uuid: @math.generate_uuid(),
    name: "",
    type_: "BufferGeometry",
    index: None,
    indirect: None,
    indirect_offset: [0],
    attributes: Map([]),
    morph_attributes: Map([]),
    morph_targets_relative: false,
    groups: [],
    bounding_box: None,
    bounding_sphere: None,
    draw_range: { start: 0, count: buffer_geometry_infinity(), },
    user_data: JsValue::object(),
    _transformed: false,
    parameters: None,
    is_instanced_buffer_geometry: false,
    instance_count: buffer_geometry_infinity(),
  }
}

///|
pub impl EventSource for BufferGeometry with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for BufferGeometry with fn event_target(self) {
  BufferGeometry(self)
}

///|
pub extend BufferGeometry with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub fn BufferGeometry::get_index(self : BufferGeometry) -> GeometryAttribute? {
  self.index
}

///|
/// What `setIndex` accepts: an array of indices or an attribute; `None` clears.
pub(open) trait GeometryIndex {
  fn to_geometry_index(Self) -> GeometryAttribute?
}

///|
/// `T` is a number type: `Array[Double]` or `Array[Int]`, the same values in JS.
pub impl[T] GeometryIndex for Array[T] with fn to_geometry_index(self) {
  let index : Array[Double] = JsValue::of(self).cast()
  Some(
    Buffer(
      if array_needs_uint32(index) {
        Uint32BufferAttribute::new(index, 1)
      } else {
        Uint16BufferAttribute::new(index, 1)
      },
    ),
  )
}

///|
pub impl GeometryIndex for BufferAttribute with fn to_geometry_index(self) {
  Some(Buffer(self))
}

///|
pub impl GeometryIndex for GeometryAttribute with fn to_geometry_index(self) {
  Some(self)
}

///|
pub impl GeometryIndex for GeometryAttribute? with fn to_geometry_index(self) {
  self
}

///|
pub extend BufferAttribute with GeometryIndex::{to_geometry_index}

///|
pub extend GeometryAttribute with GeometryIndex::{to_geometry_index}

///|
pub fn[I : GeometryIndex] BufferGeometry::set_index(
  self : BufferGeometry,
  index : I,
) -> BufferGeometry {
  self.index = index.to_geometry_index()
  self
}

///|
/// `indirect_offset` holds the one offset, or several for multiple indirect draws.
pub fn BufferGeometry::set_indirect(
  self : BufferGeometry,
  indirect : BufferAttribute?,
  indirect_offset~ : Array[Int32] = [0],
) -> BufferGeometry {
  self.indirect = indirect
  self.indirect_offset = indirect_offset
  self
}

///|
pub fn BufferGeometry::get_indirect(self : BufferGeometry) -> BufferAttribute? {
  self.indirect
}

///|
pub fn BufferGeometry::get_attribute(
  self : BufferGeometry,
  name : String,
) -> GeometryAttribute? {
  self.attributes.get(name)
}

///|
pub fn[A : ToGeometryAttribute] BufferGeometry::set_attribute(
  self : BufferGeometry,
  name : String,
  attribute : A,
) -> BufferGeometry {
  self.attributes[name] = attribute.to_geometry_attribute()
  self
}

///|
pub fn BufferGeometry::delete_attribute(
  self : BufferGeometry,
  name : String,
) -> BufferGeometry {
  self.attributes.remove(name)
  self
}

///|
pub fn BufferGeometry::has_attribute(
  self : BufferGeometry,
  name : String,
) -> Bool {
  self.attributes.contains(name)
}

///|
pub fn BufferGeometry::add_group(
  self : BufferGeometry,
  start : Int32,
  count : Double,
  material_index~ : Int32 = 0,
) -> Unit {
  self.groups.push({ start, count, material_index, })
}

///|
pub fn BufferGeometry::clear_groups(self : BufferGeometry) -> Unit {
  self.groups = []
}

///|
pub fn BufferGeometry::set_draw_range(
  self : BufferGeometry,
  start : Int32,
  count : Double,
) -> Unit {
  self.draw_range.start = start
  self.draw_range.count = count
}

///|
pub fn BufferGeometry::apply_matrix4(
  self : BufferGeometry,
  matrix : @math.Matrix4,
) -> BufferGeometry {
  if self.attributes.get("position") is Some(position) {
    position.apply_matrix4(matrix)
    position.set_needs_update(true)
  }
  if self.attributes.get("normal") is Some(normal) {
    let normal_matrix = @math.Matrix3::new().get_normal_matrix(matrix)
    normal.apply_normal_matrix(normal_matrix)
    normal.set_needs_update(true)
  }
  if self.attributes.get("tangent") is Some(tangent) {
    tangent.transform_direction(matrix)
    tangent.set_needs_update(true)
  }
  if self.bounding_box is Some(_) {
    self.compute_bounding_box()
  }
  if self.bounding_sphere is Some(_) {
    self.compute_bounding_sphere()
  }
  self._transformed = true
  self
}

///|
pub fn BufferGeometry::apply_quaternion(
  self : BufferGeometry,
  q : @math.Quaternion,
) -> BufferGeometry {
  ignore(_buffer_geometry_m1.make_rotation_from_quaternion(q))
  self.apply_matrix4(_buffer_geometry_m1)
}

///|
/// Rotates the geometry around the world x-axis.
pub fn BufferGeometry::rotate_x(
  self : BufferGeometry,
  angle : Double,
) -> BufferGeometry {
  ignore(_buffer_geometry_m1.make_rotation_x(angle))
  self.apply_matrix4(_buffer_geometry_m1)
}

///|
/// Rotates the geometry around the world y-axis.
pub fn BufferGeometry::rotate_y(
  self : BufferGeometry,
  angle : Double,
) -> BufferGeometry {
  ignore(_buffer_geometry_m1.make_rotation_y(angle))
  self.apply_matrix4(_buffer_geometry_m1)
}

///|
/// Rotates the geometry around the world z-axis.
pub fn BufferGeometry::rotate_z(
  self : BufferGeometry,
  angle : Double,
) -> BufferGeometry {
  ignore(_buffer_geometry_m1.make_rotation_z(angle))
  self.apply_matrix4(_buffer_geometry_m1)
}

///|
pub fn BufferGeometry::translate(
  self : BufferGeometry,
  x : Double,
  y : Double,
  z : Double,
) -> BufferGeometry {
  ignore(_buffer_geometry_m1.make_translation(x, y, z))
  self.apply_matrix4(_buffer_geometry_m1)
}

///|
pub fn BufferGeometry::scale(
  self : BufferGeometry,
  x : Double,
  y : Double,
  z : Double,
) -> BufferGeometry {
  ignore(_buffer_geometry_m1.make_scale(x, y, z))
  self.apply_matrix4(_buffer_geometry_m1)
}

///|
pub fn BufferGeometry::look_at(
  self : BufferGeometry,
  vector : @math.Vector3,
) -> BufferGeometry {
  _buffer_geometry_obj.look_at(vector)
  _buffer_geometry_obj.update_matrix()
  self.apply_matrix4(_buffer_geometry_obj.matrix)
}

///|
pub fn BufferGeometry::center(self : BufferGeometry) -> BufferGeometry {
  self.compute_bounding_box()
  if self.bounding_box is Some(bounding_box) {
    ignore(bounding_box.get_center(_buffer_geometry_offset).negate())
  }
  self.translate(
    _buffer_geometry_offset.x,
    _buffer_geometry_offset.y,
    _buffer_geometry_offset.z,
  )
}

///|
/// `point.z || 0`: upstream also takes `Vector2` points, and NaN becomes 0.
fn buffer_geometry_point_z(z : Double) -> Double {
  if z.is_nan() {
    0.0
  } else {
    z
  }
}

///|
fn BufferGeometry::set_from_coordinates(
  self : BufferGeometry,
  count : Int32,
  x : (Int32) -> Double,
  y : (Int32) -> Double,
  z : (Int32) -> Double,
) -> BufferGeometry {
  match self.get_attribute("position") {
    None => {
      let position = []
      for i in 0..<count {
        position.push(x(i))
        position.push(y(i))
        position.push(buffer_geometry_point_z(z(i)))
      }
      ignore(
        self.set_attribute("position", Float32BufferAttribute::new(position, 3)),
      )
    }
    Some(position_attribute) => {
      // make sure data do not exceed buffer size
      let l = if count < position_attribute.count() {
        count
      } else {
        position_attribute.count()
      }
      for i in 0..<l {
        position_attribute.set_xyz(i, x(i), y(i), buffer_geometry_point_z(z(i)))
      }
      if count > position_attribute.count() {
        warn(
          "BufferGeometry: Buffer size too small for points data. Use .dispose() and create a new geometry.",
        )
      }
      position_attribute.set_needs_update(true)
    }
  }
  self
}

///|
pub fn BufferGeometry::set_from_points(
  self : BufferGeometry,
  points : Array[@math.Vector3],
) -> BufferGeometry {
  self.set_from_coordinates(
    points.length(),
    i => points[i].x,
    i => points[i].y,
    i => points[i].z,
  )
}

///|
/// `setFromPoints` with `Vector2` points.
pub fn BufferGeometry::set_from_points2(
  self : BufferGeometry,
  points : Array[@math.Vector2],
) -> BufferGeometry {
  self.set_from_coordinates(
    points.length(),
    i => points[i].x,
    i => points[i].y,
    _ => 0.0,
  )
}

///|
pub fn BufferGeometry::compute_bounding_box(self : BufferGeometry) -> Unit {
  let bounding_box = match self.bounding_box {
    Some(bounding_box) => bounding_box
    None => {
      let bounding_box = @math.Box3::new()
      self.bounding_box = Some(bounding_box)
      bounding_box
    }
  }
  let position = self.attributes.get("position")
  let morph_attributes_position = self.morph_attributes.get("position")
  if position is Some(GL(_)) {
    error(
      "BufferGeometry.computeBoundingBox(): GLBufferAttribute requires a manual bounding box.",
    )
    let infinity = buffer_geometry_infinity()
    ignore(
      bounding_box.set(
        @math.Vector3::new(-infinity, -infinity, -infinity),
        @math.Vector3::new(infinity, infinity, infinity),
      ),
    )
    return
  }
  match position {
    Some(position) => {
      ignore(box3_set_from_buffer_attribute(bounding_box, position))
      // process morph attributes if present
      if morph_attributes_position is Some(morph_attributes) {
        for morph_attribute in morph_attributes {
          ignore(
            box3_set_from_buffer_attribute(
              _buffer_geometry_box, morph_attribute,
            ),
          )
          if self.morph_targets_relative {
            ignore(
              _buffer_geometry_vector.add_vectors(
                bounding_box.min,
                _buffer_geometry_box.min,
              ),
            )
            ignore(bounding_box.expand_by_point(_buffer_geometry_vector))
            ignore(
              _buffer_geometry_vector.add_vectors(
                bounding_box.max,
                _buffer_geometry_box.max,
              ),
            )
            ignore(bounding_box.expand_by_point(_buffer_geometry_vector))
          } else {
            ignore(bounding_box.expand_by_point(_buffer_geometry_box.min))
            ignore(bounding_box.expand_by_point(_buffer_geometry_box.max))
          }
        }
      }
    }
    None => ignore(bounding_box.make_empty())
  }
  if bounding_box.min.x.is_nan() ||
    bounding_box.min.y.is_nan() ||
    bounding_box.min.z.is_nan() {
    error(
      "BufferGeometry.computeBoundingBox(): Computed min/max have NaN values. The \"position\" attribute is likely to have NaN values.",
    )
  }
}

///|
pub fn BufferGeometry::compute_bounding_sphere(self : BufferGeometry) -> Unit {
  let bounding_sphere = match self.bounding_sphere {
    Some(bounding_sphere) => bounding_sphere
    None => {
      let bounding_sphere = @math.Sphere::new()
      self.bounding_sphere = Some(bounding_sphere)
      bounding_sphere
    }
  }
  let position = self.attributes.get("position")
  let morph_attributes_position = self.morph_attributes.get("position")
  if position is Some(GL(_)) {
    error(
      "BufferGeometry.computeBoundingSphere(): GLBufferAttribute requires a manual bounding sphere.",
    )
    ignore(
      bounding_sphere.set(
        @math.Vector3::new(0.0, 0.0, 0.0),
        buffer_geometry_infinity(),
      ),
    )
    return
  }
  guard position is Some(position) else { return }
  // first, find the center of the bounding sphere
  let center = bounding_sphere.center
  ignore(box3_set_from_buffer_attribute(_buffer_geometry_box, position))
  // process morph attributes if present
  if morph_attributes_position is Some(morph_attributes) {
    for morph_attribute in morph_attributes {
      ignore(
        box3_set_from_buffer_attribute(
          _buffer_geometry_box_morph_targets, morph_attribute,
        ),
      )
      if self.morph_targets_relative {
        ignore(
          _buffer_geometry_vector.add_vectors(
            _buffer_geometry_box.min,
            _buffer_geometry_box_morph_targets.min,
          ),
        )
        ignore(_buffer_geometry_box.expand_by_point(_buffer_geometry_vector))
        ignore(
          _buffer_geometry_vector.add_vectors(
            _buffer_geometry_box.max,
            _buffer_geometry_box_morph_targets.max,
          ),
        )
        ignore(_buffer_geometry_box.expand_by_point(_buffer_geometry_vector))
      } else {
        ignore(
          _buffer_geometry_box.expand_by_point(
            _buffer_geometry_box_morph_targets.min,
          ),
        )
        ignore(
          _buffer_geometry_box.expand_by_point(
            _buffer_geometry_box_morph_targets.max,
          ),
        )
      }
    }
  }
  ignore(_buffer_geometry_box.get_center(center))
  // second, try to find a boundingSphere with a radius smaller than the
  // boundingSphere of the boundingBox: sqrt(3) smaller in the best case
  let mut max_radius_sq = 0.0
  for i in 0..<position.count() {
    ignore(_buffer_geometry_vector.from_buffer_attribute(position, i))
    max_radius_sq = utils_math_max(
      max_radius_sq,
      center.distance_to_squared(_buffer_geometry_vector),
    )
  }
  // process morph attributes if present
  if morph_attributes_position is Some(morph_attributes) {
    for morph_attribute in morph_attributes {
      let morph_targets_relative = self.morph_targets_relative
      for j in 0..<morph_attribute.count() {
        ignore(
          _buffer_geometry_vector.from_buffer_attribute(morph_attribute, j),
        )
        if morph_targets_relative {
          ignore(_buffer_geometry_offset.from_buffer_attribute(position, j))
          ignore(_buffer_geometry_vector.add(_buffer_geometry_offset))
        }
        max_radius_sq = utils_math_max(
          max_radius_sq,
          center.distance_to_squared(_buffer_geometry_vector),
        )
      }
    }
  }
  bounding_sphere.radius = max_radius_sq.sqrt()
  if bounding_sphere.radius.is_nan() {
    error(
      "BufferGeometry.computeBoundingSphere(): Computed radius is NaN. The \"position\" attribute is likely to have NaN values.",
    )
  }
}

///|
pub fn BufferGeometry::compute_tangents(self : BufferGeometry) -> Unit {
  let attributes = self.attributes
  // based on http://www.terathon.com/code/tangent.html
  // (per vertex tangents)
  guard self.index is Some(index) &&
    attributes.get("position") is Some(position_attribute) &&
    attributes.get("normal") is Some(normal_attribute) &&
    attributes.get("uv") is Some(uv_attribute) else {
    error(
      "BufferGeometry: .computeTangents() failed. Missing required attributes (index, position, normal or uv)",
    )
    return
  }
  let tangent_attribute = match self.get_attribute("tangent") {
    Some(tangent) if tangent.count() == position_attribute.count() => tangent
    _ => {
      let tangent = GeometryAttribute::Buffer(
        BufferAttribute::new(
          TypedArray::float32(4 * position_attribute.count()),
          4,
        ),
      )
      ignore(self.set_attribute("tangent", tangent))
      tangent
    }
  }
  let tan1 = []
  let tan2 = []
  let used = Array::make(position_attribute.count(), false)
  for _ in 0..<position_attribute.count() {
    tan1.push(@math.Vector3::new(0.0, 0.0, 0.0))
    tan2.push(@math.Vector3::new(0.0, 0.0, 0.0))
  }
  let v_a = @math.Vector3::new(0.0, 0.0, 0.0)
  let v_b = @math.Vector3::new(0.0, 0.0, 0.0)
  let v_c = @math.Vector3::new(0.0, 0.0, 0.0)
  let uv_a = @math.Vector2::new(0.0, 0.0)
  let uv_b = @math.Vector2::new(0.0, 0.0)
  let uv_c = @math.Vector2::new(0.0, 0.0)
  let sdir = @math.Vector3::new(0.0, 0.0, 0.0)
  let tdir = @math.Vector3::new(0.0, 0.0, 0.0)
  fn handle_triangle(a : Int32, b : Int32, c : Int32) -> Unit {
    used[a] = true
    used[b] = true
    used[c] = true
    ignore(v_a.from_buffer_attribute(position_attribute, a))
    ignore(v_b.from_buffer_attribute(position_attribute, b))
    ignore(v_c.from_buffer_attribute(position_attribute, c))
    ignore(uv_a.from_buffer_attribute(uv_attribute, a))
    ignore(uv_b.from_buffer_attribute(uv_attribute, b))
    ignore(uv_c.from_buffer_attribute(uv_attribute, c))
    ignore(v_b.sub(v_a))
    ignore(v_c.sub(v_a))
    ignore(uv_b.sub(uv_a))
    ignore(uv_c.sub(uv_a))
    let r = 1.0 / (uv_b.x * uv_c.y - uv_c.x * uv_b.y)
    // silently ignore degenerate uv triangles having coincident or colinear vertices
    if !utils_is_finite(r) {
      return
    }
    ignore(
      sdir
      .copy(v_b)
      .multiply_scalar(uv_c.y)
      .add_scaled_vector(v_c, -uv_b.y)
      .multiply_scalar(r),
    )
    ignore(
      tdir
      .copy(v_c)
      .multiply_scalar(uv_b.x)
      .add_scaled_vector(v_b, -uv_c.x)
      .multiply_scalar(r),
    )
    ignore(tan1[a].add(sdir))
    ignore(tan1[b].add(sdir))
    ignore(tan1[c].add(sdir))
    ignore(tan2[a].add(tdir))
    ignore(tan2[b].add(tdir))
    ignore(tan2[c].add(tdir))
  }

  let groups = if self.groups.is_empty() {
    [{ start: 0, count: index.count().to_double(), material_index: 0, }]
  } else {
    self.groups
  }
  for group in groups {
    let start = group.start
    let end = start.to_double() + group.count
    let mut j = start
    while j.to_double() < end {
      handle_triangle(
        index.get_x(j + 0).to_int(),
        index.get_x(j + 1).to_int(),
        index.get_x(j + 2).to_int(),
      )
      j += 3
    }
  }
  let tmp = @math.Vector3::new(0.0, 0.0, 0.0)
  let tmp2 = @math.Vector3::new(0.0, 0.0, 0.0)
  let n = @math.Vector3::new(0.0, 0.0, 0.0)
  let n2 = @math.Vector3::new(0.0, 0.0, 0.0)
  for v in 0..<position_attribute.count() {
    if used[v] {
      ignore(n.from_buffer_attribute(normal_attribute, v))
      ignore(n2.copy(n))
      let t = tan1[v]
      // Gram-Schmidt orthogonalize
      ignore(tmp.copy(t))
      ignore(tmp.sub(n.multiply_scalar(n.dot(t))).normalize())
      // Calculate handedness
      ignore(tmp2.cross_vectors(n2, t))
      let test_ = tmp2.dot(tan2[v])
      let w = if test_ < 0.0 { -1.0 } else { 1.0 }
      tangent_attribute.set_xyzw(v, tmp.x, tmp.y, tmp.z, w)
    }
  }
  self._transformed = true
}

///|
pub fn BufferGeometry::compute_vertex_normals(self : BufferGeometry) -> Unit {
  guard self.get_attribute("position") is Some(position_attribute) else {
    return
  }
  let normal_attribute = match self.get_attribute("normal") {
    Some(normal) if normal.count() == position_attribute.count() => {
      // reset existing normals to zero
      for i in 0..<normal.count() {
        normal.set_xyz(i, 0, 0, 0)
      }
      normal
    }
    _ => {
      let normal = GeometryAttribute::Buffer(
        BufferAttribute::new(
          TypedArray::float32(position_attribute.count() * 3),
          3,
        ),
      )
      ignore(self.set_attribute("normal", normal))
      normal
    }
  }
  let p_a = @math.Vector3::new(0.0, 0.0, 0.0)
  let p_b = @math.Vector3::new(0.0, 0.0, 0.0)
  let p_c = @math.Vector3::new(0.0, 0.0, 0.0)
  let n_a = @math.Vector3::new(0.0, 0.0, 0.0)
  let n_b = @math.Vector3::new(0.0, 0.0, 0.0)
  let n_c = @math.Vector3::new(0.0, 0.0, 0.0)
  let cb = @math.Vector3::new(0.0, 0.0, 0.0)
  let ab = @math.Vector3::new(0.0, 0.0, 0.0)
  match self.index {
    // indexed elements
    Some(index) => {
      let mut i = 0
      while i < index.count() {
        let v_a = index.get_x(i + 0).to_int()
        let v_b = index.get_x(i + 1).to_int()
        let v_c = index.get_x(i + 2).to_int()
        ignore(p_a.from_buffer_attribute(position_attribute, v_a))
        ignore(p_b.from_buffer_attribute(position_attribute, v_b))
        ignore(p_c.from_buffer_attribute(position_attribute, v_c))
        ignore(cb.sub_vectors(p_c, p_b))
        ignore(ab.sub_vectors(p_a, p_b))
        ignore(cb.cross(ab))
        ignore(n_a.from_buffer_attribute(normal_attribute, v_a))
        ignore(n_b.from_buffer_attribute(normal_attribute, v_b))
        ignore(n_c.from_buffer_attribute(normal_attribute, v_c))
        ignore(n_a.add(cb))
        ignore(n_b.add(cb))
        ignore(n_c.add(cb))
        normal_attribute.set_xyz(v_a, n_a.x, n_a.y, n_a.z)
        normal_attribute.set_xyz(v_b, n_b.x, n_b.y, n_b.z)
        normal_attribute.set_xyz(v_c, n_c.x, n_c.y, n_c.z)
        i += 3
      }
    }
    // non-indexed elements (unconnected triangle soup)
    None => {
      let mut i = 0
      while i < position_attribute.count() {
        ignore(p_a.from_buffer_attribute(position_attribute, i + 0))
        ignore(p_b.from_buffer_attribute(position_attribute, i + 1))
        ignore(p_c.from_buffer_attribute(position_attribute, i + 2))
        ignore(cb.sub_vectors(p_c, p_b))
        ignore(ab.sub_vectors(p_a, p_b))
        ignore(cb.cross(ab))
        normal_attribute.set_xyz(i + 0, cb.x, cb.y, cb.z)
        normal_attribute.set_xyz(i + 1, cb.x, cb.y, cb.z)
        normal_attribute.set_xyz(i + 2, cb.x, cb.y, cb.z)
        i += 3
      }
    }
  }
  self.normalize_normals()
  normal_attribute.set_needs_update(true)
}

///|
pub fn BufferGeometry::normalize_normals(self : BufferGeometry) -> Unit {
  guard self.attributes.get("normal") is Some(normals) else {
    abort("BufferGeometry.normalizeNormals(): no normal attribute")
  }
  for i in 0..<normals.count() {
    ignore(_buffer_geometry_vector.from_buffer_attribute(normals, i))
    ignore(_buffer_geometry_vector.normalize())
    normals.set_xyz(
      i,
      _buffer_geometry_vector.x,
      _buffer_geometry_vector.y,
      _buffer_geometry_vector.z,
    )
  }
}

///|
fn buffer_geometry_convert_attribute(
  attribute : GeometryAttribute,
  indices : TypedArray,
) -> BufferAttribute {
  let array = attribute.array()
  let item_size = attribute.item_size()
  let array2 = array.new_like(indices.length() * item_size)
  let mut index2 = 0
  for i in 0..<indices.length() {
    let mut index = match attribute {
      Interleaved(a) => indices.get_int(i) * a.data.stride + a.offset
      _ => indices.get_int(i) * item_size
    }
    for _ in 0..<item_size {
      array2[index2] = array[index]
      index2 += 1
      index += 1
    }
  }
  BufferAttribute::new(array2, item_size, normalized=attribute.normalized())
}

///|
/// Returns a non-indexed copy, or `self` if there is no index.
pub fn BufferGeometry::to_non_indexed(self : BufferGeometry) -> BufferGeometry {
  guard self.index is Some(index) else {
    warn(
      "BufferGeometry.toNonIndexed(): BufferGeometry is already non-indexed.",
    )
    return self
  }
  let geometry2 = BufferGeometry::new()
  let indices = index.array()
  // attributes
  for name, attribute in self.attributes {
    ignore(
      geometry2.set_attribute(
        name,
        buffer_geometry_convert_attribute(attribute, indices),
      ),
    )
  }
  // morph attributes
  for name, morph_attribute in self.morph_attributes {
    let morph_array = []
    for attribute in morph_attribute {
      morph_array.push(
        GeometryAttribute::Buffer(
          buffer_geometry_convert_attribute(attribute, indices),
        ),
      )
    }
    geometry2.morph_attributes[name] = morph_array
  }
  geometry2.morph_targets_relative = self.morph_targets_relative
  // groups
  for group in self.groups {
    geometry2.add_group(
      group.start,
      group.count,
      material_index=group.material_index,
    )
  }
  geometry2
}

///|
/// A JS `WeakMap`, for what `GeometryParameters` and `BufferGeometry` have no field for.
#external
priv type GeometryWeakTable

///|
extern "js" fn GeometryWeakTable::new() -> GeometryWeakTable = "() => new WeakMap()"

///|
extern "js" fn GeometryWeakTable::has(
  self : GeometryWeakTable,
  key : JsValue,
) -> Bool = "(table, key) => table.has(key)"

///|
extern "js" fn GeometryWeakTable::get(
  self : GeometryWeakTable,
  key : JsValue,
) -> JsValue = "(table, key) => table.get(key)"

///|
extern "js" fn GeometryWeakTable::set(
  self : GeometryWeakTable,
  key : JsValue,
  value : JsValue,
) -> Unit = "(table, key, value) => { table.set(key, value); }"

///|
/// The lazy values of each `GeometryParameters`, keyed by its `values` map.
let _buffer_geometry_lazy_values : GeometryWeakTable = GeometryWeakTable::new()

///|
/// The `toJSON` override of each geometry whose class has one.
let _buffer_geometry_to_json_hooks : GeometryWeakTable = GeometryWeakTable::new()

///|
fn GeometryParameters::lazy_values(
  self : GeometryParameters,
) -> Map[String, () -> Json]? {
  let key = JsValue::of(self.values)
  if _buffer_geometry_lazy_values.has(key) {
    Some(_buffer_geometry_lazy_values.get(key).cast())
  } else {
    None
  }
}

///|
/// Sets `parameters[ key ]` to a value serialized each time `to_json` runs, for what
/// upstream holds by reference: a source geometry, a curve, an array of points. `values`
/// keeps a `null` placeholder at `key`, which fixes the key order; the function wins over
/// it. `BufferGeometry::copy` carries the function over, as upstream's `Object.assign`
/// carries the reference.
pub fn GeometryParameters::set_lazy(
  self : GeometryParameters,
  key : String,
  value : () -> Json,
) -> Unit {
  if !self.values.contains(key) {
    self.values[key] = Json::null()
  }
  match self.lazy_values() {
    Some(lazy_values) => lazy_values[key] = value
    None =>
      _buffer_geometry_lazy_values.set(
        JsValue::of(self.values),
        JsValue::of(Map::from_array([(key, value)])),
      )
  }
}

///|
/// `parameters[ key ]` as `JSON.stringify` writes it, evaluating a lazy value.
pub fn GeometryParameters::get(
  self : GeometryParameters,
  key : String,
) -> Json? {
  guard self.values.get(key) is Some(value) else { return None }
  match self.lazy_values() {
    Some(lazy_values) if lazy_values.get(key) is Some(f) => Some(f())
    _ => Some(value)
  }
}

///|
/// All of `parameters` as `JSON.stringify` writes them, in order, evaluating lazy values.
pub fn GeometryParameters::resolved_values(
  self : GeometryParameters,
) -> Map[String, Json] {
  let lazy_values = self.lazy_values().unwrap_or(Map([]))
  let values : Map[String, Json] = Map([])
  for key, value in self.values {
    values[key] = match lazy_values.get(key) {
      Some(f) => f()
      None => value
    }
  }
  values
}

///|
/// `Object.assign( {}, source )`, carrying the lazy values over.
fn GeometryParameters::copy_values(
  source : GeometryParameters?,
) -> GeometryParameters {
  guard source is Some(source) else { return { values: Map([]), shapes: [], } }
  let parameters : GeometryParameters = {
    values: source.values.copy(),
    shapes: source.shapes.copy(),
  }
  if source.lazy_values() is Some(lazy_values) {
    _buffer_geometry_lazy_values.set(
      JsValue::of(parameters.values),
      JsValue::of(lazy_values.copy()),
    )
  }
  parameters
}

///|
/// Sets the `toJSON` override of a subclass in `geometries`, which `to_json` runs on the
/// data upstream's `super.toJSON()` returns. It belongs to the class: `clone` gives it
/// to the new geometry and `copy` keeps the target's.
pub fn BufferGeometry::set_to_json_hook(
  self : BufferGeometry,
  hook : (BufferGeometry, Map[String, Json]) -> Unit,
) -> Unit {
  _buffer_geometry_to_json_hooks.set(JsValue::of(self), JsValue::of(hook))
}

///|
fn BufferGeometry::to_json_hook(
  self : BufferGeometry,
) -> ((BufferGeometry, Map[String, Json]) -> Unit)? {
  let key = JsValue::of(self)
  if _buffer_geometry_to_json_hooks.has(key) {
    Some(_buffer_geometry_to_json_hooks.get(key).cast())
  } else {
    None
  }
}

///|
/// Upstream's `toJSON`, followed by the subclass override set with `set_to_json_hook`.
pub fn BufferGeometry::to_json(self : BufferGeometry) -> Json {
  let data = self.to_json_base()
  if self.to_json_hook() is Some(hook) {
    hook(self, data)
  }
  Json::object(data)
}

///|
/// `BufferGeometry.prototype.toJSON`, the `super.toJSON()` of a subclass.
fn BufferGeometry::to_json_base(self : BufferGeometry) -> Map[String, Json] {
  let data : Map[String, Json] = {
    "metadata": Json::object({
      "version": Json::number(4.7),
      "type": Json::string("BufferGeometry"),
      "generator": Json::string("BufferGeometry.toJSON"),
    }),
  }
  // standard BufferGeometry serialization
  data["uuid"] = Json::string(self.uuid)
  data["type"] = Json::string(
    if self.parameters is Some(_) && self._transformed {
      "BufferGeometry"
    } else {
      self.type_
    },
  )
  data["name"] = Json::string(self.name)
  if self.user_data.key_count() > 0 {
    data["userData"] = self.user_data.to_json()
  }
  if self.parameters is Some(parameters) && !self._transformed {
    for key, value in parameters.resolved_values() {
      data[key] = value
    }
    if self.is_instanced_buffer_geometry {
      self.instanced_to_json(data)
    }
    return data
  }
  // for simplicity the code assumes attributes are not shared across geometries, see #15811
  let data_attributes : Map[String, Json] = Map([])
  let data_data : Map[String, Json] = {
    "attributes": Json::object(data_attributes),
  }
  data["data"] = Json::object(data_data)
  if self.index is Some(index) {
    data_data["index"] = Json::object({
      "type": Json::string(index.array().type_name()),
      "array": json_numbers(index.array().to_array()),
    })
  }
  for key, attribute in self.attributes {
    data_attributes[key] = attribute.to_json(data=data_data)
  }
  let morph_attributes : Map[String, Json] = Map([])
  let mut has_morph_attributes = false
  for key, attribute_array in self.morph_attributes {
    let array = []
    for attribute in attribute_array {
      array.push(attribute.to_json(data=data_data))
    }
    if array.length() > 0 {
      morph_attributes[key] = Json::array(array)
      has_morph_attributes = true
    }
  }
  if has_morph_attributes {
    data_data["morphAttributes"] = Json::object(morph_attributes)
    data_data["morphTargetsRelative"] = Json::boolean(
      self.morph_targets_relative,
    )
  }
  if self.groups.length() > 0 {
    data_data["groups"] = Json::array(
      self.groups.map(group => {
        Json::object({
          "start": json_int(group.start),
          "count": @math.json_number(group.count),
          "materialIndex": json_int(group.material_index),
        })
      }),
    )
  }
  if self.bounding_sphere is Some(bounding_sphere) {
    data_data["boundingSphere"] = bounding_sphere.to_json()
  }
  if self.is_instanced_buffer_geometry {
    self.instanced_to_json(data)
  }
  data
}

///|
fn BufferGeometry::instanced_to_json(
  self : BufferGeometry,
  data : Map[String, Json],
) -> Unit {
  data["instanceCount"] = @math.json_number(self.instance_count)
  data["isInstancedBufferGeometry"] = Json::boolean(true)
}

///|
/// Keeps the class of `self`: `type_`, `parameters`, and the instanced fields.
pub fn BufferGeometry::clone(self : BufferGeometry) -> BufferGeometry {
  let geometry = BufferGeometry::new()
  geometry.type_ = self.type_
  geometry.parameters = self.parameters
  if self.to_json_hook() is Some(hook) {
    geometry.set_to_json_hook(hook)
  }
  geometry.is_instanced_buffer_geometry = self.is_instanced_buffer_geometry
  geometry.copy(self)
}

///|
/// Subclasses in `geometries` have `parameters` set and copy them, as each upstream
/// subclass's `copy` does; a plain `BufferGeometry` target does not.
pub fn BufferGeometry::copy(
  self : BufferGeometry,
  source : BufferGeometry,
) -> BufferGeometry {
  // reset
  self.index = None
  self.attributes = Map([])
  self.morph_attributes = Map([])
  self.groups = []
  self.bounding_box = None
  self.bounding_sphere = None
  // used for storing cloned, shared data
  let data : AttributeCloneData = {
    array_buffers: Map([]),
    interleaved_buffers: Map([]),
  }
  // name
  self.name = source.name
  // index
  if source.index is Some(index) {
    self.index = Some(index.clone())
  }
  // attributes
  for name, attribute in source.attributes {
    self.attributes[name] = attribute.clone(data~)
  }
  // morph attributes
  for name, morph_attribute in source.morph_attributes {
    self.morph_attributes[name] = morph_attribute.map(a => a.clone(data~))
  }
  self.morph_targets_relative = source.morph_targets_relative
  // groups
  for group in source.groups {
    self.add_group(
      group.start,
      group.count,
      material_index=group.material_index,
    )
  }
  // bounding box
  if source.bounding_box is Some(bounding_box) {
    self.bounding_box = Some(bounding_box.clone())
  }
  // bounding sphere
  if source.bounding_sphere is Some(bounding_sphere) {
    self.bounding_sphere = Some(bounding_sphere.clone())
  }
  // draw range
  self.draw_range.start = source.draw_range.start
  self.draw_range.count = source.draw_range.count
  // user data
  self.user_data = source.user_data
  // transformed flag
  self._transformed = source._transformed
  // a subclass: `this.parameters = Object.assign( {}, source.parameters )`, which is `{}`
  // for a plain source
  if self.parameters is Some(_) {
    self.parameters = Some(GeometryParameters::copy_values(source.parameters))
  }
  if self.is_instanced_buffer_geometry {
    self.instance_count = source.instance_count
  }
  self
}

///|
pub fn BufferGeometry::dispose(self : BufferGeometry) -> Unit {
  self.dispatch_event(Event::new("dispose"))
}
