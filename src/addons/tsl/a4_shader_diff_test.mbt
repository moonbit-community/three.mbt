// MoonBit side of the A4 shader scenarios (the display add-ons of TSL agent A4). The
// upstream side is diff/core/webgpu/shader_diff/upstream_a4.mjs
// (scenarios in shader_diff/a4/<group>.mjs, each group in a fresh child process); `node
// run.mjs a4_...` compares them byte for byte. Each `a4*_shader_diff_test.mbt` file is one
// group, run in its own `moon test` so its counters start fresh, as the child does.
//
// A scenario builds the add-on node through the real WGSLNodeBuilder (`flowStagesNode` in
// one stage, plus the builder's declarations), then every internal material the node set
// up (its blur / AO / composite passes) through a full `build()` of a mesh with that
// material; with `glsl=true` the same again through GLSLNodeBuilder (`<name>_glsl`).

///|
extern "js" fn a4_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn a4_only() -> String = "() => (typeof process !== 'undefined' && process.env.A4_ONLY) || ''"

///|
extern "js" fn a4_flow_json(
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
extern "js" fn a4_error_json(message : String) -> String = "(message) => JSON.stringify({ error: message })"

///|
/// The recording mock WebGL 2 context (`createMockGL( { extensions } )`), loaded from
/// diff/core/webgl/harness/mock_gl.cjs as upstream_a4.mjs does.
extern "js" fn a4_mock_gl_js(extensions : FixedArray[String]) -> @core.JsValue =
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
extern "js" fn a4_stub_canvas() -> @core.JsValue = "() => ({ style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } })"

///|
let a4_default_extensions : Array[String] = [
  "EXT_color_buffer_float", "EXT_color_buffer_half_float", "OES_texture_float_linear",
  "EXT_texture_filter_anisotropic", "WEBGL_multi_draw", "KHR_parallel_shader_compile",
  "WEBGL_lose_context", "EXT_clip_control", "WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_astc",
  "WEBGL_compressed_texture_etc",
]

///|
/// The backend of the WGSL renderer: an initialized WebGPUBackend as upstream_a4.mjs
/// fakes it (no device features), like G8's renderer `a`.
priv struct A4Backend {}

///|
impl @nodes.BackendClass for A4Backend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for A4Backend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for A4Backend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for A4Backend with fn has_compatibility(_, _, name) {
  name == @core.Compatibility_TEXTURE_COMPARE
}

///|
impl @nodes.BackendClass for A4Backend with fn has_feature(_, backend, name) {
  @webgpu.wgsl_backend_state(backend).features.contains(
    @webgpu.wgsl_gpu_feature_name(name),
  )
}

///|
/// `new WebGPURenderer( { canvas } )`, `_bindings = undefined`, marked initialized.
fn a4_wgsl_renderer() -> @nodes.Renderer {
  let r = @nodes.Renderer::foundation_stub()
  r.backend.class_ = A4Backend::{ }
  r._initialized = true
  r.backend.renderer = Some(r)
  r.library = @webgpu.StandardNodeLibrary::new()
  r
}

///|
/// `new WebGPURenderer( { canvas, forceWebGL: true } )` with the mock `gl` and a
/// `WebGLExtensions` over it, as G10's renderer `a`.
fn a4_glsl_renderer() -> @nodes.Renderer {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", a4_stub_canvas())
  parameters.set("forceWebGL", @core.JsValue::of(true))
  let backend = @webgl_fallback.WebGLBackend::new(parameters~)
  let r = @nodes.Renderer::new(backend)
  r.library = @webgpu.StandardNodeLibrary::new()
  r._initialized = true
  backend.renderer = Some(r)
  let payload = @webgl_fallback.WebGLBackend::of(backend).unwrap()
  payload.gl = Some(
    a4_mock_gl_js(FixedArray::from_array(a4_default_extensions)).cast(),
  )
  payload.extensions = Some(@webgl_fallback.WebGLExtensions::new(payload))
  r
}

///|
fn a4_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
/// The mesh geometry of the scenarios (position, normal, uv).
fn a4_geometry() -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", a4_attribute(24, 3)) |> ignore
  g.set_attribute("normal", a4_attribute(24, 3)) |> ignore
  g.set_attribute("uv", a4_attribute(24, 2)) |> ignore
  g
}

///|
/// `bindingsOf( builder )`: each bind group's bindings with their visibility.
fn a4_bindings(b : @nodes.NodeBuilder) -> String {
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
/// A named texture, as upstream_a4.mjs's `tex( name )`.
fn a4_tex(name : String) -> @core.Texture {
  let t = @core.Texture::new()
  t.name = name
  t
}

///|
/// A depth texture of size 4x4 named `name`.
fn a4_depth_tex(name : String) -> @core.Texture {
  let t = @core.DepthTexture::new(width=4, height=4)
  t.name = name
  t
}

///|
/// One scenario: `make` returns the add-on node to build; `internals` lists the internal
/// materials (label, material) it set up, read after the flow.
priv struct A4Scenario {
  name : String
  make : () -> @nodes.Node
  stage : String
  mesh : Bool
  glsl : Bool
  internals : (@nodes.Node) -> Array[(String, @core.Material)]
  /// `renderer.logarithmicDepthBuffer` while the scenario builds
  log_depth : Bool
}

///|
/// The scenario list of a group, as `flow( name, make, options )` in the upstream files.
priv struct A4Scenarios {
  list : Array[A4Scenario]
}

///|
fn A4Scenarios::new() -> A4Scenarios {
  { list: [], }
}

///|
fn A4Scenarios::flow(
  self : A4Scenarios,
  name : String,
  make : () -> @nodes.Node,
  stage~ : String = "fragment",
  mesh~ : Bool = true,
  glsl~ : Bool = false,
  internals~ : (@nodes.Node) -> Array[(String, @core.Material)] = fn(_) { [] },
  log_depth~ : Bool = false,
) -> Unit {
  self.list.push({
    name: "a4_" + name,
    make,
    stage,
    mesh,
    glsl,
    internals,
    log_depth,
  })
}

///|
/// A full `build()` of a mesh with `material`, as the renderer builds a pass's quad.
fn a4_build_material(
  material : @core.Material,
  renderer : @nodes.Renderer,
  glsl : Bool,
) -> String {
  let mesh = @core.Mesh::new(geometry=a4_geometry(), material=Single(material))
  let b = if glsl {
    @webgl_fallback.GLSLNodeBuilder::new(Object3D(mesh), renderer)
  } else {
    @webgpu.WGSLNodeBuilder::new(Object3D(mesh), renderer)
  }
  b.scene = Some(@core.Scene::new())
  b.camera = Some(@core.PerspectiveCamera::new())
  b.lights_node = Some(
    @nodes.LightsNode::set_lights(@nodes.LightsNode::new(), []),
  )
  b.build() |> ignore
  b.vertex_shader.unwrap_or("undefined") +
  "\n@@@@\n" +
  b.fragment_shader.unwrap_or("undefined") +
  "\n@@@@\n" +
  a4_bindings(b)
}

///|
fn a4_run_one(
  s : A4Scenario,
  renderer : @nodes.Renderer,
  glsl : Bool,
) -> String {
  let object : @nodes.BuilderObject = if s.mesh {
    Object3D(
      @core.Mesh::new(
        geometry=a4_geometry(),
        material=Single(@core.MeshBasicMaterial::new()),
      ),
    )
  } else {
    NoObject
  }
  let b = if glsl {
    @webgl_fallback.GLSLNodeBuilder::new(object, renderer)
  } else {
    @webgpu.WGSLNodeBuilder::new(object, renderer)
  }
  b.camera = Some(@core.PerspectiveCamera::new())
  renderer.logarithmic_depth_buffer = s.log_depth
  let stage = s.stage
  b.set_shader_stage(Some(stage))
  let node = (s.make)()
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
  let bindings = a4_bindings(b)
  let internals = (s.internals)(node).map(fn(entry) {
    entry.0 + "\n" + a4_build_material(entry.1, renderer, glsl)
  })
  renderer.logarithmic_depth_buffer = false
  a4_flow_json(
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

///|
/// Runs a group's scenarios and prints each record (`@@SHADER <name> <json>`).
fn a4_run(scenarios : A4Scenarios) -> Unit {
  let wgsl = a4_wgsl_renderer()
  let glsl = if a4_shader_diff_enabled() {
    Some(a4_glsl_renderer())
  } else {
    None
  }
  let only = a4_only()
  let emit = fn(name : String, record : String) {
    if a4_shader_diff_enabled() {
      println("@@SHADER \{name} \{record}")
    }
  }
  for s in scenarios.list {
    if only == "" || only == s.name {
      emit(s.name, a4_run_one(s, wgsl, false))
    }
    if s.glsl && (only == "" || only == s.name + "_glsl") {
      match glsl {
        Some(r) => emit(s.name + "_glsl", a4_run_one(s, r, true))
        None => ()
      }
    }
  }
}

///|
/// Group `basic`: the add-ons without internal passes (a4/basic.mjs). The modules are
/// loaded first, in the upstream group's `modules` order.
test "a4 basic shader scenarios (compared with upstream by run.mjs)" {
  @tsl.load_display_bleach_bypass()
  @tsl.load_display_crt()
  @tsl.load_display_lens_dirt()
  @tsl.load_display_radial_blur()
  @tsl.load_display_depth_aware_blur()
  @tsl.load_display_depth_aware_blend()
  let s = A4Scenarios::new()
  let color = fn() { @nodes.texture(a4_tex("color")) }
  // RGBShiftNode
  s.flow("rgb_shift", fn() { @tsl.rgb_shift(color()) })
  s.flow(
    "rgb_shift_options",
    fn() {
      @tsl.rgb_shift(
        @nodes.texture(a4_tex("color"), uv_node=@nodes.uv().mul(2)),
        amount=0.01,
        angle=@nodes.uniform(0.5),
      )
    },
    glsl=true,
  )
  s.flow(
    "rgb_shift_rtt",
    fn() { @tsl.rgb_shift(@nodes.vec4_of([@nodes.uv(), 0, 1])) },
    internals=fn(n) {
      let t = @tsl.RGBShiftNode::of(n).unwrap().texture_node
      [("rtt", @nodes.RTTNode::of(t).unwrap()._quad_mesh.material())]
    },
  )
  // DotScreenNode
  s.flow("dot_screen", fn() { @tsl.dot_screen(color()) })
  s.flow(
    "dot_screen_options",
    fn() {
      @tsl.dot_screen(color().mul(0.5), angle=@nodes.uniform(0.3), scale=2)
    },
    glsl=true,
  )
  // SobelOperatorNode
  s.flow("sobel", fn() { @tsl.sobel(color()) }, glsl=true)
  s.flow("sobel_rtt", fn() { @tsl.sobel(color().mul(@nodes.uniform(2))) }, internals=fn(
    n,
  ) {
    let t = @tsl.SobelOperatorNode::of(n).unwrap().texture_node
    [("rtt", @nodes.RTTNode::of(t).unwrap()._quad_mesh.material())]
  })
  // FXAANode
  s.flow("fxaa", fn() { @tsl.fxaa(color()) }, glsl=true)
  s.flow("fxaa_uv", fn() {
    @tsl.fxaa(@nodes.texture(a4_tex("color"), uv_node=@nodes.screen_uv))
  })
  // BleachBypass
  s.flow("bleach", fn() { @tsl.bleach().call([color()]) })
  s.flow(
    "bleach_opacity",
    fn() { @tsl.bleach().call([color(), @nodes.uniform(0.5)]) },
    glsl=true,
  )
  // CRT
  s.flow("crt_barrel_uv", fn() { @tsl.barrel_uv().call([]) })
  s.flow("crt_barrel_uv_args", fn() {
    @tsl.barrel_uv().call([@nodes.uniform(0.2), @nodes.uv().mul(2)])
  })
  s.flow("crt_barrel_mask", fn() {
    @tsl.barrel_mask().call([@tsl.barrel_uv().call([])])
  })
  s.flow("crt_color_bleeding", fn() { @tsl.color_bleeding().call([color()]) })
  s.flow("crt_color_bleeding_rtt", fn() {
    @tsl.color_bleeding().call([@nodes.vec4_of([@nodes.uv(), 0, 1]), 0.01])
  })
  s.flow("crt_scanlines", fn() { @tsl.scanlines().call([color().rgb()]) })
  s.flow(
    "crt_scanlines_args",
    fn() {
      @tsl.scanlines().call([
        color().rgb(),
        0.5,
        @nodes.uniform(120),
        2,
        @nodes.screen_uv,
      ])
    },
    glsl=true,
  )
  s.flow("crt_vignette", fn() { @tsl.vignette().call([color().rgb()]) })
  s.flow(
    "crt_vignette_args",
    fn() {
      @tsl.vignette().call([
        color().rgb(),
        @nodes.uniform(0.6),
        0.25,
        @nodes.screen_uv,
      ])
    },
    glsl=true,
  )
  s.flow("crt_chain", fn() {
    let distorted = @tsl.barrel_uv().call([0.15])
    let c = @nodes.texture(a4_tex("color"), uv_node=distorted)
    let bled = @tsl.color_bleeding().call([c])
    let lines = @tsl.scanlines().call([bled, 0.3, 240, 0, distorted])
    @tsl.vignette()
    .call([lines, 0.4, 0.5, distorted])
    .mul(@tsl.barrel_mask().call([distorted]))
  })
  // lensDirt
  s.flow("lens_dirt", fn() {
    @tsl.lens_dirt().call([color(), @nodes.texture(a4_tex("dirt"))])
  })
  s.flow(
    "lens_dirt_intensity",
    fn() {
      @tsl.lens_dirt().call([
        @nodes.texture(a4_tex("color"), uv_node=@nodes.screen_uv),
        @nodes.texture(a4_tex("dirt")),
        @nodes.uniform(2),
      ])
    },
    glsl=true,
  )
  // radialBlur
  s.flow("radial_blur", fn() { @tsl.radial_blur().call([color()]) })
  s.flow(
    "radial_blur_options",
    fn() {
      @tsl.radial_blur().call([
        color(),
        @tsl.addon_options([
          ("center", @nodes.uniform(@math.Vector2::new(0.25, 0.75))),
          ("weight", 0.8),
          ("decay", @nodes.uniform(0.9)),
          ("count", 16),
          ("exposure", 3),
          ("premultipliedAlpha", true),
        ]),
      ])
    },
    glsl=true,
  )
  // depthAwareBlur
  let camera = fn() {
    let c = @core.PerspectiveCamera::new(near=0.5, far=50.0)
    c
  }
  s.flow("depth_aware_blur", fn() {
    @tsl.depth_aware_blur().call([
      color(),
      @nodes.texture(a4_depth_tex("depth")),
      @nodes.vec2_of([0.01, 0]),
      camera(),
    ])
  })
  s.flow(
    "depth_aware_blur_args",
    fn() {
      @tsl.depth_aware_blur().call([
        color(),
        @nodes.texture(a4_depth_tex("depth")),
        @nodes.uniform(@math.Vector2::new(0, 0.02)),
        camera(),
        4,
        @nodes.uniform(2),
      ])
    },
    glsl=true,
  )
  s.flow(
    "depth_aware_blur_log_depth",
    fn() {
      @tsl.depth_aware_blur().call([
        color(),
        @nodes.texture(a4_depth_tex("depth")),
        @nodes.vec2_of([0.01, 0]),
        camera(),
      ])
    },
    log_depth=true,
  )
  // depthAwareBlend
  s.flow("depth_aware_blend", fn() {
    @tsl.depth_aware_blend().call([
      color(),
      @nodes.texture(a4_tex("blend")),
      @nodes.texture(a4_depth_tex("depth")),
      camera(),
    ])
  })
  s.flow(
    "depth_aware_blend_options",
    fn() {
      @tsl.depth_aware_blend().call([
        @nodes.texture(a4_tex("color"), uv_node=@nodes.screen_uv),
        @nodes.texture(a4_tex("blend")),
        @nodes.texture(a4_depth_tex("depth")),
        camera(),
        @tsl.addon_options([
          ("blendColor", @nodes.uniform(@math.Color::new(1, 0, 0))),
          ("edgeRadius", 3),
          ("edgeStrength", @nodes.uniform(1.5)),
        ]),
      ])
    },
    glsl=true,
  )
  a4_run(s)
}
