// Upstream src/renderers/WebGLRenderer.js. GROUP 4.
//
// The module fields are created in `init_gl_context` (upstream `initGLContext`), which
// also runs again on context restore. Until then they hold `uninitialized()`, as upstream
// leaves them `undefined`; the modules that take the renderer (`WebGLPrograms`,
// `WebGLMaterials`, `WebGLBackground`, `WebGLShadowMap`, `WebGLEnvironments`,
// `PMREMGenerator`) can then hold it before its modules exist.
//
// Upstream's closure functions (`projectObject`, `setProgram`, ...) are private methods.
// Its `Promise`s are callbacks.

///|
/// `renderer.debug.diagnostics`.
pub(all) struct WebGLDebugDiagnostics {
  mut keywords : Bool
}

///|
/// `renderer.debug`.
pub(all) struct WebGLDebug {
  mut check_shader_errors : Bool
  diagnostics : WebGLDebugDiagnostics
  /// `onShaderError( gl, program, glVertexShader, glFragmentShader )`
  mut on_shader_error : ((WebGL2RenderingContext, GLProgram, GLShader, GLShader) -> Unit)?
}

///|
/// The node-material bridge `renderer.setNodesHandler` installs (upstream's
/// `WebGLNodesHandler`, from the nodes addon).
pub(open) trait WebGLNodesHandler {
  /// `nodesHandler.setRenderer( renderer )`.
  fn set_renderer(Self, WebGLRenderer) -> Unit
  /// `nodesHandler.setObject( object, material )`.
  fn set_object(Self, @core.Object3D, @core.Material) -> Unit
  /// `nodesHandler.renderStart( scene, camera, targetScene )`.
  fn render_start(Self, @core.Object3D, @core.Object3D, @core.Object3D?) -> Unit
  /// `nodesHandler.renderEnd()`.
  fn render_end(Self) -> Unit
  /// `nodesHandler.updateLights( lights )`.
  fn update_lights(Self, Array[@core.Object3D]) -> Unit
  /// `nodesHandler.build( material, object, parameters )`.
  fn build(Self, @core.Material, @core.Object3D, WebGLProgramParameters) -> Unit
  /// `nodesHandler.onUpdateProgram( material, program, materialProperties )`.
  fn on_update_program(Self, @core.Material, WebGLProgram, MaterialProperties) -> Unit
}

///|
/// `lightProbeGridUniforms`: the per-frame arrays uploaded for `LightProbeGrid`s.
pub(all) struct LightProbeGridUniforms {
  textures : Array[@core.UniformValue]
  min : Array[@core.UniformValue]
  max : Array[@core.UniformValue]
  resolution : Array[@core.UniformValue]
}

///|
/// `srcRegion` of `copyTextureToTexture`.
pub(all) enum TextureCopyRegion {
  Box2(@math.Box2)
  Box3(@math.Box3)
}

///|
/// `dstPosition` of `copyTextureToTexture`.
pub(all) enum TextureCopyPosition {
  Vector2(@math.Vector2)
  Vector3(@math.Vector3)
}

///|
pub(all) struct WebGLRenderer {
  // public properties
  dom_element : HTMLCanvasElement
  debug : WebGLDebug
  mut auto_clear : Bool
  mut auto_clear_color : Bool
  mut auto_clear_depth : Bool
  mut auto_clear_stencil : Bool
  mut sort_objects : Bool
  mut clipping_planes : Array[@math.Plane]
  mut local_clipping_enabled : Bool
  mut tone_mapping : Int32
  mut tone_mapping_exposure : Double
  mut transmission_resolution_scale : Double
  mut _output_color_space : String
  mut xr : WebXRManager
  // assigned by initGLContext, also public upstream
  mut capabilities : WebGLCapabilities
  mut extensions : WebGLExtensions
  mut properties : WebGLProperties
  mut render_lists : WebGLRenderLists
  mut shadow_map : WebGLShadowMap
  mut state : WebGLState
  mut info : WebGLInfo
  // constructor parameters
  depth : Bool
  stencil : Bool
  /// `_alpha`: the context's alpha, or the `alpha` option
  alpha : Bool
  antialias : Bool
  premultiplied_alpha : Bool
  preserve_drawing_buffer : Bool
  power_preference : String
  fail_if_major_performance_caveat : Bool
  reversed_depth_buffer : Bool
  /// what `WebGLCapabilities` reads from the options
  capabilities_parameters : WebGLCapabilitiesParameters
  _output_buffer_type : Int32
  // internal state
  uint_clear_color : @core.TypedArray
  int_clear_color : @core.TypedArray
  light_probe_grid_uniforms : LightProbeGridUniforms
  mut current_render_list : WebGLRenderList?
  mut current_render_state : WebGLRenderState?
  render_list_stack : Array[WebGLRenderList]
  render_state_stack : Array[WebGLRenderState]
  mut output : WebGLOutput?
  mut _is_context_lost : Bool
  mut _nodes_handler : &WebGLNodesHandler?
  mut _scratch_framebuffer : GLFramebuffer
  mut _src_framebuffer : GLFramebuffer
  mut _dst_framebuffer : GLFramebuffer
  mut _current_active_cube_face : Int32
  mut _current_active_mipmap_level : Int32
  mut _current_render_target : @core.RenderTarget?
  mut _current_material_id : Int32
  mut _current_camera : @core.Object3D?
  _current_viewport : @math.Vector4
  _current_scissor : @math.Vector4
  mut _current_scissor_test : Bool?
  _current_clear_color : @math.Color
  mut _current_clear_alpha : Double
  mut _width : Double
  mut _height : Double
  mut _pixel_ratio : Double
  mut _opaque_sort : ((RenderItem, RenderItem) -> Double)?
  mut _transparent_sort : ((RenderItem, RenderItem) -> Double)?
  _viewport : @math.Vector4
  _scissor : @math.Vector4
  mut _scissor_test : Bool
  _frustum : @math.Frustum
  _frustum_array : @math.FrustumArray
  mut _clipping_enabled : Bool
  mut _local_clipping_enabled : Bool
  _proj_screen_matrix : @math.Matrix4
  _vector3 : @math.Vector3
  _vector4 : @math.Vector4
  /// `_emptyScene`, substituted when `scene` is not a `Scene`
  _empty_scene : @core.Object3D
  mut _render_background : Bool
  mut _gl : WebGL2RenderingContext
  // modules (initGLContext)
  mut utils : WebGLUtils
  mut textures : WebGLTextures
  mut environments : WebGLEnvironments
  mut attributes : WebGLAttributes
  mut binding_states : WebGLBindingStates
  mut geometries : WebGLGeometries
  mut objects : WebGLObjects
  mut morphtargets : WebGLMorphtargets
  mut clipping : WebGLClipping
  mut program_cache : WebGLPrograms
  mut materials : WebGLMaterials
  mut render_states : WebGLRenderStates
  mut background : WebGLBackground
  mut uniforms_groups : WebGLUniformsGroups
  mut buffer_renderer : WebGLBufferRenderer
  mut indexed_buffer_renderer : WebGLIndexedBufferRenderer
  // animation
  animation : WebGLAnimation
  mut on_animation_frame_callback : ((Double, @core.JsValue) -> Unit)?
  // listeners kept so they can be removed
  mut on_context_lost : (@core.JsValue) -> Unit
  mut on_context_restore : (@core.JsValue) -> Unit
  mut on_context_creation_error : (@core.JsValue) -> Unit
  mut on_material_dispose : (@core.Event) -> Unit
  mut on_xr_session_start : (@core.Event) -> Unit
  mut on_xr_session_end : (@core.Event) -> Unit
}

// ---------------------------------------------------------------------------
// JS helpers

///|
/// JS `String( x )`, for `width + 'px'`.
extern "js" fn renderer_number_to_string(x : Double) -> String = "(x) => String(x)"

///|
/// JS `x | 0`, the conversion WebGL applies to `GLint`/`GLsizei` arguments.
extern "js" fn renderer_to_int32(x : Double) -> Int32 = "(x) => x | 0"

///|
/// `Math.log`, so `logDepthBufFC` matches upstream bit for bit.
extern "js" fn renderer_math_log(x : Double) -> Double = "Math.log"

///|
/// `Math.pow`.
extern "js" fn renderer_math_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
/// `Math.LN2`.
extern "js" fn renderer_math_ln2() -> Double = "() => Math.LN2"

///|
/// `!! value[ key ]`.
extern "js" fn renderer_js_bool(value : @core.JsValue, key : String) -> Bool = "(v, k) => !!v[k]"

///|
let renderer_infinity : Double = 1.0 / 0.0

///|
let renderer_nan : Double = 0.0 / 0.0

// ---------------------------------------------------------------------------
// small helpers

///|
/// `a || b` for optional textures.
fn renderer_texture_or(
  a : @core.Texture?,
  b : @core.Texture?,
) -> @core.Texture? {
  match a {
    Some(_) => a
    None => b
  }
}

///|
/// Identity of two `scene.fog` values (upstream compares the fog objects).
fn renderer_same_fog(a : @core.SceneFog?, b : @core.SceneFog?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(Fog(x)), Some(Fog(y))) => physical_equal(x, y)
    (Some(FogExp2(x)), Some(FogExp2(y))) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `isMeshStandardMaterial || isMeshLambertMaterial || isMeshPhongMaterial`: the materials
/// that take the scene environment.
fn renderer_uses_environment(material : @core.Material) -> Bool {
  material.is_mesh_standard_material() ||
  material.is_mesh_lambert_material() ||
  material.is_mesh_phong_material()
}

///|
/// `usePMREM` of `getProgram` / `setProgram`.
fn renderer_use_pmrem(material : @core.Material) -> Bool {
  material.is_mesh_standard_material() ||
  (material.is_mesh_lambert_material() && material.env_map is None) ||
  (material.is_mesh_phong_material() && material.env_map is None)
}

///|
/// `materialNeedsLights( material )`.
fn renderer_material_needs_lights(material : @core.Material) -> Bool {
  material.is_mesh_lambert_material() ||
  material.is_mesh_toon_material() ||
  material.is_mesh_phong_material() ||
  material.is_mesh_standard_material() ||
  material.is_shadow_material() ||
  (material.is_shader_material() && material.lights == Some(true))
}

///|
/// `camera.far`; `undefined` (NaN) for a plain `Camera`.
fn renderer_camera_far(camera : @core.Object3D) -> Double {
  match camera.kind {
    Camera({ kind: PerspectiveCamera(p), .. }) => p.far
    Camera({ kind: OrthographicCamera(o), .. }) => o.far
    _ => renderer_nan
  }
}

///|
/// `uniforms[ name ]`; upstream throws a `TypeError` when the uniform is missing.
fn renderer_uniform(
  uniforms : Map[String, @core.Uniform],
  name : String,
) -> @core.Uniform {
  match uniforms.get(name) {
    Some(uniform) => uniform
    None => abort("WebGLRenderer: material uniform '\{name}' is undefined")
  }
}

///|
/// `uniforms[ name ].value = value`.
fn renderer_set_uniform(
  uniforms : Map[String, @core.Uniform],
  name : String,
  value : @core.UniformValue,
) -> Unit {
  renderer_uniform(uniforms, name).value = value
}

///|
/// An optional texture as a uniform value (`null` when absent).
fn renderer_texture_value(texture : @core.Texture?) -> @core.UniformValue {
  match texture {
    Some(texture) => Texture(texture)
    None => Null
  }
}

///|
/// `array[ index ] = value` on a JS array that grows by one at most.
fn renderer_array_assign(
  array : Array[@core.UniformValue],
  index : Int32,
  value : @core.UniformValue,
) -> Unit {
  if index < array.length() {
    array[index] = value
  } else {
    array.push(value)
  }
}

///|
/// A `__webglFramebuffer` value passed to `gl.bindFramebuffer`. Upstream passes the
/// per-level or per-face array as it is, which the context rejects with a `TypeError`.
fn renderer_slot_framebuffer(slot : WebGLFramebufferSlot?) -> GLFramebuffer? {
  match slot {
    None => None
    Some(Framebuffer(framebuffer)) => framebuffer
    Some(_) =>
      abort("WebGLRenderer: framebuffer argument is not a WebGLFramebuffer")
  }
}

///|
/// `!! framebuffer` for a `__webglFramebuffer` value.
fn renderer_slot_truthy(slot : WebGLFramebufferSlot?) -> Bool {
  match slot {
    None | Some(Framebuffer(None)) => false
    Some(_) => true
  }
}

///|
/// The draw call module `renderBufferDirect` uses: `bufferRenderer` or
/// `indexedBufferRenderer`.
priv enum RendererDraw {
  DrawArrays(WebGLBufferRenderer)
  DrawElements(WebGLIndexedBufferRenderer)
}

///|
fn RendererDraw::set_mode(self : RendererDraw, mode : Int32) -> Unit {
  match self {
    DrawArrays(r) => r.set_mode(mode)
    DrawElements(r) => r.set_mode(mode)
  }
}

///|
fn RendererDraw::render(
  self : RendererDraw,
  start : Int32,
  count : Int32,
) -> Unit {
  match self {
    DrawArrays(r) => r.render(start, count)
    DrawElements(r) => r.render(start, count)
  }
}

///|
fn RendererDraw::render_instances(
  self : RendererDraw,
  start : Int32,
  count : Int32,
  primcount : Int32,
) -> Unit {
  match self {
    DrawArrays(r) => r.render_instances(start, count, primcount)
    DrawElements(r) => r.render_instances(start, count, primcount)
  }
}

///|
fn RendererDraw::render_multi_draw(
  self : RendererDraw,
  starts : @core.TypedArray,
  counts : @core.TypedArray,
  draw_count : Int32,
) -> Unit {
  match self {
    DrawArrays(r) => r.render_multi_draw(starts, counts, draw_count)
    DrawElements(r) => r.render_multi_draw(starts, counts, draw_count)
  }
}

// ---------------------------------------------------------------------------
// construction

///|
/// `new WebGLRenderer( parameters )`. `context` is an existing WebGL 2 context;
/// `precision` and `logarithmic_depth_buffer` are the options `WebGLCapabilities` reads.
pub fn WebGLRenderer::new(
  canvas? : HTMLCanvasElement,
  context? : WebGL2RenderingContext,
  depth~ : Bool = true,
  stencil~ : Bool = false,
  alpha~ : Bool = false,
  antialias~ : Bool = false,
  premultiplied_alpha~ : Bool = true,
  preserve_drawing_buffer~ : Bool = false,
  power_preference~ : String = "default",
  fail_if_major_performance_caveat~ : Bool = false,
  reversed_depth_buffer~ : Bool = false,
  output_buffer_type~ : Int32 = @core.UnsignedByteType,
  precision? : String,
  logarithmic_depth_buffer~ : Bool = false,
) -> WebGLRenderer {
  let canvas = match canvas {
    Some(canvas) => canvas
    None => create_canvas_element()
  }
  let _alpha = match context {
    Some(context) => {
      if is_webgl1_context(@core.JsValue::of(context)) {
        abort("THREE.WebGLRenderer: WebGL 1 is not supported since r163.")
      }
      renderer_js_bool(context.get_context_attributes(), "alpha")
    }
    None => alpha
  }
  let width = canvas.width().to_double()
  let height = canvas.height().to_double()
  let renderer : WebGLRenderer = {
    dom_element: canvas,
    debug: {
      check_shader_errors: true,
      diagnostics: { keywords: false, },
      on_shader_error: None,
    },
    auto_clear: true,
    auto_clear_color: true,
    auto_clear_depth: true,
    auto_clear_stencil: true,
    sort_objects: true,
    clipping_planes: [],
    local_clipping_enabled: false,
    tone_mapping: @core.NoToneMapping,
    tone_mapping_exposure: 1.0,
    transmission_resolution_scale: 1.0,
    _output_color_space: @core.SRGBColorSpace,
    xr: uninitialized(),
    capabilities: uninitialized(),
    extensions: uninitialized(),
    properties: uninitialized(),
    render_lists: uninitialized(),
    shadow_map: uninitialized(),
    state: uninitialized(),
    info: uninitialized(),
    depth,
    stencil,
    alpha: _alpha,
    antialias,
    premultiplied_alpha,
    preserve_drawing_buffer,
    power_preference,
    fail_if_major_performance_caveat,
    reversed_depth_buffer,
    capabilities_parameters: {
      precision,
      logarithmic_depth_buffer,
      reversed_depth_buffer,
    },
    _output_buffer_type: output_buffer_type,
    uint_clear_color: @core.TypedArray::new(Uint32Array, 4),
    int_clear_color: @core.TypedArray::new(Int32Array, 4),
    light_probe_grid_uniforms: {
      textures: [],
      min: [],
      max: [],
      resolution: [],
    },
    current_render_list: None,
    current_render_state: None,
    render_list_stack: [],
    render_state_stack: [],
    output: None,
    _is_context_lost: false,
    _nodes_handler: None,
    _scratch_framebuffer: uninitialized(),
    _src_framebuffer: uninitialized(),
    _dst_framebuffer: uninitialized(),
    _current_active_cube_face: 0,
    _current_active_mipmap_level: 0,
    _current_render_target: None,
    _current_material_id: -1,
    _current_camera: None,
    _current_viewport: @math.Vector4::new(0.0, 0.0, 0.0, 0.0),
    _current_scissor: @math.Vector4::new(0.0, 0.0, 0.0, 0.0),
    _current_scissor_test: None,
    _current_clear_color: @math.Color::new(0.0, 0.0, 0.0),
    _current_clear_alpha: 0.0,
    _width: width,
    _height: height,
    _pixel_ratio: 1.0,
    _opaque_sort: None,
    _transparent_sort: None,
    _viewport: @math.Vector4::new(0.0, 0.0, width, height),
    _scissor: @math.Vector4::new(0.0, 0.0, width, height),
    _scissor_test: false,
    _frustum: @math.Frustum::new(),
    _frustum_array: @math.FrustumArray::new(),
    _clipping_enabled: false,
    _local_clipping_enabled: false,
    _proj_screen_matrix: @math.Matrix4::new(),
    _vector3: @math.Vector3::new(0.0, 0.0, 0.0),
    _vector4: @math.Vector4::new(0.0, 0.0, 0.0, 1.0),
    _empty_scene: @core.Scene::new(),
    _render_background: false,
    _gl: match context {
      Some(context) => context
      None => uninitialized()
    },
    utils: uninitialized(),
    textures: uninitialized(),
    environments: uninitialized(),
    attributes: uninitialized(),
    binding_states: uninitialized(),
    geometries: uninitialized(),
    objects: uninitialized(),
    morphtargets: uninitialized(),
    clipping: uninitialized(),
    program_cache: uninitialized(),
    materials: uninitialized(),
    render_states: uninitialized(),
    background: uninitialized(),
    uniforms_groups: uninitialized(),
    buffer_renderer: uninitialized(),
    indexed_buffer_renderer: uninitialized(),
    animation: WebGLAnimation::new(),
    on_animation_frame_callback: None,
    on_context_lost: _ => (),
    on_context_restore: _ => (),
    on_context_creation_error: _ => (),
    on_material_dispose: _ => (),
    on_xr_session_start: _ => (),
    on_xr_session_end: _ => (),
  }
  renderer.on_context_lost = event => renderer.handle_context_lost(event)
  renderer.on_context_restore = _ => renderer.handle_context_restore()
  renderer.on_context_creation_error = event => {
    @core.error(
      "WebGLRenderer: A WebGL context could not be created. Reason: " +
      js_to_string(event.get("statusMessage")),
    )
  }
  renderer.on_material_dispose = event => {
    renderer.handle_material_dispose(event)
  }
  renderer.on_xr_session_start = _ => renderer.animation.stop()
  renderer.on_xr_session_end = _ => renderer.animation.start()
  // initialize
  let context_attributes = @core.JsValue::object()
  context_attributes.set("alpha", @core.JsValue::of(true))
  context_attributes.set("depth", @core.JsValue::of(depth))
  context_attributes.set("stencil", @core.JsValue::of(stencil))
  context_attributes.set("antialias", @core.JsValue::of(antialias))
  context_attributes.set(
    "premultipliedAlpha",
    @core.JsValue::of(premultiplied_alpha),
  )
  context_attributes.set(
    "preserveDrawingBuffer",
    @core.JsValue::of(preserve_drawing_buffer),
  )
  context_attributes.set("powerPreference", @core.JsValue::of(power_preference))
  context_attributes.set(
    "failIfMajorPerformanceCaveat",
    @core.JsValue::of(fail_if_major_performance_caveat),
  )
  // OffscreenCanvas does not have setAttribute, see #22811
  if canvas.has_set_attribute() {
    canvas.set_attribute("data-engine", "three.js r\{@core.REVISION}")
  }
  // event listeners must be registered before WebGL context is created, see #12753
  canvas.add_event_listener("webglcontextlost", renderer.on_context_lost)
  canvas.add_event_listener("webglcontextrestored", renderer.on_context_restore)
  canvas.add_event_listener(
    "webglcontextcreationerror",
    renderer.on_context_creation_error,
  )
  if context is None {
    match canvas.get_context_webgl2(context_attributes) {
      Some(gl) => renderer._gl = gl
      None => {
        let message = if canvas.get_context_webgl2(@core.JsValue::undefined())
          is Some(_) {
          "THREE.WebGLRenderer: Error creating WebGL context with your selected attributes."
        } else {
          "THREE.WebGLRenderer: Error creating WebGL context."
        }
        canvas.remove_event_listener(
          "webglcontextlost",
          renderer.on_context_lost,
        )
        canvas.remove_event_listener(
          "webglcontextrestored",
          renderer.on_context_restore,
        )
        canvas.remove_event_listener(
          "webglcontextcreationerror",
          renderer.on_context_creation_error,
        )
        @core.error("WebGLRenderer: " + message)
        abort(message)
      }
    }
  }
  renderer.init_gl_context()
  // initialize internal render target for non-UnsignedByteType color buffer
  if output_buffer_type != @core.UnsignedByteType {
    renderer.output = Some(
      WebGLOutput::new(
        output_buffer_type,
        canvas.width(),
        canvas.height(),
        antialias,
        depth,
        stencil,
      ),
    )
  }
  // xr
  renderer.xr = WebXRManager::new(renderer, renderer._gl)
  // animation
  renderer.animation.set_animation_loop(
    Some((time, _frame) => renderer.on_animation_frame(time)),
  )
  if global_self() is Some(self_) {
    renderer.animation.set_context(Some(self_))
  }
  renderer.xr.add_event_listener("sessionstart", renderer.on_xr_session_start)
  renderer.xr.add_event_listener("sessionend", renderer.on_xr_session_end)
  three_devtools_observe(@core.JsValue::of(renderer))
  renderer
}

///|
/// `initGLContext()`: (re)creates every module.
pub fn WebGLRenderer::init_gl_context(self : WebGLRenderer) -> Unit {
  let gl = self._gl
  let extensions = WebGLExtensions::new(gl)
  extensions.init()
  self.extensions = extensions
  let utils = WebGLUtils::new(gl, extensions)
  self.utils = utils
  let capabilities = WebGLCapabilities::new(
    gl,
    extensions,
    self.capabilities_parameters,
    utils,
  )
  self.capabilities = capabilities
  let state = WebGLState::new(gl, extensions)
  self.state = state
  if capabilities.reversed_depth_buffer && self.reversed_depth_buffer {
    state.buffers.depth.set_reversed(true)
  }
  self._scratch_framebuffer = gl.create_framebuffer()
  self._src_framebuffer = gl.create_framebuffer()
  self._dst_framebuffer = gl.create_framebuffer()
  let info = WebGLInfo::new(gl)
  self.info = info
  let properties = WebGLProperties::new()
  self.properties = properties
  let textures = WebGLTextures::new(
    gl, extensions, state, properties, capabilities, utils, info,
  )
  self.textures = textures
  let environments = WebGLEnvironments::new(self)
  self.environments = environments
  let attributes = WebGLAttributes::new(gl)
  self.attributes = attributes
  let binding_states = WebGLBindingStates::new(gl, attributes)
  self.binding_states = binding_states
  let geometries = WebGLGeometries::new(gl, attributes, info, binding_states)
  self.geometries = geometries
  let objects = WebGLObjects::new(
    gl, geometries, attributes, binding_states, info,
  )
  self.objects = objects
  self.morphtargets = WebGLMorphtargets::new(gl, capabilities, textures)
  let clipping = WebGLClipping::new(properties)
  self.clipping = clipping
  let program_cache = WebGLPrograms::new(
    self, environments, extensions, capabilities, binding_states, clipping,
  )
  self.program_cache = program_cache
  self.materials = WebGLMaterials::new(self, properties)
  self.render_lists = WebGLRenderLists::new()
  self.render_states = WebGLRenderStates::new(extensions)
  self.background = WebGLBackground::new(
    self,
    environments,
    state,
    objects,
    self.alpha,
    self.premultiplied_alpha,
  )
  self.shadow_map = WebGLShadowMap::new(self, objects, capabilities)
  self.uniforms_groups = WebGLUniformsGroups::new(gl, info, capabilities, state)
  self.buffer_renderer = WebGLBufferRenderer::new(gl, extensions, info)
  self.indexed_buffer_renderer = WebGLIndexedBufferRenderer::new(
    gl, extensions, info,
  )
  info.programs = Some(program_cache.programs)
}

///|
/// `getTargetPixelRatio()`.
fn WebGLRenderer::get_target_pixel_ratio(self : WebGLRenderer) -> Double {
  if self._current_render_target is None {
    self._pixel_ratio
  } else {
    1.0
  }
}

// ---------------------------------------------------------------------------
// context and size

///|
/// `renderer.getContext()`.
pub fn WebGLRenderer::get_context(
  self : WebGLRenderer,
) -> WebGL2RenderingContext {
  self._gl
}

///|
/// `renderer.getContextAttributes()`.
pub fn WebGLRenderer::get_context_attributes(
  self : WebGLRenderer,
) -> @core.JsValue {
  self._gl.get_context_attributes()
}

///|
/// `renderer.forceContextLoss()`.
pub fn WebGLRenderer::force_context_loss(self : WebGLRenderer) -> Unit {
  if self.extensions.get("WEBGL_lose_context") is Some(extension) {
    extension.lose_context()
  }
}

///|
/// `renderer.forceContextRestore()`.
pub fn WebGLRenderer::force_context_restore(self : WebGLRenderer) -> Unit {
  if self.extensions.get("WEBGL_lose_context") is Some(extension) {
    extension.restore_context()
  }
}

///|
/// `renderer.getPixelRatio()`.
pub fn WebGLRenderer::get_pixel_ratio(self : WebGLRenderer) -> Double {
  self._pixel_ratio
}

///|
/// `renderer.setPixelRatio( value )`.
pub fn WebGLRenderer::set_pixel_ratio(
  self : WebGLRenderer,
  value : Double,
) -> Unit {
  self._pixel_ratio = value
  self.set_size(self._width, self._height, update_style=false)
}

///|
/// `renderer.getSize( target )`.
pub fn WebGLRenderer::get_size(
  self : WebGLRenderer,
  target : @math.Vector2,
) -> @math.Vector2 {
  target.set(self._width, self._height)
}

///|
/// `renderer.setSize( width, height, updateStyle )`.
pub fn WebGLRenderer::set_size(
  self : WebGLRenderer,
  width : Double,
  height : Double,
  update_style~ : Bool = true,
) -> Unit {
  if self.xr.is_presenting {
    @core.warn(
      "WebGLRenderer: Can't change size while VR device is presenting.",
    )
    return
  }
  self._width = width
  self._height = height
  let canvas = self.dom_element
  canvas.set_width((width * self._pixel_ratio).floor().to_int())
  canvas.set_height((height * self._pixel_ratio).floor().to_int())
  if update_style {
    canvas.set_style_width(renderer_number_to_string(width) + "px")
    canvas.set_style_height(renderer_number_to_string(height) + "px")
  }
  if self.output is Some(output) {
    output.set_size(canvas.width(), canvas.height())
  }
  self.set_viewport(0.0, 0.0, width, height)
}

///|
/// `renderer.getDrawingBufferSize( target )`.
pub fn WebGLRenderer::get_drawing_buffer_size(
  self : WebGLRenderer,
  target : @math.Vector2,
) -> @math.Vector2 {
  target
  .set(self._width * self._pixel_ratio, self._height * self._pixel_ratio)
  .floor()
}

///|
/// `renderer.setDrawingBufferSize( width, height, pixelRatio )`.
pub fn WebGLRenderer::set_drawing_buffer_size(
  self : WebGLRenderer,
  width : Double,
  height : Double,
  pixel_ratio : Double,
) -> Unit {
  self._width = width
  self._height = height
  self._pixel_ratio = pixel_ratio
  self.dom_element.set_width((width * pixel_ratio).floor().to_int())
  self.dom_element.set_height((height * pixel_ratio).floor().to_int())
  self.set_viewport(0.0, 0.0, width, height)
}

///|
/// `renderer.setEffects( effects )`; `None` is `null`.
pub fn WebGLRenderer::set_effects(
  self : WebGLRenderer,
  effects : Array[&WebGLOutputEffect]?,
) -> Unit {
  if self._output_buffer_type == @core.UnsignedByteType {
    @core.error(
      "WebGLRenderer: setEffects() requires outputBufferType set to HalfFloatType or FloatType.",
    )
    return
  }
  if effects is Some(effects) {
    for effect in effects {
      if effect.is_output_pass() {
        @core.warn(
          "WebGLRenderer: OutputPass is not needed in setEffects(). Tone mapping and color space conversion are applied automatically.",
        )
        break
      }
    }
  }
  self.output.unwrap().set_effects(effects.unwrap_or([]))
}

///|
/// `renderer.getCurrentViewport( target )`.
pub fn WebGLRenderer::get_current_viewport(
  self : WebGLRenderer,
  target : @math.Vector4,
) -> @math.Vector4 {
  target.copy(self._current_viewport)
}

///|
/// `renderer.getViewport( target )`.
pub fn WebGLRenderer::get_viewport(
  self : WebGLRenderer,
  target : @math.Vector4,
) -> @math.Vector4 {
  target.copy(self._viewport)
}

///|
/// `renderer.setViewport( x, y, width, height )`.
pub fn WebGLRenderer::set_viewport(
  self : WebGLRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  ignore(self._viewport.set(x, y, width, height))
  self.state.viewport(
    self._current_viewport
    .copy(self._viewport)
    .multiply_scalar(self.get_target_pixel_ratio())
    .round(),
  )
}

///|
/// `renderer.setViewport( vector4 )`.
pub fn WebGLRenderer::set_viewport_vector(
  self : WebGLRenderer,
  viewport : @math.Vector4,
) -> Unit {
  self.set_viewport(viewport.x, viewport.y, viewport.z, viewport.w)
}

///|
/// `renderer.getScissor( target )`.
pub fn WebGLRenderer::get_scissor(
  self : WebGLRenderer,
  target : @math.Vector4,
) -> @math.Vector4 {
  target.copy(self._scissor)
}

///|
/// `renderer.setScissor( x, y, width, height )`.
pub fn WebGLRenderer::set_scissor(
  self : WebGLRenderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  ignore(self._scissor.set(x, y, width, height))
  self.state.scissor(
    self._current_scissor
    .copy(self._scissor)
    .multiply_scalar(self.get_target_pixel_ratio())
    .round(),
  )
}

///|
/// `renderer.setScissor( vector4 )`.
pub fn WebGLRenderer::set_scissor_vector(
  self : WebGLRenderer,
  scissor : @math.Vector4,
) -> Unit {
  self.set_scissor(scissor.x, scissor.y, scissor.z, scissor.w)
}

///|
/// `renderer.getScissorTest()`.
pub fn WebGLRenderer::get_scissor_test(self : WebGLRenderer) -> Bool {
  self._scissor_test
}

///|
/// `renderer.setScissorTest( boolean )`.
pub fn WebGLRenderer::set_scissor_test(
  self : WebGLRenderer,
  boolean : Bool,
) -> Unit {
  self._scissor_test = boolean
  self.state.set_scissor_test(boolean)
}

///|
/// `renderer.setOpaqueSort( method )`.
pub fn WebGLRenderer::set_opaque_sort(
  self : WebGLRenderer,
  sort : ((RenderItem, RenderItem) -> Double)?,
) -> Unit {
  self._opaque_sort = sort
}

///|
/// `renderer.setTransparentSort( method )`.
pub fn WebGLRenderer::set_transparent_sort(
  self : WebGLRenderer,
  sort : ((RenderItem, RenderItem) -> Double)?,
) -> Unit {
  self._transparent_sort = sort
}

// ---------------------------------------------------------------------------
// clearing

///|
/// `renderer.getClearColor( target )`.
pub fn WebGLRenderer::get_clear_color(
  self : WebGLRenderer,
  target : @math.Color,
) -> @math.Color {
  target.copy(self.background.get_clear_color())
}

///|
/// `renderer.setClearColor( color, alpha )`.
pub fn WebGLRenderer::set_clear_color(
  self : WebGLRenderer,
  color : @math.Color,
  alpha~ : Double = 1,
) -> Unit {
  self.background.set_clear_color(color, alpha~)
}

///|
/// `renderer.setClearColor( hex, alpha )`.
pub fn WebGLRenderer::set_clear_color_hex(
  self : WebGLRenderer,
  hex : Int32,
  alpha~ : Double = 1,
) -> Unit {
  self.background.set_clear_color_hex(hex, alpha~)
}

///|
/// `renderer.getClearAlpha()`.
pub fn WebGLRenderer::get_clear_alpha(self : WebGLRenderer) -> Double {
  self.background.get_clear_alpha()
}

///|
/// `renderer.setClearAlpha( alpha )`.
pub fn WebGLRenderer::set_clear_alpha(
  self : WebGLRenderer,
  alpha : Double,
) -> Unit {
  self.background.set_clear_alpha(alpha)
}

///|
/// `INTEGER_FORMATS.has( format )`.
fn renderer_is_integer_format(format : Int32) -> Bool {
  format == @core.RGBAIntegerFormat ||
  format == @core.RGIntegerFormat ||
  format == @core.RedIntegerFormat
}

///|
/// `UNSIGNED_TYPES.has( type )`.
fn renderer_is_unsigned_type(type_ : Int32) -> Bool {
  type_ == @core.UnsignedByteType ||
  type_ == @core.UnsignedIntType ||
  type_ == @core.UnsignedShortType ||
  type_ == @core.UnsignedInt248Type ||
  type_ == @core.UnsignedShort4444Type ||
  type_ == @core.UnsignedShort5551Type
}

///|
/// `renderer.clear( color, depth, stencil )`.
pub fn WebGLRenderer::clear(
  self : WebGLRenderer,
  color~ : Bool = true,
  depth~ : Bool = true,
  stencil~ : Bool = true,
) -> Unit {
  let gl = self._gl
  let mut bits = 0
  if color {
    // check if we're trying to clear an integer target
    let is_integer_format = match self._current_render_target {
      Some(target) => renderer_is_integer_format(target.texture().format)
      None => false
    }
    // use the appropriate clear functions to clear the target if it's a signed
    // or unsigned integer target
    if is_integer_format {
      let target_type = self._current_render_target.unwrap().texture().type_
      let is_unsigned_type = renderer_is_unsigned_type(target_type)
      let clear_color = self.background.get_clear_color()
      let a = self.background.get_clear_alpha()
      let r = clear_color.r
      let g = clear_color.g
      let b = clear_color.b
      if is_unsigned_type {
        self.uint_clear_color.set(0, r)
        self.uint_clear_color.set(1, g)
        self.uint_clear_color.set(2, b)
        self.uint_clear_color.set(3, a)
        gl.clear_bufferuiv(GL_COLOR, 0, self.uint_clear_color)
      } else {
        self.int_clear_color.set(0, r)
        self.int_clear_color.set(1, g)
        self.int_clear_color.set(2, b)
        self.int_clear_color.set(3, a)
        gl.clear_bufferiv(GL_COLOR, 0, self.int_clear_color)
      }
    } else {
      bits = bits | GL_COLOR_BUFFER_BIT
    }
  }
  if depth {
    bits = bits | GL_DEPTH_BUFFER_BIT
    self.state.buffers.depth.set_mask(true)
  }
  if stencil {
    bits = bits | GL_STENCIL_BUFFER_BIT
    self.state.buffers.stencil.set_mask(-1) // 0xffffffff
  }
  if bits != 0 {
    gl.clear(bits)
  }
}

///|
/// `renderer.clearColor()`.
pub fn WebGLRenderer::clear_color(self : WebGLRenderer) -> Unit {
  self.clear(color=true, depth=false, stencil=false)
}

///|
/// `renderer.clearDepth()`.
pub fn WebGLRenderer::clear_depth(self : WebGLRenderer) -> Unit {
  self.clear(color=false, depth=true, stencil=false)
}

///|
/// `renderer.clearStencil()`.
pub fn WebGLRenderer::clear_stencil(self : WebGLRenderer) -> Unit {
  self.clear(color=false, depth=false, stencil=true)
}

///|
/// `renderer.setNodesHandler( nodesHandler )`.
pub fn WebGLRenderer::set_nodes_handler(
  self : WebGLRenderer,
  nodes_handler : &WebGLNodesHandler,
) -> Unit {
  nodes_handler.set_renderer(self)
  self._nodes_handler = Some(nodes_handler)
}

///|
/// `renderer.dispose()`.
pub fn WebGLRenderer::dispose(self : WebGLRenderer) -> Unit {
  let canvas = self.dom_element
  canvas.remove_event_listener("webglcontextlost", self.on_context_lost)
  canvas.remove_event_listener("webglcontextrestored", self.on_context_restore)
  canvas.remove_event_listener(
    "webglcontextcreationerror",
    self.on_context_creation_error,
  )
  self.background.dispose()
  self.render_lists.dispose()
  self.render_states.dispose()
  self.textures.dispose()
  self.properties.dispose()
  self.environments.dispose()
  self.objects.dispose()
  self.geometries.dispose()
  self.binding_states.dispose()
  self.uniforms_groups.dispose()
  self.program_cache.dispose()
  self.xr.dispose()
  self.xr.remove_event_listener("sessionstart", self.on_xr_session_start)
  self.xr.remove_event_listener("sessionend", self.on_xr_session_end)
  self.animation.stop()
}

// ---------------------------------------------------------------------------
// events

///|
/// `onContextLost( event )`.
fn WebGLRenderer::handle_context_lost(
  self : WebGLRenderer,
  event : @core.JsValue,
) -> Unit {
  dom_event_prevent_default(event)
  @core.log("WebGLRenderer: Context Lost.")
  self._is_context_lost = true
}

///|
/// `onContextRestore()`.
fn WebGLRenderer::handle_context_restore(self : WebGLRenderer) -> Unit {
  @core.log("WebGLRenderer: Context Restored.")
  self._is_context_lost = false
  let info_auto_reset = self.info.auto_reset
  let shadow_map_enabled = self.shadow_map.enabled
  let shadow_map_auto_update = self.shadow_map.auto_update
  let shadow_map_needs_update = self.shadow_map.needs_update
  let shadow_map_type = self.shadow_map.type_
  self.init_gl_context()
  self.info.auto_reset = info_auto_reset
  self.shadow_map.enabled = shadow_map_enabled
  self.shadow_map.auto_update = shadow_map_auto_update
  self.shadow_map.needs_update = shadow_map_needs_update
  self.shadow_map.type_ = shadow_map_type
}

///|
/// `onMaterialDispose( event )`.
fn WebGLRenderer::handle_material_dispose(
  self : WebGLRenderer,
  event : @core.Event,
) -> Unit {
  guard event.target is Some(Material(material)) else { return }
  material.remove_event_listener("dispose", self.on_material_dispose)
  self.deallocate_material(material)
}

///|
/// `deallocateMaterial( material )`.
fn WebGLRenderer::deallocate_material(
  self : WebGLRenderer,
  material : @core.Material,
) -> Unit {
  self.release_material_program_references(material)
  self.properties.remove(material)
}

///|
/// `releaseMaterialProgramReferences( material )`.
fn WebGLRenderer::release_material_program_references(
  self : WebGLRenderer,
  material : @core.Material,
) -> Unit {
  if self.properties.get_material(material).programs is Some(programs) {
    programs.each((_, program) => self.program_cache.release_program(program))
    if material.is_shader_material() {
      self.program_cache.release_shader_cache(material)
    }
  }
}

// ---------------------------------------------------------------------------
// buffer rendering

///|
/// `renderer.renderBufferDirect( camera, scene, geometry, material, object, group )`;
/// `scene` may be `None` (upstream `null`).
pub fn WebGLRenderer::render_buffer_direct(
  self : WebGLRenderer,
  camera : @core.Object3D,
  scene : @core.Object3D?,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  object : @core.Object3D,
  group : @core.GeometryGroup?,
) -> Unit {
  // renderBufferDirect second parameter used to be fog (could be null)
  let scene = match scene {
    Some(scene) => scene
    None => self._empty_scene
  }
  let gl = self._gl
  let front_face_cw = object.is_mesh() &&
    object.matrix_world.determinant_affine() < 0.0
  let program = self.set_program(camera, scene, geometry, material, object)
  self.state.set_material(material, front_face_cw)
  //
  let mut index : @core.GeometryAttribute? = geometry.index
  let mut range_factor = 1.0
  if material.wireframe == Some(true) {
    match self.geometries.get_wireframe_attribute(geometry) {
      Some(attribute) => index = Some(Buffer(attribute))
      None => return
    }
    range_factor = 2.0
  }
  //
  let draw_range = geometry.draw_range
  let position = geometry.attributes.get("position")
  let mut draw_start = draw_range.start.to_double() * range_factor
  let mut draw_end = (draw_range.start.to_double() + draw_range.count) *
    range_factor
  if group is Some(group) {
    draw_start = js_math_max(draw_start, group.start.to_double() * range_factor)
    draw_end = js_math_min(
      draw_end,
      (group.start.to_double() + group.count) * range_factor,
    )
  }
  match index {
    Some(index) => {
      draw_start = js_math_max(draw_start, 0.0)
      draw_end = js_math_min(draw_end, index.count().to_double())
    }
    None =>
      if position is Some(position) {
        draw_start = js_math_max(draw_start, 0.0)
        draw_end = js_math_min(draw_end, position.count().to_double())
      }
  }
  let draw_count = draw_end - draw_start
  if draw_count < 0.0 || draw_count == renderer_infinity {
    return
  }
  //
  self.binding_states.setup(object, material, program, geometry, index)
  let renderer = match index {
    Some(index) => {
      let attribute = self.attributes.get(index).unwrap()
      self.indexed_buffer_renderer.set_index(attribute)
      RendererDraw::DrawElements(self.indexed_buffer_renderer)
    }
    None => RendererDraw::DrawArrays(self.buffer_renderer)
  }
  //
  if object.is_mesh() {
    if material.wireframe == Some(true) {
      self.state.set_line_width(
        material.wireframe_linewidth.unwrap_or(renderer_nan) *
        self.get_target_pixel_ratio(),
      )
      renderer.set_mode(GL_LINES)
    } else {
      renderer.set_mode(GL_TRIANGLES)
    }
  } else if object.is_line() {
    // Not using Line*Material
    let line_width = material.linewidth.unwrap_or(1.0)
    self.state.set_line_width(line_width * self.get_target_pixel_ratio())
    if object.is_line_segments() {
      renderer.set_mode(GL_LINES)
    } else if object.is_line_loop() {
      renderer.set_mode(GL_LINE_LOOP)
    } else {
      renderer.set_mode(GL_LINE_STRIP)
    }
  } else if object.is_points() {
    renderer.set_mode(GL_POINTS)
  } else if object.is_sprite() {
    renderer.set_mode(GL_TRIANGLES)
  }
  let start = renderer_to_int32(draw_start)
  let count = renderer_to_int32(draw_count)
  match object.kind {
    Mesh({ kind: BatchedMesh(batched), .. }) =>
      if self.extensions.get("WEBGL_multi_draw") is None {
        let starts = batched._multi_draw_starts
        let counts = batched._multi_draw_counts
        let draw_count = batched._multi_draw_count
        let bytes_per_element = match index {
          Some(index) =>
            self.attributes.get(index).unwrap().bytes_per_element.to_double()
          None => 1.0
        }
        let uniforms = self.properties.get_material(material).current_program
          .unwrap()
          .get_uniforms()
        for i in 0..<draw_count {
          uniforms.set_value(gl, "_gl_DrawID", Number(i.to_double()))
          renderer.render(
            renderer_to_int32(starts.get(i) / bytes_per_element),
            renderer_to_int32(counts.get(i)),
          )
        }
      } else {
        renderer.render_multi_draw(
          batched._multi_draw_starts,
          batched._multi_draw_counts,
          batched._multi_draw_count,
        )
      }
    Mesh({ kind: InstancedMesh(_), count: instance_count, .. }) =>
      renderer.render_instances(start, count, instance_count)
    _ =>
      if geometry.is_instanced_buffer_geometry {
        let max_instance_count = match geometry_max_instance_count(geometry) {
          Some(max) => max.to_double()
          None => renderer_infinity
        }
        let instance_count = js_math_min(
          geometry.instance_count,
          max_instance_count,
        )
        renderer.render_instances(
          start,
          count,
          renderer_to_int32(instance_count),
        )
      } else {
        renderer.render(start, count)
      }
  }
}

// ---------------------------------------------------------------------------
// compile

///|
/// `prepareMaterial( material, scene, camera, object )`.
fn WebGLRenderer::prepare_material(
  self : WebGLRenderer,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  object : @core.Object3D,
) -> Unit {
  if self._nodes_handler is Some(handler) && material.is_node_material() {
    handler.set_object(object, material)
  }
  if self._clipping_enabled {
    self.clipping.set_state(material, camera, false)
  }
  if material.transparent &&
    material.side == @core.DoubleSide &&
    !material.force_single_pass {
    material.side = @core.BackSide
    material.set_needs_update(true)
    ignore(self.get_program(material, scene, object))
    material.side = @core.FrontSide
    material.set_needs_update(true)
    ignore(self.get_program(material, scene, object))
    material.side = @core.DoubleSide
  } else {
    ignore(self.get_program(material, scene, object))
  }
}

///|
/// The lights `compile` gathers from `root`.
fn WebGLRenderer::compile_push_lights(
  self : WebGLRenderer,
  root : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  let render_state = self.current_render_state.unwrap()
  root.traverse_visible(object => {
    if object.is_light() && object.layers.test_(camera.layers) {
      render_state.push_light(object)
      if object.cast_shadow {
        render_state.push_shadow(object)
      }
    }
  })
}

///|
/// `renderer.compile( scene, camera, targetScene )`: the materials it prepared, in first-seen
/// order (upstream's `Set`).
pub fn WebGLRenderer::compile(
  self : WebGLRenderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  target_scene? : @core.Object3D,
) -> Array[@core.Material] {
  let target_scene = match target_scene {
    Some(target_scene) => target_scene
    None => scene
  }
  if self._nodes_handler is Some(handler) {
    handler.render_start(scene, camera, Some(target_scene))
  }
  let render_state = self.render_states.get(target_scene)
  self.current_render_state = Some(render_state)
  render_state.init(camera)
  self.render_state_stack.push(render_state)
  // gather lights from both the target scene and the new object that will be added to the scene.
  self.compile_push_lights(target_scene, camera)
  if !physical_equal(scene, target_scene) {
    self.compile_push_lights(scene, camera)
  }
  render_state.setup_lights()
  if self._nodes_handler is Some(handler) {
    handler.update_lights(render_state.state.lights_array)
  }
  self._local_clipping_enabled = self.local_clipping_enabled
  self._clipping_enabled = self.clipping.init(
    self.clipping_planes,
    self._local_clipping_enabled,
  )
  if self._clipping_enabled {
    self.clipping.set_global_state(self.clipping_planes, camera)
  }
  // node materials reference the shadow map when they are built, so it must exist by now
  if self._nodes_handler is Some(_) {
    self.shadow_map.render(
      render_state.state.shadows_array,
      target_scene,
      camera,
    )
  }
  // Only initialize materials in the new scene, not the targetScene.
  let materials : Array[@core.Material] = []
  let add = (material : @core.Material) => {
    if !materials.iter().any(m => physical_equal(m, material)) {
      materials.push(material)
    }
  }
  scene.traverse(object => {
    if !(object.is_mesh() ||
      object.is_points() ||
      object.is_line() ||
      object.is_sprite()) {
      return
    }
    match object.get_material() {
      Some(Multiple(material)) =>
        for material2 in material {
          self.prepare_material(material2, target_scene, camera, object)
          add(material2)
        }
      Some(Single(material)) => {
        self.prepare_material(material, target_scene, camera, object)
        add(material)
      }
      None => ()
    }
  })
  self.current_render_state = self.render_state_stack.pop()
  if self._nodes_handler is Some(handler) {
    handler.render_end()
  }
  materials
}

///|
/// `renderer.compileAsync( scene, camera, targetScene )`; the `Promise` resolution is
/// `on_done( scene )`.
pub fn WebGLRenderer::compile_async(
  self : WebGLRenderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  on_done : (@core.Object3D) -> Unit,
  target_scene? : @core.Object3D,
) -> Unit {
  let materials = self.compile(scene, camera, target_scene?)
  // Wait for all the materials in the new object to indicate that they're
  // ready to be used before resolving the promise.
  fn check_materials_ready() -> Unit {
    let pending = []
    for material in materials {
      let material_properties = self.properties.get_material(material)
      let ready = match material_properties.current_program {
        None => true
        Some(program) => program.is_ready()
      }
      // stop waiting for materials that are ready to use or have been disposed
      if !ready {
        pending.push(material)
      }
    }
    materials.clear()
    materials.push_iter(pending.iter())
    // once the list of compiling materials is empty, call the callback
    if materials.length() == 0 {
      on_done(scene)
      return
    }
    // if some materials are still not ready, wait a bit and check again
    set_timeout(check_materials_ready, 10.0)
  }

  if self.extensions.get("KHR_parallel_shader_compile") is Some(_) {
    // If we can check the compilation status of the materials without
    // blocking then do so right away.
    check_materials_ready()
  } else {
    // Otherwise start by waiting a bit to give the materials we just
    // initialized a chance to finish.
    set_timeout(check_materials_ready, 10.0)
  }
}

// ---------------------------------------------------------------------------
// animation loop

///|
/// `onAnimationFrame( time )`.
fn WebGLRenderer::on_animation_frame(
  self : WebGLRenderer,
  time : Double,
) -> Unit {
  if self.on_animation_frame_callback is Some(callback) {
    callback(time, @core.JsValue::undefined())
  }
}

///|
/// `renderer.setAnimationLoop( callback )`; `callback( time, xrFrame )`.
pub fn WebGLRenderer::set_animation_loop(
  self : WebGLRenderer,
  callback : ((Double, @core.JsValue) -> Unit)?,
) -> Unit {
  self.on_animation_frame_callback = callback
  self.xr.set_animation_loop(callback)
  if callback is None {
    self.animation.stop()
  } else {
    self.animation.start()
  }
}

// ---------------------------------------------------------------------------
// rendering

///|
/// `renderer.render( scene, camera )`.
pub fn WebGLRenderer::render(
  self : WebGLRenderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  if !camera.is_camera() {
    @core.error(
      "WebGLRenderer.render: camera is not an instance of THREE.Camera.",
    )
    return
  }
  if self._is_context_lost {
    return
  }
  // update node builder if available
  if self._nodes_handler is Some(handler) {
    handler.render_start(scene, camera, None)
  }
  // use internal render target for HalfFloatType color buffer (only when tone mapping is enabled)
  let xr = self.xr
  let is_xr_presenting = xr.enabled && xr.is_presenting
  let use_output = match self.output {
    Some(output) =>
      (self._current_render_target is None || is_xr_presenting) &&
      output.begin(self, self._current_render_target)
    None => false
  }
  // update scene graph
  if scene.matrix_world_auto_update {
    scene.update_matrix_world()
  }
  // update camera matrices and frustum
  if camera.parent is None && camera.matrix_world_auto_update {
    camera.update_matrix_world()
  }
  let mut camera = camera
  if xr.enabled &&
    xr.is_presenting &&
    (self.output is None || !self.output.unwrap().is_compositing()) {
    if xr.camera_auto_update {
      xr.update_camera(camera)
    }
    camera = xr.get_camera() // use XR camera for rendering
  }
  //
  if scene.is_scene() {
    (scene.as_scene().on_before_render)(
      @core.JsValue::of(self),
      scene,
      camera,
      self._current_render_target,
    )
  }
  let render_state = self.render_states.get(
    scene,
    render_call_depth=self.render_state_stack.length(),
  )
  self.current_render_state = Some(render_state)
  render_state.init(camera)
  render_state.state.texture_units = self.textures.get_texture_units()
  self.render_state_stack.push(render_state)
  ignore(
    self._proj_screen_matrix.multiply_matrices(
      camera.projection_matrix(),
      camera.matrix_world_inverse(),
    ),
  )
  if camera.is_array_camera() {
    ignore(
      @core.frustum_array_set_from_array_camera(self._frustum_array, camera),
    )
  } else {
    ignore(
      self._frustum.set_from_projection_matrix(
        self._proj_screen_matrix,
        coordinate_system=@core.WebGLCoordinateSystem,
        reversed_depth=camera.reversed_depth(),
      ),
    )
  }
  self._local_clipping_enabled = self.local_clipping_enabled
  self._clipping_enabled = self.clipping.init(
    self.clipping_planes,
    self._local_clipping_enabled,
  )
  let render_list = self.render_lists.get(
    scene,
    self.render_list_stack.length(),
  )
  self.current_render_list = Some(render_list)
  render_list.init()
  self.render_list_stack.push(render_list)
  self.info.render.frame += 1 // increment before projectObject(), see #35099
  if xr.enabled && xr.is_presenting {
    if xr.get_depth_sensing_mesh() is Some(depth_sensing_mesh) {
      self.project_object(
        depth_sensing_mesh,
        camera,
        -renderer_infinity,
        self.sort_objects,
      )
    }
  }
  self.project_object(scene, camera, 0.0, self.sort_objects)
  render_list.finish()
  if self._nodes_handler is Some(handler) {
    handler.update_lights(render_state.state.lights_array)
  }
  if self.sort_objects {
    render_list.sort(self._opaque_sort, self._transparent_sort)
  }
  self._render_background = !xr.enabled ||
    !xr.is_presenting ||
    !xr.has_depth_sensing()
  if self._render_background {
    self.background.add_to_render_list(render_list, scene)
  }
  //
  if self.info.auto_reset {
    self.info.reset()
  }
  if self._clipping_enabled {
    self.clipping.begin_shadows()
  }
  let shadows_array = render_state.state.shadows_array
  self.shadow_map.render(shadows_array, scene, camera)
  if self._clipping_enabled {
    self.clipping.end_shadows()
  }
  //
  // render scene (skip if first effect is a render pass - it will render the scene itself)
  let skip_scene_render = use_output && self.output.unwrap().has_render_pass()
  if !skip_scene_render {
    let opaque_objects = render_list.opaque_
    let transmissive_objects = render_list.transmissive
    render_state.setup_lights()
    match camera.kind {
      Camera(
        {
          kind: PerspectiveCamera({ array_camera: Some(array_camera), .. }),
          ..
        }
      ) => {
        let cameras = array_camera.cameras
        if transmissive_objects.length() > 0 {
          for camera2 in cameras {
            self.render_transmission_pass(
              opaque_objects, transmissive_objects, scene, camera2,
            )
          }
        }
        if self._render_background {
          self.background.render(scene)
        }
        for camera2 in cameras {
          self.render_scene(
            render_list,
            scene,
            camera2,
            camera_viewport(camera2),
          )
        }
      }
      _ => {
        if transmissive_objects.length() > 0 {
          self.render_transmission_pass(
            opaque_objects, transmissive_objects, scene, camera,
          )
        }
        if self._render_background {
          self.background.render(scene)
        }
        self.render_scene(render_list, scene, camera, None)
      }
    }
  }
  //
  if self._current_render_target is Some(target) &&
    self._current_active_mipmap_level == 0 {
    // resolve multisample renderbuffers to a single-sample texture if necessary
    self.textures.update_multisample_render_target(target)
    // Generate mipmap if we're using any kind of mipmap filtering
    self.textures.update_render_target_mipmap(target)
  }
  // copy from internal render target to canvas using fullscreen quad
  if use_output {
    self.output.unwrap().end(self)
  }
  //
  if scene.is_scene() {
    (scene.as_scene().on_after_render)(@core.JsValue::of(self), scene, camera)
  }
  // _gl.finish();
  self.binding_states.reset_default_state()
  self._current_material_id = -1
  self._current_camera = None
  ignore(self.render_state_stack.pop())
  if self.render_state_stack.last() is Some(current) {
    self.current_render_state = Some(current)
    self.textures.set_texture_units(current.state.texture_units)
    if self._clipping_enabled {
      self.clipping.set_global_state(
        self.clipping_planes,
        current.state.camera.unwrap(),
      )
    }
  } else {
    self.current_render_state = None
  }
  ignore(self.render_list_stack.pop())
  self.current_render_list = self.render_list_stack.last()
  if self._nodes_handler is Some(handler) {
    handler.render_end()
  }
}

///|
/// `projectObject( object, camera, groupOrder, sortObjects )`.
fn WebGLRenderer::project_object(
  self : WebGLRenderer,
  object : @core.Object3D,
  camera : @core.Object3D,
  group_order : Double,
  sort_objects : Bool,
) -> Unit {
  if !object.visible {
    return
  }
  let mut group_order = group_order
  let visible = object.layers.test_(camera.layers)
  if visible {
    let render_state = self.current_render_state.unwrap()
    let render_list = self.current_render_list.unwrap()
    let frustum : @core.FrustumRef = if camera.is_array_camera() {
      Array(self._frustum_array)
    } else {
      Single(self._frustum)
    }
    if object.is_group() {
      group_order = object.render_order
    } else if object.is_lod() {
      if object.kind is LOD(lod) && lod.auto_update {
        object.update(camera)
      }
    } else if object.is_light() {
      render_state.push_light(object)
      if object.cast_shadow {
        render_state.push_shadow(object)
      }
    } else if object.is_sprite() {
      if !object.frustum_culled || object.intersects_frustum(frustum) {
        if sort_objects {
          ignore(
            self._vector4
            .set_from_matrix_position(object.matrix_world)
            .apply_matrix4(self._proj_screen_matrix),
          )
        }
        let geometry = self.objects.update(object)
        guard object.kind is Sprite(sprite) else { return }
        let material = sprite.material
        if material.visible {
          render_list.push(
            object,
            geometry,
            material,
            group_order,
            self._vector4.z,
            None,
            camera,
          )
        }
      }
    } else if object.is_mesh() || object.is_line() || object.is_points() {
      if !object.frustum_culled || object.intersects_frustum(frustum) {
        let geometry = self.objects.update(object)
        let material = object.get_material().unwrap()
        if sort_objects {
          if object.has_object_bounds() {
            if object.get_bounding_sphere() is None {
              object.compute_bounding_sphere()
            }
            ignore(
              self._vector4.copy_vector3(
                object.get_bounding_sphere().unwrap().center,
              ),
            )
          } else {
            if geometry.bounding_sphere is None {
              geometry.compute_bounding_sphere()
            }
            ignore(
              self._vector4.copy_vector3(
                geometry.bounding_sphere.unwrap().center,
              ),
            )
          }
          ignore(
            self._vector4
            .apply_matrix4(object.matrix_world)
            .apply_matrix4(self._proj_screen_matrix),
          )
        }
        match material {
          Multiple(materials) =>
            for group in geometry.groups {
              if materials.get(group.material_index) is Some(group_material) &&
                group_material.visible {
                render_list.push(
                  object,
                  geometry,
                  group_material,
                  group_order,
                  self._vector4.z,
                  Some(group),
                  camera,
                )
              }
            }
          Single(material) =>
            if material.visible {
              render_list.push(
                object,
                geometry,
                material,
                group_order,
                self._vector4.z,
                None,
                camera,
              )
            }
        }
      }
    }
  }
  let children = object.children
  for i in 0..<children.length() {
    self.project_object(children[i], camera, group_order, sort_objects)
  }
}

///|
/// `renderScene( currentRenderList, scene, camera, viewport )`.
fn WebGLRenderer::render_scene(
  self : WebGLRenderer,
  render_list : WebGLRenderList,
  scene : @core.Object3D,
  camera : @core.Object3D,
  viewport : @math.Vector4?,
) -> Unit {
  let opaque_objects = render_list.opaque_
  let transmissive_objects = render_list.transmissive
  let transparent_objects = render_list.transparent
  self.current_render_state.unwrap().setup_lights_view(camera)
  if self._clipping_enabled {
    self.clipping.set_global_state(self.clipping_planes, camera)
  }
  if viewport is Some(viewport) {
    self.state.viewport(self._current_viewport.copy(viewport))
  }
  if opaque_objects.length() > 0 {
    self.render_objects(opaque_objects, scene, camera)
  }
  if transmissive_objects.length() > 0 {
    self.render_objects(transmissive_objects, scene, camera)
  }
  if transparent_objects.length() > 0 {
    self.render_objects(transparent_objects, scene, camera)
  }
  // Ensure depth buffer writing is enabled so it can be cleared on next render
  self.state.buffers.depth.set_test(true)
  self.state.buffers.depth.set_mask(true)
  self.state.buffers.color.set_mask(true)
  self.state.set_polygon_offset(false)
}

///|
/// `scene.overrideMaterial` of a `Scene`, `null` otherwise.
fn renderer_override_material(scene : @core.Object3D) -> @core.Material? {
  match scene.kind {
    Scene(scene) => scene.override_material
    _ => None
  }
}

///|
/// `renderTransmissionPass( opaqueObjects, transmissiveObjects, scene, camera )`.
fn WebGLRenderer::render_transmission_pass(
  self : WebGLRenderer,
  opaque_objects : Array[RenderItem],
  transmissive_objects : Array[RenderItem],
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  if renderer_override_material(scene) is Some(_) {
    return
  }
  let render_state = self.current_render_state.unwrap()
  let targets = render_state.state.transmission_render_target
  if targets.get(camera.id) is None {
    let has_half_float_support = self.extensions.has(
        "EXT_color_buffer_half_float",
      ) ||
      self.extensions.has("EXT_color_buffer_float")
    targets[camera.id] = WebGLRenderTarget::new(
      width=1,
      height=1,
      generate_mipmaps=true,
      type_=if has_half_float_support {
        @core.HalfFloatType
      } else {
        @core.UnsignedByteType
      },
      min_filter=@core.LinearMipmapLinearFilter,
      // to avoid feedback loops, the transmission render target requires a resolve, see #26177
      samples=if self.capabilities.samples > 4 {
        self.capabilities.samples
      } else {
        4
      },
      stencil_buffer=self.stencil,
      resolve_depth_buffer=false,
      resolve_stencil_buffer=false,
      store_multisampled_depth_buffer=false,
      store_multisampled_stencil_buffer=false,
      color_space=@math.color_management.working_color_space,
    )
  }
  let transmission_render_target = targets[camera.id]
  let active_viewport = match camera_viewport(camera) {
    Some(viewport) => viewport
    None => self._current_viewport
  }
  // `setSize` stores upstream's (possibly fractional) numbers; WebGL truncates them
  transmission_render_target.set_size(
    renderer_to_int32(active_viewport.z * self.transmission_resolution_scale),
    renderer_to_int32(active_viewport.w * self.transmission_resolution_scale),
  )
  //
  let current_render_target = self.get_render_target()
  let current_active_cube_face = self.get_active_cube_face()
  let current_active_mipmap_level = self.get_active_mipmap_level()
  self.set_render_target(Some(transmission_render_target))
  ignore(self.get_clear_color(self._current_clear_color))
  self._current_clear_alpha = self.get_clear_alpha()
  if self._current_clear_alpha < 1.0 {
    self.set_clear_color_hex(0xffffff, alpha=0.5)
  }
  self.clear()
  if self._render_background {
    self.background.render(scene)
  }
  // Turn off the features which can affect the frag color for opaque objects pass.
  // Otherwise they are applied twice in opaque objects pass and transmission objects pass.
  let current_tone_mapping = self.tone_mapping
  self.tone_mapping = @core.NoToneMapping
  // Remove viewport from camera to avoid nested render calls resetting viewport to it (e.g Reflector).
  // Transmission render pass requires viewport to match the transmissionRenderTarget.
  let current_camera_viewport = camera_viewport(camera)
  if current_camera_viewport is Some(_) {
    set_camera_viewport(camera, None)
  }
  render_state.setup_lights_view(camera)
  if self._clipping_enabled {
    self.clipping.set_global_state(self.clipping_planes, camera)
  }
  self.render_objects(opaque_objects, scene, camera)
  self.textures.update_multisample_render_target(transmission_render_target)
  self.textures.update_render_target_mipmap(transmission_render_target)
  if !self.extensions.has("WEBGL_multisampled_render_to_texture") { // see #28131
    let mut render_target_needs_update = false
    for render_item in transmissive_objects {
      let { object, geometry, material, group, .. } = render_item
      if material.side == @core.DoubleSide && object.layers.test_(camera.layers) {
        let current_side = material.side
        material.side = @core.BackSide
        material.set_needs_update(true)
        self.render_object(object, scene, camera, geometry, material, group)
        material.side = current_side
        material.set_needs_update(true)
        render_target_needs_update = true
      }
    }
    if render_target_needs_update {
      self.textures.update_multisample_render_target(transmission_render_target)
      self.textures.update_render_target_mipmap(transmission_render_target)
    }
  }
  self.set_render_target(
    current_render_target,
    active_cube_face=current_active_cube_face,
    active_mipmap_level=current_active_mipmap_level,
  )
  self.set_clear_color(
    self._current_clear_color,
    alpha=self._current_clear_alpha,
  )
  if current_camera_viewport is Some(_) {
    set_camera_viewport(camera, current_camera_viewport)
  }
  self.tone_mapping = current_tone_mapping
}

///|
/// `renderObjects( renderList, scene, camera )`.
fn WebGLRenderer::render_objects(
  self : WebGLRenderer,
  render_list : Array[RenderItem],
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  let override_material = renderer_override_material(scene)
  for i in 0..<render_list.length() {
    let render_item = render_list[i]
    let { object, geometry, group, .. } = render_item
    let mut material = render_item.material
    if material.allow_override && override_material is Some(override_material) {
      material = override_material
    }
    if object.layers.test_(camera.layers) {
      self.render_object(object, scene, camera, geometry, material, group)
    }
  }
}

///|
/// `renderObject( object, scene, camera, geometry, material, group )`.
fn WebGLRenderer::render_object(
  self : WebGLRenderer,
  object : @core.Object3D,
  scene : @core.Object3D,
  camera : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group : @core.GeometryGroup?,
) -> Unit {
  let this = @core.JsValue::of(self)
  if self._nodes_handler is Some(handler) && material.is_node_material() {
    handler.set_object(object, material)
  }
  (object.on_before_render)(this, scene, camera, geometry, material, group)
  ignore(
    object.model_view_matrix.multiply_matrices(
      camera.matrix_world_inverse(),
      object.matrix_world,
    ),
  )
  ignore(object.normal_matrix.get_normal_matrix(object.model_view_matrix))
  (material.on_before_render)(this, scene, camera, geometry, object, group)
  if material.transparent &&
    material.side == @core.DoubleSide &&
    !material.force_single_pass {
    material.side = @core.BackSide
    material.set_needs_update(true)
    self.render_buffer_direct(
      camera,
      Some(scene),
      geometry,
      material,
      object,
      group,
    )
    material.side = @core.FrontSide
    material.set_needs_update(true)
    self.render_buffer_direct(
      camera,
      Some(scene),
      geometry,
      material,
      object,
      group,
    )
    material.side = @core.DoubleSide
  } else {
    self.render_buffer_direct(
      camera,
      Some(scene),
      geometry,
      material,
      object,
      group,
    )
  }
  (object.on_after_render)(this, scene, camera, geometry, material, group)
}

///|
/// The registered `LightProbeGrid` data of `grid`; unregistered objects count as
/// having no texture.
fn renderer_grid_texture(grid : @core.Object3D) -> @core.Texture? {
  match light_probe_grid_of(grid) {
    Some(source) => source.texture()
    None => None
  }
}

///|
/// `countLightProbeGrids( grids )`.
fn renderer_count_light_probe_grids(grids : Array[@core.Object3D]) -> Int32 {
  let mut count = 0
  for grid in grids {
    if renderer_grid_texture(grid) is Some(_) {
      count += 1
    }
  }
  count
}

///|
/// `getProgram( material, scene, object )`.
fn WebGLRenderer::get_program(
  self : WebGLRenderer,
  material : @core.Material,
  scene : @core.Object3D,
  object : @core.Object3D,
) -> WebGLProgram {
  // scene could be a Mesh, Line, Points, ...
  let scene = if scene.is_scene() { scene } else { self._empty_scene }
  let scene_data = scene.as_scene()
  let material_properties = self.properties.get_material(material)
  let render_state = self.current_render_state.unwrap()
  let lights = render_state.state.lights
  let shadows_array = render_state.state.shadows_array
  let lights_state_version = lights.state.version
  let parameters = self.program_cache.get_parameters(
    material,
    lights.state,
    shadows_array,
    scene,
    object,
    render_state.state.light_probe_grid_array,
  )
  let program_cache_key = self.program_cache.get_program_cache_key(parameters)
  // always update environment and fog - changing these trigger an getProgram call, but it's possible that the program doesn't change
  material_properties.environment = if renderer_uses_environment(material) {
    scene_data.environment
  } else {
    None
  }
  material_properties.fog = scene_data.fog
  material_properties.env_map = self.environments.get(
    renderer_texture_or(material.env_map, material_properties.environment),
    use_pmrem=renderer_use_pmrem(material),
  )
  material_properties.env_map_rotation = if material_properties.environment
    is Some(_) &&
    material.env_map is None {
    Some(scene_data.environment_rotation)
  } else {
    material.env_map_rotation
  }
  let programs = match material_properties.programs {
    Some(programs) => programs
    None => {
      // new material
      material.add_event_listener("dispose", self.on_material_dispose)
      let programs = Map([])
      material_properties.programs = Some(programs)
      material_properties.program_variants = Some(Map([]))
      programs
    }
  }
  let program = match programs.get(program_cache_key) {
    Some(program) => {
      // early out if program and light state is identical
      if same_handle(material_properties.current_program, Some(program)) &&
        material_properties.lights_state_version == Some(lights_state_version) {
        self.update_common_material_properties(material, parameters)
        return program
      }
      program
    }
    None => {
      parameters.shader.uniforms = self.program_cache.get_uniforms(material)
      // Use node builder for node materials if available
      if self._nodes_handler is Some(handler) && material.is_node_material() {
        handler.build(material, object, parameters)
      }
      parameters.shader.parameters = @core.JsValue::of(parameters)
      if material.on_before_compile is Some(on_before_compile) {
        on_before_compile(parameters.shader, @core.JsValue::of(self))
      }
      let program = self.program_cache.acquire_program(
        parameters, program_cache_key,
      )
      programs[program_cache_key] = program
      material_properties.uniforms = Some(parameters.shader.uniforms)
      program
    }
  }
  let uniforms = material_properties.uniforms.unwrap()
  if (!material.is_shader_material() && !material.is_raw_shader_material()) ||
    material.clipping == Some(true) {
    uniforms["clippingPlanes"] = self.clipping.uniform
  }
  self.update_common_material_properties(material, parameters)
  // store the light setup it was created for
  material_properties.needs_lights = renderer_material_needs_lights(material)
  material_properties.lights_state_version = Some(lights_state_version)
  if material_properties.needs_lights {
    // wire up the material to this renderer's lighting state
    let s = lights.state
    renderer_set_uniform(uniforms, "ambientLightColor", Numbers(s.ambient))
    renderer_set_uniform(uniforms, "lightProbe", Array(s.probe))
    renderer_set_uniform(uniforms, "sunLights", Array(s.sun))
    renderer_set_uniform(uniforms, "sunLightShadows", Array(s.sun_shadow))
    renderer_set_uniform(uniforms, "directionalLights", Array(s.directional))
    renderer_set_uniform(
      uniforms,
      "directionalLightShadows",
      Array(s.directional_shadow),
    )
    renderer_set_uniform(uniforms, "spotLights", Array(s.spot))
    renderer_set_uniform(uniforms, "spotLightShadows", Array(s.spot_shadow))
    renderer_set_uniform(uniforms, "rectAreaLights", Array(s.rect_area))
    renderer_set_uniform(
      uniforms,
      "ltc_1",
      renderer_texture_value(s.rect_area_ltc1),
    )
    renderer_set_uniform(
      uniforms,
      "ltc_2",
      renderer_texture_value(s.rect_area_ltc2),
    )
    renderer_set_uniform(uniforms, "pointLights", Array(s.point))
    renderer_set_uniform(uniforms, "pointLightShadows", Array(s.point_shadow))
    renderer_set_uniform(uniforms, "hemisphereLights", Array(s.hemi))
    renderer_set_uniform(
      uniforms,
      "sunShadowMatrix",
      Array(s.sun_shadow_matrix),
    )
    renderer_set_uniform(
      uniforms,
      "sunShadowCascade",
      Array(s.sun_shadow_cascade),
    )
    renderer_set_uniform(
      uniforms,
      "directionalShadowMatrix",
      Array(s.directional_shadow_matrix),
    )
    renderer_set_uniform(
      uniforms,
      "spotLightMatrix",
      Array(s.spot_light_matrix),
    )
    renderer_set_uniform(uniforms, "spotLightMap", Array(s.spot_light_map))
    renderer_set_uniform(
      uniforms,
      "pointShadowMatrix",
      Array(s.point_shadow_matrix),
    )
    // TODO (abelnation): add area lights shadow info to uniforms
  }
  material_properties.num_light_probe_grids = Some(
    renderer_count_light_probe_grids(render_state.state.light_probe_grid_array),
  )
  material_properties.current_program = Some(program)
  material_properties.uniforms_list = None
  program
}

///|
/// `getProgramVariant( material, scene, object, colorSpace, toneMapping )`.
fn WebGLRenderer::get_program_variant(
  self : WebGLRenderer,
  material : @core.Material,
  scene : @core.Object3D,
  object : @core.Object3D,
  color_space : String,
  tone_mapping : Int32,
) -> WebGLProgram {
  let material_properties = self.properties.get_material(material)
  let program_variant_key = material_properties.current_program.unwrap().id.to_string() +
    "," +
    color_space +
    "," +
    tone_mapping.to_string()
  let program_variants = material_properties.program_variants.unwrap()
  match program_variants.get(program_variant_key) {
    None => {
      let program = self.get_program(material, scene, object)
      program_variants[program_variant_key] = program
      program
    }
    Some(program) => {
      material_properties.current_program = Some(program)
      material_properties.uniforms_list = None
      material_properties.output_color_space = Some(color_space)
      material_properties.tone_mapping = Some(tone_mapping)
      program
    }
  }
}

///|
/// `getUniformList( materialProperties )`.
fn renderer_get_uniform_list(
  material_properties : MaterialProperties,
) -> Array[WebGLUniformSetter] {
  match material_properties.uniforms_list {
    Some(list) => list
    None => {
      let prog_uniforms = material_properties.current_program
        .unwrap()
        .get_uniforms()
      let list = WebGLUniforms::seq_with_value(
        prog_uniforms.seq,
        material_properties.uniforms.unwrap(),
      )
      material_properties.uniforms_list = Some(list)
      list
    }
  }
}

///|
/// `updateCommonMaterialProperties( material, parameters )`.
fn WebGLRenderer::update_common_material_properties(
  self : WebGLRenderer,
  material : @core.Material,
  parameters : WebGLProgramParameters,
) -> Unit {
  let material_properties = self.properties.get_material(material)
  material_properties.output_color_space = Some(parameters.output_color_space)
  material_properties.batching = Some(parameters.batching)
  material_properties.batching_color = Some(parameters.batching_color)
  material_properties.instancing = Some(parameters.instancing)
  material_properties.instancing_color = Some(parameters.instancing_color)
  material_properties.instancing_morph = Some(parameters.instancing_morph)
  material_properties.skinning = Some(parameters.skinning)
  material_properties.morph_targets = Some(parameters.morph_targets)
  material_properties.morph_normals = Some(parameters.morph_normals)
  material_properties.morph_colors = Some(parameters.morph_colors)
  material_properties.morph_targets_count = Some(parameters.morph_targets_count)
  material_properties.num_clipping_planes = Some(parameters.num_clipping_planes)
  material_properties.num_intersection = Some(parameters.num_clip_intersection)
  material_properties.vertex_alphas = Some(parameters.vertex_alphas)
  material_properties.vertex_tangents = Some(parameters.vertex_tangents)
  material_properties.tone_mapping = Some(parameters.tone_mapping)
}

///|
/// `setProgram( camera, scene, geometry, material, object )`.
fn WebGLRenderer::set_program(
  self : WebGLRenderer,
  camera : @core.Object3D,
  scene : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  object : @core.Object3D,
) -> WebGLProgram {
  // scene could be a Mesh, Line, Points, ...
  let scene = if scene.is_scene() { scene } else { self._empty_scene }
  let scene_data = scene.as_scene()
  let gl = self._gl
  let textures = self.textures
  textures.reset_texture_units()
  let fog = scene_data.fog
  let environment = if renderer_uses_environment(material) {
    scene_data.environment
  } else {
    None
  }
  let color_space = match self._current_render_target {
    None => self.output_color_space()
    Some(target) =>
      if target.has_extension_flag("isXRRenderTarget") {
        target.texture().color_space
      } else {
        @math.color_management.working_color_space
      }
  }
  let env_map = self.environments.get(
    renderer_texture_or(material.env_map, environment),
    use_pmrem=renderer_use_pmrem(material),
  )
  let vertex_alphas = material.vertex_colors &&
    (match geometry.attributes.get("color") {
      Some(color) => color.item_size() == 4
      None => false
    })
  let vertex_tangents = geometry.attributes.contains("tangent") &&
    (
      material.normal_map is Some(_) ||
      (match material.anisotropy() {
        Some(anisotropy) => anisotropy > 0.0
        None => false
      })
    )
  let morph_attributes = geometry.morph_attributes
  let morph_targets = morph_attributes.contains("position")
  let morph_normals = morph_attributes.contains("normal")
  let morph_colors = morph_attributes.contains("color")
  let mut tone_mapping = @core.NoToneMapping
  if material.tone_mapped {
    match self._current_render_target {
      None => tone_mapping = self.tone_mapping
      Some(target) =>
        if target.has_extension_flag("isXRRenderTarget") {
          tone_mapping = self.tone_mapping
        }
    }
  }
  let morph_attribute = match morph_attributes.get("position") {
    Some(a) => Some(a)
    None =>
      match morph_attributes.get("normal") {
        Some(a) => Some(a)
        None => morph_attributes.get("color")
      }
  }
  let morph_targets_count = match morph_attribute {
    Some(attribute) => attribute.length()
    None => 0
  }
  let material_properties = self.properties.get_material(material)
  let render_state = self.current_render_state.unwrap()
  let lights = render_state.state.lights
  if self._clipping_enabled {
    let same_camera = same_handle(Some(camera), self._current_camera)
    if self._local_clipping_enabled || !same_camera {
      let use_cache = same_camera && material.id == self._current_material_id
      // we might want to call this function with some ClippingGroup
      // object instead of the material, once it becomes feasible
      // (#8465, #8379)
      self.clipping.set_state(material, camera, use_cache)
    }
  }
  //
  let mut needs_program_change = false
  let mut needs_program_variant = false
  let is_batched = object.is_batched_mesh()
  let is_instanced = object.is_instanced_mesh()
  let is_skinned = object.is_skinned_mesh()
  let batched_colors_texture = match object.kind {
    Mesh({ kind: BatchedMesh(batched), .. }) => batched._colors_texture
    _ => None
  }
  let (instance_color, morph_texture) = match object.kind {
    Mesh({ kind: InstancedMesh(instanced), .. }) =>
      (instanced.instance_color is Some(_), instanced.morph_texture is Some(_))
    _ => (false, false)
  }
  if material_properties.__version == Some(material.version) {
    if material_properties.needs_lights &&
      material_properties.lights_state_version != Some(lights.state.version) {
      needs_program_change = true
    } else if is_batched && material_properties.batching == Some(false) {
      needs_program_change = true
    } else if !is_batched && material_properties.batching == Some(true) {
      needs_program_change = true
    } else if is_batched &&
      material_properties.batching_color == Some(true) &&
      batched_colors_texture is None {
      needs_program_change = true
    } else if is_batched &&
      material_properties.batching_color == Some(false) &&
      batched_colors_texture is Some(_) {
      needs_program_change = true
    } else if is_instanced && material_properties.instancing == Some(false) {
      needs_program_change = true
    } else if !is_instanced && material_properties.instancing == Some(true) {
      needs_program_change = true
    } else if is_skinned && material_properties.skinning == Some(false) {
      needs_program_change = true
    } else if !is_skinned && material_properties.skinning == Some(true) {
      needs_program_change = true
    } else if is_instanced &&
      material_properties.instancing_color == Some(true) &&
      !instance_color {
      needs_program_change = true
    } else if is_instanced &&
      material_properties.instancing_color == Some(false) &&
      instance_color {
      needs_program_change = true
    } else if is_instanced &&
      material_properties.instancing_morph == Some(true) &&
      !morph_texture {
      needs_program_change = true
    } else if is_instanced &&
      material_properties.instancing_morph == Some(false) &&
      morph_texture {
      needs_program_change = true
    } else if !same_handle(material_properties.env_map, env_map) {
      needs_program_change = true
    } else if material.fog == Some(true) &&
      !renderer_same_fog(material_properties.fog, fog) {
      needs_program_change = true
    } else if material_properties.num_clipping_planes is Some(num_planes) &&
      (
        num_planes != self.clipping.num_planes ||
        material_properties.num_intersection !=
        Some(self.clipping.num_intersection)
      ) {
      needs_program_change = true
    } else if material_properties.vertex_alphas != Some(vertex_alphas) {
      needs_program_change = true
    } else if material_properties.vertex_tangents != Some(vertex_tangents) {
      needs_program_change = true
    } else if material_properties.morph_targets != Some(morph_targets) {
      needs_program_change = true
    } else if material_properties.morph_normals != Some(morph_normals) {
      needs_program_change = true
    } else if material_properties.morph_colors != Some(morph_colors) {
      needs_program_change = true
    } else if material_properties.morph_targets_count !=
      Some(morph_targets_count) {
      needs_program_change = true
    } else if material_properties.num_light_probe_grids !=
      Some(
        renderer_count_light_probe_grids(
          render_state.state.light_probe_grid_array,
        ),
      ) {
      needs_program_change = true
    } else if material_properties.output_color_space != Some(color_space) ||
      material_properties.tone_mapping != Some(tone_mapping) {
      needs_program_variant = true
    }
  } else {
    needs_program_change = true
    material_properties.__version = Some(material.version)
  }
  //
  let mut program = material_properties.current_program
  if needs_program_change || needs_program_variant {
    let new_program = if needs_program_variant {
      self.get_program_variant(
        material, scene, object, color_space, tone_mapping,
      )
    } else {
      self.get_program(material, scene, object)
    }
    program = Some(new_program)
    // notify the node builder that the program has changed so uniforms and update nodes can
    // be cached and triggered.
    if self._nodes_handler is Some(handler) && material.is_node_material() {
      handler.on_update_program(material, new_program, material_properties)
    }
  }
  let program = program.unwrap()
  let mut refresh_program = false
  let mut refresh_material = false
  let mut refresh_lights = false
  let p_uniforms = program.get_uniforms()
  let m_uniforms = material_properties.uniforms.unwrap()
  if self.state.use_program(program.program) {
    refresh_program = true
    refresh_material = true
    refresh_lights = true
  }
  if material.id != self._current_material_id {
    self._current_material_id = material.id
    refresh_material = true
  }
  if refresh_program || !same_handle(self._current_camera, Some(camera)) {
    // common camera uniforms
    let reversed_depth_buffer = self.state.buffers.depth.get_reversed()
    if reversed_depth_buffer && !camera.reversed_depth() {
      if camera.kind is Camera(camera_data) {
        camera_data._reversed_depth = true
      }
      camera.update_projection_matrix()
    }
    p_uniforms.set_value(
      gl,
      "projectionMatrix",
      Matrix4(camera.projection_matrix()),
    )
    p_uniforms.set_value(
      gl,
      "viewMatrix",
      Matrix4(camera.matrix_world_inverse()),
    )
    if p_uniforms.map.get("cameraPosition") is Some(u_cam_pos) {
      u_cam_pos.set_value(
        gl,
        Vector3(self._vector3.set_from_matrix_position(camera.matrix_world)),
      )
    }
    if self.capabilities.logarithmic_depth_buffer {
      p_uniforms.set_value(
        gl,
        "logDepthBufFC",
        Number(
          2.0 /
          (
            renderer_math_log(renderer_camera_far(camera) + 1.0) /
            renderer_math_ln2()
          ),
        ),
      )
    }
    // consider moving isOrthographic to UniformLib and WebGLMaterials, see https://github.com/mrdoob/three.js/pull/26467#issuecomment-1645185067
    if material.is_mesh_phong_material() ||
      material.is_mesh_toon_material() ||
      material.is_mesh_lambert_material() ||
      material.is_mesh_basic_material() ||
      material.is_mesh_standard_material() ||
      material.is_shader_material() {
      p_uniforms.set_value(
        gl,
        "isOrthographic",
        Bool(camera.is_orthographic_camera()),
      )
    }
    if !same_handle(self._current_camera, Some(camera)) {
      self._current_camera = Some(camera)
      // lighting uniforms depend on the camera so enforce an update
      // now, in case this material supports lights - or later, when
      // the next material that does gets activated:
      refresh_material = true // set to true on material change
      refresh_lights = true // remains set until update done
    }
  }
  // Pre-allocate texture units for shadow samplers before setting data textures
  if material_properties.needs_lights {
    // Set shadow map uniforms first to ensure they get the first texture units
    let s = lights.state
    if s.sun_shadow_map.length() > 0 {
      p_uniforms.set_value(
        gl,
        "sunShadowMap",
        Array(s.sun_shadow_map),
        textures~,
      )
    }
    if s.directional_shadow_map.length() > 0 {
      p_uniforms.set_value(
        gl,
        "directionalShadowMap",
        Array(s.directional_shadow_map),
        textures~,
      )
    }
    if s.spot_shadow_map.length() > 0 {
      p_uniforms.set_value(
        gl,
        "spotShadowMap",
        Array(s.spot_shadow_map),
        textures~,
      )
    }
    if s.point_shadow_map.length() > 0 {
      p_uniforms.set_value(
        gl,
        "pointShadowMap",
        Array(s.point_shadow_map),
        textures~,
      )
    }
  }
  // skinning and morph target uniforms must be set even if material didn't change
  // auto-setting of texture unit for bone and morph texture must go before other textures
  // otherwise textures used for skinning and morphing can take over texture units reserved for other material textures
  match object.kind {
    Mesh({ kind: SkinnedMesh(skinned), .. }) => {
      p_uniforms.set_optional(gl, object, "bindMatrix")
      p_uniforms.set_optional(gl, object, "bindMatrixInverse")
      if skinned.skeleton is Some(skeleton) {
        if skeleton.bone_texture is None {
          ignore(skeleton.compute_bone_texture())
        }
        p_uniforms.set_value(
          gl,
          "boneTexture",
          renderer_texture_value(skeleton.bone_texture),
          textures~,
        )
      }
    }
    Mesh({ kind: BatchedMesh(batched), .. }) => {
      p_uniforms.set_optional(gl, object, "batchingTexture")
      p_uniforms.set_value(
        gl,
        "batchingTexture",
        renderer_texture_value(batched._matrices_texture),
        textures~,
      )
      p_uniforms.set_optional(gl, object, "batchingIdTexture")
      p_uniforms.set_value(
        gl,
        "batchingIdTexture",
        renderer_texture_value(batched._indirect_texture),
        textures~,
      )
      p_uniforms.set_optional(gl, object, "batchingColorTexture")
      if batched._colors_texture is Some(colors_texture) {
        p_uniforms.set_value(
          gl,
          "batchingColorTexture",
          Texture(colors_texture),
          textures~,
        )
      }
    }
    _ => ()
  }
  if morph_attributes.contains("position") ||
    morph_attributes.contains("normal") ||
    morph_attributes.contains("color") {
    self.morphtargets.update(object, geometry, program)
  }
  if refresh_material ||
    material_properties.receive_shadow != Some(object.receive_shadow) {
    material_properties.receive_shadow = Some(object.receive_shadow)
    p_uniforms.set_value(gl, "receiveShadow", Bool(object.receive_shadow))
  }
  if renderer_uses_environment(material) &&
    material.env_map is None &&
    scene_data.environment is Some(_) {
    renderer_set_uniform(
      m_uniforms,
      "envMapIntensity",
      Number(scene_data.environment_intensity),
    )
  }
  // Set DFG LUT for physically-based materials
  if m_uniforms.get("dfgLUT") is Some(dfg_lut) {
    dfg_lut.value = Texture(@shaders.get_dfg_lut())
  }
  if refresh_material {
    p_uniforms.set_value(
      gl,
      "toneMappingExposure",
      Number(self.tone_mapping_exposure),
    )
    if material_properties.needs_lights {
      // the current material requires lighting info

      // note: all lighting uniforms are always set correctly
      // they simply reference the renderer's state for their
      // values
      //
      // use the current material's .needsUpdate flags to set
      // the GL state when required
      renderer_mark_uniforms_lights_needs_update(m_uniforms, refresh_lights)
    }
    // refresh uniforms common to several materials
    if fog is Some(fog) && material.fog == Some(true) {
      self.materials.refresh_fog_uniforms(m_uniforms, fog)
    }
    self.materials.refresh_material_uniforms(
      m_uniforms,
      material,
      self._pixel_ratio,
      self._height,
      render_state.state.transmission_render_target.get(camera.id),
    )
    // light probe volume
    if material_properties.needs_lights &&
      material_properties.num_light_probe_grids.unwrap_or(0) > 0 {
      let grids = self.light_probe_grid_uniforms
      let mut count = 0
      for grid in render_state.state.light_probe_grid_array {
        guard light_probe_grid_of(grid) is Some(source) else { continue }
        guard source.texture() is Some(texture) else { continue }
        renderer_array_assign(grids.textures, count, Texture(texture))
        renderer_array_assign(
          grids.min,
          count,
          Vector3(source.bounding_box().min),
        )
        renderer_array_assign(
          grids.max,
          count,
          Vector3(source.bounding_box().max),
        )
        renderer_array_assign(
          grids.resolution,
          count,
          Vector3(source.resolution()),
        )
        count += 1
      }
      truncate_array(grids.textures, count)
      truncate_array(grids.min, count)
      truncate_array(grids.max, count)
      truncate_array(grids.resolution, count)
      renderer_set_uniform(m_uniforms, "probesSH", Array(grids.textures))
      renderer_set_uniform(m_uniforms, "probesMin", Array(grids.min))
      renderer_set_uniform(m_uniforms, "probesMax", Array(grids.max))
      renderer_set_uniform(
        m_uniforms,
        "probesResolution",
        Array(grids.resolution),
      )
    }
    WebGLUniforms::upload(
      gl,
      renderer_get_uniform_list(material_properties),
      m_uniforms,
      textures,
    )
  }
  if material.is_shader_material() &&
    material.uniforms_need_update == Some(true) {
    WebGLUniforms::upload(
      gl,
      renderer_get_uniform_list(material_properties),
      m_uniforms,
      textures,
    )
    material.uniforms_need_update = Some(false)
  }
  if material.is_sprite_material() {
    match object.kind {
      Sprite(sprite) =>
        p_uniforms.set_value(gl, "center", Vector2(sprite.center))
      // upstream reads `object.center`, undefined on other objects
      _ => p_uniforms.set_value(gl, "center", Null)
    }
  }
  // common matrices
  p_uniforms.set_value(gl, "modelViewMatrix", Matrix4(object.model_view_matrix))
  p_uniforms.set_value(gl, "normalMatrix", Matrix3(object.normal_matrix))
  p_uniforms.set_value(gl, "modelMatrix", Matrix4(object.matrix_world))
  // UBOs
  if material.uniforms_groups is Some(groups) {
    for group in groups {
      self.uniforms_groups.update(group, program)
      self.uniforms_groups.bind(group, program)
    }
  }
  program
}

///|
/// `markUniformsLightsNeedsUpdate( uniforms, value )`: if uniforms are marked as clean,
/// they don't need to be loaded to the GPU.
fn renderer_mark_uniforms_lights_needs_update(
  uniforms : Map[String, @core.Uniform],
  value : Bool,
) -> Unit {
  for
    name in [
      "ambientLightColor", "lightProbe", "sunLights", "sunLightShadows", "directionalLights",
      "directionalLightShadows", "pointLights", "pointLightShadows", "spotLights",
      "spotLightShadows", "rectAreaLights", "hemisphereLights",
    ] {
    set_uniform_needs_update(renderer_uniform(uniforms, name), value)
  }
}

// ---------------------------------------------------------------------------
// render targets

///|
/// `renderer.getActiveCubeFace()`.
pub fn WebGLRenderer::get_active_cube_face(self : WebGLRenderer) -> Int32 {
  self._current_active_cube_face
}

///|
/// `renderer.getActiveMipmapLevel()`.
pub fn WebGLRenderer::get_active_mipmap_level(self : WebGLRenderer) -> Int32 {
  self._current_active_mipmap_level
}

///|
/// `renderer.getRenderTarget()`.
pub fn WebGLRenderer::get_render_target(
  self : WebGLRenderer,
) -> @core.RenderTarget? {
  self._current_render_target
}

///|
/// `renderer.setRenderTargetTextures( renderTarget, colorTexture, depthTexture )`.
pub fn WebGLRenderer::set_render_target_textures(
  self : WebGLRenderer,
  render_target : @core.RenderTarget,
  color_texture : GLTexture?,
  depth_texture : GLTexture?,
) -> Unit {
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  render_target_properties.__auto_allocate_depth_buffer = !render_target.resolve_depth_buffer
  if !render_target_properties.__auto_allocate_depth_buffer {
    // The multisample_render_to_texture extension doesn't work properly if there
    // are midframe flushes and an external depth buffer. Disable use of the extension.
    render_target_properties.__use_render_to_texture = Some(false)
  }
  self.properties.get_texture(render_target.texture()).__webgl_texture = color_texture
  // upstream's `properties.get( null )` throws when there is no depth texture
  let target_depth_texture = match render_target.depth_texture() {
    Some(texture) => texture
    None => abort("WebGLRenderer.setRenderTargetTextures: no depthTexture")
  }
  self.properties.get_texture(target_depth_texture).__webgl_texture = if render_target_properties.__auto_allocate_depth_buffer {
    None
  } else {
    depth_texture
  }
  render_target_properties.__has_external_textures = true
}

///|
/// `renderer.setRenderTargetFramebuffer( renderTarget, defaultFramebuffer )`.
pub fn WebGLRenderer::set_render_target_framebuffer(
  self : WebGLRenderer,
  render_target : @core.RenderTarget,
  default_framebuffer : GLFramebuffer?,
) -> Unit {
  let render_target_properties = self.properties.get_render_target(
    render_target,
  )
  // `None` is upstream's `null`; this binding cannot pass `undefined`
  render_target_properties.__webgl_framebuffer = Some(
    Framebuffer(default_framebuffer),
  )
  render_target_properties.__use_default_framebuffer = Some(false)
}

///|
/// `renderer.setRenderTarget( renderTarget, activeCubeFace, activeMipmapLevel )`.
pub fn WebGLRenderer::set_render_target(
  self : WebGLRenderer,
  render_target : @core.RenderTarget?,
  active_cube_face~ : Int32 = 0,
  active_mipmap_level~ : Int32 = 0,
) -> Unit {
  let gl = self._gl
  let state = self.state
  self._current_render_target = render_target
  self._current_active_cube_face = active_cube_face
  self._current_active_mipmap_level = active_mipmap_level
  let mut framebuffer : GLFramebuffer? = None
  let mut is_cube = false
  let mut is_render_target_3d = false
  match render_target {
    Some(render_target) => {
      let render_target_properties = self.properties.get_render_target(
        render_target,
      )
      if render_target_properties.__use_default_framebuffer is Some(_) {
        // Externally-managed framebuffer (e.g. XR)
        // Bind to the stored framebuffer (may be null for default, or a WebGLFramebuffer)
        ignore(
          state.bind_framebuffer(
            GL_FRAMEBUFFER,
            renderer_slot_framebuffer(
              render_target_properties.__webgl_framebuffer,
            ),
          ),
        )
        ignore(self._current_viewport.copy(render_target.viewport))
        ignore(self._current_scissor.copy(render_target.scissor))
        self._current_scissor_test = Some(render_target.scissor_test)
        state.viewport(self._current_viewport)
        state.scissor(self._current_scissor)
        state.set_scissor_test(render_target.scissor_test)
        self._current_material_id = -1
        return
      } else if render_target_properties.__webgl_framebuffer is None {
        self.textures.setup_render_target(render_target)
      } else if render_target_properties.__has_external_textures {
        // Color and depth texture must be rebound in order for the swapchain to update.
        let depth_texture = match render_target.depth_texture() {
          Some(texture) => self.properties.get_texture(texture).__webgl_texture
          None => None
        }
        self.textures.rebind_textures(
          render_target,
          self.properties.get_texture(render_target.texture()).__webgl_texture,
          depth_texture,
        )
      } else if render_target.depth_buffer {
        // check if the depth texture is already bound to the frame buffer and that it's been initialized
        let depth_texture = render_target.depth_texture()
        let bound = match render_target_properties.__bound_depth_texture {
          None => false
          Some(bound) => same_handle(bound, depth_texture)
        }
        if !bound {
          // check if the depth texture is compatible
          if depth_texture is Some(depth_texture) &&
            self.properties.has(depth_texture) &&
            (
              render_target.width.to_double() != depth_texture.width() ||
              render_target.height.to_double() != depth_texture.height()
            ) {
            abort(
              "THREE.WebGLRenderer: Attached DepthTexture is initialized to the incorrect size.",
            )
          }
          // Swap the depth buffer to the currently attached one
          self.textures.setup_depth_renderbuffer(render_target)
        }
      }
      let texture = render_target.texture()
      if texture.texture_type
        is (Data3DTexture | DataArrayTexture | CompressedArrayTexture) {
        is_render_target_3d = true
      }
      let __webgl_framebuffer = self.properties.get_render_target(render_target).__webgl_framebuffer
      if render_target.has_extension_flag("isWebGLCubeRenderTarget") {
        framebuffer = match __webgl_framebuffer {
          Some(CubeFaces(faces)) =>
            match faces[active_cube_face] {
              Mipmaps(levels) => Some(levels[active_mipmap_level])
              Framebuffer(framebuffer) => framebuffer
              CubeFaces(_) => abort("WebGLRenderer: invalid cube framebuffer")
            }
          slot => renderer_slot_framebuffer(slot)
        }
        is_cube = true
      } else if render_target.samples > 0 &&
        !self.textures.use_multisampled_rtt(render_target) {
        framebuffer = self.properties.get_render_target(render_target).__webgl_multisampled_framebuffer
      } else {
        framebuffer = match __webgl_framebuffer {
          Some(Mipmaps(levels)) => Some(levels[active_mipmap_level])
          slot => renderer_slot_framebuffer(slot)
        }
      }
      ignore(self._current_viewport.copy(render_target.viewport))
      ignore(self._current_scissor.copy(render_target.scissor))
      self._current_scissor_test = Some(render_target.scissor_test)
    }
    None => {
      ignore(
        self._current_viewport
        .copy(self._viewport)
        .multiply_scalar(self._pixel_ratio)
        .floor(),
      )
      ignore(
        self._current_scissor
        .copy(self._scissor)
        .multiply_scalar(self._pixel_ratio)
        .floor(),
      )
      self._current_scissor_test = Some(self._scissor_test)
    }
  }
  // Use a scratch frame buffer if rendering to a mip level to avoid depth buffers
  // being bound that are different sizes.
  if active_mipmap_level != 0 {
    framebuffer = Some(self._scratch_framebuffer)
  }
  let framebuffer_bound = state.bind_framebuffer(GL_FRAMEBUFFER, framebuffer)
  if framebuffer_bound {
    state.draw_buffers(render_target, framebuffer)
  }
  state.viewport(self._current_viewport)
  state.scissor(self._current_scissor)
  state.set_scissor_test(self._current_scissor_test.unwrap())
  if is_cube {
    let texture_properties = self.properties.get_texture(
      render_target.unwrap().texture(),
    )
    gl.framebuffer_texture2d(
      GL_FRAMEBUFFER,
      GL_COLOR_ATTACHMENT0,
      GL_TEXTURE_CUBE_MAP_POSITIVE_X + active_cube_face,
      texture_properties.__webgl_texture,
      active_mipmap_level,
    )
  } else if is_render_target_3d {
    let layer = active_cube_face
    let textures = render_target.unwrap().textures
    for i in 0..<textures.length() {
      let texture_properties = self.properties.get_texture(textures[i])
      gl.framebuffer_texture_layer(
        GL_FRAMEBUFFER,
        GL_COLOR_ATTACHMENT0 + i,
        texture_properties.__webgl_texture,
        active_mipmap_level,
        layer,
      )
    }
  } else if render_target is Some(render_target) && active_mipmap_level != 0 {
    // Only bind the frame buffer if we are using a scratch frame buffer to render to a mipmap.
    // If we rebind the texture when using a multi sample buffer then an error about inconsistent samples will be thrown.
    let texture_properties = self.properties.get_texture(
      render_target.texture(),
    )
    gl.framebuffer_texture2d(
      GL_FRAMEBUFFER,
      GL_COLOR_ATTACHMENT0,
      GL_TEXTURE_2D,
      texture_properties.__webgl_texture,
      active_mipmap_level,
    )
  }
  self._current_material_id = -1 // reset current material to ensure correct uniform bindings
}

///|
/// `getReadableState( texture )`.
fn WebGLRenderer::get_readable_state(
  self : WebGLRenderer,
  texture : @core.Texture,
) -> TextureProperties {
  let texture_properties = self.properties.get_texture(texture)
  if texture_properties.__read_format != Some(texture.format) ||
    texture_properties.__read_type != Some(texture.type_) {
    texture_properties.__read_format = Some(texture.format)
    texture_properties.__read_type = Some(texture.type_)
    texture_properties.__format_readable = self.capabilities.texture_format_readable(
      texture.format,
    )
    texture_properties.__type_readable = self.capabilities.texture_type_readable(
      texture.type_,
    )
  }
  texture_properties
}

///|
/// The `__webglFramebuffer` `readRenderTargetPixels` reads from.
fn WebGLRenderer::read_framebuffer_slot(
  self : WebGLRenderer,
  render_target : @core.RenderTarget,
  active_cube_face_index : Int32?,
) -> WebGLFramebufferSlot? {
  let framebuffer = self.properties.get_render_target(render_target).__webgl_framebuffer
  if render_target.has_extension_flag("isWebGLCubeRenderTarget") &&
    active_cube_face_index is Some(face) {
    match framebuffer {
      Some(CubeFaces(faces)) =>
        match faces[face] {
          // Custom mip chains store one framebuffer per level; read level 0.
          Mipmaps(levels) => Some(Framebuffer(Some(levels[0])))
          slot => Some(slot)
        }
      // `framebuffer[ index ]` of a single framebuffer is undefined
      _ => None
    }
  } else {
    framebuffer
  }
}

///|
/// The framebuffer of the current render target, `null` for the canvas.
fn WebGLRenderer::current_framebuffer(self : WebGLRenderer) -> GLFramebuffer? {
  match self._current_render_target {
    Some(target) =>
      renderer_slot_framebuffer(
        self.properties.get_render_target(target).__webgl_framebuffer,
      )
    None => None
  }
}

///|
/// `renderer.readRenderTargetPixels( renderTarget, x, y, width, height, buffer,
/// activeCubeFaceIndex, textureIndex )`.
pub fn WebGLRenderer::read_render_target_pixels(
  self : WebGLRenderer,
  render_target : @core.RenderTarget,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  buffer : @core.TypedArray,
  active_cube_face_index? : Int32,
  texture_index~ : Int32 = 0,
) -> Unit {
  if !render_target.has_extension_flag("isWebGLRenderTarget") {
    @core.error(
      "WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.",
    )
    return
  }
  let gl = self._gl
  let framebuffer = self.read_framebuffer_slot(
    render_target, active_cube_face_index,
  )
  if renderer_slot_truthy(framebuffer) {
    ignore(
      self.state.bind_framebuffer(
        GL_FRAMEBUFFER,
        renderer_slot_framebuffer(framebuffer),
      ),
    )
    // try { ... } finally { restore }
    fn read() -> Unit {
      let texture = render_target.textures[texture_index]
      let texture_format = texture.format
      let texture_type = texture.type_
      // when using MRT, select the correct color buffer for the subsequent read command
      if render_target.textures.length() > 1 {
        gl.read_buffer(GL_COLOR_ATTACHMENT0 + texture_index)
      }
      let readable_state = self.get_readable_state(texture)
      if !readable_state.__format_readable {
        @core.error(
          "WebGLRenderer.readRenderTargetPixels: renderTarget is not in RGBA or implementation defined format.",
        )
        return
      }
      if !readable_state.__type_readable {
        @core.error(
          "WebGLRenderer.readRenderTargetPixels: renderTarget is not in UnsignedByteType or implementation defined type.",
        )
        return
      }
      // the following if statement ensures valid read requests (no out-of-bounds pixels, see #8604)
      if x >= 0 &&
        x <= render_target.width - width &&
        y >= 0 &&
        y <= render_target.height - height {
        gl.read_pixels(
          x,
          y,
          width,
          height,
          self.utils.convert(texture_format).unwrap_or(0),
          self.utils.convert(texture_type).unwrap_or(0),
          buffer,
        )
      }
    }

    read()
    // restore framebuffer of current render target if necessary
    ignore(
      self.state.bind_framebuffer(GL_FRAMEBUFFER, self.current_framebuffer()),
    )
  }
}

///|
/// `probeAsync( gl, sync, interval )` from src/utils.js, with callbacks.
fn renderer_probe_async(
  gl : WebGL2RenderingContext,
  sync : GLSync,
  interval : Double,
  resolve : () -> Unit,
  reject : () -> Unit,
) -> Unit {
  fn probe() -> Unit {
    let status = gl.client_wait_sync(sync, GL_SYNC_FLUSH_COMMANDS_BIT, 0.0)
    if status == GL_WAIT_FAILED {
      reject()
    } else if status == GL_TIMEOUT_EXPIRED {
      set_timeout(probe, interval)
    } else {
      resolve()
    }
  }

  set_timeout(probe, interval)
}

///|
/// `renderer.readRenderTargetPixelsAsync( ... )`; the `Promise` resolution is
/// `on_done( buffer )`, a rejection `on_error()`.
pub fn WebGLRenderer::read_render_target_pixels_async(
  self : WebGLRenderer,
  render_target : @core.RenderTarget,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  buffer : @core.TypedArray,
  on_done : (@core.TypedArray) -> Unit,
  on_error? : () -> Unit,
  active_cube_face_index? : Int32,
  texture_index~ : Int32 = 0,
) -> Unit {
  let reject = () => if on_error is Some(on_error) { on_error() }
  if !render_target.has_extension_flag("isWebGLRenderTarget") {
    @core.error(
      "WebGLRenderer.readRenderTargetPixels: renderTarget is not THREE.WebGLRenderTarget.",
    )
    reject()
    return
  }
  let gl = self._gl
  let framebuffer = self.read_framebuffer_slot(
    render_target, active_cube_face_index,
  )
  if !renderer_slot_truthy(framebuffer) {
    // upstream resolves with `undefined`; the callback is not called
    return
  }
  // the following if statement ensures valid read requests (no out-of-bounds pixels, see #8604)
  if !(x >= 0 &&
    x <= render_target.width - width &&
    y >= 0 &&
    y <= render_target.height - height) {
    @core.error(
      "WebGLRenderer.readRenderTargetPixelsAsync: requested read bounds are out of range.",
    )
    reject()
    return
  }
  // set the active frame buffer to the one we want to read
  ignore(
    self.state.bind_framebuffer(
      GL_FRAMEBUFFER,
      renderer_slot_framebuffer(framebuffer),
    ),
  )
  let texture = render_target.textures[texture_index]
  let texture_format = texture.format
  let texture_type = texture.type_
  // when using MRT, select the correct color buffer for the subsequent read command
  if render_target.textures.length() > 1 {
    gl.read_buffer(GL_COLOR_ATTACHMENT0 + texture_index)
  }
  let readable_state = self.get_readable_state(texture)
  if !readable_state.__format_readable {
    @core.error(
      "WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in RGBA or implementation defined format.",
    )
    reject()
    return
  }
  if !readable_state.__type_readable {
    @core.error(
      "WebGLRenderer.readRenderTargetPixelsAsync: renderTarget is not in UnsignedByteType or implementation defined type.",
    )
    reject()
    return
  }
  let gl_buffer = gl.create_buffer()
  gl.bind_buffer(GL_PIXEL_PACK_BUFFER, Some(gl_buffer))
  gl.buffer_data_size(
    GL_PIXEL_PACK_BUFFER,
    buffer.byte_length(),
    GL_STREAM_READ,
  )
  gl.read_pixels_offset(
    x,
    y,
    width,
    height,
    self.utils.convert(texture_format).unwrap_or(0),
    self.utils.convert(texture_type).unwrap_or(0),
    0,
  )
  gl.bind_buffer(GL_PIXEL_PACK_BUFFER, None)
  // reset the frame buffer to the currently set buffer before waiting
  ignore(
    self.state.bind_framebuffer(GL_FRAMEBUFFER, self.current_framebuffer()),
  )
  // check if the commands have finished every 8 ms
  let sync = gl.fence_sync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0)
  gl.flush()
  renderer_probe_async(
    gl,
    sync,
    4.0,
    () => {
      // read the data and delete the buffer
      gl.bind_buffer(GL_PIXEL_PACK_BUFFER, Some(gl_buffer))
      gl.get_buffer_sub_data(GL_PIXEL_PACK_BUFFER, 0, buffer)
      gl.bind_buffer(GL_PIXEL_PACK_BUFFER, None)
      gl.delete_buffer(gl_buffer)
      gl.delete_sync(sync)
      on_done(buffer)
    },
    reject,
  )
}

///|
/// `renderer.copyFramebufferToTexture( texture, position, level )`.
pub fn WebGLRenderer::copy_framebuffer_to_texture(
  self : WebGLRenderer,
  texture : @core.Texture,
  position? : @math.Vector2,
  level~ : Int32 = 0,
) -> Unit {
  let level_scale = renderer_math_pow(2.0, -level.to_double())
  let width = (texture.width() * level_scale).floor()
  let height = (texture.height() * level_scale).floor()
  let (x, y) = match position {
    Some(position) => (position.x, position.y)
    None => (0.0, 0.0)
  }
  self.textures.set_texture2d(texture, 0)
  self._gl.copy_tex_sub_image2d(
    GL_TEXTURE_2D,
    level,
    0,
    0,
    renderer_to_int32(x),
    renderer_to_int32(y),
    renderer_to_int32(width),
    renderer_to_int32(height),
  )
  self.state.unbind_texture()
}

///|
/// The pixel data of a `TextureImage`: `image.data` for data images, the DOM source
/// otherwise.
fn renderer_image_data(image : @core.TextureImage) -> @core.JsValue {
  match image {
    DataImage(data) =>
      match data.data {
        Some(array) => @core.JsValue::of(array)
        None => @core.JsValue::null()
      }
    DomImage(value) => value
    image => image.to_js()
  }
}

///|
/// `image.data` of a data image (`undefined` for other images).
fn renderer_image_data_field(image : @core.TextureImage) -> @core.JsValue {
  match image {
    DataImage({ data: Some(array), .. }) => @core.JsValue::of(array)
    DataImage(_) => @core.JsValue::null()
    DomImage(value) => value.get("data")
    _ => @core.JsValue::undefined()
  }
}

///|
/// `renderer.copyTextureToTexture( srcTexture, dstTexture, srcRegion, dstPosition,
/// srcLevel, dstLevel )`.
pub fn WebGLRenderer::copy_texture_to_texture(
  self : WebGLRenderer,
  src_texture : @core.Texture,
  dst_texture : @core.Texture,
  src_region? : TextureCopyRegion,
  dst_position? : TextureCopyPosition,
  src_level~ : Int32 = 0,
  dst_level~ : Int32 = 0,
) -> Unit {
  let gl = self._gl
  let state = self.state
  let properties = self.properties
  // gather the necessary dimensions to copy
  let image = if src_texture.is_compressed_texture() {
    src_texture.mipmaps[dst_level]
  } else {
    src_texture.image()
  }
  let (width, height, depth, min_x, min_y, min_z) = match src_region {
    Some(Box2(region)) =>
      (
        region.max.x - region.min.x,
        region.max.y - region.min.y,
        1.0,
        region.min.x,
        region.min.y,
        0.0,
      )
    Some(Box3(region)) =>
      (
        region.max.x - region.min.x,
        region.max.y - region.min.y,
        region.max.z - region.min.z,
        region.min.x,
        region.min.y,
        region.min.z,
      )
    None => {
      let level_scale = renderer_math_pow(2.0, -src_level.to_double())
      let depth = if src_texture.texture_type is DataArrayTexture {
        image.depth()
      } else if src_texture.texture_type is Data3DTexture {
        (image.depth() * level_scale).floor()
      } else {
        1.0
      }
      (
        (image.width() * level_scale).floor(),
        (image.height() * level_scale).floor(),
        depth,
        0.0,
        0.0,
        0.0,
      )
    }
  }
  // `dstPosition.z` of a `Vector2` is undefined, which WebGL reads as 0
  let (dst_x, dst_y, dst_z) = match dst_position {
    Some(Vector2(position)) => (position.x, position.y, 0.0)
    Some(Vector3(position)) => (position.x, position.y, position.z)
    None => (0.0, 0.0, 0.0)
  }
  let i32 = renderer_to_int32
  // Set up the destination target
  let gl_format = self.utils.convert(dst_texture.format).unwrap_or(0)
  let gl_type = self.utils.convert(dst_texture.type_).unwrap_or(0)
  let gl_target = if dst_texture.texture_type is Data3DTexture {
    self.textures.set_texture3d(dst_texture, 0)
    GL_TEXTURE_3D
  } else if dst_texture.texture_type
    is (DataArrayTexture | CompressedArrayTexture) {
    self.textures.set_texture2d_array(dst_texture, 0)
    GL_TEXTURE_2D_ARRAY
  } else {
    self.textures.set_texture2d(dst_texture, 0)
    GL_TEXTURE_2D
  }
  state.active_texture(webgl_slot=GL_TEXTURE0) // see #33153
  state.pixel_storei_bool(GL_UNPACK_FLIP_Y_WEBGL, dst_texture.flip_y)
  state.pixel_storei_bool(
    GL_UNPACK_PREMULTIPLY_ALPHA_WEBGL,
    dst_texture.premultiply_alpha,
  )
  state.pixel_storei(GL_UNPACK_ALIGNMENT, dst_texture.unpack_alignment)
  // used for copying data from cpu
  let current_unpack_row_len = state.get_parameter(GL_UNPACK_ROW_LENGTH)
  let current_unpack_image_height = state.get_parameter(GL_UNPACK_IMAGE_HEIGHT)
  let current_unpack_skip_pixels = state.get_parameter(GL_UNPACK_SKIP_PIXELS)
  let current_unpack_skip_rows = state.get_parameter(GL_UNPACK_SKIP_ROWS)
  let current_unpack_skip_images = state.get_parameter(GL_UNPACK_SKIP_IMAGES)
  state.pixel_storei(GL_UNPACK_ROW_LENGTH, i32(image.width()))
  state.pixel_storei(GL_UNPACK_IMAGE_HEIGHT, i32(image.height()))
  state.pixel_storei(GL_UNPACK_SKIP_PIXELS, i32(min_x))
  state.pixel_storei(GL_UNPACK_SKIP_ROWS, i32(min_y))
  state.pixel_storei(GL_UNPACK_SKIP_IMAGES, i32(min_z))
  // set up the src texture
  let is_src_3d = src_texture.texture_type is (DataArrayTexture | Data3DTexture)
  let is_dst_3d = dst_texture.texture_type is (DataArrayTexture | Data3DTexture)
  let depth_count = i32(depth)
  if src_texture.is_depth_texture() {
    let src_texture_properties = properties.get_texture(src_texture)
    let dst_texture_properties = properties.get_texture(dst_texture)
    let src_render_target_properties = properties.get_render_target(
      src_texture_properties.__render_target.unwrap(),
    )
    let dst_render_target_properties = properties.get_render_target(
      dst_texture_properties.__render_target.unwrap(),
    )
    ignore(
      state.bind_framebuffer(
        GL_READ_FRAMEBUFFER,
        renderer_slot_framebuffer(
          src_render_target_properties.__webgl_framebuffer,
        ),
      ),
    )
    ignore(
      state.bind_framebuffer(
        GL_DRAW_FRAMEBUFFER,
        renderer_slot_framebuffer(
          dst_render_target_properties.__webgl_framebuffer,
        ),
      ),
    )
    for i in 0..<depth_count {
      // if the source or destination are a 3d target then a layer needs to be bound
      if is_src_3d {
        gl.framebuffer_texture_layer(
          GL_READ_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          properties.get_texture(src_texture).__webgl_texture,
          src_level,
          i32(min_z) + i,
        )
        gl.framebuffer_texture_layer(
          GL_DRAW_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          properties.get_texture(dst_texture).__webgl_texture,
          dst_level,
          i32(dst_z) + i,
        )
      }
      gl.blit_framebuffer(
        i32(min_x),
        i32(min_y),
        i32(min_x + width),
        i32(min_y + height),
        i32(dst_x),
        i32(dst_y),
        i32(dst_x + width),
        i32(dst_y + height),
        GL_DEPTH_BUFFER_BIT,
        GL_NEAREST,
      )
    }
    ignore(state.bind_framebuffer(GL_READ_FRAMEBUFFER, None))
    ignore(state.bind_framebuffer(GL_DRAW_FRAMEBUFFER, None))
  } else if src_level != 0 ||
    src_texture.is_render_target_texture ||
    properties.has(src_texture) {
    // get the appropriate frame buffers
    let src_texture_properties = properties.get_texture(src_texture)
    let dst_texture_properties = properties.get_texture(dst_texture)
    // bind the frame buffer targets
    ignore(
      state.bind_framebuffer(GL_READ_FRAMEBUFFER, Some(self._src_framebuffer)),
    )
    ignore(
      state.bind_framebuffer(GL_DRAW_FRAMEBUFFER, Some(self._dst_framebuffer)),
    )
    for i in 0..<depth_count {
      // assign the correct layers and mip maps to the frame buffers
      if is_src_3d {
        gl.framebuffer_texture_layer(
          GL_READ_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          src_texture_properties.__webgl_texture,
          src_level,
          i32(min_z) + i,
        )
      } else {
        gl.framebuffer_texture2d(
          GL_READ_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          GL_TEXTURE_2D,
          src_texture_properties.__webgl_texture,
          src_level,
        )
      }
      if is_dst_3d {
        gl.framebuffer_texture_layer(
          GL_DRAW_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          dst_texture_properties.__webgl_texture,
          dst_level,
          i32(dst_z) + i,
        )
      } else {
        gl.framebuffer_texture2d(
          GL_DRAW_FRAMEBUFFER,
          GL_COLOR_ATTACHMENT0,
          GL_TEXTURE_2D,
          dst_texture_properties.__webgl_texture,
          dst_level,
        )
      }
      // copy the data using the fastest function that can achieve the copy
      if src_level != 0 {
        gl.blit_framebuffer(
          i32(min_x),
          i32(min_y),
          i32(min_x + width),
          i32(min_y + height),
          i32(dst_x),
          i32(dst_y),
          i32(dst_x + width),
          i32(dst_y + height),
          GL_COLOR_BUFFER_BIT,
          GL_NEAREST,
        )
      } else if is_dst_3d {
        gl.copy_tex_sub_image3d(
          gl_target,
          dst_level,
          i32(dst_x),
          i32(dst_y),
          i32(dst_z) + i,
          i32(min_x),
          i32(min_y),
          i32(width),
          i32(height),
        )
      } else {
        gl.copy_tex_sub_image2d(
          gl_target,
          dst_level,
          i32(dst_x),
          i32(dst_y),
          i32(min_x),
          i32(min_y),
          i32(width),
          i32(height),
        )
      }
    }
    // unbind read, draw buffers
    ignore(state.bind_framebuffer(GL_READ_FRAMEBUFFER, None))
    ignore(state.bind_framebuffer(GL_DRAW_FRAMEBUFFER, None))
  } else if is_dst_3d {
    // copy data into the 3d texture
    if src_texture.texture_type is (DataTexture | Data3DTexture) {
      gl.tex_sub_image3d(
        gl_target,
        dst_level,
        i32(dst_x),
        i32(dst_y),
        i32(dst_z),
        i32(width),
        i32(height),
        i32(depth),
        gl_format,
        gl_type,
        renderer_image_data_field(image),
      )
    } else if dst_texture.texture_type is CompressedArrayTexture {
      gl.compressed_tex_sub_image3d(
        gl_target,
        dst_level,
        i32(dst_x),
        i32(dst_y),
        i32(dst_z),
        i32(width),
        i32(height),
        i32(depth),
        gl_format,
        renderer_image_data_field(image),
      )
    } else {
      gl.tex_sub_image3d(
        gl_target,
        dst_level,
        i32(dst_x),
        i32(dst_y),
        i32(dst_z),
        i32(width),
        i32(height),
        i32(depth),
        gl_format,
        gl_type,
        renderer_image_data(image),
      )
    }
  } else if src_texture.texture_type is DataTexture {
    // copy data into the 2d texture
    gl.tex_sub_image2d(
      GL_TEXTURE_2D,
      dst_level,
      i32(dst_x),
      i32(dst_y),
      i32(width),
      i32(height),
      gl_format,
      gl_type,
      renderer_image_data_field(image),
    )
  } else if src_texture.is_compressed_texture() {
    gl.compressed_tex_sub_image2d(
      GL_TEXTURE_2D,
      dst_level,
      i32(dst_x),
      i32(dst_y),
      i32(image.width()),
      i32(image.height()),
      gl_format,
      renderer_image_data_field(image),
    )
  } else {
    gl.tex_sub_image2d(
      GL_TEXTURE_2D,
      dst_level,
      i32(dst_x),
      i32(dst_y),
      i32(width),
      i32(height),
      gl_format,
      gl_type,
      renderer_image_data(image),
    )
  }
  // reset values
  state.pixel_storei(
    GL_UNPACK_ROW_LENGTH,
    js_number_to_int(current_unpack_row_len),
  )
  state.pixel_storei(
    GL_UNPACK_IMAGE_HEIGHT,
    js_number_to_int(current_unpack_image_height),
  )
  state.pixel_storei(
    GL_UNPACK_SKIP_PIXELS,
    js_number_to_int(current_unpack_skip_pixels),
  )
  state.pixel_storei(
    GL_UNPACK_SKIP_ROWS,
    js_number_to_int(current_unpack_skip_rows),
  )
  state.pixel_storei(
    GL_UNPACK_SKIP_IMAGES,
    js_number_to_int(current_unpack_skip_images),
  )
  // Generate mipmaps only when copying level 0
  if dst_level == 0 &&
    dst_texture.generate_mipmaps &&
    dst_texture.mipmaps_auto_update {
    gl.generate_mipmap(gl_target)
  }
  state.unbind_texture()
}

///|
/// `renderer.initRenderTarget( target )`.
pub fn WebGLRenderer::init_render_target(
  self : WebGLRenderer,
  target : @core.RenderTarget,
) -> Unit {
  if self.properties.get_render_target(target).__webgl_framebuffer is None {
    self.textures.setup_render_target(target)
  }
}

///|
/// `renderer.initTexture( texture )`.
pub fn WebGLRenderer::init_texture(
  self : WebGLRenderer,
  texture : @core.Texture,
) -> Unit {
  if texture.is_cube_texture() {
    self.textures.set_texture_cube(texture, 0)
  } else if texture.texture_type is Data3DTexture {
    self.textures.set_texture3d(texture, 0)
  } else if texture.texture_type is (DataArrayTexture | CompressedArrayTexture) {
    self.textures.set_texture2d_array(texture, 0)
  } else {
    self.textures.set_texture2d(texture, 0)
  }
  self.state.unbind_texture()
}

///|
/// `renderer.resetState()`.
pub fn WebGLRenderer::reset_state(self : WebGLRenderer) -> Unit {
  self._current_active_cube_face = 0
  self._current_active_mipmap_level = 0
  self._current_render_target = None
  self.state.reset()
  self.binding_states.reset()
}

///|
/// `renderer.coordinateSystem`.
pub fn WebGLRenderer::coordinate_system(_self : WebGLRenderer) -> Int32 {
  @core.WebGLCoordinateSystem
}

///|
/// `renderer.outputColorSpace`.
pub fn WebGLRenderer::output_color_space(self : WebGLRenderer) -> String {
  self._output_color_space
}

///|
/// `renderer.outputColorSpace = colorSpace`.
pub fn WebGLRenderer::set_output_color_space(
  self : WebGLRenderer,
  color_space : String,
) -> Unit {
  self._output_color_space = color_space
  let gl = self.get_context()
  gl.set_drawing_buffer_color_space(
    @math.color_management._get_drawing_buffer_color_space(color_space),
  )
  gl.set_unpack_color_space(@math.color_management._get_unpack_color_space())
}

///|
/// What `CubeCamera.update` needs (fixed by core).
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn coordinate_system(
  self,
) {
  WebGLRenderer::coordinate_system(self)
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn get_render_target(
  self,
) {
  WebGLRenderer::get_render_target(self)
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn get_active_cube_face(
  self,
) {
  WebGLRenderer::get_active_cube_face(self)
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn get_active_mipmap_level(
  self,
) {
  WebGLRenderer::get_active_mipmap_level(self)
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn xr_enabled(self) {
  self.xr.enabled
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn set_xr_enabled(
  self,
  value,
) {
  self.xr.enabled = value
}

///|
/// `renderer.state.buffers.depth.getReversed()`.
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn reversed_depth_buffer(
  self,
) {
  self.state.buffers.depth.get_reversed()
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn auto_clear(self) {
  self.auto_clear
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn set_render_target(
  self,
  render_target,
  active_cube_face,
  active_mipmap_level,
) {
  WebGLRenderer::set_render_target(
    self,
    render_target,
    active_cube_face~,
    active_mipmap_level~,
  )
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn clear_depth(self) {
  WebGLRenderer::clear_depth(self)
}

///|
pub impl @core.CubeCameraRenderer for WebGLRenderer with fn render(
  self,
  scene,
  camera,
) {
  WebGLRenderer::render(self, scene, camera)
}

///|
#deprecated
pub extend WebGLRenderer with @core.CubeCameraRenderer::{
  xr_enabled,
  set_xr_enabled,
  reversed_depth_buffer,
  auto_clear,
}
