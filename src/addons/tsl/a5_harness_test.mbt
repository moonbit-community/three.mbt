// Shared runner of the A5 shader scenarios (TSL agent A5's add-ons: tsl/utils, math,
// lighting, shadows and half of display). Each `a5_<group>_shader_diff_test.mbt` is one
// group, run in its own `moon test` by run.mjs; the upstream side of group `<group>` is
// diff/core/webgpu/shader_diff/a5/<group>.mjs, run by
// a5/child.mjs in a fresh process (upstream_a5.mjs). `node run_a5.mjs [--group g] [name]`
// compares only these.
//
// Both sides: make the renderers, align the counters (node ids, `fn<id>` names, object /
// material / texture / attribute / geometry ids) to fixed values, load the group's add-on
// modules in the listed order (`load_*()` / `import()`), then build each scenario:
// - flow: the node through the real WGSLNodeBuilder (`flowStagesNode` in one stage, with
//   the builder's declarations), then each internal material the node set up through a
//   full `build()` of a mesh with it; `glsl=true` repeats it with GLSLNodeBuilder
//   (`<name>_glsl`).
// - whole: a material through a full `build()` (`whole_glsl=true` adds `<name>_glsl`).

///|
extern "js" fn a5_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn a5_only() -> String = "() => (typeof process !== 'undefined' && process.env.A5_ONLY) || ''"

///|
extern "js" fn a5_flow_json(
  code : String,
  result : String,
  vars : String,
  uniforms : FixedArray[String],
  codes : String,
  decl : String,
  bindings : String,
  internals : FixedArray[String],
) -> String = "(code, result, vars, uniforms, codes, decl, bindings, internals) => JSON.stringify({ code, result, vars, uniforms, codes, decl, bindings, internals })"

///|
extern "js" fn a5_whole_json(shader : String) -> String = "(shader) => JSON.stringify({ shader })"

///|
extern "js" fn a5_mock_gl_js(extensions : FixedArray[String]) -> @core.JsValue =
  #|(extensions) => {
  #|  const { createRequire } = process.getBuiltinModule( 'node:module' );
  #|  const require = createRequire( '/' );
  #|  const fs = process.getBuiltinModule( 'node:fs' );
  #|  const path = process.getBuiltinModule( 'node:path' );
  #|  // diff/core/webgl/harness/mock_gl.cjs of this repository: walk up from the module root (moon test's cwd).
  #|  let root = process.cwd();
  #|  while ( ! fs.existsSync( path.join( root, 'diff/core/webgl/harness/mock_gl.cjs' ) ) ) {
  #|    const up = path.dirname( root );
  #|    if ( up === root ) throw new Error( 'diff/core/webgl/harness/mock_gl.cjs not found above ' + process.cwd() );
  #|    root = up;
  #|  }
  #|  const { createMockGL } = require( path.join( root, 'diff/core/webgl/harness/mock_gl.cjs' ) );
  #|  return createMockGL( { extensions: [ ...extensions ] } );
  #|}

///|
extern "js" fn a5_stub_canvas() -> @core.JsValue = "() => ({ style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } })"

///|
let a5_default_extensions : Array[String] = [
  "EXT_color_buffer_float", "EXT_color_buffer_half_float", "OES_texture_float_linear",
  "EXT_texture_filter_anisotropic", "WEBGL_multi_draw", "KHR_parallel_shader_compile",
  "WEBGL_lose_context", "EXT_clip_control", "WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_astc",
  "WEBGL_compressed_texture_etc",
]

///|
/// An initialized WebGPUBackend as the upstream child fakes it (no device features).
priv struct A5Backend {}

///|
impl @nodes.BackendClass for A5Backend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for A5Backend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for A5Backend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for A5Backend with fn has_compatibility(_, _, name) {
  name == @core.Compatibility_TEXTURE_COMPARE
}

///|
impl @nodes.BackendClass for A5Backend with fn has_feature(_, backend, name) {
  @webgpu.wgsl_backend_state(backend).features.contains(
    @webgpu.wgsl_gpu_feature_name(name),
  )
}

///|
fn a5_wgsl_renderer() -> @nodes.Renderer {
  let r = @nodes.Renderer::foundation_stub()
  r.backend.class_ = A5Backend::{ }
  r._initialized = true
  r.backend.renderer = Some(r)
  r.library = @webgpu.StandardNodeLibrary::new()
  r
}

///|
fn a5_glsl_renderer() -> @nodes.Renderer {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", a5_stub_canvas())
  parameters.set("forceWebGL", @core.JsValue::of(true))
  let backend = @webgl_fallback.WebGLBackend::new(parameters~)
  let r = @nodes.Renderer::new(backend)
  r.library = @webgpu.StandardNodeLibrary::new()
  r._initialized = true
  backend.renderer = Some(r)
  let payload = @webgl_fallback.WebGLBackend::of(backend).unwrap()
  payload.gl = Some(
    a5_mock_gl_js(FixedArray::from_array(a5_default_extensions)).cast(),
  )
  payload.extensions = Some(@webgl_fallback.WebGLExtensions::new(payload))
  r
}

///|
/// The counters the scenarios start from (the upstream child aligns to the same).
fn a5_align_counters() -> Unit {
  fn advance(name : String, target : Int32, f : () -> Int32) -> Unit {
    let mut id = f()
    if id >= target {
      // Only the per-file runs (run.mjs / run_a5.mjs, SHADER_DIFF=1) compare records; a
      // plain package `moon test` runs several groups in one process and just builds them.
      if a5_shader_diff_enabled() {
        abort("counter \{name} already at \{id}")
      }
      return
    }
    while id < target - 1 {
      id = f()
    }
  }

  advance("fn", 2000, fn() {
    let f = @nodes.fn_(
      fn(_, _) { None },
      layout=@nodes.FnLayout::short([], return_="float"),
    )
    let name = @nodes.ShaderNodeInternal::get_layout(
        @nodes.FnNode::of(f).unwrap().shader_node,
      ).unwrap().name
    let mut v = 0
    for c in name.view(start_offset=2) {
      v = v * 10 + (c.to_int() - '0'.to_int())
    }
    v
  })
  advance("node", 200000, fn() { @nodes.Node::alloc().id })
  advance("object3d", 5000, fn() { @core.Object3D::new().id })
  advance("material", 5000, fn() { @core.Material::new().id })
  advance("texture", 5000, fn() { @core.Texture::new().id })
  advance("attribute", 5000, fn() {
    @core.BufferAttribute::new(@core.TypedArray::float32(1), 1).id
  })
  advance("geometry", 5000, fn() { @core.BufferGeometry::new().id })
}

///|
fn a5_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
/// The mesh geometry of the scenarios (position, normal, uv).
fn a5_geometry() -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", a5_attribute(24, 3)) |> ignore
  g.set_attribute("normal", a5_attribute(24, 3)) |> ignore
  g.set_attribute("uv", a5_attribute(24, 2)) |> ignore
  g
}

///|
fn a5_bindings(b : @nodes.NodeBuilder) -> String {
  b
  .get_bindings()
  .map(fn(g) {
    g.name +
    "[" +
    g.bindings
    .map(fn(binding) { "\{binding.name}:\{binding.visibility}" })
    .join(",") +
    "]"
  })
  .join(" ")
}

///|
/// A named texture (`tex( name )`).
fn a5_tex(name : String) -> @core.Texture {
  let t = @core.Texture::new()
  t.name = name
  t
}

///|
/// A 4x4 depth texture named `name` (`depthTex( name )`).
fn a5_depth_tex(name : String) -> @core.Texture {
  let t = @core.DepthTexture::new(width=4, height=4)
  t.name = name
  t
}

///|
priv enum A5Kind {
  Flow(() -> @nodes.Node, (@nodes.Node) -> Array[(String, @core.Material)])
  Whole(() -> @core.Material)
  /// Any build; returns the record's `text` (`custom( name, ( renderer, isGLSL ) => text )`).
  Custom((@nodes.Renderer, Bool) -> String)
}

///|
priv struct A5Scenario {
  name : String
  kind : A5Kind
  stage : String
  mesh : Bool
  glsl : Bool
}

///|
priv struct A5Scenarios {
  list : Array[A5Scenario]
}

///|
fn A5Scenarios::new() -> A5Scenarios {
  { list: [], }
}

///|
/// `flow( name, make, { stage, mesh, glsl, internals } )`.
fn A5Scenarios::flow(
  self : A5Scenarios,
  name : String,
  make : () -> @nodes.Node,
  stage~ : String = "fragment",
  mesh~ : Bool = true,
  glsl~ : Bool = false,
  internals~ : (@nodes.Node) -> Array[(String, @core.Material)] = fn(_) { [] },
) -> Unit {
  self.list.push({
    name: "a5_" + name,
    kind: Flow(make, internals),
    stage,
    mesh,
    glsl,
  })
}

///|
/// `whole( name, material, { glsl } )`.
fn A5Scenarios::whole(
  self : A5Scenarios,
  name : String,
  material : () -> @core.Material,
  glsl~ : Bool = false,
) -> Unit {
  self.list.push({
    name: "a5_" + name,
    kind: Whole(material),
    stage: "fragment",
    mesh: true,
    glsl,
  })
}

///|
/// `custom( name, run, { glsl } )`: `run( renderer, isGLSL )` returns the record text.
fn A5Scenarios::custom(
  self : A5Scenarios,
  name : String,
  run : (@nodes.Renderer, Bool) -> String,
  glsl~ : Bool = false,
) -> Unit {
  self.list.push({
    name: "a5_" + name,
    kind: Custom(run),
    stage: "fragment",
    mesh: true,
    glsl,
  })
}

///|
extern "js" fn a5_text_json(text : String) -> String = "(text) => JSON.stringify({ text })"

///|
fn a5_builder(
  object : @nodes.BuilderObject,
  renderer : @nodes.Renderer,
  glsl : Bool,
) -> @nodes.NodeBuilder {
  if glsl {
    @webgl_fallback.GLSLNodeBuilder::new(object, renderer)
  } else {
    @webgpu.WGSLNodeBuilder::new(object, renderer)
  }
}

///|
/// A full `build()` of a mesh with `material` (`lights_node` defaults to an empty
/// `LightsNode`; `object` defaults to a mesh of `a5_geometry()`).
fn a5_build_material(
  material : @core.Material,
  renderer : @nodes.Renderer,
  glsl : Bool,
  lights_node? : @nodes.Node,
  object? : @core.Object3D,
  camera? : @core.Object3D,
) -> String {
  let mesh = match object {
    Some(o) => o
    None => @core.Mesh::new(geometry=a5_geometry(), material=Single(material))
  }
  let b = a5_builder(Object3D(mesh), renderer, glsl)
  b.scene = Some(@core.Scene::new())
  b.camera = Some(
    match camera {
      Some(c) => c
      None => @core.PerspectiveCamera::new()
    },
  )
  b.lights_node = Some(
    match lights_node {
      Some(l) => l
      None => @nodes.LightsNode::set_lights(@nodes.LightsNode::new(), [])
    },
  )
  b.build() |> ignore
  b.vertex_shader.unwrap_or("undefined") +
  "\n@@@@\n" +
  b.fragment_shader.unwrap_or("undefined") +
  "\n@@@@\n" +
  a5_bindings(b)
}

///|
fn a5_run_one(
  s : A5Scenario,
  renderer : @nodes.Renderer,
  glsl : Bool,
) -> String {
  match s.kind {
    Whole(material) =>
      a5_whole_json(a5_build_material(material(), renderer, glsl))
    Custom(run) => a5_text_json(run(renderer, glsl))
    Flow(make, internals) => {
      let object : @nodes.BuilderObject = if s.mesh {
        Object3D(
          @core.Mesh::new(
            geometry=a5_geometry(),
            material=Single(@core.MeshBasicMaterial::new()),
          ),
        )
      } else {
        NoObject
      }
      let b = a5_builder(object, renderer, glsl)
      b.camera = Some(@core.PerspectiveCamera::new())
      let stage = s.stage
      b.set_shader_stage(Some(stage))
      let node = make()
      let flow = b.flow_stages_node(node)
      if !b.vars.contains("vertex") {
        b.vars.set("vertex", [])
      }
      let structs = if glsl {
        @webgl_fallback.GLSLNodeBuilder::of(b).unwrap().get_structs(b, stage)
      } else {
        @webgpu.WGSLNodeBuilder::of(b).unwrap().get_structs(b, stage)
      }
      let decl = [
        b.get_uniforms(stage),
        b.get_attributes(stage),
        b.get_varyings("vertex"),
        b.get_varyings("fragment"),
        structs,
        b.get_vars(stage, global=true),
        b.get_vars("vertex", global=true),
      ].join("\n@@\n")
      let uniforms = []
      for st in ["vertex", "fragment", "compute"] {
        for u in b.uniforms.stage(st) {
          uniforms.push("\{st}:\{u.name}:\{u.type_}")
        }
      }
      let codes = b.get_codes(stage)
      let bindings = a5_bindings(b)
      let internals = internals(node).map(fn(entry) {
        entry.0 + "\n" + a5_build_material(entry.1, renderer, glsl)
      })
      a5_flow_json(
        flow.code,
        flow.result_snippet(),
        flow.vars.unwrap_or(""),
        FixedArray::from_array(uniforms),
        codes,
        decl,
        bindings,
        FixedArray::from_array(internals),
      )
    }
  }
}

///|
/// Runs a group: makes the renderers, aligns the counters, loads the group's add-on
/// modules (`load`, in upstream's import order), then lists and builds the scenarios,
/// printing each record (`@@SHADER <name> <json>`).
fn a5_run(load : () -> Unit, scenarios : () -> A5Scenarios) -> Unit {
  let enabled = a5_shader_diff_enabled()
  let wgsl = a5_wgsl_renderer()
  let glsl = if enabled { Some(a5_glsl_renderer()) } else { None }
  a5_align_counters()
  load()
  let only = a5_only()
  let emit = fn(name : String, record : String) {
    if enabled {
      println("@@SHADER \{name} \{record}")
    }
  }
  for s in scenarios().list {
    if only == "" || only == s.name {
      emit(s.name, a5_run_one(s, wgsl, false))
    }
    if s.glsl && (only == "" || only == s.name + "_glsl") {
      match glsl {
        Some(r) => emit(s.name + "_glsl", a5_run_one(s, r, true))
        None => ()
      }
    }
  }
}
