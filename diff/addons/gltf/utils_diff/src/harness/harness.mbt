// MoonBit side of the BufferGeometryUtils / SkeletonUtils differential harness.
// `run.mjs` builds each case descriptor once, hands it to `run_case` here and to the
// upstream runner, and compares the two summaries. Keep the builders and summaries in
// step with run.mjs (`buildAttr`, `buildGeometry`, `sumGeometry`, ...).

///|
using @core {type JsValue}

///|
extern "js" fn js_array() -> JsValue = "() => []"

///|
extern "js" fn js_push(a : JsValue, v : JsValue) -> Unit = "(a, v) => { a.push(v) }"

///|
extern "js" fn js_len(a : JsValue) -> Int = "(a) => a.length"

///|
extern "js" fn js_at(a : JsValue, i : Int) -> JsValue = "(a, i) => a[i]"

///|
extern "js" fn js_num(v : JsValue) -> Double = "(v) => v"

///|
extern "js" fn js_int(v : JsValue) -> Int = "(v) => v | 0"

///|
extern "js" fn js_str(v : JsValue) -> String = "(v) => String(v)"

///|
extern "js" fn js_truthy(v : JsValue) -> Bool = "(v) => !!v"

///|
extern "js" fn js_present(v : JsValue, k : String) -> Bool = "(v, k) => v != null && v[k] !== undefined && v[k] !== null"

///|
extern "js" fn js_keys(v : JsValue) -> JsValue = "(v) => Object.keys(v)"

///|
extern "js" fn js_clone_ta(v : JsValue) -> @core.TypedArray = "(a) => new a.constructor(a)"

///|
extern "js" fn js_replace(s : String, a : String, b : String) -> String = "(s, a, b) => s.replace(a, b)"

///|
extern "js" fn js_bool(b : Bool) -> JsValue = "(b) => !!b"

///|
fn get(v : JsValue, k : String) -> JsValue {
  v.get(k)
}

///|
fn num(v : JsValue, k : String) -> Double {
  js_num(v.get(k))
}

///|
fn int(v : JsValue, k : String) -> Int {
  js_int(v.get(k))
}

///|
fn str(v : JsValue, k : String) -> String {
  js_str(v.get(k))
}

///|
fn flag(v : JsValue, k : String) -> Bool {
  js_truthy(v.get(k))
}

///|
fn has(v : JsValue, k : String) -> Bool {
  js_present(v, k)
}

///|
fn each(a : JsValue, f : (JsValue) -> Unit) -> Unit {
  for i in 0..<js_len(a) {
    f(js_at(a, i))
  }
}

///|
fn nums(a : JsValue) -> Array[Double] {
  let out = []
  each(a, x => out.push(js_num(x)))
  out
}

///|
fn obj(pairs : Array[(String, JsValue)]) -> JsValue {
  let o = JsValue::object()
  for p in pairs {
    o.set(p.0, p.1)
  }
  o
}

///|
fn arr(items : Array[JsValue]) -> JsValue {
  let a = js_array()
  for x in items {
    js_push(a, x)
  }
  a
}

///|
fn jn(x : Double) -> JsValue {
  JsValue::of(x)
}

///|
fn ji(x : Int) -> JsValue {
  JsValue::of(x.to_double())
}

///|
fn js(x : String) -> JsValue {
  JsValue::of(x)
}

///|
fn jnums(xs : Array[Double]) -> JsValue {
  arr(xs.map(jn))
}

// ---------------------------------------------------------------- builders

///|
fn build_buffers(c : JsValue) -> Array[@core.InterleavedBuffer] {
  let out = []
  if has(c, "buffers") {
    each(get(c, "buffers"), d => {
      let array = js_clone_ta(get(d, "array"))
      let stride = int(d, "stride")
      let buffer = if flag(d, "instanced") {
        @core.InstancedInterleavedBuffer::new(
          array,
          stride,
          mesh_per_attribute=int(d, "mpa"),
        )
      } else {
        @core.InterleavedBuffer::new(array, stride)
      }
      if has(d, "usage") {
        ignore(buffer.set_usage(int(d, "usage")))
      }
      out.push(buffer)
    })
  }
  out
}

///|
fn build_attr(
  d : JsValue,
  bufs : Array[@core.InterleavedBuffer],
) -> @core.GeometryAttribute {
  if has(d, "il") {
    let a = @core.InterleavedBufferAttribute::new(
      bufs[int(d, "il")],
      int(d, "itemSize"),
      int(d, "offset"),
      normalized=flag(d, "normalized"),
    )
    if has(d, "name") {
      a.name = str(d, "name")
    }
    return Interleaved(a)
  }
  let array = js_clone_ta(get(d, "array"))
  let item_size = int(d, "itemSize")
  let normalized = flag(d, "normalized")
  let kind = if has(d, "kind") { str(d, "kind") } else { "plain" }
  let a = match kind {
    "f16" => @core.Float16BufferAttribute::new(array, item_size, normalized~)
    "inst" =>
      @core.InstancedBufferAttribute::new(
        array,
        item_size,
        normalized~,
        mesh_per_attribute=int(d, "mpa"),
      )
    _ => @core.BufferAttribute::new(array, item_size, normalized~)
  }
  if has(d, "name") {
    a.name = str(d, "name")
  }
  if has(d, "usage") {
    ignore(a.set_usage(int(d, "usage")))
  }
  if has(d, "gpuType") {
    a.gpu_type = int(d, "gpuType")
  }
  Buffer(a)
}

///|
fn arg(args : JsValue, i : Int, default : Double) -> Double {
  if i < js_len(args) {
    js_num(js_at(args, i))
  } else {
    default
  }
}

///|
fn build_builtin(b : JsValue) -> @core.BufferGeometry {
  let a = get(b, "args")
  match str(b, "type") {
    "BoxGeometry" =>
      @geometries.BoxGeometry::new(
        width=arg(a, 0, 1.0),
        height=arg(a, 1, 1.0),
        depth=arg(a, 2, 1.0),
        width_segments=arg(a, 3, 1.0),
        height_segments=arg(a, 4, 1.0),
        depth_segments=arg(a, 5, 1.0),
      )
    "SphereGeometry" =>
      @geometries.SphereGeometry::new(
        radius=arg(a, 0, 1.0),
        width_segments=arg(a, 1, 32.0),
        height_segments=arg(a, 2, 16.0),
      )
    "TorusKnotGeometry" =>
      @geometries.TorusKnotGeometry::new(
        radius=arg(a, 0, 1.0),
        tube=arg(a, 1, 0.4),
        tubular_segments=arg(a, 2, 64.0),
        radial_segments=arg(a, 3, 8.0),
        p=arg(a, 4, 2.0),
        q=arg(a, 5, 3.0),
      )
    "PlaneGeometry" =>
      @geometries.PlaneGeometry::new(
        width=arg(a, 0, 1.0),
        height=arg(a, 1, 1.0),
        width_segments=arg(a, 2, 1.0),
        height_segments=arg(a, 3, 1.0),
      )
    "TorusGeometry" =>
      @geometries.TorusGeometry::new(
        radius=arg(a, 0, 1.0),
        tube=arg(a, 1, 0.4),
        radial_segments=arg(a, 2, 12.0),
        tubular_segments=arg(a, 3, 48.0),
      )
    "CylinderGeometry" =>
      @geometries.CylinderGeometry::new(
        radius_top=arg(a, 0, 1.0),
        radius_bottom=arg(a, 1, 1.0),
        height=arg(a, 2, 1.0),
        radial_segments=arg(a, 3, 32.0),
        height_segments=arg(a, 4, 1.0),
      )
    "IcosahedronGeometry" =>
      @geometries.IcosahedronGeometry::new(
        radius=arg(a, 0, 1.0),
        detail=arg(a, 1, 0.0),
      )
    "CapsuleGeometry" =>
      @geometries.CapsuleGeometry::new(
        radius=arg(a, 0, 1.0),
        height=arg(a, 1, 1.0),
        cap_segments=arg(a, 2, 4.0),
        radial_segments=arg(a, 3, 8.0),
      )
    t => abort("harness: unknown builtin " + t)
  }
}

///|
fn build_geometry(
  d : JsValue,
  bufs : Array[@core.InterleavedBuffer],
) -> @core.BufferGeometry {
  let g = if has(d, "builtin") {
    build_builtin(get(d, "builtin"))
  } else {
    @core.BufferGeometry::new()
  }
  if has(d, "attrs") {
    each(get(d, "attrs"), pair => {
      ignore(
        g.set_attribute(str(pair, "0"), build_attr(js_at(pair, 1), bufs)),
      )
    })
  }
  if has(d, "index") {
    ignore(g.set_index(build_attr(get(d, "index"), bufs)))
  }
  if has(d, "noIndex") {
    g.index = None
  }
  if has(d, "morph") {
    each(get(d, "morph"), pair => {
      let list = []
      each(js_at(pair, 1), a => list.push(build_attr(a, bufs)))
      g.morph_attributes[str(pair, "0")] = list
    })
  }
  if has(d, "morphRelative") {
    g.morph_targets_relative = flag(d, "morphRelative")
  }
  if has(d, "groups") {
    g.clear_groups()
    each(get(d, "groups"), gr => {
      g.add_group(
        js_int(js_at(gr, 0)),
        js_num(js_at(gr, 1)),
        material_index=js_int(js_at(gr, 2)),
      )
    })
  }
  if has(d, "drawRange") {
    let dr = get(d, "drawRange")
    g.set_draw_range(js_int(js_at(dr, 0)), js_num(js_at(dr, 1)))
  }
  if has(d, "name") {
    g.name = str(d, "name")
  }
  g
}

///|
fn set_trs(o : @core.Object3D, d : JsValue) -> Unit {
  if has(d, "p") {
    let p = nums(get(d, "p"))
    ignore(o.position.set(p[0], p[1], p[2]))
  }
  if has(d, "q") {
    let q = nums(get(d, "q"))
    ignore(o.quaternion.set(q[0], q[1], q[2], q[3]))
  }
  if has(d, "s") {
    let s = nums(get(d, "s"))
    ignore(o.scale.set(s[0], s[1], s[2]))
  }
}

///|
fn set_influences(o : @core.Object3D, d : JsValue) -> Unit {
  if has(d, "influences") {
    let inf = nums(get(d, "influences"))
    match o.kind {
      Mesh(m) => m.morph_target_influences = Some(inf)
      Line(m) => m.morph_target_influences = Some(inf)
      Points(m) => m.morph_target_influences = Some(inf)
      _ => ()
    }
  }
}

///|
/// `{ root, bones, meshes }` built from a rig descriptor, as `buildRig` in run.mjs.
fn build_rig(
  d : JsValue,
  bufs : Array[@core.InterleavedBuffer],
) -> (@core.Object3D, Array[@core.Object3D], Array[@core.Object3D]) {
  let root = @core.Group::new()
  root.name = str(d, "rootName")
  set_trs(root, get(d, "root"))
  let bones : Array[@core.Object3D] = []
  each(get(d, "bones"), b => {
    let bone = @core.Bone::new()
    bone.name = str(b, "name")
    set_trs(bone, b)
    let parent = int(b, "parent")
    if parent < 0 {
      ignore(root.add(bone))
    } else {
      ignore(bones[parent].add(bone))
    }
    bones.push(bone)
  })
  let meshes = []
  each(get(d, "meshes"), m => {
    let mesh = @core.SkinnedMesh::new(
      geometry=build_geometry(get(m, "geom"), bufs),
      material=Single(@core.MeshBasicMaterial::new()),
    )
    mesh.name = str(m, "name")
    set_trs(mesh, m)
    if has(m, "parentBone") {
      ignore(bones[int(m, "parentBone")].add(mesh))
    } else {
      ignore(root.add(mesh))
    }
    meshes.push(mesh)
  })
  root.update_matrix_world(force=true)
  let mut k = 0
  each(get(d, "meshes"), m => {
    let skeleton_bones = []
    each(get(m, "bones"), i => skeleton_bones.push(bones[js_int(i)]))
    let mesh = meshes[k]
    if has(m, "bindMode") {
      if mesh.kind is Mesh({ kind: SkinnedMesh(s), .. }) {
        s.bind_mode = str(m, "bindMode")
      }
    }
    mesh.bind(@core.Skeleton::new(bones=skeleton_bones))
    set_influences(mesh, m)
    k += 1
  })
  if has(d, "pose") {
    each(get(d, "pose"), p => {
      let bone = bones[int(p, "i")]
      set_trs(bone, p)
    })
  }
  root.update_matrix_world(force=true)
  (root, bones, meshes)
}

///|
fn build_object(
  d : JsValue,
  bufs : Array[@core.InterleavedBuffer],
) -> @core.Object3D {
  let cls = str(d, "cls")
  if cls == "SkinnedMesh" {
    let (_, _, meshes) = build_rig(get(d, "rig"), bufs)
    return meshes[0]
  }
  let geometry = build_geometry(get(d, "geom"), bufs)
  let multi = flag(d, "multi")
  let o = match cls {
    "Mesh" => {
      let m = @core.MeshBasicMaterial::new()
      @core.Mesh::new(
        geometry~,
        material=if multi { Multiple([m, @core.MeshBasicMaterial::new()]) } else {
          Single(m)
        },
      )
    }
    "Line" => {
      let m = @core.LineBasicMaterial::new()
      @core.Line::new(
        geometry~,
        material=if multi { Multiple([m, @core.LineBasicMaterial::new()]) } else {
          Single(m)
        },
      )
    }
    "Points" => {
      let m = @core.PointsMaterial::new()
      @core.Points::new(
        geometry~,
        material=if multi { Multiple([m, @core.PointsMaterial::new()]) } else {
          Single(m)
        },
      )
    }
    _ => abort("harness: unknown class " + cls)
  }
  set_influences(o, d)
  o
}

// ---------------------------------------------------------------- summaries

///|
priv struct Ctx {
  buffers : Array[@core.InterleavedBuffer]
  out : JsValue
}

///|
fn Ctx::new() -> Ctx {
  { buffers: [], out: js_array() }
}

///|
fn sum_buffer_id(ctx : Ctx, b : @core.InterleavedBuffer) -> Int {
  for i, x in ctx.buffers {
    if physical_equal(x, b) {
      return i
    }
  }
  ctx.buffers.push(b)
  js_push(
    ctx.out,
    obj([
      ("type", js(b.array.type_name())),
      ("stride", ji(b.stride)),
      ("count", ji(b.count)),
      ("usage", ji(b.usage)),
      ("instanced", js_bool(b.is_instanced_interleaved_buffer)),
      ("mpa", ji(b.mesh_per_attribute)),
      ("array", JsValue::of(b.array)),
    ]),
  )
  ctx.buffers.length() - 1
}

///|
fn sum_attr(ctx : Ctx, a : @core.GeometryAttribute) -> JsValue {
  match a {
    Buffer(b) => {
      let kind = match b.kind {
        PlainAttribute => "plain"
        Float16Attribute => "f16"
        InstancedAttribute => "inst"
        StorageAttribute => "storage"
        StorageInstancedAttribute => "storageInst"
      }
      let o = obj([
        ("k", js("buf")),
        ("kind", js(kind)),
        ("type", js(b.array.type_name())),
        ("itemSize", ji(b.item_size)),
        ("normalized", js_bool(b.normalized)),
        ("count", ji(b.count)),
        ("name", js(b.name)),
        ("usage", ji(b.usage)),
        ("gpuType", ji(b.gpu_type)),
        ("array", JsValue::of(b.array)),
      ])
      if b.is_instanced_buffer_attribute() {
        o.set("mpa", ji(b.mesh_per_attribute))
      }
      o
    }
    Interleaved(b) =>
      obj([
        ("k", js("il")),
        ("itemSize", ji(b.item_size)),
        ("offset", ji(b.offset)),
        ("normalized", js_bool(b.normalized)),
        ("name", js(b.name)),
        ("count", ji(b.count())),
        ("buf", ji(sum_buffer_id(ctx, b.data))),
      ])
    GL(_) => js("GL")
  }
}

///|
fn sum_geometry_ctx(ctx : Ctx, g : @core.BufferGeometry) -> JsValue {
  let attrs = []
  for name, a in g.attributes {
    attrs.push(arr([js(name), sum_attr(ctx, a)]))
  }
  let morph = []
  for name, list in g.morph_attributes {
    morph.push(arr([js(name), arr(list.map(a => sum_attr(ctx, a)))]))
  }
  let groups = g.groups.map(gr => {
    arr([ji(gr.start), jn(gr.count), ji(gr.material_index)])
  })
  obj([
    ("type", js(g.type_)),
    ("name", js(g.name)),
    ("attrs", arr(attrs)),
    (
      "index",
      match g.index {
        Some(i) => sum_attr(ctx, i)
        None => JsValue::null()
      },
    ),
    ("morph", arr(morph)),
    ("morphRelative", js_bool(g.morph_targets_relative)),
    ("groups", arr(groups)),
    ("drawRange", arr([ji(g.draw_range.start), jn(g.draw_range.count)])),
  ])
}

///|
fn sum_geometry(g : @core.BufferGeometry) -> JsValue {
  let ctx = Ctx::new()
  let s = sum_geometry_ctx(ctx, g)
  s.set("buffers", ctx.out)
  s
}

///|
fn sum_attr_alone(a : @core.GeometryAttribute) -> JsValue {
  let ctx = Ctx::new()
  obj([("attr", sum_attr(ctx, a)), ("buffers", ctx.out)])
}

///|
fn jm4(m : @math.Matrix4) -> JsValue {
  jnums(m.elements)
}

///|
fn sum_node_list(root : @core.Object3D) -> Array[@core.Object3D] {
  let nodes = []
  root.traverse(n => nodes.push(n))
  nodes
}

///|
fn index_in(nodes : Array[@core.Object3D], o : @core.Object3D) -> Int {
  for i, n in nodes {
    if physical_equal(n, o) {
      return i
    }
  }
  -1
}

///|
fn sum_scene(
  root : @core.Object3D,
  source_nodes : Array[@core.Object3D],
) -> JsValue {
  let nodes = sum_node_list(root)
  arr(
    nodes.map(n => {
      let o = obj([
        ("name", js(n.name)),
        ("type", js(n.type_)),
        (
          "parent",
          ji(
            match n.parent {
              Some(p) => index_in(nodes, p)
              None => -1
            },
          ),
        ),
        (
          "p",
          jnums([n.position.x, n.position.y, n.position.z]),
        ),
        (
          "q",
          jnums([n.quaternion.x, n.quaternion.y, n.quaternion.z, n.quaternion.w]),
        ),
        ("s", jnums([n.scale.x, n.scale.y, n.scale.z])),
        ("matrix", jm4(n.matrix)),
        ("matrixWorld", jm4(n.matrix_world)),
        ("inSource", js_bool(index_in(source_nodes, n) >= 0)),
      ])
      match n.kind {
        Mesh({ kind: SkinnedMesh(s), geometry, .. }) => {
          let src = source_nodes[index_in(nodes, n)]
          let src_skinned = match src.kind {
            Mesh({ kind: SkinnedMesh(ss), geometry: sg, .. }) => Some((ss, sg))
            _ => None
          }
          match s.skeleton {
            Some(sk) => {
              o.set("bones", arr(sk.bones.map(b => ji(index_in(nodes, b)))))
              o.set(
                "sourceBones",
                arr(sk.bones.map(b => ji(index_in(source_nodes, b)))),
              )
              o.set("boneInverses", arr(sk.bone_inverses.map(jm4)))
              o.set(
                "skeletonShared",
                js_bool(
                  match src_skinned {
                    Some((ss, _)) =>
                      match ss.skeleton {
                        Some(ssk) => physical_equal(ssk, sk)
                        None => false
                      }
                    None => false
                  },
                ),
              )
              o.set(
                "inversesShared",
                js_bool(
                  match src_skinned {
                    Some((ss, _)) =>
                      match ss.skeleton {
                        Some(ssk) =>
                          physical_equal(ssk.bone_inverses, sk.bone_inverses)
                        None => false
                      }
                    None => false
                  },
                ),
              )
            }
            None => ()
          }
          o.set(
            "geometryShared",
            js_bool(
              match src_skinned {
                Some((_, sg)) => physical_equal(sg, geometry)
                None => false
              },
            ),
          )
          o.set("bindMatrix", jm4(s.bind_matrix))
          o.set("bindMatrixInverse", jm4(s.bind_matrix_inverse))
          o.set("bindMode", js(s.bind_mode))
        }
        _ => ()
      }
      o
    }),
  )
}

///|
fn sum_bones(bones : Array[@core.Object3D]) -> JsValue {
  arr(
    bones.map(n => {
      obj([
        ("name", js(n.name)),
        ("p", jnums([n.position.x, n.position.y, n.position.z])),
        (
          "q",
          jnums([n.quaternion.x, n.quaternion.y, n.quaternion.z, n.quaternion.w]),
        ),
        ("s", jnums([n.scale.x, n.scale.y, n.scale.z])),
        ("matrix", jm4(n.matrix)),
        ("matrixWorld", jm4(n.matrix_world)),
      ])
    }),
  )
}

///|
fn build_options(d : JsValue) -> @utils.RetargetOptions {
  let o = @utils.RetargetOptions::new()
  if has(d, "names") {
    let names = get(d, "names")
    each(js_keys(names), k => o.names[js_str(k)] = str(names, js_str(k)))
  }
  if has(d, "getBoneName") {
    let r = get(d, "getBoneName")
    let from = str(r, "0")
    let to = str(r, "1")
    o.get_bone_name = Some(bone => Some(js_replace(bone.name, from, to)))
  }
  if has(d, "hip") {
    o.hip = str(d, "hip")
  }
  if has(d, "scale") {
    o.scale = num(d, "scale")
  }
  if has(d, "hipInfluence") {
    let v = nums(get(d, "hipInfluence"))
    o.hip_influence = @math.Vector3::new(v[0], v[1], v[2])
  }
  if has(d, "hipPosition") {
    let v = nums(get(d, "hipPosition"))
    o.hip_position = Some(@math.Vector3::new(v[0], v[1], v[2]))
  }
  if has(d, "preserveBoneMatrix") {
    o.preserve_bone_matrix = flag(d, "preserveBoneMatrix")
  }
  if has(d, "preserveBonePositions") {
    o.preserve_bone_positions = flag(d, "preserveBonePositions")
  }
  if has(d, "useTargetMatrix") {
    o.use_target_matrix = flag(d, "useTargetMatrix")
  }
  if has(d, "useFirstFramePosition") {
    o.use_first_frame_position = flag(d, "useFirstFramePosition")
  }
  if has(d, "fps") {
    o.fps = Some(num(d, "fps"))
  }
  if has(d, "trim") {
    let t = nums(get(d, "trim"))
    o.trim = Some((t[0], t[1]))
  }
  if has(d, "localOffsets") {
    let lo = get(d, "localOffsets")
    let m : Map[String, @math.Matrix4] = Map([])
    each(js_keys(lo), k => {
      let e = nums(get(lo, js_str(k)))
      let mat = @math.Matrix4::new()
      mat.elements = e
      m[js_str(k)] = mat
    })
    o.local_offsets = Some(m)
  }
  o
}

///|
fn sum_options(o : @utils.RetargetOptions) -> JsValue {
  obj([
    ("useTargetMatrix", js_bool(o.use_target_matrix)),
    ("preserveBoneMatrix", js_bool(o.preserve_bone_matrix)),
    (
      "fps",
      match o.fps {
        Some(f) => jn(f)
        None => JsValue::undefined()
      },
    ),
  ])
}

///|
fn skeleton_of(o : @core.Object3D) -> @core.Skeleton {
  guard o.kind is Mesh({ kind: SkinnedMesh({ skeleton: Some(s), .. }), .. }) else {
    abort("harness: not a bound SkinnedMesh")
  }
  s
}

///|
fn build_clip(d : JsValue) -> @animation.AnimationClip {
  let tracks = []
  each(get(d, "tracks"), t => {
    let name = str(t, "name")
    let times = nums(get(t, "times"))
    let values = nums(get(t, "values"))
    tracks.push(
      match str(t, "type") {
        "quaternion" =>
          @animation.QuaternionKeyframeTrack::new(name, times, values)
        "vector" => @animation.VectorKeyframeTrack::new(name, times, values)
        _ => @animation.NumberKeyframeTrack::new(name, times, values)
      },
    )
  })
  @animation.AnimationClip::new(
    name=str(d, "name"),
    duration=num(d, "duration"),
    tracks~,
  )
}

///|
fn sum_clip(clip : @animation.AnimationClip) -> JsValue {
  obj([
    ("name", js(clip.name)),
    ("duration", jn(clip.duration)),
    (
      "tracks",
      arr(
        clip.tracks.map(t => {
          obj([
            ("name", js(t.name)),
            ("type", js(t.value_type_name)),
            ("times", JsValue::of(t.times)),
            (
              "values",
              match t.values {
                Numbers(v) => JsValue::of(v)
                _ => js("non-numeric")
              },
            ),
          ])
        }),
      ),
    ),
  ])
}

// ---------------------------------------------------------------- cases

///|
fn opt_geometry(g : @core.BufferGeometry?) -> JsValue {
  match g {
    Some(g) => sum_geometry(g)
    None => JsValue::null()
  }
}

///|
fn ref_of(
  c : JsValue,
  key : String,
  mesh : @core.Object3D,
) -> @utils.SkeletonRef {
  if has(c, key) && str(c, key) == "skeleton" {
    Skeleton(skeleton_of(mesh))
  } else {
    Object(mesh)
  }
}

///|
pub fn run_case(c : JsValue) -> JsValue {
  let bufs = build_buffers(c)
  match str(c, "op") {
    "mergeGeometries" => {
      let geoms = []
      each(get(c, "geoms"), d => geoms.push(build_geometry(d, bufs)))
      opt_geometry(
        @utils.BufferGeometryUtils::merge_geometries(
          geoms,
          use_groups=flag(c, "useGroups"),
        ),
      )
    }
    "mergeAttributes" => {
      let attrs = []
      each(get(c, "attrs"), d => attrs.push(build_attr(d, bufs)))
      match @utils.BufferGeometryUtils::merge_attributes(attrs) {
        Some(a) => sum_attr_alone(Buffer(a))
        None => JsValue::null()
      }
    }
    "interleaveAttributes" => {
      let attrs = []
      each(get(c, "attrs"), d => attrs.push(build_attr(d, bufs)))
      match @utils.BufferGeometryUtils::interleave_attributes(attrs) {
        Some(list) => {
          let ctx = Ctx::new()
          let items = list.map(a => sum_attr(ctx, Interleaved(a)))
          obj([("attrs", arr(items)), ("buffers", ctx.out)])
        }
        None => JsValue::null()
      }
    }
    "deinterleaveAttribute" => {
      guard build_attr(get(c, "attr"), bufs) is Interleaved(a) else {
        abort("harness: not interleaved")
      }
      sum_attr_alone(Buffer(@utils.BufferGeometryUtils::deinterleave_attribute(a)))
    }
    "deinterleaveGeometry" => {
      let g = build_geometry(get(c, "geom"), bufs)
      @utils.BufferGeometryUtils::deinterleave_geometry(g)
      sum_geometry(g)
    }
    "deepCloneAttribute" => {
      let a = build_attr(get(c, "attr"), bufs)
      let r = @utils.BufferGeometryUtils::deep_clone_attribute(a)
      let s = sum_attr_alone(Buffer(r))
      s.set(
        "sameArray",
        js_bool(physical_equal(r.array, a.array())),
      )
      s
    }
    "estimateBytesUsed" => {
      let g = build_geometry(get(c, "geom"), bufs)
      ji(@utils.BufferGeometryUtils::estimate_bytes_used(g))
    }
    "mergeVertices" => {
      let g = build_geometry(get(c, "geom"), bufs)
      let r = if has(c, "tolerance") {
        @utils.BufferGeometryUtils::merge_vertices(
          g,
          tolerance=num(c, "tolerance"),
        )
      } else {
        @utils.BufferGeometryUtils::merge_vertices(g)
      }
      let s = sum_geometry(r)
      s.set("input", sum_geometry(g))
      s
    }
    "toTrianglesDrawMode" => {
      let g = build_geometry(get(c, "geom"), bufs)
      let r = @utils.BufferGeometryUtils::to_triangles_draw_mode(
        g,
        int(c, "drawMode"),
      )
      let s = sum_geometry(r)
      s.set("same", js_bool(physical_equal(r, g)))
      s
    }
    "computeMorphedAttributes" => {
      let o = build_object(get(c, "object"), bufs)
      let r = @utils.BufferGeometryUtils::compute_morphed_attributes(o)
      let g = o.get_geometry().unwrap()
      obj([
        ("position", sum_attr_alone(r.position_attribute)),
        ("normal", sum_attr_alone(r.normal_attribute)),
        ("morphedPosition", sum_attr_alone(Buffer(r.morphed_position_attribute))),
        ("morphedNormal", sum_attr_alone(Buffer(r.morphed_normal_attribute))),
        (
          "samePosition",
          js_bool(
            match (r.position_attribute, g.attributes["position"]) {
              (Buffer(a), Buffer(b)) => physical_equal(a, b)
              (Interleaved(a), Interleaved(b)) => physical_equal(a, b)
              _ => false
            },
          ),
        ),
      ])
    }
    "computeMikkTSpaceTangents" => {
      let g = build_geometry(get(c, "geom"), bufs)
      let r = if has(c, "negateSign") {
        @utils.BufferGeometryUtils::compute_mikktspace_tangents(
          g,
          get(c, "mikk"),
          negate_sign=flag(c, "negateSign"),
        )
      } else {
        @utils.BufferGeometryUtils::compute_mikktspace_tangents(g, get(c, "mikk"))
      }
      let s = sum_geometry(r)
      s.set("same", js_bool(physical_equal(r, g)))
      s
    }
    "toCreasedNormals" => {
      let g = build_geometry(get(c, "geom"), bufs)
      let r = if has(c, "creaseAngle") {
        @utils.BufferGeometryUtils::to_creased_normals(
          g,
          crease_angle=num(c, "creaseAngle"),
        )
      } else {
        @utils.BufferGeometryUtils::to_creased_normals(g)
      }
      let s = sum_geometry(r)
      s.set("same", js_bool(physical_equal(r, g)))
      s
    }
    "mergeGroups" => {
      let g = build_geometry(get(c, "geom"), bufs)
      sum_geometry(@utils.BufferGeometryUtils::merge_groups(g))
    }
    "remapAttribute" => {
      let shared = flag(c, "shared")
      let buffers = @utils.RemapBuffers::new()
      let indices = nums(get(c, "sourceIndices")).map(x => x.to_int())
      let ctx = Ctx::new()
      let items = []
      each(get(c, "attrs"), d => {
        let a = build_attr(d, bufs)
        let r = if shared {
          @utils.BufferGeometryUtils::remap_attribute(a, indices, buffers~)
        } else {
          @utils.BufferGeometryUtils::remap_attribute(a, indices)
        }
        items.push(sum_attr(ctx, r))
      })
      obj([("attrs", arr(items)), ("buffers", ctx.out)])
    }
    "clone" => {
      let (root, _, meshes) = build_rig(get(c, "rig"), bufs)
      let start = if flag(c, "fromMesh") { meshes[0] } else { root }
      let source_nodes = sum_node_list(start)
      let clone = @utils.SkeletonUtils::clone(start)
      obj([
        ("clone", sum_scene(clone, source_nodes)),
        ("source", sum_scene(start, source_nodes)),
      ])
    }
    "retarget" => {
      let (_, tbones, tmeshes) = build_rig(get(c, "target"), bufs)
      let (_, _, smeshes) = build_rig(get(c, "source"), bufs)
      let options = build_options(get(c, "options"))
      let target = ref_of(c, "targetAs", tmeshes[0])
      let source = ref_of(c, "sourceAs", smeshes[0])
      if flag(c, "defaultOptions") {
        @utils.SkeletonUtils::retarget(target, source)
      } else {
        @utils.SkeletonUtils::retarget(target, source, options~)
      }
      obj([
        ("bones", sum_bones(tbones)),
        ("mesh", jm4(tmeshes[0].matrix_world)),
        ("options", sum_options(options)),
      ])
    }
    "retargetClip" => {
      let (_, tbones, tmeshes) = build_rig(get(c, "target"), bufs)
      let (_, _, smeshes) = build_rig(get(c, "source"), bufs)
      let options = build_options(get(c, "options"))
      let clip = build_clip(get(c, "clip"))
      let source = ref_of(c, "sourceAs", smeshes[0])
      let result = @utils.SkeletonUtils::retarget_clip(
        tmeshes[0],
        source,
        clip,
        options~,
      )
      obj([
        ("clip", sum_clip(result)),
        ("bones", sum_bones(tbones)),
        ("options", sum_options(options)),
      ])
    }
    op => abort("harness: unknown op " + op)
  }
}
