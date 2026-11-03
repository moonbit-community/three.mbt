// Differential scenarios for SceneUtils, GeometryUtils, SortUtils and ColorUtils: with
// A6_DIFF=1 each prints `@@A6U <name> <json>`, compared with upstream by the
// diff/addons/utils_env harness (`node --import ./register.mjs run.mjs`),
// whose upstream_utils.mjs runs the same steps on examples/jsm/utils.

///|
/// The harness helpers of common.js (diff/addons/utils_env), embedded verbatim.
extern "js" fn a6_common() -> @core.JsValue =
  #|() =>
  #|// Shared by both sides (embedded verbatim in the MoonBit tests as an extern).
  #|(function () {
  #|  function rng( seed ) {
  #|    let a = seed >>> 0;
  #|    return function () {
  #|      a |= 0; a = a + 0x6D2B79F5 | 0;
  #|      let t = Math.imul( a ^ a >>> 15, 1 | a );
  #|      t = t + Math.imul( t ^ t >>> 7, 61 | t ) ^ t;
  #|      return ( ( t ^ t >>> 14 ) >>> 0 ) / 4294967296;
  #|    };
  #|  }
  #|  // n values: floor( r * scale ) + offset, or r * scale + offset when float
  #|  function data( seed, n, scale, offset, float ) {
  #|    const r = rng( seed ); const out = [];
  #|    for ( let i = 0; i < n; i ++ ) out.push( float ? r() * scale + offset : Math.floor( r() * scale ) + offset );
  #|    return out;
  #|  }
  #|  // canonical JSON: uuids replaced by their order of first appearance
  #|  function canon( json ) {
  #|    const ids = new Map();
  #|    const s = JSON.stringify( json );
  #|    return s.replace( /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/gi, ( u ) => { if ( ! ids.has( u ) ) ids.set( u, 'uuid' + ids.size ); return ids.get( u ); } );
  #|  }
  #|  return { rng, data, canon };
  #|})()

///|
let a6u_common : @core.JsValue = a6_common()

///|
extern "js" fn a6u_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.A6_DIFF === '1'"

///|
extern "js" fn a6u_canon(c : @core.JsValue, value : @core.JsValue) -> String = "(c, v) => c.canon(v)"

///|
extern "js" fn a6u_data_raw(
  c : @core.JsValue,
  seed : Int32,
  n : Int32,
  scale : Double,
  offset : Double,
  float : Bool,
) -> Array[Double] = "(c, s, n, k, o, f) => c.data(s, n, k, o, f)"

///|
extern "js" fn a6u_rng_raw(c : @core.JsValue, seed : Int32) -> () -> Double = "(c, s) => c.rng(s)"

///|
fn a6u_data(
  seed : Int32,
  n : Int32,
  scale : Double,
  offset : Double,
  float : Bool,
) -> Array[Double] {
  a6u_data_raw(a6u_common, seed, n, scale, offset, float)
}

///|
fn a6u_emit(name : String, value : @core.JsValue) -> Unit {
  let s = a6u_canon(a6u_common, value)
  if a6u_enabled() {
    println("@@A6U \{name} \{s}")
  }
}

///|
fn[T] a6u_js(value : T) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn a6u_xyz(vs : Array[@math.Vector3]) -> Array[Double] {
  let out = []
  for v in vs {
    out.push(v.x)
    out.push(v.y)
    out.push(v.z)
  }
  out
}

///|
fn a6u_array(a : @core.TypedArray) -> Array[Double] {
  a.to_array()
}

///|
test "a6 utils: ColorUtils and GeometryUtils" {
  let r = []
  let mut k = 0.0
  while k <= 45000.0 {
    let c = @utils.set_kelvin(@math.Color::new(1.0, 1.0, 1.0), k)
    r.push([c.r, c.g, c.b])
    k += 250.0
  }
  a6u_emit("kelvin", a6u_js(r))
  let c123 = @math.Vector3::new(1.0, 2.0, 3.0)
  a6u_emit(
    "hilbert2d",
    a6u_js([
      a6u_xyz(@utils.hilbert2d()),
      a6u_xyz(@utils.hilbert2d(center=c123, size=7.0, iterations=3)),
      a6u_xyz(
        @utils.hilbert2d(
          center=c123,
          size=5.0,
          iterations=2,
          v0=1,
          v1=2,
          v2=3,
          v3=0,
        ),
      ),
      a6u_xyz(@utils.hilbert2d(size=10.0, iterations=0)),
    ]),
  )
  a6u_emit(
    "hilbert3d",
    a6u_js([
      a6u_xyz(@utils.hilbert3d()),
      a6u_xyz(
        @utils.hilbert3d(
          center=@math.Vector3::new(-1.0, 0.5, 2.0),
          size=3.0,
          iterations=2,
        ),
      ),
      a6u_xyz(
        @utils.hilbert3d(
          center=@math.Vector3::new(0.0, 0.0, 0.0),
          size=4.0,
          iterations=1,
          v0=7,
          v1=6,
          v2=5,
          v3=4,
          v4=3,
          v5=2,
          v6=1,
          v7=0,
        ),
      ),
      a6u_xyz(@utils.hilbert3d(size=10.0, iterations=3)),
    ]),
  )
  assert_eq(@utils.hilbert3d(iterations=1).length(), 64)
  assert_eq(@utils.hilbert2d(iterations=2).length(), 64)
  a6u_emit("gosper", a6u_js([@utils.gosper(), @utils.gosper(size=2.5)]))
}

///|
test "a6 utils: SortUtils" {
  let r = []
  for n in [0, 1, 2, 5, 32, 33, 64, 100, 257, 1000, 5000] {
    for reversed in [false, true] {
      for scale in [4294967296.0, 4.0, 70000.0] {
        let a = a6u_data(n + 7, n, scale, 0.0, false)
        @utils.radix_sort_numbers(a, reversed~)
        for i in 1..<a.length() {
          assert_true(
            if reversed {
              a[i - 1] >= a[i]
            } else {
              a[i - 1] <= a[i]
            },
          )
        }
        r.push(a)
      }
    }
  }
  a6u_emit("radix_numbers", a6u_js(r))
  let r = []
  for n in [3, 40, 600] {
    for reversed in [false, true] {
      let z = a6u_data(n, n, 2000.0, -1000.0, true)
      let a = z.mapi(fn(id, z) { (id, z) })
      @utils.radix_sort(a, get=fn(el) { el.1 }, reversed~)
      r.push(a.map(fn(e) { e.0 }))
    }
  }
  a6u_emit("radix_get", a6u_js(r))
  let r = []
  for n in [10, 50, 700] {
    for reversed in [false, true] {
      let u = @core.TypedArray::uint32(
        a6u_data(n + 1, n, 4294967296.0, 0.0, false),
      )
      let ua = @core.TypedArray::uint32(n)
      @utils.radix_sort_typed(u, aux=ua, reversed~)
      let f = @core.TypedArray::float32(a6u_data(n + 2, n, 1.0e6, 0.0, true))
      @utils.radix_sort_typed(f, reversed~)
      let b = @core.TypedArray::uint8(a6u_data(n + 3, n, 256.0, 0.0, false))
      let ba = @core.TypedArray::uint8(n)
      @utils.radix_sort_typed(b, aux=ba, reversed~, get=fn(v) { v * 16777216.0 })
      let p = a6u_data(n + 4, n, 1.0e9, -5.0e8, false)
      let pa = Array::make(n, 0.0)
      @utils.radix_sort_numbers(p, aux=pa, reversed~)
      r.push([
        a6u_js(a6u_array(u)),
        a6u_js(a6u_array(ua)),
        a6u_js(a6u_array(f)),
        a6u_js(a6u_array(b)),
        a6u_js(a6u_array(ba)),
        a6u_js(p),
        a6u_js(pa),
      ])
    }
  }
  a6u_emit("radix_typed", a6u_js(r))
}

///|
fn a6u_instanced(count : Int32, seed : Int32) -> @core.Object3D {
  let r = a6u_rng_raw(a6u_common, seed)
  let im = @core.InstancedMesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=2.0, depth=3.0),
    material=Single(@core.MeshBasicMaterial::new()),
    count,
  )
  let m = @math.Matrix4::new()
  let p = @math.Vector3::new(0.0, 0.0, 0.0)
  let q = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
  let s = @math.Vector3::new(0.0, 0.0, 0.0)
  let e = @math.Euler::new(0.0, 0.0, 0.0)
  for i in 0..<count {
    let px = r() * 10.0 - 5.0
    let py = r() * 10.0 - 5.0
    let pz = r() * 10.0 - 5.0
    p.set(px, py, pz) |> ignore
    let ex = r() * 3.0
    let ey = r() * 3.0
    let ez = r() * 3.0
    q.set_from_euler(e.set(ex, ey, ez)) |> ignore
    let sx = r() + 0.5
    let sy = r() + 0.5
    let sz = r() + 0.5
    s.set(sx, sy, sz) |> ignore
    im.set_matrix_at(i, m.compose(p, q, s)) |> ignore
  }
  im
}

///|
fn a6u_geometry(o : @core.Object3D) -> @core.BufferGeometry {
  o.get_geometry().unwrap()
}

///|
fn a6u_material(o : @core.Object3D) -> @core.Material {
  match o.get_material() {
    Some(Single(m)) => m
    _ => abort("no single material")
  }
}

///|
test "a6 utils: SceneUtils" {
  // createMeshesFromInstancedMesh
  let im = a6u_instanced(4, 11)
  im.name = "inst"
  im.position.set(1.0, 2.0, 3.0) |> ignore
  im.rotation.set(0.1, 0.2, 0.3) |> ignore
  im.update_matrix()
  let child = @core.Object3D::new()
  child.name = "child"
  im.add(child) |> ignore
  let group = @utils.create_meshes_from_instanced_mesh(im)
  a6u_emit(
    "scene_instanced",
    a6u_js([
      @core.JsValue::from_json(group.to_json()),
      a6u_js(
        group.children.map(fn(c) {
          a6u_js([
            a6u_js(c.type_),
            a6u_js(c.name),
            a6u_js(c.matrix_world.elements),
            a6u_js(a6u_xyz([c.position, c.scale])),
            a6u_js(c.quaternion.to_array()),
            a6u_js(
              c.get_geometry() is Some(g) && physical_equal(g, a6u_geometry(im)),
            ),
            a6u_js(
              c.get_material() is Some(Single(m)) &&
              physical_equal(m, a6u_material(im)),
            ),
          ])
        }),
      ),
    ]),
  )
  // createMultiMaterialObject
  let g = @geometries.PlaneGeometry::new(width=1.0, height=1.0)
  let red = @core.MeshBasicMaterial::new()
  red.color.unwrap().set_hex(0xff0000) |> ignore
  let group = @utils.create_multi_material_object(g, [
    red,
    @core.MeshNormalMaterial::new(),
  ])
  a6u_emit(
    "scene_multi_object",
    a6u_js([
      @core.JsValue::from_json(group.to_json()),
      a6u_js(group.children.map(fn(c) { physical_equal(a6u_geometry(c), g) })),
    ]),
  )
  // createMeshesFromMultiMaterialMesh
  let g = @geometries.BoxGeometry::new(
    width=1.0,
    height=1.0,
    depth=1.0,
    width_segments=2.0,
  )
  for i, group in g.groups {
    group.material_index = i * 5 % 3
  }
  let materials = [
    @core.MeshBasicMaterial::new(),
    @core.MeshLambertMaterial::new(),
    @core.MeshPhongMaterial::new(),
  ]
  let mesh = @core.Mesh::new(geometry=g, material=Multiple(materials))
  mesh.name = "multi"
  mesh.position.set(0.5, 0.0, 0.0) |> ignore
  let object = @utils.create_meshes_from_multi_material_mesh(mesh)
  let single = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  a6u_emit(
    "scene_multi_mesh",
    a6u_js([
      a6u_js(object.type_),
      a6u_js(object.name),
      a6u_js(object.position.to_array()),
      a6u_js(
        g.groups.map(fn(x) {
          [x.start.to_double(), x.count, x.material_index.to_double()]
        }),
      ),
      a6u_js(a6u_array(g.index.unwrap().array())),
      a6u_js(
        object.children.map(fn(c) {
          let geometry = a6u_geometry(c)
          let m = a6u_material(c)
          a6u_js([
            a6u_js(
              materials.search_by(fn(x) { physical_equal(x, m) }).unwrap_or(-1),
            ),
            a6u_js(geometry.attributes.keys().collect()),
            a6u_js(
              geometry.attributes
              .values()
              .map(fn(a) {
                a6u_js([
                  a6u_js(a.array().type_name()),
                  a6u_js(a.item_size()),
                  a6u_js(a.normalized()),
                  a6u_js(a6u_array(a.array())),
                ])
              })
              .collect(),
            ),
          ])
        }),
      ),
      a6u_js(
        physical_equal(
          @utils.create_meshes_from_multi_material_mesh(single),
          single,
        ),
      ),
    ]),
  )
  // reduceVertices
  let scene = @core.Scene::new()
  let box = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(width=1.0, height=2.0, depth=3.0),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  box.position.set(1.0, 2.0, 3.0) |> ignore
  box.rotation.set(0.3, 0.2, 0.1) |> ignore
  scene.add(box) |> ignore
  let morph = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=2.0, height=2.0),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  a6u_geometry(morph).morph_attributes["position"] = [
    Buffer(
      @core.Float32BufferAttribute::new(a6u_data(5, 12, 1.0, 0.0, true), 3),
    ),
  ]
  morph.update_morph_targets()
  morph.morph_targets().1.unwrap()[0] = 0.5
  morph.scale.set(2.0, 1.0, 1.0) |> ignore
  box.add(morph) |> ignore
  let line = @core.Line::new(
    geometry=@core.BufferGeometry::new().set_from_points([
      @math.Vector3::new(0.0, 0.0, 0.0),
      @math.Vector3::new(5.0, -6.0, 7.0),
    ]),
  )
  line.position.x = -4.0
  scene.add(line) |> ignore
  let points = @core.Points::new(
    geometry=@core.BufferGeometry::new().set_from_points([
      @math.Vector3::new(9.0, 9.0, 9.0),
    ]),
  )
  scene.add(points) |> ignore
  let hidden = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(
      width=100.0,
      height=100.0,
      depth=100.0,
    ),
  )
  hidden.visible = false
  scene.add(hidden) |> ignore
  let sprite = @core.Sprite::new()
  sprite.position.set(0.0, -10.0, 0.0) |> ignore
  scene.add(sprite) |> ignore
  let value = @utils.reduce_vertices(
    scene,
    fn(acc : Array[Double], v) {
      [
        acc[0] + v.x,
        acc[1] + v.y,
        acc[2] + v.z,
        acc[3] + 1.0,
        @webgl.js_math_max(acc[4], v.x),
      ]
    },
    [0.0, 0.0, 0.0, 0.0, -1.0 / 0.0],
  )
  let bbox = @utils.reduce_vertices(
    box,
    fn(b : @math.Box3, v) { b.expand_by_point(v) },
    @math.Box3::new(),
  )
  a6u_emit(
    "scene_reduce",
    a6u_js([
      a6u_js(value),
      a6u_js(bbox.min.to_array()),
      a6u_js(bbox.max.to_array()),
    ]),
  )
  // sortInstancedMesh
  let im = a6u_instanced(7, 12)
  let r = a6u_rng_raw(a6u_common, 13)
  for i in 0..<7 {
    let cr = r()
    let cg = r()
    let cb = r()
    im.set_color_at(i, @math.Color::new(cr, cg, cb)) |> ignore
  }
  let ig = a6u_geometry(im)
  ig.set_attribute(
    "offset",
    @core.InstancedBufferAttribute::new(
      @core.TypedArray::float32(a6u_data(14, 21, 1.0, 0.0, true)),
      3,
    ),
  )
  |> ignore
  ig.set_attribute(
    "weight",
    @core.InstancedBufferAttribute::new(
      @core.TypedArray::float32(a6u_data(15, 7, 1.0, 0.0, true)),
      1,
    ),
  )
  |> ignore
  let shared = @core.InstancedBufferAttribute::new(
    @core.TypedArray::uint16(a6u_data(16, 28, 1000.0, 0.0, false)),
    4,
  )
  ig.set_attribute("id4", shared) |> ignore
  ig.set_attribute("id4b", shared) |> ignore
  let keys = a6u_data(17, 7, 100.0, 0.0, false)
  @utils.sort_instanced_mesh(im, fn(a, b) { keys[a] - keys[b] })
  let (matrix, color) = match im.kind {
    Mesh({ kind: InstancedMesh(i), .. }) =>
      (i.instance_matrix.array, i.instance_color.unwrap().array)
    _ => abort("not instanced")
  }
  let attrs = ig.attributes
  a6u_emit(
    "scene_sort_instanced",
    a6u_js([
      a6u_array(matrix),
      a6u_array(color),
      a6u_array(attrs["offset"].array()),
      a6u_array(attrs["weight"].array()),
      a6u_array(attrs["id4"].array()),
      a6u_array(attrs["position"].array())[0:6].to_array(),
    ]),
  )
  // traverse generators
  let make = fn(name : String, parent : @core.Object3D?) {
    let o = @core.Object3D::new()
    o.name = name
    if parent is Some(parent) {
      parent.add(o) |> ignore
    }
    o
  }
  let root = make("root", None)
  let a = make("a", Some(root))
  let a1 = make("a1", Some(a))
  make("a2", Some(a)) |> ignore
  let b = make("b", Some(root))
  b.visible = false
  make("b1", Some(b)) |> ignore
  let c = make("c", Some(root))
  let c1 = make("c1", Some(c))
  make("c1x", Some(c1)) |> ignore
  let names = fn(it : Iter[@core.Object3D]) {
    let r = []
    for o in it {
      r.push(o.name)
    }
    r
  }
  let all = names(@utils.traverse_generator(root))
  let visible = names(@utils.traverse_visible_generator(root))
  let ancestors = names(@utils.traverse_ancestors_generator(c1.children[0]))
  let lazy = []
  for o in @utils.traverse_generator(root) {
    lazy.push(o.name)
    if o.name == "a" {
      make("a3", Some(a)) |> ignore
      make("d", Some(root)) |> ignore
    }
    if o.name == "a1" {
      make("a1x", Some(a1)) |> ignore
    }
  }
  let early = []
  for o in @utils.traverse_visible_generator(root) {
    early.push(o.name)
    if early.length() == 3 {
      break
    }
  }
  let invisible_root = names(@utils.traverse_visible_generator(b))
  a6u_emit(
    "scene_traverse",
    a6u_js([
      all,
      visible,
      ancestors,
      lazy,
      early,
      invisible_root,
      names(@utils.traverse_ancestors_generator(root)),
    ]),
  )
}
