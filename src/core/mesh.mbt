// Upstream src/objects/Mesh.js. `SkinnedMesh`, `InstancedMesh` and `BatchedMesh` keep
// their class code in their own files; the hooks here dispatch to them on `MeshKind`.

///|
let _mesh_inverse_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _mesh_ray : @math.Ray = @math.Ray::new()

///|
let _mesh_sphere : @math.Sphere = @math.Sphere::new()

///|
let _mesh_sphere_hit_at : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_v_a : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_v_b : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_v_c : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_temp_a : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_morph_a : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_intersection_point : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _mesh_intersection_point_world : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
extern "js" fn mesh_squared(x : Double) -> Double = "(x) => x ** 2"

///|
/// Builds a `Mesh`-kind object; subclass constructors pass their `kind` and `type_`.
/// Upstream's `updateMorphTargets` runs for the caller to do, since `InstancedMesh`
/// overrides it with a no-op that is already in effect during `super()`.
fn mesh_make(
  geometry : BufferGeometry?,
  material : MaterialSlot?,
  kind : MeshKind,
  type_ : String,
) -> Object3D {
  let mesh : Mesh = {
    geometry: match geometry {
      Some(geometry) => geometry
      None => BufferGeometry::new()
    },
    material: match material {
      Some(material) => material
      None => Single(MeshBasicMaterial::new())
    },
    morph_target_dictionary: None,
    morph_target_influences: None,
    count: 1,
    kind,
  }
  Object3D::new(kind=Mesh(mesh), type_~)
}

///|
pub fn Mesh::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
) -> Object3D {
  let object = mesh_make(geometry, material, PlainMesh, "Mesh")
  object.update_morph_targets()
  object
}

///|
fn Object3D::mesh_data(self : Object3D) -> Mesh {
  guard self.kind is Mesh(mesh) else { abort("Object3D: not a Mesh") }
  mesh
}

///|
/// `Array.isArray( material ) ? material.slice() : material`.
fn material_slot_copy(material : MaterialSlot) -> MaterialSlot {
  match material {
    Single(_) => material
    Multiple(materials) => Multiple(materials.copy())
  }
}

///|
/// The morph fields as `Mesh.copy`, `Line.copy` and `Points.copy` take them from `source`.
fn morph_targets_copy(
  source : Object3D,
) -> (Map[String, Int32]?, Array[Double]?) {
  let (dictionary, influences) = source.morph_targets()
  (dictionary.map(d => d.copy()), influences.map(a => a.copy()))
}

///|
/// The body of `updateMorphTargets`: `None` leaves the object's fields as they are.
fn morph_targets_from_geometry(
  geometry : BufferGeometry,
) -> (Map[String, Int32], Array[Double])? {
  for _, morph_attribute in geometry.morph_attributes {
    let influences : Array[Double] = []
    let dictionary : Map[String, Int32] = Map([])
    for m, attribute in morph_attribute {
      let name = attribute.name()
      influences.push(0.0)
      dictionary[if name == "" { m.to_string() } else { name }] = m
    }
    return Some((dictionary, influences))
  }
  None
}

///|
/// Sets up `morphTargetInfluences` and `morphTargetDictionary` from the geometry.
pub fn Object3D::update_morph_targets(self : Object3D) -> Unit {
  match self.kind {
    Mesh({ kind: InstancedMesh(_), .. }) => ()
    Mesh(mesh) =>
      if morph_targets_from_geometry(mesh.geometry)
        is Some((dictionary, influences)) {
        mesh.morph_target_dictionary = Some(dictionary)
        mesh.morph_target_influences = Some(influences)
      }
    Line(line) =>
      if morph_targets_from_geometry(line.geometry)
        is Some((dictionary, influences)) {
        line.morph_target_dictionary = Some(dictionary)
        line.morph_target_influences = Some(influences)
      }
    Points(points) =>
      if morph_targets_from_geometry(points.geometry)
        is Some((dictionary, influences)) {
        points.morph_target_dictionary = Some(dictionary)
        points.morph_target_influences = Some(influences)
      }
    _ => abort("Object3D.updateMorphTargets: not a Mesh, Line or Points")
  }
}

///|
fn mesh_copy(object : Object3D, source : Object3D, recursive : Bool) -> Unit {
  object.copy_base(source, recursive)
  let target = object.mesh_data()
  let (dictionary, influences) = morph_targets_copy(source)
  target.morph_target_influences = influences
  target.morph_target_dictionary = dictionary
  guard source.get_material() is Some(material) else {
    abort("Mesh.copy: source has no material")
  }
  guard source.get_geometry() is Some(geometry) else {
    abort("Mesh.copy: source has no geometry")
  }
  target.material = material_slot_copy(material)
  target.geometry = geometry
}

///|
/// The base `getVertexPosition`, with morph targets; `SkinnedMesh` adds to it.
fn mesh_get_vertex_position(
  object : Object3D,
  index : Int32,
  target : @math.Vector3,
) -> @math.Vector3 {
  let mesh = object.mesh_data()
  let geometry = mesh.geometry
  guard geometry.attributes.get("position") is Some(position) else {
    abort("Mesh.getVertexPosition: geometry has no position attribute")
  }
  ignore(target.from_buffer_attribute(position, index))
  if geometry.morph_attributes.get("position") is Some(morph_position) &&
    mesh.morph_target_influences is Some(morph_influences) {
    let morph_targets_relative = geometry.morph_targets_relative
    ignore(_mesh_morph_a.set(0.0, 0.0, 0.0))
    let influence_count = morph_influences.length()
    for i, morph_attribute in morph_position {
      // an influence past the end of the list is `undefined` upstream, so NaN
      let influence = if i < influence_count {
        morph_influences[i]
      } else {
        objects_nan()
      }
      if influence == 0.0 {
        continue
      }
      ignore(_mesh_temp_a.from_buffer_attribute(morph_attribute, index))
      if morph_targets_relative {
        ignore(_mesh_morph_a.add_scaled_vector(_mesh_temp_a, influence))
      } else {
        ignore(
          _mesh_morph_a.add_scaled_vector(_mesh_temp_a.sub(target), influence),
        )
      }
    }
    ignore(target.add(_mesh_morph_a))
  }
  target
}

///|
/// The position of a vertex after morphing and, for a `SkinnedMesh`, skinning.
pub fn Object3D::get_vertex_position(
  self : Object3D,
  index : Int32,
  target : @math.Vector3,
) -> @math.Vector3 {
  match self.kind {
    Mesh({ kind: SkinnedMesh(_), .. }) =>
      skinned_mesh_get_vertex_position(self, index, target)
    Mesh(_) => mesh_get_vertex_position(self, index, target)
    _ => abort("Object3D.getVertexPosition: not a Mesh")
  }
}

///|
fn mesh_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let geometry = object.mesh_data().geometry
  let matrix_world = object.matrix_world
  // test with bounding sphere in world space
  if geometry.bounding_sphere is None {
    geometry.compute_bounding_sphere()
  }
  guard geometry.bounding_sphere is Some(bounding_sphere) else {
    abort("Mesh.raycast: geometry has no bounding sphere")
  }
  ignore(_mesh_sphere.copy(bounding_sphere))
  ignore(_mesh_sphere.apply_matrix4(matrix_world))
  // check distance from ray origin to bounding sphere
  ignore(_mesh_ray.copy(raycaster.ray).recast(raycaster.near))
  if !_mesh_sphere.contains_point(_mesh_ray.origin) {
    if _mesh_ray.intersect_sphere(_mesh_sphere, _mesh_sphere_hit_at) is None {
      return
    }
    if _mesh_ray.origin.distance_to_squared(_mesh_sphere_hit_at) >
      mesh_squared(raycaster.far - raycaster.near) {
      return
    }
  }
  // convert ray to local space of mesh
  ignore(_mesh_inverse_matrix.copy(matrix_world).invert())
  ignore(_mesh_ray.copy(raycaster.ray).apply_matrix4(_mesh_inverse_matrix))
  // test with bounding box in local space
  if geometry.bounding_box is Some(bounding_box) {
    if !_mesh_ray.intersects_box(bounding_box) {
      return
    }
  }
  // test for intersections with geometry
  mesh_compute_intersections(object, raycaster, intersects, _mesh_ray)
}

///|
/// Upstream `_computeIntersections`.
fn mesh_compute_intersections(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
  ray_local_space : @math.Ray,
) -> Unit {
  let mesh = object.mesh_data()
  let geometry = mesh.geometry
  let material = mesh.material
  let position = geometry.attributes.get("position")
  let uv = geometry.attributes.get("uv")
  let uv1 = geometry.attributes.get("uv1")
  let normal = geometry.attributes.get("normal")
  let groups = geometry.groups
  let draw_range = geometry.draw_range
  let draw_end = draw_range.start.to_double() + draw_range.count
  match (geometry.index, material) {
    // indexed buffer geometry
    (Some(index), Multiple(materials)) =>
      for group in groups {
        let group_material = materials[group.material_index]
        let start = objects_max_int(group.start, draw_range.start)
        let end = objects_math_min(
          index.count().to_double(),
          objects_math_min(group.start.to_double() + group.count, draw_end),
        )
        for j = start; j.to_double() < end; j = j + 3 {
          let a = index.get_x(j).to_int()
          let b = index.get_x(j + 1).to_int()
          let c = index.get_x(j + 2).to_int()
          if mesh_check_geometry_intersection(
              object, group_material, raycaster, ray_local_space, uv, uv1, normal,
              a, b, c,
            )
            is Some(intersection) {
            mesh_push_intersection(
              intersection,
              j,
              Some(group.material_index),
              intersects,
            )
          }
        }
      }
    (Some(index), Single(material)) => {
      let start = objects_max_int(0, draw_range.start)
      let end = objects_math_min(index.count().to_double(), draw_end)
      for i = start; i.to_double() < end; i = i + 3 {
        let a = index.get_x(i).to_int()
        let b = index.get_x(i + 1).to_int()
        let c = index.get_x(i + 2).to_int()
        if mesh_check_geometry_intersection(
            object, material, raycaster, ray_local_space, uv, uv1, normal, a, b,
            c,
          )
          is Some(intersection) {
          mesh_push_intersection(intersection, i, None, intersects)
        }
      }
    }
    // non-indexed buffer geometry
    (None, Multiple(materials)) =>
      if position is Some(position) {
        for group in groups {
          let group_material = materials[group.material_index]
          let start = objects_max_int(group.start, draw_range.start)
          let end = objects_math_min(
            position.count().to_double(),
            objects_math_min(group.start.to_double() + group.count, draw_end),
          )
          for j = start; j.to_double() < end; j = j + 3 {
            if mesh_check_geometry_intersection(
                object,
                group_material,
                raycaster,
                ray_local_space,
                uv,
                uv1,
                normal,
                j,
                j + 1,
                j + 2,
              )
              is Some(intersection) {
              mesh_push_intersection(
                intersection,
                j,
                Some(group.material_index),
                intersects,
              )
            }
          }
        }
      }
    (None, Single(material)) =>
      if position is Some(position) {
        let start = objects_max_int(0, draw_range.start)
        let end = objects_math_min(position.count().to_double(), draw_end)
        for i = start; i.to_double() < end; i = i + 3 {
          if mesh_check_geometry_intersection(
              object,
              material,
              raycaster,
              ray_local_space,
              uv,
              uv1,
              normal,
              i,
              i + 1,
              i + 2,
            )
            is Some(intersection) {
            mesh_push_intersection(intersection, i, None, intersects)
          }
        }
      }
  }
}

///|
/// Records the triangle number in the buffer's semantics and keeps the intersection.
fn mesh_push_intersection(
  intersection : Intersection,
  index : Int32,
  material_index : Int32?,
  intersects : Array[Intersection],
) -> Unit {
  intersection.face_index = Some((index.to_double() / 3.0).floor().to_int())
  if material_index is Some(material_index) && intersection.face is Some(face) {
    face.material_index = material_index
  }
  intersects.push(intersection)
}

///|
fn mesh_check_intersection(
  object : Object3D,
  material : Material,
  raycaster : Raycaster,
  ray : @math.Ray,
  p_a : @math.Vector3,
  p_b : @math.Vector3,
  p_c : @math.Vector3,
  point : @math.Vector3,
) -> Intersection? {
  let intersect = if material.side == BackSide {
    ray.intersect_triangle(p_c, p_b, p_a, true, point)
  } else {
    ray.intersect_triangle(p_a, p_b, p_c, material.side == FrontSide, point)
  }
  if intersect is None {
    return None
  }
  ignore(_mesh_intersection_point_world.copy(point))
  ignore(_mesh_intersection_point_world.apply_matrix4(object.matrix_world))
  let distance = raycaster.ray.origin.distance_to(
    _mesh_intersection_point_world,
  )
  if distance < raycaster.near || distance > raycaster.far {
    return None
  }
  Some(
    Intersection::make(distance, _mesh_intersection_point_world.clone(), object),
  )
}

///|
fn mesh_check_geometry_intersection(
  object : Object3D,
  material : Material,
  raycaster : Raycaster,
  ray : @math.Ray,
  uv : GeometryAttribute?,
  uv1 : GeometryAttribute?,
  normal : GeometryAttribute?,
  a : Int32,
  b : Int32,
  c : Int32,
) -> Intersection? {
  ignore(object.get_vertex_position(a, _mesh_v_a))
  ignore(object.get_vertex_position(b, _mesh_v_b))
  ignore(object.get_vertex_position(c, _mesh_v_c))
  let intersection = mesh_check_intersection(
    object, material, raycaster, ray, _mesh_v_a, _mesh_v_b, _mesh_v_c, _mesh_intersection_point,
  )
  if intersection is Some(intersection) {
    let barycoord = @math.Vector3::new(0.0, 0.0, 0.0)
    ignore(
      @math.Triangle::get_barycoord_static(
        _mesh_intersection_point, _mesh_v_a, _mesh_v_b, _mesh_v_c, barycoord,
      ),
    )
    if uv is Some(uv) {
      intersection.uv = Some(
        triangle_get_interpolated_attribute(
          uv,
          a,
          b,
          c,
          barycoord,
          @math.Vector2::new(0.0, 0.0),
        ),
      )
    }
    if uv1 is Some(uv1) {
      intersection.uv1 = Some(
        triangle_get_interpolated_attribute(
          uv1,
          a,
          b,
          c,
          barycoord,
          @math.Vector2::new(0.0, 0.0),
        ),
      )
    }
    if normal is Some(normal) {
      let interpolated = triangle_get_interpolated_attribute(
        normal,
        a,
        b,
        c,
        barycoord,
        @math.Vector3::new(0.0, 0.0, 0.0),
      )
      if interpolated.dot(ray.direction) > 0.0 {
        ignore(interpolated.multiply_scalar(-1.0))
      }
      intersection.normal = Some(interpolated)
    }
    let face : Face = {
      a,
      b,
      c,
      normal: @math.Vector3::new(0.0, 0.0, 0.0),
      material_index: 0,
    }
    ignore(
      @math.Triangle::get_normal_static(
        _mesh_v_a,
        _mesh_v_b,
        _mesh_v_c,
        face.normal,
      ),
    )
    intersection.face = Some(face)
    intersection.barycoord = Some(barycoord)
  }
  intersection
}

///|
/// Upstream `raycast`.
fn hook_mesh_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  match object.mesh_data().kind {
    PlainMesh => mesh_raycast(object, raycaster, intersects)
    SkinnedMesh(_) => skinned_mesh_raycast(object, raycaster, intersects)
    InstancedMesh(_) => instanced_mesh_raycast(object, raycaster, intersects)
    BatchedMesh(_) => batched_mesh_raycast(object, raycaster, intersects)
  }
}

///|
/// Upstream `intersectsFrustum`.
fn hook_mesh_intersects_frustum(
  object : Object3D,
  frustum : FrustumRef,
) -> Bool {
  match frustum {
    Single(frustum) => frustum_intersects_object(frustum, object)
    Array(frustum) => frustum_array_intersects_object(frustum, object)
  }
}

///|
/// `new this.constructor()`.
fn hook_mesh_new_like(object : Object3D) -> Object3D {
  match object.mesh_data().kind {
    PlainMesh => Mesh::new()
    SkinnedMesh(_) => SkinnedMesh::new()
    // upstream's missing arguments size every buffer at zero
    InstancedMesh(_) => InstancedMesh::new(0)
    BatchedMesh(_) => BatchedMesh::new(0, 0)
  }
}

///|
/// Calls `object.copy_base( source, recursive )` first, as `super.copy`.
fn hook_mesh_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  match object.mesh_data().kind {
    PlainMesh => mesh_copy(object, source, recursive)
    SkinnedMesh(_) => skinned_mesh_copy(object, source, recursive)
    InstancedMesh(_) => instanced_mesh_copy(object, source, recursive)
    BatchedMesh(_) => batched_mesh_copy(object, source)
  }
}

///|
/// Calls `object.update_matrix_world_base( force )` as `super`.
fn hook_mesh_update_matrix_world(object : Object3D, force : Bool) -> Unit {
  object.update_matrix_world_base(force)
  skinned_mesh_update_bind_matrix_inverse(object)
}

///|
/// Calls `object.dispose_base()` as `super.dispose`.
fn hook_mesh_dispose(object : Object3D) -> Unit {
  object.dispose_base()
  match object.mesh_data().kind {
    InstancedMesh(instanced) => instanced_mesh_dispose(instanced)
    BatchedMesh(batched) => batched_mesh_dispose(object, batched)
    PlainMesh | SkinnedMesh(_) => ()
  }
}

///|
/// `object.boundingBox !== undefined`: skinned, instanced and batched meshes.
pub fn Object3D::has_object_bounds(self : Object3D) -> Bool {
  self.kind
  is Mesh({ kind: SkinnedMesh(_) | InstancedMesh(_) | BatchedMesh(_), .. })
}

///|
/// `object.boundingBox` of a skinned, instanced or batched mesh.
pub fn Object3D::get_bounding_box(self : Object3D) -> @math.Box3? {
  match self.kind {
    Mesh({ kind: SkinnedMesh(skinned), .. }) => skinned.bounding_box
    Mesh({ kind: InstancedMesh(instanced), .. }) => instanced.bounding_box
    Mesh({ kind: BatchedMesh(batched), .. }) => batched.bounding_box
    _ => None
  }
}

///|
/// `object.boundingSphere` of a skinned, instanced or batched mesh.
pub fn Object3D::get_bounding_sphere(self : Object3D) -> @math.Sphere? {
  match self.kind {
    Mesh({ kind: SkinnedMesh(skinned), .. }) => skinned.bounding_sphere
    Mesh({ kind: InstancedMesh(instanced), .. }) => instanced.bounding_sphere
    Mesh({ kind: BatchedMesh(batched), .. }) => batched.bounding_sphere
    _ => None
  }
}

///|
/// Computes `object.boundingBox` of a skinned, instanced or batched mesh.
pub fn Object3D::compute_bounding_box(self : Object3D) -> Unit {
  match self.kind {
    Mesh({ kind: SkinnedMesh(_), .. }) =>
      skinned_mesh_compute_bounding_box(self)
    Mesh({ kind: InstancedMesh(_), .. }) =>
      instanced_mesh_compute_bounding_box(self)
    Mesh({ kind: BatchedMesh(_), .. }) =>
      batched_mesh_compute_bounding_box(self)
    _ => abort("Object3D.computeBoundingBox: no bounds of its own")
  }
}

///|
/// Computes `object.boundingSphere` of a skinned, instanced or batched mesh.
pub fn Object3D::compute_bounding_sphere(self : Object3D) -> Unit {
  match self.kind {
    Mesh({ kind: SkinnedMesh(_), .. }) =>
      skinned_mesh_compute_bounding_sphere(self)
    Mesh({ kind: InstancedMesh(_), .. }) =>
      instanced_mesh_compute_bounding_sphere(self)
    Mesh({ kind: BatchedMesh(_), .. }) =>
      batched_mesh_compute_bounding_sphere(self)
    _ => abort("Object3D.computeBoundingSphere: no bounds of its own")
  }
}
