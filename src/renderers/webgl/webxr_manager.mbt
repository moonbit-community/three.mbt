// Upstream src/renderers/webxr/WebXRManager.js. It lives in this package because it
// needs `WebGLRenderer` and `WebGLRenderTarget`, and the renderer needs it.
//
// `setSession` is async upstream; here `set_session( session, on_done? )` runs `on_done`
// where upstream's promise resolves. As upstream, the constructor reads
// `gl.getContextAttributes()`.

///|
/// The base layer of a session: `XRProjectionLayer` with WebXR Layers, else
/// `XRWebGLLayer`.
pub(all) enum WebXRBaseLayer {
  ProjectionLayer(XRProjectionLayer)
  WebGLLayer(XRWebGLLayer)
}

///|
/// `currentCameraSettings`: the user camera's `fov` and `zoom` before the session.
priv struct WebXRCameraSettings {
  camera : @core.Object3D
  fov : Double
  zoom : Double
}

///|
/// `WebXRManager`.
pub struct WebXRManager {
  renderer : WebGLRenderer
  gl : WebGL2RenderingContext
  dispatcher : @core.EventDispatcher
  mut enabled : Bool
  mut is_presenting : Bool
  mut camera_auto_update : Bool
  priv mut session : XRSession?
  priv mut framebuffer_scale_factor : Double
  priv mut reference_space : XRReferenceSpace?
  priv mut reference_space_type : String
  priv mut foveation : Double
  priv mut custom_reference_space : XRReferenceSpace?
  priv mut pose : XRViewerPose?
  priv mut gl_binding : XRWebGLBinding?
  priv mut gl_proj_layer : XRProjectionLayer?
  priv mut gl_base_layer : XRWebGLLayer?
  priv mut xr_frame : XRFrame?
  priv supports_gl_binding : Bool
  priv depth_sensing : WebXRDepthSensing
  priv camera_access_textures : Map[String, @core.Texture]
  priv mut attributes : @core.JsValue?
  priv mut initial_render_target : @core.RenderTarget?
  priv mut new_render_target : @core.RenderTarget?
  priv controllers : Array[WebXRController?]
  /// Dense; an index past the end is upstream's `undefined`, `None` its `null`.
  priv controller_input_sources : Array[XRInputSource?]
  priv current_size : @math.Vector2
  priv mut current_pixel_ratio : Double
  priv mut current_camera_settings : WebXRCameraSettings?
  priv camera_l : @core.Object3D
  priv camera_r : @core.Object3D
  priv cameras : Array[@core.Object3D]
  priv camera_xr : @core.Object3D
  priv mut _current_depth_near : Double?
  priv mut _current_depth_far : Double?
  priv animation : WebGLAnimation
  priv mut on_animation_frame_callback : ((Double, @core.JsValue) -> Unit)?
  priv mut on_session_event : (@core.JsValue) -> Unit
  priv mut on_session_end : (@core.JsValue) -> Unit
  priv mut on_input_sources_change : (@core.JsValue) -> Unit
}

///|
/// `new WebXRManager( renderer, gl )`.
pub fn WebXRManager::new(
  renderer : WebGLRenderer,
  gl : WebGL2RenderingContext,
) -> WebXRManager {
  let camera_l = @core.PerspectiveCamera::new()
  set_camera_viewport(camera_l, Some(@math.Vector4::new(0.0, 0.0, 0.0, 0.0)))
  let camera_r = @core.PerspectiveCamera::new()
  set_camera_viewport(camera_r, Some(@math.Vector4::new(0.0, 0.0, 0.0, 0.0)))
  let camera_xr = @core.ArrayCamera::new()
  let depth_sensing = WebXRDepthSensing::new()
  let attributes = gl.get_context_attributes()
  let xr : WebXRManager = {
    renderer,
    gl,
    dispatcher: @core.EventDispatcher::new(),
    enabled: false,
    is_presenting: false,
    camera_auto_update: true,
    session: None,
    framebuffer_scale_factor: 1.0,
    reference_space: None,
    reference_space_type: "local-floor",
    // Set default foveation to maximum.
    foveation: 1.0,
    custom_reference_space: None,
    pose: None,
    gl_binding: None,
    gl_proj_layer: None,
    gl_base_layer: None,
    xr_frame: None,
    supports_gl_binding: xr_webgl_binding_supported(),
    depth_sensing,
    camera_access_textures: Map([]),
    attributes: Some(attributes),
    initial_render_target: None,
    new_render_target: None,
    controllers: [],
    controller_input_sources: [],
    current_size: @math.Vector2::new(0.0, 0.0),
    current_pixel_ratio: 1.0,
    current_camera_settings: None,
    camera_l,
    camera_r,
    cameras: [camera_l, camera_r],
    camera_xr,
    _current_depth_near: None,
    _current_depth_far: None,
    animation: WebGLAnimation::new(),
    on_animation_frame_callback: None,
    on_session_event: _ => (),
    on_session_end: _ => (),
    on_input_sources_change: _ => (),
  }
  xr.on_session_event = event => xr.handle_session_event(event.cast())
  xr.on_session_end = _ => xr.handle_session_end()
  xr.on_input_sources_change = event => {
    xr.handle_input_sources_change(event.cast())
  }
  xr.animation.set_animation_loop(
    Some((time, frame) => xr.on_animation_frame(time, frame.cast())),
  )
  xr
}

///|
pub impl @core.EventSource for WebXRManager with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl @core.EventSource for WebXRManager with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend WebXRManager with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// `xr.enabled = value`, for other packages.
pub fn WebXRManager::set_enabled(self : WebXRManager, value : Bool) -> Unit {
  self.enabled = value
}

///|
/// `xr.cameraAutoUpdate = value`, for other packages.
pub fn WebXRManager::set_camera_auto_update(
  self : WebXRManager,
  value : Bool,
) -> Unit {
  self.camera_auto_update = value
}

///|
/// The context attributes, read by the constructor as upstream.
fn WebXRManager::context_attributes(self : WebXRManager) -> @core.JsValue {
  match self.attributes {
    Some(attributes) => attributes
    None => {
      let attributes = self.gl.get_context_attributes()
      self.attributes = Some(attributes)
      attributes
    }
  }
}

///|
fn WebXRManager::controller_at(
  self : WebXRManager,
  index : Int32,
) -> WebXRController {
  if index < self.controllers.length() {
    if self.controllers[index] is Some(controller) {
      return controller
    }
  }
  let controller = WebXRController::new()
  while self.controllers.length() <= index {
    self.controllers.push(None)
  }
  self.controllers[index] = Some(controller)
  controller
}

///|
/// `xr.getController( index )`: the target ray space group.
pub fn WebXRManager::get_controller(
  self : WebXRManager,
  index : Int32,
) -> @core.Object3D {
  self.controller_at(index).get_target_ray_space()
}

///|
/// `xr.getControllerGrip( index )`: the grip space group.
pub fn WebXRManager::get_controller_grip(
  self : WebXRManager,
  index : Int32,
) -> @core.Object3D {
  self.controller_at(index).get_grip_space()
}

///|
/// `xr.getHand( index )`: the hand space group.
pub fn WebXRManager::get_hand(
  self : WebXRManager,
  index : Int32,
) -> @core.Object3D {
  self.controller_at(index).get_hand_space()
}

///|
/// `controllerInputSources.indexOf( inputSource )`.
fn WebXRManager::input_source_index(
  self : WebXRManager,
  input_source : XRInputSource,
) -> Int32 {
  for i, source in self.controller_input_sources {
    if source is Some(source) && physical_equal(source, input_source) {
      return i
    }
  }
  -1
}

///|
/// `customReferenceSpace || referenceSpace`.
fn WebXRManager::current_reference_space(
  self : WebXRManager,
) -> XRReferenceSpace? {
  match self.custom_reference_space {
    Some(_) as space => space
    None => self.reference_space
  }
}

///|
/// `onSessionEvent( event )`.
fn WebXRManager::handle_session_event(
  self : WebXRManager,
  event : XRInputSourceEvent,
) -> Unit {
  let input_source = event.input_source()
  let controller_index = self.input_source_index(input_source)
  if controller_index == -1 {
    return
  }
  if controller_index < self.controllers.length() &&
    self.controllers[controller_index] is Some(controller) {
    ignore(
      controller.update(
        Some(input_source),
        event.frame(),
        self.current_reference_space(),
      ),
    )
    ignore(
      controller.dispatch_event(
        @core.Event::new(event.type_(), data=@core.JsValue::of(input_source)),
      ),
    )
  }
}

///|
/// `onSessionEnd()`.
fn WebXRManager::handle_session_end(self : WebXRManager) -> Unit {
  guard self.session is Some(session) else {
    abort("WebXRManager: session ended without a session")
  }
  session.remove_event_listener("select", self.on_session_event)
  session.remove_event_listener("selectstart", self.on_session_event)
  session.remove_event_listener("selectend", self.on_session_event)
  session.remove_event_listener("squeeze", self.on_session_event)
  session.remove_event_listener("squeezestart", self.on_session_event)
  session.remove_event_listener("squeezeend", self.on_session_event)
  session.remove_event_listener("end", self.on_session_end)
  session.remove_event_listener(
    "inputsourceschange",
    self.on_input_sources_change,
  )
  for i in 0..<self.controllers.length() {
    // past the end is `undefined`, which is not skipped
    let input_source = if i < self.controller_input_sources.length() {
      match self.controller_input_sources[i] {
        None => continue
        source => source
      }
    } else {
      None
    }
    if i < self.controller_input_sources.length() {
      self.controller_input_sources[i] = None
    } else {
      self.controller_input_sources.push(None)
    }
    match self.controllers[i] {
      Some(controller) => ignore(controller.disconnect(input_source))
      None => abort("WebXRManager: no controller at index " + i.to_string())
    }
  }
  self._current_depth_near = None
  self._current_depth_far = None
  self.depth_sensing.reset()
  self.camera_access_textures.clear()

  // restore framebuffer/rendering state
  self.renderer.set_render_target(self.initial_render_target)
  self.gl_base_layer = None
  self.gl_proj_layer = None
  self.gl_binding = None
  self.session = None
  self.new_render_target = None

  //
  self.animation.stop()
  self.is_presenting = false
  self.renderer.set_pixel_ratio(self.current_pixel_ratio)
  self.renderer.set_size(
    self.current_size.x,
    self.current_size.y,
    update_style=false,
  )
  if self.current_camera_settings is Some(settings) {
    let camera = settings.camera.as_perspective_camera()
    camera.fov = settings.fov
    camera.zoom = settings.zoom
    settings.camera.update_projection_matrix()
    self.current_camera_settings = None
  }
  self.dispatch_event(@core.Event::new("sessionend"))
}

///|
/// `xr.setFramebufferScaleFactor( value )`.
pub fn WebXRManager::set_framebuffer_scale_factor(
  self : WebXRManager,
  value : Double,
) -> Unit {
  self.framebuffer_scale_factor = value
  if self.is_presenting {
    @core.warn(
      "WebXRManager: Cannot change framebuffer scale while presenting.",
    )
  }
}

///|
/// `xr.setReferenceSpaceType( value )`.
pub fn WebXRManager::set_reference_space_type(
  self : WebXRManager,
  value : String,
) -> Unit {
  self.reference_space_type = value
  if self.is_presenting {
    @core.warn(
      "WebXRManager: Cannot change reference space type while presenting.",
    )
  }
}

///|
/// `xr.getReferenceSpace()`.
pub fn WebXRManager::get_reference_space(
  self : WebXRManager,
) -> XRReferenceSpace? {
  self.current_reference_space()
}

///|
/// `xr.setReferenceSpace( space )`.
pub fn WebXRManager::set_reference_space(
  self : WebXRManager,
  space : XRReferenceSpace?,
) -> Unit {
  self.custom_reference_space = space
}

///|
/// `xr.getBaseLayer()`.
pub fn WebXRManager::get_base_layer(self : WebXRManager) -> WebXRBaseLayer? {
  match self.gl_proj_layer {
    Some(layer) => Some(ProjectionLayer(layer))
    None => self.gl_base_layer.map(layer => WebGLLayer(layer))
  }
}

///|
/// `xr.getBinding()`: creates the binding on first use where the browser has one.
pub fn WebXRManager::get_binding(self : WebXRManager) -> XRWebGLBinding? {
  if self.gl_binding is None && self.supports_gl_binding {
    guard self.session is Some(session) else {
      abort("WebXRManager.getBinding: no session")
    }
    self.gl_binding = Some(XRWebGLBinding::new(session, self.gl))
  }
  self.gl_binding
}

///|
/// `xr.getFrame()`: the frame of the running XR animation callback.
pub fn WebXRManager::get_frame(self : WebXRManager) -> XRFrame? {
  self.xr_frame
}

///|
/// `xr.getSession()`.
pub fn WebXRManager::get_session(self : WebXRManager) -> XRSession? {
  self.session
}

///|
/// The `isXRRenderTarget` render target: a `WebGLRenderTarget` with the flag set.
priv struct WebXRRenderTargetExtension {}

///|
impl @core.RenderTargetExtension for WebXRRenderTargetExtension with fn construct(
  _,
) {
  // the flag is an own property upstream, which `clone` does not copy
  WebGLRenderTarget::new()
}

///|
impl @core.RenderTargetExtension for WebXRRenderTargetExtension with fn payload(
  _,
) {
  @core.JsValue::of(({ kind: WebGLRenderTarget, } : WebGLRenderTargetExtension))
}

///|
impl @core.RenderTargetExtension for WebXRRenderTargetExtension with fn has_flag(
  _,
  flag,
) {
  flag == "isWebGLRenderTarget" || flag == "isXRRenderTarget"
}

///|
/// `xr.setSession( value )`; `on_done` runs where upstream's promise resolves.
pub fn WebXRManager::set_session(
  self : WebXRManager,
  value : XRSession?,
  on_done? : () -> Unit,
) -> Unit {
  self.session = value
  guard value is Some(session) else {
    if on_done is Some(on_done) {
      on_done()
    }
    return
  }
  let attributes = self.context_attributes()
  self.initial_render_target = self.renderer.get_render_target()
  session.add_event_listener("select", self.on_session_event)
  session.add_event_listener("selectstart", self.on_session_event)
  session.add_event_listener("selectend", self.on_session_event)
  session.add_event_listener("squeeze", self.on_session_event)
  session.add_event_listener("squeezestart", self.on_session_event)
  session.add_event_listener("squeezeend", self.on_session_event)
  session.add_event_listener("end", self.on_session_end)
  session.add_event_listener("inputsourceschange", self.on_input_sources_change)
  let continue_session = () => self.set_session_layers(attributes, on_done)
  if !xr_compatible_attribute(attributes) {
    self.gl.make_xr_compatible(continue_session)
  } else {
    continue_session()
  }
}

///|
/// `setSession` after `await gl.makeXRCompatible()`.
fn WebXRManager::set_session_layers(
  self : WebXRManager,
  attributes : @core.JsValue,
  on_done : (() -> Unit)?,
) -> Unit {
  guard self.session is Some(session) else {
    abort("WebXRManager.setSession: session was cleared")
  }
  let renderer = self.renderer
  let gl = self.gl
  self.current_pixel_ratio = renderer.get_pixel_ratio()
  ignore(renderer.get_size(self.current_size))

  // Check that the browser implements the necessary APIs to use an
  // XRProjectionLayer rather than an XRWebGLLayer
  let supports_layers = self.supports_gl_binding &&
    xr_webgl_binding_supports_layers()
  let stencil = xr_truthy(attributes.get("stencil"))
  let new_render_target = if !supports_layers {
    let gl_base_layer = XRWebGLLayer::new(
      session,
      gl,
      attributes.get("antialias"),
      true,
      attributes.get("depth"),
      attributes.get("stencil"),
      self.framebuffer_scale_factor,
    )
    self.gl_base_layer = Some(gl_base_layer)
    session.update_render_state_base_layer(gl_base_layer)
    renderer.set_pixel_ratio(1.0)
    renderer.set_size(
      gl_base_layer.framebuffer_width().to_double(),
      gl_base_layer.framebuffer_height().to_double(),
      update_style=false,
    )
    let keep_depth = gl_base_layer.keeps_depth_values()
    WebGLRenderTarget::new(
      width=gl_base_layer.framebuffer_width(),
      height=gl_base_layer.framebuffer_height(),
      format=@core.RGBAFormat,
      type_=@core.UnsignedByteType,
      color_space=renderer.output_color_space(),
      stencil_buffer=stencil,
      resolve_depth_buffer=keep_depth,
      resolve_stencil_buffer=keep_depth,
      store_multisampled_depth_buffer=keep_depth,
      store_multisampled_stencil_buffer=keep_depth,
    )
  } else {
    let mut depth_format : Int32? = None
    let mut depth_type : Int32? = None
    let mut gl_depth_format : Int32? = None
    if xr_truthy(attributes.get("depth")) {
      gl_depth_format = Some(
        if stencil {
          GL_DEPTH24_STENCIL8
        } else {
          GL_DEPTH_COMPONENT24
        },
      )
      depth_format = Some(
        if stencil {
          @core.DepthStencilFormat
        } else {
          @core.DepthFormat
        },
      )
      depth_type = Some(
        if stencil {
          @core.UnsignedInt248Type
        } else {
          @core.UnsignedIntType
        },
      )
    }
    let gl_binding = match self.get_binding() {
      Some(binding) => binding
      None => abort("WebXRManager.setSession: no XRWebGLBinding")
    }
    self.gl_binding = Some(gl_binding)
    let gl_proj_layer = gl_binding.create_projection_layer(
      GL_RGBA8,
      gl_depth_format,
      self.framebuffer_scale_factor,
    )
    self.gl_proj_layer = Some(gl_proj_layer)
    session.update_render_state_layers([gl_proj_layer])
    renderer.set_pixel_ratio(1.0)
    renderer.set_size(
      gl_proj_layer.texture_width().to_double(),
      gl_proj_layer.texture_height().to_double(),
      update_style=false,
    )
    // upstream's `new DepthTexture( ..., null, ..., null )` throws without depth
    let depth_texture = match (depth_type, depth_format) {
      (Some(type_), Some(format)) =>
        @core.DepthTexture::new(
          width=gl_proj_layer.texture_width(),
          height=gl_proj_layer.texture_height(),
          type_~,
          format~,
        )
      _ =>
        abort(
          "THREE.DepthTexture: format must be either THREE.DepthFormat or THREE.DepthStencilFormat",
        )
    }
    let keep_depth = gl_proj_layer.keeps_depth_values()
    WebGLRenderTarget::new(
      width=gl_proj_layer.texture_width(),
      height=gl_proj_layer.texture_height(),
      format=@core.RGBAFormat,
      type_=@core.UnsignedByteType,
      depth_texture~,
      stencil_buffer=stencil,
      color_space=renderer.output_color_space(),
      samples=if xr_truthy(attributes.get("antialias")) { 4 } else { 0 },
      resolve_depth_buffer=keep_depth,
      resolve_stencil_buffer=keep_depth,
      store_multisampled_depth_buffer=keep_depth,
      store_multisampled_stencil_buffer=keep_depth,
    )
  }
  ignore(new_render_target.set_extension(WebXRRenderTargetExtension::{ })) // TODO Remove this when possible, see #23278
  self.new_render_target = Some(new_render_target)
  self.set_foveation(self.foveation)
  self.custom_reference_space = None
  session.request_reference_space(self.reference_space_type, reference_space => {
    self.reference_space = Some(reference_space)
    self.animation.set_context(Some(session.as_animation_frame_provider()))
    self.animation.start()
    self.is_presenting = true
    self.dispatch_event(@core.Event::new("sessionstart"))
    if on_done is Some(on_done) {
      on_done()
    }
  })
}

///|
/// `xr.getEnvironmentBlendMode()`; `None` (upstream `undefined`) without a session.
pub fn WebXRManager::get_environment_blend_mode(self : WebXRManager) -> String? {
  match self.session {
    Some(session) => Some(session.environment_blend_mode())
    None => None
  }
}

///|
/// `xr.getDepthTexture()`.
pub fn WebXRManager::get_depth_texture(self : WebXRManager) -> @core.Texture? {
  self.depth_sensing.get_depth_texture()
}

///|
/// `onInputSourcesChange( event )`.
fn WebXRManager::handle_input_sources_change(
  self : WebXRManager,
  event : XRInputSourcesChangeEvent,
) -> Unit {
  // Notify disconnected
  for input_source in event.removed() {
    let index = self.input_source_index(input_source)
    if index >= 0 {
      self.controller_input_sources[index] = None
      match self.controllers[index] {
        Some(controller) => ignore(controller.disconnect(Some(input_source)))
        None =>
          abort("WebXRManager: no controller at index " + index.to_string())
      }
    }
  }

  // Notify connected
  for input_source in event.added() {
    let mut controller_index = self.input_source_index(input_source)
    if controller_index == -1 {
      // Assign input source a controller that currently has no input source
      for i in 0..<self.controllers.length() {
        if i >= self.controller_input_sources.length() {
          self.controller_input_sources.push(Some(input_source))
          controller_index = i
          break
        } else if self.controller_input_sources[i] is None {
          self.controller_input_sources[i] = Some(input_source)
          controller_index = i
          break
        }
      }

      // If all controllers do currently receive input we ignore new ones
      if controller_index == -1 {
        break
      }
    }
    if controller_index < self.controllers.length() &&
      self.controllers[controller_index] is Some(controller) {
      ignore(controller.connect(input_source))
    }
  }
}

///|
/// The `ArrayCamera` data of `cameraXR`.
fn webxr_array_camera(camera : @core.Object3D) -> @core.ArrayCamera {
  match camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(array), .. }), .. }) =>
      array
    _ => abort("WebXRManager: not an ArrayCamera")
  }
}

///|
/// `camera.near`.
fn webxr_camera_near(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.near
    OrthographicCamera(c) => c.near
    BaseCamera => abort("WebXRManager.updateCamera: camera without near")
  }
}

///|
/// `camera.far`.
fn webxr_camera_far(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far
    OrthographicCamera(c) => c.far
    BaseCamera => abort("WebXRManager.updateCamera: camera without far")
  }
}

///|
/// `camera.near = near; camera.far = far` on a perspective camera.
fn webxr_set_near_far(
  camera : @core.Object3D,
  near : Double,
  far : Double,
) -> Unit {
  let perspective = camera.as_perspective_camera()
  perspective.near = near
  perspective.far = far
}

///|
extern "js" fn webxr_layers_with_eyes(mask : Double) -> Double = "(m) => m | 0b110"

///|
extern "js" fn webxr_layers_left(mask : Double) -> Double = "(m) => m & ~0b100"

///|
extern "js" fn webxr_layers_right(mask : Double) -> Double = "(m) => m & ~0b010"

///|
extern "js" fn webxr_math_atan(x : Double) -> Double = "Math.atan"

///|
/// `updateCamera( camera, parent )`: the world matrices of an XR sub-camera.
fn webxr_update_camera(
  camera : @core.Object3D,
  parent : @core.Object3D?,
) -> Unit {
  match parent {
    None => ignore(camera.matrix_world.copy(camera.matrix))
    Some(parent) =>
      ignore(
        camera.matrix_world.multiply_matrices(
          parent.matrix_world,
          camera.matrix,
        ),
      )
  }
  ignore(
    camera.as_camera().matrix_world_inverse.copy(camera.matrix_world).invert(),
  )
}

///|
/// `xr.updateCamera( camera )`: moves the XR camera rig and `camera` to the viewer pose.
pub fn WebXRManager::update_camera(
  self : WebXRManager,
  camera : @core.Object3D,
) -> Unit {
  guard self.session is Some(session) else { return }
  let camera_xr = self.camera_xr
  let camera_l = self.camera_l
  let camera_r = self.camera_r
  let mut depth_near = webxr_camera_near(camera)
  let mut depth_far = webxr_camera_far(camera)
  if self.depth_sensing.texture is Some(_) {
    if self.depth_sensing.depth_near > 0.0 {
      depth_near = self.depth_sensing.depth_near
    }
    if self.depth_sensing.depth_far > 0.0 {
      depth_far = self.depth_sensing.depth_far
    }
  }
  webxr_set_near_far(camera_l, depth_near, depth_far)
  webxr_set_near_far(camera_r, depth_near, depth_far)
  webxr_set_near_far(camera_xr, depth_near, depth_far)
  if self._current_depth_near != Some(depth_near) ||
    self._current_depth_far != Some(depth_far) {
    // Note that the new renderState won't apply until the next frame. See #18320
    session.update_render_state_depth(depth_near, depth_far)
    self._current_depth_near = Some(depth_near)
    self._current_depth_far = Some(depth_far)
  }

  // inherit camera layers and enable eye layers (1 = left, 2 = right)
  camera_xr.layers.mask = webxr_layers_with_eyes(camera.layers.mask)
  camera_l.layers.mask = webxr_layers_left(camera_xr.layers.mask)
  camera_r.layers.mask = webxr_layers_right(camera_xr.layers.mask)
  let parent = camera.parent
  let cameras = webxr_array_camera(camera_xr).cameras
  webxr_update_camera(camera_xr, parent)
  for sub_camera in cameras {
    webxr_update_camera(sub_camera, parent)
  }
  let xr_data = camera_xr.as_camera()
  let l_data = camera_l.as_camera()
  ignore(xr_data.projection_matrix.copy(l_data.projection_matrix))
  ignore(
    xr_data.projection_matrix_inverse.copy(l_data.projection_matrix_inverse),
  )

  // update user camera and its children
  if self.current_camera_settings is None && camera.is_perspective_camera() {
    let perspective = camera.as_perspective_camera()
    self.current_camera_settings = Some({
      camera,
      fov: perspective.fov,
      zoom: perspective.zoom,
    })
  }
  webxr_update_user_camera(camera, camera_xr, parent)
}

///|
/// `updateUserCamera( camera, cameraXR, parent )`.
fn webxr_update_user_camera(
  camera : @core.Object3D,
  camera_xr : @core.Object3D,
  parent : @core.Object3D?,
) -> Unit {
  match parent {
    None => ignore(camera.matrix.copy(camera_xr.matrix_world))
    Some(parent) => {
      ignore(camera.matrix.copy(parent.matrix_world))
      ignore(camera.matrix.invert())
      ignore(camera.matrix.multiply(camera_xr.matrix_world))
    }
  }
  ignore(
    camera.matrix.decompose(camera.position, camera.quaternion, camera.scale),
  )
  camera.update_matrix_world(force=true)
  let data = camera.as_camera()
  let xr_data = camera_xr.as_camera()
  ignore(data.projection_matrix.copy(xr_data.projection_matrix))
  ignore(data.projection_matrix_inverse.copy(xr_data.projection_matrix_inverse))
  if camera.is_perspective_camera() {
    let perspective = camera.as_perspective_camera()
    perspective.fov = @math.RAD2DEG *
      2.0 *
      webxr_math_atan(1.0 / data.projection_matrix.elements[5])
    perspective.zoom = 1.0
  }
}

///|
/// `xr.getCamera()`: the `ArrayCamera` with one sub-camera per view.
pub fn WebXRManager::get_camera(self : WebXRManager) -> @core.Object3D {
  self.camera_xr
}

///|
/// `xr.getFoveation()`; `None` (upstream `undefined`) without a layer.
pub fn WebXRManager::get_foveation(self : WebXRManager) -> Double? {
  if self.gl_proj_layer is None && self.gl_base_layer is None {
    return None
  }
  Some(self.foveation)
}

///|
/// `xr.setFoveation( value )`: `0` is full resolution, `1` maximum foveation.
pub fn WebXRManager::set_foveation(self : WebXRManager, value : Double) -> Unit {
  // 0 = no foveation = full resolution
  // 1 = maximum foveation = the edges render at lower resolution
  self.foveation = value
  if self.gl_proj_layer is Some(layer) {
    layer.set_fixed_foveation(value)
  }
  if self.gl_base_layer is Some(layer) && layer.has_fixed_foveation() {
    layer.set_fixed_foveation(value)
  }
}

///|
/// `xr.hasDepthSensing()`.
pub fn WebXRManager::has_depth_sensing(self : WebXRManager) -> Bool {
  self.depth_sensing.texture is Some(_)
}

///|
/// `xr.getDepthSensingMesh()`.
pub fn WebXRManager::get_depth_sensing_mesh(
  self : WebXRManager,
) -> @core.Object3D? {
  self.depth_sensing.get_mesh(self.camera_xr)
}

///|
/// `xr.getCameraTexture( xrCamera )`. Upstream keys a plain object by the camera, so
/// every camera shares the key `String( camera )`; this keeps that.
pub fn WebXRManager::get_camera_texture(
  self : WebXRManager,
  xr_camera : XRCamera,
) -> @core.Texture? {
  self.camera_access_textures.get(xr_property_key(@core.JsValue::of(xr_camera)))
}

///|
/// `onAnimationFrame( time, frame )`, the XR session's animation loop.
fn WebXRManager::on_animation_frame(
  self : WebXRManager,
  time : Double,
  frame : XRFrame,
) -> Unit {
  let renderer = self.renderer
  self.pose = frame.get_viewer_pose(self.current_reference_space())
  self.xr_frame = Some(frame)
  if self.pose is Some(pose) {
    let views = pose.views()
    if self.gl_base_layer is Some(gl_base_layer) {
      let new_render_target = self.new_render_target.unwrap()
      renderer.set_render_target_framebuffer(
        new_render_target,
        gl_base_layer.framebuffer(),
      )
      renderer.set_render_target(Some(new_render_target))
    }
    let mut camera_xr_needs_update = false
    let xr_cameras = webxr_array_camera(self.camera_xr).cameras

    // check if it's necessary to rebuild cameraXR's camera list
    if views.length() != xr_cameras.length() {
      xr_cameras.clear()
      camera_xr_needs_update = true
    }
    for i, view in views {
      let viewport = match self.gl_base_layer {
        Some(gl_base_layer) => gl_base_layer.get_viewport(view)
        None => {
          let gl_binding = self.gl_binding.unwrap()
          let gl_sub_image = gl_binding.get_view_sub_image(
            self.gl_proj_layer.unwrap(),
            view,
          )
          let viewport = gl_sub_image.viewport()

          // For side-by-side projection, we only produce a single texture for both eyes.
          if i == 0 {
            let new_render_target = self.new_render_target.unwrap()
            renderer.set_render_target_textures(
              new_render_target,
              gl_sub_image.color_texture(),
              gl_sub_image.depth_stencil_texture(),
            )
            renderer.set_render_target(Some(new_render_target))
          }
          viewport
        }
      }
      let camera = if i < self.cameras.length() {
        self.cameras[i]
      } else {
        let camera = @core.PerspectiveCamera::new()
        camera.layers.enable(i)
        set_camera_viewport(
          camera,
          Some(@math.Vector4::new(0.0, 0.0, 0.0, 0.0)),
        )
        self.cameras.push(camera)
        camera
      }
      ignore(camera.matrix.from_array(view.transform().matrix()))
      ignore(
        camera.matrix.decompose(
          camera.position,
          camera.quaternion,
          camera.scale,
        ),
      )
      let data = camera.as_camera()
      ignore(data.projection_matrix.from_array(view.projection_matrix()))
      ignore(
        data.projection_matrix_inverse.copy(data.projection_matrix).invert(),
      )
      ignore(
        camera_viewport(camera)
        .unwrap()
        .set(viewport.x(), viewport.y(), viewport.width(), viewport.height()),
      )
      if i == 0 {
        let camera_xr = self.camera_xr
        ignore(camera_xr.matrix.copy(camera.matrix))
        ignore(
          camera_xr.matrix.decompose(
            camera_xr.position,
            camera_xr.quaternion,
            camera_xr.scale,
          ),
        )
      }
      if camera_xr_needs_update {
        xr_cameras.push(camera)
      }
    }

    //
    let session = self.session.unwrap()
    let enabled_features = session.enabled_features()
    let gpu_depth_sensing_enabled = match enabled_features {
      Some(features) =>
        features.contains("depth-sensing") &&
        session.depth_usage_is("gpu-optimized")
      None => false
    }
    if gpu_depth_sensing_enabled && self.supports_gl_binding {
      self.gl_binding = self.get_binding()
      let depth_data = self.gl_binding.unwrap().get_depth_information(views[0])
      if depth_data is Some(depth_data) &&
        depth_data.is_valid() &&
        depth_data.texture() is Some(_) {
        self.depth_sensing.init(depth_data, session.render_state())
      }
    }
    let camera_access_enabled = match enabled_features {
      Some(features) => features.contains("camera-access")
      None => false
    }
    if camera_access_enabled && self.supports_gl_binding {
      renderer.state.unbind_texture()
      self.gl_binding = self.get_binding()
      for view in views {
        if view.camera() is Some(camera) {
          let key = xr_property_key(@core.JsValue::of(camera))
          let camera_tex = match self.camera_access_textures.get(key) {
            Some(texture) => texture
            None => {
              let texture = @core.ExternalTexture::new()
              self.camera_access_textures[key] = texture
              texture
            }
          }
          let gl_texture = self.gl_binding.unwrap().get_camera_image(camera)
          camera_tex.external_source = gl_texture.map(@core.JsValue::of)
        }
      }
    }
  }

  //
  for i in 0..<self.controllers.length() {
    guard self.controllers[i] is Some(controller) else { continue }
    if i >= self.controller_input_sources.length() {
      // upstream's `undefined` input source passes the `!== null` check
      ignore(controller.update(None, frame, self.current_reference_space()))
    } else if self.controller_input_sources[i] is Some(input_source) {
      ignore(
        controller.update(
          Some(input_source),
          frame,
          self.current_reference_space(),
        ),
      )
    }
  }
  if self.on_animation_frame_callback is Some(callback) {
    callback(time, @core.JsValue::of(frame))
  }
  if frame.has_detected_planes() {
    self.dispatch_event(
      @core.Event::new("planesdetected", data=@core.JsValue::of(frame)),
    )
  }
  self.xr_frame = None
}

///|
/// `xr.setAnimationLoop( callback )`: called with `( time, xrFrame )` while presenting.
pub fn WebXRManager::set_animation_loop(
  self : WebXRManager,
  callback : ((Double, @core.JsValue) -> Unit)?,
) -> Unit {
  self.on_animation_frame_callback = callback
}

///|
/// `xr.dispose()`.
pub fn WebXRManager::dispose(_self : WebXRManager) -> Unit {

}
