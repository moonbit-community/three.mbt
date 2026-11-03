// renderers/common/Renderer.js: the renderer of the WebGPU and WebGL backends. The
// backend-specific renderers (WebGPURenderer) build it with their backend. Upstream's
// async members (`init`, `compileAsync`, `computeAsync`, ...) take a callback that runs
// when the work is done: synchronously when the backend completes synchronously, where
// upstream resumes on a later microtask.

///|
let _renderer_scene : @core.Object3D = @core.Scene::new()

///|
let _renderer_drawing_buffer_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _renderer_screen : @math.Vector4 = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)

///|
let _renderer_vector4 : @math.Vector4 = @math.Vector4::new(0.0, 0.0, 0.0, 0.0)

///|
/// `_shadowSide[ side ]`.
fn _renderer_shadow_side(side : Int32) -> Int32 {
  if side == @core.FrontSide {
    @core.BackSide
  } else if side == @core.BackSide {
    @core.FrontSide
  } else {
    @core.DoubleSide
  }
}

///|
/// The time in milliseconds an async compilation works before it yields to the main thread.
let _renderer_compile_yield_interval : Double = 8.0

///|
/// The maximum number of pipelines an async compilation creates at the same time.
/// Too many pipelines in flight stall the rendering of new frames.
let _renderer_max_compiling_pipelines : Int32 = 16

///|
extern "js" fn renderer_performance_now() -> Double = "() => performance.now()"

///|
extern "js" fn renderer_shr(value : Double, shift : Int32) -> Double = "(v, s) => v >> s"

///|
extern "js" fn renderer_shr_int(value : Int32, shift : Int32) -> Int32 = "(v, s) => v >> s"

///|
extern "js" fn renderer_math_max(a : Double, b : Double) -> Double = "Math.max"

///|
/// `yieldToMain()`, or a frame-aligned yield when frames are rendered.
extern "js" fn renderer_compile_yield(on_done : () -> Unit) -> Unit =
  #|(done) => {
  #|  if ( typeof requestAnimationFrame === 'undefined' || ( typeof document !== 'undefined' && document.hidden === true ) ) {
  #|    if ( typeof scheduler !== 'undefined' && typeof scheduler.yield === 'function' ) scheduler.yield().then( done );
  #|    else setTimeout( done, 0 );
  #|    return;
  #|  }
  #|  let resolved = false;
  #|  const once = () => { if ( resolved === false ) { resolved = true; done(); } };
  #|  requestAnimationFrame( () => setTimeout( once, 0 ) );
  #|  setTimeout( once, 100 );
  #|}

///|
extern "js" fn renderer_promise_all(
  promises : Array[@core.JsValue],
  on_done : () -> Unit,
) -> Unit = "(p, f) => { Promise.all( p ).then( () => f() ); }"

///|
extern "js" fn renderer_progress_event(
  loaded : Int32,
  total : Int32,
) -> @core.JsValue = "(loaded, total) => typeof ProgressEvent !== 'undefined' ? new ProgressEvent( 'progress', { lengthComputable: true, loaded, total } ) : { type: 'progress', lengthComputable: true, loaded, total }"

///|
/// `CompileScheduler`: yields an async compilation to the main thread after a time budget.
priv struct CompileScheduler {
  mut last_yield_time : Double
}

///|
fn CompileScheduler::new() -> CompileScheduler {
  { last_yield_time: renderer_performance_now(), }
}

///|
fn CompileScheduler::needs_yield(self : CompileScheduler) -> Bool {
  renderer_performance_now() - self.last_yield_time >=
  _renderer_compile_yield_interval
}

///|
fn CompileScheduler::yield_(
  self : CompileScheduler,
  on_done : () -> Unit,
) -> Unit {
  renderer_compile_yield(fn() {
    self.last_yield_time = renderer_performance_now()
    on_done()
  })
}

///|
/// `renderer.debug.diagnostics`.
pub(all) struct RendererDiagnostics {
  /// Whether declaration names that collide with reserved keywords are renamed.
  mut keywords : Bool
}

///|
/// `renderer.debug`.
pub(all) struct RendererDebug {
  mut check_shader_errors : Bool
  diagnostics : RendererDiagnostics
  /// `onNodeBuilderCreated( nodeBuilder, renderObjectOrComputeNode )`; `None` is `null`.
  mut on_node_builder_created : ((NodeBuilder, NodeBuilderOwner) -> Unit)?
  /// `onShaderError( ... )`, called by the backends; `None` is `null`.
  mut on_shader_error : @core.JsValue?
}

///|
/// `renderer.shadowMap`.
pub(all) struct RendererShadowMap {
  mut enabled : Bool
  mut type_ : Int32
  /// Whether shadows carry color (`castShadowNode`); read by shadow nodes (G3).
  mut transmitted : Bool
}

///|
/// The function of `renderer.setRenderObjectFunction( fn )`: ( object, scene, camera,
/// geometry, material, group, lightsNode, clippingContext, passId ).
pub(all) struct RenderObjectFunction {
  f : (
    @core.Object3D,
    @core.Object3D,
    @core.Object3D,
    @core.BufferGeometry,
    @core.Material,
    @core.GeometryGroup?,
    Node,
    ClippingContext?,
    String?,
  ) -> Unit
}

///|
/// `_handleObjectFunction`: draws (`_renderObjectDirect`) or compiles
/// (`_createObjectPipeline`).
#derive(Eq)
pub(all) enum HandleObjectFunction {
  RenderObjectDirect
  CreateObjectPipeline
}

///|
/// A work item `_createObjectPipeline` queues during `compileAsync`.
pub(all) struct CompileObjectItem {
  object : @core.Object3D
  material : @core.Material
  side : Int32
  scene : @core.Object3D
  camera : @core.Object3D
  lights_node : Node
  group : @core.GeometryGroup?
  clipping_context : ClippingContext?
  pass_id : String?
  render_context : RenderContext?
  precompilation_state : PrecompilationState
}

///|
/// An entry of `_compilationPromises`: an object to compile, or compute work queued by
/// a drawing pipeline (`{ computeNodes }`).
pub(all) enum CompilationItem {
  Object(CompileObjectItem)
  Compute(Array[Node])
}

///|
/// The precompilation state of `compileAsync`, reapplied every time it continues.
pub(all) struct PrecompilationState {
  mut use_frame_buffer_target : Bool
  mut render_target : @core.RenderTarget?
  mut output_render_target : @core.RenderTarget?
  mut active_cube_face : Int32
  mut active_mipmap_level : Int32
  mut item : CompileObjectItem?
  mut material_side : Int32?
  mut mrt : Node?
  mut output_mrt : Node?
  /// `None` is `undefined`.
  mut render_context : RenderContext?
  mut previous_render_context : RenderContext?
}

///|
/// `{ ...state }`.
fn PrecompilationState::copy(self : PrecompilationState) -> PrecompilationState {
  { ..self, }
}

///|
/// The owner of a frame buffer target: the output render target or a canvas target.
priv enum FrameBufferTargetOwner {
  Output(@core.RenderTarget)
  Canvas(CanvasTarget)
}

///|
fn FrameBufferTargetOwner::same(
  self : FrameBufferTargetOwner,
  other : FrameBufferTargetOwner,
) -> Bool {
  match (self, other) {
    (Output(a), Output(b)) => physical_equal(a, b)
    (Canvas(a), Canvas(b)) => physical_equal(a, b)
    _ => false
  }
}

///|
fn FrameBufferTargetOwner::dispose(self : FrameBufferTargetOwner) -> Unit {
  match self {
    Output(t) => t.dispose()
    Canvas(t) => t.dispose()
  }
}

///|
/// The output quad of a frame buffer target.
priv struct RendererQuadData {
  quad : QuadMesh
  mut cache_key : String
}

///|
/// `_getShadowNodes( material )`.
pub(all) struct RendererShadowNodes {
  version : Int32
  color_node : Node?
  depth_node : Node?
  position_node : Node?
}

///|
/// The state of `_initPromise`.
priv enum RendererInitState {
  NotStarted
  Pending(Array[(String?) -> Unit])
  Resolved
  Rejected(String)
}

///|
pub(all) struct Renderer {
  mut backend : Backend
  /// `context()`: the context node every build starts from.
  mut context_node : Node
  mut library : NodeLibrary
  /// `_bindings`; `None` until `init()` (the test stand-in keeps it `undefined`).
  mut _bindings : Bindings?
  mut _render_target : @core.RenderTarget?
  /// `_mrt`, an `MRTNode`.
  mut _mrt : Node?
  /// `_inspector`, `new InspectorBase()` with this renderer set.
  mut _inspector : InspectorBase
  debug : RendererDebug
  info : Info
  mut lighting : Lighting
  shadow_map : RendererShadowMap
  mut _current_render_context : RenderContext?
  mut _current_source_material : @core.Material?
  mut tone_mapping : Int32
  mut tone_mapping_exposure : Double
  mut output_color_space : String
  mut auto_clear : Bool
  mut auto_clear_color : Bool
  mut auto_clear_depth : Bool
  mut auto_clear_stencil : Bool
  mut opaque_ : Bool
  mut transparent : Bool
  mut reversed_depth_buffer : Bool
  mut logarithmic_depth_buffer : Bool
  /// `_precompilationState`; `None` is `null`.
  mut _precompilation_state : PrecompilationState?
  mut _clear_depth : Double
  mut _clear_stencil : Int32
  mut _output_render_target : @core.RenderTarget?
  mut alpha : Bool
  mut sort_objects : Bool
  mut depth : Bool
  mut stencil : Bool
  mut _drawing_pipeline : StandardDrawingPipeline
  mut _samples : Int32
  mut _on_canvas_target_resize : (@core.Event) -> Unit
  mut _on_canvas_target_dispose : (@core.Event) -> Unit
  mut _canvas_target : CanvasTarget
  _get_fallback : ((String) -> Backend)?
  mut _attributes : Attributes?
  mut _geometries : Geometries?
  mut _nodes : NodeManager?
  mut _animation : Animation?
  mut _objects : RenderObjects?
  mut _pipelines : Pipelines?
  mut _bundles : RenderBundles?
  mut _render_lists : RenderLists?
  mut _render_contexts : RenderContexts?
  mut _textures : Textures?
  mut _background : Background?
  priv _quad_cache : @webgl.WeakMap[@core.JsValue, RendererQuadData]
  mut _opaque_sort : ((RenderItem, RenderItem) -> Double)?
  mut _transparent_sort : ((RenderItem, RenderItem) -> Double)?
  priv _frame_buffer_targets : Array[
    (FrameBufferTargetOwner, @core.RenderTarget),
  ]
  _clear_color : Color4
  mut _active_cube_face : Int32
  mut _active_mipmap_level : Int32
  mut _render_object_function : RenderObjectFunction?
  /// `_currentRenderObjectFunction`; `None` is `this.renderObject`.
  mut _current_render_object_function : RenderObjectFunction?
  mut _current_render_bundle : RenderBundle?
  mut _handle_object_function : HandleObjectFunction
  mut _is_device_lost : Bool
  /// `onDeviceLost( info )`, called by the backends.
  mut on_device_lost : (@core.JsValue) -> Unit
  /// `onError( info )`, called by the backends.
  mut on_error : (@core.JsValue) -> Unit
  _output_buffer_type : Int32
  _cache_shadow_nodes : @webgl.WeakMap[@core.JsValue, RendererShadowNodes]
  mut _initialized : Bool
  mut _call_depth : Int32
  priv mut _init_promise : RendererInitState
  mut _compilation_promises : Array[CompilationItem]?
  mut xr : XRManager
  /// `isRenderer`; `false` only for renderers that stand in for another one (the
  /// WebGLNodesHandler add-on's proxy of a WebGLRenderer, which has no `isRenderer`).
  mut is_renderer : Bool
}

///|
extern "js" fn renderer_undefined() -> XRManager = "() => undefined"

///|
/// `new Renderer( backend, parameters = {} )`.
pub fn Renderer::new(
  backend : Backend,
  logarithmic_depth_buffer~ : Bool = false,
  reversed_depth_buffer~ : Bool = false,
  alpha~ : Bool = true,
  depth~ : Bool = true,
  stencil~ : Bool = false,
  antialias~ : Bool = false,
  samples~ : Int32 = 0,
  get_fallback? : (String) -> Backend,
  output_buffer_type~ : Int32 = @core.HalfFloatType,
  multiview~ : Bool = false,
) -> Renderer {
  let context_node = context()
  let library = NodeLibrary::new()
  let lighting = Lighting::new()
  let drawing_pipeline = StandardDrawingPipeline::new()
  let canvas_target = CanvasTarget::new(backend.get_dom_element())
  let alpha_clear = if alpha == true { 0.0 } else { 1.0 }
  let renderer : Renderer = {
    backend,
    auto_clear: true,
    auto_clear_color: true,
    auto_clear_depth: true,
    auto_clear_stencil: true,
    alpha,
    logarithmic_depth_buffer,
    reversed_depth_buffer,
    output_color_space: @core.SRGBColorSpace,
    tone_mapping: @core.NoToneMapping,
    tone_mapping_exposure: 1.0,
    sort_objects: true,
    depth,
    stencil,
    info: Info::new(),
    context_node,
    library,
    lighting,
    _drawing_pipeline: drawing_pipeline,
    _samples: if samples != 0 {
      samples
    } else if antialias == true {
      4
    } else {
      0
    },
    _on_canvas_target_resize: fn(_) {  },
    _on_canvas_target_dispose: fn(_) {  },
    _canvas_target: canvas_target,
    _inspector: InspectorBase::new(),
    _get_fallback: get_fallback,
    _attributes: None,
    _geometries: None,
    _nodes: None,
    _animation: None,
    _bindings: None,
    _objects: None,
    _pipelines: None,
    _bundles: None,
    _render_lists: None,
    _render_contexts: None,
    _textures: None,
    _background: None,
    _quad_cache: @webgl.WeakMap::new(),
    _current_render_context: None,
    _opaque_sort: None,
    _transparent_sort: None,
    _frame_buffer_targets: [],
    _clear_color: Color4::new(r=0.0, g=0.0, b=0.0, a=alpha_clear),
    _clear_depth: 1.0,
    _clear_stencil: 0,
    _render_target: None,
    _active_cube_face: 0,
    _active_mipmap_level: 0,
    _output_render_target: None,
    _mrt: None,
    _render_object_function: None,
    _current_render_object_function: None,
    _current_render_bundle: None,
    _handle_object_function: RenderObjectDirect,
    _is_device_lost: false,
    on_device_lost: fn(_) {  },
    on_error: fn(_) {  },
    _output_buffer_type: output_buffer_type,
    _cache_shadow_nodes: @webgl.WeakMap::new(),
    _initialized: false,
    _call_depth: -1,
    _init_promise: NotStarted,
    _compilation_promises: None,
    _precompilation_state: None,
    _current_source_material: None,
    transparent: true,
    opaque_: true,
    shadow_map: {
      enabled: false,
      transmitted: false,
      type_: @core.PCFShadowMap,
    },
    xr: renderer_undefined(),
    is_renderer: true,
    debug: {
      check_shader_errors: true,
      diagnostics: { keywords: false, },
      on_node_builder_created: None,
      on_shader_error: None,
    },
  }
  renderer.set_drawing_pipeline(drawing_pipeline)
  renderer._on_canvas_target_resize = fn(_) {
    renderer._handle_canvas_target_resize()
  }
  renderer._on_canvas_target_dispose = fn(event) {
    match event.target {
      Some(Other(target)) => renderer._destroy_canvas_target(target.cast())
      _ => ()
    }
  }
  canvas_target.add_event_listener("resize", renderer._on_canvas_target_resize)
  canvas_target.add_event_listener(
    "dispose",
    renderer._on_canvas_target_dispose,
  )
  canvas_target.is_default_canvas_target = true
  renderer._inspector.set_renderer(Some(renderer)) |> ignore
  renderer.on_device_lost = fn(info) { renderer._handle_device_lost(info) }
  renderer.on_error = fn(info) { renderer._handle_error(info) }
  renderer.xr = XRManager::new(renderer, multiview~)
  renderer
}

///|
/// `set drawingPipeline( pipeline )`.
pub fn Renderer::set_drawing_pipeline(
  self : Renderer,
  pipeline : StandardDrawingPipeline,
) -> Unit {
  pipeline.renderer = Some(self)
  self._drawing_pipeline = pipeline
}

///|
/// `get drawingPipeline()`.
pub fn Renderer::drawing_pipeline(self : Renderer) -> StandardDrawingPipeline {
  self._drawing_pipeline
}

// The modules `init()` creates (`this._nodes` etc.); upstream throws a TypeError when
// they are used before `init()`.

///|
pub fn Renderer::_nodes(self : Renderer) -> NodeManager {
  self._nodes.unwrap()
}

///|
pub fn Renderer::_animation(self : Renderer) -> Animation {
  self._animation.unwrap()
}

///|
pub fn Renderer::_attributes(self : Renderer) -> Attributes {
  self._attributes.unwrap()
}

///|
pub fn Renderer::_geometries(self : Renderer) -> Geometries {
  self._geometries.unwrap()
}

///|
pub fn Renderer::_textures(self : Renderer) -> Textures {
  self._textures.unwrap()
}

///|
pub fn Renderer::_pipelines(self : Renderer) -> Pipelines {
  self._pipelines.unwrap()
}

///|
pub fn Renderer::_bindings(self : Renderer) -> Bindings {
  self._bindings.unwrap()
}

///|
pub fn Renderer::_objects(self : Renderer) -> RenderObjects {
  self._objects.unwrap()
}

///|
pub fn Renderer::_render_lists(self : Renderer) -> RenderLists {
  self._render_lists.unwrap()
}

///|
pub fn Renderer::_bundles(self : Renderer) -> RenderBundles {
  self._bundles.unwrap()
}

///|
pub fn Renderer::_render_contexts(self : Renderer) -> RenderContexts {
  self._render_contexts.unwrap()
}

///|
pub fn Renderer::_background(self : Renderer) -> Background {
  self._background.unwrap()
}

///|
extern "js" fn renderer_js_try(
  f : () -> Unit,
  on_throw : (String) -> Bool,
) -> Unit =
  #|(f, on_throw) => { try { f(); } catch (e) { if (!on_throw(String(e))) throw e; } }

///|
/// `await backend.init( renderer )`: `init` is async upstream, so an exception thrown
/// while it runs rejects (reaches `on_done` as the error) instead of escaping. An
/// exception thrown after `on_done` was called (by the continuation) propagates.
fn renderer_await_backend_init(
  backend : Backend,
  renderer : Renderer,
  on_done : (String?) -> Unit,
) -> Unit {
  let settled = Ref(false)
  renderer_js_try(
    fn() {
      backend.init(renderer, fn(error) {
        settled.val = true
        on_done(error)
      })
    },
    fn(error) {
      if settled.val {
        return false
      }
      settled.val = true
      on_done(Some(error))
      true
    },
  )
}

///|
/// `async init()`: initializes the backend (or the fallback) and creates the
/// renderer's modules; calls back with `None`, or the error.
pub fn Renderer::init(
  self : Renderer,
  on_done~ : (String?) -> Unit = fn(_) {  },
) -> Unit {
  match self._init_promise {
    Resolved => return on_done(None)
    Rejected(e) => return on_done(Some(e))
    Pending(callbacks) => return callbacks.push(on_done)
    NotStarted => ()
  }
  let callbacks = [on_done]
  self._init_promise = Pending(callbacks)
  fn reject(error : String) -> Unit {
    self._init_promise = Rejected(error)
    for f in callbacks {
      f(Some(error))
    }
  }

  fn resolve(backend : Backend) -> Unit {
    if self.logarithmic_depth_buffer == true &&
      self.reversed_depth_buffer == true {
      @core.warn(
        "WebGPURenderer: Logarithmic depth buffer is ignored when reversed depth buffer is enabled.",
      )
      self.logarithmic_depth_buffer = false
    }
    let nodes = NodeManager::new(self, backend)
    self._nodes = Some(nodes)
    self._animation = Some(Animation::new(self, nodes, self.info))
    let attributes = Attributes::new(backend, self.info)
    self._attributes = Some(attributes)
    self._background = Some(Background::new(self, nodes))
    let geometries = Geometries::new(backend, attributes, self.info)
    self._geometries = Some(geometries)
    let textures = Textures::new(self, backend, self.info)
    self._textures = Some(textures)
    let pipelines = Pipelines::new(backend, nodes, self.info)
    self._pipelines = Some(pipelines)
    let bindings = Bindings::new(
      backend,
      nodes,
      textures,
      attributes,
      pipelines,
      self.info,
    )
    self._bindings = Some(bindings)
    self._objects = Some(
      RenderObjects::new(
        self,
        nodes,
        geometries,
        pipelines,
        bindings,
        self.info,
      ),
    )
    self._render_lists = Some(RenderLists::new())
    self._bundles = Some(RenderBundles::new())
    self._render_contexts = Some(RenderContexts::new(self))
    //
    self._initialized = true
    self._init_promise = Resolved
    for f in callbacks {
      f(None)
    }
  }

  let backend = self.backend
  renderer_await_backend_init(backend, self, fn(error) {
    match error {
      None => resolve(backend)
      Some(error) =>
        match self._get_fallback {
          // try the fallback
          Some(get_fallback) => {
            let fallback = get_fallback(error)
            self.backend = fallback
            renderer_await_backend_init(fallback, self, fn(error) {
              match error {
                None => resolve(fallback)
                Some(error) => reject(error)
              }
            })
          }
          None => reject(error)
        }
    }
  })
}

///|
/// `get domElement()`.
pub fn Renderer::dom_element(self : Renderer) -> @core.JsValue {
  self._canvas_target.dom_element
}

///|
/// `get coordinateSystem()`.
pub fn Renderer::coordinate_system(self : Renderer) -> Int32 {
  self.backend.coordinate_system()
}

///|
/// `async compileAsync( scene, camera, targetScene = null, onProgress = null )`:
/// builds the render objects and pipelines of a scene without drawing; calls back
/// when they are ready.
pub fn Renderer::compile_async(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  target_scene? : @core.Object3D,
  on_progress? : (@core.JsValue) -> Unit,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  if self._is_device_lost == true {
    return on_done()
  }
  fn start() -> Unit {
    // only awaited when the drawing pipeline prepares something, so the state below is still taken synchronously
    self
    .drawing_pipeline()
    .prepare_async(scene, camera, fn() {
      self._compile_prepared(scene, camera, target_scene, on_progress, on_done)
    })
  }

  if self._initialized == false {
    self.init(on_done=fn(error) {
      match error {
        None => start()
        Some(e) => abort(e)
      }
    })
  } else {
    start()
  }
}

///|
/// `get compile()`: `compileAsync`.
pub fn Renderer::compile(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  target_scene? : @core.Object3D,
  on_progress? : (@core.JsValue) -> Unit,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  self.compile_async(scene, camera, target_scene?, on_progress?, on_done~)
}

///|
/// The body of `compileAsync` after the drawing pipeline is prepared.
fn Renderer::_compile_prepared(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  target_scene : @core.Object3D?,
  on_progress : ((@core.JsValue) -> Unit)?,
  on_done : () -> Unit,
) -> Unit {
  if self.shadow_map.type_ == @core.PCFSoftShadowMap {
    @core.warn(
      "WebGPURenderer: PCFSoftShadowMap has been removed. Using PCFShadowMap instead.",
    )
    self.shadow_map.type_ = @core.PCFShadowMap
  }
  // preserve render tree
  let nodes = self._nodes()
  let node_frame = nodes.node_frame
  let previous_render_id = node_frame.render_id
  let previous_render_context = self._current_render_context
  let previous_render_object_function = self._current_render_object_function
  let previous_handle_object_function = self._handle_object_function
  let previous_compilation_promises = self._compilation_promises
  //
  let target_scene = match target_scene {
    Some(t) => t
    None => scene
  }
  // Use the actual scene for caching when compiling individual objects
  // This ensures cache keys match between compileAsync and render
  let scene_ref = if scene.is_scene() {
    scene
  } else if target_scene.is_scene() {
    target_scene
  } else {
    _renderer_scene
  }
  // Match render()'s logic: use frameBufferTarget when needsFrameBufferTarget is true
  let use_frame_buffer_target = self.needs_frame_buffer_target() &&
    self._render_target is None
  let output_render_target = match self._render_target {
    Some(t) => Some(t)
    None => self._output_render_target
  }
  let use_xr_camera = self.xr.is_presenting == true && self.is_output_target()
  let render_target = if use_frame_buffer_target {
    self._get_frame_buffer_target()
  } else {
    output_render_target
  }
  let active_cube_face = self._active_cube_face
  let active_mipmap_level = self._active_mipmap_level
  // a state snapshot is taken once at the beginning and reapplied every time precompilation continues.
  let precompilation_state : PrecompilationState = {
    use_frame_buffer_target,
    render_target,
    output_render_target: if use_frame_buffer_target {
      output_render_target
    } else {
      self._render_target
    },
    active_cube_face,
    active_mipmap_level,
    item: None,
    material_side: None,
    mrt: self._mrt,
    output_mrt: self._mrt,
    render_context: None,
    previous_render_context: None,
  }
  self._begin_pre_compile(precompilation_state)
  let render_context = self
    ._render_contexts()
    .get(render_target?, mrt?=self._mrt, call_depth=self._call_depth, camera~)
  precompilation_state.render_context = Some(render_context)
  let compilation_promises : Array[CompilationItem] = []
  self._current_render_context = Some(render_context)
  self._current_render_object_function = None
  self._handle_object_function = CreateObjectPipeline
  self._compilation_promises = Some(compilation_promises)
  node_frame.render_id += 1
  //
  node_frame.update()
  //
  render_context.depth = self.depth
  render_context.stencil = self.stencil
  if render_context.clipping_context is None {
    render_context.clipping_context = Some(ClippingContext::new())
  }
  render_context.clipping_context.unwrap().update_global(scene_ref, camera)
  //
  if scene.matrix_world_auto_update == true {
    scene.update_matrix_world()
  }
  let camera = self._update_camera(camera, use_xr_camera)
  //
  _renderer_scene_on_before_render(
    self, scene_ref, scene, camera, render_target,
  )
  //
  self.drawing_pipeline().begin(camera, render_context)
  // Use sceneRef for render list to ensure lightsNode matches between compileAsync and render
  let render_list = self._render_lists().get(scene_ref, camera, self.lighting)
  self.drawing_pipeline().begin_render_list(render_list)
  self
  .drawing_pipeline()
  .project(scene, camera, 0, render_list, render_context.clipping_context)
  // include lights from target scene
  if !physical_equal(target_scene, scene) {
    target_scene.traverse_visible(fn(object) {
      if object.is_light() && object.layers.test_(camera.layers) {
        render_list.push_light(object)
      }
    })
  }
  self.drawing_pipeline().finish_render_list(render_list)
  //
  match render_target {
    Some(render_target) => {
      self._textures().update_render_target(render_target, active_mipmap_level~)
      let render_target_data = self._textures().get_render_target(render_target)
      render_context.textures = render_target_data.textures
      render_context.depth_texture = render_target_data.depth_texture
    }
    None => {
      render_context.textures = None
      render_context.depth_texture = None
    }
  }
  //
  if !physical_equal(target_scene, scene) {
    self._background().update(target_scene, render_list, render_context)
  } else {
    self._background().update(scene_ref, render_list, render_context)
  }
  // process render lists - _createObjectPipeline queues work in _compilationPromises
  let opaque_objects = render_list.opaque_
  let transparent_objects = render_list.transparent
  let transparent_double_pass_objects = render_list.transparent_double_pass
  let lights_node = render_list.lights_node
  if self.opaque_ == true && opaque_objects.length() > 0 {
    self._render_objects(opaque_objects, camera, scene_ref, lights_node)
  }
  if self.transparent == true && transparent_objects.length() > 0 {
    self._render_transparents(
      transparent_objects, transparent_double_pass_objects, camera, scene_ref, lights_node,
    )
  }
  // restore render tree
  node_frame.render_id = previous_render_id
  self._current_render_context = previous_render_context
  self._current_render_object_function = previous_render_object_function
  self._handle_object_function = previous_handle_object_function
  self._compilation_promises = previous_compilation_promises
  self._finish_pre_compile()
  // Process compilation work items sequentially and yield to the main thread after a
  // time budget to keep animation smooth. Pipelines are compiled in parallel while
  // the next items are processed.
  let total = compilation_promises.length()
  let loaded = Ref(0)
  let scheduler = CompileScheduler::new()
  let compiling = RendererCompiling::new(on_done)
  let on_loaded = fn() {
    loaded.val += 1
    match on_progress {
      Some(f) => f(renderer_progress_event(loaded.val, total))
      None => ()
    }
  }
  let yield_pre_compile = fn(k : () -> Unit) {
    if scheduler.needs_yield() == false {
      return k()
    }
    let active_precompilation_state = self._precompilation_state
    self._finish_pre_compile()
    scheduler.yield_(fn() {
      self._begin_pre_compile(active_precompilation_state.unwrap())
      k()
    })
  }
  fn process(i : Int32) -> Unit {
    if i >= compilation_promises.length() {
      return compiling.finish()
    }
    match compilation_promises[i] {
      Compute(compute_nodes) =>
        // compute work queued by the drawing pipeline, e.g. its culling
        self.compile_compute_async_list(compute_nodes, on_done=fn() {
          on_loaded()
          process(i + 1)
        })
      Object(item) => {
        let pipeline_promises : Array[@core.JsValue] = []
        // each item is compiled with the state of the render call that queued it, e.g. a nested render into another target
        let item_precompilation_state = item.precompilation_state
        item_precompilation_state.item = Some(item)
        self._begin_pre_compile(item_precompilation_state)
        let render_object = self
          ._objects()
          .get(
            item.object,
            item.material,
            item.scene,
            item.camera,
            item.lights_node,
            item.render_context.unwrap(),
            item.clipping_context,
            pass_id?=item.pass_id,
          )
        render_object.draw_range = item.object
          .get_geometry()
          .map(fn(g) { g.draw_range })
        render_object.group = item.group
        nodes.get_for_render_async(
          render_object,
          fn(_) {
            nodes.update_before(render_object)
            self._geometries().update_for_render(render_object)
            nodes.update_for_render(render_object)
            self._bindings().update_for_render(render_object)
            self
            ._pipelines()
            .get_for_render(render_object, promises=pipeline_promises)
            |> ignore
            nodes.update_after(render_object)
            self._finish_pre_compile()
            let next = fn() {
              if scheduler.needs_yield() {
                scheduler.yield_(fn() { process(i + 1) })
              } else {
                process(i + 1)
              }
            }
            if pipeline_promises.length() > 0 {
              compiling.add(pipeline_promises, on_loaded)
              compiling.wait_below(_renderer_max_compiling_pipelines, next)
            } else {
              on_loaded()
              next()
            }
          },
          yield_fn=yield_pre_compile,
        )
      }
    }
  }

  process(0)
}

///|
/// The pipelines in flight of an async compilation (upstream's `compilingPipelines`
/// set with `Promise.race` / `Promise.all`).
priv struct RendererCompiling {
  mut size : Int32
  mut waiting : (Int32, () -> Unit)?
  mut finished : Bool
  on_done : () -> Unit
}

///|
fn RendererCompiling::new(on_done : () -> Unit) -> RendererCompiling {
  { size: 0, waiting: None, finished: false, on_done, }
}

///|
fn RendererCompiling::add(
  self : RendererCompiling,
  promises : Array[@core.JsValue],
  on_loaded : () -> Unit,
) -> Unit {
  self.size += 1
  renderer_promise_all(promises, fn() {
    self.size -= 1
    on_loaded()
    self._check()
  })
}

///|
fn RendererCompiling::_check(self : RendererCompiling) -> Unit {
  match self.waiting {
    Some((limit, k)) if self.size < limit => {
      self.waiting = None
      k()
    }
    _ => ()
  }
  if self.finished && self.size == 0 && self.waiting is None {
    self.finished = false
    (self.on_done)()
  }
}

///|
/// `while ( compilingPipelines.size >= limit ) await Promise.race( compilingPipelines )`.
fn RendererCompiling::wait_below(
  self : RendererCompiling,
  limit : Int32,
  k : () -> Unit,
) -> Unit {
  if self.size < limit {
    k()
  } else {
    self.waiting = Some((limit, k))
  }
}

///|
/// `await Promise.all( compilingPipelines )`, then the caller's callback.
fn RendererCompiling::finish(self : RendererCompiling) -> Unit {
  self.finished = true
  self._check()
}

///|
/// `_beginPreCompile( precompilationState )`.
fn Renderer::_begin_pre_compile(
  self : Renderer,
  precompilation_state : PrecompilationState,
) -> Unit {
  if precompilation_state.use_frame_buffer_target == true {
    self.set_render_target(precompilation_state.render_target)
  }
  self.set_mrt(precompilation_state.mrt) |> ignore
  match precompilation_state.item {
    Some(item) => {
      // apply the material side the work item was queued with since the renderer changes the side
      // temporarily, e.g. for the back and front pass of double-sided transparent materials
      precompilation_state.material_side = Some(item.material.side)
      item.material.side = item.side
    }
    None => ()
  }
  self._call_depth += 1
  // node builds take their shared bind groups from the current render context
  precompilation_state.previous_render_context = self._current_render_context
  match precompilation_state.render_context {
    Some(c) => self._current_render_context = Some(c)
    None => ()
  }
  self._precompilation_state = Some(precompilation_state)
}

///|
/// `_finishPreCompile()`.
fn Renderer::_finish_pre_compile(self : Renderer) -> Unit {
  let state = self._precompilation_state.unwrap()
  if state.use_frame_buffer_target == true {
    self.set_render_target(
      state.output_render_target,
      active_cube_face=state.active_cube_face,
      active_mipmap_level=state.active_mipmap_level,
    )
  }
  self.set_mrt(state.output_mrt) |> ignore
  match state.item {
    Some(item) => item.material.side = state.material_side.unwrap()
    None => ()
  }
  self._current_render_context = state.previous_render_context
  self._call_depth -= 1
  self._precompilation_state = None
}

///|
/// The `onInit` and dispose setup of a compute node's first use.
fn Renderer::_init_compute_node(self : Renderer, compute_node : Node) -> Unit {
  let pipelines = self._pipelines()
  let bindings = self._bindings()
  let nodes = self._nodes()
  if pipelines.has_compute(compute_node) == false {
    let dispose : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
    dispose.val = fn(_) {
      compute_node.remove_event_listener("dispose", dispose.val)
      pipelines.delete_compute(compute_node) |> ignore
      bindings.delete_for_compute(compute_node)
      nodes.delete_compute(compute_node) |> ignore
    }
    compute_node.add_event_listener("dispose", dispose.val)
    match ComputeNode::of(compute_node) {
      Some({ on_init_function: Some(f), .. }) => f(compute_node, self)
      _ => ()
    }
  }
}

///|
fn _renderer_check_compute_nodes(
  compute_list : Array[Node],
  message : String,
) -> Unit {
  if compute_list.length() == 0 ||
    compute_list.iter().any(fn(n) { !n.has_flag("isComputeNode") }) {
    abort(message)
  }
}

///|
/// `async compileComputeAsync( computeNode, onProgress = null )`.
pub fn Renderer::compile_compute_async(
  self : Renderer,
  compute_node : Node,
  on_progress? : (@core.JsValue) -> Unit,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  self.compile_compute_async_list([compute_node], on_progress?, on_done~)
}

///|
/// `async compileComputeAsync( computeNodes, onProgress = null )` with an array.
pub fn Renderer::compile_compute_async_list(
  self : Renderer,
  compute_list : Array[Node],
  on_progress? : (@core.JsValue) -> Unit,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  if self._is_device_lost == true {
    return on_done()
  }
  fn start() -> Unit {
    _renderer_check_compute_nodes(
      compute_list, "THREE.Renderer: .compileComputeAsync() expects a ComputeNode.",
    )
    let total = compute_list.length()
    let loaded = Ref(0)
    let scheduler = CompileScheduler::new()
    let compiling = RendererCompiling::new(on_done)
    let on_loaded = fn() {
      loaded.val += 1
      match on_progress {
        Some(f) => f(renderer_progress_event(loaded.val, total))
        None => ()
      }
    }
    let yield_compile = fn(k : () -> Unit) {
      if scheduler.needs_yield() {
        scheduler.yield_(k)
      } else {
        k()
      }
    }
    //
    let pipelines = self._pipelines()
    let bindings = self._bindings()
    let nodes = self._nodes()
    fn process(i : Int32) -> Unit {
      if i >= compute_list.length() {
        return compiling.finish()
      }
      let compute_node = compute_list[i]
      self._init_compute_node(compute_node)
      nodes.get_for_compute_async(
        compute_node,
        fn(_) {
          nodes.update_before_for_compute(compute_node)
          nodes.update_for_compute(compute_node)
          bindings.update_for_compute(compute_node)
          let compute_bindings = bindings.get_for_compute(compute_node)
          let compilation_promises : Array[@core.JsValue] = []
          pipelines.get_for_compute(
            compute_node,
            compute_bindings,
            promises=compilation_promises,
          )
          |> ignore
          nodes.update_after_for_compute(compute_node)
          let next = fn() { yield_compile(fn() { process(i + 1) }) }
          // Pipelines are compiled in parallel while the next compute nodes are processed
          if compilation_promises.length() > 0 {
            compiling.add(compilation_promises, on_loaded)
            compiling.wait_below(_renderer_max_compiling_pipelines, next)
          } else {
            on_loaded()
            next()
          }
        },
        yield_fn=yield_compile,
      )
    }

    process(0)
  }

  if self._initialized == false {
    self.init(on_done=fn(error) {
      match error {
        None => start()
        Some(e) => abort(e)
      }
    })
  } else {
    start()
  }
}

///|
/// `async renderAsync( scene, camera )` (deprecated): `init()`, then `render()`.
pub fn Renderer::render_async(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  @core.warn_once(
    "Renderer: \"renderAsync()\" has been deprecated. Use \"render()\" and \"await renderer.init();\" when creating the renderer.",
  )
  self.init(on_done=fn(error) {
    match error {
      None => {
        self.render(scene, camera)
        on_done()
      }
      Some(e) => abort(e)
    }
  })
}

///|
/// `async waitForGPU()`: removed upstream; reports an error.
pub fn Renderer::wait_for_gpu(
  self : Renderer,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  ignore(self)
  @core.error(
    "Renderer: waitForGPU() has been removed. Read https://github.com/mrdoob/three.js/issues/32012 for more information.",
  )
  on_done()
}

///|
/// `set inspector( value )`.
pub fn Renderer::set_inspector(self : Renderer, value : InspectorBase) -> Unit {
  self._inspector.set_renderer(None) |> ignore
  self._inspector = value
  self._inspector.set_renderer(Some(self)) |> ignore
}

///|
/// `get inspector()`.
pub fn Renderer::inspector(self : Renderer) -> InspectorBase {
  self._inspector
}

///|
/// `set highPrecision( value )`.
pub fn Renderer::set_high_precision(self : Renderer, value : Bool) -> Unit {
  let context_node_data = ContextNode::of(self.context_node).unwrap().value
  if value == true {
    context_node_data.set("modelViewMatrix", Node(highp_model_view_matrix))
    context_node_data.set(
      "modelNormalViewMatrix",
      Node(highp_model_normal_view_matrix),
    )
  } else if self.high_precision() {
    context_node_data.delete("modelViewMatrix")
    context_node_data.delete("modelNormalViewMatrix")
  }
}

///|
/// `get highPrecision()`.
pub fn Renderer::high_precision(self : Renderer) -> Bool {
  let context_node_data = ContextNode::of(self.context_node).unwrap().value
  context_node_data.get_node("modelViewMatrix") is Some(a) &&
  a.same(highp_model_view_matrix) &&
  context_node_data.get_node("modelNormalViewMatrix") is Some(b) &&
  b.same(highp_model_normal_view_matrix)
}

///|
/// `setMRT( mrt )`; `None` is `null`.
pub fn Renderer::set_mrt(self : Renderer, mrt : Node?) -> Renderer {
  self._mrt = mrt
  self
}

///|
pub fn Renderer::get_mrt(self : Renderer) -> Node? {
  self._mrt
}

///|
pub fn Renderer::get_output_buffer_type(self : Renderer) -> Int32 {
  self._output_buffer_type
}

///|
/// `getColorBufferType()` (deprecated): `getOutputBufferType()`.
pub fn Renderer::get_color_buffer_type(self : Renderer) -> Int32 {
  @core.warn_once(
    "Renderer: \".getColorBufferType()\" has been renamed to \".getOutputBufferType()\".",
  )
  self.get_output_buffer_type()
}

///|
extern "js" fn renderer_device_lost_message(info : @core.JsValue) -> String = "(info) => { let m = `THREE.WebGPURenderer: ${info.api} Device Lost:\\n\\nMessage: ${info.message}`; if ( info.reason ) m += `\\nReason: ${info.reason}`; return m; }"

///|
extern "js" fn renderer_error_message(info : @core.JsValue) -> String = "(info) => { let m = `WebGPURenderer: Uncaptured ${ info.api } ${ info.type }`; if ( info.message ) m += `: ${ info.message }`; return m; }"

///|
/// `_onDeviceLost( info )`.
fn Renderer::_handle_device_lost(self : Renderer, info : @core.JsValue) -> Unit {
  @core.error(renderer_device_lost_message(info))
  self._is_device_lost = true
}

///|
/// `_onError( info )`.
fn Renderer::_handle_error(self : Renderer, info : @core.JsValue) -> Unit {
  ignore(self)
  @core.error(renderer_error_message(info))
}

///|
extern "js" fn renderer_js_length(array : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn renderer_js_index(
  array : @core.JsValue,
  i : Int32,
) -> @core.JsValue = "(a, i) => a[ i ]"

///|
extern "js" fn renderer_js_push(
  array : @core.JsValue,
  value : @core.JsValue,
) -> Unit = "(a, v) => { a.push( v ); }"

///|
/// `_bundleNeedsUpdate( bundleGroup, renderBundleData )`.
pub fn Renderer::_bundle_needs_update(
  self : Renderer,
  bundle_group : BundleGroup,
  render_bundle_data : @core.JsValue,
) -> Bool {
  let drawing_pipeline = render_bundle_data.get("drawingPipeline")
  if render_bundle_data.get("bundleGPU").is_undefined() ||
    !render_bundle_data
    .get("version")
    .strict_equal(@core.JsValue::of(bundle_group.version)) ||
    !drawing_pipeline.strict_equal(@core.JsValue::of(self.drawing_pipeline())) {
    return true
  }
  // the recorded bundle references the buffers of its attributes. they are only verified after a disposal
  let attributes = self._attributes()
  if !render_bundle_data
    .get("attributesDisposeVersion")
    .strict_equal(@core.JsValue::of(attributes.dispose_version)) {
    render_bundle_data.set(
      "attributesDisposeVersion",
      @core.JsValue::of(attributes.dispose_version),
    )
    let render_objects = render_bundle_data.get("renderObjects")
    for i in 0..<renderer_js_length(render_objects) {
      let render_object : RenderObject = renderer_js_index(render_objects, i).cast()
      let index = render_object.get_index()
      let mut disposed = match index {
        Some(index) =>
          attributes.has(
            render_object._geometries.backend.get_buffer_attribute(index),
          ) ==
          false
        None => false
      }
      for vertex_buffer in render_object.get_vertex_buffers() {
        if attributes.has(vertex_buffer) == false {
          disposed = true
        }
      }
      if disposed {
        // invalidate the recorded version so the bundle is recorded again
        render_bundle_data.set("version", @core.JsValue::null())
        return true
      }
    }
  }
  false
}

///|
/// `_renderBundle( bundle, sceneRef, lightsNode )`.
fn Renderer::_render_bundle(
  self : Renderer,
  bundle : RenderListBundle,
  scene_ref : @core.Object3D,
  lights_node : Node,
) -> Unit {
  let { bundle_group, camera, render_list, } = bundle
  let render_context = self._current_render_context.unwrap()
  let bundle_group_data = BundleGroup::of(bundle_group).unwrap()
  //
  let render_bundle = self._bundles().get(bundle_group, camera, render_context)
  let render_bundle_data = self.backend.get(@core.JsValue::of(render_bundle))
  let render_bundle_needs_update = self._bundle_needs_update(
    bundle_group_data, render_bundle_data,
  )
  if render_bundle_needs_update {
    self.backend.begin_bundle(render_context)
    // nested renders, like shadow maps updated by the objects of the bundle, record their own bundles
    let previous_render_bundle = self._current_render_bundle
    self._current_render_bundle = Some(render_bundle)
    // objects whose pipelines are not ready yet reset the version, so the bundle is recorded again
    render_bundle_data.set(
      "version",
      @core.JsValue::of(bundle_group_data.version),
    )
    render_bundle_data.set(
      "drawingPipeline",
      @core.JsValue::of(self.drawing_pipeline()),
    )
    let transparent_double_pass_objects = render_list.transparent_double_pass
    let transparent_objects = render_list.transparent
    let opaque_objects = render_list.opaque_
    if self.opaque_ == true && opaque_objects.length() > 0 {
      self._render_objects(opaque_objects, camera, scene_ref, lights_node)
    }
    if self.transparent == true && transparent_objects.length() > 0 {
      self._render_transparents(
        transparent_objects, transparent_double_pass_objects, camera, scene_ref,
        lights_node,
      )
    }
    self._current_render_bundle = previous_render_bundle
    //
    self.backend.finish_bundle(render_context, render_bundle)
  } else {
    let render_objects = render_bundle_data.get("renderObjects")
    let nodes = self._nodes()
    for i in 0..<renderer_js_length(render_objects) {
      let render_object : RenderObject = renderer_js_index(render_objects, i).cast()
      let refresh_type = nodes.needs_refresh(render_object)
      if refresh_type == @core.RenderObjectRefreshType_FULL {
        nodes.update_before(render_object)
        self._geometries().update_for_render(render_object)
        nodes.update_for_render(render_object)
        self._bindings().update_for_render(render_object)
        nodes.update_after(render_object)
      } else if refresh_type == @core.RenderObjectRefreshType_SHARED {
        nodes.update_before(render_object)
        nodes.update_for_render(render_object)
        self._bindings().update_shared_for_render(render_object)
        nodes.update_after(render_object)
      }
    }
  }
  self.backend.add_bundle(render_context, render_bundle)
}

///|
/// `render( scene, camera )`: renders a scene, or any object, with a camera.
pub fn Renderer::render(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .render() called before the backend is initialized. Use \"await renderer.init();\" before rendering.",
    )
  }
  self._animation().start()
  self._render_scene(scene, camera) |> ignore
}

///|
/// `get initialized()`.
pub fn Renderer::initialized(self : Renderer) -> Bool {
  self._initialized
}

///|
/// `_renderOutputLayers( quad, renderTarget )`.
fn Renderer::_render_output_layers(
  self : Renderer,
  quad : QuadMesh,
  render_target : @core.RenderTarget,
) -> Unit {
  let use_multiview = self.backend.has_flag("isWebGLBackend") &&
    render_target.multiview == true
  let texture = render_target.texture()
  let layers = texture.image().depth()
  if use_multiview || texture.is_array_texture != true || layers <= 1.0 {
    self._render_scene(
      quad.object,
      quad.camera(),
      use_frame_buffer_target=false,
    )
    |> ignore
    return
  }
  let current_active_cube_face = self._active_cube_face
  let nodes = self._nodes()
  for layer in 0..<layers.to_int() {
    nodes.set_output_layer_index(layer)
    self._active_cube_face = layer
    self._render_scene(
      quad.object,
      quad.camera(),
      use_frame_buffer_target=false,
    )
    |> ignore
  }
  nodes.set_output_layer_index(0)
  self._active_cube_face = current_active_cube_face
}

///|
/// `_getFrameBufferTarget()`: the intermediate target of tone mapping and color space
/// conversion; `None` when the output needs none.
pub fn Renderer::_get_frame_buffer_target(
  self : Renderer,
) -> @core.RenderTarget? {
  if self.needs_frame_buffer_target() == false {
    return None
  }
  let size = self.get_drawing_buffer_size(_renderer_drawing_buffer_size)
  let width = size.x
  let height = size.y
  let depth = self.depth
  let stencil = self.stencil
  // TODO: Unify CanvasTarget and OutputRenderTarget
  let target : FrameBufferTargetOwner = match self._output_render_target {
    Some(t) => Output(t)
    None => Canvas(self._canvas_target)
  }
  let frame_buffer_target = match
    self._frame_buffer_targets.search_by(fn(e) { e.0.same(target) }) {
    Some(i) => self._frame_buffer_targets[i].1
    None => {
      let frame_buffer_target = @core.RenderTarget::new(
        width=width.to_int(),
        height=height.to_int(),
        depth_buffer=depth,
        stencil_buffer=stencil,
        type_=self._output_buffer_type,
        format=@core.RGBAFormat,
        color_space=@math.color_management.working_color_space,
        generate_mipmaps=false,
        min_filter=@core.LinearFilter,
        mag_filter=@core.LinearFilter,
        samples=self.samples(),
      )
      render_target_props(frame_buffer_target).is_post_processing_render_target
      = Some(true)
      let dispose : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
      dispose.val = fn(_) {
        match target {
          Output(t) => t.remove_event_listener("dispose", dispose.val)
          Canvas(t) => t.remove_event_listener("dispose", dispose.val)
        }
        frame_buffer_target.dispose()
        match self._frame_buffer_targets.search_by(fn(e) { e.0.same(target) }) {
          Some(i) => self._frame_buffer_targets.remove(i) |> ignore
          None => ()
        }
        let key = @core.JsValue::of(frame_buffer_target)
        match self._quad_cache.get(key) {
          Some(quad_data) => {
            quad_data.quad.material().dispose()
            self._quad_cache.delete(key)
          }
          None => ()
        }
      }
      match target {
        Output(t) => t.add_event_listener("dispose", dispose.val)
        Canvas(t) => t.add_event_listener("dispose", dispose.val)
      }
      self._frame_buffer_targets.push((target, frame_buffer_target))
      frame_buffer_target
    }
  }
  let output_render_target = self.get_output_render_target()
  frame_buffer_target.depth_buffer = depth
  frame_buffer_target.stencil_buffer = stencil
  match output_render_target {
    Some(o) => frame_buffer_target.set_size(o.width, o.height, depth=o.depth)
    None =>
      frame_buffer_target.set_size(width.to_int(), height.to_int(), depth=1)
  }
  // RenderTarget || CanvasTarget
  match self._output_render_target {
    Some(o) => {
      frame_buffer_target.viewport.copy(o.viewport) |> ignore
      frame_buffer_target.scissor.copy(o.scissor) |> ignore
      frame_buffer_target.viewport.multiply_scalar(1.0) |> ignore
      frame_buffer_target.scissor.multiply_scalar(1.0) |> ignore
      frame_buffer_target.scissor_test = o.scissor_test
    }
    None => {
      let canvas = self._canvas_target
      frame_buffer_target.viewport.copy(canvas._viewport) |> ignore
      frame_buffer_target.scissor.copy(canvas._scissor) |> ignore
      frame_buffer_target.viewport.multiply_scalar(canvas._pixel_ratio)
      |> ignore
      frame_buffer_target.scissor.multiply_scalar(canvas._pixel_ratio) |> ignore
      frame_buffer_target.scissor_test = canvas._scissor_test
    }
  }
  let props = render_target_props(frame_buffer_target)
  match output_render_target {
    Some(o) => {
      frame_buffer_target.multiview = o.multiview
      frame_buffer_target.use_array_depth_texture = o.use_array_depth_texture
      frame_buffer_target.resolve_depth_buffer = o.resolve_depth_buffer
      frame_buffer_target.resolve_stencil_buffer = o.resolve_stencil_buffer
      frame_buffer_target.store_multisampled_color_buffer = o.store_multisampled_color_buffer
      frame_buffer_target.store_multisampled_depth_buffer = o.store_multisampled_depth_buffer
      frame_buffer_target.store_multisampled_stencil_buffer = o.store_multisampled_stencil_buffer
      props._auto_allocate_depth_buffer = render_target_props(o)._auto_allocate_depth_buffer
    }
    None => {
      frame_buffer_target.multiview = false
      frame_buffer_target.use_array_depth_texture = false
      frame_buffer_target.resolve_depth_buffer = true
      frame_buffer_target.resolve_stencil_buffer = true
      frame_buffer_target.store_multisampled_color_buffer = true
      frame_buffer_target.store_multisampled_depth_buffer = true
      frame_buffer_target.store_multisampled_stencil_buffer = true
      props._auto_allocate_depth_buffer = Some(false)
    }
  }
  Some(frame_buffer_target)
}

///|
/// `sceneRef.onBeforeRender( renderer, scene, camera, renderTarget )`.
fn _renderer_scene_on_before_render(
  renderer : Renderer,
  scene_ref : @core.Object3D,
  scene : @core.Object3D,
  camera : @core.Object3D,
  render_target : @core.RenderTarget?,
) -> Unit {
  match scene_ref.kind {
    Scene(s) =>
      (s.on_before_render)(
        @core.JsValue::of(renderer),
        scene,
        camera,
        render_target,
      )
    _ => ()
  }
}

///|
/// `sceneRef.onAfterRender( renderer, scene, camera, renderTarget )`.
fn _renderer_scene_on_after_render(
  renderer : Renderer,
  scene_ref : @core.Object3D,
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> Unit {
  match scene_ref.kind {
    Scene(s) => (s.on_after_render)(@core.JsValue::of(renderer), scene, camera)
    _ => ()
  }
}

///|
/// `_renderScene( scene, camera, useFrameBufferTarget = true )`: one render pass;
/// returns the render context (`None` when the device is lost).
pub fn Renderer::_render_scene(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  use_frame_buffer_target~ : Bool = true,
) -> RenderContext? {
  if self._is_device_lost == true {
    return None
  }
  if self.shadow_map.type_ == @core.PCFSoftShadowMap {
    @core.warn(
      "WebGPURenderer: PCFSoftShadowMap has been removed. Using PCFShadowMap instead.",
    )
    self.shadow_map.type_ = @core.PCFShadowMap
  }
  //
  let frame_buffer_target = if use_frame_buffer_target {
    self._get_frame_buffer_target()
  } else {
    None
  }
  // preserve render tree
  let nodes = self._nodes()
  let node_frame = nodes.node_frame
  let previous_render_id = node_frame.render_id
  let previous_render_context = self._current_render_context
  let previous_render_object_function = self._current_render_object_function
  let previous_handle_object_function = self._handle_object_function
  let previous_render_bundle = self._current_render_bundle
  // a render nested in the recording of a render bundle draws its objects directly
  self._current_render_bundle = None
  self.lighting.begin_render(scene)
  //
  self._call_depth += 1
  let scene_ref = if scene.is_scene() { scene } else { _renderer_scene }
  let output_render_target = match self._render_target {
    Some(t) => Some(t)
    None => self._output_render_target
  }
  let use_xr_camera = self.xr.is_presenting == true && self.is_output_target()
  let active_cube_face = self._active_cube_face
  let active_mipmap_level = self._active_mipmap_level
  //
  let render_target = match frame_buffer_target {
    Some(t) => {
      self.set_render_target(Some(t))
      Some(t)
    }
    None => output_render_target
  }
  // make sure a new render target has correct default depth values
  match render_target {
    Some(rt) if rt.depth_buffer == true => {
      let render_target_data = self._textures().get_render_target(rt)
      if render_target_data.depth_initialized != Some(true) {
        // we need a single manual clear if auto clear depth is disabled
        if self.auto_clear == false ||
          (self.auto_clear == true && self.auto_clear_depth == false) {
          self.clear_depth()
        }
        render_target_data.depth_initialized = Some(true)
      }
    }
    _ => ()
  }
  //
  let render_context = self
    ._render_contexts()
    .get(render_target?, mrt?=self._mrt, call_depth=self._call_depth, camera~)
  self._current_render_context = Some(render_context)
  self._current_render_object_function = self._render_object_function
  self._handle_object_function = RenderObjectDirect
  //
  self.info.calls += 1
  self.info.render.calls += 1
  self.info.render.frame_calls += 1
  node_frame.render_id = self.info.calls
  //
  self.backend.update_time_stamp_uid(render_context)
  self
  .inspector()
  .begin_render(
    self.backend
    .get_timestamp_uid(@core.JsValue::of(render_context))
    .unwrap_or(""),
    scene,
    camera,
    render_target,
  )
  //
  if scene.matrix_world_auto_update == true {
    scene.update_matrix_world()
  }
  let camera = self._update_camera(camera, use_xr_camera)
  //
  let canvas_target = self._canvas_target
  let (viewport, scissor, scissor_test, pixel_ratio, min_depth, max_depth) = match
    render_target {
    Some(rt) => (rt.viewport, rt.scissor, rt.scissor_test, 1.0, None, None)
    None =>
      (
        canvas_target._viewport,
        canvas_target._scissor,
        canvas_target._scissor_test,
        canvas_target._pixel_ratio,
        canvas_target._viewport_min_depth,
        canvas_target._viewport_max_depth,
      )
  }
  let min_depth = min_depth.unwrap_or(0.0)
  let max_depth = max_depth.unwrap_or(1.0)
  let viewport_value = render_context.viewport_value
  viewport_value.copy(viewport).multiply_scalar(pixel_ratio).floor() |> ignore
  viewport_value.z = renderer_shr(viewport_value.z, active_mipmap_level)
  viewport_value.w = renderer_shr(viewport_value.w, active_mipmap_level)
  render_context.viewport_min_depth = Some(min_depth)
  render_context.viewport_max_depth = Some(max_depth)
  let scissor_value = render_context.scissor_value
  scissor_value.copy(scissor).multiply_scalar(pixel_ratio).floor() |> ignore
  scissor_value.z = renderer_shr(scissor_value.z, active_mipmap_level)
  scissor_value.w = renderer_shr(scissor_value.w, active_mipmap_level)
  if render_context.clipping_context is None {
    render_context.clipping_context = Some(ClippingContext::new())
  }
  render_context.clipping_context.unwrap().update_global(scene_ref, camera)
  //
  _renderer_scene_on_before_render(
    self, scene_ref, scene, camera, render_target,
  )
  //
  let drawing_pipeline = self.drawing_pipeline()
  drawing_pipeline.begin(camera, render_context)
  self._render_lists().update(node_frame.frame_id)
  let render_list = self._render_lists().get(scene, camera, self.lighting)
  drawing_pipeline.begin_render_list(render_list)
  drawing_pipeline.project(
    scene,
    camera,
    0,
    render_list,
    render_context.clipping_context,
  )
  drawing_pipeline.finish_render_list(render_list)
  if self.sort_objects == true {
    render_list.sort(self._opaque_sort, self._transparent_sort)
  }
  //
  match render_target {
    Some(rt) => {
      self._textures().update_render_target(rt, active_mipmap_level~)
      let render_target_data = self._textures().get_render_target(rt)
      render_context.textures = render_target_data.textures
      render_context.depth_texture = render_target_data.depth_texture
      render_context.width = render_target_data.width.unwrap_or(0)
      render_context.height = render_target_data.height.unwrap_or(0)
      render_context.render_target = Some(rt)
      render_context.depth = rt.depth_buffer
      render_context.stencil = rt.stencil_buffer
    }
    None => {
      self.get_drawing_buffer_size(_renderer_drawing_buffer_size) |> ignore
      render_context.textures = None
      render_context.depth_texture = None
      render_context.width = _renderer_drawing_buffer_size.x.to_int()
      render_context.height = _renderer_drawing_buffer_size.y.to_int()
      render_context.depth = self.depth
      render_context.stencil = self.stencil
    }
  }
  render_context.width = renderer_shr_int(
    render_context.width,
    active_mipmap_level,
  )
  render_context.height = renderer_shr_int(
    render_context.height,
    active_mipmap_level,
  )
  render_context.active_cube_face = active_cube_face
  render_context.active_mipmap_level = active_mipmap_level
  render_context.occlusion_query_count = render_list.occlusion_query_count
  render_context.fullscreen_pass = scene.has_extension_flag("isQuadMesh")
  //
  scissor_value.max(_renderer_vector4.set(0.0, 0.0, 0.0, 0.0)) |> ignore
  let width = render_context.width.to_double()
  let height = render_context.height.to_double()
  if scissor_value.x + scissor_value.z > width {
    scissor_value.z = renderer_math_max(width - scissor_value.x, 0.0)
  }
  if scissor_value.y + scissor_value.w > height {
    scissor_value.w = renderer_math_max(height - scissor_value.y, 0.0)
  }
  _renderer_screen.set(0.0, 0.0, width, height) |> ignore
  render_context.viewport = viewport_value.equals(_renderer_screen) == false
  render_context.scissor = scissor_test &&
    scissor_value.equals(_renderer_screen) == false
  //
  self._background().update(scene_ref, render_list, render_context)
  //
  render_context.camera = Some(camera)
  self.backend.begin_render(render_context)
  // process render lists
  let bundles = render_list.bundles
  let lights_node = render_list.lights_node
  let transparent_double_pass_objects = render_list.transparent_double_pass
  let transparent_objects = render_list.transparent
  let opaque_objects = render_list.opaque_
  if bundles.length() > 0 {
    self._render_bundles(bundles, scene_ref, lights_node)
  }
  if self.opaque_ == true && opaque_objects.length() > 0 {
    self._render_objects(opaque_objects, camera, scene_ref, lights_node)
  }
  if self.transparent == true && transparent_objects.length() > 0 {
    self._render_transparents(
      transparent_objects, transparent_double_pass_objects, camera, scene_ref, lights_node,
    )
  }
  // finish render pass
  self.backend.finish_render(render_context)
  // restore render tree
  node_frame.render_id = previous_render_id
  self._current_render_context = previous_render_context
  self._current_render_object_function = previous_render_object_function
  self._handle_object_function = previous_handle_object_function
  self._current_render_bundle = previous_render_bundle
  self.lighting.finish_render(scene)
  //
  self._call_depth -= 1
  match frame_buffer_target {
    Some(_) => {
      self.set_render_target(
        output_render_target,
        active_cube_face~,
        active_mipmap_level~,
      )
      self._render_output(render_target.unwrap())
    }
    None => ()
  }
  //
  _renderer_scene_on_after_render(self, scene_ref, scene, camera)
  //
  self
  .inspector()
  .finish_render(
    self.backend
    .get_timestamp_uid(@core.JsValue::of(render_context))
    .unwrap_or(""),
  )
  //
  Some(render_context)
}

///|
/// `_setXRLayerSize( width, height )`.
pub fn Renderer::_set_xr_layer_size(
  self : Renderer,
  width : Double,
  height : Double,
) -> Unit {
  // TODO: Find a better solution to resize the canvas when in XR.
  self._canvas_target._width = width
  self._canvas_target._height = height
  self.set_viewport(0.0, 0.0, width, height)
}

///|
/// `_renderOutput( renderTarget )`: draws the frame buffer target to the output with
/// tone mapping and color space conversion.
fn Renderer::_render_output(
  self : Renderer,
  render_target : @core.RenderTarget,
) -> Unit {
  let nodes = self._nodes()
  let cache_key = nodes.get_output_cache_key()
  let key = @core.JsValue::of(render_target)
  let quad = match self._quad_cache.get(key) {
    None => {
      let quad = QuadMesh::new(material=NodeMaterial::new())
      quad.object.name = "Output Color Transform"
      quad.material().name = "outputColorTransform"
      NodeMaterial::of(quad.material()).unwrap().fragment_node = Some(
        nodes.get_output_node(render_target.texture()),
      )
      self._quad_cache.set(key, { quad, cache_key, })
      quad
    }
    Some(quad_data) => {
      let quad = quad_data.quad
      if quad_data.cache_key != cache_key {
        NodeMaterial::of(quad.material()).unwrap().fragment_node = Some(
          nodes.get_output_node(render_target.texture()),
        )
        quad.material().set_needs_update(true)
        quad_data.cache_key = cache_key
      }
      quad
    }
  }
  // a clear operation clears the intermediate renderTarget texture, but should not update the screen canvas.
  let current_auto_clear = self.auto_clear
  let current_xr = self.xr.enabled
  self.auto_clear = false
  self.xr.enabled = false
  self._render_output_layers(quad, render_target)
  self.auto_clear = current_auto_clear
  self.xr.enabled = current_xr
}

///|
pub fn Renderer::get_max_anisotropy(self : Renderer) -> Int32 {
  self.backend.get_max_anisotropy()
}

///|
pub fn Renderer::get_active_cube_face(self : Renderer) -> Int32 {
  self._active_cube_face
}

///|
pub fn Renderer::get_active_mipmap_level(self : Renderer) -> Int32 {
  self._active_mipmap_level
}

///|
/// `async setAnimationLoop( callback )`; `None` is `null`.
pub fn Renderer::set_animation_loop(
  self : Renderer,
  callback : ((Double, @core.JsValue) -> Unit)?,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  fn start() -> Unit {
    // started before assigning the callback, so it first runs on the next frame
    if callback is Some(_) {
      self._animation().start()
    }
    self._animation().set_animation_loop(callback)
    on_done()
  }

  if self._initialized == false {
    self.init(on_done=fn(error) {
      match error {
        None => start()
        Some(e) => abort(e)
      }
    })
  } else {
    start()
  }
}

///|
pub fn Renderer::get_animation_loop(
  self : Renderer,
) -> ((Double, @core.JsValue) -> Unit)? {
  self._animation().get_animation_loop()
}

///|
/// `async getArrayBufferAsync( attribute, target = null, offset = 0, count = -1 )`.
pub fn Renderer::get_array_buffer_async(
  self : Renderer,
  attribute : AttributeBuffer,
  target? : ReadbackBuffer,
  offset~ : Int32 = 0,
  count~ : Int32 = -1,
  on_done : (@core.JsValue) -> Unit,
) -> Unit {
  // tally the memory for this readback buffer
  match target {
    Some(target) =>
      if self.info.memory_map_has(@core.JsValue::of(target)) == false {
        self.info.create_readback_buffer(target)
        let dispose_info : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
        dispose_info.val = fn(_) {
          target.remove_event_listener("dispose", dispose_info.val)
          self.info.destroy_readback_buffer(target)
        }
        target.add_event_listener("dispose", dispose_info.val)
      }
    None => ()
  }
  if offset % 4 != 0 || (count > 0 && count % 4 != 0) {
    abort(
      "THREE.Renderer: \"getArrayBufferAsync()\" offset and count must be a multiple of 4.",
    )
  }
  self.backend.get_array_buffer_async(attribute, target, offset, count, on_done)
}

///|
pub fn Renderer::get_context(self : Renderer) -> @core.JsValue {
  self.backend.get_context()
}

///|
pub fn Renderer::get_pixel_ratio(self : Renderer) -> Double {
  self._canvas_target.get_pixel_ratio()
}

///|
/// `getDrawingBufferSize( target )`.
pub fn Renderer::get_drawing_buffer_size(
  self : Renderer,
  target : @math.Vector2,
) -> @math.Vector2 {
  self._canvas_target.get_drawing_buffer_size(target)
}

///|
/// `getSize( target )`.
pub fn Renderer::get_size(
  self : Renderer,
  target : @math.Vector2,
) -> @math.Vector2 {
  self._canvas_target.get_size(target)
}

///|
/// `setPixelRatio( value = 1 )`.
pub fn Renderer::set_pixel_ratio(self : Renderer, value : Double) -> Unit {
  self._canvas_target.set_pixel_ratio(value~)
}

///|
/// `setDrawingBufferSize( width, height, pixelRatio )`.
pub fn Renderer::set_drawing_buffer_size(
  self : Renderer,
  width : Double,
  height : Double,
  pixel_ratio : Double,
) -> Unit {
  // Renderer can't be resized while presenting in XR.
  if self.xr.is_presenting {
    return
  }
  self._canvas_target.set_drawing_buffer_size(width, height, pixel_ratio)
}

///|
/// `setSize( width, height, updateStyle = true )`.
pub fn Renderer::set_size(
  self : Renderer,
  width : Double,
  height : Double,
  update_style~ : Bool = true,
) -> Unit {
  // Renderer can't be resized while presenting in XR.
  if self.xr.is_presenting {
    return
  }
  self._canvas_target.set_size(width, height, update_style~)
}

///|
/// `setOpaqueSort( method )`; `None` is `null`.
pub fn Renderer::set_opaque_sort(
  self : Renderer,
  sort : ((RenderItem, RenderItem) -> Double)?,
) -> Unit {
  self._opaque_sort = sort
}

///|
/// `setTransparentSort( method )`; `None` is `null`.
pub fn Renderer::set_transparent_sort(
  self : Renderer,
  sort : ((RenderItem, RenderItem) -> Double)?,
) -> Unit {
  self._transparent_sort = sort
}

///|
pub fn Renderer::get_scissor(
  self : Renderer,
  target : @math.Vector4,
) -> @math.Vector4 {
  self._canvas_target.get_scissor(target)
}

///|
pub fn Renderer::set_scissor(
  self : Renderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self._canvas_target.set_scissor(x, y, width, height)
}

///|
/// `setScissor( vector4 )`.
pub fn Renderer::set_scissor_vector(self : Renderer, x : @math.Vector4) -> Unit {
  self._canvas_target.set_scissor_vector(x)
}

///|
pub fn Renderer::get_scissor_test(self : Renderer) -> Bool {
  self._canvas_target.get_scissor_test()
}

///|
pub fn Renderer::set_scissor_test(self : Renderer, boolean : Bool) -> Unit {
  self._canvas_target.set_scissor_test(boolean)
  // TODO: Move it to CanvasTarget event listener.
  self.backend.set_scissor_test(boolean)
}

///|
pub fn Renderer::reset_state(self : Renderer) -> Unit {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .resetState() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self.backend.reset_state()
}

///|
pub fn Renderer::get_viewport(
  self : Renderer,
  target : @math.Vector4,
) -> @math.Vector4 {
  self._canvas_target.get_viewport(target)
}

///|
/// `setViewport( x, y, width, height, minDepth = 0, maxDepth = 1 )`.
pub fn Renderer::set_viewport(
  self : Renderer,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  min_depth~ : Double = 0.0,
  max_depth~ : Double = 1.0,
) -> Unit {
  self._canvas_target.set_viewport(x, y, width, height, min_depth~, max_depth~)
}

///|
/// `setViewport( vector4, minDepth = 0, maxDepth = 1 )`.
pub fn Renderer::set_viewport_vector(
  self : Renderer,
  x : @math.Vector4,
  min_depth~ : Double = 0.0,
  max_depth~ : Double = 1.0,
) -> Unit {
  self._canvas_target.set_viewport_vector(x, min_depth~, max_depth~)
}

///|
/// `getClearColor( target )` with a `Color` target (the alpha is not copied).
pub fn Renderer::get_clear_color(
  self : Renderer,
  target : @math.Color,
) -> @math.Color {
  target.copy(self._clear_color.color)
}

///|
/// `getClearColor( target )` with a `Color4` target.
pub fn Renderer::get_clear_color4(self : Renderer, target : Color4) -> Color4 {
  target.copy(self._clear_color)
}

///|
/// `setClearColor( color, alpha = 1 )`.
pub fn Renderer::set_clear_color(
  self : Renderer,
  color : @math.Color,
  alpha~ : Double = 1.0,
) -> Unit {
  self._clear_color.set_color(color) |> ignore
  self._clear_color.a = alpha
}

///|
/// `setClearColor( hex, alpha = 1 )` with a hex number.
pub fn Renderer::set_clear_color_hex(
  self : Renderer,
  hex : Int32,
  alpha~ : Double = 1.0,
) -> Unit {
  self._clear_color.set_hex(hex) |> ignore
  self._clear_color.a = alpha
}

///|
pub fn Renderer::get_clear_alpha(self : Renderer) -> Double {
  self._clear_color.a
}

///|
pub fn Renderer::set_clear_alpha(self : Renderer, alpha : Double) -> Unit {
  self._clear_color.a = alpha
}

///|
/// `getClearDepth()`.
pub fn Renderer::get_clear_depth(self : Renderer) -> Double {
  if self.reversed_depth_buffer {
    1.0 - self._clear_depth
  } else {
    self._clear_depth
  }
}

///|
pub fn Renderer::set_clear_depth(self : Renderer, depth : Double) -> Unit {
  self._clear_depth = depth
}

///|
/// `getClearStencil()`.
pub fn Renderer::get_clear_stencil(self : Renderer) -> Int32 {
  self._clear_stencil
}

///|
pub fn Renderer::set_clear_stencil(self : Renderer, stencil : Int32) -> Unit {
  self._clear_stencil = stencil
}

///|
/// `isOccluded( object )`.
pub fn Renderer::is_occluded(self : Renderer, object : @core.Object3D) -> Bool {
  match self._current_render_context {
    Some(render_context) => self.backend.is_occluded(render_context, object)
    None => false
  }
}

///|
/// `clear( color = true, depth = true, stencil = true )`.
pub fn Renderer::clear(
  self : Renderer,
  color~ : Bool = true,
  depth~ : Bool = true,
  stencil~ : Bool = true,
) -> Unit {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .clear() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  let render_target = match self._render_target {
    Some(t) => Some(t)
    None => self._get_frame_buffer_target()
  }
  let render_context = match render_target {
    Some(rt) => {
      self._textures().update_render_target(rt)
      let render_target_data = self._textures().get_render_target(rt)
      // using - 1 for the call depth to get a render context for the clear operation
      let render_context = self
        ._render_contexts()
        .get(render_target=rt, call_depth=-1)
      render_context.textures = render_target_data.textures
      render_context.depth_texture = render_target_data.depth_texture
      render_context.width = render_target_data.width.unwrap_or(0)
      render_context.height = render_target_data.height.unwrap_or(0)
      render_context.render_target = Some(rt)
      render_context.depth = rt.depth_buffer
      render_context.stencil = rt.stencil_buffer
      // #30329
      let clear_color = self.backend.get_clear_color()
      render_context.clear_color_value.r = clear_color.color.r
      render_context.clear_color_value.g = clear_color.color.g
      render_context.clear_color_value.b = clear_color.color.b
      render_context.clear_color_value.a = clear_color.a
      render_context.clear_depth_value = self.get_clear_depth()
      render_context.clear_stencil_value = self.get_clear_stencil()
      render_context.active_cube_face = self.get_active_cube_face()
      render_context.active_mipmap_level = self.get_active_mipmap_level()
      if rt.depth_buffer == true {
        render_target_data.depth_initialized = Some(true)
      }
      Some(render_context)
    }
    None => None
  }
  self.backend.clear(color, depth, stencil, render_context)
  match render_target {
    Some(rt) if self._render_target is None => self._render_output(rt)
    _ => ()
  }
}

///|
pub fn Renderer::clear_color(self : Renderer) -> Unit {
  self.clear(color=true, depth=false, stencil=false)
}

///|
pub fn Renderer::clear_depth(self : Renderer) -> Unit {
  self.clear(color=false, depth=true, stencil=false)
}

///|
pub fn Renderer::clear_stencil(self : Renderer) -> Unit {
  self.clear(color=false, depth=false, stencil=true)
}

///|
/// `async clearAsync( color = true, depth = true, stencil = true )` (deprecated).
pub fn Renderer::clear_async(
  self : Renderer,
  color~ : Bool = true,
  depth~ : Bool = true,
  stencil~ : Bool = true,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  @core.warn_once(
    "Renderer: \"clearAsync()\" has been deprecated. Use \"clear()\" and \"await renderer.init();\" when creating the renderer.",
  )
  self.init(on_done=fn(error) {
    match error {
      None => {
        self.clear(color~, depth~, stencil~)
        on_done()
      }
      Some(e) => abort(e)
    }
  })
}

///|
/// `get needsFrameBufferTarget()`: whether the output needs tone mapping or a color
/// space conversion.
pub fn Renderer::needs_frame_buffer_target(self : Renderer) -> Bool {
  let use_tone_mapping = self.current_tone_mapping() != @core.NoToneMapping
  let use_color_space = self.current_color_space() !=
    @math.color_management.working_color_space
  use_tone_mapping || use_color_space
}

///|
/// `get samples()`.
pub fn Renderer::samples(self : Renderer) -> Int32 {
  self._samples
}

///|
/// `get currentSamples()`: the samples of the current render target.
pub fn Renderer::current_samples(self : Renderer) -> Int32 {
  let mut samples = self._samples
  match self._render_target {
    Some(rt) => samples = rt.samples
    None =>
      if self.needs_frame_buffer_target() ||
        (self._current_render_context is Some(c) && c.fullscreen_pass == true) {
        samples = 0
      }
  }
  samples
}

///|
/// `get currentToneMapping()`.
pub fn Renderer::current_tone_mapping(self : Renderer) -> Int32 {
  if self.is_output_target() {
    self.tone_mapping
  } else {
    @core.NoToneMapping
  }
}

///|
/// `get currentColorSpace()`.
pub fn Renderer::current_color_space(self : Renderer) -> String {
  if self.is_output_target() {
    self.output_color_space
  } else {
    @math.color_management.working_color_space
  }
}

///|
/// `get isOutputTarget()`: whether rendering goes to the output (screen or output target).
pub fn Renderer::is_output_target(self : Renderer) -> Bool {
  match (self._render_target, self._output_render_target) {
    (None, _) => true
    (Some(a), Some(b)) => physical_equal(a, b)
    (Some(_), None) => false
  }
}

///|
/// `async dispose()`: frees the renderer's resources; calls back when done.
pub fn Renderer::dispose(
  self : Renderer,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  fn run() -> Unit {
    if self._initialized == true {
      // the drawing pipeline frees its resources while the managers of the renderer still track them
      self.drawing_pipeline().dispose()
      self.lighting.dispose()
      self._inspector.dispose()
      self._animation().dispose()
      self._objects().dispose()
      self._geometries().dispose()
      self._attributes().dispose()
      self._pipelines().dispose()
      self._nodes().dispose()
      self._bindings().dispose()
      self._render_lists().dispose()
      self._render_contexts().dispose()
      for entry in self._frame_buffer_targets.copy() {
        entry.0.dispose()
      }
      self._destroy_canvas_target(self._canvas_target)
      self._textures().dispose()
      self.info.dispose()
      self.backend.dispose(fn() {
        self.set_render_target(None)
        on_done()
      })
    } else {
      self.set_render_target(None)
      on_done()
    }
  }

  // edge case: If dispose() is called during an init, wait for the finish
  match self._init_promise {
    NotStarted => run()
    _ => self.init(on_done=fn(_) { run() })
  }
}

///|
/// `setRenderTarget( renderTarget, activeCubeFace = 0, activeMipmapLevel = 0 )`.
pub fn Renderer::set_render_target(
  self : Renderer,
  render_target : @core.RenderTarget?,
  active_cube_face~ : Int32 = 0,
  active_mipmap_level~ : Int32 = 0,
) -> Unit {
  self._render_target = render_target
  self._active_cube_face = active_cube_face
  self._active_mipmap_level = active_mipmap_level
}

///|
pub fn Renderer::get_render_target(self : Renderer) -> @core.RenderTarget? {
  self._render_target
}

///|
pub fn Renderer::set_output_render_target(
  self : Renderer,
  render_target : @core.RenderTarget?,
) -> Unit {
  self._output_render_target = render_target
}

///|
/// `getOutputRenderTarget()`.
pub fn Renderer::get_output_render_target(
  self : Renderer,
) -> @core.RenderTarget? {
  self._output_render_target
}

///|
/// `setCanvasTarget( canvasTarget )`.
pub fn Renderer::set_canvas_target(
  self : Renderer,
  canvas_target : CanvasTarget,
) -> Unit {
  self._canvas_target.remove_event_listener(
    "resize",
    self._on_canvas_target_resize,
  )
  // keep any dispose event listener attached for later use
  self._canvas_target = canvas_target
  self._canvas_target.add_event_listener(
    "resize",
    self._on_canvas_target_resize,
  )
  self._canvas_target.add_event_listener(
    "dispose",
    self._on_canvas_target_dispose,
  )
}

///|
pub fn Renderer::get_canvas_target(self : Renderer) -> CanvasTarget {
  self._canvas_target
}

///|
/// `_resetXRState()`.
pub fn Renderer::_reset_xr_state(self : Renderer) -> Unit {
  self.backend.set_xr_target(None)
  self.set_output_render_target(None)
  self.set_render_target(None)
  for entry in self._frame_buffer_targets.copy() {
    entry.0.dispose()
  }
}

///|
/// `setRenderObjectFunction( renderObjectFunction )`; `None` is `null`.
pub fn Renderer::set_render_object_function(
  self : Renderer,
  render_object_function : RenderObjectFunction?,
) -> Unit {
  self._render_object_function = render_object_function
}

///|
/// `getRenderObjectFunction()`; `None` is `null`.
pub fn Renderer::get_render_object_function(
  self : Renderer,
) -> RenderObjectFunction? {
  self._render_object_function
}

///|
/// `compute( computeNode, dispatchSize = null )`.
pub fn Renderer::compute(
  self : Renderer,
  compute_node : Node,
  dispatch_size? : ComputeDispatchSize,
) -> Unit {
  self._compute(Node(compute_node), dispatch_size)
}

///|
/// `compute( computeNodes, dispatchSize = null )` with an array.
pub fn Renderer::compute_list(
  self : Renderer,
  compute_nodes : Array[Node],
  dispatch_size? : ComputeDispatchSize,
) -> Unit {
  self._compute(Nodes(compute_nodes), dispatch_size)
}

///|
fn ComputeGroup::list(self : ComputeGroup) -> Array[Node] {
  match self {
    Node(n) => [n]
    Nodes(a) => a
  }
}

///|
fn Renderer::_compute(
  self : Renderer,
  compute_nodes : ComputeGroup,
  dispatch_size : ComputeDispatchSize?,
) -> Unit {
  if self._is_device_lost == true {
    return
  }
  if self._initialized == false {
    @core.warn(
      "Renderer: \".compute()\" called before the backend is initialized. Try using \".computeAsync()\" instead.",
    )
    self._compute_async(compute_nodes, dispatch_size, fn() {  })
    return
  }
  let compute_list = compute_nodes.list()
  _renderer_check_compute_nodes(
    compute_list, "THREE.Renderer: \".compute()\" expects a \"ComputeNode\".",
  )
  if dispatch_size is Some(_) &&
    compute_list
    .iter()
    .any(fn(n) {
      match ComputeNode::of(n) {
        Some(c) => c.count is Some(_) || c.dispatch_size is Some(_)
        None => false
      }
    }) {
    abort(
      "THREE.Renderer: A dispatch size cannot be passed to \"renderer.compute()\" for nodes created with \"compute( count )\". Use \"computeKernel()\" instead.",
    )
  }
  //
  self._animation().start()
  let nodes = self._nodes()
  let node_frame = nodes.node_frame
  let previous_render_id = node_frame.render_id
  //
  self.info.calls += 1
  self.info.compute.calls += 1
  self.info.compute.frame_calls += 1
  node_frame.render_id = self.info.calls
  //
  let backend = self.backend
  backend.update_time_stamp_uid_compute(compute_nodes)
  let first = compute_list[0]
  self
  .inspector()
  .begin_compute(
    backend.get_timestamp_uid(compute_nodes.key()).unwrap_or(""),
    first,
  )
  //
  let pipelines = self._pipelines()
  let bindings = self._bindings()
  backend.begin_compute(compute_nodes)
  for compute_node in compute_list {
    // onInit
    self._init_compute_node(compute_node)
    nodes.update_before_for_compute(compute_node)
    nodes.update_for_compute(compute_node)
    bindings.update_for_compute(compute_node)
    let compute_bindings = bindings.get_for_compute(compute_node)
    let compute_pipeline = pipelines.get_for_compute(
      compute_node, compute_bindings,
    )
    self._update_dispatch_size(compute_node, dispatch_size)
    backend.compute(
      compute_nodes, compute_node, compute_bindings, compute_pipeline, dispatch_size,
    )
    nodes.update_after_for_compute(compute_node)
  }
  backend.finish_compute(compute_nodes)
  //
  node_frame.render_id = previous_render_id
  //
  self
  .inspector()
  .finish_compute(backend.get_timestamp_uid(compute_nodes.key()).unwrap_or(""))
}

///|
/// `async computeAsync( computeNode, dispatchSize = null )`.
pub fn Renderer::compute_async(
  self : Renderer,
  compute_node : Node,
  dispatch_size? : ComputeDispatchSize,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  self._compute_async(Node(compute_node), dispatch_size, on_done)
}

///|
/// `async computeAsync( computeNodes, dispatchSize = null )` with an array.
pub fn Renderer::compute_async_list(
  self : Renderer,
  compute_nodes : Array[Node],
  dispatch_size? : ComputeDispatchSize,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  self._compute_async(Nodes(compute_nodes), dispatch_size, on_done)
}

///|
fn Renderer::_compute_async(
  self : Renderer,
  compute_nodes : ComputeGroup,
  dispatch_size : ComputeDispatchSize?,
  on_done : () -> Unit,
) -> Unit {
  if self._initialized == false {
    self.init(on_done=fn(error) {
      match error {
        None => {
          self._compute(compute_nodes, dispatch_size)
          on_done()
        }
        Some(e) => abort(e)
      }
    })
  } else {
    self._compute(compute_nodes, dispatch_size)
    on_done()
  }
}

///|
/// `async hasFeatureAsync( name )` (deprecated).
pub fn Renderer::has_feature_async(
  self : Renderer,
  name : String,
  on_done : (Bool) -> Unit,
) -> Unit {
  @core.warn_once(
    "Renderer: \"hasFeatureAsync()\" has been deprecated. Use \"hasFeature()\" and \"await renderer.init();\" when creating the renderer.",
  )
  self.init(on_done=fn(error) {
    match error {
      None => on_done(self.has_feature(name))
      Some(e) => abort(e)
    }
  })
}

///|
/// `async resolveTimestampsAsync( type = 'render' )`.
pub fn Renderer::resolve_timestamps_async(
  self : Renderer,
  type_~ : String = "render",
  on_done : (Double?) -> Unit,
) -> Unit {
  if self._initialized == false {
    self.init(on_done=fn(error) {
      match error {
        None => self.backend.resolve_timestamps_async(type_~, on_done)
        Some(e) => abort(e)
      }
    })
  } else {
    self.backend.resolve_timestamps_async(type_~, on_done)
  }
}

///|
pub fn Renderer::has_feature(self : Renderer, name : String) -> Bool {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .hasFeature() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self.backend.has_feature(name)
}

///|
pub fn Renderer::has_initialized(self : Renderer) -> Bool {
  self._initialized
}

///|
/// `async initTextureAsync( texture )` (deprecated).
pub fn Renderer::init_texture_async(
  self : Renderer,
  texture : @core.Texture,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  @core.warn_once(
    "Renderer: \"initTextureAsync()\" has been deprecated. Use \"initTexture()\" and \"await renderer.init();\" when creating the renderer.",
  )
  self.init(on_done=fn(error) {
    match error {
      None => {
        self.init_texture(texture)
        on_done()
      }
      Some(e) => abort(e)
    }
  })
}

///|
/// `initTexture( texture )`: uploads the texture.
pub fn Renderer::init_texture(self : Renderer, texture : @core.Texture) -> Unit {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .initTexture() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self._textures().update_texture(texture) |> ignore
}

///|
/// `initRenderTarget( renderTarget )`: creates the render target's textures.
pub fn Renderer::init_render_target(
  self : Renderer,
  render_target : @core.RenderTarget,
) -> Unit {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .initRenderTarget() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self._textures().update_render_target(render_target)
  let render_target_data = self._textures().get_render_target(render_target)
  let render_context = self._render_contexts().get(render_target~)
  render_context.textures = render_target_data.textures
  render_context.depth_texture = render_target_data.depth_texture
  render_context.width = render_target_data.width.unwrap_or(0)
  render_context.height = render_target_data.height.unwrap_or(0)
  render_context.render_target = Some(render_target)
  render_context.depth = render_target.depth_buffer
  render_context.stencil = render_target.stencil_buffer
  self.backend.init_render_target(render_context)
}

///|
fn _renderer_image_size(texture : @core.Texture) -> (Double, Double) {
  let image = texture.image()
  (image.width(), image.height())
}

///|
/// `copyFramebufferToTexture( framebufferTexture, rectangle = null )` with a
/// `Vector4` rectangle (or the whole texture).
pub fn Renderer::copy_framebuffer_to_texture(
  self : Renderer,
  framebuffer_texture : @core.Texture,
  rectangle? : @math.Vector4,
) -> Unit {
  let rectangle = match rectangle {
    Some(r) => _renderer_vector4.copy(r).floor()
    None => {
      let (width, height) = _renderer_image_size(framebuffer_texture)
      _renderer_vector4.set(0.0, 0.0, width, height)
    }
  }
  self._copy_framebuffer_to_texture(framebuffer_texture, rectangle)
}

///|
/// `copyFramebufferToTexture( framebufferTexture, position )` with a `Vector2`.
pub fn Renderer::copy_framebuffer_to_texture_at(
  self : Renderer,
  framebuffer_texture : @core.Texture,
  position : @math.Vector2,
) -> Unit {
  let (width, height) = _renderer_image_size(framebuffer_texture)
  let rectangle = _renderer_vector4
    .set(position.x, position.y, width, height)
    .floor()
  self._copy_framebuffer_to_texture(framebuffer_texture, rectangle)
}

///|
fn Renderer::_copy_framebuffer_to_texture(
  self : Renderer,
  framebuffer_texture : @core.Texture,
  rectangle : @math.Vector4,
) -> Unit {
  let (render_context, render_target) : (FramebufferSource, @core.RenderTarget?) = match
    self._current_render_context {
    Some(c) => (Context(c), c.render_target)
    None => {
      let render_target = match self._render_target {
        Some(t) => Some(t)
        None => self._get_frame_buffer_target()
      }
      match render_target {
        Some(rt) => {
          self._textures().update_render_target(rt)
          (TargetData(self._textures().get_render_target(rt)), Some(rt))
        }
        None => (NoContext, None)
      }
    }
  }
  //
  let options = TextureOptions::new()
  options.render_target = render_target
  self._textures().update_texture(framebuffer_texture, options~) |> ignore
  self.backend.copy_framebuffer_to_texture(
    framebuffer_texture, render_context, rectangle,
  )
  self._inspector.copy_framebuffer_to_texture(framebuffer_texture)
}

///|
/// `copyTextureToTexture( srcTexture, dstTexture, srcRegion = null, dstPosition = null,
/// srcLevel = 0, dstLevel = 0 )`.
pub fn Renderer::copy_texture_to_texture(
  self : Renderer,
  src_texture : @core.Texture,
  dst_texture : @core.Texture,
  src_region? : TextureCopyRegion,
  dst_position? : TextureCopyPosition,
  src_level~ : Int32 = 0,
  dst_level~ : Int32 = 0,
) -> Unit {
  self._textures().update_texture(src_texture) |> ignore
  self._textures().update_texture(dst_texture) |> ignore
  self.backend.copy_texture_to_texture(
    src_texture, dst_texture, src_region, dst_position, src_level, dst_level,
  )
  self._inspector.copy_texture_to_texture(src_texture, dst_texture)
}

///|
/// `async readRenderTargetPixelsAsync( renderTarget, x, y, width, height, textureIndex
/// = 0, faceIndex = 0 )`: calls back with the pixels.
pub fn Renderer::read_render_target_pixels_async(
  self : Renderer,
  render_target : @core.RenderTarget,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
  texture_index~ : Int32 = 0,
  face_index~ : Int32 = 0,
  on_done : (@core.TypedArray?) -> Unit,
) -> Unit {
  self.backend.copy_texture_to_buffer(
    render_target.textures[texture_index],
    x,
    y,
    width,
    height,
    face_index,
    on_done,
  )
}

///|
fn Renderer::_render_bundles(
  self : Renderer,
  bundles : Array[RenderListBundle],
  scene_ref : @core.Object3D,
  lights_node : Node,
) -> Unit {
  for bundle in bundles {
    self._render_bundle(bundle, scene_ref, lights_node)
  }
}

///|
fn Renderer::_render_transparents(
  self : Renderer,
  render_list : Array[RenderItem],
  double_pass_list : Array[RenderItem],
  camera : @core.Object3D,
  scene : @core.Object3D,
  lights_node : Node,
) -> Unit {
  if double_pass_list.length() > 0 {
    // render back side
    for item in double_pass_list {
      item.material.unwrap().side = @core.BackSide
    }
    self._render_objects(
      double_pass_list,
      camera,
      scene,
      lights_node,
      pass_id="backSide",
    )
    // render front side
    for item in double_pass_list {
      item.material.unwrap().side = @core.FrontSide
    }
    self._render_objects(render_list, camera, scene, lights_node)
    // restore
    for item in double_pass_list {
      item.material.unwrap().side = @core.DoubleSide
    }
  } else {
    self._render_objects(render_list, camera, scene, lights_node)
  }
}

///|
fn Renderer::_render_objects(
  self : Renderer,
  render_list : Array[RenderItem],
  camera : @core.Object3D,
  scene : @core.Object3D,
  lights_node : Node,
  pass_id? : String,
) -> Unit {
  for i in 0..<render_list.length() {
    let item = render_list[i]
    let object = item.object.unwrap()
    let geometry = item.geometry.unwrap()
    let material = item.material.unwrap()
    let group = item.group
    let clipping_context = item.clipping_context
    match self._current_render_object_function {
      Some(f) =>
        (f.f)(
          object, scene, camera, geometry, material, group, lights_node, clipping_context,
          pass_id,
        )
      None =>
        self.render_object(
          object, scene, camera, geometry, material, group, lights_node, clipping_context,
          pass_id,
        )
    }
  }
}

///|
/// `_getShadowNodes( material )`: the color, depth and position nodes of a material's
/// shadow pass.
pub fn Renderer::_get_shadow_nodes(
  self : Renderer,
  material : @core.Material,
) -> RendererShadowNodes {
  let version = material.version
  let key = @core.JsValue::of(material)
  match self._cache_shadow_nodes.get(key) {
    Some(cache) if cache.version == version => return cache
    _ => ()
  }
  let node_material = NodeMaterial::of(material)
  let has_map = material.map is Some(_)
  let material_color_node = node_material.bind(fn(m) { m.color_node })
  let cast_shadow_node = node_material.bind(fn(m) { m.cast_shadow_node })
  let mask_node = match node_material {
    Some({ mask_shadow_node: Some(n), .. }) => Some(n)
    Some({ mask_node: Some(n), .. }) => Some(n)
    _ => None
  }
  let mut position_node = None
  let mut color_node = None
  let mut depth_node = None
  if has_map ||
    material_color_node is Some(_) ||
    cast_shadow_node is Some(_) ||
    mask_node is Some(_) {
    let (shadow_rgb, shadow_alpha0) = match cast_shadow_node {
      Some(n) => {
        let rgb = n.rgb()
        let a = n.a()
        if self.shadow_map.transmitted != true {
          @core.warn_once(
            "Renderer: `shadowMap.transmitted` needs to be set to `true` when using `material.castShadowNode`.",
          )
        }
        (rgb, a)
      }
      None => (vec3(0), float(1))
    }
    let mut shadow_alpha = shadow_alpha0
    if has_map {
      shadow_alpha = shadow_alpha.mul(
        reference("map", "texture", object=Material(material)).a(),
      )
    }
    match material_color_node {
      Some(n) => shadow_alpha = shadow_alpha.mul(n.a())
      None => ()
    }
    let mut c = vec4_of([shadow_rgb, shadow_alpha])
    match mask_node {
      Some(mask_node) =>
        c = fn_(fn(inputs, _) {
          let color = inputs.get(0).unwrap()
          mask_node.not_().discard()
          Some(color)
        }).call([c])
      None => ()
    }
    color_node = Some(c)
  }
  match node_material {
    Some({ depth_node: Some(n), .. }) => depth_node = Some(n)
    _ => ()
  }
  match node_material {
    Some({ cast_shadow_position_node: Some(n), .. }) => position_node = Some(n)
    Some({ position_node: Some(n), .. }) => position_node = Some(n)
    _ => ()
  }
  let cache = { version, color_node, depth_node, position_node, }
  self._cache_shadow_nodes.set(key, cache)
  cache
}

///|
/// The sub-cameras of an `ArrayCamera`.
fn _renderer_array_cameras(camera : @core.Object3D) -> Array[@core.Object3D]? {
  match camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(a), .. }), .. }) =>
      Some(a.cameras)
    _ => None
  }
}

///|
/// `_updateCamera( camera, useXRCamera )`: applies the reversed depth and coordinate
/// system, updates the world matrix, and returns the XR camera when presenting.
fn Renderer::_update_camera(
  self : Renderer,
  camera : @core.Object3D,
  use_xr_camera : Bool,
) -> @core.Object3D {
  let xr = self.xr
  let use_xr = xr.enabled == true &&
    xr.is_presenting == true &&
    use_xr_camera == true
  if use_xr == false {
    let mut projection_matrix_needs_update = false
    let sub_cameras = _renderer_array_cameras(camera)
    // reversed depth
    if self.reversed_depth_buffer == true && camera.reversed_depth() != true {
      camera.as_camera()._reversed_depth = true
      match sub_cameras {
        Some(cameras) =>
          for sub_camera in cameras {
            sub_camera.as_camera()._reversed_depth = true
          }
        None => ()
      }
      projection_matrix_needs_update = true
    }
    // WebGPU/WebGL coordinate system
    let coordinate_system = self.coordinate_system()
    if camera.as_camera().coordinate_system != coordinate_system {
      camera.as_camera().coordinate_system = coordinate_system
      match sub_cameras {
        Some(cameras) =>
          for sub_camera in cameras {
            sub_camera.as_camera().coordinate_system = coordinate_system
          }
        None => ()
      }
      projection_matrix_needs_update = true
    }
    // camera update
    if projection_matrix_needs_update == true {
      camera.update_projection_matrix()
      match sub_cameras {
        Some(cameras) =>
          for sub_camera in cameras {
            sub_camera.update_projection_matrix()
          }
        None => ()
      }
    }
  }
  if camera.parent is None && camera.matrix_world_auto_update == true {
    camera.update_matrix_world()
  }
  // handle XR
  if use_xr == true {
    if xr.camera_auto_update == true {
      xr.update_camera(camera)
    }
    return xr.get_camera() // use XR camera for rendering
  }
  camera
}

///|
fn Renderer::_update_dispatch_size(
  self : Renderer,
  compute_node : Node,
  dispatch_size : ComputeDispatchSize?,
) -> Unit {
  let indirect = match dispatch_size {
    Some(d) => Some(d)
    None => ComputeNode::of(compute_node).bind(fn(c) { c.dispatch_size })
  }
  match indirect {
    Some(Indirect(attribute)) if is_indirect_storage_buffer_attribute(attribute) =>
      self._attributes().update(Buffer(attribute), INDIRECT)
    _ => ()
  }
}

///|
/// `renderObject( object, scene, camera, geometry, material, group, lightsNode,
/// clippingContext = null, passId = null )`: draws one object, with the scene's
/// override material and the double-sided transparent passes.
pub fn Renderer::render_object(
  self : Renderer,
  object : @core.Object3D,
  scene : @core.Object3D,
  camera : @core.Object3D,
  geometry : @core.BufferGeometry,
  material : @core.Material,
  group : @core.GeometryGroup?,
  lights_node : Node,
  clipping_context : ClippingContext?,
  pass_id : String?,
) -> Unit {
  let previous_source_material = self._current_source_material
  //
  (object.on_before_render)(
    @core.JsValue::of(self),
    scene,
    camera,
    geometry,
    material,
    group,
  )
  //
  let override_material = match scene.kind {
    Scene(s) => s.override_material
    _ => None
  }
  let mut material = material
  let saved = match override_material {
    Some(override_material) if material.allow_override == true => {
      self._current_source_material = Some(material)
      // store original nodes
      let override_node_material = NodeMaterial::of(override_material)
      let saved = (
        override_node_material.bind(fn(m) { m.color_node }),
        override_node_material.bind(fn(m) { m.depth_node }),
        override_node_material.bind(fn(m) { m.position_node }),
        override_material.side,
        override_material.displacement_map,
        override_material.displacement_scale,
        override_material.displacement_bias,
      )
      let source_node_material = NodeMaterial::of(material)
      match (source_node_material, override_node_material) {
        (Some({ position_node: Some(p), .. }), Some(o)) =>
          o.position_node = Some(p)
        _ => ()
      }
      override_material._alpha_test = material.alpha_test() // bypass the setter so the version doesn't change
      override_material.alpha_map = material.alpha_map
      override_material.displacement_map = material.displacement_map
      override_material.displacement_scale = material.displacement_scale
      override_material.displacement_bias = material.displacement_bias
      override_material.transparent = material.transparent ||
        (material.transmission() is Some(t) && t > 0.0) ||
        _renderer_has_node_property(material, "transmissionNode") ||
        source_node_material is Some({ backdrop_node: Some(_), .. })
      if override_material.has_extension_flag("isShadowPassMaterial") {
        let { color_node, depth_node, position_node, .. } = self._get_shadow_nodes(
          material,
        )
        if self.shadow_map.type_ == @core.VSMShadowMap {
          override_material.side = match material.shadow_side {
            Some(s) => s
            None => material.side
          }
        } else {
          override_material.side = match material.shadow_side {
            Some(s) => s
            None => _renderer_shadow_side(material.side)
          }
        }
        match override_node_material {
          Some(o) => {
            if color_node is Some(_) {
              o.color_node = color_node
            }
            if depth_node is Some(_) {
              o.depth_node = depth_node
            }
            if position_node is Some(_) {
              o.position_node = position_node
            }
          }
          None => ()
        }
      }
      material = override_material
      Some((override_material, saved))
    }
    _ => None
  }
  //
  if material.transparent == true &&
    material.side == @core.DoubleSide &&
    material.force_single_pass == false {
    material.side = @core.BackSide
    self._handle_object(
      object,
      material,
      scene,
      camera,
      lights_node,
      group,
      clipping_context,
      Some("backSide"),
    ) // create backSide pass id
    material.side = @core.FrontSide
    self._handle_object(
      object, material, scene, camera, lights_node, group, clipping_context, pass_id,
    ) // use default pass id
    material.side = @core.DoubleSide
  } else {
    self._handle_object(
      object, material, scene, camera, lights_node, group, clipping_context, pass_id,
    )
  }
  //
  match saved {
    Some((override_material, saved)) => {
      let (
        color_node,
        depth_node,
        position_node,
        side,
        displacement_map,
        displacement_scale,
        displacement_bias,
      ) = saved
      match NodeMaterial::of(override_material) {
        Some(o) => {
          o.color_node = color_node
          o.depth_node = depth_node
          o.position_node = position_node
        }
        None => ()
      }
      override_material.side = side
      override_material.displacement_map = displacement_map
      override_material.displacement_scale = displacement_scale
      override_material.displacement_bias = displacement_bias
    }
    None => ()
  }
  self._current_source_material = previous_source_material
  //
  (object.on_after_render)(
    @core.JsValue::of(self),
    scene,
    camera,
    geometry,
    material,
    group,
  )
}

///|
/// Whether a node material class property (`transmissionNode`, ...) holds a value.
fn _renderer_has_node_property(
  material : @core.Material,
  name : String,
) -> Bool {
  match NodeMaterial::of(material) {
    Some(m) =>
      match m.class_.get_property(material, name) {
        Some(Object) => true
        _ => false
      }
    None => false
  }
}

///|
/// `this._handleObjectFunction( ... )`.
fn Renderer::_handle_object(
  self : Renderer,
  object : @core.Object3D,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lights_node : Node,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
  pass_id : String?,
) -> Unit {
  match self._handle_object_function {
    RenderObjectDirect =>
      self._render_object_direct(
        object, material, scene, camera, lights_node, group, clipping_context, pass_id,
      )
    CreateObjectPipeline =>
      self._create_object_pipeline(
        object, material, scene, camera, lights_node, group, clipping_context, pass_id,
      )
  }
}

///|
/// `hasCompatibility( name )`.
pub fn Renderer::has_compatibility(self : Renderer, name : String) -> Bool {
  if self._initialized == false {
    abort(
      "THREE.Renderer: .hasCompatibility() called before the backend is initialized. Use \"await renderer.init();\" before using this method.",
    )
  }
  self.backend.has_compatibility(name)
}

///|
/// `_renderObjectDirect( ... )`: updates and draws a render object.
fn Renderer::_render_object_direct(
  self : Renderer,
  object : @core.Object3D,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lights_node : Node,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
  pass_id : String?,
) -> Unit {
  let render_object = self
    ._objects()
    .get(
      object,
      material,
      scene,
      camera,
      lights_node,
      self._current_render_context.unwrap(),
      clipping_context,
      pass_id?,
    )
  render_object.draw_range = object.get_geometry().map(fn(g) { g.draw_range })
  render_object.group = group
  match self._current_render_bundle {
    Some(render_bundle) => {
      let render_bundle_data = self.backend.get(
        @core.JsValue::of(render_bundle),
      )
      renderer_js_push(
        render_bundle_data.get("renderObjects"),
        @core.JsValue::of(render_object),
      )
      render_object.bundle = Some(render_bundle.bundle_group)
    }
    None => ()
  }
  //
  let nodes = self._nodes()
  let refresh_type = nodes.needs_refresh(render_object)
  if refresh_type == @core.RenderObjectRefreshType_FULL {
    nodes.update_before(render_object)
    self._geometries().update_for_render(render_object)
    nodes.update_for_render(render_object)
    self._bindings().update_for_render(render_object)
  } else if refresh_type == @core.RenderObjectRefreshType_SHARED {
    nodes.update_before(render_object)
    nodes.update_for_render(render_object)
    self._bindings().update_shared_for_render(render_object)
  }
  self._pipelines().update_for_render(render_object)
  //
  if self._pipelines().is_ready(render_object) {
    self.backend.draw(render_object, self.info)
    if refresh_type != @core.RenderObjectRefreshType_NONE {
      nodes.update_after(render_object)
    }
  } else {
    match self._current_render_bundle {
      Some(render_bundle) =>
        self.backend
        .get(@core.JsValue::of(render_bundle))
        .set("version", @core.JsValue::of(-1))
      None => ()
    }
  }
}

///|
/// `_createObjectPipeline( ... )`: queues (async compile) or builds the pipeline of a
/// render object without drawing.
fn Renderer::_create_object_pipeline(
  self : Renderer,
  object : @core.Object3D,
  material : @core.Material,
  scene : @core.Object3D,
  camera : @core.Object3D,
  lights_node : Node,
  group : @core.GeometryGroup?,
  clipping_context : ClippingContext?,
  pass_id : String?,
) -> Unit {
  // If in async compilation mode, queue the work for sequential execution
  match self._compilation_promises {
    Some(compilation_promises) => {
      // Store work items instead of promises - will be processed sequentially.
      // The side is stored since the renderer might have changed it temporarily.
      let state = self._precompilation_state.unwrap().copy()
      state.use_frame_buffer_target = true
      state.render_target = self.get_render_target()
      state.mrt = self.get_mrt()
      state.render_context = self._current_render_context
      compilation_promises.push(
        Object({
          object,
          material,
          side: material.side,
          scene,
          camera,
          lights_node,
          group,
          clipping_context,
          pass_id,
          render_context: self._current_render_context,
          precompilation_state: state,
        }),
      )
      return
    }
    None => ()
  }
  // Sync path
  let render_object = self
    ._objects()
    .get(
      object,
      material,
      scene,
      camera,
      lights_node,
      self._current_render_context.unwrap(),
      clipping_context,
      pass_id?,
    )
  render_object.draw_range = object.get_geometry().map(fn(g) { g.draw_range })
  render_object.group = group
  //
  let nodes = self._nodes()
  nodes.update_before(render_object)
  self._geometries().update_for_render(render_object)
  nodes.update_for_render(render_object)
  self._bindings().update_for_render(render_object)
  self._pipelines().get_for_render(render_object) |> ignore
  nodes.update_after(render_object)
}

///|
/// `_onCanvasTargetResize()`.
fn Renderer::_handle_canvas_target_resize(self : Renderer) -> Unit {
  if self._initialized {
    self.backend.update_size()
  }
}

///|
/// `_destroyCanvasTarget( canvasTarget )`.
fn Renderer::_destroy_canvas_target(
  self : Renderer,
  canvas_target : CanvasTarget,
) -> Unit {
  canvas_target.remove_event_listener("dispose", self._on_canvas_target_dispose)
  if self._initialized {
    self.backend.destroy_canvas_target(canvas_target)
  }
}

///|
/// `renderer.debug.getShaderAsync( scene, camera, object )`: compiles the object and
/// calls back with its `( fragmentShader, vertexShader )`.
pub fn Renderer::debug_get_shader_async(
  self : Renderer,
  scene : @core.Object3D,
  camera : @core.Object3D,
  object : @core.Object3D,
  on_done : (String?, String?) -> Unit,
) -> Unit {
  self.compile_async(object, camera, target_scene=scene, on_done=fn() {
    let use_frame_buffer_target = self.needs_frame_buffer_target() &&
      self._render_target is None
    let render_target = if use_frame_buffer_target {
      self._get_frame_buffer_target()
    } else {
      match self._render_target {
        Some(t) => Some(t)
        None => self._output_render_target
      }
    }
    let render_list = self._render_lists().get(scene, camera, self.lighting)
    let render_context = self
      ._render_contexts()
      .get(render_target?, mrt?=self._mrt, call_depth=0, camera~)
    let material = match scene.kind {
      Scene({ override_material: Some(m), .. }) => m
      _ =>
        match object.get_material() {
          Some(Single(m)) => m
          _ => abort("getShaderAsync: the object has no single material")
        }
    }
    let render_object = self
      ._objects()
      .get(
        object,
        material,
        scene,
        camera,
        render_list.lights_node,
        render_context,
        render_context.clipping_context,
        // upstream passes no passId here, which is the 'default' chain map
        pass_id="default",
      )
    let state = render_object.get_node_builder_state()
    on_done(state.fragment_shader, state.vertex_shader)
  })
}

///|
/// `renderer.xr.isPresenting`.
pub fn Renderer::xr_is_presenting(self : Renderer) -> Bool {
  self.xr.is_presenting
}

///|
/// `renderer._nodes.nodeFrame` (`_nodes` is the `NodeManager` that `init()` creates).
pub fn Renderer::node_frame(self : Renderer) -> NodeFrame {
  self._nodes().node_frame
}

///|
/// `renderer.backend.isWebGPUBackend === true`.
pub fn Renderer::backend_is_webgpu(self : Renderer) -> Bool {
  self.backend.has_flag("isWebGPUBackend")
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn coordinate_system(self) {
  self.coordinate_system()
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn get_render_target(self) {
  self._render_target
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn get_active_cube_face(
  self,
) {
  self._active_cube_face
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn get_active_mipmap_level(
  self,
) {
  self._active_mipmap_level
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn xr_enabled(self) {
  self.xr.enabled
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn set_xr_enabled(
  self,
  value,
) {
  self.xr.enabled = value
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn reversed_depth_buffer(
  self,
) {
  self.reversed_depth_buffer
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn auto_clear(self) {
  self.auto_clear
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn set_render_target(
  self,
  target,
  face,
  level,
) {
  self.set_render_target(
    target,
    active_cube_face=face,
    active_mipmap_level=level,
  )
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn clear_depth(self) {
  self.clear_depth()
}

///|
pub impl @core.CubeCameraRenderer for Renderer with fn render(
  self,
  scene,
  camera,
) {
  self.render(scene, camera)
}

// ---------------------------------------------------------------------------
// The test stand-in of the shader harnesses.

///|
/// The backend of `Renderer::foundation_stub`: an uninitialized `WebGPUBackend`.
priv struct FoundationStubBackend {}

///|
impl BackendClass for FoundationStubBackend with fn class_name(_) {
  "WebGPUBackend"
}

///|
impl BackendClass for FoundationStubBackend with fn has_flag(_, flag) {
  flag == "isWebGPUBackend"
}

///|
/// `WebGPUBackend`'s constructor sets `_compatibility[ TEXTURE_COMPARE ]` to `true`
/// outside Android.
impl BackendClass for FoundationStubBackend with fn has_compatibility(
  _,
  _,
  name,
) {
  name == @core.Compatibility_TEXTURE_COMPARE
}

///|
impl BackendClass for FoundationStubBackend with fn coordinate_system(_, _) {
  @core.WebGPUCoordinateSystem
}

///|
impl BackendClass for FoundationStubBackend with fn get_uniform_buffer_limit(
  _,
  _,
) {
  // `this.backend.device.limits` before `init()`.
  abort("TypeError: Cannot read properties of null (reading 'limits')")
}

///|
extern "js" fn renderer_stub_canvas() -> @core.JsValue = "() => ( { style: {}, width: 300, height: 150, addEventListener() {}, removeEventListener() {}, getContext() { return null; } } )"

///|
/// A test stand-in: `new WebGPURenderer( { canvas } )` right after construction (not
/// initialized), with `renderer._bindings = undefined`.
pub fn Renderer::foundation_stub() -> Renderer {
  let parameters = @core.JsValue::object()
  parameters.set("canvas", renderer_stub_canvas())
  Renderer::new(Backend::new(FoundationStubBackend::{ }, parameters~))
}
