// Upstream src/objects/SkinnedMesh.js. The dispatch sits in mesh.mbt.

///|
let _skinned_mesh_base_vector : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _skinned_mesh_skin_index : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _skinned_mesh_skin_weight : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _skinned_mesh_vector4 : @math.Vector4 = @math.Vector4::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _skinned_mesh_matrix4 : @math.Matrix4 = @math.Matrix4::new()

///|
let _skinned_mesh_vertex : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _skinned_mesh_sphere : @math.Sphere = @math.Sphere::new()

///|
let _skinned_mesh_inverse_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _skinned_mesh_ray : @math.Ray = @math.Ray::new()

///|
pub fn SkinnedMesh::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
) -> Object3D {
  let skinned : SkinnedMesh = {
    bind_mode: AttachedBindMode,
    bind_matrix: @math.Matrix4::new(),
    bind_matrix_inverse: @math.Matrix4::new(),
    bounding_box: None,
    bounding_sphere: None,
    skeleton: None,
  }
  let object = mesh_make(
    geometry,
    material,
    SkinnedMesh(skinned),
    "SkinnedMesh",
  )
  object.update_morph_targets()
  object
}

///|
fn Object3D::skinned_mesh_data(self : Object3D) -> SkinnedMesh {
  guard self.kind is Mesh({ kind: SkinnedMesh(skinned), .. }) else {
    abort("Object3D: not a SkinnedMesh")
  }
  skinned
}

///|
fn skinned_mesh_compute_bounding_box(object : Object3D) -> Unit {
  let skinned = object.skinned_mesh_data()
  let bounding_box = match skinned.bounding_box {
    Some(bounding_box) => bounding_box
    None => {
      let bounding_box = @math.Box3::new()
      skinned.bounding_box = Some(bounding_box)
      bounding_box
    }
  }
  ignore(bounding_box.make_empty())
  guard object.mesh_data().geometry.get_attribute("position")
    is Some(position_attribute) else {
    abort("SkinnedMesh.computeBoundingBox: geometry has no position attribute")
  }
  for i in 0..<position_attribute.count() {
    ignore(object.get_vertex_position(i, _skinned_mesh_vertex))
    ignore(bounding_box.expand_by_point(_skinned_mesh_vertex))
  }
}

///|
fn skinned_mesh_compute_bounding_sphere(object : Object3D) -> Unit {
  let skinned = object.skinned_mesh_data()
  let bounding_sphere = match skinned.bounding_sphere {
    Some(bounding_sphere) => bounding_sphere
    None => {
      let bounding_sphere = @math.Sphere::new()
      skinned.bounding_sphere = Some(bounding_sphere)
      bounding_sphere
    }
  }
  ignore(bounding_sphere.make_empty())
  guard object.mesh_data().geometry.get_attribute("position")
    is Some(position_attribute) else {
    abort(
      "SkinnedMesh.computeBoundingSphere: geometry has no position attribute",
    )
  }
  for i in 0..<position_attribute.count() {
    ignore(object.get_vertex_position(i, _skinned_mesh_vertex))
    ignore(bounding_sphere.expand_by_point(_skinned_mesh_vertex))
  }
}

///|
fn skinned_mesh_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  mesh_copy(object, source, recursive)
  let target = object.skinned_mesh_data()
  let source_skinned = source.skinned_mesh_data()
  target.bind_mode = source_skinned.bind_mode
  ignore(target.bind_matrix.copy(source_skinned.bind_matrix))
  ignore(target.bind_matrix_inverse.copy(source_skinned.bind_matrix_inverse))
  target.skeleton = source_skinned.skeleton
  target.bounding_box = source_skinned.bounding_box.map(box_ => box_.clone())
  target.bounding_sphere = source_skinned.bounding_sphere.map(sphere => {
    sphere.clone()
  })
}

///|
fn skinned_mesh_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let skinned = object.skinned_mesh_data()
  let matrix_world = object.matrix_world
  // test with bounding sphere in world space
  if skinned.bounding_sphere is None {
    skinned_mesh_compute_bounding_sphere(object)
  }
  guard skinned.bounding_sphere is Some(bounding_sphere) else {
    abort("SkinnedMesh.raycast: no bounding sphere")
  }
  ignore(_skinned_mesh_sphere.copy(bounding_sphere))
  ignore(_skinned_mesh_sphere.apply_matrix4(matrix_world))
  if !raycaster.ray.intersects_sphere(_skinned_mesh_sphere) {
    return
  }
  // convert ray to local space of skinned mesh
  ignore(_skinned_mesh_inverse_matrix.copy(matrix_world).invert())
  ignore(
    _skinned_mesh_ray
    .copy(raycaster.ray)
    .apply_matrix4(_skinned_mesh_inverse_matrix),
  )
  // test with bounding box in local space
  if skinned.bounding_box is Some(bounding_box) {
    if !_skinned_mesh_ray.intersects_box(bounding_box) {
      return
    }
  }
  // test for intersections with geometry
  mesh_compute_intersections(object, raycaster, intersects, _skinned_mesh_ray)
}

///|
fn skinned_mesh_get_vertex_position(
  object : Object3D,
  index : Int32,
  target : @math.Vector3,
) -> @math.Vector3 {
  ignore(mesh_get_vertex_position(object, index, target))
  ignore(object.apply_bone_transform(index, target))
  target
}

///|
/// Binds the skeleton; `bind_matrix` defaults to the current `matrix_world`.
pub fn Object3D::bind(
  self : Object3D,
  skeleton : Skeleton,
  bind_matrix? : @math.Matrix4,
) -> Unit {
  let skinned = self.skinned_mesh_data()
  skinned.skeleton = Some(skeleton)
  let bind_matrix = match bind_matrix {
    Some(bind_matrix) => bind_matrix
    None => {
      self.update_matrix_world(force=true)
      skeleton.calculate_inverses()
      self.matrix_world
    }
  }
  ignore(skinned.bind_matrix.copy(bind_matrix))
  ignore(skinned.bind_matrix_inverse.copy(bind_matrix).invert())
}

///|
/// Returns the skeleton of a `SkinnedMesh` to the bind pose.
pub fn Object3D::pose(self : Object3D) -> Unit {
  guard self.skinned_mesh_data().skeleton is Some(skeleton) else {
    abort("SkinnedMesh.pose: no skeleton bound")
  }
  skeleton.pose()
}

///|
/// Normalizes the `skinWeight` attribute.
pub fn Object3D::normalize_skin_weights(self : Object3D) -> Unit {
  let vector = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  guard self.mesh_data().geometry.attributes.get("skinWeight")
    is Some(skin_weight) else {
    abort("SkinnedMesh.normalizeSkinWeights: geometry has no skinWeight")
  }
  let infinity = buffer_geometry_infinity()
  for i in 0..<skin_weight.count() {
    ignore(vector.from_buffer_attribute(skin_weight, i))
    let scale = 1.0 / vector.manhattan_length()
    if scale != infinity {
      ignore(vector.multiply_scalar(scale))
    } else {
      // do something reasonable
      ignore(vector.set(1.0, 0.0, 0.0, 0.0))
    }
    skin_weight.set_xyzw(i, vector.x, vector.y, vector.z, vector.w)
  }
}

///|
/// The part of `updateMatrixWorld` after `super.updateMatrixWorld`.
fn skinned_mesh_update_bind_matrix_inverse(object : Object3D) -> Unit {
  let skinned = object.skinned_mesh_data()
  if skinned.bind_mode == AttachedBindMode {
    ignore(skinned.bind_matrix_inverse.copy(object.matrix_world).invert())
  } else if skinned.bind_mode == DetachedBindMode {
    ignore(skinned.bind_matrix_inverse.copy(skinned.bind_matrix).invert())
  } else {
    warn("SkinnedMesh: Unrecognized bindMode: " + skinned.bind_mode)
  }
}

///|
/// Reads the skin data of a vertex into the scratch vectors.
fn skinned_mesh_load_skin(
  object : Object3D,
  skinned : SkinnedMesh,
  index : Int32,
) -> Skeleton {
  guard skinned.skeleton is Some(skeleton) else {
    abort("SkinnedMesh.applyBoneTransform: no skeleton bound")
  }
  let attributes = object.mesh_data().geometry.attributes
  guard attributes.get("skinIndex") is Some(skin_index) else {
    abort("SkinnedMesh.applyBoneTransform: geometry has no skinIndex")
  }
  guard attributes.get("skinWeight") is Some(skin_weight) else {
    abort("SkinnedMesh.applyBoneTransform: geometry has no skinWeight")
  }
  ignore(_skinned_mesh_skin_index.from_buffer_attribute(skin_index, index))
  ignore(_skinned_mesh_skin_weight.from_buffer_attribute(skin_weight, index))
  skeleton
}

///|
/// The base vector moved by the bone in slot `i` of the scratch skin index.
fn skinned_mesh_bone_vector(skeleton : Skeleton, i : Int32) -> @math.Vector4 {
  let bone_index = _skinned_mesh_skin_index.get_component(i).to_int()
  ignore(
    _skinned_mesh_matrix4.multiply_matrices(
      skeleton.bones[bone_index].matrix_world,
      skeleton.bone_inverses[bone_index],
    ),
  )
  _skinned_mesh_vector4
  .copy(_skinned_mesh_base_vector)
  .apply_matrix4(_skinned_mesh_matrix4)
}

///|
/// Moves a vertex from bind space through its bones.
pub fn Object3D::apply_bone_transform(
  self : Object3D,
  index : Int32,
  target : @math.Vector3,
) -> @math.Vector3 {
  let skinned = self.skinned_mesh_data()
  let skeleton = skinned_mesh_load_skin(self, skinned, index)
  ignore(_skinned_mesh_base_vector.set(target.x, target.y, target.z, 1.0))
  ignore(target.set(0.0, 0.0, 0.0))
  ignore(_skinned_mesh_base_vector.apply_matrix4(skinned.bind_matrix))
  for i in 0..<4 {
    let weight = _skinned_mesh_skin_weight.get_component(i)
    if weight != 0.0 {
      ignore(
        target.add_scaled_vector4(skinned_mesh_bone_vector(skeleton, i), weight),
      )
    }
  }
  target.apply_matrix4(skinned.bind_matrix_inverse)
}

///|
/// `applyBoneTransform` for a `Vector4` target.
pub fn Object3D::apply_bone_transform_vector4(
  self : Object3D,
  index : Int32,
  target : @math.Vector4,
) -> @math.Vector4 {
  let skinned = self.skinned_mesh_data()
  let skeleton = skinned_mesh_load_skin(self, skinned, index)
  ignore(_skinned_mesh_base_vector.copy(target))
  ignore(target.set(0.0, 0.0, 0.0, 0.0))
  ignore(_skinned_mesh_base_vector.apply_matrix4(skinned.bind_matrix))
  for i in 0..<4 {
    let weight = _skinned_mesh_skin_weight.get_component(i)
    if weight != 0.0 {
      ignore(
        target.add_scaled_vector(skinned_mesh_bone_vector(skeleton, i), weight),
      )
    }
  }
  // ensure the homogenous coordinate remains unchanged after vector operations
  target.w = _skinned_mesh_base_vector.w
  target.apply_matrix4(skinned.bind_matrix_inverse)
}
