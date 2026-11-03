// Upstream examples/jsm/utils/SceneUtils.js. The generators (`traverseGenerator`, ...)
// are lazy `Iter`s.

///|
let _scene_utils_color : @math.Color = @math.Color::new(1.0, 1.0, 1.0)

///|
let _scene_utils_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
/// `createMeshesFromInstancedMesh( instancedMesh )`: a `Group` with one `Mesh` per
/// instance, sharing the geometry and material.
pub fn create_meshes_from_instanced_mesh(
  instanced_mesh : @core.Object3D,
) -> @core.Object3D {
  let group = @core.Group::new()
  let (count, geometry, material) = match instanced_mesh.kind {
    Mesh(m) => (m.count, m.geometry, m.material)
    _ => abort("createMeshesFromInstancedMesh: not an InstancedMesh")
  }
  for i in 0..<count {
    let mesh = @core.Mesh::new(geometry~, material~)
    instanced_mesh.get_matrix_at(i, mesh.matrix) |> ignore
    mesh.matrix.decompose(mesh.position, mesh.quaternion, mesh.scale) |> ignore
    group.add(mesh) |> ignore
  }
  group.copy(instanced_mesh) |> ignore
  group.update_matrix_world() // ensure correct world matrices of meshes
  group
}

///|
/// `createMeshesFromMultiMaterialMesh( mesh )`: a `Group` with one `Mesh` per geometry
/// group of a mesh with an array of materials; other meshes are returned unchanged.
pub fn create_meshes_from_multi_material_mesh(
  mesh : @core.Object3D,
) -> @core.Object3D {
  let (mesh_geometry, materials) = match mesh.kind {
    Mesh({ material: Multiple(materials), geometry, .. }) =>
      (geometry, materials)
    _ => {
      @core.warn(
        "THREE.SceneUtils.createMeshesFromMultiMaterialMesh(): The given mesh has no multiple materials.",
      )
      return mesh
    }
  }
  let object = @core.Group::new()
  object.copy(mesh) |> ignore
  // merge groups (which automatically sorts them)
  let geometry = BufferGeometryUtils::merge_groups(mesh_geometry)
  let index = geometry.index.unwrap()
  let groups = geometry.groups
  let attribute_names = geometry.attributes.keys().collect()
  // create a mesh for each group by extracting the buffer data into a new geometry
  for i in 0..<groups.length() {
    let group = groups[i]
    let start = group.start
    let end = start.to_double() + group.count
    let new_geometry = @core.BufferGeometry::new()
    let new_material = materials[group.material_index]
    // process all buffer attributes
    for j in 0..<attribute_names.length() {
      let name = attribute_names[j]
      let attribute = geometry.attributes[name]
      let item_size = attribute.item_size()
      let new_length = group.count * item_size.to_double()
      let new_array = attribute.array().new_like(new_length.to_int())
      let new_attribute : @core.GeometryAttribute = Buffer(
        @core.BufferAttribute::new(
          new_array,
          item_size,
          normalized=attribute.normalized(),
        ),
      )
      let mut n = 0
      for k = start; k.to_double() < end; k = k + 1 {
        let ind = index.get_x(k).to_int()
        if item_size >= 1 {
          new_attribute.set_x(n, attribute.get_x(ind)) |> ignore
        }
        if item_size >= 2 {
          new_attribute.set_y(n, attribute.get_y(ind)) |> ignore
        }
        if item_size >= 3 {
          new_attribute.set_z(n, attribute.get_z(ind)) |> ignore
        }
        if item_size >= 4 {
          new_attribute.set_w(n, attribute.get_w(ind)) |> ignore
        }
        n += 1
      }
      new_geometry.set_attribute(name, new_attribute) |> ignore
    }
    let new_mesh = @core.Mesh::new(
      geometry=new_geometry,
      material=Single(new_material),
    )
    object.add(new_mesh) |> ignore
  }
  object
}

///|
/// `createMultiMaterialObject( geometry, materials )`: a `Group` with one `Mesh` per
/// material, all sharing `geometry`.
pub fn create_multi_material_object(
  geometry : @core.BufferGeometry,
  materials : Array[@core.Material],
) -> @core.Object3D {
  let group = @core.Group::new()
  for i in 0..<materials.length() {
    group.add(@core.Mesh::new(geometry~, material=Single(materials[i])))
    |> ignore
  }
  group
}

///|
/// `reduceVertices( object, func, initialValue )`: folds `func` over the world-space
/// positions of every vertex of the visible objects below `object`.
pub fn[T] reduce_vertices(
  object : @core.Object3D,
  func : (T, @math.Vector3) -> T,
  initial_value : T,
) -> T {
  let mut value = initial_value
  let vertex = @math.Vector3::new(0.0, 0.0, 0.0)
  object.update_world_matrix(true, true)
  object.traverse_visible(fn(child) {
    if child.get_geometry() is Some(geometry) {
      if geometry.attributes.get("position") is Some(position) {
        for i in 0..<position.count() {
          if child.is_mesh() {
            child.get_vertex_position(i, vertex) |> ignore
          } else {
            vertex.from_buffer_attribute(position, i) |> ignore
          }
          if !child.is_skinned_mesh() {
            vertex.apply_matrix4(child.matrix_world) |> ignore
          }
          value = func(value, vertex)
        }
      }
    }
  })
  value
}

///|
/// `matrix.fromArray( array, offset )` on a typed array.
fn scene_utils_matrix_from(
  matrix : @math.Matrix4,
  array : @core.TypedArray,
  offset : Int32,
) -> Unit {
  for i in 0..<16 {
    matrix.elements[i] = array.get(i + offset)
  }
}

///|
/// `matrix.toArray( array, offset )` into a typed array.
fn scene_utils_matrix_to(
  matrix : @math.Matrix4,
  array : @core.TypedArray,
  offset : Int32,
) -> Unit {
  for i in 0..<16 {
    array.set(offset + i, matrix.elements[i])
  }
}

///|
/// `sortInstancedMesh( mesh, compareFn )`: reorders the instances (matrices, colors and
/// instanced attributes) by sorting the instance indices with `compare_fn`.
pub fn sort_instanced_mesh(
  mesh : @core.Object3D,
  compare_fn : (Int32, Int32) -> Double,
) -> Unit {
  let (instanced, geometry, count) = match mesh.kind {
    Mesh({ kind: InstancedMesh(instanced), geometry, count, .. }) =>
      (instanced, geometry, count)
    _ => abort("sortInstancedMesh: not an InstancedMesh")
  }
  // store copy of instanced attributes for lookups
  let instance_matrix_ref = BufferGeometryUtils::deep_clone_attribute(
    Buffer(instanced.instance_matrix),
  )
  let instance_color_ref = match instanced.instance_color {
    Some(color) =>
      Some(BufferGeometryUtils::deep_clone_attribute(Buffer(color)))
    None => None
  }
  // `new Map()` keyed by the attribute
  let attribute_refs : Array[(@core.BufferAttribute, @core.BufferAttribute)] = []
  for _, attribute in geometry.attributes {
    if attribute is Buffer(a) && a.is_instanced_buffer_attribute() {
      let clone = BufferGeometryUtils::deep_clone_attribute(attribute)
      match attribute_refs.search_by(fn(entry) { physical_equal(entry.0, a) }) {
        Some(k) => attribute_refs[k] = (a, clone)
        None => attribute_refs.push((a, clone))
      }
    }
  }
  // compute sort order
  let tokens : Array[Int32] = []
  for i in 0..<count {
    tokens.push(i)
  }
  @webgl.stable_sort_by(tokens, compare_fn)
  // apply sort order
  for i in 0..<tokens.length() {
    let ref_index = tokens[i]
    let instance_matrix = instanced.instance_matrix
    scene_utils_matrix_from(
      _scene_utils_matrix,
      instance_matrix_ref.array,
      ref_index * instance_matrix.item_size,
    )
    scene_utils_matrix_to(
      _scene_utils_matrix,
      instance_matrix.array,
      i * instance_matrix.item_size,
    )
    if instanced.instance_color is Some(instance_color) {
      let color_ref = instance_color_ref.unwrap().array
      let offset = ref_index * instance_color.item_size
      _scene_utils_color.r = color_ref.get(offset)
      _scene_utils_color.g = color_ref.get(offset + 1)
      _scene_utils_color.b = color_ref.get(offset + 2)
      let offset = i * instance_color.item_size
      instance_color.array.set(offset, _scene_utils_color.r)
      instance_color.array.set(offset + 1, _scene_utils_color.g)
      instance_color.array.set(offset + 2, _scene_utils_color.b)
    }
    for _, attribute in geometry.attributes {
      if attribute is Buffer(a) && a.is_instanced_buffer_attribute() {
        let attribute_ref = attribute_refs[attribute_refs
          .search_by(fn(entry) { physical_equal(entry.0, a) })
          .unwrap()].1
        attribute.set_x(i, attribute_ref.get_x(ref_index)) |> ignore
        if a.item_size > 1 {
          attribute.set_y(i, attribute_ref.get_y(ref_index)) |> ignore
        }
        if a.item_size > 2 {
          attribute.set_z(i, attribute_ref.get_z(ref_index)) |> ignore
        }
        if a.item_size > 3 {
          attribute.set_w(i, attribute_ref.get_w(ref_index)) |> ignore
        }
      }
    }
  }
}

///|
/// `traverseGenerator( object )`: `object` and its descendants, depth first, read
/// lazily as upstream's generator.
pub fn traverse_generator(object : @core.Object3D) -> Iter[@core.Object3D] {
  scene_utils_generator(object, false)
}

///|
/// `traverseVisibleGenerator( object )`: like `traverse_generator`, skipping invisible
/// objects and their descendants.
pub fn traverse_visible_generator(
  object : @core.Object3D,
) -> Iter[@core.Object3D] {
  scene_utils_generator(object, true)
}

///|
/// One suspended `traverse*Generator( object )` call.
priv struct SceneUtilsFrame {
  object : @core.Object3D
  /// 0: not started, 1: suspended after `yield object`, 2: in the children loop
  mut phase : Int32
  mut children : Array[@core.Object3D]
  mut i : Int32
  mut l : Int32
}

///|
fn scene_utils_generator(
  object : @core.Object3D,
  visible_only : Bool,
) -> Iter[@core.Object3D] {
  let stack : Array[SceneUtilsFrame] = [
    { object, phase: 0, children: [], i: 0, l: 0, },
  ]
  Iter::new(fn() {
    while stack.last() is Some(frame) {
      match frame.phase {
        0 => {
          if visible_only && frame.object.visible == false {
            stack.pop() |> ignore
            continue
          }
          frame.phase = 1
          return Some(frame.object)
        }
        1 => {
          frame.children = frame.object.children
          frame.l = frame.children.length()
          frame.i = 0
          frame.phase = 2
        }
        _ =>
          if frame.i < frame.l {
            let child = frame.children[frame.i]
            frame.i += 1
            stack.push({ object: child, phase: 0, children: [], i: 0, l: 0, })
          } else {
            stack.pop() |> ignore
          }
      }
    }
    None
  })
}

///|
/// `traverseAncestorsGenerator( object )`: the parent of `object`, its parent, ...
pub fn traverse_ancestors_generator(
  object : @core.Object3D,
) -> Iter[@core.Object3D] {
  let mut current : @core.Object3D? = Some(object)
  Iter::new(fn() {
    match current {
      Some(object) =>
        match object.parent {
          Some(parent) => {
            current = Some(parent)
            Some(parent)
          }
          None => {
            current = None
            None
          }
        }
      None => None
    }
  })
}
