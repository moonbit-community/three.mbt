// Upstream src/core/Object3D.js.
//
// Overridable methods come in three layers (see extension.mbt): `m` dispatches to the
// extension, `m_kind` dispatches on `kind` to a `hook_*` function in the class's file,
// and `m_base` is upstream's `Object3D.prototype.m`, which a hook calls as `super.m`.

///|
let _object3d_id : Ref[Int32] = Ref(0)

///|
let _object3d_v1 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _object3d_q1 : @math.Quaternion = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)

///|
let _object3d_m1 : @math.Matrix4 = @math.Matrix4::new()

///|
let _object3d_target : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _object3d_position : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _object3d_scale : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _object3d_quaternion : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _object3d_x_axis : @math.Vector3 = @math.Vector3::new(1.0, 0.0, 0.0)

///|
let _object3d_y_axis : @math.Vector3 = @math.Vector3::new(0.0, 1.0, 0.0)

///|
let _object3d_z_axis : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 1.0)

///|
let _object3d_added_event : Event = Event::new("added")

///|
let _object3d_removed_event : Event = Event::new("removed")

///|
let _object3d_child_added_event : Event = Event::new("childadded")

///|
let _object3d_child_removed_event : Event = Event::new("childremoved")

///|
/// Upstream `Object3D.DEFAULT_UP`.
pub let object3d_default_up : @math.Vector3 = @math.Vector3::new(0.0, 1.0, 0.0)

///|
/// Upstream `Object3D.DEFAULT_MATRIX_AUTO_UPDATE`.
pub let object3d_default_matrix_auto_update : Ref[Bool] = Ref(true)

///|
/// Upstream `Object3D.DEFAULT_MATRIX_WORLD_AUTO_UPDATE`.
pub let object3d_default_matrix_world_auto_update : Ref[Bool] = Ref(true)

///|
/// Creates a plain `Object3D`; subclass constructors pass `kind` and `type_`.
pub fn Object3D::new(
  kind~ : Object3DKind = Base,
  type_~ : String = "Object3D",
) -> Object3D {
  let id = _object3d_id.val
  _object3d_id.val += 1
  let position = @math.Vector3::new(0.0, 0.0, 0.0)
  let rotation = @math.Euler::new(0.0, 0.0, 0.0)
  let quaternion = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
  let scale = @math.Vector3::new(1.0, 1.0, 1.0)
  ignore(
    rotation.on_change(() => {
      ignore(quaternion.set_from_euler(rotation, update=false))
    }),
  )
  ignore(
    quaternion.on_change(() => {
      ignore(rotation.set_from_quaternion(quaternion, update=false))
    }),
  )
  {
    id,
    dispatcher: EventDispatcher::new(),
    uuid: @math.generate_uuid(),
    name: "",
    type_,
    parent: None,
    children: [],
    up: object3d_default_up.clone(),
    position,
    rotation,
    quaternion,
    scale,
    model_view_matrix: @math.Matrix4::new(),
    normal_matrix: @math.Matrix3::new(),
    matrix: @math.Matrix4::new(),
    matrix_world: @math.Matrix4::new(),
    matrix_auto_update: object3d_default_matrix_auto_update.val,
    matrix_world_auto_update: object3d_default_matrix_world_auto_update.val,
    matrix_world_needs_update: false,
    layers: Layers::new(),
    visible: true,
    cast_shadow: false,
    receive_shadow: false,
    frustum_culled: true,
    render_order: 0,
    animations: [],
    custom_depth_material: None,
    custom_distance_material: None,
    static_: false,
    user_data: JsValue::object(),
    pivot: None,
    on_before_shadow: (_, _, _, _, _, _, _) => (),
    on_after_shadow: (_, _, _, _, _, _, _) => (),
    on_before_render: (_, _, _, _, _, _) => (),
    on_after_render: (_, _, _, _, _, _) => (),
    kind,
    extension: None,
  }
}

///|
pub impl EventSource for Object3D with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for Object3D with fn event_target(self) {
  Object3D(self)
}

///|
pub extend Object3D with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub fn Object3D::apply_matrix4(self : Object3D, matrix : @math.Matrix4) -> Unit {
  if self.matrix_auto_update {
    self.update_matrix()
  }
  ignore(self.matrix.premultiply(matrix))
  ignore(self.matrix.decompose(self.position, self.quaternion, self.scale))
  if self.pivot is Some(pivot) {
    // the matrix maps the pivot to position + pivot, see updateMatrix()
    ignore(self.position.copy(pivot).apply_matrix4(self.matrix).sub(pivot))
  }
}

///|
pub fn Object3D::apply_quaternion(
  self : Object3D,
  q : @math.Quaternion,
) -> Object3D {
  ignore(self.quaternion.premultiply(q))
  self
}

///|
pub fn Object3D::set_rotation_from_axis_angle(
  self : Object3D,
  axis : @math.Vector3,
  angle : Double,
) -> Unit {
  // assumes axis is normalized
  ignore(self.quaternion.set_from_axis_angle(axis, angle))
}

///|
pub fn Object3D::set_rotation_from_euler(
  self : Object3D,
  euler : @math.Euler,
) -> Unit {
  ignore(self.quaternion.set_from_euler(euler, update=true))
}

///|
pub fn Object3D::set_rotation_from_matrix(
  self : Object3D,
  m : @math.Matrix4,
) -> Unit {
  // assumes the upper 3x3 of m is a pure rotation matrix (i.e, unscaled)
  ignore(self.quaternion.set_from_rotation_matrix(m))
}

///|
pub fn Object3D::set_rotation_from_quaternion(
  self : Object3D,
  q : @math.Quaternion,
) -> Unit {
  // assumes q is normalized
  ignore(self.quaternion.copy(q))
}

///|
pub fn Object3D::rotate_on_axis(
  self : Object3D,
  axis : @math.Vector3,
  angle : Double,
) -> Object3D {
  // rotate object on axis in object space
  // axis is assumed to be normalized
  ignore(_object3d_q1.set_from_axis_angle(axis, angle))
  ignore(self.quaternion.multiply(_object3d_q1))
  self
}

///|
pub fn Object3D::rotate_on_world_axis(
  self : Object3D,
  axis : @math.Vector3,
  angle : Double,
) -> Object3D {
  // rotate object on axis in world space
  // axis is assumed to be normalized
  // method assumes no rotated parent
  ignore(_object3d_q1.set_from_axis_angle(axis, angle))
  ignore(self.quaternion.premultiply(_object3d_q1))
  self
}

///|
pub fn Object3D::rotate_x(self : Object3D, angle : Double) -> Object3D {
  self.rotate_on_axis(_object3d_x_axis, angle)
}

///|
pub fn Object3D::rotate_y(self : Object3D, angle : Double) -> Object3D {
  self.rotate_on_axis(_object3d_y_axis, angle)
}

///|
pub fn Object3D::rotate_z(self : Object3D, angle : Double) -> Object3D {
  self.rotate_on_axis(_object3d_z_axis, angle)
}

///|
pub fn Object3D::translate_on_axis(
  self : Object3D,
  axis : @math.Vector3,
  distance : Double,
) -> Object3D {
  // translate object by distance along axis in object space
  // axis is assumed to be normalized
  ignore(_object3d_v1.copy(axis).apply_quaternion(self.quaternion))
  ignore(self.position.add(_object3d_v1.multiply_scalar(distance)))
  self
}

///|
pub fn Object3D::translate_x(self : Object3D, distance : Double) -> Object3D {
  self.translate_on_axis(_object3d_x_axis, distance)
}

///|
pub fn Object3D::translate_y(self : Object3D, distance : Double) -> Object3D {
  self.translate_on_axis(_object3d_y_axis, distance)
}

///|
pub fn Object3D::translate_z(self : Object3D, distance : Double) -> Object3D {
  self.translate_on_axis(_object3d_z_axis, distance)
}

///|
pub fn Object3D::local_to_world(
  self : Object3D,
  vector : @math.Vector3,
) -> @math.Vector3 {
  self.update_world_matrix(true, false)
  vector.apply_matrix4(self.matrix_world)
}

///|
pub fn Object3D::world_to_local(
  self : Object3D,
  vector : @math.Vector3,
) -> @math.Vector3 {
  self.update_world_matrix(true, false)
  vector.apply_matrix4(_object3d_m1.copy(self.matrix_world).invert())
}

///|
/// Rotates the object to face a point in world space.
pub fn Object3D::look_at(self : Object3D, target : @math.Vector3) -> Unit {
  ignore(_object3d_target.copy(target))
  self.look_at_target()
}

///|
/// `lookAt( x, y, z )`.
pub fn Object3D::look_at_xyz(
  self : Object3D,
  x : Double,
  y : Double,
  z : Double,
) -> Unit {
  ignore(_object3d_target.set(x, y, z))
  self.look_at_target()
}

///|
fn Object3D::look_at_target(self : Object3D) -> Unit {
  // This method does not support objects having non-uniformly-scaled parent(s)
  let parent = self.parent
  self.update_world_matrix(true, false)
  ignore(_object3d_position.set_from_matrix_position(self.matrix_world))
  if self.is_camera() || self.is_light() {
    ignore(_object3d_m1.look_at(_object3d_position, _object3d_target, self.up))
  } else {
    ignore(_object3d_m1.look_at(_object3d_target, _object3d_position, self.up))
  }
  ignore(self.quaternion.set_from_rotation_matrix(_object3d_m1))
  if parent is Some(parent) {
    ignore(_object3d_m1.extract_rotation(parent.matrix_world))
    ignore(_object3d_q1.set_from_rotation_matrix(_object3d_m1))
    ignore(self.quaternion.premultiply(_object3d_q1.invert()))
  }
}

///|
pub fn Object3D::add(self : Object3D, object : Object3D) -> Object3D {
  if physical_equal(object, self) {
    error("Object3D.add: object can't be added as a child of itself.")
    return self
  }
  ignore(object.remove_from_parent())
  object.parent = Some(self)
  self.children.push(object)
  object.dispatch_event(_object3d_added_event)
  _object3d_child_added_event.child = Some(object)
  self.dispatch_event(_object3d_child_added_event)
  _object3d_child_added_event.child = None
  self
}

///|
/// `add( a, b, ... )`.
pub fn Object3D::add_all(
  self : Object3D,
  objects : Array[Object3D],
) -> Object3D {
  for object in objects {
    ignore(self.add(object))
  }
  self
}

///|
pub fn Object3D::remove(self : Object3D, object : Object3D) -> Object3D {
  let index = object3d_index_of(self.children, object)
  if index != -1 {
    object.parent = None
    ignore(self.children.remove(index))
    object.dispatch_event(_object3d_removed_event)
    _object3d_child_removed_event.child = Some(object)
    self.dispatch_event(_object3d_child_removed_event)
    _object3d_child_removed_event.child = None
  }
  self
}

///|
/// `remove( a, b, ... )`.
pub fn Object3D::remove_all(
  self : Object3D,
  objects : Array[Object3D],
) -> Object3D {
  for object in objects {
    ignore(self.remove(object))
  }
  self
}

///|
fn object3d_index_of(array : Array[Object3D], object : Object3D) -> Int32 {
  for i, item in array {
    if physical_equal(item, object) {
      return i
    }
  }
  -1
}

///|
pub fn Object3D::remove_from_parent(self : Object3D) -> Object3D {
  if self.parent is Some(parent) {
    ignore(parent.remove(self))
  }
  self
}

///|
pub fn Object3D::clear(self : Object3D) -> Object3D {
  self.remove_all(self.children.copy())
}

///|
pub fn Object3D::attach(self : Object3D, object : Object3D) -> Object3D {
  // adds object as a child of this, while maintaining the object's world transform
  // Note: This method does not support scene graphs having non-uniformly-scaled nodes(s)
  self.update_world_matrix(true, false)
  ignore(_object3d_m1.copy(self.matrix_world).invert())
  if object.parent is Some(parent) {
    parent.update_world_matrix(true, false)
    ignore(_object3d_m1.multiply(parent.matrix_world))
  }
  object.apply_matrix4(_object3d_m1)
  ignore(object.remove_from_parent())
  object.parent = Some(self)
  self.children.push(object)
  object.update_world_matrix(false, true)
  object.dispatch_event(_object3d_added_event)
  _object3d_child_added_event.child = Some(object)
  self.dispatch_event(_object3d_child_added_event)
  _object3d_child_added_event.child = None
  self
}

///|
pub fn Object3D::get_object_by_id(self : Object3D, id : Int32) -> Object3D? {
  self.get_object_by_property("id", json_int(id))
}

///|
pub fn Object3D::get_object_by_name(
  self : Object3D,
  name : String,
) -> Object3D? {
  self.get_object_by_property("name", Json::string(name))
}

///|
/// The value `self[ name ]` for the scalar properties of `Object3D`, by upstream name.
fn Object3D::scalar_property(self : Object3D, name : String) -> Json? {
  match name {
    "id" => Some(json_int(self.id))
    "uuid" => Some(Json::string(self.uuid))
    "name" => Some(Json::string(self.name))
    "type" => Some(Json::string(self.type_))
    "visible" => Some(Json::boolean(self.visible))
    "castShadow" => Some(Json::boolean(self.cast_shadow))
    "receiveShadow" => Some(Json::boolean(self.receive_shadow))
    "frustumCulled" => Some(Json::boolean(self.frustum_culled))
    "renderOrder" => Some(@math.json_number(self.render_order))
    "static" => Some(Json::boolean(self.static_))
    "matrixAutoUpdate" => Some(Json::boolean(self.matrix_auto_update))
    "matrixWorldAutoUpdate" =>
      Some(Json::boolean(self.matrix_world_auto_update))
    "matrixWorldNeedsUpdate" =>
      Some(Json::boolean(self.matrix_world_needs_update))
    _ => None
  }
}

///|
/// Searches this object and its descendants. MoonBit has no `this[ name ]`, so `name`
/// is one of the scalar properties of `Object3D`, by upstream name.
pub fn Object3D::get_object_by_property(
  self : Object3D,
  name : String,
  value : Json,
) -> Object3D? {
  if self.scalar_property(name) is Some(own) && own == value {
    return Some(self)
  }
  for child in self.children {
    if child.get_object_by_property(name, value) is Some(object) {
      return Some(object)
    }
  }
  None
}

///|
/// See `get_object_by_property` for `name`.
pub fn Object3D::get_objects_by_property(
  self : Object3D,
  name : String,
  value : Json,
  result~ : Array[Object3D] = [],
) -> Array[Object3D] {
  if self.scalar_property(name) is Some(own) && own == value {
    result.push(self)
  }
  for child in self.children {
    ignore(child.get_objects_by_property(name, value, result~))
  }
  result
}

///|
pub fn Object3D::get_world_position(
  self : Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  self.update_world_matrix(true, false)
  target.set_from_matrix_position(self.matrix_world)
}

///|
pub fn Object3D::get_world_quaternion(
  self : Object3D,
  target : @math.Quaternion,
) -> @math.Quaternion {
  self.update_world_matrix(true, false)
  ignore(
    self.matrix_world.decompose(_object3d_position, target, _object3d_scale),
  )
  target
}

///|
pub fn Object3D::get_world_scale(
  self : Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  self.update_world_matrix(true, false)
  ignore(
    self.matrix_world.decompose(
      _object3d_position, _object3d_quaternion, target,
    ),
  )
  target
}

///|
pub fn Object3D::get_world_direction(
  self : Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  match self.extension {
    Some(extension) => extension.get_world_direction(self, target)
    None => self.get_world_direction_kind(target)
  }
}

///|
pub fn Object3D::get_world_direction_kind(
  self : Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  match self.kind {
    Camera(_) => hook_camera_get_world_direction(self, target)
    _ => self.get_world_direction_base(target)
  }
}

///|
pub fn Object3D::get_world_direction_base(
  self : Object3D,
  target : @math.Vector3,
) -> @math.Vector3 {
  self.update_world_matrix(true, false)
  let e = self.matrix_world.elements
  target.set(e[8], e[9], e[10]).normalize()
}

///|
/// Collects the intersections of a ray with this object.
pub fn Object3D::raycast(
  self : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  match self.extension {
    Some(extension) => extension.raycast(self, raycaster, intersects)
    None => self.raycast_kind(raycaster, intersects)
  }
}

///|
pub fn Object3D::raycast_kind(
  self : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  match self.kind {
    Mesh(_) => hook_mesh_raycast(self, raycaster, intersects)
    Line(_) => hook_line_raycast(self, raycaster, intersects)
    Points(_) => hook_points_raycast(self, raycaster, intersects)
    Sprite(_) => hook_sprite_raycast(self, raycaster, intersects)
    LOD(_) => hook_lod_raycast(self, raycaster, intersects)
    Base
    | Group
    | ClippingGroup(_)
    | Bone
    | Camera(_)
    | CubeCamera(_)
    | Light(_)
    | Scene(_) => ()
  }
}

///|
pub fn Object3D::intersects_frustum(
  self : Object3D,
  frustum : FrustumRef,
) -> Bool {
  match self.extension {
    Some(extension) => extension.intersects_frustum(self, frustum)
    None => self.intersects_frustum_kind(frustum)
  }
}

///|
pub fn Object3D::intersects_frustum_kind(
  self : Object3D,
  frustum : FrustumRef,
) -> Bool {
  match self.kind {
    Mesh(_) => hook_mesh_intersects_frustum(self, frustum)
    Line(_) => hook_line_intersects_frustum(self, frustum)
    Points(_) => hook_points_intersects_frustum(self, frustum)
    Sprite(_) => hook_sprite_intersects_frustum(self, frustum)
    Base
    | Group
    | ClippingGroup(_)
    | Bone
    | LOD(_)
    | Camera(_)
    | CubeCamera(_)
    | Light(_)
    | Scene(_) => true
  }
}

///|
pub fn Object3D::traverse(
  self : Object3D,
  callback : (Object3D) -> Unit,
) -> Unit {
  callback(self)
  for child in self.children {
    child.traverse(callback)
  }
}

///|
pub fn Object3D::traverse_visible(
  self : Object3D,
  callback : (Object3D) -> Unit,
) -> Unit {
  if !self.visible {
    return
  }
  callback(self)
  for child in self.children {
    child.traverse_visible(callback)
  }
}

///|
pub fn Object3D::traverse_ancestors(
  self : Object3D,
  callback : (Object3D) -> Unit,
) -> Unit {
  if self.parent is Some(parent) {
    callback(parent)
    parent.traverse_ancestors(callback)
  }
}

///|
pub fn Object3D::update_matrix(self : Object3D) -> Unit {
  ignore(self.matrix.compose(self.position, self.quaternion, self.scale))
  if self.pivot is Some(pivot) {
    let px = pivot.x
    let py = pivot.y
    let pz = pivot.z
    let te = self.matrix.elements
    te[12] = te[12] + (px - te[0] * px - te[4] * py - te[8] * pz)
    te[13] = te[13] + (py - te[1] * px - te[5] * py - te[9] * pz)
    te[14] = te[14] + (pz - te[2] * px - te[6] * py - te[10] * pz)
  }
  self.matrix_world_needs_update = true
}

///|
pub fn Object3D::update_matrix_world(
  self : Object3D,
  force~ : Bool = false,
) -> Unit {
  match self.extension {
    Some(extension) => extension.update_matrix_world(self, force)
    None => self.update_matrix_world_kind(force)
  }
}

///|
pub fn Object3D::update_matrix_world_kind(
  self : Object3D,
  force : Bool,
) -> Unit {
  match self.kind {
    Camera(_) => hook_camera_update_matrix_world(self, force)
    Mesh({ kind: SkinnedMesh(_), .. }) =>
      hook_mesh_update_matrix_world(self, force)
    _ => self.update_matrix_world_base(force)
  }
}

///|
pub fn Object3D::update_matrix_world_base(
  self : Object3D,
  force : Bool,
) -> Unit {
  let mut force = force
  if self.matrix_auto_update {
    self.update_matrix()
  }
  if self.matrix_world_needs_update || force {
    if self.matrix_world_auto_update {
      match self.parent {
        None => ignore(self.matrix_world.copy(self.matrix))
        Some(parent) =>
          ignore(
            self.matrix_world.multiply_matrices(
              parent.matrix_world,
              self.matrix,
            ),
          )
      }
    }
    self.matrix_world_needs_update = false
    force = true
  }
  // make sure descendants are updated if required
  for child in self.children {
    child.update_matrix_world(force~)
  }
}

///|
pub fn Object3D::update_world_matrix(
  self : Object3D,
  update_parents : Bool,
  update_children : Bool,
  force~ : Bool = false,
) -> Unit {
  match self.extension {
    Some(extension) =>
      extension.update_world_matrix(
        self, update_parents, update_children, force,
      )
    None =>
      self.update_world_matrix_kind(update_parents, update_children, force)
  }
}

///|
pub fn Object3D::update_world_matrix_kind(
  self : Object3D,
  update_parents : Bool,
  update_children : Bool,
  force : Bool,
) -> Unit {
  match self.kind {
    Camera(_) =>
      hook_camera_update_world_matrix(
        self, update_parents, update_children, force,
      )
    _ => self.update_world_matrix_base(update_parents, update_children, force)
  }
}

///|
pub fn Object3D::update_world_matrix_base(
  self : Object3D,
  update_parents : Bool,
  update_children : Bool,
  force : Bool,
) -> Unit {
  let mut force = force
  if update_parents && self.parent is Some(parent) {
    parent.update_world_matrix(true, false)
  }
  if self.matrix_auto_update {
    self.update_matrix()
  }
  if self.matrix_world_needs_update || force {
    if self.matrix_world_auto_update {
      match self.parent {
        None => ignore(self.matrix_world.copy(self.matrix))
        Some(parent) =>
          ignore(
            self.matrix_world.multiply_matrices(
              parent.matrix_world,
              self.matrix,
            ),
          )
      }
    }
    self.matrix_world_needs_update = false
    force = true
  }
  // make sure descendants are updated
  if update_children {
    for child in self.children {
      child.update_world_matrix(false, true, force~)
    }
  }
}

///|
/// Creates the `meta` hash of a root `toJSON` call.
pub fn ToJsonMeta::new() -> ToJsonMeta {
  {
    geometries: Map([]),
    materials: Map([]),
    textures: Map([]),
    images: Map([]),
    shapes: Map([]),
    skeletons: Map([]),
    animations: Map([]),
    nodes: Map([]),
  }
}

///|
fn to_json_serialize(
  library : Map[String, Json],
  uuid : String,
  to_json : () -> Json,
) -> String {
  if !library.contains(uuid) {
    library[uuid] = to_json()
  }
  uuid
}

///|
/// Extracts data from the cache hash, removing the metadata on each item.
fn to_json_extract_from_cache(cache : Map[String, Json]) -> Array[Json] {
  let values = []
  for _, data in cache {
    if data is Object(map) {
      map.remove("metadata")
    }
    values.push(data)
  }
  values
}

///|
fn batched_mesh_to_json(
  batched : BatchedMesh,
  meta : ToJsonMeta,
  object : Map[String, Json],
) -> Unit {
  fn texture_json(texture : Texture?) -> Json {
    match texture {
      Some(texture) => texture.to_json(meta~)
      None => abort("BatchedMesh.toJSON(): texture is not initialized")
    }
  }

  object["type"] = Json::string("BatchedMesh")
  object["perObjectFrustumCulled"] = Json::boolean(
    batched.per_object_frustum_culled,
  )
  object["sortObjects"] = Json::boolean(batched.sort_objects)
  object["geometryInfo"] = Json::array(
    batched._geometry_info.map(info => {
      let json : Map[String, Json] = {
        "vertexStart": json_int(info.vertex_start),
        "vertexCount": json_int(info.vertex_count),
        "reservedVertexCount": json_int(info.reserved_vertex_count),
        "indexStart": json_int(info.index_start),
        "indexCount": json_int(info.index_count),
        "reservedIndexCount": json_int(info.reserved_index_count),
        "start": json_int(info.start),
        "count": json_int(info.count),
      }
      // upstream spreads the info object, whose keys are in this order
      if info.bounding_box is Some(bounding_box) {
        json["boundingBox"] = bounding_box.to_json()
      }
      if info.bounding_sphere is Some(bounding_sphere) {
        json["boundingSphere"] = bounding_sphere.to_json()
      }
      json["active"] = Json::boolean(info.active)
      Json::object(json)
    }),
  )
  object["instanceInfo"] = Json::array(
    batched._instance_info.map(info => {
      Json::object({
        "visible": Json::boolean(info.visible),
        "active": Json::boolean(info.active),
        "geometryIndex": json_int(info.geometry_index),
      })
    }),
  )
  object["availableInstanceIds"] = Json::array(
    batched._available_instance_ids.map(json_int),
  )
  object["availableGeometryIds"] = Json::array(
    batched._available_geometry_ids.map(json_int),
  )
  object["nextIndexStart"] = json_int(batched._next_index_start)
  object["nextVertexStart"] = json_int(batched._next_vertex_start)
  object["geometryCount"] = json_int(batched._geometry_count)
  object["maxInstanceCount"] = json_int(batched._max_instance_count)
  object["maxVertexCount"] = json_int(batched._max_vertex_count)
  object["maxIndexCount"] = json_int(batched._max_index_count)
  object["geometryInitialized"] = Json::boolean(batched._geometry_initialized)
  object["matricesTexture"] = texture_json(batched._matrices_texture)
  object["indirectTexture"] = texture_json(batched._indirect_texture)
  if batched._colors_texture is Some(_) {
    object["colorsTexture"] = texture_json(batched._colors_texture)
  }
  if batched.bounding_sphere is Some(bounding_sphere) {
    object["boundingSphere"] = bounding_sphere.to_json()
  }
  if batched.bounding_box is Some(bounding_box) {
    object["boundingBox"] = bounding_box.to_json()
  }
}

///|
/// Serializes the object. Pass `meta` only from inside another `to_json`, as upstream.
pub fn Object3D::to_json(self : Object3D, meta? : ToJsonMeta) -> Json {
  let is_root_object = meta is None
  let meta = match meta {
    Some(meta) => meta
    None => ToJsonMeta::new()
  }
  let output : Map[String, Json] = Map([])
  if is_root_object {
    output["metadata"] = Json::object({
      "version": Json::number(4.7),
      "type": Json::string("Object"),
      "generator": Json::string("Object3D.toJSON"),
    })
  }
  // standard Object3D serialization
  let object : Map[String, Json] = Map([])
  object["uuid"] = Json::string(self.uuid)
  object["type"] = Json::string(self.type_)
  object["name"] = Json::string(self.name)
  object["castShadow"] = Json::boolean(self.cast_shadow)
  object["receiveShadow"] = Json::boolean(self.receive_shadow)
  object["visible"] = Json::boolean(self.visible)
  object["frustumCulled"] = Json::boolean(self.frustum_culled)
  object["renderOrder"] = @math.json_number(self.render_order)
  object["static"] = Json::boolean(self.static_)
  object["matrixAutoUpdate"] = Json::boolean(self.matrix_auto_update)
  if self.user_data.key_count() > 0 {
    object["userData"] = self.user_data.to_json()
  }
  object["layers"] = @math.json_number(self.layers.mask)
  object["matrix"] = json_numbers(self.matrix.to_array())
  object["up"] = json_numbers(self.up.to_array())
  if self.pivot is Some(pivot) {
    object["pivot"] = json_numbers(pivot.to_array())
  }
  let (morph_dictionary, morph_influences) = self.morph_targets()
  if morph_dictionary is Some(dictionary) {
    let copy : Map[String, Json] = Map([])
    for key, value in dictionary {
      copy[key] = json_int(value)
    }
    object["morphTargetDictionary"] = Json::object(copy)
  }
  if morph_influences is Some(influences) {
    object["morphTargetInfluences"] = json_numbers(influences)
  }
  // object specific properties
  match self.kind {
    Mesh({ kind: InstancedMesh(instanced), count, .. }) => {
      object["type"] = Json::string("InstancedMesh")
      object["count"] = json_int(count)
      object["instanceMatrix"] = instanced.instance_matrix.to_json()
      if instanced.instance_color is Some(instance_color) {
        object["instanceColor"] = instance_color.to_json()
      }
    }
    Mesh({ kind: BatchedMesh(batched), .. }) =>
      batched_mesh_to_json(batched, meta, object)
    _ => ()
  }
  match self.kind {
    Scene(scene) => {
      match scene.background {
        Some(Color(color)) => object["background"] = json_int(color.to_json())
        Some(Texture(texture)) => {
          ignore(texture.to_json(meta~))
          object["background"] = Json::string(texture.uuid)
        }
        None => ()
      }
      if scene.environment is Some(environment) &&
        !environment.is_render_target_texture {
        ignore(environment.to_json(meta~))
        object["environment"] = Json::string(environment.uuid)
      }
    }
    Mesh(_) | Line(_) | Points(_) => {
      guard self.get_geometry() is Some(geometry) else {
        abort("Object3D.toJSON(): renderable object without geometry")
      }
      object["geometry"] = Json::string(
        to_json_serialize(meta.geometries, geometry.uuid, () => {
          geometry.to_json()
        }),
      )
      if geometry.parameters is Some(parameters) {
        for shape in parameters.shapes {
          ignore(
            to_json_serialize(meta.shapes, shape.uuid(), () => shape.to_json()),
          )
        }
      }
    }
    _ => ()
  }
  if self.kind is Mesh({ kind: SkinnedMesh(skinned), .. }) {
    object["bindMode"] = Json::string(skinned.bind_mode)
    object["bindMatrix"] = json_numbers(skinned.bind_matrix.to_array())
    if skinned.skeleton is Some(skeleton) {
      ignore(
        to_json_serialize(meta.skeletons, skeleton.uuid, () => {
          skeleton.to_json()
        }),
      )
      object["skeleton"] = Json::string(skeleton.uuid)
    }
  }
  fn serialize_material(material : Material) -> Json {
    Json::string(
      to_json_serialize(meta.materials, material.uuid, () => {
        material.to_json(meta~)
      }),
    )
  }

  match self.get_material() {
    Some(Multiple(materials)) =>
      object["material"] = Json::array(materials.map(serialize_material))
    Some(Single(material)) => object["material"] = serialize_material(material)
    None => ()
  }
  if self.children.length() > 0 {
    let children = []
    for child in self.children {
      match child.to_json(meta~) {
        Object(child_output) if child_output.get("object") is Some(child_object) =>
          children.push(child_object)
        _ => ()
      }
    }
    object["children"] = Json::array(children)
  }
  if self.animations.length() > 0 {
    let animations = []
    for animation in self.animations {
      animations.push(
        Json::string(
          to_json_serialize(meta.animations, animation.uuid(), () => {
            animation.to_json()
          }),
        ),
      )
    }
    object["animations"] = Json::array(animations)
  }
  if is_root_object {
    let libraries = [
      ("geometries", meta.geometries),
      ("materials", meta.materials),
      ("textures", meta.textures),
      ("images", meta.images),
      ("shapes", meta.shapes),
      ("skeletons", meta.skeletons),
      ("animations", meta.animations),
      ("nodes", meta.nodes),
    ]
    for library in libraries {
      let (name, cache) = library
      let values = to_json_extract_from_cache(cache)
      if values.length() > 0 {
        output[name] = Json::array(values)
      }
    }
  }
  // subclass additions, which upstream makes after `super.toJSON( meta )`
  self.to_json_kind(meta, object)
  if self.extension is Some(extension) {
    extension.to_json(self, meta, object)
  }
  output["object"] = Json::object(object)
  Json::object(output)
}

///|
/// Adds the fields of the subclass to `data.object`.
pub fn Object3D::to_json_kind(
  self : Object3D,
  meta : ToJsonMeta,
  object : Map[String, Json],
) -> Unit {
  match self.kind {
    Sprite(_) => hook_sprite_to_json(self, meta, object)
    LOD(_) => hook_lod_to_json(self, meta, object)
    Camera(_) => hook_camera_to_json(self, meta, object)
    Light(_) => hook_light_to_json(self, meta, object)
    Scene(_) => hook_scene_to_json(self, meta, object)
    Base
    | Group
    | ClippingGroup(_)
    | Bone
    | Mesh(_)
    | Line(_)
    | Points(_)
    | CubeCamera(_) => ()
  }
}

///|
/// `new this.constructor()`.
fn Object3D::new_like(self : Object3D) -> Object3D {
  match self.extension {
    Some(extension) => extension.construct()
    None =>
      match self.kind {
        Base => Object3D::new()
        Group => Object3D::new(kind=Group, type_="Group")
        Bone => Object3D::new(kind=Bone, type_="Bone")
        ClippingGroup(_) =>
          Object3D::new(
            kind=ClippingGroup({
              clipping_planes: [],
              enabled: true,
              clip_intersection: false,
              clip_shadows: false,
            }),
            type_="Group",
          )
        Mesh(_) => hook_mesh_new_like(self)
        Line(_) => hook_line_new_like(self)
        Points(_) => hook_points_new_like(self)
        Sprite(_) => hook_sprite_new_like(self)
        LOD(_) => hook_lod_new_like(self)
        Camera(_) => hook_camera_new_like(self)
        CubeCamera(_) => hook_cube_camera_new_like(self)
        Light(_) => hook_light_new_like(self)
        Scene(_) => hook_scene_new_like(self)
      }
  }
}

///|
pub fn Object3D::clone(self : Object3D, recursive~ : Bool = true) -> Object3D {
  // Upstream's `Camera.clone()` takes no argument, so it is always recursive.
  self.new_like().copy(self, recursive=recursive || self.is_camera())
}

///|
pub fn Object3D::copy(
  self : Object3D,
  source : Object3D,
  recursive~ : Bool = true,
) -> Object3D {
  match self.extension {
    Some(extension) => extension.copy_from(self, source, recursive)
    None => self.copy_kind(source, recursive)
  }
  self
}

///|
pub fn Object3D::copy_kind(
  self : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  match self.kind {
    Mesh(_) => hook_mesh_copy(self, source, recursive)
    Line(_) => hook_line_copy(self, source, recursive)
    Points(_) => hook_points_copy(self, source, recursive)
    Sprite(_) => hook_sprite_copy(self, source, recursive)
    LOD(_) => hook_lod_copy(self, source, recursive)
    Camera(_) => hook_camera_copy(self, source, recursive)
    Light(_) => hook_light_copy(self, source, recursive)
    Scene(_) => hook_scene_copy(self, source, recursive)
    Base | Group | ClippingGroup(_) | Bone | CubeCamera(_) =>
      self.copy_base(source, recursive)
  }
}

///|
pub fn Object3D::copy_base(
  self : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  self.name = source.name
  ignore(self.up.copy(source.up))
  ignore(self.position.copy(source.position))
  self.rotation.set_order(source.rotation.order)
  ignore(self.quaternion.copy(source.quaternion))
  ignore(self.scale.copy(source.scale))
  self.pivot = match source.pivot {
    Some(pivot) => Some(pivot.clone())
    None => None
  }
  ignore(self.matrix.copy(source.matrix))
  ignore(self.matrix_world.copy(source.matrix_world))
  self.matrix_auto_update = source.matrix_auto_update
  self.matrix_world_auto_update = source.matrix_world_auto_update
  self.matrix_world_needs_update = source.matrix_world_needs_update
  self.layers.mask = source.layers.mask
  self.visible = source.visible
  self.cast_shadow = source.cast_shadow
  self.receive_shadow = source.receive_shadow
  self.frustum_culled = source.frustum_culled
  self.render_order = source.render_order
  self.static_ = source.static_
  self.animations = source.animations.copy()
  self.user_data = source.user_data.json_clone()
  if recursive {
    for child in source.children {
      ignore(self.add(child.clone()))
    }
  }
}

///|
pub fn Object3D::dispose(self : Object3D) -> Unit {
  match self.extension {
    Some(extension) => extension.dispose(self)
    None => self.dispose_kind()
  }
}

///|
pub fn Object3D::dispose_kind(self : Object3D) -> Unit {
  match self.kind {
    Mesh({ kind: InstancedMesh(_) | BatchedMesh(_), .. }) =>
      hook_mesh_dispose(self)
    Light(_) => hook_light_dispose(self)
    _ => self.dispose_base()
  }
}

///|
pub fn Object3D::dispose_base(self : Object3D) -> Unit {
  self.dispatch_event(Event::new("dispose"))
}
