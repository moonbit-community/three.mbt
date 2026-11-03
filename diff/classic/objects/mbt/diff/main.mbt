// Differential runner: reads scenarios.json, runs them on the port and writes port.json.
// The scenario format and output shape mirror run_upstream.mjs.

///|
extern "js" fn read_json(path : String) -> @core.JsValue =
  #|(p) => JSON.parse(process.getBuiltinModule('fs').readFileSync(p, 'utf8'))

///|
extern "js" fn write_results(path : String, value : @core.JsValue) -> Unit =
  #|(p, v) => process.getBuiltinModule('fs').writeFileSync(p, JSON.stringify(v, (k, x) => {
  #|  if (x === undefined) return '@undefined';
  #|  if (typeof x === 'number') {
  #|    if (Number.isNaN(x)) return '@NaN';
  #|    if (x === Infinity) return '@Inf';
  #|    if (x === -Infinity) return '@-Inf';
  #|    if (Object.is(x, -0)) return '@-0';
  #|  }
  #|  return x;
  #|}))

///|
extern "js" fn arg(index : Int) -> String = "(i) => process.argv[i]"

///|
extern "js" fn js_is_nullish(v : @core.JsValue) -> Bool = "(v) => v === null || v === undefined"

///|
extern "js" fn js_array() -> @core.JsValue = "() => []"

///|
extern "js" fn js_push(a : @core.JsValue, v : @core.JsValue) -> Unit = "(a, v) => { a.push(v); }"

///|
extern "js" fn js_len(a : @core.JsValue) -> Int = "(a) => a.length"

///|
extern "js" fn js_at(a : @core.JsValue, i : Int) -> @core.JsValue = "(a, i) => a[i]"

///|
extern "js" fn js_sort_hits(a : @core.JsValue) -> Unit = "(a) => { a.sort((x, y) => x.distance - y.distance); }"

///|
extern "js" fn js_infinity() -> Double = "() => Infinity"

///|
extern "js" fn typed_to_array(a : @core.TypedArray) -> @core.JsValue = "(a) => Array.from(a)"

///|
extern "js" fn silence_console() -> Unit =
  #|() => { console.log = () => {}; }

///|
fn[T] jv(x : T) -> @core.JsValue {
  @core.JsValue::of(x)
}

///|
fn nums(v : @core.JsValue) -> Array[Double] {
  v.cast()
}

///|
fn num(v : @core.JsValue) -> Double {
  v.cast()
}

///|
fn int(v : @core.JsValue) -> Int {
  (v.cast() : Double).to_int()
}

///|
fn bool(v : @core.JsValue) -> Bool {
  v.cast()
}

///|
fn str(v : @core.JsValue) -> String {
  v.cast()
}

///|
fn items(v : @core.JsValue) -> Array[@core.JsValue] {
  v.cast()
}

///|
fn has(v : @core.JsValue, key : String) -> Bool {
  !js_is_nullish(v.get(key))
}

///|
fn v3(v : @core.JsValue) -> @math.Vector3 {
  let a = nums(v)
  @math.Vector3::new(a[0], a[1], a[2])
}

///|
fn arr3(v : @math.Vector3) -> @core.JsValue {
  jv([v.x, v.y, v.z])
}

///|
fn arr2(v : @math.Vector2) -> @core.JsValue {
  jv([v.x, v.y])
}

///|
fn arr4(v : @math.Vector4) -> @core.JsValue {
  jv([v.x, v.y, v.z, v.w])
}

///|
fn list(xs : Array[@core.JsValue]) -> @core.JsValue {
  jv(xs)
}

///|
fn obj(fields : Array[(String, @core.JsValue)]) -> @core.JsValue {
  let o = @core.JsValue::object()
  for field in fields {
    o.set(field.0, field.1)
  }
  o
}

///|
fn[T] opt(x : T?, f : (T) -> @core.JsValue) -> @core.JsValue {
  match x {
    Some(x) => f(x)
    None => @core.JsValue::null()
  }
}

///|
fn apply_transform(o : @core.Object3D, t : @core.JsValue) -> Unit {
  let p = nums(t.get("p"))
  let q = nums(t.get("q"))
  let s = nums(t.get("s"))
  ignore(o.position.set(p[0], p[1], p[2]))
  ignore(o.quaternion.set(q[0], q[1], q[2], q[3]))
  ignore(o.scale.set(s[0], s[1], s[2]))
}

///|
fn build_geometry(g : @core.JsValue) -> @core.BufferGeometry {
  let geo = @core.BufferGeometry::new()
  if has(g, "interleaved") {
    let spec = g.get("interleaved")
    let ib = @core.InterleavedBuffer::new(
      @core.TypedArray::float32(nums(spec.get("array"))),
      int(spec.get("stride")),
    )
    ignore(
      geo.set_attribute(
        "position",
        @core.InterleavedBufferAttribute::new(ib, 3, 0),
      ),
    )
    if has(spec, "uvOffset") {
      ignore(
        geo.set_attribute(
          "uv",
          @core.InterleavedBufferAttribute::new(ib, 2, int(spec.get("uvOffset"))),
        ),
      )
    }
  } else if has(g, "position") {
    ignore(
      geo.set_attribute(
        "position",
        @core.Float32BufferAttribute::new(nums(g.get("position")), 3),
      ),
    )
  }
  if has(g, "index") {
    ignore(geo.set_index(nums(g.get("index"))))
  }
  if has(g, "uv") {
    ignore(
      geo.set_attribute(
        "uv",
        @core.Float32BufferAttribute::new(nums(g.get("uv")), 2),
      ),
    )
  }
  if has(g, "uv1") {
    ignore(
      geo.set_attribute(
        "uv1",
        @core.Float32BufferAttribute::new(nums(g.get("uv1")), 2),
      ),
    )
  }
  if has(g, "uvNorm") {
    ignore(
      geo.set_attribute(
        "uv",
        @core.BufferAttribute::new(
          @core.TypedArray::int16(nums(g.get("uvNorm"))),
          2,
          normalized=true,
        ),
      ),
    )
  }
  if has(g, "normal") {
    ignore(
      geo.set_attribute(
        "normal",
        @core.Float32BufferAttribute::new(nums(g.get("normal")), 3),
      ),
    )
  }
  if has(g, "skinIndex") {
    ignore(
      geo.set_attribute(
        "skinIndex",
        @core.Uint16BufferAttribute::new(nums(g.get("skinIndex")), 4),
      ),
    )
  }
  if has(g, "skinWeight") {
    ignore(
      geo.set_attribute(
        "skinWeight",
        @core.Float32BufferAttribute::new(nums(g.get("skinWeight")), 4),
      ),
    )
  }
  if has(g, "morph") {
    let morph : Array[@core.GeometryAttribute] = []
    for i, a in items(g.get("morph")) {
      let attr = @core.Float32BufferAttribute::new(nums(a), 3)
      if i % 2 == 0 {
        attr.name = "m\{i}"
      }
      morph.push(Buffer(attr))
    }
    geo.morph_attributes["position"] = morph
    geo.morph_targets_relative = bool(g.get("morphRelative"))
  }
  if has(g, "groups") {
    for group in items(g.get("groups")) {
      let parts = items(group)
      let count = if js_is_nullish(parts[1]) { js_infinity() } else { num(parts[1]) }
      geo.add_group(int(parts[0]), count, material_index=int(parts[2]))
    }
  }
  if has(g, "drawRange") {
    let parts = items(g.get("drawRange"))
    let count = if js_is_nullish(parts[1]) { js_infinity() } else { num(parts[1]) }
    geo.set_draw_range(int(parts[0]), count)
  }
  geo
}

///|
fn material_of(m : @core.JsValue, make : () -> @core.Material) -> @core.Material {
  let material = make()
  if !js_is_nullish(m) {
    material.side = int(m.get("side"))
  }
  material
}

///|
fn slot(
  n : @core.JsValue,
  make : () -> @core.Material,
) -> @core.MaterialSlot {
  if has(n, "materials") {
    Multiple(items(n.get("materials")).map(m => material_of(m, make)))
  } else {
    Single(material_of(n.get("material"), make))
  }
}

///|
struct BuiltBones {
  bones : Array[@core.Object3D]
  roots : Array[@core.Object3D]
  skeleton : @core.Skeleton
}

///|
fn build_skeleton(spec : @core.JsValue) -> BuiltBones {
  let parents = items(spec.get("parents"))
  let rest = items(spec.get("rest"))
  let bones = parents.map(_ => @core.Bone::new())
  let roots = []
  for i, p in parents {
    apply_transform(bones[i], rest[i])
    let p = int(p)
    if p < 0 {
      roots.push(bones[i])
    } else {
      ignore(bones[p].add(bones[i]))
    }
  }
  for r in roots {
    r.update_matrix_world(force=true)
  }
  { bones, roots, skeleton: @core.Skeleton::new(bones~) }
}

///|
fn pose_bones(built : BuiltBones, spec : @core.JsValue) -> Unit {
  for i, t in items(spec.get("posed")) {
    apply_transform(built.bones[i], t)
  }
  for r in built.roots {
    r.update_matrix_world(force=true)
  }
}

///|
let built_bones : Map[String, BuiltBones] = Map([])

///|
fn matrix_from(a : Array[Double], offset : Int) -> @math.Matrix4 {
  @math.Matrix4::new().from_array(a, offset~)
}

///|
fn build_node(n : @core.JsValue) -> @core.Object3D {
  let type_ = str(n.get("type"))
  let geometry = () => build_geometry(n.get("geometry"))
  let o = match type_ {
    "mesh" =>
      @core.Mesh::new(
        geometry=geometry(),
        material=slot(n, @core.MeshBasicMaterial::new),
      )
    "line" =>
      @core.Line::new(
        geometry=geometry(),
        material=slot(n, @core.LineBasicMaterial::new),
      )
    "lineLoop" =>
      @core.LineLoop::new(
        geometry=geometry(),
        material=slot(n, @core.LineBasicMaterial::new),
      )
    "lineSegments" =>
      @core.LineSegments::new(
        geometry=geometry(),
        material=slot(n, @core.LineBasicMaterial::new),
      )
    "points" =>
      @core.Points::new(
        geometry=geometry(),
        material=slot(n, @core.PointsMaterial::new),
      )
    "group" => @core.Group::new()
    "sprite" => {
      let m = @core.SpriteMaterial::new()
      m.rotation = Some(num(n.get("rotation")))
      m.size_attenuation = Some(bool(n.get("sizeAttenuation")))
      let o = @core.Sprite::new(material=m)
      guard o.kind is Sprite(sprite) else { abort("sprite") }
      let center = nums(n.get("center"))
      ignore(sprite.center.set(center[0], center[1]))
      o
    }
    "instanced" => {
      let count = int(n.get("count"))
      let o = @core.InstancedMesh::new(
        geometry=geometry(),
        material=slot(n, @core.MeshBasicMaterial::new),
        count,
      )
      let matrices = nums(n.get("matrices"))
      for i in 0..<count {
        ignore(o.set_matrix_at(i, matrix_from(matrices, i * 16)))
      }
      o
    }
    "skinned" =>
      @core.SkinnedMesh::new(
        geometry=geometry(),
        material=slot(n, @core.MeshBasicMaterial::new),
      )
    "lod" => {
      let o = @core.LOD::new()
      for l in items(n.get("levels")) {
        ignore(
          o.add_level(
            build_node(l.get("node")),
            distance=num(l.get("distance")),
            hysteresis=num(l.get("hysteresis")),
          ),
        )
      }
      o
    }
    _ => abort("unknown node type " + type_)
  }
  if has(n, "influences") {
    let (_, influences) = o.morph_targets()
    guard influences is Some(influences) else { abort("no influences") }
    for i, v in nums(n.get("influences")) {
      influences[i] = v
    }
  }
  apply_transform(o, n.get("transform"))
  if type_ == "skinned" {
    guard o.kind is Mesh({ kind: SkinnedMesh(skinned), .. }) else {
      abort("skinned")
    }
    skinned.bind_mode = str(n.get("bindMode"))
    o.update_matrix_world(force=true)
    let built = build_skeleton(n.get("skeleton"))
    if has(n, "bindMatrix") {
      o.bind(
        built.skeleton,
        bind_matrix=matrix_from(nums(n.get("bindMatrix")), 0),
      )
    } else {
      o.bind(built.skeleton)
    }
    pose_bones(built, n.get("skeleton"))
    built.skeleton.update()
    built_bones[o.uuid] = built
  }
  if has(n, "children") {
    for c in items(n.get("children")) {
      ignore(o.add(build_node(c)))
    }
  }
  o
}

///|
fn build_camera(c : @core.JsValue) -> @core.Object3D {
  let cam = if str(c.get("type")) == "perspective" {
    @core.PerspectiveCamera::new(
      fov=num(c.get("fov")),
      aspect=num(c.get("aspect")),
      near=num(c.get("near")),
      far=num(c.get("far")),
    )
  } else {
    @core.OrthographicCamera::new(
      left=num(c.get("left")),
      right=num(c.get("right")),
      top=num(c.get("top")),
      bottom=num(c.get("bottom")),
      near=num(c.get("near")),
      far=num(c.get("far")),
    )
  }
  apply_transform(cam, c.get("transform"))
  guard cam.kind is Camera(data) else { abort("camera") }
  if has(c, "zoom") {
    match data.kind {
      PerspectiveCamera(p) => p.zoom = num(c.get("zoom"))
      OrthographicCamera(p) => p.zoom = num(c.get("zoom"))
      _ => ()
    }
  }
  if has(c, "webgpu") && bool(c.get("webgpu")) {
    data.coordinate_system = @math.WebGPUCoordinateSystem
  }
  if has(c, "reversed") && bool(c.get("reversed")) {
    data._reversed_depth = true
  }
  cam.update_projection_matrix()
  cam.update_matrix_world(force=true)
  cam
}

///|
fn encode_hit(h : @core.Intersection) -> @core.JsValue {
  obj([
    ("distance", jv(h.distance)),
    ("distanceToRay", opt(h.distance_to_ray, jv)),
    ("point", arr3(h.point)),
    ("index", opt(h.index, jv)),
    (
      "face",
      opt(h.face, face => {
        obj([
          ("a", jv(face.a)),
          ("b", jv(face.b)),
          ("c", jv(face.c)),
          ("normal", arr3(face.normal)),
          ("materialIndex", jv(face.material_index)),
        ])
      }),
    ),
    ("faceIndex", opt(h.face_index, jv)),
    ("barycoord", opt(h.barycoord, arr3)),
    ("uv", opt(h.uv, arr2)),
    ("uv1", opt(h.uv1, arr2)),
    ("normal", opt(h.normal, arr3)),
    ("instanceId", opt(h.instance_id, jv)),
    ("batchId", opt(h.batch_id, jv)),
  ])
}

///|
fn prepare(n : @core.JsValue, o : @core.Object3D) -> Unit {
  if has(n, "computeDistances") &&
    bool(n.get("computeDistances")) &&
    o.get_geometry().unwrap().index is None {
    ignore(o.compute_line_distances())
  }
  if has(n, "computeBox") && bool(n.get("computeBox")) {
    o.compute_bounding_box()
  }
  if has(n, "normalize") && bool(n.get("normalize")) {
    o.normalize_skin_weights()
  }
  if has(n, "children") {
    for i, c in items(n.get("children")) {
      prepare(c, o.children[i])
    }
  }
}

///|
fn raycaster_for(r : @core.JsValue) -> @core.Raycaster {
  let far = if has(r, "far") { num(r.get("far")) } else { js_infinity() }
  let rc = @core.Raycaster::new(
    origin=v3(r.get("o")),
    direction=v3(r.get("d")),
    near=num(r.get("near")),
    far~,
  )
  rc.params.line.threshold = num(r.get("lineT"))
  rc.params.points.threshold = num(r.get("pointsT"))
  rc
}

///|
fn box_json(b : @math.Box3) -> @core.JsValue {
  list([arr3(b.min), arr3(b.max)])
}

///|
fn run_raycast(s : @core.JsValue) -> @core.JsValue {
  let node = s.get("node")
  let o = build_node(node)
  prepare(node, o)
  o.update_matrix_world(force=true)
  let o = if has(s, "clone") && bool(s.get("clone")) {
    let copy = o.clone()
    copy.update_matrix_world(force=true)
    copy
  } else {
    o
  }
  let cam = @core.PerspectiveCamera::new(fov=60, aspect=1, near=0.1, far=100)
  ignore(cam.position.set(0, 0, 9))
  cam.update_matrix_world(force=true)
  let out = @core.JsValue::object()
  if has(node, "computeDistances") &&
    bool(node.get("computeDistances")) &&
    o.get_geometry().unwrap().index is None {
    guard o.get_geometry().unwrap().attributes["lineDistance"] is Buffer(d) else {
      abort("lineDistance")
    }
    out.set("lineDistances", typed_to_array(d.array))
  }
  out.set(
    "hits",
    list(
      items(s.get("rays")).map(r => {
        let rc = raycaster_for(r)
        rc.camera = Some(cam)
        list(rc.intersect_object(o, recursive=true).map(encode_hit))
      }),
    ),
  )
  if str(node.get("type")) == "instanced" {
    o.compute_bounding_box()
    guard o.kind is Mesh({ kind: InstancedMesh(instanced), .. }) else {
      abort("instanced")
    }
    out.set(
      "box",
      list([
        arr3(instanced.bounding_box.unwrap().min),
        arr3(instanced.bounding_box.unwrap().max),
        opt(instanced.bounding_sphere, sphere => {
          list([arr3(sphere.center), jv(sphere.radius)])
        }),
      ]),
    )
  }
  out
}

///|
fn run_sprite(s : @core.JsValue) -> @core.JsValue {
  let o = build_node(s.get("node"))
  o.update_matrix_world(force=true)
  let cam = build_camera(s.get("camera"))
  let center = o.get_world_position(@math.Vector3::new(0, 0, 0)).project(cam)
  let far = if has(s, "far") { num(s.get("far")) } else { js_infinity() }
  let hits = items(s.get("ndc")).map(ndc => {
    let rc = @core.Raycaster::new()
    rc.near = num(s.get("near"))
    rc.far = far
    let coords = if js_is_nullish(ndc) {
      @math.Vector2::new(center.x, center.y)
    } else {
      let a = nums(ndc)
      @math.Vector2::new(a[0], a[1])
    }
    rc.set_from_camera(coords, cam)
    obj([
      ("ray", list([arr3(rc.ray.origin), arr3(rc.ray.direction)])),
      ("hit", list(rc.intersect_object(o).map(encode_hit))),
    ])
  })
  obj([("hits", list(hits))])
}

///|
fn run_skinning(s : @core.JsValue) -> @core.JsValue {
  let node = s.get("node")
  let o = build_node(node)
  prepare(node, o)
  o.update_matrix_world(force=true)
  guard o.kind is Mesh({ kind: SkinnedMesh(skinned), geometry, .. }) else {
    abort("skinned")
  }
  let skeleton = skinned.skeleton.unwrap()
  let count = geometry.get_attribute("position").unwrap().count()
  let vectors = items(s.get("vectors"))
  let v3s = []
  let v4s = []
  let verts = []
  for i in 0..<count {
    let t = nums(vectors[i % vectors.length()])
    let a = @math.Vector3::new(t[0], t[1], t[2])
    v3s.push(arr3(o.apply_bone_transform(i, a)))
    let b = @math.Vector4::new(t[0], t[1], t[2], t[3])
    v4s.push(arr4(o.apply_bone_transform_vector4(i, b)))
    verts.push(arr3(o.get_vertex_position(i, @math.Vector3::new(0, 0, 0))))
  }
  o.compute_bounding_box()
  o.compute_bounding_sphere()
  let box_ = skinned.bounding_box.unwrap()
  let sphere = skinned.bounding_sphere.unwrap()
  let bone_matrices = typed_to_array(skeleton.bone_matrices.unwrap())
  let bind_inverse = jv(skinned.bind_matrix_inverse.to_array())
  o.pose()
  o.update_matrix_world(force=true)
  let posed = built_bones[o.uuid].bones.map(b => {
    list([
      arr3(b.position),
      jv([b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w]),
      arr3(b.scale),
      jv(b.matrix_world.to_array()),
    ])
  })
  obj([
    ("boneMatrices", bone_matrices),
    ("bindInverse", bind_inverse),
    ("v3", list(v3s)),
    ("v4", list(v4s)),
    ("verts", list(verts)),
    ("box", box_json(box_)),
    ("sphere", list([arr3(sphere.center), jv(sphere.radius)])),
    ("posed", list(posed)),
  ])
}

///|
fn run_skeleton(s : @core.JsValue) -> @core.JsValue {
  let spec = s.get("spec")
  let built = build_skeleton(spec)
  let skel = built.skeleton
  let bones = built.bones
  let inverses = list(skel.bone_inverses.map(m => jv(m.to_array())))
  ignore(skel.compute_bone_texture())
  guard skel.bone_texture.unwrap().source.data is DataImage({ width, .. }) else {
    abort("texture")
  }
  let rounds = []
  let posed = items(spec.get("posed"))
  for r in 0..<int(s.get("rounds")) {
    for i, t in posed {
      if (i + r) % 2 == 0 {
        apply_transform(bones[i], t)
      }
    }
    for b in built.roots {
      b.update_matrix_world(force=true)
    }
    skel.update()
    let m = typed_to_array(skel.bone_matrices.unwrap())
    skel.pose()
    for b in built.roots {
      b.update_matrix_world(force=true)
    }
    rounds.push(
      list([
        m,
        list(
          bones.map(b => {
            list([
              arr3(b.position),
              jv([b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w]),
              arr3(b.scale),
            ])
          }),
        ),
        jv(skel.bone_texture.unwrap().version),
      ]),
    )
  }
  guard skel.to_json() is Object(json) else { abort("json") }
  guard json["bones"] is Array(json_bones) else { abort("json") }
  obj([
    ("inverses", inverses),
    ("textureSize", jv(width)),
    ("textureLength", jv(skel.bone_matrices.unwrap().length())),
    ("rounds", list(rounds)),
    (
      "json",
      list([
        jv(json_bones.length()),
        @core.JsValue::from_json(json["boneInverses"]),
      ]),
    ),
  ])
}

///|
fn run_box3(s : @core.JsValue) -> @core.JsValue {
  let node = s.get("node")
  let o = build_node(node)
  prepare(node, o)
  o.update_matrix_world(force=true)
  let out = @core.JsValue::object()
  out.set("coarse", box_json(@core.box3_set_from_object(@math.Box3::new(), o)))
  out.set(
    "precise",
    box_json(@core.box3_set_from_object(@math.Box3::new(), o, precise=true)),
  )
  if has(s, "start") {
    let start = items(s.get("start"))
    let b = @math.Box3::new(min=v3(start[0]), max=v3(start[1]))
    out.set("expanded", box_json(@core.box3_expand_by_object(b.clone(), o)))
    out.set(
      "expandedPrecise",
      box_json(@core.box3_expand_by_object(b.clone(), o, precise=true)),
    )
  }
  out
}

///|
fn run_triangle(s : @core.JsValue) -> @core.JsValue {
  let a = s.get("attr")
  let mode = str(a.get("mode"))
  let item_size = int(a.get("itemSize"))
  let array = nums(a.get("array"))
  let attribute : @core.GeometryAttribute = match mode {
    "float" => Buffer(@core.Float32BufferAttribute::new(array, item_size))
    "int16norm" =>
      Buffer(
        @core.BufferAttribute::new(
          @core.TypedArray::int16(array),
          item_size,
          normalized=true,
        ),
      )
    _ =>
      Interleaved(
        @core.InterleavedBufferAttribute::new(
          @core.InterleavedBuffer::new(
            @core.TypedArray::float32(array),
            item_size + 1,
          ),
          item_size,
          int(a.get("offset")),
        ),
      )
  }
  list(
    items(s.get("calls")).map(c => {
      let b = v3(c.get("bary"))
      let i = items(c.get("i"))
      let i1 = int(i[0])
      let i2 = int(i[1])
      let i3 = int(i[2])
      let t = @core.triangle_set_from_attribute_and_indices(
        @math.Triangle::new(),
        attribute,
        i1,
        i2,
        i3,
      )
      obj([
        (
          "v2",
          arr2(
            @core.triangle_get_interpolated_attribute(
              attribute,
              i1,
              i2,
              i3,
              b,
              @math.Vector2::new(9, 9),
            ),
          ),
        ),
        (
          "v3",
          arr3(
            @core.triangle_get_interpolated_attribute(
              attribute,
              i1,
              i2,
              i3,
              b,
              @math.Vector3::new(9, 9, 9),
            ),
          ),
        ),
        (
          "v4",
          arr4(
            @core.triangle_get_interpolated_attribute(
              attribute,
              i1,
              i2,
              i3,
              b,
              @math.Vector4::new(9, 9, 9, 9),
            ),
          ),
        ),
        ("tri", list([arr3(t.a), arr3(t.b), arr3(t.c)])),
      ])
    }),
  )
}

///|
fn run_frustum(s : @core.JsValue) -> @core.JsValue {
  let node = s.get("node")
  let o = build_node(node)
  prepare(node, o)
  o.update_matrix_world(force=true)
  let cam = build_camera(s.get("camera"))
  guard cam.kind is Camera(data) else { abort("camera") }
  let m = @math.Matrix4::new().multiply_matrices(
    cam.projection_matrix(),
    cam.matrix_world_inverse(),
  )
  let f = @math.Frustum::new().set_from_projection_matrix(
    m,
    coordinate_system=data.coordinate_system,
    reversed_depth=data._reversed_depth,
  )
  let via_method = o.intersects_frustum(Single(f))
  let direct = if o.is_sprite() {
    @core.frustum_intersects_sprite(f, o)
  } else {
    @core.frustum_intersects_object(f, o)
  }
  obj([("viaMethod", jv(via_method)), ("direct", jv(direct))])
}

///|
fn run_frustum_array(s : @core.JsValue) -> @core.JsValue {
  let cams = items(s.get("cameras")).map(build_camera)
  let array = @core.ArrayCamera::new(array=cams)
  guard array.kind
    is Camera({ kind: PerspectiveCamera({ array_camera: Some(data), .. }), .. }) else {
    abort("array camera")
  }
  let fa = @math.FrustumArray::new()
  let objs = items(s.get("nodes")).map(n => {
    let o = build_node(n)
    prepare(n, o)
    o.update_matrix_world(force=true)
    o
  })
  let out = []
  for r in 0..<int(s.get("rounds")) {
    data.cameras = cams[r % cams.length():].to_array()
    ignore(@core.frustum_array_set_from_array_camera(fa, array))
    out.push(
      list([
        jv(fa.count),
        list(
          objs.map(o => {
            let direct = if o.is_sprite() {
              @core.frustum_array_intersects_sprite(fa, o)
            } else {
              @core.frustum_array_intersects_object(fa, o)
            }
            list([jv(direct), jv(o.intersects_frustum(Array(fa)))])
          }),
        ),
        list(
          fa.frustums.map(x => {
            list(
              x.planes.map(p => {
                jv([p.normal.x, p.normal.y, p.normal.z, p.constant])
              }),
            )
          }),
        ),
      ]),
    )
  }
  list(out)
}

///|
fn batched_state(o : @core.Object3D) -> @core.JsValue {
  guard o.kind is Mesh({ kind: BatchedMesh(b), geometry, .. }) else {
    abort("batched")
  }
  let attr = fn(name : String) {
    opt(geometry.attributes.get(name), a => typed_to_array(a.array()))
  }
  let image = fn(t : @core.Texture) {
    guard t.source.data is DataImage({ data: Some(data), .. }) else {
      abort("image")
    }
    typed_to_array(data)
  }
  guard b._matrices_texture.unwrap().source.data is DataImage({ width, .. }) else {
    abort("image")
  }
  obj([
    ("instanceCount", jv(o.instance_count())),
    ("maxInstanceCount", jv(o.max_instance_count())),
    ("unusedVertexCount", jv(o.unused_vertex_count())),
    ("unusedIndexCount", jv(o.unused_index_count())),
    ("nextIndexStart", jv(b._next_index_start)),
    ("nextVertexStart", jv(b._next_vertex_start)),
    ("geometryCount", jv(b._geometry_count)),
    ("availableInstanceIds", jv(b._available_instance_ids)),
    ("availableGeometryIds", jv(b._available_geometry_ids)),
    (
      "instanceInfo",
      list(
        b._instance_info.map(i => {
          list([jv(i.visible), jv(i.active), jv(i.geometry_index)])
        }),
      ),
    ),
    (
      "geometryInfo",
      list(
        b._geometry_info.map(g => {
          list([
            jv(g.vertex_start),
            jv(g.vertex_count),
            jv(g.reserved_vertex_count),
            jv(g.index_start),
            jv(g.index_count),
            jv(g.reserved_index_count),
            jv(g.start),
            jv(g.count),
            jv(g.active),
          ])
        }),
      ),
    ),
    ("index", opt(geometry.index, a => typed_to_array(a.array()))),
    ("position", attr("position")),
    ("uv", attr("uv")),
    (
      "positionRanges",
      opt(geometry.attributes.get("position"), a => {
        guard a is Buffer(a) else { abort("buffer") }
        list(a.update_ranges.map(r => list([jv(r.start), jv(r.count)])))
      }),
    ),
    ("matrices", image(b._matrices_texture.unwrap())),
    ("matricesSize", jv(width)),
    ("indirect", image(b._indirect_texture.unwrap())),
    ("colors", opt(b._colors_texture, image)),
    (
      "versions",
      list([
        jv(b._matrices_texture.unwrap().version),
        jv(b._indirect_texture.unwrap().version),
        match b._colors_texture {
          Some(t) => jv(t.version)
          None => jv(-1)
        },
      ]),
    ),
  ])
}

///|
fn run_batched(s : @core.JsValue) -> @core.JsValue {
  let material = @core.MeshBasicMaterial::new()
  material.side = int(s.get("side"))
  let mesh = @core.BatchedMesh::new(
    int(s.get("maxInstances")),
    int(s.get("maxVertices")),
    max_index_count=int(s.get("maxIndices")),
    material=Single(material),
  )
  apply_transform(mesh, s.get("transform"))
  mesh.update_matrix_world(force=true)
  guard mesh.kind is Mesh({ kind: BatchedMesh(b), .. }) else { abort("batched") }
  let geometries = items(s.get("geometries")).map(build_geometry)
  let out = []
  for op in items(s.get("ops")) {
    let op = items(op)
    match str(op[0]) {
      "addGeometry" =>
        out.push(
          jv(
            mesh.add_geometry(
              geometries[int(op[1])],
              reserved_vertex_count=int(op[2]),
              reserved_index_count=int(op[3]),
            ),
          ),
        )
      "addInstance" => out.push(jv(mesh.add_instance(int(op[1]))))
      "setMatrixAt" =>
        ignore(mesh.set_matrix_at(int(op[1]), matrix_from(nums(op[2]), 0)))
      "setColorAt" => {
        let c = nums(op[2])
        ignore(mesh.set_color_at(int(op[1]), @math.Color::new(c[0], c[1], c[2])))
        let got = mesh.get_color_at(int(op[1]), @math.Color::new(0, 0, 0))
        out.push(jv([got.r, got.g, got.b]))
      }
      "setVisibleAt" => {
        ignore(mesh.set_visible_at(int(op[1]), bool(op[2])))
        out.push(jv(mesh.get_visible_at(int(op[1]))))
      }
      "deleteInstance" => ignore(mesh.delete_instance(int(op[1])))
      "deleteGeometry" => ignore(mesh.delete_geometry(int(op[1])))
      "optimize" => ignore(mesh.optimize())
      "setInstanceCount" => mesh.set_instance_count(int(op[1]))
      "setGeometrySize" => mesh.set_geometry_size(int(op[1]), int(op[2]))
      "setGeometryAt" =>
        out.push(jv(mesh.set_geometry_at(int(op[1]), geometries[int(op[2])])))
      "setGeometryIdAt" => {
        ignore(mesh.set_geometry_id_at(int(op[1]), int(op[2])))
        out.push(jv(mesh.get_geometry_id_at(int(op[1]))))
      }
      "draw" => {
        let cam = build_camera(op[1])
        let o = op[2]
        b.sort_objects = bool(o.get("sort"))
        b.per_object_frustum_culled = bool(o.get("culled"))
        material.transparent = bool(o.get("transparent"))
        material.wireframe = Some(bool(o.get("wireframe")))
        b._visibility_changed = true
        mesh._update_draw_parameters(
          cam,
          test_geometry(mesh),
          material,
          draw_format=str(o.get("format")),
        )
        guard b._indirect_texture.unwrap().source.data
          is DataImage({ data: Some(indirect), .. }) else {
          abort("indirect")
        }
        out.push(
          list([
            jv(b._multi_draw_count),
            jv(b._merged_draw_count),
            jv(b._multi_draw_bytes_per_element),
            typed_to_array(b._multi_draw_starts),
            typed_to_array(b._multi_draw_counts),
            typed_to_array(b._merged_draw_starts),
            typed_to_array(b._merged_draw_counts),
            typed_to_array(b._merged_draw_instance_counts),
            typed_to_array(indirect),
          ]),
        )
      }
      "raycast" => {
        let r = op[1]
        let far = if has(r, "far") { num(r.get("far")) } else { js_infinity() }
        let rc = @core.Raycaster::new(
          origin=v3(r.get("o")),
          direction=v3(r.get("d")),
          near=num(r.get("near")),
          far~,
        )
        let hits = []
        mesh.raycast(rc, hits)
        js_sort_hits(jv(hits))
        out.push(list(hits.map(encode_hit)))
      }
      "bounds" => {
        mesh.compute_bounding_box()
        mesh.compute_bounding_sphere()
        let box_ = b.bounding_box.unwrap()
        let sphere = b.bounding_sphere.unwrap()
        out.push(
          list([
            arr3(box_.min),
            arr3(box_.max),
            arr3(sphere.center),
            jv(sphere.radius),
          ]),
        )
      }
      "clone" => out.push(batched_state(mesh.clone()))
      other => abort("unknown op " + other)
    }
  }
  obj([("out", list(out)), ("state", batched_state(mesh))])
}

///|
fn test_geometry(object : @core.Object3D) -> @core.BufferGeometry {
  object.get_geometry().unwrap()
}

///|
fn run(s : @core.JsValue) -> @core.JsValue {
  match str(s.get("kind")) {
    "raycast" => run_raycast(s)
    "sprite" => run_sprite(s)
    "skinning" => run_skinning(s)
    "skeleton" => run_skeleton(s)
    "box3" => run_box3(s)
    "triangle" => run_triangle(s)
    "frustum" => run_frustum(s)
    "frustumArray" => run_frustum_array(s)
    "batched" => run_batched(s)
    other => abort("unknown scenario " + other)
  }
}

///|
fn main {
  let scenarios = items(read_json(arg(2)))
  silence_console()
  write_results(arg(3), list(scenarios.map(run)))
}
