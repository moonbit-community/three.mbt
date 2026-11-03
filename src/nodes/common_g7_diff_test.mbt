// MoonBit side of the G7 differential harness (renderer data classes). Each test
// `g7diff <name>` mirrors the upstream scenario of the same name in
// diff/core/g7/harness/scenarios.mjs step by step and, with G7_DIFF=1, prints its log as
// `@@G7 <name> <json>`; `node run.mjs` runs each scenario in a fresh process on both
// sides and compares the logs entry by entry. Without G7_DIFF the tests do nothing (each
// scenario advances the global id counters, which only a fresh process allows).

///|
extern "js" fn g7_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.G7_DIFF === '1'"

///|
extern "js" fn g7_print(name : String, log : @core.JsValue) -> Unit = "(n, l) => { console.log('@@G7 ' + n + ' ' + JSON.stringify(l)); }"

///|
extern "js" fn g7_new_array() -> @core.JsValue = "() => []"

///|
extern "js" fn g7_push(array : @core.JsValue, value : @core.JsValue) -> Unit = "(a, v) => { a.push(v); }"

///|
extern "js" fn g7_bytes(typed : @core.TypedArray) -> @core.JsValue = "(t) => Array.from(new Uint8Array(t.buffer, t.byteOffset, t.byteLength))"

///|
extern "js" fn g7_typed_values(typed : @core.TypedArray) -> @core.JsValue = "(t) => Array.from(t)"

///|
extern "js" fn g7_mock_create() -> @core.JsValue =
  #|() => {
  #|  const { createRequire } = process.getBuiltinModule( 'module' );
  #|  const require = createRequire( process.env.G7_MOCK_GPU );
  #|  const { createMockGPU } = require( process.env.G7_MOCK_GPU );
  #|  const mock = createMockGPU( {} );
  #|  let device;
  #|  mock.gpu.requestAdapter().then( ( a ) => a.requestDevice() ).then( ( d ) => { device = d; } );
  #|  return { mock, device };
  #|}

///|
extern "js" fn g7_create_buffer(
  gpu : @core.JsValue,
  label : String,
  size : Int32,
  usage : Int32,
) -> @core.JsValue = "(g, label, size, usage) => g.device.createBuffer( { label, size, usage } )"

///|
extern "js" fn g7_write_buffer(
  gpu : @core.JsValue,
  buffer : @core.JsValue,
  typed : @core.TypedArray,
) -> Unit = "(g, b, t) => { g.device.queue.writeBuffer( b, 0, new Uint8Array( t.buffer, t.byteOffset, t.byteLength ) ); }"

///|
extern "js" fn g7_destroy_buffer(buffer : @core.JsValue) -> Unit = "(b) => { b.destroy(); }"

///|
extern "js" fn g7_mock_log(gpu : @core.JsValue) -> @core.JsValue = "(g) => g.mock.log"

// ---- log values

///|
fn[T] g7j(v : T) -> @core.JsValue {
  @core.JsValue::of(v)
}

///|
fn g7_opt_int(v : Int32?) -> @core.JsValue {
  match v {
    Some(x) => g7j(x)
    None => @core.JsValue::null()
  }
}

///|
fn g7_opt_double(v : Double?) -> @core.JsValue {
  match v {
    Some(x) => g7j(x)
    None => @core.JsValue::null()
  }
}

///|
fn g7_opt_string(v : String?) -> @core.JsValue {
  match v {
    Some(x) => g7j(x)
    None => @core.JsValue::null()
  }
}

///|
struct G7Log {
  array : @core.JsValue
}

///|
fn G7Log::new() -> G7Log {
  { array: g7_new_array(), }
}

///|
fn G7Log::push(self : G7Log, entry : Array[@core.JsValue]) -> Unit {
  g7_push(self.array, g7j(entry))
}

///|
fn g7_run(name : String, f : (G7Log) -> Unit) -> Unit {
  if !g7_enabled() {
    return
  }
  let log = G7Log::new()
  f(log)
  g7_print(name, log.array)
}

// ---- counters (see TARGETS in common.mjs)

///|
fn g7_align(log : G7Log) -> Unit {
  // the stand-in renderer allocates a canvas target and XR cameras; build it before
  // the counters are aligned, as upstream's stub renderer is a plain object
  g7_prebuilt_renderer.val = Some(@nodes.Renderer::foundation_stub())
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
  log.push([g7j("aligned")])
}

// ---- stub backend: the same calls and mock-device traffic as StubBackend in common.mjs

///|
struct G7StubBackend {
  log : G7Log
  gpu : @core.JsValue
  mut needs_update_flag : Bool
}

///|
let g7_usage_copy_dst : Int32 = 8

///|
fn G7StubBackend::create_buffer(
  self : G7StubBackend,
  backend : @nodes.Backend,
  kind : String,
  attribute : @nodes.AttributeBuffer,
  usage : Int32,
) -> Unit {
  let array = attribute.array().unwrap()
  let byte_length = array.byte_length()
  let size = byte_length + (4 - byte_length % 4) % 4
  let name = match attribute {
    Buffer(a) => a.name
    _ => ""
  }
  self.log.push([
    g7j("backend"),
    g7j(kind),
    g7j(name),
    g7j(array.type_name()),
    g7j(array.length()),
    g7j(attribute.version()),
  ])
  let buffer = g7_create_buffer(self.gpu, name, size, usage | g7_usage_copy_dst)
  g7_write_buffer(self.gpu, buffer, array)
  backend.get(attribute.key()).set("buffer", buffer)
}

///|
fn g7_binding_ranges(b : @nodes.Binding) -> @core.JsValue {
  g7j(b.update_ranges().map(fn(r) { g7j([g7j(r.start), g7j(r.count)]) }))
}

///|
fn g7_texture_options(o : @nodes.TextureOptions) -> @core.JsValue {
  g7j([
    g7_opt_int(o.sample_count),
    g7j(o.width),
    g7j(o.height),
    g7j(o.depth),
    g7j(o.needs_mipmaps),
    g7j(o.levels),
    g7j(o.image is Some(_)),
    match o.images {
      Some(i) => g7j(i.length())
      None => @core.JsValue::null()
    },
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn class_name(_) {
  "StubBackend"
}

///|
impl @nodes.BackendClass for G7StubBackend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_attribute(self, b, a) {
  self.create_buffer(b, "createAttribute", a, 32)
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_index_attribute(
  self,
  b,
  a,
) {
  self.create_buffer(b, "createIndexAttribute", a, 16)
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_storage_attribute(
  self,
  b,
  a,
) {
  self.create_buffer(b, "createStorageAttribute", a, 128 | 32)
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_indirect_storage_attribute(
  self,
  b,
  a,
) {
  self.create_buffer(b, "createIndirectStorageAttribute", a, 128 | 256)
}

///|
impl @nodes.BackendClass for G7StubBackend with fn update_attribute(self, b, a) {
  let name = match a {
    Buffer(x) => x.name
    _ => ""
  }
  self.log.push([
    g7j("backend"),
    g7j("updateAttribute"),
    g7j(name),
    g7j(a.version()),
  ])
  g7_write_buffer(self.gpu, b.get(a.key()).get("buffer"), a.array().unwrap())
}

///|
impl @nodes.BackendClass for G7StubBackend with fn destroy_attribute(self, b, a) {
  let name = match a {
    Buffer(x) => x.name
    _ => ""
  }
  self.log.push([g7j("backend"), g7j("destroyAttribute"), g7j(name)])
  g7_destroy_buffer(b.get(a.key()).get("buffer"))
  b.delete(a.key())
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_uniform_buffer(
  self,
  backend,
  b,
) {
  self.log.push([
    g7j("backend"),
    g7j("createUniformBuffer"),
    g7j(b.name),
    g7j(b.byte_length()),
  ])
  backend
  .get(g7j(b))
  .set("buffer", g7_create_buffer(self.gpu, b.name, b.byte_length(), 64 | 8))
}

///|
impl @nodes.BackendClass for G7StubBackend with fn update_binding(
  self,
  backend,
  b,
) {
  self.log.push([
    g7j("backend"),
    g7j("updateBinding"),
    g7j(b.name),
    g7_binding_ranges(b),
  ])
  g7_write_buffer(
    self.gpu,
    backend.get(g7j(b)).get("buffer"),
    b.buffer().unwrap(),
  )
}

///|
impl @nodes.BackendClass for G7StubBackend with fn destroy_uniform_buffer(
  self,
  backend,
  b,
) {
  self.log.push([g7j("backend"), g7j("destroyUniformBuffer"), g7j(b.name)])
  g7_destroy_buffer(backend.get(g7j(b)).get("buffer"))
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_bindings(
  self,
  _,
  bind_group,
  bindings,
  cache_index,
) {
  self.log.push([
    g7j("backend"),
    g7j("createBindings"),
    g7j(bind_group.name),
    g7j(bind_group.id),
    g7j(bind_group.bindings.map(fn(b) { g7j(b.name) })),
    g7j(bindings.length()),
    g7j(cache_index),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn update_bindings(
  self,
  _,
  bind_group,
  _,
  cache_key,
  version,
) {
  self.log.push([
    g7j("backend"),
    g7j("updateBindings"),
    g7j(bind_group.name),
    g7j(bind_group.id),
    g7j(cache_key),
    g7j(version),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn delete_bind_group_data(
  self,
  _,
  bind_group,
) {
  self.log.push([
    g7j("backend"),
    g7j("deleteBindGroupData"),
    g7j(bind_group.name),
    g7j(bind_group.id),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn update_sampler(self, _, b) {
  let t = b.texture().unwrap()
  let key = "\{t.min_filter}-\{t.mag_filter}-\{t.wrap_s}"
  self.log.push([g7j("backend"), g7j("updateSampler"), g7j(b.name), g7j(key)])
  key
}

///|
impl @nodes.BackendClass for G7StubBackend with fn destroy_sampler(self, _, b) {
  self.log.push([g7j("backend"), g7j("destroySampler"), g7j(b.name)])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_default_texture(
  self,
  _,
  t,
) {
  self.log.push([g7j("backend"), g7j("createDefaultTexture"), g7j(t.id)])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_texture(self, _, t, o) {
  self.log.push([
    g7j("backend"),
    g7j("createTexture"),
    g7j(t.id),
    g7_texture_options(o),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn update_texture(self, _, t, o) {
  self.log.push([
    g7j("backend"),
    g7j("updateTexture"),
    g7j(t.id),
    g7_texture_options(o),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn generate_mipmaps(self, _, t) {
  self.log.push([g7j("backend"), g7j("generateMipmaps"), g7j(t.id)])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn destroy_texture(
  self,
  _,
  t,
  is_default,
) {
  self.log.push([
    g7j("backend"),
    g7j("destroyTexture"),
    g7j(t.id),
    match is_default {
      Some(x) => g7j(x)
      None => @core.JsValue::null()
    },
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_program(self, _, p) {
  self.log.push([
    g7j("backend"),
    g7j("createProgram"),
    g7j(p.id),
    g7j(p.stage),
    g7j(p.name),
    g7j(p.code),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn destroy_program(self, _, p) {
  self.log.push([g7j("backend"), g7j("destroyProgram"), g7j(p.id), g7j(p.stage)])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_render_pipeline(
  self,
  backend,
  render_object,
  _,
) {
  let pipeline = render_object.pipeline.unwrap()
  self.log.push([
    g7j("backend"),
    g7j("createRenderPipeline"),
    g7j(render_object.id),
    g7j(pipeline.cache_key),
  ])
  backend.get(g7j(pipeline)).set("pipeline", @core.JsValue::object())
}

///|
impl @nodes.BackendClass for G7StubBackend with fn create_compute_pipeline(
  self,
  _,
  pipeline,
  bindings,
  _,
) {
  self.log.push([
    g7j("backend"),
    g7j("createComputePipeline"),
    g7j(pipeline.cache_key),
    g7j(bindings.length()),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn destroy_pipeline(
  self,
  _,
  pipeline,
) {
  self.log.push([
    g7j("backend"),
    g7j("destroyPipeline"),
    g7j(pipeline.cache_key),
  ])
}

///|
impl @nodes.BackendClass for G7StubBackend with fn needs_render_update(
  self,
  _,
  render_object,
) {
  self.log.push([
    g7j("backend"),
    g7j("needsRenderUpdate"),
    g7j(render_object.id),
  ])
  self.needs_update_flag
}

///|
impl @nodes.BackendClass for G7StubBackend with fn get_render_cache_key(
  _,
  _,
  render_object,
) {
  "s" + render_object.material.side.to_string()
}

///|
impl @nodes.BackendClass for G7StubBackend with fn delete_vertex_state(
  self,
  _,
  render_object,
) {
  self.log.push([
    g7j("backend"),
    g7j("deleteVertexState"),
    g7j(render_object.id),
  ])
}

///|
/// The stub backend, as `createStubBackend( log )`.
fn g7_stub_backend(log : G7Log) -> (@nodes.Backend, G7StubBackend) {
  let stub = { log, gpu: g7_mock_create(), needs_update_flag: false, }
  let backend = @nodes.Backend::new(stub)
  (backend, stub)
}

///|
let g7_prebuilt_renderer : Ref[@nodes.Renderer?] = Ref(None)

///|
/// The stub renderer, as `createStubRenderer( backend )`.
fn g7_stub_renderer(backend : @nodes.Backend) -> @nodes.Renderer {
  let renderer = match g7_prebuilt_renderer.val {
    Some(r) => {
      g7_prebuilt_renderer.val = None
      // upstream's stub creates `contextNode: context()` here
      r.context_node = @nodes.context()
      r
    }
    None => @nodes.Renderer::foundation_stub()
  }
  renderer.backend = backend
  backend.renderer = Some(renderer)
  renderer
}

///|
struct G7Modules {
  info : @nodes.Info
  nodes : @nodes.NodeManager
  attributes : @nodes.Attributes
  textures : @nodes.Textures
  geometries : @nodes.Geometries
  pipelines : @nodes.Pipelines
  bindings : @nodes.Bindings
  render_objects : @nodes.RenderObjects
  render_contexts : @nodes.RenderContexts
}

///|
fn g7_modules(renderer : @nodes.Renderer) -> G7Modules {
  let backend = renderer.backend
  let info = renderer.info
  let nodes = @nodes.NodeManager::new(renderer, backend)
  let attributes = @nodes.Attributes::new(backend, info)
  let textures = @nodes.Textures::new(renderer, backend, info)
  let geometries = @nodes.Geometries::new(backend, attributes, info)
  let pipelines = @nodes.Pipelines::new(backend, nodes, info)
  let bindings = @nodes.Bindings::new(
    backend, nodes, textures, attributes, pipelines, info,
  )
  renderer._bindings = Some(bindings)
  let render_objects = @nodes.RenderObjects::new(
    renderer, nodes, geometries, pipelines, bindings, info,
  )
  let render_contexts = @nodes.RenderContexts::new(renderer)
  {
    info,
    nodes,
    attributes,
    textures,
    geometries,
    pipelines,
    bindings,
    render_objects,
    render_contexts,
  }
}

///|
fn g7_info_memory(info : @nodes.Info) -> @core.JsValue {
  let m = info.memory
  g7j([
    g7j(m.attributes),
    g7j(m.attributes_size),
    g7j(m.geometries),
    g7j(m.index_attributes),
    g7j(m.index_attributes_size),
    g7j(m.indirect_storage_attributes),
    g7j(m.indirect_storage_attributes_size),
    g7j(m.programs),
    g7j(m.programs_size),
    g7j(m.readback_buffers),
    g7j(m.readback_buffers_size),
    g7j(m.render_targets),
    g7j(m.storage_attributes),
    g7j(m.storage_attributes_size),
    g7j(m.textures),
    g7j(m.textures_size),
    g7j(m.uniform_buffers),
    g7j(m.uniform_buffers_size),
    g7j(m.total),
  ])
}

// ---- fixtures (mirror the helpers of scenarios.mjs)

///|
fn g7_node_uniform(
  type_ : String,
  node_uniform : @nodes.NodeUniform,
) -> @nodes.Uniform {
  match type_ {
    "float" | "int" | "uint" | "bool" =>
      @nodes.NumberNodeUniform::new(node_uniform)
    "vec2" | "ivec2" | "uvec2" => @nodes.Vector2NodeUniform::new(node_uniform)
    "vec3" | "ivec3" | "uvec3" => @nodes.Vector3NodeUniform::new(node_uniform)
    "vec4" | "ivec4" | "uvec4" => @nodes.Vector4NodeUniform::new(node_uniform)
    "color" => @nodes.ColorNodeUniform::new(node_uniform)
    "mat2" => @nodes.Matrix2NodeUniform::new(node_uniform)
    "mat3" => @nodes.Matrix3NodeUniform::new(node_uniform)
    "mat4" => @nodes.Matrix4NodeUniform::new(node_uniform)
    _ => abort(type_)
  }
}

///|
fn g7_group_state(group : @nodes.Binding) -> @core.JsValue {
  g7j([
    g7j(group.name),
    g7j(group.byte_length()),
    g7j(
      group
      .uniforms()
      .map(fn(u) {
        g7j([
          g7j(u.name),
          g7j(u.offset),
          g7j(u.index),
          g7j(u.boundary),
          g7j(u.item_size),
        ])
      }),
    ),
  ])
}

///|
fn g7_m3() -> @math.Matrix3 {
  @math.Matrix3::new().set(1, 2, 3, 4, 5, 6, 7, 8, 9)
}

///|
fn g7_m4() -> @math.Matrix4 {
  @math.Matrix4::new().set(
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
  )
}

///|
fn g7_make_group(
  specs : Array[(String, &@nodes.IntoTsl)],
) -> (@nodes.Binding, Array[@nodes.Node]) {
  let group = @nodes.NodeUniformsGroup::new("object", @nodes.object_group)
  let nodes = []
  for i, spec in specs {
    let (type_, value) = spec
    let node = @nodes.uniform(value)
    nodes.push(node)
    group.add_uniform(
      g7_node_uniform(type_, @nodes.NodeUniform::new("u\{i}", type_, node)),
    )
    |> ignore
  }
  (group, nodes)
}

///|
fn g7_mesh_fixture() -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  geometry.set_attribute(
    "position",
    @core.BufferAttribute::new(
      @core.TypedArray::float32([0.0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 1, 0]),
      3,
    ),
  )
  |> ignore
  geometry.set_attribute(
    "normal",
    @core.BufferAttribute::new(
      @core.TypedArray::float32([0.0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
      3,
    ),
  )
  |> ignore
  geometry.set_attribute(
    "uv",
    @core.BufferAttribute::new(
      @core.TypedArray::float32([0.0, 0, 1, 0, 0, 1, 1, 1]),
      2,
    ),
  )
  |> ignore
  geometry.set_index(
    @core.BufferAttribute::new(@core.TypedArray::uint16([0, 1, 2, 2, 1, 3]), 1),
  )
  |> ignore
  geometry
}

///|
fn g7_node_material() -> @core.Material {
  let material = @nodes.NodeMaterial::new()
  material.custom_program_cache_key = Some(fn() { "custom" })
  material
}

///|
fn g7_state_fixture(
  node_attributes~ : Array[@nodes.NodeAttribute] = [],
  bindings~ : Array[@nodes.BindGroup] = [],
  vs~ : String = "vs",
  fs~ : String = "fs",
) -> @nodes.NodeBuilderState {
  @nodes.NodeBuilderState::new(
    Some(vs),
    Some(fs),
    None,
    node_attributes,
    bindings,
    [],
    [],
    [],
    None,
    false,
  )
}

///|
fn g7_set_mesh_geometry(
  mesh : @core.Object3D,
  geometry : @core.BufferGeometry,
) -> Unit {
  match mesh.kind {
    Mesh(m) => m.geometry = geometry
    _ => abort("not a mesh")
  }
}

///|
fn g7_mesh_geometry(mesh : @core.Object3D) -> @core.BufferGeometry {
  mesh.get_geometry().unwrap()
}

// ---- scenarios

///|
test "g7diff buffer_utils_chain_map" {
  g7_run("buffer_utils_chain_map", fn(log) {
    g7_align(log)
    log.push([
      g7j("floatLength"),
      g7j(
        [0, 1, 4, 15, 16, 17, 33].map(fn(x) { g7j(@nodes.get_float_length(x)) }),
      ),
    ])
    log.push([
      g7j("vectorLength"),
      g7j(
        [(1, 4), (2, 3), (3, 2), (5, 1)].map(fn(p) {
          g7j(@nodes.get_vector_length(p.0, vector_length=p.1))
        }),
      ),
      g7j(@nodes.get_vector_length(3)),
    ])
    log.push([
      g7j("strideLength"),
      g7j([1, 2, 3, 4, 5, 7, 8].map(fn(x) { g7j(@nodes.get_stride_length(x)) })),
    ])
    let map : @nodes.ChainMap[String] = @nodes.ChainMap::new()
    let a = @core.JsValue::object()
    let b = @core.JsValue::object()
    let c = @core.JsValue::object()
    map.set([a, b], "ab") |> ignore
    map.set([a], "a") |> ignore
    map.set([a, b, c], "abc") |> ignore
    let g = fn(k : Array[@core.JsValue]) { g7_opt_string(map.get(k)) }
    log.push([
      g7j("get"),
      g([a, b]),
      g([a]),
      g([a, b, c]),
      g([b, a]),
      g([a, c]),
      g([c]),
    ])
    log.push([
      g7j("delete"),
      g7j(map.delete([a, b])),
      g7j(map.delete([a, b])),
      g7j(map.delete([c, b])),
      g([a, b]),
      g([a, b, c]),
    ])
    map.set([a, b], "ab2") |> ignore
    log.push([g7j("reset"), g([a, b])])
    let dm : @nodes.DataMap[@core.JsValue, G7Record] = @nodes.DataMap::new(fn() {
      { x: None, }
    })
    let r1 = dm.get(a)
    r1.x = Some(1)
    let e1 = dm.has(a)
    let e2 = dm.has(b)
    let e3 = physical_equal(dm.get(a), r1)
    let e4 = g7_opt_int(dm.get(a).x)
    let e5 = dm.delete(b) is None
    let e6 = dm.delete(a) is Some(r) && physical_equal(r, r1)
    let e7 = dm.has(a)
    let e8 = dm.get(a).x is None
    log.push([
      g7j("dm"),
      g7j(e1),
      g7j(e2),
      g7j(e3),
      e4,
      g7j(e5),
      g7j(e6),
      g7j(e7),
      g7j(e8),
    ])
    dm.get(c) |> ignore
    dm.dispose()
    log.push([g7j("dm dispose"), g7j(dm.has(c)), g7j(dm.has(a))])
  })
}

///|
struct G7Record {
  mut x : Int32?
}

///|
fn g7_layout_orders() -> Array[Array[(String, &@nodes.IntoTsl)]] {
  [
    [
      ("float", 1.5),
      ("vec2", @math.Vector2::new(1, 2)),
      ("vec3", @math.Vector3::new(3, 4, 5)),
      ("color", @math.Color::new(0.1, 0.2, 0.3)),
      ("vec4", @math.Vector4::new(6, 7, 8, 9)),
      ("mat3", g7_m3()),
      ("float", 2.0),
      ("mat4", g7_m4()),
      ("vec2", @math.Vector2::new(10, 11)),
    ],
    [
      ("vec3", @math.Vector3::new(1, 2, 3)),
      ("float", 4.0),
      ("float", 5.0),
      ("vec2", @math.Vector2::new(6, 7)),
      ("float", 8.0),
      ("vec3", @math.Vector3::new(9, 10, 11)),
      ("mat3", g7_m3()),
      ("vec2", @math.Vector2::new(12, 13)),
      ("vec2", @math.Vector2::new(14, 15)),
      ("float", 16.0),
      ("mat4", g7_m4()),
      ("color", @math.Color::new(0.5, 0.25, 0.125)),
    ],
    [
      ("float", 1.0),
      ("float", 2.0),
      ("float", 3.0),
      ("vec3", @math.Vector3::new(4, 5, 6)),
      ("float", 7.0),
      ("vec4", @math.Vector4::new(8, 9, 10, 11)),
      ("vec2", @math.Vector2::new(12, 13)),
      ("float", 14.0),
      ("vec3", @math.Vector3::new(15, 16, 17)),
    ],
    [],
  ]
}

///|
test "g7diff uniforms_layout" {
  g7_run("uniforms_layout", fn(log) {
    g7_align(log)
    for specs in g7_layout_orders() {
      let (group, nodes) = g7_make_group(specs)
      log.push([
        g7j("layout"),
        g7_group_state(group),
        g7j(group.has_flag("isUniformsGroup")),
        g7j(group.has_flag("isUniformBuffer")),
        g7j(group.has_flag("isBuffer")),
        g7j(group.has_flag("isNodeUniformsGroup")),
      ])
      log.push([
        g7j("update"),
        g7j(group.update()),
        g7_bytes(group.buffer().unwrap()),
        g7_binding_ranges(group),
      ])
      group.clear_update_ranges()
      log.push([
        g7j("update again"),
        g7j(group.update()),
        g7_binding_ranges(group),
      ])
      if nodes.length() > 2 {
        let mut v3 = -1
        let mut f1 = -1
        for i, s in specs {
          if s.0 == "vec3" && v3 < 0 {
            v3 = i
          }
          if s.0 == "float" && f1 < 0 {
            f1 = i
          }
        }
        @nodes.InputNode::set_value(nodes[f1], Number(42))
        match @nodes.InputNode::get_value(nodes[v3]) {
          Vector3(v) => v.set(-1, -2, -3) |> ignore
          _ => abort("vec3")
        }
        log.push([
          g7j("update changed"),
          g7j(group.update()),
          g7_bytes(group.buffer().unwrap()),
          g7_binding_ranges(group),
        ])
        match @nodes.InputNode::get_value(nodes[v3]) {
          Vector3(v) => v.set(-1, -2, -4) |> ignore
          _ => abort("vec3")
        }
        log.push([
          g7j("update changed2"),
          g7j(group.update()),
          g7_binding_ranges(group),
        ])
        group.clear_update_ranges()
      }
      let clone = group.clone()
      let clone_id = @nodes.NodeUniformsGroup::of(clone).unwrap().id
      let group_id = @nodes.NodeUniformsGroup::of(group).unwrap().id
      let same_uniforms = physical_equal(clone.uniforms(), group.uniforms())
      let clone_byte_length = clone.byte_length()
      let clone_updated = clone.update()
      log.push([
        g7j("clone"),
        g7j(clone.name),
        g7j(clone_id),
        g7j(group_id),
        g7j(same_uniforms),
        g7j(clone_byte_length),
        g7j(clone_updated),
        g7_binding_ranges(clone),
        g7_binding_ranges(group),
      ])
      group.release()
      log.push([g7j("release"), g7_bytes(group.buffer().unwrap())])
    }
  })
}

///|
test "g7diff uniforms_types" {
  g7_run("uniforms_types", fn(log) {
    g7_align(log)
    let (group, nodes) = g7_make_group([
      ("int", -3.7),
      ("uint", -1.0),
      ("bool", true),
      ("float", 0.0 / 0.0),
      ("bool", false),
      ("int", 2147483648.0),
      ("ivec3", @math.Vector3::new(1.5, -2.5, 3.9)),
      ("uvec2", @math.Vector2::new(-1, 7.5)),
      ("ivec4", @math.Vector4::new(-0.0, 1, 2, 3)),
      ("float", -0.0),
      ("uint", 4294967296.0),
      ("vec2", @math.Vector2::new(1.0e-40, 3.4e39)),
    ])
    log.push([g7j("layout"), g7_group_state(group)])
    log.push([
      g7j("update"),
      g7j(group.update()),
      g7_bytes(group.buffer().unwrap()),
      g7_binding_ranges(group),
    ])
    group.clear_update_ranges()
    log.push([g7j("again"), g7j(group.update()), g7_binding_ranges(group)])
    group.clear_update_ranges()
    @nodes.InputNode::set_value(nodes[2], Bool(false))
    @nodes.InputNode::set_value(nodes[4], Number(0))
    @nodes.InputNode::set_value(nodes[9], Number(0))
    log.push([
      g7j("changed"),
      g7j(group.update()),
      g7_bytes(group.buffer().unwrap()),
      g7_binding_ranges(group),
    ])
    let (m2, _) = g7_make_group([("mat2", @math.Matrix2::new()), ("float", 1.0)])
    log.push([
      g7j("mat2"),
      g7_group_state(m2),
      g7j(m2.update()),
      g7_bytes(m2.buffer().unwrap()),
    ])
  })
}

///|
fn g7_describe(groups : Array[@nodes.BindGroup]) -> @core.JsValue {
  g7j(
    groups.map(fn(g) {
      g7j([
        g7j(g.name),
        g7j(g.id),
        g7j(
          g.bindings.map(fn(x) {
            let id = match @nodes.NodeUniformsGroup::of(x) {
              Some(u) => g7j(u.id)
              None =>
                match @nodes.SampledTexture::of(x) {
                  Some(s) => g7j(s.id)
                  None => @core.JsValue::null()
                }
            }
            g7j([
              g7j(x.name),
              id,
              g7j(x.has_flag("isSampledTexture")),
              g7j(x.visibility),
            ])
          }),
        ),
      ])
    }),
  )
}

///|
test "g7diff bindings" {
  g7_run("bindings", fn(log) {
    g7_align(log)
    let (backend, stub) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let a = @nodes.uniform(1)
    let b = @nodes.uniform(@math.Vector3::new(1, 2, 3))
    let c = @nodes.uniform(2)
    let d = @nodes.uniform(@math.Vector4::new(1, 2, 3, 4))
    let texture = @core.DataTexture::new(
      data=@core.TypedArray::uint8(16),
      width=2,
      height=2,
    )
    let texture_node = @nodes.uniform(texture)
    let object_group = @nodes.object_group
    let render_group = @nodes.render_group
    let obj = @nodes.NodeUniformsGroup::new("object", object_group)
    obj.add_uniform(
      @nodes.NumberNodeUniform::new(@nodes.NodeUniform::new("a", "float", a)),
    )
    |> ignore
    obj.add_uniform(
      @nodes.Vector3NodeUniform::new(@nodes.NodeUniform::new("b", "vec3", b)),
    )
    |> ignore
    let sampler = @nodes.NodeSampler::new(
      "map_sampler",
      Some(texture_node),
      Some(object_group),
    )
    let sampled = @nodes.NodeSampledTexture::new(
      "map",
      Some(texture_node),
      Some(object_group),
    )
    let ren = @nodes.NodeUniformsGroup::new("render", render_group)
    ren.add_uniform(
      @nodes.Vector4NodeUniform::new(@nodes.NodeUniform::new("d", "vec4", d)),
    )
    |> ignore
    ren.add_uniform(
      @nodes.NumberNodeUniform::new(@nodes.NodeUniform::new("c", "float", c)),
    )
    |> ignore
    let obj_group = @nodes.BindGroup::new(name="object", bindings=[
      obj, sampler, sampled,
    ])
    let ren_group = @nodes.BindGroup::new(name="render", bindings=[ren])
    let state = g7_state_fixture(bindings=[obj_group, ren_group])
    let ctx1 = m.render_contexts.get()
    let ctx2 = m.render_contexts.get(call_depth=1)
    let bg1 = state.create_bindings(Some(m.bindings), Some(ctx1))
    log.push([
      g7j("bg1"),
      g7_describe(bg1),
      g7j(physical_equal(bg1[1], ren_group)),
      g7j(ren.uniforms().map(fn(u) { g7j(u.name) })),
    ])
    let bg2 = state.create_bindings(Some(m.bindings), Some(ctx1))
    log.push([
      g7j("bg2"),
      g7_describe(bg2),
      g7j(physical_equal(bg2[1], bg1[1])),
      g7j(physical_equal(bg2[0], bg1[0])),
      g7j(physical_equal(bg2[0].bindings[0], obj)),
    ])
    let bg3 = state.create_bindings(Some(m.bindings), Some(ctx2))
    log.push([
      g7j("bg3"),
      g7_describe(bg3),
      g7j(physical_equal(bg3[1], bg1[1])),
      g7j(physical_equal(bg3[1].bindings[0], ren)),
    ])
    let bg4 = state.create_bindings(Some(m.bindings), None)
    log.push([g7j("bg4"), g7_describe(bg4)])
    m.bindings._create_bindings(bg1)
    m.bindings._create_bindings(bg2)
    log.push([
      g7j("used"),
      g7j(m.bindings.get(bg1[1]).used_times),
      g7j(m.bindings.get(bg1[0]).used_times),
      g7_info_memory(m.info),
    ])
    m.bindings._update_bindings(bg1)
    log.push([g7j("updated1")])
    m.bindings._update_bindings(bg1)
    log.push([g7j("updated2")])
    @nodes.InputNode::set_value(a, Number(5))
    match @nodes.InputNode::get_value(d) {
      Vector4(v) => v.set(9, 8, 7, 6) |> ignore
      _ => abort("vec4")
    }
    texture.set_needs_update(true)
    m.bindings._update_bindings(bg1)
    log.push([g7j("updated3"), g7j(ren.uniforms().map(fn(u) { g7j(u.name) }))])
    render_group.set_needs_update(true)
    m.bindings._update_bindings(bg1)
    m.bindings._update_bindings(bg2)
    log.push([g7j("updated4")])
    let other = @core.DataTexture::new(
      data=@core.TypedArray::uint8(4),
      width=1,
      height=1,
    )
    other.set_needs_update(true)
    @nodes.InputNode::set_value(texture_node, Texture(other))
    m.bindings._update_bindings(bg1)
    log.push([
      g7j("updated5"),
      g7_opt_int(bg1[0].bindings[2].generation()),
      g7j(bg1[0].bindings[1].sampler_key()),
    ])
    texture.dispose()
    m.bindings._destroy_bindings(bg2)
    log.push([
      g7j("destroyed2"),
      g7j(m.bindings.has(bg1[1])),
      g7_info_memory(m.info),
    ])
    m.bindings._destroy_bindings(bg1)
    log.push([
      g7j("destroyed1"),
      g7j(m.bindings.has(bg1[1])),
      g7j(m.bindings.has(bg1[0])),
      g7_info_memory(m.info),
    ])
    let bg5 = state.create_bindings(Some(m.bindings), Some(ctx1))
    log.push([g7j("bg5"), g7_describe(bg5), g7j(physical_equal(bg5[1], bg1[1]))])
    log.push([g7j("gpu"), g7_mock_log(stub.gpu)])
  })
}

///|
extern "js" fn g7_draw_params_object(
  vertex_count : Int32,
  first_vertex : Int32,
  instance_count : Double,
  first_instance : Int32,
) -> @core.JsValue = "(vertexCount, firstVertex, instanceCount, firstInstance) => ({ vertexCount, firstVertex, instanceCount, firstInstance })"

///|
fn g7_draw_params(p : @nodes.DrawParameters?) -> @core.JsValue {
  match p {
    Some(p) =>
      g7_draw_params_object(
        p.vertex_count,
        p.first_vertex,
        p.instance_count,
        p.first_instance,
      )
    None => @core.JsValue::null()
  }
}

///|
fn g7_keys(ro : @nodes.RenderObject) -> @core.JsValue {
  let id = ro.id
  let initial_cache_key = ro.initial_cache_key
  let initial_nodes_cache_key = ro.initial_nodes_cache_key
  let initial_geometry_cache_key = ro.initial_geometry_cache_key
  let material_key = ro.get_material_cache_key()
  let dynamic_key = ro.get_dynamic_cache_key()
  g7j([
    g7j(id),
    g7j(initial_cache_key),
    g7j(initial_nodes_cache_key),
    g7j(initial_geometry_cache_key),
    g7j(material_key),
    g7j(dynamic_key),
    g7j(ro.version),
    g7j(ro.geometry_version),
  ])
}

///|
fn g7_prep(ro : @nodes.RenderObject) -> @nodes.RenderObject {
  if ro._node_builder_state is None {
    ro._node_builder_state = Some(g7_state_fixture())
  }
  ro
}

///|
fn g7_clipping_group(planes : Array[@math.Plane]) -> @core.Object3D {
  let group = @core.ClippingGroup::new()
  match group.kind {
    ClippingGroup(g) => g.clipping_planes = planes
    _ => abort("clipping group")
  }
  group
}

///|
test "g7diff render_objects" {
  g7_run("render_objects", fn(log) {
    g7_align(log)
    let (backend, _) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let scene = @core.Scene::new()
    let camera = @core.PerspectiveCamera::new()
    let geometry = g7_mesh_fixture()
    let material = g7_node_material()
    let mesh = @core.Mesh::new(geometry~, material=Single(material))
    let lights_node = @nodes.Node::alloc()
    let ctx = m.render_contexts.get()
    let get = fn() {
      g7_prep(
        m.render_objects.get(
          mesh,
          material,
          scene,
          camera,
          lights_node,
          ctx,
          None,
        ),
      )
    }
    let ro1 = get()
    log.push([g7j("ro1"), g7_keys(ro1)])
    log.push([g7j("same"), g7j(physical_equal(get(), ro1))])
    material.set_needs_update(true)
    let ro2 = get()
    log.push([g7j("version bump"), g7j(physical_equal(ro2, ro1)), g7_keys(ro2)])
    material.side = @core.DoubleSide
    material.set_needs_update(true)
    let ro3 = get()
    log.push([g7j("side change"), g7j(physical_equal(ro3, ro1)), g7_keys(ro3)])
    let geometry2 = g7_mesh_fixture()
    g7_set_mesh_geometry(mesh, geometry2)
    ro3.get_attributes() |> ignore
    let ro4 = get()
    log.push([
      g7j("geometry swap"),
      g7j(physical_equal(ro4, ro3)),
      g7_keys(ro4),
      g7j(physical_equal(ro4.geometry, geometry2)),
    ])
    let geometry3 = g7_mesh_fixture()
    geometry3.set_attribute(
      "color",
      @core.BufferAttribute::new(
        @core.TypedArray::float32(12),
        3,
        normalized=true,
      ),
    )
    |> ignore
    g7_set_mesh_geometry(mesh, geometry3)
    let ro5 = get()
    log.push([
      g7j("geometry layout"),
      g7j(physical_equal(ro5, ro4)),
      g7_keys(ro5),
    ])
    mesh.receive_shadow = true
    let ro6 = get()
    log.push([
      g7j("receive shadow"),
      g7j(physical_equal(ro6, ro5)),
      g7_keys(ro6),
    ])
    material.transparent = true
    material.depth_write = false
    material.blending = @core.AdditiveBlending
    @nodes.NodeMaterial::of(material).unwrap().color_node = Some(
      @nodes.uniform(1),
    )
    material.set_needs_update(true)
    let ro7 = get()
    log.push([
      g7j("material props"),
      g7j(physical_equal(ro7, ro6)),
      g7_keys(ro7),
    ])
    let map = @core.Texture::new()
    map.wrap_s = @core.RepeatWrapping
    map.channel = 2
    material.map = Some(map)
    material.set_needs_update(true)
    let ro8 = get()
    log.push([g7j("texture prop"), g7j(physical_equal(ro8, ro7)), g7_keys(ro8)])
    ro8.draw_range = Some(g7_mesh_geometry(mesh).draw_range)
    let p = g7_draw_params(ro8.get_draw_parameters())
    log.push([g7j("draw"), p, g7j(ro8.get_index().unwrap().count())])
    g7_mesh_geometry(mesh).set_draw_range(1, 3.0)
    ro8.group = Some({ start: 2, count: 10.0, material_index: 0, })
    log.push([g7j("draw range"), g7_draw_params(ro8.get_draw_parameters())])
    material.wireframe = Some(true)
    ro8.group = None
    log.push([g7j("draw wireframe"), g7_draw_params(ro8.get_draw_parameters())])
    material.wireframe = Some(false)
    let chain = ro8.get_chain_array().length()
    let needs_update = ro8.needs_update()
    let clipping_needs_update = ro8.clipping_needs_update()
    log.push([
      g7j("chain"),
      g7j(chain),
      g7j(needs_update),
      g7j(clipping_needs_update),
    ])
    let clip = @nodes.ClippingContext::new()
    let ro9 = g7_prep(
      m.render_objects.get(
        mesh,
        material,
        scene,
        camera,
        lights_node,
        ctx,
        Some(clip),
      ),
    )
    let clip_update = ro9.clipping_needs_update()
    log.push([
      g7j("clip same"),
      g7j(physical_equal(ro9, ro8)),
      g7j(clip_update),
      g7j(ro9.clipping_context_cache_key),
    ])
    let group = g7_clipping_group([
      @math.Plane::new(normal=@math.Vector3::new(0, 1, 0), constant=1),
    ])
    let group_context = clip.get_group_context(group)
    let ro10 = g7_prep(
      m.render_objects.get(
        mesh,
        material,
        scene,
        camera,
        lights_node,
        ctx,
        Some(group_context),
      ),
    )
    log.push([
      g7j("clip group"),
      g7j(physical_equal(ro10, ro9)),
      g7_keys(ro10),
      g7j(ro10.clipping_context_cache_key),
    ])
    let ro11 = g7_prep(
      m.render_objects.get(
        mesh,
        material,
        scene,
        camera,
        lights_node,
        ctx,
        Some(group_context),
        pass_id="shadow",
      ),
    )
    log.push([g7j("pass"), g7j(physical_equal(ro11, ro10)), g7j(ro11.id)])
    material.dispose()
    log.push([g7j("material dispose"), g7j(physical_equal(get(), ro10))])
    m.render_objects.dispose()
    log.push([g7j("disposed"), g7_info_memory(m.info)])
  })
}

///|
fn g7_items(
  items : Array[@nodes.RenderItem],
  first : @core.Object3D,
) -> @core.JsValue {
  g7j(
    items.map(fn(it) {
      g7j([
        g7j(it.id.unwrap() - first.id),
        g7_opt_int(it.group_order),
        g7_opt_double(it.render_order),
        g7_opt_double(it.z),
        match it.group {
          Some(g) => g7j(g.start)
          None => @core.JsValue::null()
        },
      ])
    }),
  )
}

///|
test "g7diff render_list" {
  g7_run("render_list", fn(log) {
    g7_align(log)
    let scene = @core.Scene::new()
    let camera = @core.PerspectiveCamera::new()
    let lights_node = @nodes.LightsNode::new()
    let lighting = @nodes.Lighting::new()
    let list = @nodes.RenderList::with_lights_node(
      lighting, lights_node, scene, camera,
    )
    let geometry = @core.BufferGeometry::new()
    let opaque_material = @nodes.NodeMaterial::new()
    let transparent = @nodes.NodeMaterial::new()
    transparent.transparent = true
    let backdrop = @nodes.NodeMaterial::new()
    @nodes.NodeMaterial::of(backdrop).unwrap().backdrop_node = Some(
      @nodes.uniform(1),
    )
    let objects = []
    let orders = [0.0, 1, 0, 0, -1, 0, 2, 0]
    for i in 0..<8 {
      let o = @core.Mesh::new(geometry~, material=Single(opaque_material))
      o.render_order = orders[i]
      objects.push(o)
    }
    @nodes.set_occlusion_test(objects[3], true)
    @nodes.set_occlusion_test(objects[5], true)
    let ids = fn(items) { g7_items(items, objects[0]) }
    let g : @core.GeometryGroup = { start: 3, count: 6.0, material_index: 0, }
    list.begin() |> ignore
    list.push(objects[0], geometry, opaque_material, 0, 5, None, None)
    list.push(objects[1], geometry, opaque_material, 0, 1, None, None)
    list.push(objects[2], geometry, transparent, 0, 3, None, None)
    list.push(objects[3], geometry, opaque_material, 1, 2, Some(g), None)
    list.push(objects[3], geometry, transparent, 1, 2, None, None)
    list.push(objects[4], geometry, backdrop, 0, -1, None, None)
    list.push(objects[5], geometry, opaque_material, 0, 5, None, None)
    list.unshift(objects[6], geometry, opaque_material, 0, 0, None, None)
    list.unshift(objects[7], geometry, transparent, 0, 7, None, None)
    list.push(objects[2], geometry, transparent, 0, 3, None, None)
    list.push(objects[7], geometry, opaque_material, 0, 3, None, None)
    list.push(objects[2], geometry, opaque_material, 0, -4, None, None)
    log.push([
      g7j("pushed"),
      ids(list.opaque_),
      ids(list.transparent),
      ids(list.transparent_double_pass),
      g7j(list.occlusion_query_count),
      g7j(list.render_items_index),
    ])
    list.sort(None, None)
    log.push([g7j("sorted"), ids(list.opaque_), ids(list.transparent)])
    list.sort(
      Some(fn(a, b) { b.z.unwrap() - a.z.unwrap() }),
      Some(fn(a, b) { a.render_order.unwrap() - b.render_order.unwrap() }),
    )
    log.push([g7j("custom"), ids(list.opaque_), ids(list.transparent)])
    match camera.kind {
      Camera(c) => c._reversed_depth = true
      _ => ()
    }
    list.begin() |> ignore
    list.push(objects[0], geometry, transparent, 0, 5, None, None)
    list.push(objects[1], geometry, transparent, 0, -2, None, None)
    list.push(objects[2], geometry, transparent, 0, 1, None, None)
    list.sort(None, None)
    log.push([
      g7j("reversed"),
      ids(list.transparent),
      g7j(list.render_items.length()),
      g7j(list.render_items_index),
    ])
    list.clear()
    log.push([
      g7j("cleared"),
      g7j(list.render_items.map(fn(it) { g7j(it.id is None) })),
      g7j(list.opaque_.length()),
    ])
    list.begin() |> ignore
    let l1 = @core.PointLight::new()
    let l2 = @core.DirectionalLight::new()
    list.push_light(l1)
    list.push_light(l2)
    list.push(objects[0], geometry, opaque_material, 0, 1, None, None)
    list.finish()
    let lights = @nodes.LightsNode::get_lights(lights_node)
    log.push([
      g7j("finish"),
      g7j(lights.length()),
      g7j(physical_equal(lights[0], l1)),
      g7j(list.render_items.map(fn(it) { g7j(it.id is None) })),
    ])
    lighting.enabled = false
    list.begin() |> ignore
    list.push_light(l1)
    list.finish()
    log.push([
      g7j("finish disabled"),
      g7j(@nodes.LightsNode::get_lights(lights_node).length()),
      g7j(list.lights_array.length()),
    ])
  })
}

///|
fn g7_context_state(c : @nodes.RenderContext) -> @core.JsValue {
  g7j([
    g7j(c.id),
    g7j(c.state_key),
    g7j(c.sample_count),
    g7j(c.clear_depth_value),
    g7j(c.clear_stencil_value),
    match c.mrt {
      Some(n) => g7j(n.id)
      None => @core.JsValue::null()
    },
  ])
}

///|
test "g7diff render_contexts" {
  g7_run("render_contexts", fn(log) {
    g7_align(log)
    let (backend, _) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let contexts = @nodes.RenderContexts::new(renderer)
    let c1 = contexts.get()
    let rt = @core.RenderTarget::new(
      width=4,
      height=2,
      samples=4,
      depth_buffer=true,
      stencil_buffer=true,
    )
    let c2 = contexts.get(render_target=rt)
    let mrt = @nodes.Node::alloc()
    let c3 = contexts.get(render_target=rt, mrt~, call_depth=0)
    let c4 = contexts.get(call_depth=2, camera=@core.OrthographicCamera::new())
    renderer._clear_depth = 0.25
    renderer._clear_stencil = 3
    let c5 = contexts.get()
    renderer.reversed_depth_buffer = true
    let rt2 = @core.RenderTarget::new(
      width=4,
      height=2,
      samples=0,
      count=2,
      type_=@core.HalfFloatType,
    )
    let c6 = contexts.get(
      render_target=rt2,
      call_depth=0,
      camera=@core.PerspectiveCamera::new(),
    )
    log.push([
      g7j("contexts"),
      g7j([c1, c2, c3, c4, c5, c6].map(g7_context_state)),
      g7j(physical_equal(c5, c1)),
    ])
    c2.textures = Some(rt.textures)
    c2.depth_texture = None
    c2.active_cube_face = 3
    c2.active_mipmap_level = 1
    log.push([g7j("cacheKey"), g7j(c2.get_cache_key())])
    rt.set_depth_texture(Some(@core.DepthTexture::new(width=4, height=2)))
    c2.depth_texture = rt.depth_texture()
    log.push([g7j("cacheKey depth"), g7j(c2.get_cache_key())])
    contexts.dispose()
    log.push([g7j("after dispose"), g7j(contexts.get().id)])
  })
}

///|
test "g7diff attributes_geometries" {
  g7_run("attributes_geometries", fn(log) {
    g7_align(log)
    let (backend, stub) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let scene = @core.Scene::new()
    let camera = @core.PerspectiveCamera::new()
    let geometry = g7_mesh_fixture()
    let dynamic = @core.BufferAttribute::new(
      @core.TypedArray::float32([1.0, 2, 3, 4]),
      1,
    )
    dynamic.set_usage(@core.DynamicDrawUsage) |> ignore
    geometry.set_attribute("dynamic", dynamic) |> ignore
    let ib = @core.InterleavedBuffer::new(@core.TypedArray::float32(16), 4)
    geometry.set_attribute(
      "ia",
      @core.InterleavedBufferAttribute::new(ib, 2, 0),
    )
    |> ignore
    geometry.set_attribute(
      "ib",
      @core.InterleavedBufferAttribute::new(ib, 2, 2),
    )
    |> ignore
    geometry.set_attribute("storage", @nodes.StorageBufferAttribute::new(4, 2))
    |> ignore
    geometry.set_indirect(
      Some(@nodes.IndirectStorageBufferAttribute::new(5, 1)),
    )
    |> ignore
    let material = g7_node_material()
    let mesh = @core.Mesh::new(geometry~, material=Single(material))
    let lights_node = @nodes.Node::alloc()
    let ctx = m.render_contexts.get()
    let names = [
      "position", "normal", "uv", "missing", "dynamic", "ia", "ib", "storage",
    ]
    let state = g7_state_fixture(
      node_attributes=names.map(fn(n) { @nodes.NodeAttribute::new(n, "vec3") }),
    )
    let ro = m.render_objects.get(
      mesh,
      material,
      scene,
      camera,
      lights_node,
      ctx,
      None,
    )
    ro._node_builder_state = Some(state)
    let attrs = ro.get_attributes()
    log.push([
      g7j("attributes"),
      g7j(attrs.length()),
      g7j(ro.get_vertex_buffers().length()),
      g7j(attrs.map(fn(a) { g7j(a is Interleaved(_)) })),
    ])
    m.geometries.update_for_render(ro)
    log.push([
      g7j("first"),
      g7j(m.geometries.has(geometry)),
      g7_info_memory(m.info),
    ])
    m.geometries.update_for_render(ro)
    log.push([g7j("same call")])
    m.info.render.calls += 1
    m.geometries.update_for_render(ro)
    log.push([g7j("next call")])
    geometry.get_attribute("position").unwrap().set_needs_update(true)
    ib.set_needs_update(true)
    m.info.render.calls += 1
    m.geometries.update_for_render(ro)
    log.push([g7j("needsUpdate")])
    material.wireframe = Some(true)
    let wire = match ro.get_index() {
      Some(Buffer(w)) => w
      _ => abort("wireframe")
    }
    log.push([
      g7j("wireframe"),
      g7j(wire.array.type_name()),
      g7_typed_values(wire.array),
      g7j(wire.version),
    ])
    m.info.render.calls += 1
    m.geometries.update_for_render(ro)
    log.push([g7j("wire upload"), g7_info_memory(m.info)])
    geometry.index.unwrap().set_needs_update(true)
    let wire2 = match ro.get_index() {
      Some(Buffer(w)) => w
      _ => abort("wireframe")
    }
    log.push([
      g7j("wire rebuilt"),
      g7j(physical_equal(wire2, wire)),
      g7j(wire2.version),
    ])
    let plain = @core.BufferGeometry::new()
    plain.set_attribute(
      "position",
      @core.BufferAttribute::new(@core.TypedArray::float32(18), 3),
    )
    |> ignore
    let mesh2 = @core.Mesh::new(geometry=plain, material=Single(material))
    let ro2 = m.render_objects.get(
      mesh2,
      material,
      scene,
      camera,
      lights_node,
      ctx,
      None,
    )
    ro2._node_builder_state = Some(
      g7_state_fixture(node_attributes=[
        @nodes.NodeAttribute::new("position", "vec3"),
      ]),
    )
    log.push([
      g7j("plain wire"),
      g7_typed_values(ro2.get_index().unwrap().array()),
    ])
    m.geometries.update_for_render(ro2)
    material.wireframe = Some(false)
    geometry.dispose()
    log.push([
      g7j("geometry dispose"),
      g7j(m.geometries.has(geometry)),
      g7_info_memory(m.info),
      g7j(ro.attributes is None),
    ])
    m.attributes.dispose()
    log.push([
      g7j("attributes dispose"),
      g7_info_memory(m.info),
      g7j(m.attributes.dispose_version),
    ])
    m.geometries.dispose()
    log.push([g7j("geometries dispose"), g7_info_memory(m.info)])
    log.push([g7j("gpu"), g7_mock_log(stub.gpu)])
  })
}

///|
test "g7diff textures" {
  g7_run("textures", fn(log) {
    g7_align(log)
    let (backend, _) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let t = m.textures
    let tex = @core.Texture::new()
    let g1 = t.update_texture(tex)
    log.push([
      g7j("default"),
      g7_opt_int(g1),
      g7j(t.get(tex).is_default_texture == Some(true)),
      g7_info_memory(m.info),
    ])
    log.push([g7j("default again"), g7_opt_int(t.update_texture(tex))])
    let dt = @core.DataTexture::new(
      data=@core.TypedArray::uint8(64),
      width=4,
      height=4,
    )
    dt.set_needs_update(true)
    let g2 = t.update_texture(dt)
    log.push([
      g7j("data"),
      g7_opt_int(g2),
      g7j(t.get(dt).is_default_texture == Some(true)),
      g7_info_memory(m.info),
    ])
    let mip = @core.DataTexture::new(
      data=@core.TypedArray::uint8(256),
      width=8,
      height=8,
    )
    mip.generate_mipmaps = true
    mip.type_ = @core.FloatType
    mip.format = @core.RGFormat
    mip.set_needs_update(true)
    let g3 = t.update_texture(mip)
    log.push([
      g7j("mip"),
      g7_opt_int(g3),
      g7j(t.get_mip_levels(mip, 8, 8)),
      g7j(t.needs_mipmaps(mip)),
      g7_info_memory(m.info),
    ])
    let size = t.get_size(mip)
    log.push([g7j("size"), g7j(size.width), g7j(size.height), g7j(size.depth)])
    let rt = @core.RenderTarget::new(width=4, height=2, depth_buffer=true)
    t.update_render_target(rt)
    let rt_data = t.get_render_target(rt)
    let depth = rt_data.depth_texture.unwrap()
    log.push([
      g7j("rt"),
      g7_opt_int(rt_data.width),
      g7_opt_int(rt_data.height),
      g7_opt_int(rt_data.sample_count),
      g7j(depth.id),
      g7j(depth.type_),
      g7j(depth.format),
      g7j(depth.image().width()),
      g7_info_memory(m.info),
    ])
    t.update_render_target(rt)
    log.push([g7j("rt again")])
    rt.set_size(8, 4)
    t.update_render_target(rt)
    log.push([
      g7j("rt resized"),
      g7_opt_int(rt_data.width),
      g7j(rt_data.depth_texture.unwrap().image().width()),
    ])
    t.update_render_target(rt, active_mipmap_level=1)
    let mip_keys = rt_data.depth_texture_mips.unwrap().keys().collect()
    log.push([g7j("rt mip1"), g7j(mip_keys.map(fn(k) { g7j(k.to_string()) }))])
    let rts = @core.RenderTarget::new(
      width=2,
      height=2,
      depth_buffer=true,
      stencil_buffer=true,
      samples=4,
    )
    renderer.reversed_depth_buffer = true
    t.update_render_target(rts)
    let rts_depth = t.get_render_target(rts).depth_texture.unwrap()
    log.push([
      g7j("rt stencil"),
      g7j(rts_depth.type_),
      g7j(rts_depth.format),
      g7_opt_int(t.get_render_target(rts).sample_count),
    ])
    renderer.reversed_depth_buffer = false
    let st = @nodes.StorageTexture::new(width=4, height=4)
    log.push([
      g7j("storage"),
      g7_opt_int(t.update_texture(st)),
      g7j(@nodes.is_storage_texture(st)),
    ])
    let faces = []
    for _ in 0..<6 {
      faces.push(
        @core.TextureImage::TextureImage(
          @core.DataTexture::new(
            data=@core.TypedArray::uint8(16),
            width=2,
            height=2,
          ),
        ),
      )
    }
    let cube = @core.CubeTexture::new(images=faces)
    cube.generate_mipmaps = false
    cube.set_needs_update(true)
    let g_cube = t.update_texture(cube)
    log.push([g7j("cube"), g7_opt_int(g_cube), g7j(t.get_size(cube).depth)])
    let s3 = @nodes.Storage3DTexture::new(width=2, height=2, depth=3)
    let g_s3 = t.update_texture(s3)
    log.push([
      g7j("storage3d"),
      g7_opt_int(g_s3),
      g7j(t.get_size(s3).depth),
      g7j(s3.wrap_r),
      g7j(s3.is_array_texture),
    ])
    dt.dispose()
    log.push([g7j("dispose data"), g7j(t.has(dt)), g7_info_memory(m.info)])
    rt.dispose()
    log.push([
      g7j("dispose rt"),
      g7j(t.has_render_target(rt)),
      g7_info_memory(m.info),
    ])
    t.dispose()
    log.push([g7j("dispose all"), g7_info_memory(m.info)])
  })
}

///|
fn g7_pipeline_state(p : @nodes.Pipeline) -> @core.JsValue {
  g7j([
    g7j(p.cache_key),
    g7j(p.used_times),
    g7j(p.vertex_program().id),
    g7j(p.vertex_program().used_times),
    g7j(p.fragment_program().id),
    g7j(p.fragment_program().used_times),
  ])
}

///|
test "g7diff pipelines" {
  g7_run("pipelines", fn(log) {
    g7_align(log)
    let (backend, stub) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let scene = @core.Scene::new()
    let camera = @core.PerspectiveCamera::new()
    let lights_node = @nodes.Node::alloc()
    let ctx = m.render_contexts.get()
    let geometry = g7_mesh_fixture()
    let make = fn(vs : String, fs : String, side : Int32) {
      let material = g7_node_material()
      material.side = side
      material.name = "m" + vs + fs
      let mesh = @core.Mesh::new(geometry~, material=Single(material))
      let ro = m.render_objects.get(
        mesh,
        material,
        scene,
        camera,
        lights_node,
        ctx,
        None,
      )
      ro._node_builder_state = Some(g7_state_fixture(vs~, fs~))
      ro
    }
    let ro1 = make("v1", "f1", @core.FrontSide)
    let ro2 = make("v1", "f1", @core.FrontSide)
    let ro3 = make("v1", "f2", @core.BackSide)
    let p1 = m.pipelines.get_for_render(ro1)
    let p2 = m.pipelines.get_for_render(ro2)
    let p3 = m.pipelines.get_for_render(ro3)
    log.push([
      g7j("pipelines"),
      g7_pipeline_state(p1),
      g7j(physical_equal(p1, p2)),
      g7_pipeline_state(p3),
      g7j(m.pipelines.is_ready(ro1)),
      g7j(m.pipelines.caches.length()),
      g7_info_memory(m.info),
    ])
    m.pipelines.get_for_render(ro1) |> ignore
    log.push([g7j("cached")])
    stub.needs_update_flag = true
    ro1.material.side = @core.BackSide
    let p4 = m.pipelines.get_for_render(ro1)
    log.push([
      g7j("update"),
      g7_pipeline_state(p4),
      g7j(physical_equal(p4, p3)),
      g7_pipeline_state(p1),
    ])
    stub.needs_update_flag = false
    m.pipelines.delete(ro2) |> ignore
    log.push([
      g7j("delete2"),
      g7j(m.pipelines.caches.length()),
      g7_pipeline_state(p1),
      g7_info_memory(m.info),
    ])
    m.pipelines.delete(ro3) |> ignore
    m.pipelines.delete(ro1) |> ignore
    log.push([
      g7j("deleted all"),
      g7j(m.pipelines.caches.length()),
      g7j(m.pipelines.programs.vertex.length()),
      g7j(m.pipelines.programs.fragment.length()),
      g7_info_memory(m.info),
      g7j(m.pipelines.is_ready(ro1)),
    ])
  })
}

///|
test "g7diff info" {
  g7_run("info", fn(log) {
    g7_align(log)
    let info = @nodes.Info::new()
    let geometry = @core.BufferGeometry::new()
    let mat = @core.Material::new()
    info.update(@core.Mesh::new(geometry~, material=Single(mat)), 36, 2)
    info.update(@core.Points::new(geometry~, material=Single(mat)), 10, 1)
    info.update(@core.LineSegments::new(geometry~, material=Single(mat)), 10, 3)
    info.update(@core.Line::new(geometry~, material=Single(mat)), 10, 1)
    info.update(@core.LineLoop::new(geometry~, material=Single(mat)), 5, 1)
    info.update(@core.Mesh::new(geometry~, material=Single(mat)), 7, 1)
    info.update(@core.Group::new(), 7, 1)
    let r = info.render
    log.push([
      g7j("render"),
      g7j(r.draw_calls),
      g7j(r.triangles),
      g7j(r.points),
      g7j(r.lines),
    ])
    let texs = []
    let mk = fn(
      w : Int32,
      h : Int32,
      type_ : Int32,
      format : Int32,
      gen : Bool,
    ) {
      let t = @core.DataTexture::new(
        data=@core.TypedArray::uint8(4),
        width=w,
        height=h,
        format~,
        type_~,
      )
      t.generate_mipmaps = gen
      texs.push(t)
      t
    }
    mk(3, 3, @core.UnsignedByteType, @core.RGBAFormat, false) |> ignore
    mk(5, 7, @core.FloatType, @core.RGFormat, true) |> ignore
    mk(2, 2, @core.HalfFloatType, @core.RedFormat, false) |> ignore
    mk(4, 4, @core.UnsignedShort4444Type, @core.RGBAFormat, true) |> ignore
    mk(0, 3, @core.UnsignedInt248Type, @core.DepthStencilFormat, false)
    |> ignore
    let with_mips = mk(8, 8, @core.UnsignedByteType, @core.RGBFormat, false)
    with_mips.mipmaps = [
      DataImage({
        data: Some(@core.TypedArray::uint8(10)),
        width: 4,
        height: 4,
        depth: None,
        mipmaps: None,
      }),
      DataImage({ data: None, width: 0, height: 0, depth: None, mipmaps: None, }),
    ]
    for t in texs {
      info.create_texture(t)
    }
    log.push([g7j("textures"), g7_info_memory(info)])
    info.destroy_texture(texs[1])
    info.destroy_texture(@core.Texture::new())
    log.push([g7j("textures destroyed"), g7_info_memory(info)])
    let attr = @core.BufferAttribute::new(@core.TypedArray::float32(6), 3)
    let ib = @core.InterleavedBuffer::new(@core.TypedArray::float32(8), 4)
    info.create_attribute(Buffer(attr))
    info.create_index_attribute(
      Buffer(@core.BufferAttribute::new(@core.TypedArray::uint16(3), 1)),
    )
    info.create_storage_attribute(Interleaved(ib))
    info.create_indirect_storage_attribute(
      Buffer(@core.BufferAttribute::new(@core.TypedArray::uint32(5), 1)),
    )
    log.push([g7j("attributes"), g7_info_memory(info)])
    info.destroy_attribute(Buffer(attr))
    info.destroy_attribute(Buffer(attr))
    info.destroy_attribute(Interleaved(ib))
    log.push([g7j("attributes destroyed"), g7_info_memory(info)])
    let (group, _) = g7_make_group([
      ("vec3", @math.Vector3::new(0, 0, 0)),
      ("float", 1.0),
    ])
    info.create_uniform_buffer(group)
    let stage = @nodes.ProgrammableStage::new("void main() {}", "vertex", "v")
    info.create_program(stage)
    let rb = @nodes.ReadbackBuffer::new(128)
    info.create_readback_buffer(rb)
    log.push([g7j("misc"), g7_info_memory(info)])
    info.destroy_uniform_buffer(group)
    info.destroy_program(stage)
    info.destroy_readback_buffer(rb)
    log.push([g7j("misc destroyed"), g7_info_memory(info)])
    info.calls = 5
    info.render.calls = 3
    info.reset()
    log.push([
      g7j("reset"),
      g7j(info.calls),
      g7j(info.render.calls),
      g7j(info.render.draw_calls),
      g7j(info.render.triangles),
    ])
    info.dispose()
    log.push([
      g7j("dispose"),
      g7j(info.calls),
      g7j(info.render.calls),
      g7_info_memory(info),
    ])
  })
}

///|
fn g7_planes(c : @nodes.ClippingContext) -> @core.JsValue {
  g7j([
    g7j(c.id),
    g7j(c.version),
    g7j(c.cache_key),
    match c.clip_intersection {
      Some(b) => g7j(b)
      None => @core.JsValue::null()
    },
    g7_opt_int(c.parent_version),
    g7j(c.intersection_planes.map(fn(v) { g7j(v.to_array()) })),
    g7j(c.union_planes.map(fn(v) { g7j(v.to_array()) })),
    g7j(c.union_clipping_count()),
  ])
}

///|
test "g7diff clipping_context" {
  g7_run("clipping_context", fn(log) {
    g7_align(log)
    let scene = @core.Scene::new()
    let root = @nodes.ClippingContext::new()
    let parent_planes = [
      @math.Plane::new(
        normal=@math.Vector3::new(1, 2, 3).normalize(),
        constant=-2,
      ),
      @math.Plane::new(normal=@math.Vector3::new(0, 0, 1), constant=0.5),
    ]
    let parent = g7_clipping_group(parent_planes)
    let child = g7_clipping_group([
      @math.Plane::new(
        normal=@math.Vector3::new(-2, 1, 1).normalize(),
        constant=3,
      ),
    ])
    match child.kind {
      ClippingGroup(g) => g.clip_intersection = true
      _ => ()
    }
    let grand = g7_clipping_group([
      @math.Plane::new(normal=@math.Vector3::new(0, 1, 0), constant=1),
    ])
    let camera = @core.PerspectiveCamera::new()
    camera.position.set(-3, 7, 5) |> ignore
    camera.rotation.set(0.5, -0.6, 0.2) |> ignore
    camera.update_matrix_world()
    root.update_global(scene, camera)
    let pc = root.get_group_context(parent)
    let cc = pc.get_group_context(child)
    let gc = cc.get_group_context(grand)
    log.push([
      g7j("contexts"),
      g7_planes(root),
      g7_planes(pc),
      g7_planes(cc),
      g7_planes(gc),
    ])
    let r1 = physical_equal(root.get_group_context(parent), pc)
    let r2 = physical_equal(pc.get_group_context(child), cc)
    log.push([g7j("reuse"), g7j(r1), g7j(r2), g7_planes(cc)])
    parent_planes.push(
      @math.Plane::new(normal=@math.Vector3::new(1, 0, 0), constant=2),
    )
    root.get_group_context(parent) |> ignore
    pc.get_group_context(child) |> ignore
    log.push([g7j("grown"), g7_planes(pc), g7_planes(cc)])
    match child.kind {
      ClippingGroup(g) => g.clip_intersection = false
      _ => ()
    }
    pc.get_group_context(child) |> ignore
    log.push([g7j("flipped"), g7_planes(cc)])
    let array_camera = @core.ArrayCamera::new()
    array_camera.position.set(8, -4, 3) |> ignore
    array_camera.update_matrix_world()
    root.update_global(scene, array_camera)
    pc.get_group_context(child) |> ignore
    log.push([
      g7j("array camera"),
      g7_planes(cc),
      g7j(root.view_matrix.to_array()),
      g7j(root.view_normal_matrix.to_array()),
    ])
  })
}

///|
test "g7diff node_manager" {
  g7_run("node_manager", fn(log) {
    g7_align(log)
    let (backend, _) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let nodes = m.nodes
    let group = @nodes.shared_uniform_group("custom")
    let a = @nodes.NodeUniformsGroup::new("object", @nodes.object_group)
    let b = @nodes.NodeUniformsGroup::new("custom", group)
    let b2 = @nodes.NodeUniformsGroup::new("custom", group)
    let u1 = nodes.update_group(a)
    let u2 = nodes.update_group(a)
    let u3 = nodes.update_group(b)
    let u4 = nodes.update_group(b)
    let u5 = nodes.update_group(b2)
    log.push([g7j("groups"), g7j(u1), g7j(u2), g7j(u3), g7j(u4), g7j(u5)])
    group.set_needs_update(true)
    let v1 = nodes.update_group(b)
    let v2 = nodes.update_group(b)
    let v3 = nodes.update_group(b2)
    log.push([g7j("groups bumped"), g7j(v1), g7j(v2), g7j(v3)])
    let scene = @core.Scene::new()
    let lights_node = @nodes.Node::alloc()
    let k1 = nodes.get_cache_key(scene, lights_node)
    let k2 = nodes.get_cache_key(scene, lights_node)
    renderer.lighting.enabled = false
    let k3 = nodes.get_cache_key(scene, lights_node)
    renderer.info.calls += 1
    let k4 = nodes.get_cache_key(scene, lights_node)
    renderer.lighting.enabled = true
    renderer.shadow_map.enabled = true
    renderer.info.calls += 1
    let k5 = nodes.get_cache_key(scene, lights_node)
    lights_node.name = Some("renamed")
    let k6 = nodes.get_cache_key(scene, @nodes.Node::alloc())
    let env = nodes.get_environment_node(scene)
    let fog = nodes.get_fog_node(scene)
    let bg = nodes.get_background_node(scene)
    log.push([
      g7j("cacheKeys"),
      g7j(k1),
      g7j(k2),
      g7j(k3),
      g7j(k4),
      g7j(k5),
      g7j(k6),
      g7_none_or(env is None),
      g7_none_or(fog is None),
      g7_none_or(bg is None),
    ])
    let material = @nodes.NodeMaterial::new()
    let calls = Ref(0)
    material.custom_program_cache_key = Some(fn() {
      let k = "key\{calls.val}"
      calls.val += 1
      k
    })
    let c1 = nodes.get_custom_program_cache_key(material, scene)
    let c2 = nodes.get_custom_program_cache_key(material, scene)
    material.set_needs_update(true)
    let c3 = nodes.get_custom_program_cache_key(material, scene)
    match scene.kind {
      Scene(s) => s.override_material = Some(material)
      _ => ()
    }
    let c4 = nodes.get_custom_program_cache_key(material, scene)
    let c5 = nodes.get_custom_program_cache_key(material, scene)
    log.push([g7j("programKeys"), g7j(c1), g7j(c2), g7j(c3), g7j(c4), g7j(c5)])
    let frame = nodes.get_node_frame()
    log.push([
      g7j("frame"),
      g7j(frame.renderer is Some(r) && physical_equal(r, renderer)),
      g7_none_or(frame.scene is None),
      g7_none_or(frame.object is None),
      g7_none_or(frame.camera is None),
      g7_none_or(frame.material is None),
      g7_none_or(frame.compute is None),
      g7j(nodes.is_tone_mapping_state()),
    ])
    let out = @nodes.uniform(0)
    log.push([g7j("output index"), g7j(out.id > 0)])
  })
}

///|
/// `null` for an unset value, else a marker that no upstream entry has.
fn g7_none_or(is_none : Bool) -> @core.JsValue {
  if is_none {
    @core.JsValue::null()
  } else {
    g7j("<set>")
  }
}

///|
fn g7_attribute_flags(a : @core.BufferAttribute) -> @core.JsValue {
  g7j([
    g7j(a.array.type_name()),
    g7j(a.array.length()),
    g7j(a.count),
    g7j(a.item_size),
    g7j(@nodes.is_storage_buffer_attribute(a)),
    g7j(@nodes.is_storage_instanced_buffer_attribute(a)),
    g7j(@nodes.is_indirect_storage_buffer_attribute(a)),
    g7j(a.is_instanced_buffer_attribute()),
  ])
}

///|
fn g7_texture_flags(t : @core.Texture) -> @core.JsValue {
  let (w, h, d) = match t.image() {
    DataImage(i) => (i.width, i.height, i.depth)
    _ => abort("image")
  }
  g7j([
    g7j(w),
    g7j(h),
    g7_opt_int(d),
    g7j(t.mag_filter),
    g7j(t.min_filter),
    if t.has_extension_flag("is3DTexture") {
      g7j(t.wrap_r)
    } else {
      @core.JsValue::null()
    },
    g7j(t.is_array_texture),
    g7j(t.mipmaps_auto_update),
    g7j(@nodes.is_storage_texture(t)),
  ])
}

///|
test "g7diff misc_classes" {
  g7_run("misc_classes", fn(log) {
    g7_align(log)
    let sba = @nodes.StorageBufferAttribute::new(3, 4)
    let sia = @nodes.StorageInstancedBufferAttribute::from_array(
      @core.TypedArray::int32([1, 2, 3, 4]),
      2,
    )
    let isa = @nodes.IndirectStorageBufferAttribute::new(2, 5)
    log.push([
      g7j("storage attributes"),
      g7_attribute_flags(sba),
      g7_attribute_flags(sia),
      g7_attribute_flags(isa),
    ])
    let st = @nodes.StorageTexture::new(width=3, height=5)
    let sat = @nodes.StorageArrayTexture::new(width=2, height=2, depth=4)
    let s3t = @nodes.Storage3DTexture::new(width=2, height=3, depth=4)
    log.push([
      g7j("storage textures"),
      g7_texture_flags(st),
      g7_texture_flags(sat),
      g7_texture_flags(s3t),
    ])
    let disposed = Ref(0)
    st.add_event_listener("dispose", fn(_) { disposed.val += 1 })
    @nodes.StorageTexture::set_size(st, 3, 5)
    @nodes.StorageTexture::set_size(st, 4, 5)
    s3t.add_event_listener("dispose", fn(_) { disposed.val += 1 })
    @nodes.Storage3DTexture::set_size(s3t, 2, 3, 4)
    @nodes.Storage3DTexture::set_size(s3t, 2, 3, 5)
    log.push([
      g7j("setSize"),
      g7j(disposed.val),
      g7_texture_flags(st),
      g7_texture_flags(s3t),
    ])
    let s3c = s3t.clone()
    log.push([g7j("clone3d"), g7_texture_flags(s3c)])
    let bg = @nodes.BundleGroup::new()
    @nodes.BundleGroup::set_needs_update(bg, true)
    @nodes.BundleGroup::set_needs_update(bg, false)
    @nodes.BundleGroup::set_needs_update(bg, true)
    let payload = @nodes.BundleGroup::of(bg).unwrap()
    log.push([
      g7j("bundle group"),
      g7j(bg.type_),
      g7j(bg.has_extension_flag("isBundleGroup")),
      g7j(bg.is_group()),
      g7j(payload.static_),
      g7j(payload.version),
    ])
    let bundles = @nodes.RenderBundles::new()
    let camera = @core.PerspectiveCamera::new()
    let ctx = @nodes.RenderContext::new()
    let rb1 = bundles.get(bg, camera, ctx)
    let same = physical_equal(bundles.get(bg, camera, ctx), rb1)
    let other = physical_equal(
      bundles.get(bg, @core.PerspectiveCamera::new(), ctx),
      rb1,
    )
    log.push([g7j("bundles"), g7j(same), g7j(other), g7j(rb1.render_context.id)])
    bundles.dispose()
    log.push([
      g7j("bundles disposed"),
      g7j(physical_equal(bundles.get(bg, camera, ctx), rb1)),
    ])
    let readback = @nodes.ReadbackBuffer::new(64)
    let events : Array[@core.JsValue] = []
    readback.add_event_listener("release", fn(e) { events.push(g7j(e.type_)) })
    readback.add_event_listener("dispose", fn(e) { events.push(g7j(e.type_)) })
    readback.release()
    readback.dispose()
    log.push([
      g7j("readback"),
      g7j(events),
      g7j(readback.max_byte_length),
      g7j(readback.name),
      g7_none_or(readback.buffer is None),
    ])
    let pool = @nodes.TimestampQueryPool::new(max_queries=8)
    pool.timestamps.set("r:0:0:f0", 1.5)
    log.push([
      g7j("pool"),
      g7j(pool.max_queries),
      g7j(pool.get_timestamp("r:0:0:f0")),
      g7j(pool.get_timestamp("missing")),
      g7j(pool.has_timestamp_query("r:0:0:f0")),
      g7j(pool.has_timestamp_query("x")),
      g7j(pool.get_timestamp_frames()),
    ])
    let lib = @nodes.NodeLibrary::new()
    lib.add_material(fn() { @nodes.NodeMaterial::new() }, "MeshBasicMaterial")
    lib.add_material(fn() { @nodes.NodeMaterial::new() }, "MeshBasicMaterial")
    let basic = @core.MeshBasicMaterial::new()
    basic.color.unwrap().set_hex(0x336699) |> ignore
    basic.transparent = true
    basic.side = @core.DoubleSide
    basic.name = "b"
    basic.user_data.set("k", g7j(1))
    let nm = lib.from_material(basic).unwrap()
    log.push([
      g7j("library"),
      g7j(nm.is_node_material()),
      g7j(nm.type_),
      g7j(nm.color.unwrap().get_hex()),
      g7j(nm.transparent),
      g7j(nm.side),
      g7j(nm.name),
      g7j(nm.uuid == basic.uuid),
      g7j(g7j(nm.user_data).strict_equal(g7j(basic.user_data))),
      g7j(nm.id == basic.id),
      g7j(nm.version == basic.version),
      g7j(physical_equal(nm.color.unwrap(), basic.color.unwrap())),
      g7j(lib.from_material(nm) is Some(x) && physical_equal(x, nm)),
      g7_none_or(lib.from_material(@core.MeshLambertMaterial::new()) is None),
      g7_none_or(lib.get_tone_mapping_function(1) is None),
    ])
    let sampled = [
      @nodes.SampledTexture::new("s", None),
      @nodes.SampledArrayTexture::new("a", None),
      @nodes.Sampled3DTexture::new("3", None),
      @nodes.SampledCubeTexture::new("c", None),
    ]
    log.push([
      g7j("sampled"),
      g7j(
        sampled.map(fn(s) {
          let p = @nodes.SampledTexture::of(s).unwrap()
          g7j([
            g7j(p.id),
            g7j(s.has_flag("isSampledTexture")),
            g7j(s.has_flag("isSampledArrayTexture")),
            g7j(s.has_flag("isSampled3DTexture")),
            g7j(s.has_flag("isSampledCubeTexture")),
            g7j(s.has_flag("isSampler")),
            g7j(s.store()),
            g7j(s.mip_level()),
            g7j(s.sampler_version()),
            g7_opt_int(s.generation()),
          ])
        }),
      ),
    ])
    let cl = sampled[0].clone()
    let cl_id = @nodes.SampledTexture::of(cl).unwrap().id
    let s0_id = @nodes.SampledTexture::of(sampled[0]).unwrap().id
    let next_id = @nodes.SampledTexture::of(
        @nodes.SampledTexture::new("x", None),
      ).unwrap().id
    log.push([g7j("sampled clone"), g7j(cl_id), g7j(s0_id), g7j(next_id)])
    let buffer = @nodes.UniformBuffer::new(
      "ub",
      buffer=@core.TypedArray::float32(5),
    )
    buffer.add_update_range(0, 2)
    let bc = buffer.clone()
    bc.add_update_range(4, 1)
    log.push([
      g7j("uniform buffer"),
      g7j(buffer.byte_length()),
      g7j(buffer.update()),
      g7_binding_ranges(buffer),
      g7j(physical_equal(bc.update_ranges(), buffer.update_ranges())),
      g7j(bc.has_flag("isUniformBuffer")),
    ])
    buffer.clear_update_ranges()
    buffer.release()
    log.push([
      g7j("released"),
      g7_none_or(buffer.buffer() is None),
      g7j(bc.update_ranges().length()),
    ])
    let binding = @nodes.Buffer::new("b")
    binding.set_visibility(1)
    binding.set_visibility(4)
    log.push([
      g7j("visibility"),
      g7j(binding.visibility),
      g7j(binding.clone().visibility),
    ])
  })
}

///|
test "g7diff render_bindings" {
  g7_run("render_bindings", fn(log) {
    g7_align(log)
    let (backend, stub) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let scene = @core.Scene::new()
    let camera = @core.PerspectiveCamera::new()
    let lights_node = @nodes.Node::alloc()
    let ctx = m.render_contexts.get()
    renderer._current_render_context = Some(ctx)
    let a = @nodes.uniform(@math.Color::new(0.25, 0.5, 1))
    let b = @nodes.uniform(@math.Matrix4::new().make_translation(1, 2, 3))
    let c = @nodes.uniform(0.5)
    let obj = @nodes.NodeUniformsGroup::new("object", @nodes.object_group)
    obj.add_uniform(
      @nodes.ColorNodeUniform::new(@nodes.NodeUniform::new("a", "color", a)),
    )
    |> ignore
    obj.add_uniform(
      @nodes.Matrix4NodeUniform::new(@nodes.NodeUniform::new("b", "mat4", b)),
    )
    |> ignore
    let ren = @nodes.NodeUniformsGroup::new("render", @nodes.render_group)
    ren.add_uniform(
      @nodes.NumberNodeUniform::new(@nodes.NodeUniform::new("c", "float", c)),
    )
    |> ignore
    let groups = [
      @nodes.BindGroup::new(name="object", bindings=[obj]),
      @nodes.BindGroup::new(name="render", bindings=[ren]),
    ]
    let material = g7_node_material()
    let geometry = g7_mesh_fixture()
    let make = fn() {
      let mesh = @core.Mesh::new(geometry~, material=Single(material))
      let ro = m.render_objects.get(
        mesh,
        material,
        scene,
        camera,
        lights_node,
        ctx,
        None,
      )
      ro._node_builder_state = Some(g7_state_fixture(bindings=groups))
      (mesh, ro)
    }
    let (mesh1, ro1) = make()
    let (_, ro2) = make()
    let b1 = m.bindings.get_for_render(ro1)
    let b2 = m.bindings.get_for_render(ro2)
    let names = fn(bs : Array[@nodes.BindGroup]) {
      g7j(bs.map(fn(g) { g7j([g7j(g.name), g7j(g.id)]) }))
    }
    log.push([
      g7j("bindings"),
      names(b1),
      names(b2),
      g7j(physical_equal(b1[1], b2[1])),
      g7j(physical_equal(b1[0], b2[0])),
      g7j(
        ro1.get_binding_group("render") is Some(g) && physical_equal(g, b1[1]),
      ),
      g7j(ro1.get_binding_group("nope") is None),
    ])
    m.bindings.update_for_render(ro1)
    m.bindings.update_for_render(ro2)
    log.push([g7j("updated")])
    @nodes.InputNode::set_value(c, Number(0.75))
    m.bindings.update_shared_for_render(ro1)
    log.push([g7j("shared updated")])
    @nodes.render_group.set_needs_update(true)
    m.bindings.update_shared_for_render(ro1)
    m.bindings.update_shared_for_render(ro2)
    log.push([g7j("shared updated2")])
    match @nodes.InputNode::get_value(a) {
      Color(col) => col.set_rgb(1, 0, 0) |> ignore
      _ => abort("color")
    }
    match @nodes.InputNode::get_value(b) {
      Matrix4(mat) => mat.make_scale(2, 2, 2) |> ignore
      _ => abort("mat4")
    }
    m.bindings.update_for_render(ro1)
    log.push([g7j("object updated"), g7_info_memory(m.info)])
    mesh1.dispatch_event(@core.Event::new("dispose"))
    log.push([
      g7j("ro1 disposed"),
      g7j(m.bindings.get(b1[1]).used_times),
      g7_info_memory(m.info),
    ])
    ro2.dispose()
    log.push([
      g7j("ro2 disposed"),
      g7j(m.bindings.has(b1[1])),
      g7_info_memory(m.info),
    ])
    log.push([g7j("gpu"), g7_mock_log(stub.gpu)])
  })
}

///|
extern "js" fn g7_fake_frame_context(
  log : @core.JsValue,
) -> @webgl.AnimationFrameProvider =
  #|(log) => {
  #|  const callbacks = [];
  #|  return {
  #|    callbacks,
  #|    requestAnimationFrame( cb ) { callbacks.push( cb ); log.push( [ 'raf', callbacks.length ] ); return callbacks.length; },
  #|    cancelAnimationFrame( id ) { log.push( [ 'cancel', id ] ); },
  #|  };
  #|}

///|
extern "js" fn g7_fire_frame(
  context : @webgl.AnimationFrameProvider,
  index : Int32,
  time : Double,
) -> Unit = "(c, i, t) => { c.callbacks[ i ]( t ); }"

///|
test "g7diff animation" {
  g7_run("animation", fn(log) {
    g7_align(log)
    let (backend, _) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let context = g7_fake_frame_context(log.array)
    let animation = @nodes.Animation::new(renderer, m.nodes, m.info)
    animation.set_context(Some(context))
    log.push([
      g7j("context"),
      g7j(animation.get_context() is Some(c) && physical_equal(c, context)),
      g7_none_or(animation.get_animation_loop() is None),
    ])
    let loop_calls : Array[@core.JsValue] = []
    animation.set_animation_loop(
      Some(fn(time, _) { loop_calls.push(g7j(time)) }),
    )
    m.info.render.draw_calls = 4
    animation.start()
    log.push([
      g7j("started"),
      g7j(m.info.render.draw_calls),
      g7j(m.info.frame),
      g7j(renderer._inspector.is_running),
      g7j(loop_calls.copy()),
    ])
    animation.start()
    m.info.render.draw_calls = 2
    m.info.auto_reset = false
    g7_fire_frame(context, 0, 16)
    log.push([
      g7j("frame"),
      g7j(m.info.render.draw_calls),
      g7j(m.info.frame),
      g7j(m.nodes.node_frame.frame_id),
      g7j(renderer._inspector.is_running),
      g7j(loop_calls.copy()),
    ])
    animation.stop()
    log.push([g7j("stopped"), g7j(renderer._inspector.is_running)])
    animation.dispose()
    log.push([
      g7j("disposed"),
      g7_none_or(animation.get_animation_loop() is None),
    ])
  })
}

///|
test "g7diff node_buffers" {
  g7_run("node_buffers", fn(log) {
    g7_align(log)
    let (backend, stub) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let object_group = @nodes.object_group
    let data = @core.TypedArray::float32([1.0, 2, 3, 4, 5, 6, 7, 8])
    let buffer_node = @nodes.buffer(data, "vec4", 2)
    let ub = @nodes.NodeUniformBuffer::new(buffer_node, Some(object_group))
    let ub2 = @nodes.NodeUniformBuffer::new(
      @nodes.buffer(@core.TypedArray::float32(4), "vec4", 1).set_name("weights"),
      Some(object_group),
    )
    log.push([
      g7j("uniform buffers"),
      g7j(ub.name),
      g7j(ub2.name),
      g7j(ub.byte_length()),
      g7_bytes(ub.buffer().unwrap()),
      g7j(ub.has_flag("isNodeUniformBuffer")),
      g7j(ub.has_flag("isUniformBuffer")),
      g7j(ub.group_node() is Some(g) && physical_equal(g, object_group)),
    ])
    ub.add_update_range(0, 4)
    let node_ranges = fn() {
      @nodes.BufferNode::of(buffer_node).unwrap().update_ranges.length()
    }
    log.push([g7j("ranges"), g7_binding_ranges(ub), g7j(node_ranges())])
    let uc = ub.clone()
    let ub3 = @nodes.NodeUniformBuffer::new(
      @nodes.buffer(@core.TypedArray::float32(4), "vec4", 1),
      Some(object_group),
    )
    log.push([
      g7j("clone"),
      g7j(uc.name),
      g7j(physical_equal(uc.update_ranges(), ub.update_ranges())),
      g7j(ub3.name),
    ])
    ub.clear_update_ranges()
    log.push([g7j("cleared"), g7j(node_ranges())])
    ub.set_update_ranges([{ start: 1, count: 2, }])
    log.push([g7j("set"), g7_binding_ranges(ub), g7j(node_ranges())])
    ub.clear_update_ranges()
    let attr = @nodes.StorageBufferAttribute::new(4, 4)
    let sb = @nodes.NodeStorageBuffer::new(
      @nodes.storage(attr, type_="vec4", count=4),
      Some(object_group),
    )
    let ind = @nodes.IndirectStorageBufferAttribute::new(5, 1)
    let sb2 = @nodes.NodeStorageBuffer::new(
      @nodes.storage(ind, type_="uint", count=5).to_read_only(),
      Some(object_group),
    )
    log.push([
      g7j("storage"),
      g7j(sb.name),
      g7j(@nodes.NodeStorageBuffer::of(sb).unwrap().access),
      g7j(sb.attribute() is Some(a) && physical_equal(a, attr)),
      g7j(sb.buffer() is Some(b) && physical_equal(b, attr.array)),
      g7j(sb.has_flag("isStorageBuffer")),
      g7j(sb.byte_length()),
      g7j(sb2.name),
      g7j(@nodes.NodeStorageBuffer::of(sb2).unwrap().access),
    ])
    let group = @nodes.BindGroup::new(name="object", bindings=[ub, sb, sb2])
    m.bindings._create_bindings([group])
    log.push([g7j("created"), g7_info_memory(m.info)])
    m.bindings._update_bindings([group])
    log.push([g7j("updated")])
    m.bindings._update_bindings([group])
    log.push([g7j("updated again")])
    attr.set_needs_update(true)
    data.set(0, 9)
    m.bindings._update_bindings([group])
    log.push([g7j("updated changed")])
    m.attributes.delete(Buffer(ind)) |> ignore
    m.bindings._update_bindings([group])
    log.push([g7j("regenerated"), g7_info_memory(m.info)])
    m.bindings._destroy_bindings([group])
    log.push([g7j("destroyed"), g7_info_memory(m.info)])
    log.push([g7j("gpu"), g7_mock_log(stub.gpu)])
  })
}

///|
fn g7_node_kind(n : @nodes.Node?) -> @core.JsValue {
  match n {
    Some(n) => g7j([g7j(n.type_()), g7j(n.id)])
    None => @core.JsValue::null()
  }
}

///|
test "g7diff scene_nodes" {
  g7_run("scene_nodes", fn(log) {
    g7_align(log)
    let (backend, _) = g7_stub_backend(log)
    let renderer = g7_stub_renderer(backend)
    let m = g7_modules(renderer)
    let nodes = m.nodes
    let scene = @core.Scene::new()
    let s = match scene.kind {
      Scene(s) => s
      _ => abort("scene")
    }
    let lights_node = @nodes.Node::alloc()
    s.fog = Some(
      Fog(
        @core.Fog::new(
          color=@math.Color::new(0, 0, 0).set_hex(0x336699),
          near=2,
          far=20,
        ),
      ),
    )
    let f1 = nodes.get_fog_node(scene).unwrap()
    let same = physical_equal(nodes.get_fog_node(scene).unwrap(), f1)
    log.push([g7j("fog"), g7_node_kind(Some(f1)), g7j(same)])
    let key1 = nodes.get_cache_key(scene, lights_node)
    s.fog = Some(
      FogExp2(
        @core.FogExp2::new(
          color=@math.Color::new(0, 0, 0).set_hex(0x112233),
          density=0.5,
        ),
      ),
    )
    let f2 = nodes.get_fog_node(scene).unwrap()
    renderer.info.calls += 1
    let key2 = nodes.get_cache_key(scene, lights_node)
    log.push([
      g7j("fog exp2"),
      g7_node_kind(Some(f2)),
      g7j(physical_equal(f2, f1)),
      g7j(key1 == key2),
    ])
    s.fog = None
    log.push([g7j("no fog"), g7_node_kind(nodes.get_fog_node(scene))])
    let env = @core.Texture::new()
    s.environment = Some(env)
    let e1 = nodes.get_environment_node(scene).unwrap()
    let same_env = physical_equal(
      nodes.get_environment_node(scene).unwrap(),
      e1,
    )
    log.push([g7j("environment"), g7_node_kind(Some(e1)), g7j(same_env)])
    let cube_env = @core.CubeTexture::new()
    s.environment = Some(cube_env)
    let e2 = nodes.get_environment_node(scene).unwrap()
    log.push([g7j("cube environment"), g7_node_kind(Some(e2))])
    env.dispose()
    s.environment = Some(env)
    let e3 = nodes.get_environment_node(scene).unwrap()
    log.push([
      g7j("disposed environment"),
      g7_node_kind(Some(e3)),
      g7j(physical_equal(e3, e1)),
    ])
    renderer.lighting.enabled = false
    log.push([
      g7j("lighting off"),
      g7_node_kind(nodes.get_environment_node(scene)),
    ])
    renderer.lighting.enabled = true
    let bg_texture = @core.Texture::new()
    s.background = Some(Texture(bg_texture))
    let b1 = nodes.get_background_node(scene).unwrap()
    log.push([g7j("background"), g7_node_kind(Some(b1))])
    let cube_bg = @core.CubeTexture::new()
    s.background = Some(Texture(cube_bg))
    let b2 = nodes.get_background_node(scene).unwrap()
    log.push([g7j("cube background"), g7_node_kind(Some(b2))])
    s.background = Some(Color(@math.Color::new(1, 0, 0)))
    log.push([
      g7j("color background"),
      g7_node_kind(nodes.get_background_node(scene)),
    ])
    s.background = None
    log.push([
      g7j("no background"),
      g7_node_kind(nodes.get_background_node(scene)),
    ])
    let rt_texture = @core.Texture::new()
    let out = nodes.get_output_node(rt_texture)
    log.push([g7j("output"), g7_node_kind(Some(out))])
    let array_texture = @core.Texture::new()
    array_texture.is_array_texture = true
    let out2 = nodes.get_output_node(array_texture)
    nodes.set_output_layer_index(3)
    log.push([g7j("output array"), g7_node_kind(Some(out2))])
    // cache keys hash node ids, the module-level ones (fog factors, renderGroup
    // uniforms, ...) included
    log.push([
      g7j("cache keys"),
      g7j(key1),
      g7j(key2),
      g7j(
        [f1, f2, e1, e2, e3, b1, b2, out, out2].map(fn(n) { n.get_cache_key() }),
      ),
    ])
  })
}
