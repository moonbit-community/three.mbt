// MoonBit side of the a6 shader scenarios (the WebGPU objects add-ons: SkyMesh,
// WaterMesh, Water2Mesh, LensflareMesh). The upstream side is
// diff/core/webgpu/shader_diff/upstream_a6.mjs (a fresh child
// process, a6/child.mjs); `node run.mjs a6_...` compares them byte for byte. This file runs
// in its own `moon test`, so its counters start fresh as the child's do. Each object is
// built by the real WGSLNodeBuilder, and again (a fresh object) by GLSLNodeBuilder
// (`<name>_glsl`): vertex + fragment shader, bindings, and the children the build added
// (the reflector targets).

///|
extern "js" fn a6_shader_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.SHADER_DIFF === '1'"

///|
extern "js" fn a6_record_json(
  shader : String,
  bindings : String,
  children : String,
) -> String = "(shader, bindings, children) => JSON.stringify({ shader, bindings, children })"

///|
extern "js" fn a6_error_json(message : String) -> String = "(message) => JSON.stringify({ error: message })"

///|
/// The recording mock WebGL 2 context, loaded from diff/core/webgl/harness/mock_gl.cjs
/// as a6/child.mjs does.
extern "js" fn a6_mock_gl_js(extensions : FixedArray[String]) -> @core.JsValue =
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
extern "js" fn a6_stub_canvas() -> @core.JsValue = "() => ({ style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } })"

///|
let a6_default_extensions : Array[String] = [
  "EXT_color_buffer_float", "EXT_color_buffer_half_float", "OES_texture_float_linear",
  "EXT_texture_filter_anisotropic", "WEBGL_multi_draw", "KHR_parallel_shader_compile",
  "WEBGL_lose_context", "EXT_clip_control", "WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_astc",
  "WEBGL_compressed_texture_etc",
]

///|
/// An initialized WebGPUBackend as a6/child.mjs fakes it (no device features).
priv struct A6Backend {}

///|
impl @nodes.BackendClass for A6Backend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl @nodes.BackendClass for A6Backend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
impl @nodes.BackendClass for A6Backend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl @nodes.BackendClass for A6Backend with fn has_compatibility(_, _, name) {
  name == @core.Compatibility_TEXTURE_COMPARE
}

///|
impl @nodes.BackendClass for A6Backend with fn has_feature(_, backend, name) {
  @webgpu.wgsl_backend_state(backend).features.contains(
    @webgpu.wgsl_gpu_feature_name(name),
  )
}

///|
fn a6_wgsl_renderer() -> @nodes.Renderer {
  let r = @nodes.Renderer::foundation_stub()
  r.backend.class_ = A6Backend::{ }
  r._initialized = true
  r.backend.renderer = Some(r)
  r.library = @webgpu.StandardNodeLibrary::new()
  r
}

///|
fn a6_glsl_renderer() -> @nodes.Renderer {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", a6_stub_canvas())
  parameters.set("forceWebGL", @core.JsValue::of(true))
  let backend = @webgl_fallback.WebGLBackend::new(parameters~)
  let r = @nodes.Renderer::new(backend)
  r.library = @webgpu.StandardNodeLibrary::new()
  r._initialized = true
  backend.renderer = Some(r)
  let payload = @webgl_fallback.WebGLBackend::of(backend).unwrap()
  payload.gl = Some(
    a6_mock_gl_js(FixedArray::from_array(a6_default_extensions)).cast(),
  )
  payload.extensions = Some(@webgl_fallback.WebGLExtensions::new(payload))
  r
}

///|
fn a6_attribute(n : Int32, item_size : Int32) -> @core.GeometryAttribute {
  Buffer(
    @core.BufferAttribute::new(
      @core.TypedArray::float32(n * item_size),
      item_size,
    ),
  )
}

///|
fn a6_geometry() -> @core.BufferGeometry {
  let g = @core.BufferGeometry::new()
  g.set_attribute("position", a6_attribute(24, 3)) |> ignore
  g.set_attribute("normal", a6_attribute(24, 3)) |> ignore
  g.set_attribute("uv", a6_attribute(24, 2)) |> ignore
  g
}

///|
fn a6_tex(name : String) -> @core.Texture {
  let t = @core.Texture::new()
  t.name = name
  t
}

///|
fn a6_bindings(b : @nodes.NodeBuilder) -> String {
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
fn a6_build(
  object : @core.Object3D,
  renderer : @nodes.Renderer,
  glsl : Bool,
) -> String {
  let b = if glsl {
    @webgl_fallback.GLSLNodeBuilder::new(Object3D(object), renderer)
  } else {
    @webgpu.WGSLNodeBuilder::new(Object3D(object), renderer)
  }
  b.scene = Some(@core.Scene::new())
  b.camera = Some(@core.PerspectiveCamera::new())
  b.lights_node = Some(
    @nodes.LightsNode::set_lights(@nodes.LightsNode::new(), []),
  )
  b.build() |> ignore
  a6_record_json(
    b.vertex_shader.unwrap_or("undefined") +
    "\n@@@@\n" +
    b.fragment_shader.unwrap_or("undefined"),
    a6_bindings(b),
    object.children.map(fn(c) { c.type_ + ":" + c.name }).join(","),
  )
}

///|
fn a6_uniform_vector3(node : @nodes.Node) -> @math.Vector3 {
  match @nodes.InputNode::get_value(node) {
    Vector3(v) => v
    _ => abort("not a Vector3 uniform")
  }
}

///|
test "a6 objects shader scenarios run (compared with upstream by run.mjs)" {
  // the add-on modules, in a6/child.mjs's import order (only LensflareMesh.js creates
  // something at load: its geometry)
  @objects.load_lensflare_mesh()
  let scenarios : Array[(String, () -> @core.Object3D)] = [
    ("sky_mesh", fn() { @objects.SkyMesh::new() }),
    (
      "sky_mesh_scaled",
      fn() {
        let sky = @objects.SkyMesh::new()
        sky.scale.set_scalar(450000) |> ignore
        let s = @objects.SkyMesh::of(sky).unwrap()
        @nodes.InputNode::set_value(s.turbidity, Number(10))
        a6_uniform_vector3(s.sun_position).set(0.3, 0.1, -1) |> ignore
        @nodes.InputNode::set_value(s.show_sun_disc, Number(0))
        sky
      },
    ),
    (
      "water_mesh",
      fn() {
        @objects.WaterMesh::new(
          Some(a6_geometry()),
          water_normals=a6_tex("waterNormals"),
          sun_direction=@math.Vector3::new(0.2, 0.9, 0.1),
          sun_color=0xffeedd,
          water_color=0x001e0f,
          distortion_scale=3.7,
          alpha=0.8,
          size=2,
          resolution_scale=0.25,
        )
      },
    ),
    (
      "water_mesh_defaults",
      fn() { @objects.WaterMesh::new(Some(a6_geometry())) },
    ),
    (
      "water2_mesh",
      fn() {
        @objects.Water2Mesh::new(
          Some(a6_geometry()),
          normal_map0=a6_tex("n0"),
          normal_map1=a6_tex("n1"),
          color=0xaaccff,
          scale=4,
          flow_direction=@math.Vector2::new(1, 1),
        )
      },
    ),
    (
      "water2_mesh_flow",
      fn() {
        @objects.Water2Mesh::new(
          Some(a6_geometry()),
          normal_map0=a6_tex("n0"),
          normal_map1=a6_tex("n1"),
          flow_map=a6_tex("flow"),
          reflectivity=0.35,
          flow_speed=0.5,
        )
      },
    ),
    ("lensflare_mesh", fn() { @objects.LensflareMesh::new() }),
  ]
  let wgsl = a6_wgsl_renderer()
  let glsl = a6_glsl_renderer()
  for s in scenarios {
    let wgsl_record = a6_build((s.1)(), wgsl, false)
    let glsl_record = a6_build((s.1)(), glsl, true)
    if a6_shader_diff_enabled() {
      println("@@SHADER a6_\{s.0} \{wgsl_record}")
      println("@@SHADER a6_\{s.0}_glsl \{glsl_record}")
    }
  }
  ignore(a6_error_json)
}
