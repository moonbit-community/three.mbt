// renderers/webgl-fallback/WebGLBackend.js: the WebGL 2 backend of `Renderer`.
//
// `WebGLBackend::new( parameters )` returns the common `@nodes.Backend` whose class
// payload is the `WebGLBackend` struct below (upstream's own instance fields); the
// members upstream overrides are the `BackendClass` impls. Fields that upstream sets to
// `null` in the constructor and assigns in `init()` are options. Per-object records
// (`this.get( object )`) are the common backend's plain JS objects, with upstream's keys.
// `_setFramebuffer` and `_resolveRenderTarget` are in web_gl_backend_framebuffer.mbt.

///|
/// WebGLBackend's own instance fields (the class payload of the backend).
pub(all) struct WebGLBackend {
  /// The common `Backend` this payload belongs to (`this` for base members).
  mut base : @nodes.Backend
  mut attribute_utils : WebGLAttributeUtils?
  mut vertex_array_utils : WebGLVertexArrayUtils?
  mut extensions : WebGLExtensions?
  mut capabilities : WebGLCapabilities?
  mut texture_utils : WebGLTextureUtils?
  mut buffer_renderer : WebGLBufferRenderer?
  mut gl : @webgl.WebGL2RenderingContext?
  mut state : WebGLState?
  mut utils : WebGLUtils?
  /// Whether `gl.RASTERIZER_DISCARD` is enabled (compute).
  mut discard : Bool
  /// `EXT_disjoint_timer_query_webgl2`; `None` is `null`.
  mut disjoint : @webgl.GLExtension?
  /// `KHR_parallel_shader_compile`; `None` is `null`.
  mut parallel : @webgl.GLExtension?
  /// `OES_draw_buffers_indexed`; `None` is `null`.
  mut draw_buffers_indexed_ext : @webgl.GLExtension?
  mut _current_context : @nodes.RenderContext?
  /// `_knownBindings`, a `WeakSet< Array< BindGroup > >`.
  _known_bindings : @webgl.WeakMap[Array[@nodes.BindGroup], Bool]
  mut _supports_invalidate_framebuffer : Bool
  mut _xr_framebuffer : @webgl.GLFramebuffer?
  /// `_onContextLost`, the `webglcontextlost` listener added by `init()`.
  mut _on_context_lost : @core.JsValue?
}

///|
/// The class a backend has between `Backend::new` and the end of `WebGLBackend::new`.
priv struct WebGLBackendUnset {}

///|
impl @nodes.BackendClass for WebGLBackendUnset with fn class_name(_) {
  "WebGLBackend"
}

///|
extern "js" fn _web_gl_backend_supports_invalidate_framebuffer() -> Bool = "() => typeof navigator === 'undefined' ? false : /OculusBrowser/g.test( navigator.userAgent )"

///|
/// `new WebGLBackend( parameters = {} )`: `parameters` is upstream's options object
/// (`canvas`, `context`, `alpha`, `antialias`, `samples`, `trackTimestamp`,
/// `reversedDepthBuffer`, ...), copied by the common backend.
pub fn WebGLBackend::new(parameters? : @core.JsValue) -> @nodes.Backend {
  let base = @nodes.Backend::new(WebGLBackendUnset::{ }, parameters?)
  let payload : WebGLBackend = {
    base,
    attribute_utils: None,
    vertex_array_utils: None,
    extensions: None,
    capabilities: None,
    texture_utils: None,
    buffer_renderer: None,
    gl: None,
    state: None,
    utils: None,
    discard: false,
    disjoint: None,
    parallel: None,
    draw_buffers_indexed_ext: None,
    _current_context: None,
    _known_bindings: @webgl.WeakMap::new(),
    _supports_invalidate_framebuffer: _web_gl_backend_supports_invalidate_framebuffer(),
    _xr_framebuffer: None,
    _on_context_lost: None,
  }
  base.class_ = payload
  base
}

///|
/// The WebGL payload of a backend made by `WebGLBackend::new`.
pub fn WebGLBackend::of(backend : @nodes.Backend) -> WebGLBackend? {
  if backend.class_.class_name() == "WebGLBackend" &&
    backend.class_.has_flag("isWebGLBackend") {
    Some(backend.class_.payload().cast())
  } else {
    None
  }
}

///|
pub impl @nodes.BackendClass for WebGLBackend with fn class_name(_) {
  "WebGLBackend"
}

///|
pub impl @nodes.BackendClass for WebGLBackend with fn has_flag(_, flag) {
  flag == "isWebGLBackend"
}

///|
/// `this.get( object )` of the common backend.
pub fn WebGLBackend::get(
  self : WebGLBackend,
  object : @core.JsValue,
) -> @core.JsValue {
  self.base.get(object)
}

///|
/// `this.set( object, value )`.
pub fn WebGLBackend::set(
  self : WebGLBackend,
  object : @core.JsValue,
  value : @core.JsValue,
) -> Unit {
  self.base.set(object, value)
}

///|
/// `this.has( object )`.
pub fn WebGLBackend::has(self : WebGLBackend, object : @core.JsValue) -> Bool {
  self.base.has(object)
}

///|
/// `this.delete( object )`.
pub fn WebGLBackend::delete(
  self : WebGLBackend,
  object : @core.JsValue,
) -> Unit {
  self.base.delete(object)
}

///|
/// `this.renderer`.
pub fn WebGLBackend::renderer(self : WebGLBackend) -> @nodes.Renderer {
  match self.base.renderer {
    Some(r) => r
    None =>
      abort("TypeError: Cannot read properties of null (reading 'renderer')")
  }
}

///|
/// `getBufferAttribute( attribute )` of the common backend.
pub fn WebGLBackend::get_buffer_attribute(
  self : WebGLBackend,
  attribute : @core.GeometryAttribute,
) -> @nodes.AttributeBuffer {
  self.base.get_buffer_attribute(attribute)
}

///|
/// `getDrawingBufferSize()` of the common backend.
pub fn WebGLBackend::get_drawing_buffer_size(
  self : WebGLBackend,
) -> @math.Vector2 {
  self.base.get_drawing_buffer_size()
}

// ---------------------------------------------------------------------------
// JS helpers for the plain-object records.

///|
extern "js" fn _wgl_truthy(v : @core.JsValue) -> Bool = "(v) => v ? true : false"

///|
extern "js" fn _wgl_index(o : @core.JsValue, i : Int32) -> @core.JsValue = "(o, i) => o[i]"

///|
extern "js" fn _wgl_set_index(
  o : @core.JsValue,
  i : Int32,
  v : @core.JsValue,
) -> Unit = "(o, i, v) => { o[i] = v; }"

///|
extern "js" fn _wgl_new_array(n : Int32) -> @core.JsValue = "(n) => new Array( n )"

///|
extern "js" fn _wgl_length(a : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn _wgl_new_weak_set() -> @core.JsValue = "() => new WeakSet()"

///|
extern "js" fn _wgl_weak_set_add(s : @core.JsValue, v : @core.JsValue) -> Unit = "(s, v) => { s.add( v ); }"

///|
extern "js" fn _wgl_weak_set_has(s : @core.JsValue, v : @core.JsValue) -> Bool = "(s, v) => s.has( v )"

///|
extern "js" fn _wgl_add_event_listener(
  target : @core.JsValue,
  type_ : String,
  listener : @core.JsValue,
) -> Unit = "(t, n, l) => t.addEventListener( n, l, false )"

///|
extern "js" fn _wgl_remove_event_listener(
  target : @core.JsValue,
  type_ : String,
  listener : @core.JsValue,
) -> Unit = "(t, n, l) => t.removeEventListener( n, l )"

///|
/// `onContextLost`: prevents the default and reports the loss to the renderer.
extern "js" fn _wgl_context_lost_listener(
  on_lost : (@core.JsValue) -> Unit,
) -> @core.JsValue =
  #|( onLost ) => function onContextLost( event ) {
  #|  event.preventDefault();
  #|  const contextLossInfo = {
  #|    api: 'WebGL',
  #|    message: event.statusMessage || 'Unknown reason',
  #|    reason: null,
  #|    originalEvent: event
  #|  };
  #|  onLost( contextLossInfo );
  #|}

///|
extern "js" fn _wgl_request_animation_frame(f : () -> Unit) -> Unit = "(f) => requestAnimationFrame( () => f() )"

///|
/// A `Promise` that settles when `check()` is true (polled every frame), after
/// `complete()`: upstream's parallel-compile `checkStatus` loop.
extern "js" fn _wgl_status_promise(
  check : () -> Bool,
  complete : () -> Unit,
) -> @core.JsValue =
  #|( check, complete ) => new Promise( ( resolve ) => {
  #|  const checkStatus = () => {
  #|    if ( check() ) {
  #|      complete();
  #|      resolve();
  #|    } else {
  #|      requestAnimationFrame( checkStatus );
  #|    }
  #|  };
  #|  checkStatus();
  #|} )

///|
/// `getContext( 'webgl2', contextAttributes )` of a canvas.
extern "js" fn _wgl_get_context(
  canvas : @core.JsValue,
  attributes : @core.JsValue,
) -> @webgl.WebGL2RenderingContext = "(c, a) => c.getContext( 'webgl2', a )"

///|
fn[T] _wgl_handle(value : @core.JsValue) -> T? {
  if value.is_null() || value.is_undefined() {
    None
  } else {
    Some(value.cast())
  }
}

///|
fn[T] _wgl_js(value : T?) -> @core.JsValue {
  match value {
    Some(v) => @core.JsValue::of(v)
    None => @core.JsValue::null()
  }
}

///|
/// `gl.uniform1i( location, x )` with a nullable location.
extern "js" fn _wgl_uniform1i(
  gl : @webgl.WebGL2RenderingContext,
  location : @core.JsValue,
  x : Int32,
) -> Unit = "(gl, l, x) => gl.uniform1i( l, x )"

///|
/// `gl.uniform1ui( location, x )` with a nullable location.
extern "js" fn _wgl_uniform1ui(
  gl : @webgl.WebGL2RenderingContext,
  location : @core.JsValue,
  x : Int32,
) -> Unit = "(gl, l, x) => gl.uniform1ui( l, x )"

// ---------------------------------------------------------------------------
// init

///|
/// `init( renderer )`.
pub impl @nodes.BackendClass for WebGLBackend with fn init(
  self,
  backend,
  renderer,
  on_done,
) {
  // `super.init( renderer )`.
  backend.renderer = Some(renderer)
  let parameters = backend.parameters
  let context_attributes = @core.JsValue::object()
  context_attributes.set(
    "antialias",
    @core.JsValue::of(renderer.current_samples() > 0),
  )
  context_attributes.set("alpha", @core.JsValue::of(true)) // always true for performance reasons
  context_attributes.set("depth", @core.JsValue::of(renderer.depth))
  context_attributes.set("stencil", @core.JsValue::of(renderer.stencil))
  let context = parameters.get("context")
  let gl_context : @webgl.WebGL2RenderingContext = if !context.is_undefined() {
    context.cast()
  } else {
    _wgl_get_context(renderer.dom_element(), context_attributes)
  }
  let on_context_lost = _wgl_context_lost_listener(fn(info) {
    (renderer.on_device_lost)(info)
  })
  self._on_context_lost = Some(on_context_lost)
  _wgl_add_event_listener(
    renderer.dom_element(),
    "webglcontextlost",
    on_context_lost,
  )
  self.gl = Some(gl_context)
  let extensions = WebGLExtensions::new(self)
  self.extensions = Some(extensions)
  self.capabilities = Some(WebGLCapabilities::new(self))
  self.attribute_utils = Some(WebGLAttributeUtils::new(self))
  self.vertex_array_utils = Some(WebGLVertexArrayUtils::new(self))
  self.texture_utils = Some(WebGLTextureUtils::new(self))
  self.buffer_renderer = Some(WebGLBufferRenderer::new(self))
  self.state = Some(WebGLState::new(self))
  self.utils = Some(WebGLUtils::new(self))
  extensions.get("EXT_color_buffer_float") |> ignore
  extensions.get("WEBGL_clip_cull_distance") |> ignore
  extensions.get("OES_texture_float_linear") |> ignore
  extensions.get("EXT_color_buffer_half_float") |> ignore
  extensions.get("WEBGL_multisampled_render_to_texture") |> ignore
  extensions.get("WEBGL_render_shared_exponent") |> ignore
  extensions.get("WEBGL_multi_draw") |> ignore
  extensions.get("OVR_multiview2") |> ignore
  extensions.get("EXT_clip_control") |> ignore
  self.disjoint = extensions.get("EXT_disjoint_timer_query_webgl2")
  self.parallel = extensions.get("KHR_parallel_shader_compile")
  self.draw_buffers_indexed_ext = extensions.get("OES_draw_buffers_indexed")
  if _wgl_truthy(parameters.get("reversedDepthBuffer")) {
    if extensions.has("EXT_clip_control") {
      renderer.reversed_depth_buffer = true
    } else {
      @core.warn(
        "WebGPURenderer: Unable to use reversed depth buffer due to missing EXT_clip_control extension. Fallback to default depth buffer.",
      )
      renderer.reversed_depth_buffer = false
    }
  }
  if renderer.reversed_depth_buffer {
    self.state.unwrap().set_reversed_depth(true)
  }
  on_done(None)
}

///|
/// `get coordinateSystem()`.
pub impl @nodes.BackendClass for WebGLBackend with fn coordinate_system(_, _) {
  @core.WebGLCoordinateSystem
}

///|
/// `get hasTimestamp()`.
pub impl @nodes.BackendClass for WebGLBackend with fn has_timestamp(self, _) {
  self.disjoint is Some(_)
}

///|
/// `backend.capabilities.getUniformBufferLimit()`.
pub impl @nodes.BackendClass for WebGLBackend with fn get_uniform_buffer_limit(
  self,
  _,
) {
  self.capabilities.unwrap().get_uniform_buffer_limit()
}

///|
/// `backend.capabilities.getMaxAnisotropy()`.
pub impl @nodes.BackendClass for WebGLBackend with fn get_max_anisotropy(
  self,
  _,
) {
  self.capabilities.unwrap().get_max_anisotropy()
}

///|
/// `getArrayBufferAsync( attribute, target = null, offset = 0, count = - 1 )`.
pub impl @nodes.BackendClass for WebGLBackend with fn get_array_buffer_async(
  self,
  _,
  attribute,
  target,
  offset,
  count,
  on_done,
) {
  self.attribute_utils
  .unwrap()
  .get_array_buffer_async(attribute, target, offset, count, on_done)
}

///|
/// `makeXRCompatible()`.
pub impl @nodes.BackendClass for WebGLBackend with fn make_xr_compatible(
  self,
  _,
  on_done,
) {
  let gl = self.gl.unwrap()
  let attributes = gl.get_context_attributes()
  if !attributes.get("xrCompatible").strict_equal(@core.JsValue::of(true)) {
    gl.make_xr_compatible(on_done)
  } else {
    on_done()
  }
}

///|
/// `setXRTarget( xrFramebuffer )`.
pub impl @nodes.BackendClass for WebGLBackend with fn set_xr_target(
  self,
  _,
  xr_framebuffer,
) {
  self._xr_framebuffer = match xr_framebuffer {
    Some(f) => _wgl_handle(f)
    None => None
  }
}

///|
/// `setXRRenderTargetTextures( renderTarget, colorTexture, depthTexture = null )`.
pub impl @nodes.BackendClass for WebGLBackend with fn set_xr_render_target_textures(
  self,
  _,
  render_target,
  color_texture,
  depth_texture,
) {
  let texture_utils = self.texture_utils.unwrap()
  let texture = render_target.textures[0]
  let record = @core.JsValue::object()
  record.set("textureGPU", color_texture)
  record.set(
    "glTextureType",
    @core.JsValue::of(texture_utils.get_gl_texture_type(texture)),
  )
  record.set("glInternalFormat", @core.JsValue::of(@webgl.GL_RGBA8)) // see #24698 why RGBA8 and not SRGB8_ALPHA8 is used
  self.set(@core.JsValue::of(texture), record)
  if !depth_texture.is_null() && !depth_texture.is_undefined() {
    let rt_depth = render_target.depth_texture()
    let record = @core.JsValue::object()
    record.set("textureGPU", depth_texture)
    record.set(
      "glTextureType",
      @core.JsValue::of(
        match rt_depth {
          Some(t) => texture_utils.get_gl_texture_type(t)
          None => 0
        },
      ),
    )
    record.set(
      "glInternalFormat",
      @core.JsValue::of(
        if render_target.stencil_buffer {
          @webgl.GL_DEPTH24_STENCIL8
        } else {
          @webgl.GL_DEPTH_COMPONENT24
        },
      ),
    )
    self.set(_wgl_js(rt_depth), record)
    let props = @nodes.render_target_props(render_target)
    // The multisample_render_to_texture extension doesn't work properly if there
    // are midframe flushes and an external depth texture.
    if self.extensions.unwrap().has("WEBGL_multisampled_render_to_texture") ==
      true &&
      props._auto_allocate_depth_buffer == Some(true) &&
      render_target.multiview == false {
      @core.warn(
        "WebGLBackend: Render-to-texture extension was disabled because an external texture was provided",
      )
    }
    props._auto_allocate_depth_buffer = Some(false)
  }
}

///|
/// `initTimestampQuery( type, uid )`.
pub fn WebGLBackend::init_timestamp_query(
  self : WebGLBackend,
  type_ : String,
  uid : String?,
) -> Unit {
  if self.disjoint is None || !self.base.track_timestamp {
    return
  }
  let pool = if type_ == @core.TimestampQuery_COMPUTE {
    self.base.timestamp_query_pool_compute
  } else {
    self.base.timestamp_query_pool_render
  }
  let timestamp_query_pool = match pool {
    Some(p) => p
    None => {
      // TODO: Variable maxQueries?
      let p = WebGLTimestampQueryPool::new(
        self.gl.unwrap(),
        type_,
        max_queries=2048,
      )
      if type_ == @core.TimestampQuery_COMPUTE {
        self.base.timestamp_query_pool_compute = Some(p)
      } else {
        self.base.timestamp_query_pool_render = Some(p)
      }
      p
    }
  }
  let uid = uid.unwrap_or("undefined")
  let base_offset = timestamp_query_pool.allocate_queries_for_context(uid)
  if base_offset is Some(_) {
    match WebGLTimestampQueryPool::of(timestamp_query_pool) {
      Some(p) => p.begin_query(uid)
      None => ()
    }
  }
}

///|
/// `prepareTimestampBuffer( type, uid )`.
pub fn WebGLBackend::prepare_timestamp_buffer(
  self : WebGLBackend,
  type_ : String,
  uid : String?,
) -> Unit {
  if self.disjoint is None || !self.base.track_timestamp {
    return
  }
  let pool = if type_ == @core.TimestampQuery_COMPUTE {
    self.base.timestamp_query_pool_compute
  } else {
    self.base.timestamp_query_pool_render
  }
  match pool {
    Some(p) =>
      match WebGLTimestampQueryPool::of(p) {
        Some(w) => w.end_query(uid.unwrap_or("undefined"))
        None => ()
      }
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'endQuery')",
      )
  }
}

///|
/// `getContext()`.
pub impl @nodes.BackendClass for WebGLBackend with fn get_context(self, _) {
  _wgl_js(self.gl)
}

// ---------------------------------------------------------------------------
// render

///|
/// `beginRender( renderContext )`.
pub impl @nodes.BackendClass for WebGLBackend with fn begin_render(
  self,
  backend,
  render_context,
) {
  let state = self.state.unwrap()
  let render_context_data = self.get(@core.JsValue::of(render_context))
  if render_context.viewport {
    self.update_viewport_(render_context)
  } else {
    let { width, height, .. } = render_context
    state.viewport(0, 0, width.to_double(), height.to_double())
  }
  if render_context.scissor {
    self.update_scissor(render_context)
  } else {
    let { width, height, .. } = render_context
    state.scissor(0, 0, width.to_double(), height.to_double())
  }
  state.set_scissor_test(render_context.scissor)
  self.init_timestamp_query(
    @core.TimestampQuery_RENDER,
    backend.get_timestamp_uid(@core.JsValue::of(render_context)),
  )
  render_context_data.set("previousContext", _wgl_js(self._current_context))
  self._current_context = Some(render_context)
  self._set_framebuffer(Context(render_context))
  self.clear_(
    render_context.clear_color,
    render_context.clear_depth,
    render_context.clear_stencil,
    Some(render_context),
    set_frame_buffer=false,
  )
  let occlusion_query_count = render_context.occlusion_query_count
  let occlusion_data = backend.get_occlusion_data(render_context)
  if occlusion_query_count > 0 {
    // Get a reference to the array of objects with queries. The occlusionData property
    // can be changed by another render pass before the async reading of all previous
    // queries complete
    occlusion_data.set(
      "currentOcclusionQueries",
      occlusion_data.get("occlusionQueries"),
    )
    occlusion_data.set(
      "currentOcclusionQueryObjects",
      occlusion_data.get("occlusionQueryObjects"),
    )
    occlusion_data.set("lastOcclusionObject", @core.JsValue::null())
    occlusion_data.set(
      "occlusionQueries",
      _wgl_new_array(occlusion_query_count),
    )
    occlusion_data.set(
      "occlusionQueryObjects",
      _wgl_new_array(occlusion_query_count),
    )
    occlusion_data.set("occlusionQueryIndex", @core.JsValue::of(0))
  } else if !occlusion_data.get("lastOcclusionObject").is_undefined() {
    // invalidate if there is a stale query
    occlusion_data.set("lastOcclusionObject", @core.JsValue::undefined())
  }
}

///|
/// `previousContext` of a render context's record (`None` is `null`).
fn WebGLBackend::_previous_context(
  self : WebGLBackend,
  render_context : @nodes.RenderContext,
) -> @nodes.RenderContext? {
  _wgl_handle(
    self.get(@core.JsValue::of(render_context)).get("previousContext"),
  )
}

///|
/// `finishRender( renderContext )`.
pub impl @nodes.BackendClass for WebGLBackend with fn finish_render(
  self,
  backend,
  render_context,
) {
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  let previous_context = self._previous_context(render_context)
  state.reset_vertex_state()
  let occlusion_query_count = render_context.occlusion_query_count
  if occlusion_query_count > 0 {
    let last_occlusion_object = backend
      .get_occlusion_data(render_context)
      .get("lastOcclusionObject")
    if _wgl_truthy(last_occlusion_object) &&
      @nodes.occlusion_test(last_occlusion_object.cast()) == true {
      gl.end_query(@webgl.GL_ANY_SAMPLES_PASSED)
    }
    self.resolve_occluded_async(backend, render_context)
  }
  match render_context.textures {
    Some(textures) =>
      for texture in textures {
        if texture.generate_mipmaps == true &&
          texture.mipmaps_auto_update == true {
          self.texture_utils.unwrap().generate_mipmaps(texture)
        }
      }
    None => ()
  }
  self._current_context = previous_context
  self._resolve_render_target(render_context)
  match previous_context {
    Some(previous_context) => {
      self._set_framebuffer(Context(previous_context))
      if previous_context.viewport {
        self.update_viewport_(previous_context)
      } else {
        let { width, height, .. } = previous_context
        state.viewport(0, 0, width.to_double(), height.to_double())
      }
      if previous_context.scissor {
        self.update_scissor(previous_context)
      } else {
        let { width, height, .. } = previous_context
        state.scissor(0, 0, width.to_double(), height.to_double())
      }
      state.set_scissor_test(previous_context.scissor)
    }
    None => ()
  }
  self.prepare_timestamp_buffer(
    @core.TimestampQuery_RENDER,
    backend.get_timestamp_uid(@core.JsValue::of(render_context)),
  )
}

///|
/// `resolveOccludedAsync( renderContext )`.
pub fn WebGLBackend::resolve_occluded_async(
  self : WebGLBackend,
  backend : @nodes.Backend,
  render_context : @nodes.RenderContext,
) -> Unit {
  let occlusion_data = backend.get_occlusion_data(render_context)
  // handle occlusion query results
  let current_occlusion_queries = occlusion_data.get("currentOcclusionQueries")
  let current_occlusion_query_objects = occlusion_data.get(
    "currentOcclusionQueryObjects",
  )
  if _wgl_truthy(current_occlusion_queries) &&
    _wgl_truthy(current_occlusion_query_objects) {
    let occluded = _wgl_new_weak_set()
    let gl = self.gl.unwrap()
    occlusion_data.set("currentOcclusionQueryObjects", @core.JsValue::null())
    occlusion_data.set("currentOcclusionQueries", @core.JsValue::null())
    fn check() -> Unit {
      let mut completed = true
      // check all queries and requeue as appropriate
      for i in 0..<_wgl_length(current_occlusion_queries) {
        let query = _wgl_index(current_occlusion_queries, i)
        if !_wgl_truthy(query) {
          continue
        }
        let query : @webgl.GLQuery = query.cast()
        if _wgl_truthy(
            gl.get_query_parameter(query, @webgl.GL_QUERY_RESULT_AVAILABLE),
          ) {
          if gl
            .get_query_parameter(query, @webgl.GL_QUERY_RESULT)
            .strict_equal(@core.JsValue::of(0)) {
            _wgl_weak_set_add(
              occluded,
              _wgl_index(current_occlusion_query_objects, i),
            )
          }
          _wgl_set_index(current_occlusion_queries, i, @core.JsValue::null())
          gl.delete_query(query)
        } else {
          completed = false
        }
      }
      if completed == false {
        _wgl_request_animation_frame(check)
      } else {
        occlusion_data.set("occluded", occluded)
      }
    }

    check()
  }
}

///|
/// `isOccluded( renderContext, object )`.
pub impl @nodes.BackendClass for WebGLBackend with fn is_occluded(
  _,
  backend,
  render_context,
  object,
) {
  let occlusion_data = backend.get_occlusion_data(render_context)
  let occluded = occlusion_data.get("occluded")
  _wgl_truthy(occluded) &&
  _wgl_weak_set_has(occluded, @core.JsValue::of(object))
}

///|
/// `updateViewport( renderContext )`.
pub impl @nodes.BackendClass for WebGLBackend with fn update_viewport(
  self,
  _,
  render_context,
) {
  self.update_viewport_(render_context)
}

///|
/// `updateViewport( renderContext )`.
fn WebGLBackend::update_viewport_(
  self : WebGLBackend,
  render_context : @nodes.RenderContext,
) -> Unit {
  let state = self.state.unwrap()
  let v = render_context.viewport_value
  state.viewport(v.x, render_context.height.to_double() - v.w - v.y, v.z, v.w)
}

///|
/// `updateScissor( renderContext )`.
pub fn WebGLBackend::update_scissor(
  self : WebGLBackend,
  render_context : @nodes.RenderContext,
) -> Unit {
  let state = self.state.unwrap()
  let s = render_context.scissor_value
  state.scissor(s.x, render_context.height.to_double() - s.w - s.y, s.z, s.w)
}

///|
/// `setScissorTest( boolean )`.
pub impl @nodes.BackendClass for WebGLBackend with fn set_scissor_test(
  self,
  _,
  boolean,
) {
  self.state.unwrap().set_scissor_test(boolean)
}

///|
/// `resetState()`.
pub impl @nodes.BackendClass for WebGLBackend with fn reset_state(self, _) {
  self.state.unwrap().reset()
}

///|
/// `getClearColor()`: the common backend's, premultiplied by its alpha (the canvas is
/// always created with `alpha: true`).
pub fn WebGLBackend::get_clear_color(self : WebGLBackend) -> @nodes.Color4 {
  let clear_color = self.base.get_clear_color_base()
  clear_color.color.r *= clear_color.a
  clear_color.color.g *= clear_color.a
  clear_color.color.b *= clear_color.a
  clear_color
}

///|
/// `getClearColor()`.
pub impl @nodes.BackendClass for WebGLBackend with fn get_clear_color(self, _) {
  self.get_clear_color()
}

///|
/// `clear( color, depth, stencil, descriptor = null )`.
pub impl @nodes.BackendClass for WebGLBackend with fn clear(
  self,
  _,
  color,
  depth,
  stencil,
  descriptor,
) {
  self.clear_(color, depth, stencil, descriptor)
}

///|
/// `clear( color, depth, stencil, descriptor = null, setFrameBuffer = true,
/// resolveRenderTarget = true )`. A `None` descriptor is upstream's
/// `{ textures: null, clearColorValue: this.getClearColor() }`.
pub fn WebGLBackend::clear_(
  self : WebGLBackend,
  color : Bool,
  depth : Bool,
  stencil : Bool,
  descriptor : @nodes.RenderContext?,
  set_frame_buffer~ : Bool = true,
  resolve_render_target~ : Bool = true,
) -> Unit {
  let gl = self.gl.unwrap()
  let renderer = self.renderer()
  // `descriptor === null`: `{ textures: null, clearColorValue: this.getClearColor() }`.
  let default_clear_color = match descriptor {
    None => {
      let c = self.get_clear_color()
      Some((c.color.r, c.color.g, c.color.b, c.a))
    }
    Some(_) => None
  }
  let mut clear = 0
  if color {
    clear = clear | @webgl.GL_COLOR_BUFFER_BIT
  }
  if depth {
    clear = clear | @webgl.GL_DEPTH_BUFFER_BIT
  }
  if stencil {
    clear = clear | @webgl.GL_STENCIL_BUFFER_BIT
  }
  if clear != 0 {
    // `descriptor.clearColorValue` is always set (an object is truthy).
    let (r, g, b, a) = match descriptor {
      Some(d) => {
        let c = d.clear_color_value
        (c.r, c.g, c.b, c.a)
      }
      None => default_clear_color.unwrap()
    }
    let clear_depth = renderer.get_clear_depth()
    let clear_stencil = renderer.get_clear_stencil()
    let state = self.state.unwrap()
    if color {
      state.set_color_mask(true)
    }
    if depth {
      state.set_depth_mask(true)
    }
    if stencil {
      state.set_stencil_mask(-1)
    }
    let textures = match descriptor {
      Some(d) => d.textures
      None => None
    }
    match textures {
      None => {
        if color {
          gl.clear_color(r, g, b, a)
        }
        if depth {
          gl.clear_depth(clear_depth)
        }
        if stencil {
          gl.clear_stencil(clear_stencil)
        }
        gl.clear(clear)
      }
      Some(textures) => {
        let descriptor = descriptor.unwrap()
        if set_frame_buffer {
          self._set_framebuffer(Context(descriptor))
        }
        if color {
          for i, texture in textures {
            let mrt_clear_color = match descriptor.mrt {
              Some(mrt) =>
                match @nodes.MRTNode::of(mrt) {
                  Some(m) => m.get_clear_color(texture.name)
                  None => None
                }
              None => None
            }
            match mrt_clear_color {
              Some(c) =>
                gl.clear_bufferfv(@webgl.GL_COLOR, i, [
                  c.color.r,
                  c.color.g,
                  c.color.b,
                  c.a,
                ])
              None =>
                if i == 0 {
                  gl.clear_bufferfv(@webgl.GL_COLOR, i, [r, g, b, a])
                } else {
                  gl.clear_bufferfv(@webgl.GL_COLOR, i, [0.0, 0, 0, 1])
                }
            }
          }
        }
        if depth && stencil {
          gl.clear_bufferfi(
            @webgl.GL_DEPTH_STENCIL,
            0,
            clear_depth,
            clear_stencil,
          )
        } else if depth {
          gl.clear_bufferfv(@webgl.GL_DEPTH, 0, [clear_depth])
        } else if stencil {
          gl.clear_bufferiv(@webgl.GL_STENCIL, 0, [clear_stencil])
        }
        if set_frame_buffer && resolve_render_target {
          self._resolve_render_target(descriptor)
        }
        // Restore the framebuffer of the active render pass when clearing an
        // unrelated render target, so subsequent draws in the pass don't bind to the
        // cleared target.
        match self._current_context {
          Some(current) if set_frame_buffer &&
            !physical_equal(current, descriptor) =>
            self._set_framebuffer(Context(current))
          _ => ()
        }
      }
    }
  }
}

// ---------------------------------------------------------------------------
// compute

///|
/// `beginCompute( computeGroup )`.
pub impl @nodes.BackendClass for WebGLBackend with fn begin_compute(
  self,
  backend,
  compute_group,
) {
  let state = self.state.unwrap()
  state.bind_framebuffer(@webgl.GL_FRAMEBUFFER, None) |> ignore
  self.init_timestamp_query(
    @core.TimestampQuery_COMPUTE,
    backend.get_timestamp_uid(compute_group.key()),
  )
}

///|
extern "js" fn _wgl_warn_once(message : String) -> Unit = "(m) => {}"

///|
/// `compute( computeGroup, computeNode, bindings, pipeline, count = null )`.
pub impl @nodes.BackendClass for WebGLBackend with fn compute(
  self,
  _,
  _,
  compute_node,
  bindings,
  pipeline,
  count,
) {
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  if self.discard == false {
    // required here to handle async behaviour of render.compute()
    state.enable(@webgl.GL_RASTERIZER_DISCARD)
    self.discard = true
  }
  let pipeline_data = self.get(@core.JsValue::of(pipeline))
  let program_gpu : @webgl.GLProgram = pipeline_data.get("programGPU").cast()
  let transform_attributes : Array[@core.BufferAttribute] = pipeline_data
    .get("transformAttributes")
    .cast()
  let attributes : Array[@core.BufferAttribute] = pipeline_data
    .get("attributes")
    .cast()
  // the buffers are managed by the renderer's attributes so they are re-created after
  // disposal
  for attribute in attributes {
    self._update_compute_attribute(attribute)
  }
  for attribute in transform_attributes {
    self._update_compute_attribute(attribute)
  }
  let vao_gpu = self.vertex_array_utils
    .unwrap()
    .get_vao(
      @core.JsValue::of(pipeline),
      attributes.map(fn(a) { @core.GeometryAttribute::Buffer(a) }),
    )
  state.set_vertex_state(Some(vao_gpu)) |> ignore
  state.use_program(Some(program_gpu)) |> ignore
  self._bind_uniforms(bindings)
  // the buffers are only bound to the default transform feedback object during the
  // dispatch so no transform feedback object keeps the memory of disposed buffers
  // allocated
  for i, attribute in transform_attributes {
    gl.bind_buffer_base(
      @webgl.GL_TRANSFORM_FEEDBACK_BUFFER,
      i,
      _wgl_handle(self.get(@core.JsValue::of(attribute)).get("transformBuffer")),
    )
  }
  gl.begin_transform_feedback(@webgl.GL_POINTS)
  let compute_count = match @nodes.ComputeNode::of(compute_node) {
    Some(c) => c.count.unwrap_or(0)
    None => 0
  }
  let count = match count {
    None => compute_count
    Some(Count(c)) => c
    Some(Size(a)) => {
      @core.warn_once(
        "WebGLBackend.compute(): The count parameter must be a single number, not an array.",
      )
      a[0]
    }
    Some(Indirect(_)) => {
      @core.warn_once(
        "WebGLBackend.compute(): The count parameter must be a single number, not IndirectStorageBufferAttribute",
      )
      compute_count
    }
  }
  if @nodes.is_storage_instanced_buffer_attribute(attributes[0]) {
    gl.draw_arrays_instanced(@webgl.GL_POINTS, 0, 1, count)
  } else {
    gl.draw_arrays(@webgl.GL_POINTS, 0, count)
  }
  gl.end_transform_feedback()
  for i in 0..<transform_attributes.length() {
    gl.bind_buffer_base(@webgl.GL_TRANSFORM_FEEDBACK_BUFFER, i, None)
  }
  // switch active buffers
  for attribute in transform_attributes {
    let dual_attribute_data = self.get(@core.JsValue::of(attribute))
    let pbo = dual_attribute_data.get("pbo")
    if _wgl_truthy(pbo) && self.has(pbo) {
      self.texture_utils
      .unwrap()
      .copy_buffer_to_texture(
        _wgl_handle(dual_attribute_data.get("transformBuffer")),
        pbo.cast(),
      )
    }
    DualAttributeData::switch_buffers(dual_attribute_data)
  }
}

///|
/// `_updateComputeAttribute( attribute )`.
fn WebGLBackend::_update_compute_attribute(
  self : WebGLBackend,
  attribute : @core.BufferAttribute,
) -> Unit {
  let buffer_attribute = self.get_buffer_attribute(Buffer(attribute))
  let attribute_type : @nodes.AttributeType = if @nodes.is_storage_buffer_attribute(
      attribute,
    ) ||
    @nodes.is_storage_instanced_buffer_attribute(attribute) {
    STORAGE
  } else {
    VERTEX
  }
  self.renderer()._attributes().update(buffer_attribute, attribute_type)
}

///|
/// `finishCompute( computeGroup )`.
pub impl @nodes.BackendClass for WebGLBackend with fn finish_compute(
  self,
  backend,
  compute_group,
) {
  let state = self.state.unwrap()
  self.discard = false
  state.disable(@webgl.GL_RASTERIZER_DISCARD)
  self.prepare_timestamp_buffer(
    @core.TimestampQuery_COMPUTE,
    backend.get_timestamp_uid(compute_group.key()),
  )
  match self._current_context {
    Some(c) => self._set_framebuffer(Context(c))
    None => ()
  }
}

// ---------------------------------------------------------------------------
// draw

///|
/// The `ArrayCamera` payload of a camera (`isArrayCamera`).
fn _wgl_array_camera(camera : @core.Object3D) -> @core.ArrayCamera? {
  match camera.kind {
    Camera({ kind: PerspectiveCamera(p), .. }) => p.array_camera
    _ => None
  }
}

///|
/// `_isRenderCameraDepthArray( renderContext )`.
fn WebGLBackend::_is_render_camera_depth_array(
  _self : WebGLBackend,
  render_context : @nodes.RenderContext,
) -> Bool {
  match render_context.depth_texture {
    Some(d) =>
      d.is_array_texture &&
      (match render_context.camera {
        Some(c) => _wgl_array_camera(c) is Some(_)
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'isArrayCamera')",
          )
      })
    None => false
  }
}

///|
/// The `BatchedMesh` payload of an object (`isBatchedMesh`).
fn _wgl_batched_mesh(object : @core.Object3D) -> @core.BatchedMesh? {
  match object.kind {
    Mesh({ kind: BatchedMesh(b), .. }) => Some(b)
    _ => None
  }
}

///|
/// `_draw( object, renderer, firstVertex, vertexCount, instanceCount, programGPU )`.
fn WebGLBackend::_draw(
  self : WebGLBackend,
  object : @core.Object3D,
  renderer : WebGLBufferRenderer,
  first_vertex : Int32,
  vertex_count : Int32,
  instance_count : Double,
  program_gpu : @webgl.GLProgram,
) -> Unit {
  match _wgl_batched_mesh(object) {
    Some(batched) =>
      if self.base.has_feature("WEBGL_multi_draw") == false {
        let gl = self.gl.unwrap()
        let draw_id_location = _wgl_js(
          gl.get_uniform_location(program_gpu, "nodeUniformDrawId"),
        )
        let starts = batched._multi_draw_starts
        let counts = batched._multi_draw_counts
        let draw_count = batched._multi_draw_count
        for i in 0..<draw_count {
          _wgl_uniform1ui(gl, draw_id_location, i)
          renderer.render(starts.get(i).to_int(), counts.get(i).to_int())
        }
      } else {
        renderer.render_multi_draw(
          batched._multi_draw_starts,
          batched._multi_draw_counts,
          batched._multi_draw_count,
        )
      }
    None =>
      if instance_count > 1 {
        renderer.render_instances(
          first_vertex,
          vertex_count,
          _wgl_double_to_int(instance_count),
        )
      } else {
        renderer.render(first_vertex, vertex_count)
      }
  }
}

///|
/// A count as JS passes it to GL (`Infinity` wraps to 0, as `ToInt32` does).
extern "js" fn _wgl_double_to_int(v : Double) -> Int32 = "(v) => v | 0"

///|
/// `Math.floor( v )`.
extern "js" fn _wgl_floor(v : Double) -> Double = "(v) => Math.floor( v )"

///|
/// `draw( renderObject, info )`.
pub impl @nodes.BackendClass for WebGLBackend with fn draw(
  self,
  backend,
  render_object,
  _,
) {
  let object = render_object.object
  let pipeline = render_object.pipeline.unwrap()
  let material = render_object.material
  let context = render_object.context
  let hardware_clipping_planes = render_object.hardware_clipping_planes()
  let program_gpu : @webgl.GLProgram = self
    .get(@core.JsValue::of(pipeline))
    .get("programGPU")
    .cast()
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  let draw_params = match render_object.get_draw_parameters() {
    Some(p) => p
    None => return
  }
  self._bind_uniforms(render_object.get_bindings())
  let front_face_cw = object.is_mesh() &&
    object.matrix_world.determinant_affine() < 0
  state.set_material(material, front_face_cw, hardware_clipping_planes)
  match (context.mrt, context.textures) {
    (Some(mrt), Some(textures)) =>
      state.set_mrt_blending(textures, Some(mrt), material)
    _ => ()
  }
  state.use_program(Some(program_gpu)) |> ignore
  // vertex state
  let index = render_object.get_index()
  let vao_gpu = self.vertex_array_utils
    .unwrap()
    .get_vao(
      @core.JsValue::of(render_object),
      render_object.get_attributes(),
      index?,
    )
  state.set_vertex_state(Some(vao_gpu)) |> ignore
  //
  if context.occlusion_query_count > 0 {
    let occlusion_data = backend.get_occlusion_data(context)
    let last_object = occlusion_data.get("lastOcclusionObject")
    if !last_object.strict_equal(@core.JsValue::of(object)) {
      if !last_object.is_null() &&
        @nodes.occlusion_test(last_object.cast()) == true {
        gl.end_query(@webgl.GL_ANY_SAMPLES_PASSED)
        let index : Int32 = occlusion_data.get("occlusionQueryIndex").cast()
        occlusion_data.set("occlusionQueryIndex", @core.JsValue::of(index + 1))
      }
      if @nodes.occlusion_test(object) == true {
        let query = gl.create_query()
        gl.begin_query(@webgl.GL_ANY_SAMPLES_PASSED, query)
        let index : Int32 = occlusion_data.get("occlusionQueryIndex").cast()
        _wgl_set_index(
          occlusion_data.get("occlusionQueries"),
          index,
          @core.JsValue::of(query),
        )
        _wgl_set_index(
          occlusion_data.get("occlusionQueryObjects"),
          index,
          @core.JsValue::of(object),
        )
      }
      occlusion_data.set("lastOcclusionObject", @core.JsValue::of(object))
    }
  }
  //
  let renderer = self.buffer_renderer.unwrap()
  if object.is_points() {
    renderer.mode = Some(@webgl.GL_POINTS)
  } else if object.is_line_segments() {
    renderer.mode = Some(@webgl.GL_LINES)
  } else if object.is_line() {
    renderer.mode = Some(@webgl.GL_LINE_STRIP)
  } else if object.is_line_loop() {
    renderer.mode = Some(@webgl.GL_LINE_LOOP)
  } else if material.wireframe == Some(true) {
    state.set_line_width(
      material.wireframe_linewidth.unwrap_or(1.0) *
      self.renderer().get_pixel_ratio(),
    )
    renderer.mode = Some(@webgl.GL_LINES)
  } else {
    renderer.mode = Some(@webgl.GL_TRIANGLES)
  }
  //
  let vertex_count = draw_params.vertex_count
  let instance_count = draw_params.instance_count
  let mut first_vertex = draw_params.first_vertex
  renderer.object = Some(object)
  match index {
    Some(index) => {
      first_vertex *= index.array().bytes_per_element()
      let index_data = self.get(
        @core.JsValue::of(self.get_buffer_attribute(index).key()),
      )
      renderer.index = index.count()
      renderer.type_ = _wgl_handle(index_data.get("type"))
    }
    None => renderer.index = 0
  }
  let array_camera = _wgl_array_camera(render_object.camera)
  match array_camera {
    Some(array_camera) if array_camera.cameras.length() > 0 &&
      array_camera.is_multi_view_camera == false => {
      let camera_data = self.get(@core.JsValue::of(render_object.camera))
      let cameras = array_camera.cameras
      let camera_index = render_object.get_binding_group("cameraIndex").unwrap().bindings[0]
      let indexes_gpu = camera_data.get("indexesGPU")
      if indexes_gpu.is_undefined() ||
        _wgl_length(indexes_gpu) != cameras.length() {
        let data = @core.TypedArray::uint32([0, 0, 0, 0])
        let indexes_gpu : Array[@webgl.GLBuffer] = []
        for i in 0..<cameras.length() {
          let buffer_gpu = gl.create_buffer()
          data.set(0, i.to_double())
          gl.bind_buffer(@webgl.GL_UNIFORM_BUFFER, Some(buffer_gpu))
          gl.buffer_data(@webgl.GL_UNIFORM_BUFFER, data, @webgl.GL_STATIC_DRAW)
          indexes_gpu.push(buffer_gpu)
        }
        camera_data.set(
          "indexesGPU",
          @core.JsValue::of(FixedArray::from_array(indexes_gpu)),
        ) // TODO: Create a global library for this
      }
      let indexes_gpu : FixedArray[@webgl.GLBuffer] = camera_data
        .get("indexesGPU")
        .cast()
      let mut camera_index_buffer_index = 0
      let mut found = false
      for bind_group in render_object.get_bindings() {
        for binding in bind_group.bindings {
          if physical_equal(binding, camera_index) {
            found = true
            break
          }
          if binding.has_flag("isUniformsGroup") ||
            binding.has_flag("isUniformBuffer") {
            camera_index_buffer_index += 1
          }
        }
        if found {
          break
        }
      }
      let current_context = self._current_context.unwrap()
      let render_target = current_context.render_target
      let pixel_ratio = match render_target {
        None => self.renderer().get_pixel_ratio()
        Some(rt) =>
          if rt.has_extension_flag("isPostProcessingRenderTarget") {
            self.renderer().get_pixel_ratio()
          } else {
            1.0
          }
      }
      let is_render_camera_depth_array = self._is_render_camera_depth_array(
        current_context,
      )
      let prev_active_cube_face = current_context.active_cube_face
      if is_render_camera_depth_array {
        // Clear the depth texture
        let texture_data = self.get(_wgl_js(current_context.depth_texture))
        let render_id = self.renderer()._nodes().node_frame.render_id
        if !texture_data
          .get("clearedRenderId")
          .strict_equal(@core.JsValue::of(render_id)) {
          texture_data.set("clearedRenderId", @core.JsValue::of(render_id))
          let stencil_buffer = render_target.unwrap().stencil_buffer
          for i in 0..<cameras.length() {
            self.renderer()._active_cube_face = i
            current_context.active_cube_face = i
            self._set_framebuffer(Context(current_context))
            self.clear_(
              false,
              true,
              stencil_buffer,
              Some(current_context),
              set_frame_buffer=false,
              resolve_render_target=false,
            )
          }
          self.renderer()._active_cube_face = prev_active_cube_face
          current_context.active_cube_face = prev_active_cube_face
        }
      }
      let frustum_array = context.frustum_array
      for i, sub_camera in cameras {
        if object.layers.test_(sub_camera.layers) &&
          (
            array_camera.per_camera_frustum_culled == false ||
            object.frustum_culled == false ||
            object.intersects_frustum(
              Single(frustum_array.unwrap().get_frustum(i).unwrap()),
            )
          ) {
          if is_render_camera_depth_array {
            // Update the active layer
            self.renderer()._active_cube_face = i
            current_context.active_cube_face = i
            self._set_framebuffer(Context(current_context))
          }
          match @webgl.camera_viewport(sub_camera) {
            Some(vp) => {
              let x = vp.x * pixel_ratio
              let y = vp.y * pixel_ratio
              let width = vp.z * pixel_ratio
              let height = vp.w * pixel_ratio
              state.viewport(
                _wgl_floor(x),
                _wgl_floor(
                  render_object.context.height.to_double() - height - y,
                ),
                _wgl_floor(width),
                _wgl_floor(height),
              )
            }
            None => ()
          }
          state.bind_buffer_base(
            @webgl.GL_UNIFORM_BUFFER,
            camera_index_buffer_index,
            Some(indexes_gpu[i]),
          )
          |> ignore
          self._draw(
            object, renderer, first_vertex, vertex_count, instance_count, program_gpu,
          )
        }
        current_context.active_cube_face = prev_active_cube_face
        self.renderer()._active_cube_face = prev_active_cube_face
      }
    }
    _ =>
      self._draw(
        object, renderer, first_vertex, vertex_count, instance_count, program_gpu,
      )
  }
}

///|
/// `deleteVertexState( renderObject )`.
pub impl @nodes.BackendClass for WebGLBackend with fn delete_vertex_state(
  self,
  _,
  render_object,
) {
  self.vertex_array_utils.unwrap().release_vao(@core.JsValue::of(render_object))
}

///|
/// `needsRenderUpdate( renderObject )`.
pub impl @nodes.BackendClass for WebGLBackend with fn needs_render_update(
  _,
  _,
  _,
) {
  false
}

///|
/// `getRenderCacheKey( renderObject )`.
pub impl @nodes.BackendClass for WebGLBackend with fn get_render_cache_key(
  _,
  _,
  _,
) {
  ""
}

// ---------------------------------------------------------------------------
// textures

///|
/// `createDefaultTexture( texture )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_default_texture(
  self,
  _,
  texture,
) {
  self.texture_utils.unwrap().create_default_texture(texture)
}

///|
/// `createTexture( texture, options )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_texture(
  self,
  _,
  texture,
  options,
) {
  self.texture_utils.unwrap().create_texture(texture, options)
}

///|
/// `updateTexture( texture, options )`.
pub impl @nodes.BackendClass for WebGLBackend with fn update_texture(
  self,
  _,
  texture,
  options,
) {
  self.texture_utils.unwrap().update_texture(texture, options)
}

///|
/// `generateMipmaps( texture )`.
pub impl @nodes.BackendClass for WebGLBackend with fn generate_mipmaps(
  self,
  _,
  texture,
) {
  self.texture_utils.unwrap().generate_mipmaps(texture)
}

///|
/// `destroyTexture( texture, isDefaultTexture = false )`.
pub impl @nodes.BackendClass for WebGLBackend with fn destroy_texture(
  self,
  _,
  texture,
  is_default_texture,
) {
  self.texture_utils
  .unwrap()
  .destroy_texture(
    texture,
    is_default_texture=is_default_texture.unwrap_or(false),
  )
}

///|
/// `copyTextureToBuffer( texture, x, y, width, height, faceIndex )`.
pub impl @nodes.BackendClass for WebGLBackend with fn copy_texture_to_buffer(
  self,
  _,
  texture,
  x,
  y,
  width,
  height,
  face_index,
  on_done,
) {
  self.texture_utils
  .unwrap()
  .copy_texture_to_buffer(texture, x, y, width, height, face_index, fn(a) {
    on_done(Some(a))
  })
}

///|
/// `updateSampler( binding )`.
pub impl @nodes.BackendClass for WebGLBackend with fn update_sampler(_, _, _) {
  ""
}

///|
/// `createNodeBuilder( object, renderer )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_node_builder(
  _,
  _,
  object,
  renderer,
) {
  GLSLNodeBuilder::new(object, renderer)
}

// ---------------------------------------------------------------------------
// programs and pipelines

///|
/// `createProgram( program )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_program(
  self,
  _,
  program,
) {
  let gl = self.gl.unwrap()
  self._create_program(@core.JsValue::of(program), program.stage, program.code)
  ignore(gl)
}

///|
/// `createProgram( { stage, code } )` for any program object.
fn WebGLBackend::_create_program(
  self : WebGLBackend,
  program : @core.JsValue,
  stage : String,
  code : String,
) -> Unit {
  let gl = self.gl.unwrap()
  let shader = if stage == "fragment" {
    gl.create_shader(@webgl.GL_FRAGMENT_SHADER)
  } else {
    gl.create_shader(@webgl.GL_VERTEX_SHADER)
  }
  gl.shader_source(shader, code)
  gl.compile_shader(shader)
  let record = @core.JsValue::object()
  record.set("shaderGPU", @core.JsValue::of(shader))
  self.set(program, record)
}

///|
/// `destroyProgram( program )`.
pub impl @nodes.BackendClass for WebGLBackend with fn destroy_program(
  self,
  _,
  program,
) {
  let gl = self.gl.unwrap()
  let data = self.get(@core.JsValue::of(program))
  gl.delete_shader(data.get("shaderGPU").cast())
  self.delete(@core.JsValue::of(program))
}

///|
/// `createRenderPipeline( renderObject, promises )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_render_pipeline(
  self,
  _,
  render_object,
  promises,
) {
  let gl = self.gl.unwrap()
  let pipeline = render_object.pipeline.unwrap()
  // Program
  let (fragment_program, vertex_program) = match pipeline.kind {
    RenderObject(vertex_program~, fragment_program~) =>
      (fragment_program, vertex_program)
    _ =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'shaderGPU')",
      )
  }
  let program_gpu = gl.create_program()
  let fragment_shader : @webgl.GLShader = self
    .get(@core.JsValue::of(fragment_program))
    .get("shaderGPU")
    .cast()
  let vertex_shader : @webgl.GLShader = self
    .get(@core.JsValue::of(vertex_program))
    .get("shaderGPU")
    .cast()
  gl.attach_shader(program_gpu, fragment_shader)
  gl.attach_shader(program_gpu, vertex_shader)
  gl.link_program(program_gpu)
  let record = @core.JsValue::object()
  record.set("programGPU", @core.JsValue::of(program_gpu))
  record.set("fragmentShader", @core.JsValue::of(fragment_shader))
  record.set("vertexShader", @core.JsValue::of(vertex_shader))
  self.set(@core.JsValue::of(pipeline), record)
  match (promises, self.parallel) {
    (Some(promises), Some(parallel)) => {
      let p = _wgl_status_promise(
        fn() {
          _wgl_truthy(
            gl.get_program_parameter(
              program_gpu,
              parallel.constant("COMPLETION_STATUS_KHR"),
            ),
          )
        },
        fn() { self._complete_compile(render_object, pipeline) },
      )
      promises.push(p)
      return
    }
    _ => ()
  }
  self._complete_compile(render_object, pipeline)
}

///|
/// `destroyPipeline( pipeline )`.
pub impl @nodes.BackendClass for WebGLBackend with fn destroy_pipeline(
  self,
  _,
  pipeline,
) {
  let gl = self.gl.unwrap()
  let data = self.get(@core.JsValue::of(pipeline))
  if pipeline.is_compute_pipeline() == true {
    // Compute pipeline manage their own VAOs (without render objects)
    self.vertex_array_utils.unwrap().release_vao(@core.JsValue::of(pipeline))
  }
  gl.delete_program(data.get("programGPU").cast())
  self.delete(@core.JsValue::of(pipeline))
}

///|
extern "js" fn _wgl_handle_source(
  source : String,
  error_line : Int32,
) -> String =
  #|( string, errorLine ) => {
  #|  const lines = string.split( '\n' );
  #|  const lines2 = [];
  #|  const from = Math.max( errorLine - 6, 0 );
  #|  const to = Math.min( errorLine + 6, lines.length );
  #|  for ( let i = from; i < to; i ++ ) {
  #|    const line = i + 1;
  #|    lines2.push( `${line === errorLine ? '>' : ' '} ${line}: ${lines[ i ]}` );
  #|  }
  #|  return lines2.join( '\n' );
  #|}

///|
/// `/ERROR: 0:(\d+)/.exec( errors )`: the line, or -1.
extern "js" fn _wgl_error_line(errors : String) -> Int32 = "(e) => { const m = /ERROR: 0:([0-9]+)/.exec( e ); return m ? parseInt( m[ 1 ] ) : -1; }"

///|
extern "js" fn _wgl_trim(s : String) -> String = "(s) => s.trim()"

///|
extern "js" fn _wgl_js_string(v : @core.JsValue) -> String = "(v) => String( v )"

///|
/// `_getShaderErrors( gl, shader, type )`.
fn WebGLBackend::_get_shader_errors(
  _self : WebGLBackend,
  gl : @webgl.WebGL2RenderingContext,
  shader : @webgl.GLShader,
  type_ : String,
) -> String {
  let status = _wgl_truthy(
    gl.get_shader_parameter(shader, @webgl.GL_COMPILE_STATUS),
  )
  let shader_info_log = match gl.get_shader_info_log(shader) {
    Some(s) if s != "" => s
    _ => ""
  }
  let errors = _wgl_trim(shader_info_log)
  if status && errors == "" {
    return ""
  }
  let error_line = _wgl_error_line(errors)
  if error_line >= 0 {
    type_.to_upper() +
    "\n\n" +
    errors +
    "\n\n" +
    _wgl_handle_source(
      gl.get_shader_source(shader).unwrap_or("null"),
      error_line,
    )
  } else {
    errors
  }
}

///|
/// `renderer.debug.onShaderError( gl, programGPU, glVertexShader, glFragmentShader )`.
extern "js" fn _wgl_call_on_shader_error(
  f : @core.JsValue,
  gl : @webgl.WebGL2RenderingContext,
  program : @webgl.GLProgram,
  vertex_shader : @webgl.GLShader,
  fragment_shader : @webgl.GLShader,
) -> Unit = "(f, gl, p, v, fs) => f( gl, p, v, fs )"

///|
extern "js" fn _wgl_is_function(f : @core.JsValue) -> Bool = "(f) => typeof f === 'function'"

///|
/// `_logProgramError( programGPU, glFragmentShader, glVertexShader )`.
fn WebGLBackend::_log_program_error(
  self : WebGLBackend,
  program_gpu : @webgl.GLProgram,
  gl_fragment_shader : @webgl.GLShader,
  gl_vertex_shader : @webgl.GLShader,
) -> Unit {
  let renderer = self.renderer()
  if renderer.debug.check_shader_errors {
    let gl = self.gl.unwrap()
    let program_info_log = match gl.get_program_info_log(program_gpu) {
      Some(s) if s != "" => s
      _ => ""
    }
    let program_log = _wgl_trim(program_info_log)
    if gl
      .get_program_parameter(program_gpu, @webgl.GL_LINK_STATUS)
      .strict_equal(@core.JsValue::of(false)) {
      match renderer.debug.on_shader_error {
        Some(f) if _wgl_is_function(f) =>
          _wgl_call_on_shader_error(
            f, gl, program_gpu, gl_vertex_shader, gl_fragment_shader,
          )
        _ => {
          // default error reporting
          let vertex_errors = self._get_shader_errors(
            gl, gl_vertex_shader, "vertex",
          )
          let fragment_errors = self._get_shader_errors(
            gl, gl_fragment_shader, "fragment",
          )
          @core.error(
            "WebGLProgram: Shader Error " +
            gl.get_error().to_string() +
            " - " +
            "VALIDATE_STATUS " +
            _wgl_js_string(
              gl.get_program_parameter(program_gpu, @webgl.GL_VALIDATE_STATUS),
            ) +
            "\n\n" +
            "Program Info Log: " +
            program_log +
            "\n" +
            vertex_errors +
            "\n" +
            fragment_errors,
          )
        }
      }
    } else if program_log != "" {
      @core.warn("WebGLProgram: Program Info Log: " + program_log)
    }
  }
}

///|
/// `_completeCompile( renderObject, pipeline )`.
fn WebGLBackend::_complete_compile(
  self : WebGLBackend,
  render_object : @nodes.RenderObject,
  pipeline : @nodes.Pipeline,
) -> Unit {
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  let pipeline_data = self.get(@core.JsValue::of(pipeline))
  let program_gpu : @webgl.GLProgram = pipeline_data.get("programGPU").cast()
  let fragment_shader : @webgl.GLShader = pipeline_data
    .get("fragmentShader")
    .cast()
  let vertex_shader : @webgl.GLShader = pipeline_data.get("vertexShader").cast()
  if gl
    .get_program_parameter(program_gpu, @webgl.GL_LINK_STATUS)
    .strict_equal(@core.JsValue::of(false)) {
    self._log_program_error(program_gpu, fragment_shader, vertex_shader)
  }
  state.use_program(Some(program_gpu)) |> ignore
  // Bindings
  let bindings = render_object.get_bindings()
  self._setup_bindings(bindings, program_gpu)
  //
  let record = @core.JsValue::object()
  record.set("programGPU", @core.JsValue::of(program_gpu))
  record.set("pipeline", @core.JsValue::of(program_gpu))
  self.set(@core.JsValue::of(pipeline), record)
}

///|
/// The compute fragment program of `createComputePipeline`.
priv struct WebGLComputeFragmentProgram {
  stage : String
  code : String
}

///|
/// `createComputePipeline( computePipeline, bindings, promises = null )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_compute_pipeline(
  self,
  _,
  compute_pipeline,
  bindings,
  promises,
) {
  let gl = self.gl.unwrap()
  // Program
  let fragment_program : WebGLComputeFragmentProgram = {
    stage: "fragment",
    code: "#version 300 es\nprecision highp float;\nvoid main() {}",
  }
  self._create_program(
    @core.JsValue::of(fragment_program),
    fragment_program.stage,
    fragment_program.code,
  )
  let (compute_program, transforms, attribute_nodes) = match
    compute_pipeline.kind {
    Compute(compute_program~, transforms~, attributes~) =>
      (compute_program, transforms.unwrap_or([]), attributes.unwrap_or([]))
    _ =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'shaderGPU')",
      )
  }
  let program_gpu = gl.create_program()
  let fragment_shader : @webgl.GLShader = self
    .get(@core.JsValue::of(fragment_program))
    .get("shaderGPU")
    .cast()
  let vertex_shader : @webgl.GLShader = self
    .get(@core.JsValue::of(compute_program))
    .get("shaderGPU")
    .cast()
  let transform_varying_names = []
  let transform_attribute_nodes = []
  for transform in transforms {
    transform_varying_names.push(transform.varying_name)
    transform_attribute_nodes.push(transform.attribute_node)
  }
  gl.attach_shader(program_gpu, fragment_shader)
  gl.attach_shader(program_gpu, vertex_shader)
  gl.transform_feedback_varyings(
    program_gpu,
    @core.JsValue::of(FixedArray::from_array(transform_varying_names)),
    @webgl.GL_SEPARATE_ATTRIBS,
  )
  gl.link_program(program_gpu)
  // only the attributes are stored since their buffers are re-created when they are
  // disposed (see compute())
  let attributes : Array[@core.BufferAttribute] = []
  let transform_attributes : Array[@core.BufferAttribute] = []
  for attribute_node in attribute_nodes {
    attributes.push(_wgl_node_attribute(attribute_node.node))
  }
  for attribute_node in transform_attribute_nodes {
    transform_attributes.push(_wgl_node_attribute(Some(attribute_node)))
  }
  // Store pipeline data
  let record = @core.JsValue::object()
  record.set("programGPU", @core.JsValue::of(program_gpu))
  record.set("fragmentShader", @core.JsValue::of(fragment_shader))
  record.set("vertexShader", @core.JsValue::of(vertex_shader))
  record.set("transformAttributes", @core.JsValue::of(transform_attributes))
  record.set("attributes", @core.JsValue::of(attributes))
  self.set(@core.JsValue::of(compute_pipeline), record)
  match (promises, self.parallel) {
    (Some(promises), Some(parallel)) => {
      let p = _wgl_status_promise(
        fn() {
          _wgl_truthy(
            gl.get_program_parameter(
              program_gpu,
              parallel.constant("COMPLETION_STATUS_KHR"),
            ),
          )
        },
        fn() { self._complete_compute_compile(compute_pipeline, bindings) },
      )
      promises.push(p)
      return
    }
    _ => ()
  }
  // Sync fallback
  self._complete_compute_compile(compute_pipeline, bindings)
}

///|
/// `node.attribute` of a `BufferAttributeNode`: the attribute it reads.
fn _wgl_node_attribute(node : @nodes.Node?) -> @core.BufferAttribute {
  match node {
    Some(n) =>
      match @nodes.BufferAttributeNode::of(n) {
        Some({ attribute: Some(Buffer(a)), .. }) => a
        _ =>
          abort(
            "WebGLBackend: the attribute of a compute pipeline is not a buffer attribute",
          )
      }
    None =>
      abort("TypeError: Cannot read properties of null (reading 'attribute')")
  }
}

///|
/// `_completeComputeCompile( computePipeline, bindings )`.
fn WebGLBackend::_complete_compute_compile(
  self : WebGLBackend,
  compute_pipeline : @nodes.Pipeline,
  bindings : Array[@nodes.BindGroup],
) -> Unit {
  let gl = self.gl.unwrap()
  let state = self.state.unwrap()
  let data = self.get(@core.JsValue::of(compute_pipeline))
  let program_gpu : @webgl.GLProgram = data.get("programGPU").cast()
  if gl
    .get_program_parameter(program_gpu, @webgl.GL_LINK_STATUS)
    .strict_equal(@core.JsValue::of(false)) {
    self._log_program_error(
      program_gpu,
      data.get("fragmentShader").cast(),
      data.get("vertexShader").cast(),
    )
  }
  state.use_program(Some(program_gpu)) |> ignore
  // Bindings (must be after link completion)
  self._setup_bindings(bindings, program_gpu)
}

// ---------------------------------------------------------------------------
// bindings

///|
/// `createBindings( bindGroup, bindings )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_bindings(
  self,
  _,
  bind_group,
  bindings,
  _,
) {
  if self._known_bindings.has(bindings) == false {
    self._known_bindings.set(bindings, true)
    let mut uniform_buffers = 0
    let mut textures = 0
    for group in bindings {
      let record = @core.JsValue::object()
      record.set("textures", @core.JsValue::of(textures))
      record.set("uniformBuffers", @core.JsValue::of(uniform_buffers))
      self.set(@core.JsValue::of(group), record)
      for binding in group.bindings {
        if binding.has_flag("isUniformBuffer") {
          uniform_buffers += 1
        }
        if binding.has_flag("isSampledTexture") {
          textures += 1
        }
      }
    }
  }
  self._update_bindings(bind_group)
}

///|
/// `updateBindings( bindGroup )`.
pub impl @nodes.BackendClass for WebGLBackend with fn update_bindings(
  self,
  _,
  bind_group,
  _,
  _,
  _,
) {
  self._update_bindings(bind_group)
}

///|
extern "js" fn _wgl_is_typed_array(v : @core.JsValue) -> Bool = "(v) => ArrayBuffer.isView( v ) && ! ( v instanceof DataView )"

///|
/// `updateBindings( bindGroup )`.
fn WebGLBackend::_update_bindings(
  self : WebGLBackend,
  bind_group : @nodes.BindGroup,
) -> Unit {
  let gl = self.gl.unwrap()
  for binding in bind_group.bindings {
    let map = self.get(@core.JsValue::of(binding))
    if binding.has_flag("isUniformsGroup") ||
      binding.has_flag("isUniformBuffer") {
      let array = binding.buffer()
      let buffer_gpu : @webgl.GLBuffer? = _wgl_handle(map.get("bufferGPU"))
      gl.bind_buffer(@webgl.GL_UNIFORM_BUFFER, buffer_gpu)
      // update
      let update_ranges = binding.update_ranges()
      gl.bind_buffer(@webgl.GL_UNIFORM_BUFFER, buffer_gpu)
      if update_ranges.length() == 0 {
        gl.buffer_data(@webgl.GL_UNIFORM_BUFFER, array, @webgl.GL_DYNAMIC_DRAW)
      } else {
        let array = array.unwrap()
        let is_typed = _wgl_is_typed_array(@core.JsValue::of(array))
        let byte_offset_factor = if is_typed {
          1
        } else {
          array.bytes_per_element()
        }
        for range in update_ranges {
          let data_offset = range.start * byte_offset_factor
          let size = range.count * byte_offset_factor
          let buffer_offset = data_offset *
            (if is_typed { array.bytes_per_element() } else { 1 }) // bufferOffset is always in bytes
          gl.buffer_sub_data_range(
            @webgl.GL_UNIFORM_BUFFER,
            buffer_offset,
            array,
            data_offset,
            size,
          )
        }
      }
      self.set(@core.JsValue::of(binding), map)
    } else if binding.has_flag("isSampledTexture") {
      let texture_data = self.get(_wgl_js(binding.texture()))
      map.set("textureGPU", texture_data.get("textureGPU"))
      map.set("glTextureType", texture_data.get("glTextureType"))
      self.set(@core.JsValue::of(binding), map)
    }
  }
}

///|
/// `updateBinding( binding )`.
pub impl @nodes.BackendClass for WebGLBackend with fn update_binding(
  self,
  _,
  binding,
) {
  let gl = self.gl.unwrap()
  if binding.has_flag("isUniformsGroup") || binding.has_flag("isUniformBuffer") {
    let binding_data = self.get(@core.JsValue::of(binding))
    let buffer_gpu : @webgl.GLBuffer? = _wgl_handle(
      binding_data.get("bufferGPU"),
    )
    let array = binding.buffer()
    let update_ranges = binding.update_ranges()
    gl.bind_buffer(@webgl.GL_UNIFORM_BUFFER, buffer_gpu)
    if update_ranges.length() == 0 {
      gl.buffer_data(@webgl.GL_UNIFORM_BUFFER, array, @webgl.GL_DYNAMIC_DRAW)
    } else {
      let array = array.unwrap()
      let is_typed = _wgl_is_typed_array(@core.JsValue::of(array))
      let byte_offset_factor = if is_typed {
        1
      } else {
        array.bytes_per_element()
      }
      // Update ranges arrive sorted and non-overlapping which makes it easy to merge
      // contiguous ranges.
      let mut start = update_ranges[0].start // start of the current merged range
      for i, range in update_ranges {
        let next = if i + 1 < update_ranges.length() {
          Some(update_ranges[i + 1])
        } else {
          None
        }
        let end = range.start + range.count // exclusive end of the current range
        // keep merging while the next range is contiguous
        if next is Some(n) && n.start == end {
          continue
        }
        // write the merged range
        let data_offset = start * byte_offset_factor
        let size = (end - start) * byte_offset_factor
        let buffer_offset = data_offset *
          (if is_typed { array.bytes_per_element() } else { 1 }) // bufferOffset is always in bytes
        gl.buffer_sub_data_range(
          @webgl.GL_UNIFORM_BUFFER,
          buffer_offset,
          array,
          data_offset,
          size,
        )
        // start next if possible
        match next {
          Some(n) => start = n.start
          None => ()
        }
      }
    }
  }
}

///|
/// `createUniformBuffer( uniformBuffer )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_uniform_buffer(
  self,
  _,
  uniform_buffer,
) {
  let uniform_buffer_data = self.get(@core.JsValue::of(uniform_buffer))
  if uniform_buffer_data.get("bufferGPU").is_undefined() {
    let gl = self.gl.unwrap()
    let array = uniform_buffer.buffer()
    let buffer_gpu = gl.create_buffer()
    uniform_buffer_data.set("bufferGPU", @core.JsValue::of(buffer_gpu))
    gl.bind_buffer(@webgl.GL_UNIFORM_BUFFER, Some(buffer_gpu))
    gl.buffer_data_size(
      @webgl.GL_UNIFORM_BUFFER,
      match array {
        Some(a) => a.byte_length()
        None => 0
      },
      @webgl.GL_DYNAMIC_DRAW,
    )
  }
}

///|
/// `destroyUniformBuffer( uniformBuffer )`.
pub impl @nodes.BackendClass for WebGLBackend with fn destroy_uniform_buffer(
  self,
  _,
  uniform_buffer,
) {
  let uniform_buffer_data = self.get(@core.JsValue::of(uniform_buffer))
  _wgl_delete_buffer(self.gl.unwrap(), uniform_buffer_data.get("bufferGPU"))
  self.delete(@core.JsValue::of(uniform_buffer))
}

///|
/// `gl.deleteBuffer( buffer )` with a nullable buffer.
extern "js" fn _wgl_delete_buffer(
  gl : @webgl.WebGL2RenderingContext,
  buffer : @core.JsValue,
) -> Unit = "(gl, b) => gl.deleteBuffer( b )"

// ---------------------------------------------------------------------------
// attributes

///|
/// `createIndexAttribute( attribute )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_index_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils
  .unwrap()
  .create_attribute(attribute, @webgl.GL_ELEMENT_ARRAY_BUFFER)
}

///|
/// `createAttribute( attribute )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_attribute(
  self,
  _,
  attribute,
) {
  if self.has(attribute.key()) {
    return
  }
  self.attribute_utils
  .unwrap()
  .create_attribute(attribute, @webgl.GL_ARRAY_BUFFER)
}

///|
/// `createStorageAttribute( attribute )`.
pub impl @nodes.BackendClass for WebGLBackend with fn create_storage_attribute(
  self,
  _,
  attribute,
) {
  if self.has(attribute.key()) {
    return
  }
  self.attribute_utils
  .unwrap()
  .create_attribute(attribute, @webgl.GL_ARRAY_BUFFER)
}

///|
/// `updateAttribute( attribute )`.
pub impl @nodes.BackendClass for WebGLBackend with fn update_attribute(
  self,
  _,
  attribute,
) {
  self.attribute_utils.unwrap().update_attribute(attribute)
}

///|
/// `destroyAttribute( attribute )`.
pub impl @nodes.BackendClass for WebGLBackend with fn destroy_attribute(
  self,
  _,
  attribute,
) {
  // VAOs keep the memory of attached buffers allocated
  self.vertex_array_utils.unwrap().release_buffer(self.get(attribute.key()))
  self.attribute_utils.unwrap().destroy_attribute(attribute)
}

///|
/// `hasFeature( name )`.
pub impl @nodes.BackendClass for WebGLBackend with fn has_feature(self, _, name) {
  let extensions = self.extensions.unwrap()
  for entry in gl_feature_name {
    if entry.1 == name && extensions.has(entry.0) {
      return true
    }
  }
  false
}

///|
/// `copyTextureToTexture( srcTexture, dstTexture, srcRegion = null, dstPosition = null,
/// srcLevel = 0, dstLevel = 0 )`.
pub impl @nodes.BackendClass for WebGLBackend with fn copy_texture_to_texture(
  self,
  _,
  src_texture,
  dst_texture,
  src_region,
  dst_position,
  src_level,
  dst_level,
) {
  self.texture_utils
  .unwrap()
  .copy_texture_to_texture(
    src_texture,
    dst_texture,
    src_region?,
    dst_position?,
    src_level~,
    dst_level~,
  )
}

///|
/// `copyFramebufferToTexture( texture, renderContext, rectangle )`.
pub impl @nodes.BackendClass for WebGLBackend with fn copy_framebuffer_to_texture(
  self,
  _,
  texture,
  render_context,
  rectangle,
) {
  self.texture_utils
  .unwrap()
  .copy_framebuffer_to_texture(texture, render_context, rectangle)
}

///|
/// `hasCompatibility( name )`.
pub impl @nodes.BackendClass for WebGLBackend with fn has_compatibility(
  _,
  _,
  name,
) {
  if name == @core.Compatibility_TEXTURE_COMPARE {
    return true
  }
  // `super.hasCompatibility( name )`.
  false
}

///|
/// `initRenderTarget( renderContext )`.
pub impl @nodes.BackendClass for WebGLBackend with fn init_render_target(
  self,
  _,
  render_context,
) {
  self._set_framebuffer(Context(render_context))
  self.state.unwrap().bind_framebuffer(@webgl.GL_FRAMEBUFFER, None) |> ignore
}

///|
/// `_setupBindings( bindings, programGPU )`.
fn WebGLBackend::_setup_bindings(
  self : WebGLBackend,
  bindings : Array[@nodes.BindGroup],
  program_gpu : @webgl.GLProgram,
) -> Unit {
  let gl = self.gl.unwrap()
  let mut uniform_buffers = 0
  let mut textures = 0
  for bind_group in bindings {
    for binding in bind_group.bindings {
      if binding.has_flag("isUniformsGroup") ||
        binding.has_flag("isUniformBuffer") {
        let index = uniform_buffers
        uniform_buffers += 1
        let location = gl.get_uniform_block_index(program_gpu, binding.name)
        gl.uniform_block_binding(program_gpu, location, index)
      } else if binding.has_flag("isSampledTexture") {
        let index = textures
        textures += 1
        let location = gl.get_uniform_location(program_gpu, binding.name)
        _wgl_uniform1i(gl, _wgl_js(location), index)
      }
    }
  }
}

///|
/// `_bindUniforms( bindings )`.
fn WebGLBackend::_bind_uniforms(
  self : WebGLBackend,
  bindings : Array[@nodes.BindGroup],
) -> Unit {
  let state = self.state.unwrap()
  let mut uniform_buffers = 0
  let mut textures = 0
  for bind_group in bindings {
    for binding in bind_group.bindings {
      let binding_data = self.get(@core.JsValue::of(binding))
      if binding.has_flag("isUniformsGroup") ||
        binding.has_flag("isUniformBuffer") {
        let index = uniform_buffers
        uniform_buffers += 1
        // TODO USE bindBufferRange to group multiple uniform buffers
        state.bind_buffer_base(
          @webgl.GL_UNIFORM_BUFFER,
          index,
          _wgl_handle(binding_data.get("bufferGPU")),
        )
        |> ignore
      } else if binding.has_flag("isSampledTexture") {
        let index = textures
        textures += 1
        state.bind_texture(
          _wgl_record_int(binding_data, "glTextureType"),
          _wgl_handle(binding_data.get("textureGPU")),
          webgl_slot=@webgl.GL_TEXTURE0 + index,
        )
      }
    }
  }
}

///|
extern "js" fn _wgl_record_int(record : @core.JsValue, key : String) -> Int32 = "(r, k) => r[ k ]"

///|
/// `async dispose()`.
pub impl @nodes.BackendClass for WebGLBackend with fn dispose(
  self,
  backend,
  on_done,
) {
  // `await super.dispose()`.
  backend.dispose_base()
  match self.vertex_array_utils {
    Some(v) => v.dispose()
    None => ()
  }
  match self.texture_utils {
    Some(t) => t.dispose()
    None => ()
  }
  if backend.parameters.get("canvas").is_undefined() {
    match self.extensions.unwrap().get("WEBGL_lose_context") {
      Some(extension) => extension.lose_context()
      None => ()
    }
  }
  _wgl_remove_event_listener(
    self.renderer().dom_element(),
    "webglcontextlost",
    _wgl_js(self._on_context_lost),
  )
  on_done()
}

///|
/// `backend.state !== null` (XR foveation).
pub impl @nodes.BackendClass for WebGLBackend with fn has_state(self, _) {
  self.state is Some(_)
}

///|
/// `backend.state.bindTexture( glTextureType, textureGPU )`.
pub impl @nodes.BackendClass for WebGLBackend with fn state_bind_texture(
  self,
  _,
  gl_texture_type,
  texture_gpu,
) {
  self.state.unwrap().bind_texture(gl_texture_type, _wgl_handle(texture_gpu))
}

///|
/// `backend.state.unbindTexture()`.
pub impl @nodes.BackendClass for WebGLBackend with fn state_unbind_texture(
  self,
  _,
) {
  self.state.unwrap().unbind_texture()
}
