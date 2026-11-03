// Differential scenarios for the environments: with A6_DIFF=1 each prints
// `@@A6U <name> <json>` (the scene's toJSON, ids relative to the scene, world matrices,
// attribute bytes, dispose order, clone), compared with upstream by the
// diff/addons/utils_env harness (upstream_env.mjs).

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
extern "js" fn a6e_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.A6_DIFF === '1'"

///|
extern "js" fn a6e_canon(c : @core.JsValue, value : @core.JsValue) -> String = "(c, v) => c.canon(v)"

///|
fn[T] a6e_js(value : T) -> @core.JsValue {
  @core.JsValue::of(value)
}

///|
fn a6e_emit(name : String, value : @core.JsValue) -> Unit {
  let s = a6e_canon(a6_common(), value)
  if a6e_enabled() {
    println("@@A6U \{name} \{s}")
  }
}

///|
fn a6e_material(o : @core.Object3D) -> @core.Material? {
  match o.get_material() {
    Some(Single(m)) => Some(m)
    _ => None
  }
}

///|
fn a6e_describe(scene : @core.Object3D) -> @core.JsValue {
  scene.update_matrix_world()
  let objects : Array[@core.JsValue] = []
  let mut first_material : Int32? = None
  let mut first_geometry : Int32? = None
  scene.traverse(fn(o) {
    let entry = [
      a6e_js((o.id - scene.id).to_double()),
      a6e_js(o.type_),
      a6e_js(o.name),
      a6e_js(o.matrix_world.elements),
    ]
    if o.get_geometry() is Some(g) {
      if first_geometry is None {
        first_geometry = Some(g.id)
      }
      entry.push(a6e_js((g.id - first_geometry.unwrap()).to_double()))
      entry.push(a6e_js(g.attributes.keys().collect()))
      entry.push(
        a6e_js(
          g.attributes.values().map(fn(a) { a.array().to_array() }).collect(),
        ),
      )
      entry.push(
        match g.index {
          Some(index) => a6e_js(index.array().to_array())
          None => @core.JsValue::null()
        },
      )
      entry.push(
        a6e_js(
          g.groups.map(fn(group) {
            let v = @core.JsValue::object()
            v.set("start", a6e_js(group.start.to_double()))
            v.set("count", a6e_js(group.count))
            v.set("materialIndex", a6e_js(group.material_index.to_double()))
            v
          }),
        ),
      )
    }
    if a6e_material(o) is Some(m) {
      if first_material is None {
        first_material = Some(m.id)
      }
      entry.push(a6e_js((m.id - first_material.unwrap()).to_double()))
    }
    if o.kind is Light(light) {
      entry.push(a6e_js(light.intensity))
      match light.kind {
        PointLight(p) => {
          entry.push(a6e_js(p.distance))
          entry.push(a6e_js(p.decay))
        }
        _ => abort("unexpected light")
      }
      entry.push(a6e_js(light.color.to_array()))
    }
    objects.push(a6e_js(entry))
  })
  let log : Array[String] = []
  scene.traverse(fn(o) {
    if o.get_geometry() is Some(g) {
      g.add_event_listener("dispose", fn(_) {
        log.push("geometry " + (g.id - first_geometry.unwrap()).to_string())
      })
    }
    if a6e_material(o) is Some(m) {
      m.add_event_listener("dispose", fn(_) {
        log.push("material " + (m.id - first_material.unwrap()).to_string())
      })
    }
  })
  let json = scene.to_json()
  let clone = scene.clone()
  scene.dispose()
  a6e_js([
    @core.JsValue::from_json(json),
    a6e_js(objects),
    a6e_js(log),
    a6e_js(scene.type_),
    a6e_js(clone.type_),
    a6e_js(clone.name),
    a6e_js(clone.children.length().to_double()),
  ])
}

///|
test "a6 environments" {
  a6e_emit("env_room", a6e_describe(@environments.RoomEnvironment::new()))
  a6e_emit(
    "env_color",
    a6e_describe(@environments.ColorEnvironment::new(color=0x336699)),
  )
  a6e_emit(
    "env_color_default",
    a6e_describe(@environments.ColorEnvironment::new()),
  )
  a6e_emit("env_debug", a6e_describe(@environments.DebugEnvironment::new()))
  assert_true(
    @environments.RoomEnvironment::of(@environments.RoomEnvironment::new())
    is Some(_),
  )
  assert_true(@environments.RoomEnvironment::of(@core.Scene::new()) is None)
}
