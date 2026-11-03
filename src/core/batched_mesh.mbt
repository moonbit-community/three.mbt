// Upstream src/objects/BatchedMesh.js. Upstream's methods live on `Object3D`, like every
// subclass here. `set_matrix_at`, `get_matrix_at`, `set_color_at` and `get_color_at` are
// shared with `InstancedMesh`, in instanced_mesh.mbt. `toJSON` is in object3d.mbt.

///|
/// The `{ vertexStart, ... }` of `getGeometryRangeAt`.
pub(all) struct BatchedGeometryRange {
  mut vertex_start : Int32
  mut vertex_count : Int32
  mut reserved_vertex_count : Int32
  mut index_start : Int32
  mut index_count : Int32
  mut reserved_index_count : Int32
  mut start : Int32
  mut count : Int32
}

///|
fn batched_mesh_sort_opaque(a : MultiDrawItem, b : MultiDrawItem) -> Double {
  a.z - b.z
}

///|
fn batched_mesh_sort_transparent(
  a : MultiDrawItem,
  b : MultiDrawItem,
) -> Double {
  b.z - a.z
}

///|
/// Upstream `MultiDrawRenderList`: `pool` keeps the items for reuse across frames.
priv struct MultiDrawRenderList {
  mut index : Int32
  pool : Array[MultiDrawItem]
  list : Array[MultiDrawItem]
}

///|
fn MultiDrawRenderList::new() -> MultiDrawRenderList {
  { index: 0, pool: [], list: [], }
}

///|
fn MultiDrawRenderList::push(
  self : MultiDrawRenderList,
  start : Int32,
  count : Int32,
  z : Double,
  index : Int32,
) -> Unit {
  let pool = self.pool
  let list = self.list
  if self.index >= pool.length() {
    pool.push({ start: -1, count: -1, z: -1.0, index: -1, })
  }
  let item = pool[self.index]
  list.push(item)
  self.index += 1
  item.start = start
  item.count = count
  item.z = z
  item.index = index
}

///|
fn MultiDrawRenderList::reset(self : MultiDrawRenderList) -> Unit {
  self.list.clear()
  self.index = 0
}

///|
let _batched_mesh_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _batched_mesh_white_color : @math.Color = @math.Color::new(1.0, 1.0, 1.0)

///|
let _batched_mesh_frustum : @math.Frustum = @math.Frustum::new()

///|
let _batched_mesh_frustum_array : @math.FrustumArray = @math.FrustumArray::new()

///|
let _batched_mesh_box : @math.Box3 = @math.Box3::new()

///|
let _batched_mesh_sphere : @math.Sphere = @math.Sphere::new()

///|
let _batched_mesh_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _batched_mesh_camera_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _batched_mesh_forward : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _batched_mesh_temp : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _batched_mesh_render_list : MultiDrawRenderList = MultiDrawRenderList::new()

///|
let _batched_mesh_mesh : Object3D = Mesh::new()

///|
let _batched_mesh_intersects : Array[Intersection] = []

///|
extern "js" fn batched_mesh_copy_within(
  array : TypedArray,
  target : Int32,
  start : Int32,
  end : Int32,
) -> Unit = "(a, t, s, e) => { a.copyWithin(t, s, e); }"

///|
/// The attributes of a batch geometry are always plain `BufferAttribute`s.
fn batched_mesh_buffer(attribute : GeometryAttribute) -> BufferAttribute {
  guard attribute is Buffer(buffer) else {
    abort(
      "THREE.BatchedMesh: batch geometry attribute is not a BufferAttribute",
    )
  }
  buffer
}

///|
fn batched_mesh_position(geometry : BufferGeometry) -> GeometryAttribute {
  guard geometry.attributes.get("position") is Some(position) else {
    abort("THREE.BatchedMesh: geometry has no position attribute")
  }
  position
}

///|
/// Copies data from attribute `src` into `target` starting at `target_offset`.
fn batched_mesh_copy_attribute_data(
  src : GeometryAttribute,
  target : GeometryAttribute,
  target_offset : Int32,
) -> Unit {
  let item_size = target.item_size()
  if src is Interleaved(_) ||
    src.array().type_name() != target.array().type_name() {
    // use the component getters and setters if the array data cannot
    // be copied directly
    let vertex_count = src.count()
    for i in 0..<vertex_count {
      for c in 0..<item_size {
        target.set_component(i + target_offset, c, src.get_component(i, c))
      }
    }
  } else {
    // faster copy approach using typed array set function
    target.array().set_from(src.array(), offset=target_offset * item_size)
  }
  target.set_needs_update(true)
}

///|
/// Safely copies array contents to a potentially smaller array.
fn batched_mesh_copy_array_contents(
  src : TypedArray,
  target : TypedArray,
) -> Unit {
  let len = if src.length() < target.length() {
    src.length()
  } else {
    target.length()
  }
  if src.type_name() != target.type_name() {
    // if arrays are of a different type (eg due to index size increasing) then data must be per-element copied
    for i in 0..<len {
      target[i] = src[i]
    }
  } else {
    // if the arrays use the same data layout we can use a fast block copy
    target.set_from(
      TypedArray::view_by_name(
        src.type_name(),
        src.buffer(),
        byte_offset=0,
        length=len,
      ),
    )
  }
}

///|
pub fn BatchedMesh::new(
  max_instance_count : Int32,
  max_vertex_count : Int32,
  max_index_count? : Int32,
  material? : MaterialSlot,
) -> Object3D {
  let batched : BatchedMesh = {
    per_object_frustum_culled: true,
    sort_objects: true,
    bounding_box: None,
    bounding_sphere: None,
    custom_sort: None,
    // stores visible, active, and geometry id per instance and reserved buffer ranges for geometries
    _instance_info: [],
    _geometry_info: [],
    // instance, geometry ids that have been set as inactive, and are available to be overwritten
    _available_instance_ids: [],
    _available_geometry_ids: [],
    // used to track where the next point is that geometry should be inserted
    _next_index_start: 0,
    _next_vertex_start: 0,
    _geometry_count: 0,
    // flags
    _visibility_changed: true,
    _geometry_initialized: false,
    // cached user options
    _max_instance_count: max_instance_count,
    _max_vertex_count: max_vertex_count,
    _max_index_count: max_index_count.unwrap_or(max_vertex_count * 2),
    // buffers for multi draw
    _multi_draw_counts: TypedArray::int32(max_instance_count),
    _multi_draw_starts: TypedArray::int32(max_instance_count),
    _multi_draw_count: 0,
    _multi_draw_bytes_per_element: 1,
    // buffers for instanced draws, consecutive draws with the same range are merged
    _merged_draw_counts: TypedArray::int32(max_instance_count),
    _merged_draw_starts: TypedArray::int32(max_instance_count),
    _merged_draw_instance_counts: TypedArray::int32(max_instance_count),
    _merged_draw_count: 0,
    // Local matrix per geometry by using data texture
    _matrices_texture: None,
    _indirect_texture: None,
    _colors_texture: None,
    // previous frame matrices for motion vectors, created by the renderer
    _previous_matrices_texture: None,
  }
  let object = mesh_make(
    Some(BufferGeometry::new()),
    material,
    BatchedMesh(batched),
    "Mesh",
  )
  object.update_morph_targets()
  batched_mesh_init_matrices_texture(batched)
  batched_mesh_init_indirect_texture(batched)
  // `onBeforeRender` and `onBeforeShadow` are methods upstream, fields here
  object.on_before_render = (renderer, _, camera, geometry, material, _) => {
    if renderer.get("isWebGPURenderer").strict_equal(JsValue::of(true)) {
      if batched._visibility_changed ||
        batched.per_object_frustum_culled ||
        batched.sort_objects {
        batched_mesh_indirect_texture(batched).set_needs_update(true)
      }
    } else {
      object._update_draw_parameters(camera, geometry, material)
    }
  }
  object.on_before_shadow = (
    renderer,
    _,
    _,
    shadow_camera,
    geometry,
    depth_material,
    _,
  ) => {
    if !renderer.get("isWebGPURenderer").strict_equal(JsValue::of(true)) {
      object._update_draw_parameters(shadow_camera, geometry, depth_material)
    }
  }
  object
}

///|
fn Object3D::batched_mesh_data(self : Object3D) -> BatchedMesh {
  guard self.kind is Mesh({ kind: BatchedMesh(batched), .. }) else {
    abort("Object3D: not a BatchedMesh")
  }
  batched
}

///|
fn batched_mesh_matrices_texture(batched : BatchedMesh) -> Texture {
  guard batched._matrices_texture is Some(texture) else {
    abort("THREE.BatchedMesh: matrices texture is not initialized")
  }
  texture
}

///|
fn batched_mesh_indirect_texture(batched : BatchedMesh) -> Texture {
  guard batched._indirect_texture is Some(texture) else {
    abort("THREE.BatchedMesh: indirect texture is not initialized")
  }
  texture
}

///|
/// `this._matricesTexture.image.data`.
fn batched_mesh_matrices(batched : BatchedMesh) -> TypedArray {
  objects_texture_data(batched_mesh_matrices_texture(batched))
}

///|
pub fn Object3D::max_instance_count(self : Object3D) -> Int32 {
  self.batched_mesh_data()._max_instance_count
}

///|
pub fn Object3D::instance_count(self : Object3D) -> Int32 {
  let batched = self.batched_mesh_data()
  batched._instance_info.length() - batched._available_instance_ids.length()
}

///|
pub fn Object3D::unused_vertex_count(self : Object3D) -> Int32 {
  let batched = self.batched_mesh_data()
  batched._max_vertex_count - batched._next_vertex_start
}

///|
pub fn Object3D::unused_index_count(self : Object3D) -> Int32 {
  let batched = self.batched_mesh_data()
  batched._max_index_count - batched._next_index_start
}

///|
fn batched_mesh_init_matrices_texture(batched : BatchedMesh) -> Unit {
  // layout (1 matrix = 4 pixels)
  //      RGBA RGBA RGBA RGBA (=> column1, column2, column3, column4)
  //  with  8x8  pixel texture max   16 matrices * 4 pixels =  (8 * 8)
  //       16x16 pixel texture max   64 matrices * 4 pixels = (16 * 16)
  //       32x32 pixel texture max  256 matrices * 4 pixels = (32 * 32)
  //       64x64 pixel texture max 1024 matrices * 4 pixels = (64 * 64)
  let size = objects_matrices_texture_size(batched._max_instance_count)
  // 4 floats per RGBA pixel
  let matrices_array = TypedArray::float32(size * size * 4)
  batched._matrices_texture = Some(
    DataTexture::new(
      data=matrices_array,
      width=size,
      height=size,
      format=RGBAFormat,
      type_=FloatType,
    ),
  )
}

///|
fn batched_mesh_init_indirect_texture(batched : BatchedMesh) -> Unit {
  let size = batched._max_instance_count.to_double().sqrt().ceil().to_int()
  let indirect_array = TypedArray::uint32(size * size)
  batched._indirect_texture = Some(
    DataTexture::new(
      data=indirect_array,
      width=size,
      height=size,
      format=RedIntegerFormat,
      type_=UnsignedIntType,
    ),
  )
}

///|
fn batched_mesh_init_colors_texture(batched : BatchedMesh) -> Texture {
  let size = batched._max_instance_count.to_double().sqrt().ceil().to_int()
  // 4 floats per RGBA pixel initialized to white
  let colors_array = TypedArray::float32(size * size * 4)
  colors_array.fill(1.0)
  let colors_texture = DataTexture::new(
    data=colors_array,
    width=size,
    height=size,
    format=RGBAFormat,
    type_=FloatType,
  )
  colors_texture.color_space = @math.color_management.working_color_space
  batched._colors_texture = Some(colors_texture)
  colors_texture
}

///|
fn batched_mesh_initialize_geometry(
  object : Object3D,
  batched : BatchedMesh,
  reference : BufferGeometry,
) -> Unit {
  let geometry = object.mesh_data().geometry
  let max_vertex_count = batched._max_vertex_count
  let max_index_count = batched._max_index_count
  if !batched._geometry_initialized {
    for attribute_name, src_attribute in reference.attributes {
      let item_size = src_attribute.item_size()
      let dst_array = src_attribute
        .array()
        .new_like(max_vertex_count * item_size)
      let dst_attribute = BufferAttribute::new(
        dst_array,
        item_size,
        normalized=src_attribute.normalized(),
      )
      ignore(geometry.set_attribute(attribute_name, dst_attribute))
    }
    if reference.get_index() is Some(_) {
      // Reserve last u16 index for primitive restart.
      let index_array = if max_vertex_count > 65535 {
        TypedArray::uint32(max_index_count)
      } else {
        TypedArray::uint16(max_index_count)
      }
      ignore(geometry.set_index(BufferAttribute::new(index_array, 1)))
    }
    batched._geometry_initialized = true
  }
}

///|
/// Make sure the geometry is compatible with the existing combined geometry attributes.
fn batched_mesh_validate_geometry(
  object : Object3D,
  geometry : BufferGeometry,
) -> Unit {
  // check to ensure the geometries are using consistent attributes and indices
  let batch_geometry = object.mesh_data().geometry
  if (geometry.get_index() is Some(_)) !=
    (batch_geometry.get_index() is Some(_)) {
    abort("THREE.BatchedMesh: All geometries must consistently have \"index\".")
  }
  for attribute_name, dst_attribute in batch_geometry.attributes {
    guard geometry.get_attribute(attribute_name) is Some(src_attribute) else {
      abort(
        "THREE.BatchedMesh: Added geometry missing \"\{attribute_name}\". All geometries must have consistent attributes.",
      )
    }
    if src_attribute.item_size() != dst_attribute.item_size() ||
      src_attribute.normalized() != dst_attribute.normalized() {
      abort(
        "THREE.BatchedMesh: Added geometry attribute \"\{attribute_name}\" has an inconsistent itemSize or normalized value.",
      )
    }
  }
}

///|
/// Aborts unless `instance_id` names an active instance.
pub fn Object3D::validate_instance_id(
  self : Object3D,
  instance_id : Int32,
) -> Unit {
  let instance_info = self.batched_mesh_data()._instance_info
  if instance_id < 0 ||
    instance_id >= instance_info.length() ||
    !instance_info[instance_id].active {
    abort(
      "THREE.BatchedMesh: Invalid instanceId \{instance_id}. Instance is either out of range or has been deleted.",
    )
  }
}

///|
/// Aborts unless `geometry_id` names an active geometry.
pub fn Object3D::validate_geometry_id(
  self : Object3D,
  geometry_id : Int32,
) -> Unit {
  let geometry_info_list = self.batched_mesh_data()._geometry_info
  if geometry_id < 0 ||
    geometry_id >= geometry_info_list.length() ||
    !geometry_info_list[geometry_id].active {
    abort(
      "THREE.BatchedMesh: Invalid geometryId \{geometry_id}. Geometry is either out of range or has been deleted.",
    )
  }
}

///|
/// Takes over the sort of the draw list; `None` restores the default.
pub fn Object3D::set_custom_sort(
  self : Object3D,
  func : ((Array[MultiDrawItem], Object3D) -> Unit)?,
) -> Object3D {
  self.batched_mesh_data().custom_sort = func
  self
}

///|
fn batched_mesh_compute_bounding_box(object : Object3D) -> Unit {
  let batched = object.batched_mesh_data()
  let bounding_box = match batched.bounding_box {
    Some(bounding_box) => bounding_box
    None => {
      let bounding_box = @math.Box3::new()
      batched.bounding_box = Some(bounding_box)
      bounding_box
    }
  }
  let instance_info = batched._instance_info
  ignore(bounding_box.make_empty())
  for i, info in instance_info {
    if !info.active {
      continue
    }
    let geometry_id = info.geometry_index
    ignore(object.get_matrix_at(i, _batched_mesh_matrix))
    guard object.get_bounding_box_at(geometry_id, _batched_mesh_box)
      is Some(box_) else {
      abort("THREE.BatchedMesh: Invalid geometryId \{geometry_id}.")
    }
    ignore(box_.apply_matrix4(_batched_mesh_matrix))
    ignore(bounding_box.union(_batched_mesh_box))
  }
}

///|
fn batched_mesh_compute_bounding_sphere(object : Object3D) -> Unit {
  let batched = object.batched_mesh_data()
  let bounding_sphere = match batched.bounding_sphere {
    Some(bounding_sphere) => bounding_sphere
    None => {
      let bounding_sphere = @math.Sphere::new()
      batched.bounding_sphere = Some(bounding_sphere)
      bounding_sphere
    }
  }
  let instance_info = batched._instance_info
  ignore(bounding_sphere.make_empty())
  for i, info in instance_info {
    if !info.active {
      continue
    }
    let geometry_id = info.geometry_index
    ignore(object.get_matrix_at(i, _batched_mesh_matrix))
    guard object.get_bounding_sphere_at(geometry_id, _batched_mesh_sphere)
      is Some(sphere) else {
      abort("THREE.BatchedMesh: Invalid geometryId \{geometry_id}.")
    }
    ignore(sphere.apply_matrix4(_batched_mesh_matrix))
    ignore(bounding_sphere.union(_batched_mesh_sphere))
  }
}

///|
/// Adds an instance of a geometry and returns its id.
pub fn Object3D::add_instance(self : Object3D, geometry_id : Int32) -> Int32 {
  let batched = self.batched_mesh_data()
  let at_capacity = batched._instance_info.length() >=
    batched._max_instance_count
  // ensure we're not over geometry
  if at_capacity && batched._available_instance_ids.length() == 0 {
    abort("THREE.BatchedMesh: Maximum item count reached.")
  }
  let instance_info : BatchedInstanceInfo = {
    visible: true,
    active: true,
    geometry_index: geometry_id,
  }
  // Prioritize using previously freed instance ids
  let draw_id = if batched._available_instance_ids.length() > 0 {
    batched._available_instance_ids.sort()
    let draw_id = batched._available_instance_ids.remove(0)
    batched._instance_info[draw_id] = instance_info
    draw_id
  } else {
    let draw_id = batched._instance_info.length()
    batched._instance_info.push(instance_info)
    draw_id
  }
  let matrices_texture = batched_mesh_matrices_texture(batched)
  typed_array_write_matrix4(
    objects_texture_data(matrices_texture),
    _batched_mesh_matrix.identity(),
    draw_id * 16,
  )
  matrices_texture.set_needs_update(true)
  if batched._colors_texture is Some(colors_texture) {
    typed_array_write_color(
      objects_texture_data(colors_texture),
      _batched_mesh_white_color,
      draw_id * 4,
    )
    colors_texture.set_needs_update(true)
  }
  batched._visibility_changed = true
  draw_id
}

///|
/// Adds a geometry and returns its id. The reserved counts default to its own.
pub fn Object3D::add_geometry(
  self : Object3D,
  geometry : BufferGeometry,
  reserved_vertex_count~ : Int32 = -1,
  reserved_index_count~ : Int32 = -1,
) -> Int32 {
  let batched = self.batched_mesh_data()
  batched_mesh_initialize_geometry(self, batched, geometry)
  batched_mesh_validate_geometry(self, geometry)
  let geometry_info : BatchedGeometryInfo = {
    // geometry information
    vertex_start: -1,
    vertex_count: -1,
    reserved_vertex_count: -1,
    index_start: -1,
    index_count: -1,
    reserved_index_count: -1,
    // draw range information
    start: -1,
    count: -1,
    // state
    bounding_box: None,
    bounding_sphere: None,
    active: true,
  }
  let geometry_info_list = batched._geometry_info
  geometry_info.vertex_start = batched._next_vertex_start
  geometry_info.reserved_vertex_count = if reserved_vertex_count == -1 {
    batched_mesh_position(geometry).count()
  } else {
    reserved_vertex_count
  }
  if geometry.get_index() is Some(index) {
    geometry_info.index_start = batched._next_index_start
    geometry_info.reserved_index_count = if reserved_index_count == -1 {
      index.count()
    } else {
      reserved_index_count
    }
  }
  if (
      geometry_info.index_start != -1 &&
      geometry_info.index_start + geometry_info.reserved_index_count >
      batched._max_index_count
    ) ||
    geometry_info.vertex_start + geometry_info.reserved_vertex_count >
    batched._max_vertex_count {
    abort(
      "THREE.BatchedMesh: Reserved space request exceeds the maximum buffer size.",
    )
  }
  // update id
  let geometry_id = if batched._available_geometry_ids.length() > 0 {
    batched._available_geometry_ids.sort()
    let geometry_id = batched._available_geometry_ids.remove(0)
    geometry_info_list[geometry_id] = geometry_info
    geometry_id
  } else {
    let geometry_id = batched._geometry_count
    batched._geometry_count += 1
    geometry_info_list.push(geometry_info)
    geometry_id
  }
  // update the geometry
  ignore(self.set_geometry_at(geometry_id, geometry))
  // increment the next geometry position
  batched._next_index_start = geometry_info.index_start +
    geometry_info.reserved_index_count
  batched._next_vertex_start = geometry_info.vertex_start +
    geometry_info.reserved_vertex_count
  geometry_id
}

///|
/// Replaces the data of a geometry in its reserved space.
pub fn Object3D::set_geometry_at(
  self : Object3D,
  geometry_id : Int32,
  geometry : BufferGeometry,
) -> Int32 {
  let batched = self.batched_mesh_data()
  if geometry_id >= batched._geometry_count {
    abort("THREE.BatchedMesh: Maximum geometry count reached.")
  }
  batched_mesh_validate_geometry(self, geometry)
  let batch_geometry = self.mesh_data().geometry
  let dst_index = batch_geometry.get_index()
  let src_index = geometry.get_index()
  let geometry_info = batched._geometry_info[geometry_id]
  let position = batched_mesh_position(geometry)
  if (
      dst_index is Some(_) &&
      src_index is Some(src_index) &&
      src_index.count() > geometry_info.reserved_index_count
    ) ||
    position.count() > geometry_info.reserved_vertex_count {
    abort(
      "THREE.BatchedMesh: Reserved space not large enough for provided geometry.",
    )
  }
  // copy geometry buffer data over
  let vertex_start = geometry_info.vertex_start
  let reserved_vertex_count = geometry_info.reserved_vertex_count
  geometry_info.vertex_count = position.count()
  for attribute_name, dst_attribute in batch_geometry.attributes {
    // copy attribute data
    guard geometry.get_attribute(attribute_name) is Some(src_attribute) else {
      abort("THREE.BatchedMesh: Added geometry missing \"\{attribute_name}\".")
    }
    batched_mesh_copy_attribute_data(src_attribute, dst_attribute, vertex_start)
    // fill the rest in with zeroes
    let item_size = src_attribute.item_size()
    for i = src_attribute.count(); i < reserved_vertex_count; i = i + 1 {
      let index = vertex_start + i
      for c in 0..<item_size {
        dst_attribute.set_component(index, c, 0.0)
      }
    }
    dst_attribute.set_needs_update(true)
    batched_mesh_buffer(dst_attribute).add_update_range(
      vertex_start * item_size,
      reserved_vertex_count * item_size,
    )
  }
  // copy index
  if dst_index is Some(dst_index) {
    guard src_index is Some(src_index) else {
      abort(
        "THREE.BatchedMesh: All geometries must consistently have \"index\".",
      )
    }
    let index_start = geometry_info.index_start
    let reserved_index_count = geometry_info.reserved_index_count
    geometry_info.index_count = src_index.count()
    // copy index data over
    for i in 0..<src_index.count() {
      dst_index.set_x(
        index_start + i,
        vertex_start.to_double() + src_index.get_x(i),
      )
    }
    // fill the rest in with zeroes
    for i = src_index.count(); i < reserved_index_count; i = i + 1 {
      dst_index.set_x(index_start + i, vertex_start.to_double())
    }
    dst_index.set_needs_update(true)
    batched_mesh_buffer(dst_index).add_update_range(
      index_start,
      geometry_info.reserved_index_count,
    )
  }
  // update the draw range
  if dst_index is Some(_) {
    geometry_info.start = geometry_info.index_start
    geometry_info.count = geometry_info.index_count
  } else {
    geometry_info.start = geometry_info.vertex_start
    geometry_info.count = geometry_info.vertex_count
  }
  // store the bounding boxes
  geometry_info.bounding_box = geometry.bounding_box.map(box_ => box_.clone())
  geometry_info.bounding_sphere = geometry.bounding_sphere.map(sphere => {
    sphere.clone()
  })
  batched._visibility_changed = true
  geometry_id
}

///|
/// Frees a geometry and its instances. Unknown ids are ignored.
pub fn Object3D::delete_geometry(
  self : Object3D,
  geometry_id : Int32,
) -> Object3D {
  let batched = self.batched_mesh_data()
  let geometry_info_list = batched._geometry_info
  if geometry_id >= geometry_info_list.length() ||
    !geometry_info_list[geometry_id].active {
    return self
  }
  // delete any instances associated with this geometry
  for i, info in batched._instance_info {
    if info.active && info.geometry_index == geometry_id {
      ignore(self.delete_instance(i))
    }
  }
  geometry_info_list[geometry_id].active = false
  batched._available_geometry_ids.push(geometry_id)
  batched._visibility_changed = true
  self
}

///|
pub fn Object3D::delete_instance(
  self : Object3D,
  instance_id : Int32,
) -> Object3D {
  self.validate_instance_id(instance_id)
  let batched = self.batched_mesh_data()
  batched._instance_info[instance_id].active = false
  batched._available_instance_ids.push(instance_id)
  batched._visibility_changed = true
  self
}

///|
/// Compacts the geometry buffers, removing the gaps of deleted geometries.
pub fn Object3D::optimize(self : Object3D) -> Object3D {
  let batched = self.batched_mesh_data()
  // track the next indices to copy data to
  let mut next_vertex_start = 0
  let mut next_index_start = 0
  // Iterate over all geometry ranges in order sorted from earliest in the geometry buffer to latest
  // in the geometry buffer. Because draw range objects can be reused there is no guarantee of their order.
  let geometry_info_list = batched._geometry_info
  let indices : Array[Int32] = Array::makei(geometry_info_list.length(), i => i)
  objects_stable_sort(indices, (a, b) => {
    (geometry_info_list[a].vertex_start - geometry_info_list[b].vertex_start).to_double()
  })
  let geometry = self.mesh_data().geometry
  for i in 0..<geometry_info_list.length() {
    // if a geometry range is inactive then don't copy anything
    let geometry_info = geometry_info_list[indices[i]]
    if !geometry_info.active {
      continue
    }
    // if a geometry contains an index buffer then shift it, as well
    if geometry.index is Some(index) {
      if geometry_info.index_start != next_index_start {
        let index_start = geometry_info.index_start
        let reserved_index_count = geometry_info.reserved_index_count
        let array = index.array()
        // shift the index pointers based on how the vertex data will shift
        // adjusting the index must happen first so the original vertex start value is available
        let element_delta = (next_vertex_start - geometry_info.vertex_start).to_double()
        for j = index_start; j < index_start + reserved_index_count; j = j + 1 {
          array[j] = array[j] + element_delta
        }
        batched_mesh_copy_within(
          array,
          next_index_start,
          index_start,
          index_start + reserved_index_count,
        )
        batched_mesh_buffer(index).add_update_range(
          next_index_start, reserved_index_count,
        )
        index.set_needs_update(true)
        geometry_info.index_start = next_index_start
      }
      next_index_start = next_index_start + geometry_info.reserved_index_count
    }
    // if a geometry needs to be moved then copy attribute data to overwrite unused space
    if geometry_info.vertex_start != next_vertex_start {
      let vertex_start = geometry_info.vertex_start
      let reserved_vertex_count = geometry_info.reserved_vertex_count
      for _, attribute in geometry.attributes {
        let array = attribute.array()
        let item_size = attribute.item_size()
        batched_mesh_copy_within(
          array,
          next_vertex_start * item_size,
          vertex_start * item_size,
          (vertex_start + reserved_vertex_count) * item_size,
        )
        batched_mesh_buffer(attribute).add_update_range(
          next_vertex_start * item_size,
          reserved_vertex_count * item_size,
        )
        attribute.set_needs_update(true)
      }
      geometry_info.vertex_start = next_vertex_start
    }
    next_vertex_start = next_vertex_start + geometry_info.reserved_vertex_count
    geometry_info.start = if geometry.index is Some(_) {
      geometry_info.index_start
    } else {
      geometry_info.vertex_start
    }
  }
  batched._next_index_start = next_index_start
  batched._next_vertex_start = next_vertex_start
  batched._visibility_changed = true
  self
}

///|
/// `target` holds the bounds of a geometry; `None` for an unknown id.
pub fn Object3D::get_bounding_box_at(
  self : Object3D,
  geometry_id : Int32,
  target : @math.Box3,
) -> @math.Box3? {
  let batched = self.batched_mesh_data()
  if geometry_id >= batched._geometry_count {
    return None
  }
  // compute bounding box
  let geometry = self.mesh_data().geometry
  let geometry_info = batched._geometry_info[geometry_id]
  let bounding_box = match geometry_info.bounding_box {
    Some(bounding_box) => bounding_box
    None => {
      let box_ = @math.Box3::new()
      let index = geometry.index
      let position = batched_mesh_position(geometry)
      for i = geometry_info.start
          i < geometry_info.start + geometry_info.count
          i = i + 1 {
        let iv = match index {
          Some(index) => index.get_x(i).to_int()
          None => i
        }
        ignore(
          box_.expand_by_point(
            _batched_mesh_vector.from_buffer_attribute(position, iv),
          ),
        )
      }
      geometry_info.bounding_box = Some(box_)
      box_
    }
  }
  ignore(target.copy(bounding_box))
  Some(target)
}

///|
/// `target` holds the bounds of a geometry; `None` for an unknown id.
pub fn Object3D::get_bounding_sphere_at(
  self : Object3D,
  geometry_id : Int32,
  target : @math.Sphere,
) -> @math.Sphere? {
  let batched = self.batched_mesh_data()
  if geometry_id >= batched._geometry_count {
    return None
  }
  // compute bounding sphere
  let geometry = self.mesh_data().geometry
  let geometry_info = batched._geometry_info[geometry_id]
  let bounding_sphere = match geometry_info.bounding_sphere {
    Some(bounding_sphere) => bounding_sphere
    None => {
      let sphere = @math.Sphere::new()
      ignore(self.get_bounding_box_at(geometry_id, _batched_mesh_box))
      ignore(_batched_mesh_box.get_center(sphere.center))
      let index = geometry.index
      let position = batched_mesh_position(geometry)
      let mut max_radius_sq = 0.0
      for i = geometry_info.start
          i < geometry_info.start + geometry_info.count
          i = i + 1 {
        let iv = match index {
          Some(index) => index.get_x(i).to_int()
          None => i
        }
        ignore(_batched_mesh_vector.from_buffer_attribute(position, iv))
        max_radius_sq = utils_math_max(
          max_radius_sq,
          sphere.center.distance_to_squared(_batched_mesh_vector),
        )
      }
      sphere.radius = max_radius_sq.sqrt()
      geometry_info.bounding_sphere = Some(sphere)
      sphere
    }
  }
  ignore(target.copy(bounding_sphere))
  Some(target)
}

///|
fn batched_mesh_set_matrix_at(
  object : Object3D,
  batched : BatchedMesh,
  instance_id : Int32,
  matrix : @math.Matrix4,
) -> Unit {
  object.validate_instance_id(instance_id)
  let matrices_texture = batched_mesh_matrices_texture(batched)
  typed_array_write_matrix4(
    objects_texture_data(matrices_texture),
    matrix,
    instance_id * 16,
  )
  matrices_texture.set_needs_update(true)
}

///|
fn batched_mesh_colors_for_write(batched : BatchedMesh) -> Texture {
  match batched._colors_texture {
    Some(colors_texture) => colors_texture
    None => batched_mesh_init_colors_texture(batched)
  }
}

///|
fn batched_mesh_set_color_at(
  object : Object3D,
  batched : BatchedMesh,
  instance_id : Int32,
  color : @math.Color,
) -> Unit {
  object.validate_instance_id(instance_id)
  let colors_texture = batched_mesh_colors_for_write(batched)
  typed_array_write_color(
    objects_texture_data(colors_texture),
    color,
    instance_id * 4,
  )
  colors_texture.set_needs_update(true)
}

///|
/// `setColorAt` with a `Vector4`, whose `w` is stored too.
pub fn Object3D::set_color_at_vector4(
  self : Object3D,
  instance_id : Int32,
  color : @math.Vector4,
) -> Object3D {
  let batched = self.batched_mesh_data()
  self.validate_instance_id(instance_id)
  let colors_texture = batched_mesh_colors_for_write(batched)
  let array = objects_texture_data(colors_texture)
  let offset = instance_id * 4
  array[offset] = color.x
  array[offset + 1] = color.y
  array[offset + 2] = color.z
  array[offset + 3] = color.w
  colors_texture.set_needs_update(true)
  self
}

///|
fn batched_mesh_get_color_at(
  object : Object3D,
  batched : BatchedMesh,
  instance_id : Int32,
  color : @math.Color,
) -> @math.Color {
  object.validate_instance_id(instance_id)
  match batched._colors_texture {
    None => color.set_rgb(1.0, 1.0, 1.0)
    Some(colors_texture) =>
      typed_array_read_color(
        objects_texture_data(colors_texture),
        color,
        instance_id * 4,
      )
  }
}

///|
/// `getColorAt` with a `Vector4`.
pub fn Object3D::get_color_at_vector4(
  self : Object3D,
  instance_id : Int32,
  color : @math.Vector4,
) -> @math.Vector4 {
  let batched = self.batched_mesh_data()
  self.validate_instance_id(instance_id)
  match batched._colors_texture {
    None => color.set(1.0, 1.0, 1.0, 1.0)
    Some(colors_texture) => {
      let array = objects_texture_data(colors_texture)
      let offset = instance_id * 4
      color.x = array[offset]
      color.y = array[offset + 1]
      color.z = array[offset + 2]
      color.w = array[offset + 3]
      color
    }
  }
}

///|
pub fn Object3D::set_visible_at(
  self : Object3D,
  instance_id : Int32,
  visible : Bool,
) -> Object3D {
  let batched = self.batched_mesh_data()
  self.validate_instance_id(instance_id)
  if batched._instance_info[instance_id].visible == visible {
    return self
  }
  batched._instance_info[instance_id].visible = visible
  batched._visibility_changed = true
  self
}

///|
pub fn Object3D::get_visible_at(self : Object3D, instance_id : Int32) -> Bool {
  self.validate_instance_id(instance_id)
  self.batched_mesh_data()._instance_info[instance_id].visible
}

///|
pub fn Object3D::set_geometry_id_at(
  self : Object3D,
  instance_id : Int32,
  geometry_id : Int32,
) -> Object3D {
  self.validate_instance_id(instance_id)
  self.validate_geometry_id(geometry_id)
  let batched = self.batched_mesh_data()
  batched._instance_info[instance_id].geometry_index = geometry_id
  batched._visibility_changed = true
  self
}

///|
pub fn Object3D::get_geometry_id_at(
  self : Object3D,
  instance_id : Int32,
) -> Int32 {
  self.validate_instance_id(instance_id)
  self.batched_mesh_data()._instance_info[instance_id].geometry_index
}

///|
pub fn Object3D::get_geometry_range_at(
  self : Object3D,
  geometry_id : Int32,
  target? : BatchedGeometryRange,
) -> BatchedGeometryRange {
  self.validate_geometry_id(geometry_id)
  let geometry_info = self.batched_mesh_data()._geometry_info[geometry_id]
  let target = match target {
    Some(target) => target
    None =>
      {
        vertex_start: 0,
        vertex_count: 0,
        reserved_vertex_count: 0,
        index_start: 0,
        index_count: 0,
        reserved_index_count: 0,
        start: 0,
        count: 0,
      }
  }
  target.vertex_start = geometry_info.vertex_start
  target.vertex_count = geometry_info.vertex_count
  target.reserved_vertex_count = geometry_info.reserved_vertex_count
  target.index_start = geometry_info.index_start
  target.index_count = geometry_info.index_count
  target.reserved_index_count = geometry_info.reserved_index_count
  target.start = geometry_info.start
  target.count = geometry_info.count
  target
}

///|
/// Resizes the instance buffers. Aborts if ids above the new limit are in use.
pub fn Object3D::set_instance_count(
  self : Object3D,
  max_instance_count : Int32,
) -> Unit {
  let batched = self.batched_mesh_data()
  // shrink the available instances as much as possible
  let available_instance_ids = batched._available_instance_ids
  let instance_info = batched._instance_info
  available_instance_ids.sort()
  while available_instance_ids.length() > 0 &&
        available_instance_ids[available_instance_ids.length() - 1] ==
        instance_info.length() - 1 {
    ignore(instance_info.pop())
    ignore(available_instance_ids.pop())
  }
  // throw an error if it can't be shrunk to the desired size
  if max_instance_count < instance_info.length() {
    abort(
      "THREE.BatchedMesh: Instance ids outside the range \{max_instance_count} are being used. Cannot shrink instance count.",
    )
  }
  // copy the multi draw counts
  let multi_draw_counts = TypedArray::int32(max_instance_count)
  let multi_draw_starts = TypedArray::int32(max_instance_count)
  batched_mesh_copy_array_contents(
    batched._multi_draw_counts,
    multi_draw_counts,
  )
  batched_mesh_copy_array_contents(
    batched._multi_draw_starts,
    multi_draw_starts,
  )
  batched._multi_draw_counts = multi_draw_counts
  batched._multi_draw_starts = multi_draw_starts
  let merged_draw_counts = TypedArray::int32(max_instance_count)
  let merged_draw_starts = TypedArray::int32(max_instance_count)
  let merged_draw_instance_counts = TypedArray::int32(max_instance_count)
  batched_mesh_copy_array_contents(
    batched._merged_draw_counts,
    merged_draw_counts,
  )
  batched_mesh_copy_array_contents(
    batched._merged_draw_starts,
    merged_draw_starts,
  )
  batched_mesh_copy_array_contents(
    batched._merged_draw_instance_counts,
    merged_draw_instance_counts,
  )
  batched._merged_draw_counts = merged_draw_counts
  batched._merged_draw_starts = merged_draw_starts
  batched._merged_draw_instance_counts = merged_draw_instance_counts
  batched._max_instance_count = max_instance_count
  // update texture data for instance sampling
  let indirect_texture = batched_mesh_indirect_texture(batched)
  let matrices_texture = batched_mesh_matrices_texture(batched)
  let colors_texture = batched._colors_texture
  indirect_texture.dispose()
  batched_mesh_init_indirect_texture(batched)
  batched_mesh_copy_array_contents(
    objects_texture_data(indirect_texture),
    objects_texture_data(batched_mesh_indirect_texture(batched)),
  )
  matrices_texture.dispose()
  batched_mesh_init_matrices_texture(batched)
  batched_mesh_copy_array_contents(
    objects_texture_data(matrices_texture),
    batched_mesh_matrices(batched),
  )
  if colors_texture is Some(colors_texture) {
    colors_texture.dispose()
    let new_colors_texture = batched_mesh_init_colors_texture(batched)
    batched_mesh_copy_array_contents(
      objects_texture_data(colors_texture),
      objects_texture_data(new_colors_texture),
    )
  }
  if batched._previous_matrices_texture is Some(previous_matrices_texture) {
    previous_matrices_texture.dispose()
    batched._previous_matrices_texture = None
  }
}

///|
/// Resizes the geometry buffers. Aborts if reserved ranges reach past the new limits.
pub fn Object3D::set_geometry_size(
  self : Object3D,
  max_vertex_count : Int32,
  max_index_count : Int32,
) -> Unit {
  let batched = self.batched_mesh_data()
  let mesh = self.mesh_data()
  // Check if we can shrink to the requested vertex attribute size
  let valid_ranges = batched._geometry_info.filter(info => info.active)
  // `Math.max()` of nothing is -Infinity
  let mut required_vertex_length = -buffer_geometry_infinity()
  for range in valid_ranges {
    required_vertex_length = utils_math_max(
      required_vertex_length,
      (range.vertex_start + range.reserved_vertex_count).to_double(),
    )
  }
  if required_vertex_length > max_vertex_count.to_double() {
    abort(
      "THREE.BatchedMesh: Geometry vertex values are being used outside the range \{max_vertex_count}. Cannot shrink further.",
    )
  }
  // Check if we can shrink to the requested index attribute size
  if mesh.geometry.index is Some(_) {
    let mut required_index_length = -buffer_geometry_infinity()
    for range in valid_ranges {
      required_index_length = utils_math_max(
        required_index_length,
        (range.index_start + range.reserved_index_count).to_double(),
      )
    }
    if required_index_length > max_index_count.to_double() {
      abort(
        "THREE.BatchedMesh: Geometry index values are being used outside the range \{max_index_count}. Cannot shrink further.",
      )
    }
  }
  // dispose of the previous geometry
  let old_geometry = mesh.geometry
  old_geometry.dispose()
  // recreate the geometry needed based on the previous variant
  batched._max_vertex_count = max_vertex_count
  batched._max_index_count = max_index_count
  if batched._geometry_initialized {
    batched._geometry_initialized = false
    mesh.geometry = BufferGeometry::new()
    batched_mesh_initialize_geometry(self, batched, old_geometry)
  }
  // copy data from the previous geometry
  let geometry = mesh.geometry
  if old_geometry.index is Some(old_index) && geometry.index is Some(index) {
    batched_mesh_copy_array_contents(old_index.array(), index.array())
  }
  for key, old_attribute in old_geometry.attributes {
    guard geometry.attributes.get(key) is Some(attribute) else {
      abort("THREE.BatchedMesh: geometry lost attribute \"\{key}\"")
    }
    batched_mesh_copy_array_contents(old_attribute.array(), attribute.array())
  }
  batched._visibility_changed = true
}

///|
fn batched_mesh_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let batched = object.batched_mesh_data()
  let source = object.mesh_data()
  let matrix_world = object.matrix_world
  let batch_geometry = source.geometry
  // iterate over each geometry
  let scratch = _batched_mesh_mesh.mesh_data()
  let scratch_geometry = scratch.geometry
  let idle_material = scratch.material
  scratch.material = source.material
  scratch_geometry.index = batch_geometry.index
  scratch_geometry.attributes = batch_geometry.attributes
  let bounding_box = match scratch_geometry.bounding_box {
    Some(bounding_box) => bounding_box
    None => {
      let bounding_box = @math.Box3::new()
      scratch_geometry.bounding_box = Some(bounding_box)
      bounding_box
    }
  }
  let bounding_sphere = match scratch_geometry.bounding_sphere {
    Some(bounding_sphere) => bounding_sphere
    None => {
      let bounding_sphere = @math.Sphere::new()
      scratch_geometry.bounding_sphere = Some(bounding_sphere)
      bounding_sphere
    }
  }
  for i, info in batched._instance_info {
    if !info.visible || !info.active {
      continue
    }
    let geometry_id = info.geometry_index
    let geometry_info = batched._geometry_info[geometry_id]
    scratch_geometry.set_draw_range(
      geometry_info.start,
      geometry_info.count.to_double(),
    )
    // get the intersects
    ignore(
      object
      .get_matrix_at(i, _batched_mesh_mesh.matrix_world)
      .premultiply(matrix_world),
    )
    ignore(object.get_bounding_box_at(geometry_id, bounding_box))
    ignore(object.get_bounding_sphere_at(geometry_id, bounding_sphere))
    _batched_mesh_mesh.raycast(raycaster, _batched_mesh_intersects)
    // add batch id to the intersects
    for intersect in _batched_mesh_intersects {
      intersect.object = object
      intersect.batch_id = Some(i)
      intersects.push(intersect)
    }
    _batched_mesh_intersects.clear()
  }
  scratch.material = idle_material
  scratch_geometry.index = None
  scratch_geometry.attributes = Map([])
  scratch_geometry.set_draw_range(0, buffer_geometry_infinity())
}

///|
/// `image.data = image.data.slice()`. As upstream, the image object is the one shared
/// through `source` with the texture this one was cloned from.
fn batched_mesh_detach_texture_data(texture : Texture) -> Unit {
  guard texture.source.data is DataImage(image) else {
    abort("Texture has no typed array image")
  }
  image.data = Some(objects_texture_data(texture).slice())
}

///|
/// Upstream `copy( source )` ignores `recursive`, so children are always copied.
fn batched_mesh_copy(object : Object3D, source : Object3D) -> Unit {
  mesh_copy(object, source, true)
  let target = object.batched_mesh_data()
  let source_batched = source.batched_mesh_data()
  object.mesh_data().geometry = source.mesh_data().geometry.clone()
  target.per_object_frustum_culled = source_batched.per_object_frustum_culled
  target.sort_objects = source_batched.sort_objects
  target.bounding_box = source_batched.bounding_box.map(box_ => box_.clone())
  target.bounding_sphere = source_batched.bounding_sphere.map(sphere => {
    sphere.clone()
  })
  target._geometry_info = source_batched._geometry_info.map(info => {
    ..info,
    bounding_box: info.bounding_box.map(box_ => box_.clone()),
    bounding_sphere: info.bounding_sphere.map(sphere => sphere.clone()),
  })
  target._instance_info = source_batched._instance_info.map(info => { ..info, })
  target._available_instance_ids = source_batched._available_instance_ids.copy()
  target._available_geometry_ids = source_batched._available_geometry_ids.copy()
  target._next_index_start = source_batched._next_index_start
  target._next_vertex_start = source_batched._next_vertex_start
  target._geometry_count = source_batched._geometry_count
  target._max_instance_count = source_batched._max_instance_count
  target._max_vertex_count = source_batched._max_vertex_count
  target._max_index_count = source_batched._max_index_count
  target._geometry_initialized = source_batched._geometry_initialized
  target._multi_draw_counts = source_batched._multi_draw_counts.slice()
  target._multi_draw_starts = source_batched._multi_draw_starts.slice()
  target._multi_draw_bytes_per_element = source_batched._multi_draw_bytes_per_element
  target._merged_draw_counts = source_batched._merged_draw_counts.slice()
  target._merged_draw_starts = source_batched._merged_draw_starts.slice()
  target._merged_draw_instance_counts = source_batched._merged_draw_instance_counts.slice()
  let indirect_texture = batched_mesh_indirect_texture(source_batched).clone()
  batched_mesh_detach_texture_data(indirect_texture)
  target._indirect_texture = Some(indirect_texture)
  let matrices_texture = batched_mesh_matrices_texture(source_batched).clone()
  batched_mesh_detach_texture_data(matrices_texture)
  target._matrices_texture = Some(matrices_texture)
  match source_batched._colors_texture {
    Some(source_colors_texture) => {
      let colors_texture = source_colors_texture.clone()
      batched_mesh_detach_texture_data(colors_texture)
      target._colors_texture = Some(colors_texture)
    }
    None => target._colors_texture = None
  }
}

///|
fn batched_mesh_dispose(object : Object3D, batched : BatchedMesh) -> Unit {
  // Assuming the geometry is not shared with other meshes
  object.mesh_data().geometry.dispose()
  batched_mesh_matrices_texture(batched).dispose()
  batched._matrices_texture = None
  batched_mesh_indirect_texture(batched).dispose()
  batched._indirect_texture = None
  if batched._colors_texture is Some(colors_texture) {
    colors_texture.dispose()
    batched._colors_texture = None
  }
  if batched._previous_matrices_texture is Some(previous_matrices_texture) {
    previous_matrices_texture.dispose()
    batched._previous_matrices_texture = None
  }
}

///|
fn batched_mesh_intersects_sphere(
  frustum : FrustumRef,
  sphere : @math.Sphere,
) -> Bool {
  match frustum {
    Single(frustum) => frustum.intersects_sphere(sphere)
    Array(frustum) => frustum.intersects_sphere(sphere)
  }
}

///|
/// Records one draw; `index` is the instance id for the indirect texture.
fn batched_mesh_record_draw(
  batched : BatchedMesh,
  indirect_array : TypedArray,
  start : Double,
  count : Double,
  index : Int32,
  merged : Bool,
  multi_draw_count : Int32,
  merged_draw_count : Int32,
) -> Int32 {
  let mut merged_draw_count = merged_draw_count
  if merged {
    let merged_draw_starts = batched._merged_draw_starts
    let merged_draw_counts = batched._merged_draw_counts
    let merged_draw_instance_counts = batched._merged_draw_instance_counts
    if merged_draw_count > 0 &&
      merged_draw_starts[merged_draw_count - 1] == start &&
      merged_draw_counts[merged_draw_count - 1] == count {
      merged_draw_instance_counts[merged_draw_count - 1] = merged_draw_instance_counts[merged_draw_count -
        1] +
        1.0
    } else {
      merged_draw_starts[merged_draw_count] = start
      merged_draw_counts[merged_draw_count] = count
      merged_draw_instance_counts[merged_draw_count] = 1.0
      merged_draw_count += 1
    }
  } else {
    batched._multi_draw_starts[multi_draw_count] = start
    batched._multi_draw_counts[multi_draw_count] = count
  }
  indirect_array[multi_draw_count] = index.to_double()
  merged_draw_count
}

///|
/// Upstream `_updateDrawParameters`; `draw_format` is `"multiDraw"` or `"merged"`.
pub fn Object3D::_update_draw_parameters(
  self : Object3D,
  camera : Object3D,
  geometry : BufferGeometry,
  material : Material,
  draw_format~ : String = "multiDraw",
) -> Unit {
  let batched = self.batched_mesh_data()
  // if visibility has not changed and frustum culling and object sorting is not required
  // then skip iterating over all items
  if !batched._visibility_changed &&
    !batched.per_object_frustum_culled &&
    !batched.sort_objects {
    return
  }
  // the indexed version of the multi draw function requires specifying the start
  // offset in bytes.
  let mut bytes_per_element = match geometry.get_index() {
    None => 1
    Some(index) => index.array().bytes_per_element()
  }
  // the "wireframe" attribute implicitly creates a line attribute in the renderer, which is double
  // the vertices to draw (3 lines per triangle) so we multiply the draw counts / starts and make
  // assumptions about the index buffer byte size.
  let mut multi_draw_multiplier = 1
  if material.wireframe is Some(true) {
    multi_draw_multiplier = 2
    bytes_per_element = if batched_mesh_position(geometry).count() > 65535 {
      4
    } else {
      2
    }
  }
  let instance_info = batched._instance_info
  let geometry_info_list = batched._geometry_info
  let per_object_frustum_culled = batched.per_object_frustum_culled
  let indirect_texture = batched_mesh_indirect_texture(batched)
  let indirect_array = objects_texture_data(indirect_texture)
  let is_array_camera = camera.is_array_camera()
  let frustum : FrustumRef = if is_array_camera {
    Array(_batched_mesh_frustum_array)
  } else {
    Single(_batched_mesh_frustum)
  }
  // prepare the frustum in the local frame
  if per_object_frustum_culled {
    if is_array_camera {
      ignore(
        frustum_array_set_from_array_camera(_batched_mesh_frustum_array, camera),
      )
    } else {
      ignore(
        _batched_mesh_matrix
        .multiply_matrices(
          camera.projection_matrix(),
          camera.matrix_world_inverse(),
        )
        .multiply(self.matrix_world),
      )
      let data = camera.camera_data()
      ignore(
        _batched_mesh_frustum.set_from_projection_matrix(
          _batched_mesh_matrix,
          coordinate_system=data.coordinate_system,
          reversed_depth=data._reversed_depth,
        ),
      )
    }
  }
  let bytes = bytes_per_element.to_double()
  let multiplier = multi_draw_multiplier.to_double()
  let merged = draw_format == "merged"
  let mut multi_draw_count = 0
  let mut merged_draw_count = 0
  if batched.sort_objects {
    // get the camera position in the local frame
    ignore(_batched_mesh_matrix.copy(self.matrix_world).invert())
    ignore(
      _batched_mesh_camera_position
      .set_from_matrix_position(camera.matrix_world)
      .apply_matrix4(_batched_mesh_matrix),
    )
    ignore(
      _batched_mesh_forward
      .set(0.0, 0.0, -1.0)
      .transform_direction(camera.matrix_world)
      .transform_direction(_batched_mesh_matrix),
    )
    for i, info in instance_info {
      if info.visible && info.active {
        let geometry_id = info.geometry_index
        // get the bounds in world space
        ignore(self.get_matrix_at(i, _batched_mesh_matrix))
        ignore(self.get_bounding_sphere_at(geometry_id, _batched_mesh_sphere))
        ignore(_batched_mesh_sphere.apply_matrix4(_batched_mesh_matrix))
        // determine whether the batched geometry is within the frustum
        let mut culled = false
        if per_object_frustum_culled {
          culled = !batched_mesh_intersects_sphere(
            frustum, _batched_mesh_sphere,
          )
        }
        if !culled {
          // get the distance from camera used for sorting
          let geometry_info = geometry_info_list[geometry_id]
          let z = _batched_mesh_temp
            .sub_vectors(
              _batched_mesh_sphere.center,
              _batched_mesh_camera_position,
            )
            .dot(_batched_mesh_forward)
          _batched_mesh_render_list.push(
            geometry_info.start,
            geometry_info.count,
            z,
            i,
          )
        }
      }
    }
    // Sort the draw ranges and prep for rendering
    let list = _batched_mesh_render_list.list
    match batched.custom_sort {
      None =>
        objects_stable_sort(
          list,
          if material.transparent {
            batched_mesh_sort_transparent
          } else {
            batched_mesh_sort_opaque
          },
        )
      Some(custom_sort) => custom_sort(list, camera)
    }
    for item in list {
      let start = item.start.to_double() * bytes * multiplier
      let count = item.count.to_double() * multiplier
      merged_draw_count = batched_mesh_record_draw(
        batched,
        indirect_array,
        start,
        count,
        item.index,
        merged,
        multi_draw_count,
        merged_draw_count,
      )
      multi_draw_count += 1
    }
    _batched_mesh_render_list.reset()
  } else {
    for i, info in instance_info {
      if info.visible && info.active {
        let geometry_id = info.geometry_index
        // determine whether the batched geometry is within the frustum
        let mut culled = false
        if per_object_frustum_culled {
          // get the bounds in world space
          ignore(self.get_matrix_at(i, _batched_mesh_matrix))
          ignore(self.get_bounding_sphere_at(geometry_id, _batched_mesh_sphere))
          ignore(_batched_mesh_sphere.apply_matrix4(_batched_mesh_matrix))
          culled = !batched_mesh_intersects_sphere(
            frustum, _batched_mesh_sphere,
          )
        }
        if !culled {
          let geometry_info = geometry_info_list[geometry_id]
          let start = geometry_info.start.to_double() * bytes * multiplier
          let count = geometry_info.count.to_double() * multiplier
          merged_draw_count = batched_mesh_record_draw(
            batched, indirect_array, start, count, i, merged, multi_draw_count, merged_draw_count,
          )
          multi_draw_count += 1
        }
      }
    }
  }
  indirect_texture.set_needs_update(true)
  batched._multi_draw_count = multi_draw_count
  batched._merged_draw_count = merged_draw_count
  batched._multi_draw_bytes_per_element = bytes_per_element
  batched._visibility_changed = false
}
