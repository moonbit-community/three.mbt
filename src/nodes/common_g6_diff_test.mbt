// MoonBit side of the G6 differential harness (the common Renderer and its pipeline).
// Each test `g6diff <name>` mirrors the upstream scenario of the same name in
// diff/core/g6/harness/scenarios.mjs step by step and, with G6_DIFF=1, prints its
// log as `@@G6 <name> <json>`; `node run.mjs` runs each scenario in a fresh process on
// both sides and compares the logs entry by entry. Both sides render through a stub
// backend that logs its calls and a stub node builder that skips the material build.

///|
extern "js" fn g6_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.G6_DIFF === '1'"

///|
extern "js" fn g6_print(name : String, log : @core.JsValue) -> Unit = "(n, l) => { console.log('@@G6 ' + n + ' ' + JSON.stringify(l)); }"

///|
extern "js" fn g6_new_array() -> @core.JsValue = "() => []"

///|
extern "js" fn g6_push(array : @core.JsValue, value : @core.JsValue) -> Unit = "(a, v) => { a.push(v); }"

///|
extern "js" fn g6_install_frames(log : @core.JsValue) -> @core.JsValue =
  #|(log) => {
  #|  const callbacks = [];
  #|  globalThis.self = {
  #|    requestAnimationFrame( cb ) { callbacks.push( cb ); return callbacks.length; },
  #|    cancelAnimationFrame( id ) { log.push( [ 'cancelAnimationFrame', id ] ); },
  #|  };
  #|  return callbacks;
  #|}

///|
extern "js" fn g6_fire_frame(
  callbacks : @core.JsValue,
  i : Int32,
  time : Double,
) -> Unit = "(c, i, t) => { c[ i ]( t ); }"

///|
extern "js" fn g6_frame_count(callbacks : @core.JsValue) -> Int32 = "(c) => c.length"

///|
extern "js" fn g6_stub_canvas() -> @core.JsValue = "() => ( { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } } )"

///|
extern "js" fn g6_typed_values(typed : @core.TypedArray) -> @core.JsValue = "(t) => Array.from(t)"

///|
extern "js" fn g6_byte_length(buffer : @core.JsValue) -> Int32 = "(b) => b.byteLength"

///|
extern "js" fn g6_uint8(values : Array[Int32]) -> @core.TypedArray = "(a) => new Uint8Array( a )"

///|
extern "js" fn g6_array_buffer(n : Int32) -> @core.JsValue = "(n) => new ArrayBuffer( n )"

///|
extern "js" fn g6_get(object : @core.JsValue, key : String) -> @core.JsValue = "(o, k) => o[ k ]"

// ---- log values

///|
fn[T] g6j(v : T) -> @core.JsValue {
  @core.JsValue::of(v)
}

///|
fn g6_null() -> @core.JsValue {
  @core.JsValue::null()
}

///|
fn[T] g6_opt(v : T?, f : (T) -> @core.JsValue) -> @core.JsValue {
  match v {
    Some(x) => f(x)
    None => g6_null()
  }
}

///|
struct G6Log {
  array : @core.JsValue
}

///|
fn G6Log::push(self : G6Log, entry : Array[@core.JsValue]) -> Unit {
  g6_push(self.array, g6j(entry))
}

///|
fn g6_run(name : String, f : (G6Log, () -> Unit) -> Unit) -> Unit {
  if !g6_enabled() {
    return
  }
  let log : G6Log = { array: g6_new_array(), }
  f(log, fn() { g6_print(name, log.array) })
}

///|
fn g6_align(log : G6Log) -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      abort("counter \{name} already at \{id}")
    }
    while id < target - 1 {
      id = f()
    }
  }

  // module-level nodes have upstream's ids below this; run-time ones count from it
  let first = @nodes.Node::alloc().id
  if first < @nodes.NODE_FIRST_RUNTIME_ID {
    abort("node counter at \{first}, below the first run-time id")
  }
  advance("node", 20000, fn() { @nodes.Node::alloc().id })
  advance("object3d", 1000, fn() { @core.Object3D::new().id })
  advance("material", 1000, fn() { @core.Material::new().id })
  advance("texture", 1000, fn() { @core.Texture::new().id })
  advance("attribute", 1000, fn() {
    @core.BufferAttribute::new(@core.TypedArray::float32(1), 1).id
  })
  advance("geometry", 1000, fn() { @core.BufferGeometry::new().id })
  log.push([g6j("aligned")])
}

///|
fn g6_v4(v : @math.Vector4) -> @core.JsValue {
  g6j([g6j(v.x), g6j(v.y), g6j(v.z), g6j(v.w)])
}

///|
/// Objects created at module load have runtime-specific ids.
fn g6_mid(o : @core.Object3D) -> @core.JsValue {
  if o.id < 1000 {
    g6j("module")
  } else {
    g6j(o.id)
  }
}

///|
fn g6_tex_ids(a : Array[@core.Texture]?) -> @core.JsValue {
  g6_opt(a, fn(a) { g6j(a.map(fn(t) { g6j(t.id) })) })
}

///|
fn g6_context_state(rc : @nodes.RenderContext) -> Array[@core.JsValue] {
  let c = rc.clear_color_value
  [
    g6j(rc.id),
    g6_v4(rc.viewport_value),
    g6_opt(rc.viewport_min_depth, g6j),
    g6_opt(rc.viewport_max_depth, g6j),
    g6j(rc.viewport),
    g6_v4(rc.scissor_value),
    g6j(rc.scissor),
    g6j(rc.clear_color),
    g6j([g6j(c.r), g6j(c.g), g6j(c.b), g6j(c.a)]),
    g6j(rc.clear_depth),
    g6j(rc.clear_depth_value),
    g6j(rc.clear_stencil),
    g6j(rc.clear_stencil_value),
    g6j(rc.depth),
    g6j(rc.stencil),
    g6j(rc.width),
    g6j(rc.height),
    g6j(rc.active_cube_face),
    g6j(rc.active_mipmap_level),
    g6j(rc.occlusion_query_count),
    g6j(rc.fullscreen_pass),
    g6_opt(rc.render_target, fn(t) { g6j(t.texture().id) }),
    g6_tex_ids(rc.textures),
    g6_opt(rc.depth_texture, fn(t) { g6j(t.id) }),
    g6_opt(rc.camera, g6_mid),
    g6_opt(rc.mrt, fn(_) { g6j("mrt") }),
    g6_opt(rc.frustum_array, fn(f) { g6j(f.count) }),
  ]
}

///|
fn g6_render_object_state(ro : @nodes.RenderObject) -> Array[@core.JsValue] {
  let m = ro.material
  [
    g6j(ro.id),
    g6j(ro.object.name),
    g6j(ro.object.id),
    g6j(m.name),
    g6j(m.id),
    g6j(m.side),
    g6j(m.transparent),
    g6j(ro.context.id),
    g6_mid(ro.camera),
    g6_mid(ro.scene),
    g6_opt(ro.group, fn(g) {
      g6j([g6j(g.start), g6j(g.count), g6j(g.material_index)])
    }),
    g6_opt(ro.draw_range, fn(d) { g6j([g6j(d.start), g6j(d.count)]) }),
    g6_opt(ro.bundle, fn(b) { g6j(b.id) }),
    g6_opt(ro.clipping_context, fn(c) { g6j(c.version) }),
  ]
}

// ---- stub node builder: skips the material build

///|
struct G6Observer {
  log : G6Log
  seen : @webgl.WeakMap[@core.JsValue, Int32]
}

///|
impl @nodes.NodeMaterialObserverClass for G6Observer with fn needs_refresh(
  self,
  _,
  render_object,
  node_frame,
) {
  let key = g6j(render_object)
  let type_ = match self.seen.get(key) {
    None => 2
    Some(last) => if last != node_frame.render_id { 1 } else { 0 }
  }
  self.seen.set(key, node_frame.render_id)
  self.log.push([g6j("needsRefresh"), g6j(render_object.id), g6j(type_)])
  type_
}

///|
struct G6NodeBuilder {
  log : G6Log
  observer : G6Observer
}

///|
impl @nodes.NodeBuilderClass for G6NodeBuilder with fn class_name(_) {
  "StubNodeBuilder"
}

///|
impl @nodes.NodeBuilderClass for G6NodeBuilder with fn prebuild(self, builder) {
  let m = builder.material
  let object_name = match builder.object {
    Object3D(o) => g6j(o.name)
    Compute(_) => g6j("compute")
    NoObject => g6_null()
  }
  self.log.push([
    g6j("build"),
    g6_opt(m, fn(m) { g6j(m.name) }),
    g6_opt(m, fn(m) { g6j(m.id) }),
    object_name,
    g6_opt(builder.fog_node, fn(_) { g6j("fog") }),
    g6_opt(builder.environment_node, fn(_) { g6j("env") }),
    g6_opt(builder.lights_node, fn(n) {
      g6j(@nodes.LightsNode::get_lights(n).map(fn(l) { g6j(l.id) }))
    }),
  ])
  if m is Some(_) {
    // (upstream's stub sets the observer on compute builds too, where it is unused)
    let observer = @nodes.NodeMaterialObserver::new(builder)
    observer.class_ = Some(self.observer)
    builder.observer = Some(observer)
    builder.get_attribute("position", "vec3") |> ignore
    match builder.object {
      Object3D(o) =>
        match o.get_geometry() {
          Some(g) if g.get_attribute("uv") is Some(_) =>
            builder.get_attribute("uv", "vec2") |> ignore
          _ => ()
        }
      _ => ()
    }
  }
}

///|
impl @nodes.NodeBuilderClass for G6NodeBuilder with fn build_code(_, builder) {
  match builder.material {
    Some(m) => {
      let name = m.name + ":" + m.id.to_string()
      builder.vertex_shader = Some("vs " + name)
      builder.fragment_shader = Some("fs " + name)
    }
    None => builder.compute_shader = Some("cs compute")
  }
}

// ---- stub backend

///|
struct G6Backend {
  log : G6Log
  builder : G6NodeBuilder
  bundles : Bool
  fail_init : Bool
}

///|
fn G6Backend::b(self : G6Backend, entry : Array[@core.JsValue]) -> Unit {
  self.log.push([g6j("backend"), ..entry])
}

///|
fn g6_group_ids(g : @nodes.ComputeGroup) -> @core.JsValue {
  match g {
    Node(n) => g6j(n.id)
    Nodes(a) => g6j(a.map(fn(n) { g6j(n.id) }))
  }
}

///|
fn g6_attribute_name(a : @nodes.AttributeBuffer) -> String {
  match a {
    Buffer(b) => b.name
    _ => ""
  }
}

///|
fn g6_attribute_length(a : @nodes.AttributeBuffer) -> @core.JsValue {
  g6j(a.array().unwrap().length())
}

///|
impl @nodes.BackendClass for G6Backend with fn class_name(_) {
  "StubBackend"
}

///|
impl @nodes.BackendClass for G6Backend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for G6Backend with fn init(
  self,
  backend,
  renderer,
  on_done,
) {
  self.b([g6j("init")])
  if self.fail_init {
    return on_done(Some("stub init failure"))
  }
  backend.renderer = Some(renderer)
  on_done(None)
}

///|
impl @nodes.BackendClass for G6Backend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for G6Backend with fn get_max_anisotropy(_, _) {
  16
}

///|
impl @nodes.BackendClass for G6Backend with fn has_bundles(self) {
  self.bundles
}

///|
impl @nodes.BackendClass for G6Backend with fn begin_bundle(self, _, rc) {
  self.b([g6j("beginBundle"), g6j(rc.id)])
}

///|
impl @nodes.BackendClass for G6Backend with fn finish_bundle(
  self,
  backend,
  rc,
  bundle,
) {
  self.b([g6j("finishBundle"), g6j(rc.id), g6j(bundle.bundle_group.id)])
  backend.get(g6j(bundle)).set("bundleGPU", @core.JsValue::object())
}

///|
impl @nodes.BackendClass for G6Backend with fn add_bundle(self, _, rc, bundle) {
  self.b([g6j("addBundle"), g6j(rc.id), g6j(bundle.bundle_group.id)])
}

///|
impl @nodes.BackendClass for G6Backend with fn begin_render(self, _, rc) {
  self.b([g6j("beginRender"), ..g6_context_state(rc)])
}

///|
impl @nodes.BackendClass for G6Backend with fn finish_render(self, _, rc) {
  self.b([g6j("finishRender"), g6j(rc.id)])
}

///|
impl @nodes.BackendClass for G6Backend with fn set_xr_target(self, _, t) {
  self.b([g6j("setXRTarget"), g6_opt(t, fn(t) { t })])
}

///|
impl @nodes.BackendClass for G6Backend with fn begin_compute(self, _, g) {
  self.b([g6j("beginCompute"), g6_group_ids(g)])
}

///|
impl @nodes.BackendClass for G6Backend with fn finish_compute(self, _, g) {
  self.b([g6j("finishCompute"), g6_group_ids(g)])
}

///|
impl @nodes.BackendClass for G6Backend with fn compute(
  self,
  _,
  _,
  node,
  bindings,
  pipeline,
  dispatch_size,
) {
  self.b([
    g6j("compute"),
    g6j(node.id),
    g6j(bindings.length()),
    g6j(pipeline.cache_key),
    match dispatch_size {
      None => g6_null()
      Some(Count(n)) => g6j(n)
      Some(Size(a)) => g6j(a)
      Some(Indirect(_)) => g6j("indirect")
    },
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn draw(self, _, ro, info) {
  let p = ro.get_draw_parameters()
  self.b(
    [
      g6j("draw"),
      ..g6_render_object_state(ro),
      g6_opt(p, fn(p) {
        g6j([
          g6j(p.vertex_count),
          g6j(p.first_vertex),
          g6j(p.instance_count),
          g6j(p.first_instance),
        ])
      }),
    ],
  )
  match p {
    Some(p) =>
      info.update(ro.object, p.vertex_count.to_double(), p.instance_count)
    None => ()
  }
}

///|
impl @nodes.BackendClass for G6Backend with fn create_program(self, _, p) {
  self.b([g6j("createProgram"), g6j(p.stage), g6j(p.name), g6j(p.code)])
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_program(self, _, p) {
  self.b([g6j("destroyProgram"), g6j(p.stage), g6j(p.code)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_bindings(
  self,
  _,
  g,
  bindings,
  cache_index,
) {
  self.b([
    g6j("createBindings"),
    g6j(g.name),
    g6j(bindings.length()),
    g6j(cache_index),
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn update_bindings(
  self,
  _,
  g,
  _,
  _,
  _,
) {
  self.b([g6j("updateBindings"), g6j(g.name)])
}

///|
impl @nodes.BackendClass for G6Backend with fn update_binding(self, _, binding) {
  self.b([g6j("updateBinding"), g6j(binding.name)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_render_pipeline(
  self,
  backend,
  ro,
  _,
) {
  let pipeline = ro.pipeline.unwrap()
  self.b([g6j("createRenderPipeline"), g6j(ro.id), g6j(pipeline.cache_key)])
  backend.get(g6j(pipeline)).set("pipeline", @core.JsValue::object())
}

///|
impl @nodes.BackendClass for G6Backend with fn create_compute_pipeline(
  self,
  backend,
  pipeline,
  bindings,
  _,
) {
  self.b([
    g6j("createComputePipeline"),
    g6j(pipeline.cache_key),
    g6j(bindings.length()),
  ])
  backend.get(g6j(pipeline)).set("pipeline", @core.JsValue::object())
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_pipeline(
  self,
  _,
  pipeline,
) {
  self.b([g6j("destroyPipeline"), g6j(pipeline.cache_key)])
}

///|
impl @nodes.BackendClass for G6Backend with fn needs_render_update(self, _, ro) {
  self.b([g6j("needsRenderUpdate"), g6j(ro.id)])
  false
}

///|
impl @nodes.BackendClass for G6Backend with fn get_render_cache_key(_, _, ro) {
  "s" + ro.material.side.to_string()
}

///|
impl @nodes.BackendClass for G6Backend with fn delete_vertex_state(self, _, ro) {
  self.b([g6j("deleteVertexState"), g6j(ro.id)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_node_builder(
  self,
  _,
  object,
  renderer,
) {
  @nodes.NodeBuilder::new(object, renderer, None, class_=self.builder)
}

///|
impl @nodes.BackendClass for G6Backend with fn update_sampler(self, _, s) {
  self.b([g6j("updateSampler"), g6j(s.name)])
  "sampler"
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_sampler(self, _, s) {
  self.b([g6j("destroySampler"), g6j(s.name)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_default_texture(
  self,
  _,
  t,
) {
  self.b([g6j("createDefaultTexture"), g6j(t.id)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_texture(self, _, t, o) {
  self.b([
    g6j("createTexture"),
    g6j(t.id),
    g6j(o.width),
    g6j(o.height),
    g6j(o.depth),
    g6j(o.levels),
    g6_opt(o.sample_count, g6j),
    g6_opt(o.render_target, fn(t) { g6j(t.texture().id) }),
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn update_texture(self, _, t, o) {
  self.b([g6j("updateTexture"), g6j(t.id), g6j(o.width), g6j(o.height)])
}

///|
impl @nodes.BackendClass for G6Backend with fn generate_mipmaps(self, _, t) {
  self.b([g6j("generateMipmaps"), g6j(t.id)])
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_texture(
  self,
  _,
  t,
  is_default,
) {
  self.b([g6j("destroyTexture"), g6j(t.id), g6_opt(is_default, g6j)])
}

///|
impl @nodes.BackendClass for G6Backend with fn copy_texture_to_buffer(
  self,
  _,
  t,
  x,
  y,
  w,
  h,
  face,
  on_done,
) {
  self.b([
    g6j("copyTextureToBuffer"),
    g6j(t.id),
    g6j(x),
    g6j(y),
    g6j(w),
    g6j(h),
    g6j(face),
  ])
  on_done(Some(g6_uint8([x, y, w, h])))
}

///|
impl @nodes.BackendClass for G6Backend with fn copy_texture_to_texture(
  self,
  _,
  s,
  d,
  r,
  p,
  sl,
  dl,
) {
  self.b([
    g6j("copyTextureToTexture"),
    g6j(s.id),
    g6j(d.id),
    match r {
      Some(Box2(r)) =>
        g6j([g6j(r.min.x), g6j(r.min.y), g6j(r.max.x), g6j(r.max.y)])
      Some(Box3(r)) =>
        g6j([g6j(r.min.x), g6j(r.min.y), g6j(r.max.x), g6j(r.max.y)])
      None => g6_null()
    },
    match p {
      Some(Vec2(p)) => g6j([g6j(p.x), g6j(p.y)])
      Some(Vec3(p)) => g6j([g6j(p.x), g6j(p.y)])
      None => g6_null()
    },
    g6j(sl),
    g6j(dl),
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn copy_framebuffer_to_texture(
  self,
  _,
  t,
  rc,
  rect,
) {
  self.b([
    g6j("copyFramebufferToTexture"),
    g6j(t.id),
    match rc {
      NoContext => g6_null()
      Context(c) => g6j("context:" + c.id.to_string())
      TargetData(d) =>
        g6j(
          "data:" +
          d.width.unwrap_or(0).to_string() +
          "x" +
          d.height.unwrap_or(0).to_string(),
        )
    },
    g6_v4(rect),
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_attribute(self, _, a) {
  self.b([
    g6j("createAttribute"),
    g6j(g6_attribute_name(a)),
    g6j(a.array().unwrap().type_name()),
    g6_attribute_length(a),
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_index_attribute(
  self,
  _,
  a,
) {
  self.b([g6j("createIndexAttribute"), g6_attribute_length(a)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_storage_attribute(
  self,
  _,
  a,
) {
  self.b([g6j("createStorageAttribute"), g6_attribute_length(a)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_indirect_storage_attribute(
  self,
  _,
  a,
) {
  self.b([g6j("createIndirectStorageAttribute"), g6_attribute_length(a)])
}

///|
impl @nodes.BackendClass for G6Backend with fn create_uniform_buffer(self, _, u) {
  self.b([g6j("createUniformBuffer"), g6j(u.name)])
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_uniform_buffer(
  self,
  _,
  u,
) {
  self.b([g6j("destroyUniformBuffer"), g6j(u.name)])
}

///|
impl @nodes.BackendClass for G6Backend with fn update_attribute(self, _, a) {
  self.b([g6j("updateAttribute"), g6_attribute_length(a)])
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_attribute(self, _, a) {
  self.b([g6j("destroyAttribute"), g6_attribute_length(a)])
}

///|
impl @nodes.BackendClass for G6Backend with fn get_context(_, _) {
  g6j("context")
}

///|
impl @nodes.BackendClass for G6Backend with fn update_size(self, _) {
  self.b([g6j("updateSize")])
}

///|
impl @nodes.BackendClass for G6Backend with fn destroy_canvas_target(
  self,
  _,
  ct,
) {
  self.b([g6j("destroyCanvasTarget"), g6j(ct.is_default_canvas_target)])
}

///|
impl @nodes.BackendClass for G6Backend with fn is_occluded(self, _, rc, o) {
  self.b([g6j("isOccluded"), g6j(rc.id), g6j(o.id)])
  o.name == "occluded"
}

///|
impl @nodes.BackendClass for G6Backend with fn get_array_buffer_async(
  self,
  _,
  a,
  target,
  offset,
  count,
  on_done,
) {
  self.b([
    g6j("getArrayBufferAsync"),
    g6_attribute_length(a),
    g6_opt(target, fn(t) { g6j(t.name) }),
    g6j(offset),
    g6j(count),
  ])
  on_done(g6_array_buffer(8))
}

///|
impl @nodes.BackendClass for G6Backend with fn has_feature(self, _, name) {
  self.b([g6j("hasFeature"), g6j(name)])
  name == "feature"
}

///|
impl @nodes.BackendClass for G6Backend with fn set_scissor_test(self, _, v) {
  self.b([g6j("setScissorTest"), g6j(v)])
}

///|
impl @nodes.BackendClass for G6Backend with fn reset_state(self, _) {
  self.b([g6j("resetState")])
}

///|
impl @nodes.BackendClass for G6Backend with fn has_compatibility(_, _, name) {
  name == "compat"
}

///|
impl @nodes.BackendClass for G6Backend with fn init_render_target(self, _, rc) {
  self.b([g6j("initRenderTarget"), ..g6_context_state(rc)])
}

///|
impl @nodes.BackendClass for G6Backend with fn clear(
  self,
  _,
  color,
  depth,
  stencil,
  rc,
) {
  self.b([
    g6j("clear"),
    g6j(color),
    g6j(depth),
    g6j(stencil),
    g6_opt(rc, fn(rc) { g6j(g6_context_state(rc)) }),
  ])
}

///|
impl @nodes.BackendClass for G6Backend with fn dispose(self, backend, on_done) {
  self.b([g6j("dispose")])
  backend.dispose_base()
  on_done()
}

///|
impl @nodes.BackendClass for G6Backend with fn delete_bind_group_data(
  self,
  _,
  g,
) {
  self.b([g6j("deleteBindGroupData"), g6j(g.name)])
}

///|
fn g6_backend(
  log : G6Log,
  bundles~ : Bool = false,
  fail_init~ : Bool = false,
) -> @nodes.Backend {
  let observer = G6Observer::{ log, seen: @webgl.WeakMap::new(), }
  let stub = G6Backend::{
    log,
    builder: { log, observer, },
    bundles,
    fail_init,
  }
  let parameters = @core.JsValue::object()
  parameters.set("canvas", g6_stub_canvas())
  @nodes.Backend::new(stub, parameters~)
}

///|
fn g6_info(renderer : @nodes.Renderer) -> Array[@core.JsValue] {
  let i = renderer.info
  [
    g6j(i.calls),
    g6j(i.frame),
    g6j(i.render.calls),
    g6j(i.render.frame_calls),
    g6j(i.render.draw_calls),
    g6j(i.render.triangles),
    g6j(i.render.points),
    g6j(i.render.lines),
    g6j(i.compute.calls),
    g6j(i.compute.frame_calls),
    g6j(i.memory.textures),
    g6j(i.memory.render_targets),
    g6j(i.memory.attributes),
    g6j(i.memory.geometries),
    g6j(i.memory.programs),
  ]
}

///|
fn g6_node_material(name : String) -> @core.Material {
  let m = @nodes.NodeMaterial::new()
  m.name = name
  m
}

///|
fn g6_node_slots(m : @core.Material) -> @nodes.NodeMaterial {
  @nodes.NodeMaterial::of(m).unwrap()
}

///|
fn g6_box(w~ : Double = 1.0) -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  g.set_attribute(
    "position",
    @core.Float32BufferAttribute::new(
      ([0.0, 0, 0, w, 0, 0, 0, w, 0, w, w, 0] : Array[Double]),
      3,
    ),
  )
  |> ignore
  g.set_attribute(
    "uv",
    @core.Float32BufferAttribute::new(
      ([0.0, 0, 1, 0, 0, 1, 1, 1] : Array[Double]),
      2,
    ),
  )
  |> ignore
  g.set_index([0, 1, 2, 2, 1, 3]) |> ignore
  g
}

///|
fn g6_mesh(
  name : String,
  material : @core.Material,
  geometry? : @core.BufferGeometry,
) -> @core.Object3D {
  let mesh = @core.Mesh::new(
    geometry=geometry.unwrap_or(g6_box()),
    material=Single(material),
  )
  mesh.name = name
  mesh
}

// ---- scenarios

///|
test "g6diff init_size" {
  g6_run("init_size", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    log.push([
      g6j("created"),
      g6j(renderer.initialized()),
      g6j(renderer.samples()),
      g6j(renderer.get_pixel_ratio()),
      g6j(renderer.coordinate_system()),
    ])
    renderer.init(on_done=fn(_) {
      log.push([g6j("init"), g6j(renderer.initialized()), ..g6_info(renderer)])
      renderer.set_pixel_ratio(2.0)
      renderer.set_size(200.0, 100.0)
      let v = @math.Vector2::new(0.0, 0.0)
      renderer.get_size(v) |> ignore
      let d = @math.Vector2::new(0.0, 0.0)
      renderer.get_drawing_buffer_size(d) |> ignore
      let canvas = renderer.dom_element()
      log.push([
        g6j("size"),
        g6j(v.x),
        g6j(v.y),
        g6j(d.x),
        g6j(d.y),
        g6_get(canvas, "width"),
        g6_get(canvas, "height"),
        g6_get(g6_get(canvas, "style"), "width"),
      ])
      renderer.set_viewport(10.0, 20.0, 50.0, 40.0)
      renderer.set_scissor(5.0, 5.0, 30.0, 30.0)
      renderer.set_scissor_test(true)
      let vp = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
      renderer.get_viewport(vp) |> ignore
      let sc = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)
      renderer.get_scissor(sc) |> ignore
      log.push([
        g6j("viewport"),
        g6_v4(vp),
        g6_v4(sc),
        g6j(renderer.get_scissor_test()),
      ])
      renderer.set_clear_color(@math.Color::new(0.2, 0.4, 0.6), alpha=0.5)
      let c = renderer.get_clear_color(@math.Color::new(0.0, 0.0, 0.0))
      log.push([
        g6j("clearColor"),
        g6j(c.r),
        g6j(c.g),
        g6j(c.b),
        g6j(renderer.get_clear_alpha()),
      ])
      renderer.clear()
      renderer.set_clear_color_hex(0xff0000)
      renderer.set_clear_alpha(0.25)
      renderer.set_clear_depth(0.5)
      renderer.set_clear_stencil(3)
      renderer.clear_color()
      renderer.clear_depth()
      renderer.clear_stencil()
      let rt = @core.RenderTarget::new(width=16, height=8)
      renderer.set_render_target(Some(rt))
      renderer.clear()
      renderer.set_render_target(None)
      renderer.output_color_space = @core.LinearSRGBColorSpace
      renderer.clear()
      renderer.reversed_depth_buffer = true
      log.push([
        g6j("state"),
        g6j(renderer.get_clear_depth()),
        g6j(renderer.get_clear_stencil()),
        g6j(renderer.needs_frame_buffer_target()),
        g6j(renderer.current_samples()),
        g6j(renderer.get_max_anisotropy()),
        g6j(renderer.has_feature("feature")),
        g6j(renderer.has_compatibility("compat")),
        g6j(renderer.get_context()),
      ])
      renderer.reset_state()
      renderer.set_drawing_buffer_size(50.0, 25.0, 1.0)
      renderer.get_drawing_buffer_size(d) |> ignore
      log.push([g6j("drawingBuffer"), g6j(d.x), g6j(d.y), ..g6_info(renderer)])
      done()
    })
  })
}

///|
fn g6_material(
  name : String,
  setup : (@core.Material) -> Unit,
) -> @core.Material {
  let m = g6_node_material(name)
  setup(m)
  m
}

///|
test "g6diff render_scene" {
  g6_run("render_scene", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    renderer.init(on_done=fn(_) {
      renderer.set_size(64.0, 32.0, update_style=false)
      renderer.output_color_space = @core.LinearSRGBColorSpace
      let scene = @core.Scene::new()
      scene.name = "scene"
      let camera = @core.PerspectiveCamera::new(
        fov=50.0,
        aspect=2.0,
        near=0.1,
        far=100.0,
      )
      camera.position.set(0.0, 0.0, 5.0) |> ignore
      camera.name = "camera"
      let light = @core.DirectionalLight::new()
      scene.add(light) |> ignore
      let opaque = g6_mesh("opaque", g6_node_material("opaqueMat"))
      opaque.position.set(0.0, 0.0, -1.0) |> ignore
      opaque.on_before_render = fn(r, s, c, _, m, _) {
        log.push([
          g6j("onBeforeRender"),
          g6j(opaque.name),
          g6j(s.id),
          g6j(c.id),
          g6j(m.name),
          g6j(r.strict_equal(g6j(renderer))),
        ])
      }
      opaque.on_after_render = fn(_, _, _, _, m, _) {
        log.push([g6j("onAfterRender"), g6j(opaque.name), g6j(m.name)])
      }
      let opaque2 = g6_mesh("opaque2", g6_node_material("opaqueMat2"))
      opaque2.position.set(0.5, 0.0, -3.0) |> ignore
      opaque2.render_order = 1.0
      let transparent = g6_mesh(
        "transparent",
        g6_material("transparentMat", fn(m) { m.transparent = true }),
      )
      transparent.position.z = 0.5
      let double_t = g6_mesh(
        "doubleT",
        g6_material("doubleMat", fn(m) {
          m.transparent = true
          m.side = @core.DoubleSide
        }),
      )
      let backdrop = g6_mesh(
        "backdrop",
        g6_material("backdropMat", fn(m) {
          g6_node_slots(m).backdrop_node = Some(@nodes.vec3(1))
        }),
      )
      let geometry = g6_box()
      geometry.add_group(0, 3.0, material_index=0)
      geometry.add_group(3, 3.0, material_index=1)
      let multi = @core.Mesh::new(
        geometry~,
        material=Multiple([
          g6_node_material("groupA"),
          g6_node_material("groupB"),
        ]),
      )
      multi.name = "multi"
      let group = @core.Group::new()
      group.render_order = 2.0
      group.name = "group"
      group.add(multi) |> ignore
      let sprite = @core.Sprite::new(material=g6_node_material("spriteMat"))
      sprite.name = "sprite"
      sprite.position.set(-0.5, 0.0, 0.0) |> ignore
      let lod = @core.LOD::new()
      lod.name = "lod"
      lod.add_level(
        g6_mesh("lodNear", g6_node_material("lodNearMat")),
        distance=0.0,
      )
      |> ignore
      lod.add_level(
        g6_mesh("lodFar", g6_node_material("lodFarMat")),
        distance=3.0,
      )
      |> ignore
      let culled = g6_mesh("culled", g6_node_material("culledMat"))
      culled.position.set(1000.0, 0.0, 0.0) |> ignore
      let hidden = g6_mesh("hidden", g6_node_material("hiddenMat"))
      hidden.layers.set(2)
      let invisible = g6_mesh("invisible", g6_node_material("invisibleMat"))
      invisible.visible = false
      let no_mat = g6_mesh(
        "noMat",
        g6_material("invisibleMaterial", fn(m) { m.visible = false }),
      )
      scene.add_all([
        opaque, opaque2, transparent, double_t, backdrop, group, sprite, lod, culled,
        hidden, invisible, no_mat,
      ])
      |> ignore
      renderer.render(scene, camera)
      log.push([g6j("frame1"), ..g6_info(renderer)])
      renderer.render(scene, camera)
      log.push([g6j("frame2"), ..g6_info(renderer)])
      // custom sort and render object function
      renderer.set_opaque_sort(
        Some(fn(a, b) { (b.id.unwrap() - a.id.unwrap()).to_double() }),
      )
      renderer.set_render_object_function(
        Some({
          f: fn(object, s, c, g, m, gr, lights_node, cc, pass_id) {
            log.push([
              g6j("renderObjectFunction"),
              g6j(object.name),
              g6j(m.name),
              g6_opt(pass_id, g6j),
            ])
            renderer.render_object(
              object, s, c, g, m, gr, lights_node, cc, pass_id,
            )
          },
        }),
      )
      renderer.transparent = false
      renderer.render(scene, camera)
      renderer.set_render_object_function(None)
      renderer.set_opaque_sort(None)
      renderer.transparent = true
      renderer.opaque_ = false
      renderer.sort_objects = false
      renderer.render(scene, camera)
      renderer.opaque_ = true
      renderer.sort_objects = true
      // an array camera
      let left = @core.PerspectiveCamera::new(
        fov=50.0,
        aspect=1.0,
        near=0.1,
        far=100.0,
      )
      left.position.set(-1.0, 0.0, 5.0) |> ignore
      left.update_matrix_world()
      let right = @core.PerspectiveCamera::new(
        fov=50.0,
        aspect=1.0,
        near=0.1,
        far=100.0,
      )
      right.position.set(1.0, 0.0, 5.0) |> ignore
      right.update_matrix_world()
      let array_camera = @core.ArrayCamera::new(array=[left, right])
      array_camera.position.set(0.0, 0.0, 5.0) |> ignore
      renderer.render(scene, array_camera)
      // another camera, orthographic
      let ortho = @core.OrthographicCamera::new(
        left=-2.0,
        right=2.0,
        top=1.0,
        bottom=-1.0,
        near=0.1,
        far=10.0,
      )
      ortho.position.set(0.0, 0.0, 3.0) |> ignore
      renderer.render(scene, ortho)
      log.push(
        [g6j("end"), ..g6_info(renderer), g6j(renderer.is_occluded(opaque))],
      )
      done()
    })
  })
}

///|
test "g6diff render_targets" {
  g6_run("render_targets", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    renderer.init(on_done=fn(_) {
      renderer.set_size(32.0, 32.0, update_style=false)
      let scene = @core.Scene::new()
      let camera = @core.PerspectiveCamera::new(
        fov=50.0,
        aspect=1.0,
        near=0.1,
        far=100.0,
      )
      camera.position.set(0.0, 0.0, 5.0) |> ignore
      scene.add(g6_mesh("a", g6_node_material("aMat"))) |> ignore
      // a render target with a depth texture
      let rt = @core.RenderTarget::new(
        width=16,
        height=16,
        depth_texture=@core.DepthTexture::new(width=16, height=16),
      )
      rt.viewport.set(2.0, 2.0, 8.0, 8.0) |> ignore
      rt.scissor.set(1.0, 1.0, 30.0, 4.0) |> ignore
      rt.scissor_test = true
      renderer.set_render_target(Some(rt))
      renderer.auto_clear_depth = false
      renderer.render(scene, camera)
      renderer.auto_clear_depth = true
      // MRT
      let mrt_target = @core.RenderTarget::new(width=8, height=8, count=2)
      renderer.set_render_target(Some(mrt_target))
      renderer.set_mrt(
        Some(
          @nodes.mrt({ "output": @nodes.output, "emissive": @nodes.vec4(1) }),
        ),
      )
      |> ignore
      renderer.render(scene, camera)
      renderer.set_mrt(None) |> ignore
      // a cube render target, every face, two mips
      let cube = @nodes.CubeRenderTarget::new(
        size=8,
        options=@nodes.RenderTargetOptions::new(
          generate_mipmaps=true,
          min_filter=@core.LinearMipmapLinearFilter,
        ),
      )
      let ct = cube.texture()
      log.push([
        g6j("cube"),
        g6j(cube.has_extension_flag("isCubeRenderTarget")),
        g6j(ct.is_cube_texture()),
        g6j(ct.is_render_target_texture),
        g6j(
          match ct.image() {
            ImageArray(a) => a.length()
            _ => -1
          },
        ),
        g6j(ct.generate_mipmaps),
        g6j(ct.min_filter),
      ])
      for face in 0..<6 {
        renderer.set_render_target(
          Some(cube),
          active_cube_face=face,
          active_mipmap_level=face % 2,
        )
        log.push([
          g6j("face"),
          g6j(renderer.get_active_cube_face()),
          g6j(renderer.get_active_mipmap_level()),
        ])
        renderer.render(scene, camera)
      }
      @nodes.CubeRenderTarget::clear(
        cube,
        renderer,
        color=true,
        depth=false,
        stencil=true,
      )
      renderer.set_render_target(None)
      // an output render target with tone mapping
      let out = @core.RenderTarget::new(width=20, height=10)
      renderer.set_output_render_target(Some(out))
      renderer.tone_mapping = @core.ACESFilmicToneMapping
      renderer.render(scene, camera)
      log.push([
        g6j("output"),
        g6j(renderer.is_output_target()),
        g6j(renderer.current_tone_mapping()),
        g6j(renderer.current_color_space()),
        g6j(renderer.needs_frame_buffer_target()),
      ])
      renderer.set_render_target(Some(rt))
      log.push([
        g6j("target"),
        g6j(renderer.is_output_target()),
        g6j(renderer.current_tone_mapping()),
        g6j(renderer.current_color_space()),
        g6j(renderer.current_samples()),
      ])
      renderer.set_render_target(None)
      renderer.set_output_render_target(None)
      renderer.render(scene, camera)
      renderer.init_render_target(@core.RenderTarget::new(width=4, height=4))
      rt.dispose()
      out.dispose()
      log.push([g6j("end"), ..g6_info(renderer)])
      done()
    })
  })
}

///|
test "g6diff background_fog" {
  g6_run("background_fog", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    renderer.init(on_done=fn(_) {
      renderer.set_size(16.0, 16.0, update_style=false)
      let scene = @core.Scene::new()
      let s = scene.as_scene()
      let camera = @core.PerspectiveCamera::new(
        fov=50.0,
        aspect=1.0,
        near=0.1,
        far=100.0,
      )
      camera.position.set(0.0, 0.0, 5.0) |> ignore
      scene.add(g6_mesh("a", g6_node_material("aMat"))) |> ignore
      renderer.render(scene, camera)
      s.background = Some(Color(@math.Color::new(0.25, 0.5, 0.75)))
      renderer.auto_clear = false
      renderer.render(scene, camera)
      renderer.auto_clear = true
      s.fog = Some(
        Fog(
          @core.Fog::new(
            color=@math.Color::new(1.0, 1.0, 1.0),
            near=1.0,
            far=10.0,
          ),
        ),
      )
      renderer.render(scene, camera)
      let tex = @core.DataTexture::new(
        data=@core.TypedArray::uint8(16),
        width=2,
        height=2,
      )
      tex.mapping = @core.EquirectangularReflectionMapping
      s.background = Some(Texture(tex))
      s.background_blurriness = 0.5
      renderer.render(scene, camera)
      let images = [1, 2, 3, 4, 5, 6].map(fn(_) {
        @core.TextureImage::DataImage(@core.DataImage::new(width=4, height=4))
      })
      let cube_tex = @core.CubeTexture::new(images~)
      s.background = Some(Texture(cube_tex))
      renderer.render(scene, camera)
      s.background_node = Some(g6j(@nodes.vec3(0.5)))
      renderer.render(scene, camera)
      s.background_node = None
      s.background = None
      renderer.tone_mapping = @core.ReinhardToneMapping
      renderer.output_color_space = @core.SRGBColorSpace
      renderer.render(scene, camera)
      renderer.render(scene, camera)
      renderer.tone_mapping_exposure = 2.0
      renderer.tone_mapping = @core.NoToneMapping
      renderer.render(scene, camera)
      renderer.alpha = false
      renderer.set_clear_color_hex(0x336699, alpha=0.5)
      renderer.output_color_space = @core.LinearSRGBColorSpace
      renderer.render(scene, camera)
      log.push([g6j("end"), ..g6_info(renderer)])
      done()
    })
  })
}

///|
extern "js" fn g6_join(typed : @core.TypedArray) -> String = "(t) => Array.from( t ).join( ',' )"

///|
fn g6_empty_fn() -> Node {
  @nodes.fn_(fn(_, _) { None }).call([])
}

///|
test "g6diff compute_copy" {
  g6_run("compute_copy", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    let early = g6_empty_fn().compute(2)
    renderer.compute_async(early, on_done=fn() {
      log.push([g6j("computeAsync"), ..g6_info(renderer)])
      let a = g6_empty_fn().compute(4)
      let b = g6_empty_fn().compute(8, workgroup_size=[32])
      let inits = Ref(0)
      @nodes.ComputeNode::of(a).unwrap().on_init_function = Some(fn(_, _) {
        inits.val += 1
      })
      renderer.compute(a)
      renderer.compute(a)
      renderer.compute_list([a, b])
      renderer.compile_compute_async(g6_empty_fn().compute(1), on_done=fn() {
        log.push([g6j("compute"), g6j(inits.val), ..g6_info(renderer)])
        renderer.set_size(16.0, 8.0, update_style=false)
        renderer.output_color_space = @core.LinearSRGBColorSpace
        let fb = @core.FramebufferTexture::new(width=16, height=8)
        renderer.copy_framebuffer_to_texture(fb)
        renderer.copy_framebuffer_to_texture(
          fb,
          rectangle=@math.Vector4::new(1.5, 2.5, 4.0, 4.0),
        )
        renderer.copy_framebuffer_to_texture_at(
          fb,
          @math.Vector2::new(3.0, 1.0),
        )
        let rt = @core.RenderTarget::new(width=8, height=8)
        renderer.set_render_target(Some(rt))
        renderer.copy_framebuffer_to_texture(
          @core.FramebufferTexture::new(width=8, height=8),
        )
        renderer.set_render_target(None)
        renderer.output_color_space = @core.SRGBColorSpace
        renderer.copy_framebuffer_to_texture(fb)
        let src = @core.DataTexture::new(
          data=@core.TypedArray::uint8(64),
          width=4,
          height=4,
        )
        let dst = @core.DataTexture::new(
          data=@core.TypedArray::uint8(64),
          width=4,
          height=4,
        )
        renderer.copy_texture_to_texture(src, dst)
        renderer.copy_texture_to_texture(
          src,
          dst,
          src_region=Box2(
            @math.Box2::new(
              min=@math.Vector2::new(1.0, 1.0),
              max=@math.Vector2::new(3.0, 3.0),
            ),
          ),
          dst_position=Vec2(@math.Vector2::new(0.0, 1.0)),
          src_level=0,
          dst_level=1,
        )
        renderer.read_render_target_pixels_async(rt, 1, 2, 3, 4, fn(pixels) {
          log.push([g6j("pixels"), g6_typed_values(pixels.unwrap())])
          let attribute = @nodes.StorageBufferAttribute::new(4, 4)
          let readback = @nodes.ReadbackBuffer::new(64)
          readback.name = "readback"
          renderer.get_array_buffer_async(
            Buffer(attribute),
            target=readback,
            offset=4,
            count=8,
            fn(buffer) {
              renderer.get_array_buffer_async(
                Buffer(attribute),
                target=readback,
                fn(_) {
                  log.push(
                    [
                      g6j("arrayBuffer"),
                      g6j(g6_byte_length(buffer)),
                      ..g6_info(renderer),
                    ],
                  )
                  readback.dispose()
                  log.push([g6j("readbackDisposed"), ..g6_info(renderer)])
                  a.dispose()
                  renderer.compute(a)
                  log.push([g6j("end"), g6j(inits.val), ..g6_info(renderer)])
                  done()
                },
              )
            },
          )
        })
      })
    })
  })
}

///|
test "g6diff info_dispose" {
  g6_run("info_dispose", fn(log, done) {
    let frames = g6_install_frames(log.array)
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log), antialias=true)
    renderer.init(on_done=fn(_) {
      renderer.set_size(8.0, 8.0, update_style=false)
      let scene = @core.Scene::new()
      let camera = @core.PerspectiveCamera::new()
      camera.position.z = 3.0
      let geometry = g6_box()
      let material = g6_node_material("m")
      let a = g6_mesh("a", material, geometry~)
      scene.add(a) |> ignore
      renderer.render(scene, camera)
      log.push(
        [g6j("render"), g6j(g6_frame_count(frames)), ..g6_info(renderer)],
      )
      g6_fire_frame(frames, 0, 16.0)
      log.push([g6j("frame"), g6j(g6_frame_count(frames)), ..g6_info(renderer)])
      renderer.info.auto_reset = false
      renderer.render(scene, camera)
      g6_fire_frame(frames, 1, 32.0)
      log.push([g6j("noReset"), ..g6_info(renderer)])
      renderer.info.auto_reset = true
      let loops : Array[@core.JsValue] = []
      renderer.set_animation_loop(Some(fn(t, _) { loops.push(g6j(t)) }), on_done=fn() {
        g6_fire_frame(frames, g6_frame_count(frames) - 1, 48.0)
        log.push([
          g6j("loop"),
          g6j(loops),
          g6j(renderer.get_animation_loop() is Some(_)),
        ])
        renderer.set_animation_loop(None, on_done=fn() {
          material.dispose()
          renderer.render(scene, camera)
          geometry.dispose()
          renderer.render(scene, camera)
          let xr = renderer.xr
          let xr_camera = xr.get_camera()
          log.push([
            g6j("xr"),
            g6j(xr.enabled),
            g6j(xr.is_presenting),
            g6j(xr.camera_auto_update),
            g6j(xr_camera.is_array_camera()),
            g6j(
              match xr_camera.kind {
                Camera(
                  { kind: PerspectiveCamera({ array_camera: Some(c), .. }), .. }
                ) => c.cameras.length()
                _ => -1
              },
            ),
            g6_opt(xr.get_environment_blend_mode(), g6j),
            g6j(xr.get_foveation()),
            g6j(xr.get_framebuffer_scale_factor()),
            g6j(xr.get_reference_space_type()),
            g6_opt(xr.get_reference_space(), fn(s) { s }),
            g6_opt(xr.get_session(), fn(s) { s }),
            g6_opt(xr.get_frame(), fn(s) { s }),
            g6j(xr.use_multiview()),
            g6_opt(xr.get_base_layer(), fn(s) { s }),
          ])
          xr.set_foveation(0.5)
          xr.set_framebuffer_scale_factor(2.0)
          xr.set_reference_space_type("local")
          let controller = xr.get_controller(1)
          log.push([
            g6j("controller"),
            g6j(controller.id),
            g6j(xr.get_controller_grip(1).id),
            g6j(xr.get_hand(0).id),
            g6j(physical_equal(xr.get_controller(1), controller)),
          ])
          let layer_scene = @core.Scene::new()
          layer_scene.add(g6_mesh("layerMesh", g6_node_material("layerMat")))
          |> ignore
          let plane = xr.create_quad_layer(
            1.0,
            1.0,
            @math.Vector3::new(0.0, 0.0, -1.0),
            @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
            8,
            8,
            fn() { renderer.render(layer_scene, camera) },
          )
          let plane_material = match plane.get_material() {
            Some(Single(m)) => m
            _ => abort("no material")
          }
          let map = plane_material.map.unwrap()
          log.push([
            g6j("quadLayer"),
            g6j(plane.id),
            g6j(map.id),
            g6j(map.offset.y),
            g6j(map.repeat.y),
            g6j(plane_material.side),
          ])
          let cylinder = xr.create_cylinder_layer(
            1.0,
            3.141592653589793 / 2.0,
            2.0,
            @math.Vector3::new(0.0, 0.0, -1.0),
            @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
            4,
            4,
            fn() { log.push([g6j("cylinder render")]) },
            stencil=true,
            samples=2,
          )
          let cylinder_material = match cylinder.get_material() {
            Some(Single(m)) => m
            _ => abort("no material")
          }
          log.push([
            g6j("cylinderLayer"),
            g6j(cylinder.id),
            g6j(cylinder_material.side),
            g6j(
              cylinder
              .get_geometry()
              .unwrap()
              .get_attribute("position")
              .unwrap()
              .count(),
            ),
          ])
          xr.render_layers()
          xr.update_camera(camera)
          log.push(
            [
              g6j("afterLayers"),
              g6_opt(renderer.get_render_target(), fn(_) { g6j("target") }),
              ..g6_info(renderer),
            ],
          )
          renderer.dispose(on_done=fn() {
            log.push([g6j("disposed"), ..g6_info(renderer)])
            done()
          })
        })
      })
    })
  })
}

///|
test "g6diff pipelines" {
  g6_run("pipelines", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    renderer.init(on_done=fn(_) {
      renderer.set_size(16.0, 16.0, update_style=false)
      let scene = @core.Scene::new()
      let camera = @core.PerspectiveCamera::new()
      camera.position.z = 3.0
      scene.add(g6_mesh("a", g6_node_material("aMat"))) |> ignore
      let scene_pass = @nodes.pass(scene, camera)
      let pipeline = @nodes.RenderPipeline::new(
        renderer,
        output_node=scene_pass,
      )
      pipeline.render()
      pipeline.render()
      renderer.tone_mapping = @core.AgXToneMapping
      pipeline.render()
      let frame = renderer.node_frame()
      frame.renderer = Some(renderer)
      scene_pass.update_before(frame) |> ignore
      let pass_target = @nodes.PassNode::of(scene_pass).unwrap().render_target
      log.push([
        g6j("pass"),
        g6j(pass_target.width),
        g6j(pass_target.height),
        g6j(pass_target.texture().id),
      ])
      pipeline.output_color_transform = false
      pipeline.needs_update = true
      pipeline.render()
      pipeline.dispose()
      let post = @nodes.PostProcessing::new(renderer)
      post.render()
      let direct = @nodes.DirectRenderPipeline::new(renderer)
      scene.as_scene().background = Some(Color(@math.Color::from_hex(0x112233)))
      @nodes.DirectRenderPipeline::render(direct, scene, camera)
      @nodes.DirectRenderPipeline::render(direct, scene, camera)
      let direct_payload = @nodes.DirectRenderPipeline::of(direct).unwrap()
      log.push([
        g6j("direct"),
        g6_opt(scene.as_scene().background_node, fn(n) { n }),
        g6j(
          direct_payload._context_node is Some(c) &&
          physical_equal(c, renderer.context_node),
        ),
        g6j(renderer.tone_mapping),
      ])
      let quad = @nodes.QuadMesh::new(material=g6_node_material("quadMat"))
      quad.render(renderer)
      quad.set_material(g6_node_material("quadMat2"))
      quad.render(renderer)
      log.push([
        g6j("quad"),
        g6j(quad.object.has_extension_flag("isQuadMesh")),
        g6j(quad.camera().is_orthographic_camera()),
        g6j(
          g6_join(
            quad.object
            .get_geometry()
            .unwrap()
            .get_attribute("uv")
            .unwrap()
            .array(),
          ),
        ),
        g6_opt(g6_node_slots(quad.material()).vertex_node, fn(_) { g6j("node") }),
      ])
      log.push([g6j("end"), ..g6_info(renderer)])
      done()
    })
  })
}

///|
test "g6diff pmrem" {
  g6_run("pmrem", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    renderer.init(on_done=fn(_) {
      let generator = @nodes.PMREMGenerator::new(renderer)
      let scene = @core.Scene::new()
      scene.add(g6_mesh("a", g6_node_material("aMat"))) |> ignore
      let from_scene = generator.from_scene(
        scene,
        sigma=0.04,
        near=0.1,
        far=100.0,
        size=64,
      )
      log.push([
        g6j("fromScene"),
        g6j(from_scene.width),
        g6j(from_scene.texture().mipmaps.length()),
        g6j(from_scene.texture().name),
        g6j(from_scene.texture().is_pmrem_texture),
        g6_opt(scene.as_scene().background, fn(_) { g6j("background") }),
      ])
      let equirect = @core.DataTexture::new(
        data=@core.TypedArray::uint8(4 * 512 * 4),
        width=512,
        height=4,
      )
      let from_equirect = generator.from_equirectangular(equirect)
      log.push([
        g6j("fromEquirectangular"),
        g6j(from_equirect.width),
        g6j(from_equirect.texture().mipmaps.length()),
      ])
      let images = [1, 2, 3, 4, 5, 6].map(fn(_) {
        @core.TextureImage::DataImage(
          @core.DataImage::new(width=128, height=128),
        )
      })
      let cubemap = @core.CubeTexture::new(images~)
      let from_cube = generator.from_cubemap(
        cubemap,
        render_target=from_equirect,
      )
      log.push([
        g6j("fromCubemap"),
        g6j(physical_equal(from_cube, from_equirect)),
        g6j(@nodes.PMREMGenerator::lod_to_roughness(2.0, 5.0)),
      ])
      generator.dispose()
      log.push([g6j("end"), ..g6_info(renderer)])
      done()
    })
  })
}

///|
test "g6diff bundles_compile" {
  g6_run("bundles_compile", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log, bundles=true))
    renderer.init(on_done=fn(_) {
      renderer.set_size(16.0, 16.0, update_style=false)
      renderer.output_color_space = @core.LinearSRGBColorSpace
      let scene = @core.Scene::new()
      let camera = @core.PerspectiveCamera::new()
      camera.position.z = 3.0
      let bundle = @nodes.BundleGroup::new()
      bundle.name = "bundle"
      bundle.add(g6_mesh("inBundle", g6_node_material("bundleMat"))) |> ignore
      scene.add_all([bundle, g6_mesh("outside", g6_node_material("outsideMat"))])
      |> ignore
      renderer.render(scene, camera)
      renderer.render(scene, camera)
      @nodes.BundleGroup::set_needs_update(bundle, true)
      renderer.render(scene, camera)
      let compiled = @core.Scene::new()
      compiled.add(
        g6_mesh(
          "compiled",
          g6_material("compiledMat", fn(m) {
            m.transparent = true
            m.side = @core.DoubleSide
          }),
        ),
      )
      |> ignore
      compiled.add(@core.PointLight::new()) |> ignore
      renderer.compile_async(compiled, camera, on_done=fn() {
        log.push([g6j("compiled"), ..g6_info(renderer)])
        renderer.render(compiled, camera)
        let target = @core.Scene::new()
        target.add(@core.DirectionalLight::new()) |> ignore
        let single = g6_mesh("single", g6_node_material("singleMat"))
        renderer.compile(single, camera, target_scene=target, on_done=fn() {
          // override material
          let override_ = g6_material("override", fn(m) {
            m.depth_write = false
          })
          scene.as_scene().override_material = Some(override_)
          renderer.render(scene, camera)
          scene.as_scene().override_material = None
          log.push([g6j("end"), ..g6_info(renderer)])
          done()
        })
      })
    })
  })
}

///|
extern "js" fn g6_canvas(width : Int32, height : Int32) -> @core.JsValue = "(w, h) => ( { style: {}, width: w, height: h } )"

///|
/// The class of the harness's shadow pass material (`material.isShadowPassMaterial`).
struct G6ShadowPassClass {}

///|
impl @nodes.NodeMaterialClass for G6ShadowPassClass with fn class_name(_) {
  "NodeMaterial"
}

///|
impl @nodes.NodeMaterialClass for G6ShadowPassClass with fn parent(_) {
  Some(@nodes.BaseNodeMaterial::{ })
}

///|
impl @nodes.NodeMaterialClass for G6ShadowPassClass with fn has_flag(_, flag) {
  flag == "isShadowPassMaterial"
}

///|
test "g6diff utils_misc" {
  g6_run("utils_misc", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log, fail_init=true), get_fallback=fn(
      error,
    ) {
      log.push([g6j("fallback"), g6j(error)])
      g6_backend(log)
    })
    renderer.init(on_done=fn(_) {
      log.push([
        g6j("init"),
        g6j(renderer.initialized()),
        g6j(renderer.backend.has_flag("isWebGPUBackend")),
        g6j(0),
      ])
      let failing = @nodes.Renderer::new(g6_backend(log, fail_init=true))
      let failed = Ref("")
      failing.init(on_done=fn(e) {
        failed.val = e.unwrap()
        failing.init(on_done=fn(e) {
          failed.val = failed.val + "|" + e.unwrap()
          log.push([g6j("failed"), g6j(failed.val), g6j(failing.initialized())])
          // RendererUtils
          renderer.set_clear_color_hex(0x00ff00, alpha=0.5)
          renderer.auto_clear_color = false
          renderer.tone_mapping = @core.CineonToneMapping
          let rt = @core.RenderTarget::new(width=4, height=4)
          renderer.set_render_target(
            Some(rt),
            active_cube_face=2,
            active_mipmap_level=1,
          )
          let scene = @core.Scene::new()
          let s = scene.as_scene()
          s.background = Some(Color(@math.Color::new(1.0, 0.0, 0.0)))
          s.override_material = Some(g6_node_material("ov"))
          let state = @nodes.reset_renderer_and_scene_state(renderer, scene)
          let c = renderer.get_clear_color(@math.Color::new(1.0, 1.0, 1.0))
          let bg_r = match state.background {
            Some(Color(c)) => g6j(c.r)
            _ => g6_null()
          }
          log.push([
            g6j("reset"),
            g6j([
              g6j(state.tone_mapping),
              g6j(state.active_cube_face),
              g6j(state.active_mipmap_level),
              g6j(state.pixel_ratio),
              g6j(state.clear_color.unwrap().r),
              g6j(state.clear_color.unwrap().g),
              g6j(state.clear_alpha),
              g6j(state.auto_clear_color),
              g6j(state.scissor_test),
              g6j(state.render_target is Some(t) && physical_equal(t, rt)),
              bg_r,
              g6j(state.override_material.unwrap().name),
            ]),
            g6j([
              g6j(c.r),
              g6j(c.g),
              g6j(renderer.get_clear_alpha()),
              g6j(renderer.auto_clear_color),
              g6_opt(s.background, fn(_) { g6j("bg") }),
              g6_opt(s.override_material, fn(_) { g6j("ov") }),
            ]),
          ])
          renderer.set_render_target(None)
          renderer.tone_mapping = @core.NoToneMapping
          @nodes.restore_renderer_and_scene_state(renderer, scene, state)
          log.push([
            g6j("restored"),
            g6j(renderer.tone_mapping),
            g6j(
              renderer.get_render_target() is Some(t) && physical_equal(t, rt),
            ),
            g6j(renderer.get_active_cube_face()),
            g6j(renderer.get_active_mipmap_level()),
            g6j(renderer.get_clear_alpha()),
            g6j(renderer.auto_clear_color),
            match s.background {
              Some(Color(c)) => g6j(c.r)
              _ => g6_null()
            },
            g6j(s.override_material.unwrap().name),
          ])
          let saved = @nodes.save_renderer_state(renderer)
          @nodes.restore_renderer_state(renderer, saved)
          @nodes.restore_scene_state(scene, @nodes.reset_scene_state(scene))
          renderer.set_render_target(None)
          s.override_material = None
          renderer.tone_mapping = @core.NoToneMapping
          renderer.auto_clear_color = true
          // high precision
          log.push([g6j("highPrecision"), g6j(renderer.high_precision())])
          renderer.set_high_precision(true)
          log.push([g6j("highPrecision"), g6j(renderer.high_precision())])
          renderer.set_high_precision(false)
          log.push([g6j("highPrecision"), g6j(renderer.high_precision())])
          // canvas targets
          let canvas2 = g6_canvas(40, 20)
          let target = @nodes.CanvasTarget::new(canvas2)
          renderer.set_canvas_target(target)
          renderer.set_size(10.0, 5.0)
          renderer.set_pixel_ratio(2.0)
          log.push([
            g6j("canvasTarget"),
            g6j(physical_equal(renderer.get_canvas_target(), target)),
            g6_get(canvas2, "width"),
            g6_get(canvas2, "height"),
            g6_get(g6_get(canvas2, "style"), "width"),
          ])
          renderer.output_color_space = @core.LinearSRGBColorSpace
          let camera = @core.PerspectiveCamera::new()
          camera.position.z = 3.0
          let a = g6_mesh("a", g6_node_material("aMat"))
          scene.add(a) |> ignore
          renderer.render(scene, camera)
          target.dispose()
          // shader of an object
          renderer.debug_get_shader_async(scene, camera, a, fn(fs, vs) {
            log.push([g6j("shaders"), g6_opt(vs, g6j), g6_opt(fs, g6j)])
            // a shadow pass material
            let shadow_scene = @core.Scene::new()
            let sources = [
              g6_node_material("plain"),
              g6_material("colored", fn(m) {
                g6_node_slots(m).color_node = Some(
                  @nodes.vec4_of([1, 0, 0, 0.5]),
                )
              }),
              g6_material("mapped", fn(m) {
                m.map = Some(@core.Texture::new())
                m.side = @core.BackSide
              }),
              g6_material("masked", fn(m) {
                g6_node_slots(m).mask_node = Some(@nodes.bool(true))
                m.shadow_side = Some(@core.DoubleSide)
              }),
              g6_material("cast", fn(m) {
                let slots = g6_node_slots(m)
                slots.cast_shadow_node = Some(@nodes.vec4(0.5))
                slots.position_node = Some(@nodes.vec3(1))
                slots.depth_node = Some(@nodes.float(0.5))
              }),
            ]
            for m in sources {
              shadow_scene.add(g6_mesh("shadow_" + m.name, m)) |> ignore
            }
            let shadow_material = g6_material("ShadowMaterial", fn(m) {
              g6_node_slots(m).class_ = G6ShadowPassClass::{ }
            })
            shadow_scene.as_scene().override_material = Some(shadow_material)
            renderer.render(shadow_scene, camera)
            renderer.shadow_map.type_ = @core.VSMShadowMap
            renderer.render(shadow_scene, camera)
            renderer.shadow_map.type_ = @core.PCFSoftShadowMap
            renderer.render(shadow_scene, camera)
            let slots = g6_node_slots(shadow_material)
            log.push(
              [
                g6j("shadow"),
                g6j(renderer.shadow_map.type_),
                g6j(shadow_material.side),
                g6_opt(slots.color_node, fn(_) { g6j("node") }),
                g6_opt(slots.position_node, fn(_) { g6j("node") }),
                ..g6_info(renderer),
              ],
            )
            // reversed depth
            renderer.reversed_depth_buffer = true
            renderer.render(scene, camera)
            log.push([
              g6j("reversed"),
              g6j(camera.reversed_depth()),
              g6j(renderer.get_clear_depth()),
            ])
            done()
          })
        })
      })
    })
  })
}

///|
test "g6diff nodes_render" {
  g6_run("nodes_render", fn(log, done) {
    g6_install_frames(log.array) |> ignore
    g6_align(log)
    let renderer = @nodes.Renderer::new(g6_backend(log))
    renderer.init(on_done=fn(_) {
      renderer.set_size(16.0, 8.0, update_style=false)
      let scene = @core.Scene::new()
      scene.name = "nodesScene"
      let camera = @core.PerspectiveCamera::new()
      camera.position.set(0.0, 1.0, 3.0) |> ignore
      camera.update_matrix_world()
      let material = g6_node_material("floorMat")
      scene.add(g6_mesh("floor", material)) |> ignore
      // PassNode.compileAsync
      let scene_pass = @nodes.pass(scene, camera)
      @nodes.PassNode::compile_async(scene_pass, renderer, on_done=fn() {
        log.push(
          [
            g6j("passCompiled"),
            g6_opt(renderer.get_render_target(), fn(_) { g6j("target") }),
            g6j(@nodes.PassNode::of(scene_pass).unwrap().render_target.width),
            ..g6_info(renderer),
          ],
        )
        let frame = renderer.node_frame()
        frame.renderer = Some(renderer)
        frame.scene = Some(scene)
        frame.camera = Some(camera)
        frame.material = Some(material)
        // rtt
        let r = @nodes.rtt(@nodes.vec4_of([1, 0, 0, 1]))
        r.update_before(frame) |> ignore
        r.update_before(frame) |> ignore
        let rp = @nodes.RTTNode::of(r).unwrap()
        rp.auto_update = false
        r.update_before(frame) |> ignore
        let fixed = @nodes.rtt(
          @nodes.vec4(0.5),
          width=4.0,
          height=2.0,
          resolution_scale=0.5,
        )
        fixed.update_before(frame) |> ignore
        let fp = @nodes.RTTNode::of(fixed).unwrap()
        let value = @nodes.TextureNode::get_value_opt(r).unwrap()
        let cloned = @nodes.TextureNode::clone(r)
        log.push([
          g6j("rtt"),
          g6j(r.has_flag("isRTTNode")),
          g6j(rp.auto_resize()),
          g6j(rp.render_target.width),
          g6j(rp.render_target.height),
          g6j(fp.render_target.width),
          g6j(fp.render_target.height),
          g6j(physical_equal(value, rp.render_target.texture())),
          g6j(
            @nodes.TextureNode::of(cloned).unwrap().reference_node is Some(n) &&
            physical_equal(n, r),
          ),
        ])
        let t = @nodes.texture(@core.Texture::new())
        log.push([
          g6j("convert"),
          g6j(physical_equal(@nodes.convert_to_texture(t), t)),
          g6j(@nodes.convert_to_texture(scene_pass).has_flag("isTextureNode")),
          g6j(@nodes.convert_to_texture(@nodes.vec4(1)).has_flag("isRTTNode")),
        ])
        // reflector
        let reflection = @nodes.reflector(resolution_scale=0.5)
        let target = @nodes.ReflectorNode::target(reflection)
        target.rotation.set_x(-3.141592653589793 / 2.0)
        target.update_matrix_world()
        let base = @nodes.ReflectorNode::reflector(reflection)
        let bp = @nodes.ReflectorBaseNode::of(base).unwrap()
        base.update_before(frame) |> ignore
        log.push([
          g6j("reflector"),
          g6j(bp.render_targets.length()),
          g6j(@nodes.TextureNode::get_value_opt(reflection).unwrap().id),
          g6j(scene.name),
          g6j(material.visible),
          g6j(bp.has_output),
        ])
        camera.position.set(0.0, -1.0, 3.0) |> ignore
        camera.update_matrix_world()
        base.update_before(frame) |> ignore
        bp.force_update = true
        base.update_before(frame) |> ignore
        log.push([g6j("reflector2"), g6j(bp.has_output), ..g6_info(renderer)])
        done()
      })
    })
  })
}
