// Helpers for the G10 tests: the recording mock context (g10_mock_gl_test.mbt), the
// renderer stand-ins of the shader and call-log harnesses, and what `WebGPURenderer`
// sets up that this package cannot import (renderers/webgpu imports it): the light node
// registrations of BasicNodeLibrary.js and the material/tone mapping table of
// StandardNodeLibrary.js.

///|
let g10_mock_module : @core.JsValue = g10_ffi_mock_gl_module(())

///|
extern "js" fn g10_ffi_mock_create(
  module_ : @core.JsValue,
  options : String,
) -> @webgl.WebGL2RenderingContext = "(m, o) => m.createMockGL(JSON.parse(o))"

///|
/// A mock context; `options` is the JSON options object of `createMockGL`.
fn g10_mock_gl(options~ : String = "{}") -> @webgl.WebGL2RenderingContext {
  g10_ffi_mock_create(g10_mock_module, options)
}

///|
extern "js" fn g10_ffi_log_json(gl : @webgl.WebGL2RenderingContext) -> String = "(gl) => JSON.stringify(gl.__log)"

///|
/// Records `# label <JSON of value>`, for results that are not GL calls.
extern "js" fn g10_note(
  gl : @webgl.WebGL2RenderingContext,
  label : String,
  value : @core.JsValue,
) -> Unit = "(gl, l, v) => gl.__note(l, v)"

///|
extern "js" fn g10_diff_enabled() -> Bool = "() => typeof process !== 'undefined' && process.env.G10_DIFF === '1'"

///|
/// Prints the log for the g10_diff harness when `G10_DIFF=1`.
fn g10_emit_log(name : String, gl : @webgl.WebGL2RenderingContext) -> Unit {
  if g10_diff_enabled() {
    println("@@G10_LOG " + name + " " + g10_ffi_log_json(gl))
  }
}

///|
/// The stub canvas of the harnesses (`{ style, width, height, addEventListener, ... }`).
extern "js" fn g10_stub_canvas() -> @core.JsValue = "() => ({ style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } })"

///|
/// `PointLight.registerNode( PointLightNode )` etc., as BasicNodeLibrary.js and
/// StandardNodeLibrary.js do at module load.
fn init {
  @core.Light::register_node("PointLight", @nodes.PointLightNode::node_class())
  @core.Light::register_node(
    "DirectionalLight",
    @nodes.DirectionalLightNode::node_class(),
  )
  @core.Light::register_node(
    "RectAreaLight",
    @nodes.RectAreaLightNode::node_class(),
  )
  @core.Light::register_node("SpotLight", @nodes.SpotLightNode::node_class())
  @core.Light::register_node(
    "AmbientLight",
    @nodes.AmbientLightNode::node_class(),
  )
  @core.Light::register_node(
    "HemisphereLight",
    @nodes.HemisphereLightNode::node_class(),
  )
  @core.Light::register_node("LightProbe", @nodes.LightProbeNode::node_class())
  @core.Light::register_node(
    "IESSpotLight",
    @nodes.IESSpotLightNode::node_class(),
  )
  @core.Light::register_node(
    "ProjectorLight",
    @nodes.ProjectorLightNode::node_class(),
  )
}

///|
/// `new StandardNodeLibrary()` (renderers/webgpu/nodes/StandardNodeLibrary.js).
fn g10_standard_node_library() -> @nodes.NodeLibrary {
  let library = @nodes.NodeLibrary::new()
  library.add_material(@nodes.MeshPhongNodeMaterial::new, "MeshPhongMaterial")
  library.add_material(
    @nodes.MeshStandardNodeMaterial::new,
    "MeshStandardMaterial",
  )
  library.add_material(
    @nodes.MeshPhysicalNodeMaterial::new,
    "MeshPhysicalMaterial",
  )
  library.add_material(@nodes.MeshToonNodeMaterial::new, "MeshToonMaterial")
  library.add_material(@nodes.MeshBasicNodeMaterial::new, "MeshBasicMaterial")
  library.add_material(
    @nodes.MeshLambertNodeMaterial::new,
    "MeshLambertMaterial",
  )
  library.add_material(@nodes.MeshNormalNodeMaterial::new, "MeshNormalMaterial")
  library.add_material(@nodes.MeshMatcapNodeMaterial::new, "MeshMatcapMaterial")
  library.add_material(@nodes.LineBasicNodeMaterial::new, "LineBasicMaterial")
  library.add_material(@nodes.LineDashedNodeMaterial::new, "LineDashedMaterial")
  library.add_material(@nodes.PointsNodeMaterial::new, "PointsMaterial")
  library.add_material(@nodes.SpriteNodeMaterial::new, "SpriteMaterial")
  library.add_material(@nodes.ShadowNodeMaterial::new, "ShadowMaterial")
  library.add_tone_mapping(@nodes.linear_tone_mapping, @core.LinearToneMapping)
  library.add_tone_mapping(
    @nodes.reinhard_tone_mapping,
    @core.ReinhardToneMapping,
  )
  library.add_tone_mapping(@nodes.cineon_tone_mapping, @core.CineonToneMapping)
  library.add_tone_mapping(
    @nodes.aces_filmic_tone_mapping,
    @core.ACESFilmicToneMapping,
  )
  library.add_tone_mapping(@nodes.agx_tone_mapping, @core.AgXToneMapping)
  library.add_tone_mapping(
    @nodes.neutral_tone_mapping,
    @core.NeutralToneMapping,
  )
  library
}

///|
/// The mock's default extensions (`DEFAULT_EXTENSIONS` of mock_gl_body.js).
let g10_default_extensions : Array[String] = [
  "EXT_color_buffer_float", "EXT_color_buffer_half_float", "OES_texture_float_linear",
  "EXT_texture_filter_anisotropic", "WEBGL_multi_draw", "KHR_parallel_shader_compile",
  "WEBGL_lose_context", "EXT_clip_control", "WEBGL_compressed_texture_s3tc", "WEBGL_compressed_texture_astc",
  "WEBGL_compressed_texture_etc",
]

///|
/// The shader harness renderer: `new WebGPURenderer( { canvas, forceWebGL: true } )` with
/// `_bindings = undefined`, initialized, whose backend has a mock `gl` with `extensions`
/// and a `WebGLExtensions` over it.
fn g10_shader_renderer(extensions : Array[String]) -> @nodes.Renderer {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", g10_stub_canvas())
  parameters.set("forceWebGL", @core.JsValue::of(true))
  let backend = @webgl_fallback.WebGLBackend::new(parameters~)
  let r = @nodes.Renderer::new(backend)
  r.library = g10_standard_node_library()
  r._initialized = true
  backend.renderer = Some(r)
  let payload = @webgl_fallback.WebGLBackend::of(backend).unwrap()
  let json = extensions.map(fn(e) { "\"" + e + "\"" }).join(",")
  payload.gl = Some(g10_mock_gl(options="{\"extensions\":[\{json}]}"))
  payload.extensions = Some(@webgl_fallback.WebGLExtensions::new(payload))
  r
}
