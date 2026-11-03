// renderers/common/XRManager.js: WebXR for the WebGPU and WebGL backends. The XR
// objects (session, layers, bindings, frames, views) are JS values; `WebXRController`
// is the one of renderers/webgl. Upstream's async members take a callback.

///|
let _xr_manager_context_node_lib : @webgl.WeakMap[@core.JsValue, Node] = @webgl.WeakMap::new()

///|
extern "js" fn xr_supports_gl_binding() -> Bool = "() => typeof XRWebGLBinding !== 'undefined'"

///|
extern "js" fn xr_supports_webgpu_binding() -> Bool = "() => typeof globalThis.XRGPUBinding !== 'undefined'"

///|
extern "js" fn xr_supports_layers() -> Bool = "() => typeof XRWebGLBinding !== 'undefined' && 'createProjectionLayer' in XRWebGLBinding.prototype"

///|
extern "js" fn xr_new_gl_binding(
  session : @core.JsValue,
  gl : @core.JsValue,
) -> @core.JsValue = "(s, gl) => new XRWebGLBinding( s, gl )"

///|
extern "js" fn xr_new_gpu_binding(
  session : @core.JsValue,
  device : @core.JsValue,
) -> @core.JsValue = "(s, d) => new globalThis.XRGPUBinding( s, d )"

///|
extern "js" fn xr_new_rigid_transform(
  position : @math.Vector3,
  quaternion : @math.Quaternion,
) -> @core.JsValue = "(p, q) => new XRRigidTransform( { x: p.x, y: p.y, z: p.z }, { x: q._x, y: q._y, z: q._z, w: q._w } )"

///|
extern "js" fn xr_new_webgl_layer(
  session : @core.JsValue,
  gl : @core.JsValue,
  init : @core.JsValue,
) -> @core.JsValue = "(s, gl, i) => new XRWebGLLayer( s, gl, i )"

///|
extern "js" fn xr_call0(object : @core.JsValue, name : String) -> @core.JsValue = "(o, m) => o[ m ]()"

///|
extern "js" fn xr_call1(
  object : @core.JsValue,
  name : String,
  a : @core.JsValue,
) -> @core.JsValue = "(o, m, a) => o[ m ]( a )"

///|
extern "js" fn xr_call2(
  object : @core.JsValue,
  name : String,
  a : @core.JsValue,
  b : @core.JsValue,
) -> @core.JsValue = "(o, m, a, b) => o[ m ]( a, b )"

///|
extern "js" fn xr_has_function(object : @core.JsValue, name : String) -> Bool = "(o, m) => typeof o[ m ] === 'function'"

///|
extern "js" fn xr_then(
  promise : @core.JsValue,
  on_done : (@core.JsValue) -> Unit,
) -> Unit = "(p, f) => { Promise.resolve( p ).then( f ); }"

///|
extern "js" fn xr_array_includes(array : @core.JsValue, value : String) -> Bool = "(a, v) => a.includes( v )"

///|
extern "js" fn xr_array_unshift(
  array : @core.JsValue,
  value : @core.JsValue,
) -> Unit = "(a, v) => { a.unshift( v ); }"

///|
extern "js" fn xr_array_of(values : Array[@core.JsValue]) -> @core.JsValue = "(a) => Array.from( a )"

///|
extern "js" fn xr_array_length(array : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn xr_array_get(array : @core.JsValue, i : Int32) -> @core.JsValue = "(a, i) => a[ i ]"

///|
extern "js" fn xr_number(value : @core.JsValue) -> Double = "(v) => v"

///|
extern "js" fn xr_layers_with_eyes(mask : Double) -> Double = "(m) => m | 0b110"

///|
extern "js" fn xr_layers_left(mask : Double) -> Double = "(m) => m & ~ 0b100"

///|
extern "js" fn xr_layers_right(mask : Double) -> Double = "(m) => m & ~ 0b010"

///|
extern "js" fn xr_math_atan(x : Double) -> Double = "Math.atan"

///|
extern "js" fn xr_error_text(error : @core.JsValue) -> String = "(e) => `${e.name}: ${e.message}`"

///|
extern "js" fn xr_try(f : () -> Unit) -> @core.JsValue = "(f) => { try { f(); return undefined; } catch ( e ) { return e; } }"

///|
/// A quad or cylinder layer of `createQuadLayer` / `createCylinderLayer`.
pub(all) struct XRLayer {
  type_ : String
  width : Double
  height : Double
  radius : Double
  central_angle : Double
  aspectratio : Double
  translation : @math.Vector3
  quaternion : @math.Quaternion
  pixelwidth : Int32
  pixelheight : Int32
  samples : Int32
  plane : @core.Object3D
  material : @core.Material
  rendercall : () -> Unit
  mut render_target : @core.RenderTarget
  /// The native layer; `None` is unset.
  mut xrlayer : @core.JsValue?
}

///|
priv struct XRCameraSettings {
  camera : @core.Object3D
  fov : Double
  zoom : Double
}

///|
/// The XR state of a renderer.
pub(all) struct XRManager {
  dispatcher : @core.EventDispatcher
  mut enabled : Bool
  mut is_presenting : Bool
  mut camera_auto_update : Bool
  _renderer : Renderer
  _camera_l : @core.Object3D
  _camera_r : @core.Object3D
  _cameras : Array[@core.Object3D]
  _camera_xr : @core.Object3D
  mut _current_depth_near : Double?
  mut _current_depth_far : Double?
  _controllers : Array[@webgl.WebXRController?]
  /// `None` entries are `null` input sources.
  _controller_input_sources : Array[@core.JsValue?]
  mut _xr_render_target : @core.RenderTarget?
  _layers : Array[XRLayer]
  mut _session_uses_layers : Bool
  _supports_gl_binding : Bool
  _supports_webgpu_binding : Bool
  mut _gl : @core.JsValue?
  mut _current_animation_context : @webgl.AnimationFrameProvider?
  mut _current_animation_loop : ((Double, @core.JsValue) -> Unit)?
  mut _current_pixel_ratio : Double?
  _current_size : @math.Vector2
  priv mut _current_camera_settings : XRCameraSettings?
  mut _on_session_event : (@core.JsValue) -> Unit
  mut _on_session_end : (@core.JsValue) -> Unit
  mut _on_input_sources_change : (@core.JsValue) -> Unit
  mut _on_animation_frame : (Double, @core.JsValue) -> Unit
  mut _reference_space : @core.JsValue?
  mut _reference_space_type : String
  mut _custom_reference_space : @core.JsValue?
  mut _framebuffer_scale_factor : Double
  mut _foveation : Double
  mut _session : @core.JsValue?
  mut _gl_base_layer : @core.JsValue?
  mut _gl_binding : @core.JsValue?
  mut _webgpu_binding : @core.JsValue?
  mut _gl_proj_layer : @core.JsValue?
  mut _xr_frame : @core.JsValue?
  _supports_layers : Bool
  _use_multiview_if_possible : Bool
  mut _use_multiview : Bool
}

///|
pub impl @core.EventSource for XRManager with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl @core.EventSource for XRManager with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend XRManager with @core.EventSource::{
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// A perspective camera with a viewport, as the XR eye cameras are created.
fn xr_manager_eye_camera() -> @core.Object3D {
  let camera = @core.PerspectiveCamera::new()
  @webgl.set_camera_viewport(
    camera,
    Some(@math.Vector4::new(0.0, 0.0, 0.0, 0.0)),
  )
  camera.matrix_world_auto_update = false
  camera
}

///|
/// `new XRManager( renderer, multiview = false )`.
pub fn XRManager::new(
  renderer : Renderer,
  multiview~ : Bool = false,
) -> XRManager {
  let camera_l = xr_manager_eye_camera()
  let camera_r = xr_manager_eye_camera()
  let supports_gl_binding = xr_supports_gl_binding()
  let xr : XRManager = {
    dispatcher: @core.EventDispatcher::new(),
    enabled: false,
    is_presenting: false,
    camera_auto_update: true,
    _renderer: renderer,
    _camera_l: camera_l,
    _camera_r: camera_r,
    _cameras: [camera_l, camera_r],
    _camera_xr: @core.ArrayCamera::new(),
    _current_depth_near: None,
    _current_depth_far: None,
    _controllers: [],
    _controller_input_sources: [],
    _xr_render_target: None,
    _layers: [],
    _session_uses_layers: false,
    _supports_gl_binding: supports_gl_binding,
    _supports_webgpu_binding: xr_supports_webgpu_binding(),
    _gl: None,
    _current_animation_context: None,
    _current_animation_loop: None,
    _current_pixel_ratio: None,
    _current_size: @math.Vector2::new(0.0, 0.0),
    _current_camera_settings: None,
    _on_session_event: fn(_) {  },
    _on_session_end: fn(_) {  },
    _on_input_sources_change: fn(_) {  },
    _on_animation_frame: fn(_, _) {  },
    _reference_space: None,
    _reference_space_type: "local-floor",
    _custom_reference_space: None,
    _framebuffer_scale_factor: 1.0,
    _foveation: 1.0,
    _session: None,
    _gl_base_layer: None,
    _gl_binding: None,
    _webgpu_binding: None,
    _gl_proj_layer: None,
    _xr_frame: None,
    _supports_layers: supports_gl_binding && xr_supports_layers(),
    _use_multiview_if_possible: multiview,
    _use_multiview: false,
  }
  xr._on_session_event = fn(event) { xr._handle_session_event(event) }
  xr._on_session_end = fn(_) { xr._handle_session_end() }
  xr._on_input_sources_change = fn(event) {
    xr._handle_input_sources_change(event)
  }
  xr._on_animation_frame = fn(time, frame) {
    xr._handle_animation_frame(time, frame)
  }
  xr
}

///|
/// `getController( index )`: the target ray space.
pub fn XRManager::get_controller(
  self : XRManager,
  index : Int32,
) -> @core.Object3D {
  self._get_controller(index).get_target_ray_space()
}

///|
/// `getControllerGrip( index )`.
pub fn XRManager::get_controller_grip(
  self : XRManager,
  index : Int32,
) -> @core.Object3D {
  self._get_controller(index).get_grip_space()
}

///|
/// `getHand( index )`.
pub fn XRManager::get_hand(self : XRManager, index : Int32) -> @core.Object3D {
  self._get_controller(index).get_hand_space()
}

///|
pub fn XRManager::get_foveation(self : XRManager) -> Double {
  self._foveation
}

///|
pub fn XRManager::set_foveation(self : XRManager, foveation : Double) -> Unit {
  self._foveation = foveation
  match self._gl_proj_layer {
    Some(layer) => layer.set("fixedFoveation", @core.JsValue::of(foveation))
    None => ()
  }
  match self._gl_base_layer {
    Some(layer) if !layer.get("fixedFoveation").is_undefined() =>
      layer.set("fixedFoveation", @core.JsValue::of(foveation))
    _ => ()
  }
}

///|
pub fn XRManager::get_framebuffer_scale_factor(self : XRManager) -> Double {
  self._framebuffer_scale_factor
}

///|
pub fn XRManager::set_framebuffer_scale_factor(
  self : XRManager,
  factor : Double,
) -> Unit {
  self._framebuffer_scale_factor = factor
  if self.is_presenting == true {
    @core.warn("XRManager: Cannot change framebuffer scale while presenting.")
  }
}

///|
pub fn XRManager::get_reference_space_type(self : XRManager) -> String {
  self._reference_space_type
}

///|
pub fn XRManager::set_reference_space_type(
  self : XRManager,
  type_ : String,
) -> Unit {
  self._reference_space_type = type_
  if self.is_presenting == true {
    @core.warn(
      "XRManager: Cannot change reference space type while presenting.",
    )
  }
}

///|
/// `getReferenceSpace()`: the custom one, else the session's.
pub fn XRManager::get_reference_space(self : XRManager) -> @core.JsValue? {
  match self._custom_reference_space {
    Some(s) => Some(s)
    None => self._reference_space
  }
}

///|
pub fn XRManager::set_reference_space(
  self : XRManager,
  space : @core.JsValue?,
) -> Unit {
  self._custom_reference_space = space
}

///|
/// `getCamera()`: the `ArrayCamera` of the views.
pub fn XRManager::get_camera(self : XRManager) -> @core.Object3D {
  self._camera_xr
}

///|
/// `getEnvironmentBlendMode()`; `None` without a session.
pub fn XRManager::get_environment_blend_mode(self : XRManager) -> String? {
  match self._session {
    Some(session) => {
      let mode = session.get("environmentBlendMode")
      if mode.is_undefined() {
        None
      } else {
        Some(mode.cast())
      }
    }
    None => None
  }
}

///|
/// `getBaseLayer()`.
pub fn XRManager::get_base_layer(self : XRManager) -> @core.JsValue? {
  match self._gl_proj_layer {
    Some(l) => Some(l)
    None => self._gl_base_layer
  }
}

///|
/// `getBinding()`: the `XRWebGLBinding`, created on first use.
pub fn XRManager::get_binding(self : XRManager) -> @core.JsValue? {
  if self._gl_binding is None && self._supports_gl_binding {
    self._gl_binding = Some(
      xr_new_gl_binding(
        self._session.unwrap_or(@core.JsValue::null()),
        self._gl.unwrap_or(@core.JsValue::null()),
      ),
    )
  }
  self._gl_binding
}

///|
/// `foveateBoundTexture( renderTarget )`: applies the foveation to an XR
/// post-processing texture (WebGL with projection layers).
pub fn XRManager::foveate_bound_texture(
  self : XRManager,
  render_target : @core.RenderTarget?,
) -> Unit {
  guard render_target is Some(render_target) else { return }
  if render_target_props(render_target).is_post_processing_render_target !=
    Some(true) {
    return
  }
  if self.is_presenting != true {
    return
  }
  if self._gl_proj_layer is None {
    return
  }
  let backend = self._renderer.backend
  if !backend.has_flag("isWebGLBackend") {
    return
  }
  if !backend.class_.has_state(backend) {
    return
  }
  match self._renderer.get_output_render_target() {
    Some(o) if is_xr_render_target(o) => ()
    _ => return
  }
  let gl_binding = match self.get_binding() {
    Some(b) if xr_has_function(b, "foveateBoundTexture") => b
    _ => return
  }
  self._renderer._textures().update_render_target(render_target)
  let data = backend.get(@core.JsValue::of(render_target.texture()))
  let texture_gpu = data.get("textureGPU")
  let gl_texture_type = data.get("glTextureType")
  if texture_gpu.is_undefined() || gl_texture_type.is_undefined() {
    return
  }
  let props = render_target_props(render_target)
  match props._xr_foveation_texture_gpu {
    Some(t) if t.strict_equal(texture_gpu) => return
    _ => ()
  }
  props._xr_foveation_texture_gpu = Some(texture_gpu)
  backend.class_.state_bind_texture(
    backend,
    gl_texture_type.cast(),
    texture_gpu,
  )
  let error = xr_try(fn() {
    xr_call2(
      gl_binding,
      "foveateBoundTexture",
      gl_texture_type,
      @core.JsValue::of(self.get_foveation()),
    )
    |> ignore
  })
  if !error.is_undefined() {
    @core.warn_once(
      "XRManager: Unable to foveate bound XR post-processing texture. " +
      xr_error_text(error),
    )
  }
  backend.class_.state_unbind_texture(backend)
}

///|
/// `getWebGPUBinding()`: the `XRGPUBinding`, created on first use.
pub fn XRManager::get_webgpu_binding(self : XRManager) -> @core.JsValue? {
  if self._webgpu_binding is None && self._supports_webgpu_binding {
    self._webgpu_binding = Some(
      xr_new_gpu_binding(
        self._session.unwrap_or(@core.JsValue::null()),
        self._renderer.backend.device(),
      ),
    )
  }
  self._webgpu_binding
}

///|
fn XRManager::_is_webgpu_session(self : XRManager) -> Bool {
  self._renderer.backend.has_flag("isWebGPUBackend") &&
  (match self._session {
    Some(session) => xr_array_includes(session.get("enabledFeatures"), "webgpu")
    None => false
  })
}

///|
fn XRManager::_validate_webgpu_session(self : XRManager) -> Unit {
  if !self._renderer.backend.has_flag("isWebGPUBackend") {
    return
  }
  let session = self._session.unwrap()
  if xr_array_includes(session.get("enabledFeatures"), "webgpu") == false {
    abort(
      "THREE.XRManager: WebGPU XR sessions require the \"webgpu\" session feature. Use VRButtonGPU/XRButton with \"webgpu\" enabled or use a WebGL backend.",
    )
  }
}

///|
fn XRManager::_init_webgpu_session(
  self : XRManager,
  session : @core.JsValue,
  on_done : () -> Unit,
) -> Unit {
  let webgpu_binding = self.get_webgpu_binding().unwrap()
  let init = @core.JsValue::object()
  init.set("colorFormat", xr_call0(webgpu_binding, "getPreferredColorFormat"))
  let gl_proj_layer = xr_call1(webgpu_binding, "createProjectionLayer", init)
  self._gl_proj_layer = Some(gl_proj_layer)
  let state = @core.JsValue::object()
  state.set("layers", xr_array_of([gl_proj_layer]))
  xr_call1(session, "updateRenderState", state) |> ignore
  xr_then(
    xr_call1(
      session,
      "requestReferenceSpace",
      @core.JsValue::of(self.get_reference_space_type()),
    ),
    fn(space) {
      self._reference_space = Some(space)
      let target = @core.RenderTarget::new(
        width=xr_number(gl_proj_layer.get("textureWidth")).to_int(),
        height=xr_number(gl_proj_layer.get("textureHeight")).to_int(),
        depth=2,
        min_filter=@core.LinearFilter,
        mag_filter=@core.LinearFilter,
        depth_buffer=true,
        multiview=false,
        use_array_depth_texture=true,
        store_multisampled_color_buffer=false,
        store_multisampled_depth_buffer=false,
        store_multisampled_stencil_buffer=false,
        samples=self._renderer.samples(),
      )
      target.texture().is_array_texture = true
      self._xr_render_target = Some(target)
      if self._use_multiview_if_possible == true {
        @core.warn_once(
          "THREE.XRManager: WebGPU XR does not support multiview yet. Disabling multiview for this XR session.",
        )
      }
      self._use_multiview = false
      on_done()
    },
  )
}

///|
fn XRManager::_dispose_webgpu_session(self : XRManager) -> Unit {
  let renderer = self._renderer
  let backend = renderer.backend
  guard self._xr_render_target is Some(xr_render_target) else { return }
  if !backend.has_flag("isWebGPUBackend") {
    return
  }
  match renderer._render_contexts {
    Some(c) => c.dispose()
    None => ()
  }
  xr_render_target.dispose()
  // The external texture can be registered before the render target is initialized.
  for texture in xr_render_target.textures {
    if backend.has(@core.JsValue::of(texture)) {
      backend.destroy_texture(texture)
    }
  }
  backend.delete(@core.JsValue::of(xr_render_target))
}

///|
/// The views' WebGPU sub-images: `{ colorTexture, viewDescriptors, viewports }`.
priv struct XRWebGPUViewData {
  mut color_texture : @core.JsValue?
  view_descriptors : Array[@core.JsValue]
  viewports : Array[@core.JsValue]
}

///|
fn XRManager::_get_webgpu_view_data(
  self : XRManager,
  views : @core.JsValue,
) -> XRWebGPUViewData {
  let webgpu_binding = self.get_webgpu_binding().unwrap()
  let view_data = { color_texture: None, view_descriptors: [], viewports: [], }
  for i in 0..<xr_array_length(views) {
    let gpu_sub_image = xr_call2(
      webgpu_binding,
      "getViewSubImage",
      self._gl_proj_layer.unwrap(),
      xr_array_get(views, i),
    )
    if view_data.color_texture is None {
      view_data.color_texture = Some(gpu_sub_image.get("colorTexture"))
    }
    view_data.viewports.push(gpu_sub_image.get("viewport"))
    if xr_has_function(gpu_sub_image, "getViewDescriptor") {
      view_data.view_descriptors.push(
        xr_call0(gpu_sub_image, "getViewDescriptor"),
      )
    }
  }
  view_data
}

///|
pub fn XRManager::get_frame(self : XRManager) -> @core.JsValue? {
  self._xr_frame
}

///|
pub fn XRManager::use_multiview(self : XRManager) -> Bool {
  self._use_multiview
}

///|
/// The layer render target of `createQuadLayer` / `createCylinderLayer`.
fn xr_manager_layer_render_target(
  pixelwidth : Int32,
  pixelheight : Int32,
  stencil : Bool?,
  samples : Int32,
) -> @core.RenderTarget {
  let stencil_ = stencil == Some(true)
  XRRenderTarget::new(
    width=pixelwidth,
    height=pixelheight,
    format=@core.RGBAFormat,
    type_=@core.UnsignedByteType,
    depth_texture=@core.DepthTexture::new(
      width=pixelwidth,
      height=pixelheight,
      type_=if stencil_ {
        @core.UnsignedInt248Type
      } else {
        @core.UnsignedIntType
      },
      format=if stencil_ { @core.DepthStencilFormat } else { @core.DepthFormat },
    ),
    stencil_buffer?=stencil,
    samples~,
    resolve_depth_buffer=false,
    resolve_stencil_buffer=false,
    store_multisampled_color_buffer=false,
    store_multisampled_depth_buffer=false,
    store_multisampled_stencil_buffer=false,
  )
}

///|
/// The material that punches a hole for a native layer.
fn xr_manager_hole_material(side : Int32) -> @core.Material {
  let material = @core.MeshBasicMaterial::new()
  match material.color {
    Some(c) => c.set_hex(0xffffff) |> ignore
    None => ()
  }
  material.side = side
  material.blending = @core.CustomBlending
  material.blend_equation = @core.AddEquation
  material.blend_src = @core.ZeroFactor
  material.blend_dst = @core.ZeroFactor
  material
}

///|
/// The emulated layer's material: the render target texture, flipped.
fn xr_manager_layer_material(
  side : Int32,
  render_target : @core.RenderTarget,
) -> @core.Material {
  let material = @core.MeshBasicMaterial::new()
  match material.color {
    Some(c) => c.set_hex(0xffffff) |> ignore
    None => ()
  }
  material.side = side
  material.map = Some(render_target.texture())
  render_target.texture().offset.y = 1.0
  render_target.texture().repeat.y = -1.0
  material
}

///|
fn XRManager::_add_layer(
  self : XRManager,
  layer : XRLayer,
  side : Int32,
) -> Unit {
  self._layers.push(layer)
  match self._session {
    Some(session) => {
      xr_manager_set_plane_material(
        layer.plane,
        Single(xr_manager_hole_material(side)),
      )
      let xrlayer = self._create_xr_layer(layer)
      layer.xrlayer = Some(xrlayer)
      let xrlayers = session.get("renderState").get("layers")
      xr_array_unshift(xrlayers, xrlayer)
      let state = @core.JsValue::object()
      state.set("layers", xrlayers)
      xr_call1(session, "updateRenderState", state) |> ignore
    }
    None =>
      render_target_props(layer.render_target).is_xr_render_target = Some(false)
  }
}

///|
/// `createQuadLayer( width, height, translation, quaternion, pixelwidth, pixelheight,
/// rendercall, attributes = {} )`: a plane showing what `rendercall` renders.
pub fn XRManager::create_quad_layer(
  self : XRManager,
  width : Double,
  height : Double,
  translation : @math.Vector3,
  quaternion : @math.Quaternion,
  pixelwidth : Int32,
  pixelheight : Int32,
  rendercall : () -> Unit,
  stencil? : Bool,
  samples? : Int32,
) -> @core.Object3D {
  let geometry = @geometries.PlaneGeometry::new(width~, height~)
  let render_target = xr_manager_layer_render_target(
    pixelwidth,
    pixelheight,
    stencil,
    samples.unwrap_or(self._renderer.samples()),
  )
  let material = xr_manager_layer_material(@core.FrontSide, render_target)
  let plane = @core.Mesh::new(geometry~, material=Single(material))
  plane.position.copy(translation) |> ignore
  plane.quaternion.copy(quaternion) |> ignore
  let layer = {
    type_: "quad",
    width,
    height,
    radius: 0.0,
    central_angle: 0.0,
    aspectratio: 0.0,
    translation,
    quaternion,
    pixelwidth,
    pixelheight,
    samples: render_target.samples,
    plane,
    material,
    rendercall,
    render_target,
    xrlayer: None,
  }
  self._add_layer(layer, @core.FrontSide)
  plane
}

///|
/// `createCylinderLayer( radius, centralAngle, aspectratio, translation, quaternion,
/// pixelwidth, pixelheight, rendercall, attributes = {} )`.
pub fn XRManager::create_cylinder_layer(
  self : XRManager,
  radius : Double,
  central_angle : Double,
  aspectratio : Double,
  translation : @math.Vector3,
  quaternion : @math.Quaternion,
  pixelwidth : Int32,
  pixelheight : Int32,
  rendercall : () -> Unit,
  stencil? : Bool,
  samples? : Int32,
) -> @core.Object3D {
  let geometry = @geometries.CylinderGeometry::new(
    radius_top=radius,
    radius_bottom=radius,
    height=radius * central_angle / aspectratio,
    radial_segments=64.0,
    height_segments=64.0,
    open_ended=true,
    theta_start=3.141592653589793 - central_angle / 2.0,
    theta_length=central_angle,
  )
  let render_target = xr_manager_layer_render_target(
    pixelwidth,
    pixelheight,
    stencil,
    samples.unwrap_or(self._renderer.samples()),
  )
  let material = xr_manager_layer_material(@core.BackSide, render_target)
  let plane = @core.Mesh::new(geometry~, material=Single(material))
  plane.position.copy(translation) |> ignore
  plane.quaternion.copy(quaternion) |> ignore
  let layer = {
    type_: "cylinder",
    width: 0.0,
    height: 0.0,
    radius,
    central_angle,
    aspectratio,
    translation,
    quaternion,
    pixelwidth,
    pixelheight,
    samples: render_target.samples,
    plane,
    material,
    rendercall,
    render_target,
    xrlayer: None,
  }
  self._add_layer(layer, @core.BackSide)
  plane
}

///|
/// `renderLayers()`: renders each layer into its render target.
pub fn XRManager::render_layers(self : XRManager) -> Unit {
  let translation_object = @math.Vector3::new(0.0, 0.0, 0.0)
  let quaternion_object = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0)
  let renderer = self._renderer
  let was_presenting = self.is_presenting
  self.is_presenting = false
  let renderer_size = @math.Vector2::new(0.0, 0.0)
  renderer.get_size(renderer_size) |> ignore
  let current_render_target = renderer.get_render_target()
  for layer in self._layers {
    let props = render_target_props(layer.render_target)
    props.is_xr_render_target = Some(self._session is Some(_))
    props._has_external_textures = props.is_xr_render_target
    let current_context_node = renderer.context_node
    let context_node = if is_xr_render_target(layer.render_target) &&
      self._session_uses_layers {
      let xrlayer = layer.xrlayer.unwrap()
      xrlayer.set(
        "transform",
        xr_new_rigid_transform(
          layer.plane.get_world_position(translation_object),
          layer.plane.get_world_quaternion(quaternion_object),
        ),
      )
      let gl_sub_image = xr_call2(
        self._gl_binding.unwrap(),
        "getSubImage",
        xrlayer,
        self._xr_frame.unwrap_or(@core.JsValue::null()),
      )
      renderer.backend.set_xr_render_target_textures(
        layer.render_target,
        gl_sub_image.get("colorTexture"),
        @core.JsValue::undefined(),
      )
      renderer._set_xr_layer_size(
        layer.render_target.width.to_double(),
        layer.render_target.height.to_double(),
      )
      let key = @core.JsValue::of(current_context_node)
      match _xr_manager_context_node_lib.get(key) {
        Some(c) => c
        None => {
          // Apply ToneMapping and OutputColorSpace directly in the material shader
          let value = node_context([
            (
              "getOutput",
              Other(
                @core.JsValue::of(ContextGetOutput::{
                  f: fn(output_node, builder) {
                    let render_output_node = render_output(
                      output_node,
                      tone_mapping=renderer.tone_mapping,
                      output_color_space=renderer.output_color_space,
                    )
                    RenderOutputNode::of(render_output_node).unwrap().premultiplied_alpha
                    = builder.material.unwrap().premultiplied_alpha
                    render_output_node
                  },
                }),
              ),
            ),
          ])
          for
            k, v in ContextNode::get_flow_context_data(current_context_node).values {
            value.set(k, v)
          }
          let c = context(value~)
          _xr_manager_context_node_lib.set(key, c)
          c
        }
      }
    } else {
      current_context_node
    }
    renderer.context_node = context_node
    renderer.set_render_target(Some(layer.render_target))
    (layer.rendercall)()
    renderer.context_node = current_context_node
  }
  renderer.set_render_target(current_render_target)
  renderer._set_xr_layer_size(renderer_size.x, renderer_size.y)
  self.is_presenting = was_presenting
}

///|
pub fn XRManager::get_session(self : XRManager) -> @core.JsValue? {
  self._session
}

///|
/// `async setSession( session )`: starts presenting (`None` is `null`); calls back
/// when the session is set up.
pub fn XRManager::set_session(
  self : XRManager,
  session : @core.JsValue?,
  on_done~ : () -> Unit = fn() {  },
) -> Unit {
  let renderer = self._renderer
  fn start() -> Unit {
    self._gl = Some(renderer.get_context())
    let gl = self._gl.unwrap()
    self._session = session
    guard session is Some(session) else { return on_done() }
    for
      type_ in [
        "select", "selectstart", "selectend", "squeeze", "squeezestart", "squeezeend",
      ] {
      xr_session(session).add_event_listener(type_, self._on_session_event)
    }
    xr_session(session).add_event_listener("end", self._on_session_end)
    xr_session(session).add_event_listener(
      "inputsourceschange",
      self._on_input_sources_change,
    )
    self._validate_webgpu_session()
    self._current_pixel_ratio = Some(renderer.get_pixel_ratio())
    renderer.get_size(self._current_size) |> ignore
    let animation = renderer._animation()
    self._current_animation_context = animation.get_context()
    self._current_animation_loop = animation.get_animation_loop()
    animation.stop()
    fn finish() -> Unit {
      animation.set_animation_loop(Some(self._on_animation_frame))
      animation.set_context(
        Some(xr_session(session).as_animation_frame_provider()),
      )
      animation.start()
      self.is_presenting = true
      self.dispatch_event(@core.Event::new("sessionstart"))
      on_done()
    }

    if self._is_webgpu_session() {
      self._init_webgpu_session(session, finish)
    } else if self._supports_layers == true {
      // default path using XRProjectionLayer
      let attributes = xr_call0(gl, "getContextAttributes")
      renderer.backend.make_xr_compatible(fn() {
        self.set_foveation(self.get_foveation())
        let mut depth_format : Int32? = None
        let mut depth_type : Int32? = None
        let mut gl_depth_format = @core.JsValue::null()
        if renderer.depth {
          gl_depth_format = if renderer.stencil {
            gl.get("DEPTH24_STENCIL8")
          } else {
            gl.get("DEPTH_COMPONENT24")
          }
          depth_format = Some(
            if renderer.stencil {
              @core.DepthStencilFormat
            } else {
              @core.DepthFormat
            },
          )
          depth_type = Some(
            if renderer.stencil {
              @core.UnsignedInt248Type
            } else {
              @core.UnsignedIntType
            },
          )
        }
        let projectionlayer_init = @core.JsValue::object()
        projectionlayer_init.set("colorFormat", gl.get("RGBA8"))
        projectionlayer_init.set("depthFormat", gl_depth_format)
        projectionlayer_init.set(
          "scaleFactor",
          @core.JsValue::of(self._framebuffer_scale_factor),
        )
        projectionlayer_init.set("clearOnAccess", @core.JsValue::of(false))
        if self._use_multiview_if_possible &&
          renderer.has_feature("OVR_multiview2") {
          projectionlayer_init.set(
            "textureType",
            @core.JsValue::of("texture-array"),
          )
          self._use_multiview = true
        }
        self._gl_binding = self.get_binding()
        let gl_proj_layer = xr_call1(
          self._gl_binding.unwrap(),
          "createProjectionLayer",
          projectionlayer_init,
        )
        let layers_array : Array[@core.JsValue] = [gl_proj_layer]
        self._gl_proj_layer = Some(gl_proj_layer)
        renderer.set_pixel_ratio(1.0)
        let texture_width = xr_number(gl_proj_layer.get("textureWidth"))
        let texture_height = xr_number(gl_proj_layer.get("textureHeight"))
        renderer._set_xr_layer_size(texture_width, texture_height)
        let depth = if self._use_multiview { 2 } else { 1 }
        let depth_texture = @core.DepthTexture::new(
          width=texture_width.to_int(),
          height=texture_height.to_int(),
          type_?=depth_type,
          format?=depth_format,
          depth~,
        )
        let keeps_depth = gl_proj_layer
          .get("ignoreDepthValues")
          .strict_equal(@core.JsValue::of(false))
        let antialias = attributes
          .get("antialias")
          .strict_equal(@core.JsValue::of(true))
        let target = XRRenderTarget::new(
          width=texture_width.to_int(),
          height=texture_height.to_int(),
          format=@core.RGBAFormat,
          type_=@core.UnsignedByteType,
          color_space=renderer.output_color_space,
          depth_texture~,
          stencil_buffer=renderer.stencil,
          samples=if antialias { 4 } else { 0 },
          resolve_depth_buffer=keeps_depth,
          resolve_stencil_buffer=keeps_depth,
          store_multisampled_color_buffer=false,
          store_multisampled_depth_buffer=keeps_depth,
          store_multisampled_stencil_buffer=keeps_depth,
          depth~,
          multiview=self._use_multiview,
        )
        render_target_props(target)._has_external_textures = Some(true)
        target.depth = depth
        self._xr_render_target = Some(target)
        self._session_uses_layers = xr_array_includes(
          session.get("enabledFeatures"),
          "layers",
        )
        xr_then(
          xr_call1(
            session,
            "requestReferenceSpace",
            @core.JsValue::of(self.get_reference_space_type()),
          ),
          fn(space) {
            self._reference_space = Some(space)
            if self._session_uses_layers {
              // switch layers to native
              for layer in self._layers {
                // change material so it "punches" out a hole to show the XR Layer.
                xr_manager_set_plane_material(
                  layer.plane,
                  Single(
                    xr_manager_hole_material(
                      if layer.type_ == "cylinder" {
                        @core.BackSide
                      } else {
                        @core.FrontSide
                      },
                    ),
                  ),
                )
                let xrlayer = self._create_xr_layer(layer)
                layer.xrlayer = Some(xrlayer)
                layers_array.insert(0, xrlayer)
              }
            }
            let state = @core.JsValue::object()
            state.set("layers", xr_array_of(layers_array))
            xr_call1(session, "updateRenderState", state) |> ignore
            finish()
          },
        )
      })
    } else {
      // fallback to XRWebGLLayer
      renderer.backend.make_xr_compatible(fn() {
        self.set_foveation(self.get_foveation())
        let layer_init = @core.JsValue::object()
        layer_init.set(
          "antialias",
          @core.JsValue::of(renderer.current_samples() > 0),
        )
        layer_init.set("alpha", @core.JsValue::of(true))
        layer_init.set("depth", @core.JsValue::of(renderer.depth))
        layer_init.set("stencil", @core.JsValue::of(renderer.stencil))
        layer_init.set(
          "framebufferScaleFactor",
          @core.JsValue::of(self.get_framebuffer_scale_factor()),
        )
        let gl_base_layer = xr_new_webgl_layer(session, gl, layer_init)
        self._gl_base_layer = Some(gl_base_layer)
        let state = @core.JsValue::object()
        state.set("baseLayer", gl_base_layer)
        xr_call1(session, "updateRenderState", state) |> ignore
        renderer.set_pixel_ratio(1.0)
        let width = xr_number(gl_base_layer.get("framebufferWidth"))
        let height = xr_number(gl_base_layer.get("framebufferHeight"))
        renderer._set_xr_layer_size(width, height)
        let target = XRRenderTarget::new(
          width=width.to_int(),
          height=height.to_int(),
          format=@core.RGBAFormat,
          type_=@core.UnsignedByteType,
          color_space=renderer.output_color_space,
          stencil_buffer=renderer.stencil,
        )
        render_target_props(target)._is_opaque_framebuffer = Some(true)
        self._xr_render_target = Some(target)
        xr_then(
          xr_call1(
            session,
            "requestReferenceSpace",
            @core.JsValue::of(self.get_reference_space_type()),
          ),
          fn(space) {
            self._reference_space = Some(space)
            finish()
          },
        )
      })
    }
  }

  if renderer.initialized() == false {
    renderer.init(on_done=fn(_) { start() })
  } else {
    start()
  }
}

///|
/// `updateCamera( camera )`: moves the XR cameras and `camera` to the viewer pose.
pub fn XRManager::update_camera(
  self : XRManager,
  camera : @core.Object3D,
) -> Unit {
  guard self._session is Some(session) else { return }
  let depth_near = xr_manager_camera_near(camera)
  let depth_far = xr_manager_camera_far(camera)
  let camera_xr = self._camera_xr
  let camera_l = self._camera_l
  let camera_r = self._camera_r
  for c in [camera_xr, camera_r, camera_l] {
    let p = c.as_perspective_camera()
    p.near = depth_near
    p.far = depth_far
  }
  xr_manager_array_camera(camera_xr).is_multi_view_camera = self._use_multiview
  if self._current_depth_near != Some(depth_near) ||
    self._current_depth_far != Some(depth_far) {
    // Note that the new renderState won't apply until the next frame. See #18320
    let state = @core.JsValue::object()
    state.set("depthNear", @core.JsValue::of(depth_near))
    state.set("depthFar", @core.JsValue::of(depth_far))
    xr_call1(session, "updateRenderState", state) |> ignore
    self._current_depth_near = Some(depth_near)
    self._current_depth_far = Some(depth_far)
  }
  // inherit camera layers and enable eye layers (1 = left, 2 = right)
  camera_xr.layers.mask = xr_layers_with_eyes(camera.layers.mask)
  camera_l.layers.mask = xr_layers_left(camera_xr.layers.mask)
  camera_r.layers.mask = xr_layers_right(camera_xr.layers.mask)
  let parent = camera.parent
  let cameras = xr_manager_array_camera(camera_xr).cameras
  xr_manager_update_camera(camera_xr, parent)
  for i in 0..<cameras.length() {
    xr_manager_update_camera(cameras[i], parent)
  }
  camera_xr.as_camera().projection_matrix.copy(camera_l.projection_matrix())
  |> ignore
  camera_xr.as_camera().projection_matrix_inverse.copy(
    camera_l.projection_matrix_inverse(),
  )
  |> ignore
  // update user camera and its children
  if self._current_camera_settings is None && camera.is_perspective_camera() {
    let p = camera.as_perspective_camera()
    self._current_camera_settings = Some({ camera, fov: p.fov, zoom: p.zoom, })
  }
  xr_manager_update_user_camera(camera, camera_xr, parent)
}

///|
fn XRManager::_get_controller(
  self : XRManager,
  index : Int32,
) -> @webgl.WebXRController {
  match self._controllers.get(index) {
    Some(Some(controller)) => controller
    _ => {
      let controller = @webgl.WebXRController::new()
      while self._controllers.length() <= index {
        self._controllers.push(None)
      }
      self._controllers[index] = Some(controller)
      controller
    }
  }
}

///|
/// The `ArrayCamera` payload of `cameraXR`.
fn xr_manager_array_camera(camera : @core.Object3D) -> @core.ArrayCamera {
  match camera.kind {
    Camera({ kind: PerspectiveCamera({ array_camera: Some(array), .. }), .. }) =>
      array
    _ => abort("XRManager: not an ArrayCamera")
  }
}

///|
/// `camera.near`.
fn xr_manager_camera_near(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.near
    OrthographicCamera(c) => c.near
    BaseCamera => xr_nan()
  }
}

///|
/// `camera.far`.
fn xr_manager_camera_far(camera : @core.Object3D) -> Double {
  match camera.as_camera().kind {
    PerspectiveCamera(c) => c.far
    OrthographicCamera(c) => c.far
    BaseCamera => xr_nan()
  }
}

///|
/// `updateCamera( camera, parent )`.
fn xr_manager_update_camera(
  camera : @core.Object3D,
  parent : @core.Object3D?,
) -> Unit {
  match parent {
    None => camera.matrix_world.copy(camera.matrix) |> ignore
    Some(parent) =>
      camera.matrix_world.multiply_matrices(parent.matrix_world, camera.matrix)
      |> ignore
  }
  camera.as_camera().matrix_world_inverse.copy(camera.matrix_world).invert()
  |> ignore
}

///|
/// `updateUserCamera( camera, cameraXR, parent )`.
fn xr_manager_update_user_camera(
  camera : @core.Object3D,
  camera_xr : @core.Object3D,
  parent : @core.Object3D?,
) -> Unit {
  match parent {
    None => camera.matrix.copy(camera_xr.matrix_world) |> ignore
    Some(parent) => {
      camera.matrix.copy(parent.matrix_world) |> ignore
      camera.matrix.invert() |> ignore
      camera.matrix.multiply(camera_xr.matrix_world) |> ignore
    }
  }
  camera.matrix.decompose(camera.position, camera.quaternion, camera.scale)
  |> ignore
  camera.update_matrix_world(force=true)
  camera.as_camera().projection_matrix.copy(camera_xr.projection_matrix())
  |> ignore
  camera.as_camera().projection_matrix_inverse.copy(
    camera_xr.projection_matrix_inverse(),
  )
  |> ignore
  if camera.is_perspective_camera() {
    let p = camera.as_perspective_camera()
    p.fov = @math.RAD2DEG *
      2.0 *
      xr_math_atan(1.0 / camera.projection_matrix().elements[5])
    p.zoom = 1.0
  }
}

///|
/// The index of an input source in `_controllerInputSources`, or -1.
fn XRManager::_input_source_index(
  self : XRManager,
  input_source : @core.JsValue,
) -> Int32 {
  for i, s in self._controller_input_sources {
    match s {
      Some(s) if s.strict_equal(input_source) => return i
      _ => ()
    }
  }
  -1
}

///|
/// `onSessionEvent( event )`.
fn XRManager::_handle_session_event(
  self : XRManager,
  event : @core.JsValue,
) -> Unit {
  let input_source = event.get("inputSource")
  let controller_index = self._input_source_index(input_source)
  if controller_index == -1 {
    return
  }
  match self._controllers.get(controller_index) {
    Some(Some(controller)) => {
      let reference_space = self.get_reference_space()
      controller.update(
        Some(input_source.cast()),
        event.get("frame").cast(),
        reference_space.map(fn(s) { s.cast() }),
      )
      |> ignore
      controller.dispatch_event(
        @core.Event::new(event.get("type").cast(), data=input_source),
      )
      |> ignore
    }
    _ => ()
  }
}

///|
/// `onSessionEnd()`: restores the renderer when the session ends.
fn XRManager::_handle_session_end(self : XRManager) -> Unit {
  let session = xr_session(self._session.unwrap())
  let renderer = self._renderer
  for
    type_ in [
      "select", "selectstart", "selectend", "squeeze", "squeezestart", "squeezeend",
    ] {
    session.remove_event_listener(type_, self._on_session_event)
  }
  session.remove_event_listener("end", self._on_session_end)
  session.remove_event_listener(
    "inputsourceschange",
    self._on_input_sources_change,
  )
  for i in 0..<self._controllers.length() {
    let input_source = match self._controller_input_sources.get(i) {
      Some(Some(s)) => s
      Some(None) => continue
      // `undefined` is not `null`: upstream goes on and disconnects
      None => @core.JsValue::undefined()
    }
    if i < self._controller_input_sources.length() {
      self._controller_input_sources[i] = None
    }
    match self._controllers[i] {
      Some(c) =>
        c.disconnect(
          if input_source.is_undefined() {
            None
          } else {
            Some(input_source.cast())
          },
        )
        |> ignore
      None => ()
    }
  }
  self._current_depth_near = None
  self._current_depth_far = None
  // restore framebuffer/rendering state
  renderer._reset_xr_state()
  self._dispose_webgpu_session()
  self._session = None
  self._xr_render_target = None
  self._gl_binding = None
  self._webgpu_binding = None
  self._gl_base_layer = None
  self._gl_proj_layer = None
  // switch layers back to emulated
  if self._session_uses_layers == true {
    for layer in self._layers {
      // Recreate layer render target to reset state (upstream reads the undefined
      // `layer.stencilBuffer`)
      layer.render_target = xr_manager_layer_render_target(
        layer.pixelwidth,
        layer.pixelheight,
        None,
        layer.samples,
      )
      render_target_props(layer.render_target).is_xr_render_target = Some(false)
      xr_manager_set_plane_material(layer.plane, Single(layer.material))
      layer.material.map = Some(layer.render_target.texture())
      layer.render_target.texture().offset.y = 1.0
      layer.render_target.texture().repeat.y = -1.0
      layer.xrlayer = None
    }
  }
  //
  self.is_presenting = false
  self._use_multiview = false
  let animation = renderer._animation()
  animation.stop()
  animation.set_animation_loop(self._current_animation_loop)
  animation.set_context(self._current_animation_context)
  animation.start()
  renderer.set_pixel_ratio(self._current_pixel_ratio.unwrap_or(1.0))
  renderer.set_size(
    self._current_size.x,
    self._current_size.y,
    update_style=false,
  )
  match self._current_camera_settings {
    Some(settings) => {
      let p = settings.camera.as_perspective_camera()
      p.fov = settings.fov
      p.zoom = settings.zoom
      settings.camera.update_projection_matrix()
      self._current_camera_settings = None
    }
    None => ()
  }
  self.dispatch_event(@core.Event::new("sessionend"))
}

///|
/// `onInputSourcesChange( event )`.
fn XRManager::_handle_input_sources_change(
  self : XRManager,
  event : @core.JsValue,
) -> Unit {
  let controllers = self._controllers
  let controller_input_sources = self._controller_input_sources
  // Notify disconnected
  let removed = event.get("removed")
  for i in 0..<xr_array_length(removed) {
    let input_source = xr_array_get(removed, i)
    let index = self._input_source_index(input_source)
    if index >= 0 {
      controller_input_sources[index] = None
      match controllers.get(index) {
        Some(Some(c)) => c.disconnect(Some(input_source.cast())) |> ignore
        _ => ()
      }
    }
  }
  // Notify connected
  let added = event.get("added")
  for i in 0..<xr_array_length(added) {
    let input_source = xr_array_get(added, i)
    let mut controller_index = self._input_source_index(input_source)
    if controller_index == -1 {
      // Assign input source a controller that currently has no input source
      for j in 0..<controllers.length() {
        if j >= controller_input_sources.length() {
          controller_input_sources.push(Some(input_source))
          controller_index = j
          break
        } else if controller_input_sources[j] is None {
          controller_input_sources[j] = Some(input_source)
          controller_index = j
          break
        }
      }
      // If all controllers do currently receive input we ignore new ones
      if controller_index == -1 {
        break
      }
    }
    match controllers.get(controller_index) {
      Some(Some(controller)) =>
        controller.connect(input_source.cast()) |> ignore
      _ => ()
    }
  }
}

///|
/// `createXRLayer( layer )`: the native quad or cylinder layer.
fn XRManager::_create_xr_layer(
  self : XRManager,
  layer : XRLayer,
) -> @core.JsValue {
  let init = @core.JsValue::object()
  init.set(
    "transform",
    xr_new_rigid_transform(layer.translation, layer.quaternion),
  )
  if layer.type_ == "quad" {
    init.set("width", @core.JsValue::of(layer.width / 2.0))
    init.set("height", @core.JsValue::of(layer.height / 2.0))
  } else {
    init.set("radius", @core.JsValue::of(layer.radius))
    init.set("centralAngle", @core.JsValue::of(layer.central_angle))
    // upstream reads `layer.aspectRatio`, which the layer does not have
    init.set("aspectRatio", @core.JsValue::undefined())
  }
  init.set("space", self._reference_space.unwrap_or(@core.JsValue::null()))
  init.set("viewPixelWidth", @core.JsValue::of(layer.pixelwidth))
  init.set("viewPixelHeight", @core.JsValue::of(layer.pixelheight))
  init.set("clearOnAccess", @core.JsValue::of(false))
  xr_call1(
    self._gl_binding.unwrap(),
    if layer.type_ == "quad" {
      "createQuadLayer"
    } else {
      "createCylinderLayer"
    },
    init,
  )
}

///|
/// `onAnimationFrame( time, frame )`: the XR animation loop.
fn XRManager::_handle_animation_frame(
  self : XRManager,
  time : Double,
  frame : @core.JsValue,
) -> Unit {
  if frame.is_undefined() {
    return
  }
  let camera_xr = self._camera_xr
  let renderer = self._renderer
  let backend = renderer.backend
  let gl_base_layer = self._gl_base_layer
  let reference_space = self.get_reference_space()
  let pose = xr_call1(
    frame,
    "getViewerPose",
    reference_space.unwrap_or(@core.JsValue::null()),
  )
  self._xr_frame = Some(frame)
  if !pose.is_null() {
    let views = pose.get("views")
    let webgpu_view_data = if self._is_webgpu_session() {
      Some(self._get_webgpu_view_data(views))
    } else {
      None
    }
    match (gl_base_layer, webgpu_view_data) {
      (Some(layer), None) =>
        backend.set_xr_target(Some(layer.get("framebuffer")))
      _ => ()
    }
    let mut camera_xr_needs_update = false
    let xr_cameras = xr_manager_array_camera(camera_xr).cameras
    // check if it's necessary to rebuild cameraXR's camera list
    let view_count = xr_array_length(views)
    if view_count != xr_cameras.length() {
      xr_cameras.clear()
      camera_xr_needs_update = true
    }
    for i in 0..<view_count {
      let view = xr_array_get(views, i)
      let viewport = match webgpu_view_data {
        Some(data) => data.viewports[i]
        None =>
          if self._supports_layers == true {
            // WebGL path: Use XRWebGLBinding
            let gl_sub_image = xr_call2(
              self._gl_binding.unwrap(),
              "getViewSubImage",
              self._gl_proj_layer.unwrap(),
              view,
            )
            // For side-by-side projection, we only produce a single texture for both eyes.
            if i == 0 {
              let ignore_depth = self._gl_proj_layer
                .unwrap()
                .get("ignoreDepthValues")
              backend.set_xr_render_target_textures(
                self._xr_render_target.unwrap(),
                gl_sub_image.get("colorTexture"),
                if js_truthy(ignore_depth) && !self._use_multiview {
                  @core.JsValue::undefined()
                } else {
                  gl_sub_image.get("depthStencilTexture")
                },
              )
            }
            gl_sub_image.get("viewport")
          } else {
            xr_call1(gl_base_layer.unwrap(), "getViewport", view)
          }
      }
      let camera = match self._cameras.get(i) {
        Some(c) => c
        None => {
          let camera = @core.PerspectiveCamera::new()
          camera.layers.enable(i)
          @webgl.set_camera_viewport(
            camera,
            Some(@math.Vector4::new(0.0, 0.0, 0.0, 0.0)),
          )
          camera.matrix_world_auto_update = false
          self._cameras.push(camera)
          camera
        }
      }
      camera.matrix.from_array(
        xr_number_array(view.get("transform").get("matrix")),
      )
      |> ignore
      camera.matrix.decompose(camera.position, camera.quaternion, camera.scale)
      |> ignore
      camera.as_camera().projection_matrix.from_array(
        xr_number_array(view.get("projectionMatrix")),
      )
      |> ignore
      camera.as_camera().projection_matrix_inverse
      .copy(camera.projection_matrix())
      .invert()
      |> ignore
      match @webgl.camera_viewport(camera) {
        Some(v) =>
          v.set(
            xr_number(viewport.get("x")),
            xr_number(viewport.get("y")),
            xr_number(viewport.get("width")),
            xr_number(viewport.get("height")),
          )
          |> ignore
        None => ()
      }
      if i == 0 {
        camera_xr.matrix.copy(camera.matrix) |> ignore
        camera_xr.matrix.decompose(
          camera_xr.position,
          camera_xr.quaternion,
          camera_xr.scale,
        )
        |> ignore
      }
      if camera_xr_needs_update == true {
        xr_cameras.push(camera)
      }
    }
    match webgpu_view_data {
      Some({ color_texture: Some(color_texture), view_descriptors, .. }) =>
        backend.set_xr_render_target_textures(
          self._xr_render_target.unwrap(),
          color_texture,
          xr_array_of(view_descriptors),
        )
      _ => ()
    }
    renderer.set_output_render_target(self._xr_render_target)
    let frame_buffer_target = renderer._get_frame_buffer_target()
    if webgpu_view_data is Some(_) {
      let xr_render_target = self._xr_render_target.unwrap()
      xr_render_target.samples = if frame_buffer_target is None {
        renderer.samples()
      } else {
        0
      }
      xr_render_target.depth_buffer = frame_buffer_target is None
    }
    renderer.xr.foveate_bound_texture(frame_buffer_target)
  }
  //
  for i in 0..<self._controllers.length() {
    let input_source = match self._controller_input_sources.get(i) {
      Some(s) => s
      None => Some(@core.JsValue::undefined())
    }
    match (input_source, self._controllers[i]) {
      (Some(input_source), Some(controller)) =>
        controller.update(
          if input_source.is_undefined() {
            None
          } else {
            Some(input_source.cast())
          },
          frame.cast(),
          reference_space.map(fn(s) { s.cast() }),
        )
        |> ignore
      _ => ()
    }
  }
  match self._current_animation_loop {
    Some(f) => f(time, frame)
    None => ()
  }
  if js_truthy(frame.get("detectedPlanes")) {
    self.dispatch_event(@core.Event::new("planesdetected", data=frame))
  }
  self._xr_frame = None
}

///|
extern "js" fn js_truthy(value : @core.JsValue) -> Bool = "(v) => !! v"

///|
extern "js" fn xr_nan() -> Double = "() => NaN"

///|
/// `plane.material = material`.
fn xr_manager_set_plane_material(
  plane : @core.Object3D,
  material : @core.MaterialSlot,
) -> Unit {
  match plane.kind {
    Mesh(m) => m.material = material
    _ => ()
  }
}

///|
fn xr_session(session : @core.JsValue) -> @webgl.XRSession {
  session.cast()
}

///|
extern "js" fn xr_number_array(array : @core.JsValue) -> Array[Double] = "(a) => Array.from( a )"
