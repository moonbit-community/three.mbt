// Upstream src/objects/InstancedMesh.js. The dispatch sits in mesh.mbt; `set_matrix_at`
// and its kin are shared with `BatchedMesh`, whose code is in batched_mesh.mbt.

///|
let _instanced_mesh_local_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _instanced_mesh_world_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _instanced_mesh_intersects : Array[Intersection] = []

///|
let _instanced_mesh_box3 : @math.Box3 = @math.Box3::new()

///|
let _instanced_mesh_identity : @math.Matrix4 = @math.Matrix4::new()

///|
let _instanced_mesh_mesh : Object3D = Mesh::new()

///|
let _instanced_mesh_sphere : @math.Sphere = @math.Sphere::new()

///|
/// `geometry` and `material` are labelled because they are optional.
pub fn InstancedMesh::new(
  geometry? : BufferGeometry,
  material? : MaterialSlot,
  count : Int32,
) -> Object3D {
  let instanced : InstancedMesh = {
    instance_matrix: InstancedBufferAttribute::new(
      TypedArray::float32(count * 16),
      16,
    ),
    instance_color: None,
    morph_texture: None,
    bounding_box: None,
    bounding_sphere: None,
  }
  let object = mesh_make(geometry, material, InstancedMesh(instanced), "Mesh")
  object.mesh_data().count = count
  for i in 0..<count {
    ignore(object.set_matrix_at(i, _instanced_mesh_identity))
  }
  object
}

///|
fn Object3D::instanced_mesh_data(self : Object3D) -> InstancedMesh {
  guard self.kind is Mesh({ kind: InstancedMesh(instanced), .. }) else {
    abort("Object3D: not an InstancedMesh")
  }
  instanced
}

///|
fn instanced_mesh_compute_bounding_box(object : Object3D) -> Unit {
  let instanced = object.instanced_mesh_data()
  let mesh = object.mesh_data()
  let geometry = mesh.geometry
  let bounding_box = match instanced.bounding_box {
    Some(bounding_box) => bounding_box
    None => {
      let bounding_box = @math.Box3::new()
      instanced.bounding_box = Some(bounding_box)
      bounding_box
    }
  }
  if geometry.bounding_box is None {
    geometry.compute_bounding_box()
  }
  guard geometry.bounding_box is Some(geometry_box) else {
    abort("InstancedMesh.computeBoundingBox: geometry has no bounding box")
  }
  ignore(bounding_box.make_empty())
  for i in 0..<mesh.count {
    ignore(object.get_matrix_at(i, _instanced_mesh_local_matrix))
    ignore(
      _instanced_mesh_box3
      .copy(geometry_box)
      .apply_matrix4(_instanced_mesh_local_matrix),
    )
    ignore(bounding_box.union(_instanced_mesh_box3))
  }
}

///|
fn instanced_mesh_compute_bounding_sphere(object : Object3D) -> Unit {
  let instanced = object.instanced_mesh_data()
  let mesh = object.mesh_data()
  let geometry = mesh.geometry
  let bounding_sphere = match instanced.bounding_sphere {
    Some(bounding_sphere) => bounding_sphere
    None => {
      let bounding_sphere = @math.Sphere::new()
      instanced.bounding_sphere = Some(bounding_sphere)
      bounding_sphere
    }
  }
  if geometry.bounding_sphere is None {
    geometry.compute_bounding_sphere()
  }
  guard geometry.bounding_sphere is Some(geometry_sphere) else {
    abort(
      "InstancedMesh.computeBoundingSphere: geometry has no bounding sphere",
    )
  }
  ignore(bounding_sphere.make_empty())
  for i in 0..<mesh.count {
    ignore(object.get_matrix_at(i, _instanced_mesh_local_matrix))
    ignore(
      _instanced_mesh_sphere
      .copy(geometry_sphere)
      .apply_matrix4(_instanced_mesh_local_matrix),
    )
    ignore(bounding_sphere.union(_instanced_mesh_sphere))
  }
}

///|
fn instanced_mesh_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  mesh_copy(object, source, recursive)
  let target = object.instanced_mesh_data()
  let source_instanced = source.instanced_mesh_data()
  ignore(target.instance_matrix.copy(source_instanced.instance_matrix))
  target.morph_texture = source_instanced.morph_texture.map(texture => {
    texture.clone()
  })
  target.instance_color = source_instanced.instance_color.map(attribute => {
    attribute.clone()
  })
  object.mesh_data().count = source.mesh_data().count
  target.bounding_box = source_instanced.bounding_box.map(box_ => box_.clone())
  target.bounding_sphere = source_instanced.bounding_sphere.map(sphere => {
    sphere.clone()
  })
}

///|
/// Reads the color of an instance of an `InstancedMesh` or `BatchedMesh`.
pub fn Object3D::get_color_at(
  self : Object3D,
  index : Int32,
  color : @math.Color,
) -> @math.Color {
  match self.kind {
    Mesh({ kind: InstancedMesh(instanced), .. }) =>
      match instanced.instance_color {
        None => color.set_rgb(1.0, 1.0, 1.0)
        Some(instance_color) =>
          typed_array_read_color(instance_color.array, color, index * 3)
      }
    Mesh({ kind: BatchedMesh(batched), .. }) =>
      batched_mesh_get_color_at(self, batched, index, color)
    _ => abort("Object3D.getColorAt: not an InstancedMesh or BatchedMesh")
  }
}

///|
/// Reads the local matrix of an instance of an `InstancedMesh` or `BatchedMesh`.
pub fn Object3D::get_matrix_at(
  self : Object3D,
  index : Int32,
  matrix : @math.Matrix4,
) -> @math.Matrix4 {
  match self.kind {
    Mesh({ kind: InstancedMesh(instanced), .. }) =>
      typed_array_read_matrix4(
        instanced.instance_matrix.array,
        matrix,
        index * 16,
      )
    Mesh({ kind: BatchedMesh(_), .. }) => {
      self.validate_instance_id(index)
      typed_array_read_matrix4(
        batched_mesh_matrices(self.batched_mesh_data()),
        matrix,
        index * 16,
      )
    }
    _ => abort("Object3D.getMatrixAt: not an InstancedMesh or BatchedMesh")
  }
}

///|
/// Copies the morph influences of an instance into `object`.
pub fn Object3D::get_morph_at(
  self : Object3D,
  index : Int32,
  object : Object3D,
) -> Unit {
  guard object.morph_targets() is (_, Some(object_influences)) else {
    abort("InstancedMesh.getMorphAt: object has no morphTargetInfluences")
  }
  guard self.instanced_mesh_data().morph_texture is Some(morph_texture) else {
    abort("InstancedMesh.getMorphAt: morphTexture is not initialized")
  }
  let array = objects_texture_data(morph_texture)
  // All influences + the baseInfluenceSum
  let len = object_influences.length() + 1
  // Skip the baseInfluenceSum at the beginning
  let data_index = index * len + 1
  for i in 0..<object_influences.length() {
    object_influences[i] = array[data_index + i]
  }
}

///|
/// `texture.image.data` of a data texture.
fn objects_texture_data(texture : Texture) -> TypedArray {
  guard texture.source.data is DataImage({ data: Some(data), .. }) else {
    abort("Texture has no typed array image")
  }
  data
}

///|
fn instanced_mesh_raycast(
  object : Object3D,
  raycaster : Raycaster,
  intersects : Array[Intersection],
) -> Unit {
  let source = object.mesh_data()
  let instanced = object.instanced_mesh_data()
  let matrix_world = object.matrix_world
  let raycast_times = source.count
  let scratch = _instanced_mesh_mesh.mesh_data()
  scratch.geometry = source.geometry
  scratch.material = source.material
  // test with bounding sphere first
  if instanced.bounding_sphere is None {
    instanced_mesh_compute_bounding_sphere(object)
  }
  guard instanced.bounding_sphere is Some(bounding_sphere) else {
    abort("InstancedMesh.raycast: no bounding sphere")
  }
  ignore(_instanced_mesh_sphere.copy(bounding_sphere))
  ignore(_instanced_mesh_sphere.apply_matrix4(matrix_world))
  if !raycaster.ray.intersects_sphere(_instanced_mesh_sphere) {
    return
  }
  // now test each instance
  for instance_id in 0..<raycast_times {
    // calculate the world matrix for each instance
    ignore(object.get_matrix_at(instance_id, _instanced_mesh_local_matrix))
    ignore(
      _instanced_mesh_world_matrix.multiply_matrices(
        matrix_world, _instanced_mesh_local_matrix,
      ),
    )
    // the mesh represents this single instance
    _instanced_mesh_mesh.matrix_world = _instanced_mesh_world_matrix
    _instanced_mesh_mesh.raycast(raycaster, _instanced_mesh_intersects)
    // process the result of raycast
    for intersect in _instanced_mesh_intersects {
      intersect.instance_id = Some(instance_id)
      intersect.object = object
      intersects.push(intersect)
    }
    _instanced_mesh_intersects.clear()
  }
}

///|
/// Sets the color of an instance of an `InstancedMesh` or `BatchedMesh`.
pub fn Object3D::set_color_at(
  self : Object3D,
  index : Int32,
  color : @math.Color,
) -> Object3D {
  match self.kind {
    Mesh({ kind: InstancedMesh(instanced), .. }) => {
      let instance_color = match instanced.instance_color {
        Some(instance_color) => instance_color
        None => {
          let array = TypedArray::float32(instanced.instance_matrix.count * 3)
          array.fill(1.0)
          let instance_color = InstancedBufferAttribute::new(array, 3)
          instanced.instance_color = Some(instance_color)
          instance_color
        }
      }
      typed_array_write_color(instance_color.array, color, index * 3)
    }
    Mesh({ kind: BatchedMesh(batched), .. }) =>
      batched_mesh_set_color_at(self, batched, index, color)
    _ => abort("Object3D.setColorAt: not an InstancedMesh or BatchedMesh")
  }
  self
}

///|
/// Sets the local matrix of an instance of an `InstancedMesh` or `BatchedMesh`.
pub fn Object3D::set_matrix_at(
  self : Object3D,
  index : Int32,
  matrix : @math.Matrix4,
) -> Object3D {
  match self.kind {
    Mesh({ kind: InstancedMesh(instanced), .. }) =>
      typed_array_write_matrix4(
        instanced.instance_matrix.array,
        matrix,
        index * 16,
      )
    Mesh({ kind: BatchedMesh(batched), .. }) =>
      batched_mesh_set_matrix_at(self, batched, index, matrix)
    _ => abort("Object3D.setMatrixAt: not an InstancedMesh or BatchedMesh")
  }
  self
}

///|
/// Stores the morph influences of `object` for an instance.
pub fn Object3D::set_morph_at(
  self : Object3D,
  index : Int32,
  object : Object3D,
) -> Object3D {
  let instanced = self.instanced_mesh_data()
  let mesh = self.mesh_data()
  guard object.morph_targets() is (_, Some(object_influences)) else {
    abort("InstancedMesh.setMorphAt: object has no morphTargetInfluences")
  }
  // morphBaseInfluence + all influences
  let len = object_influences.length() + 1
  let morph_texture = match instanced.morph_texture {
    Some(morph_texture) => morph_texture
    None => {
      let morph_texture = DataTexture::new(
        data=TypedArray::float32(len * mesh.count),
        width=len,
        height=mesh.count,
        format=RedFormat,
        type_=FloatType,
      )
      instanced.morph_texture = Some(morph_texture)
      morph_texture
    }
  }
  let array = objects_texture_data(morph_texture)
  let mut morph_influences_sum = 0.0
  for influence in object_influences {
    morph_influences_sum = morph_influences_sum + influence
  }
  let morph_base_influence = if mesh.geometry.morph_targets_relative {
    1.0
  } else {
    1.0 - morph_influences_sum
  }
  let data_index = len * index
  array[data_index] = morph_base_influence
  array.set_from(object_influences, offset=data_index + 1)
  self
}

///|
fn instanced_mesh_dispose(instanced : InstancedMesh) -> Unit {
  instanced.instance_matrix.dispose()
  if instanced.instance_color is Some(instance_color) {
    instance_color.dispose()
  }
  if instanced.morph_texture is Some(morph_texture) {
    morph_texture.dispose()
    instanced.morph_texture = None
  }
}
