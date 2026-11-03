// WebXR Device API and WebXR Layers bindings used by upstream src/renderers/webxr
// (WebXRManager.js, WebXRController.js, WebXRDepthSensing.js). The list is every member
// those files touch on an XR object; check it with the harness's
// tools/check_xr_coverage.mjs. Objects are opaque; where upstream reads a value that
// may be `null` or `undefined`, the binding returns `T?`.

///|
/// `XRSession`.
#external
pub type XRSession

///|
/// `XRFrame`.
#external
pub type XRFrame

///|
/// `XRReferenceSpace`.
#external
pub type XRReferenceSpace

///|
/// `XRSpace`: an input source's `targetRaySpace` or `gripSpace`.
#external
pub type XRSpace

///|
/// `XRJointSpace`: one joint of an `XRHand`.
#external
pub type XRJointSpace

///|
/// `XRHand`.
#external
pub type XRHand

///|
/// `XRInputSource`.
#external
pub type XRInputSource

///|
/// `XRViewerPose`.
#external
pub type XRViewerPose

///|
/// `XRView`.
#external
pub type XRView

///|
/// `XRViewport`.
#external
pub type XRViewport

///|
/// `XRRigidTransform`.
#external
pub type XRRigidTransform

///|
/// `XRPose`.
#external
pub type XRPose

///|
/// `XRJointPose`.
#external
pub type XRJointPose

///|
/// `DOMPointReadOnly`, as in `XRPose.linearVelocity`.
#external
pub type DOMPointReadOnly

///|
/// `XRRenderState`.
#external
pub type XRRenderState

///|
/// `XRWebGLLayer`.
#external
pub type XRWebGLLayer

///|
/// `XRProjectionLayer` (WebXR Layers).
#external
pub type XRProjectionLayer

///|
/// `XRWebGLBinding`.
#external
pub type XRWebGLBinding

///|
/// `XRWebGLSubImage`.
#external
pub type XRWebGLSubImage

///|
/// `XRWebGLDepthInformation`.
#external
pub type XRWebGLDepthInformation

///|
/// `XRCamera` (raw camera access).
#external
pub type XRCamera

///|
/// `XRInputSourceEvent` (`select`, `squeeze`, ...).
#external
pub type XRInputSourceEvent

///|
/// `XRInputSourcesChangeEvent` (`inputsourceschange`).
#external
pub type XRInputSourcesChangeEvent

///|
extern "js" fn ffi_xr_array(value : @core.JsValue) -> FixedArray[@core.JsValue] = "(a) => Array.from(a)"

///|
extern "js" fn ffi_xr_numbers(value : @core.JsValue) -> FixedArray[Double] = "(a) => Array.from(a)"

///|
/// JS truthiness, `!!value`.
extern "js" fn xr_truthy(value : @core.JsValue) -> Bool = "(v) => !!v"

///|
/// `String( value )`, the key a plain object turns an object key into.
extern "js" fn xr_property_key(value : @core.JsValue) -> String = "(v) => String(v)"

///|
fn[T] xr_array_of(value : @core.JsValue) -> Array[T] {
  ffi_xr_array(value).iter().map(v => v.cast()).collect()
}

///|
fn xr_numbers_of(value : @core.JsValue) -> Array[Double] {
  Array::from_fixed_array(ffi_xr_numbers(value))
}

// --- XRSession ---------------------------------------------------------------

///|
/// `session.addEventListener( type, listener )`; keep the closure to remove it.
pub extern "js" fn XRSession::add_event_listener(
  self : XRSession,
  type_ : String,
  listener : (@core.JsValue) -> Unit,
) -> Unit = "(s, t, l) => s.addEventListener(t, l)"

///|
/// `session.removeEventListener( type, listener )`.
pub extern "js" fn XRSession::remove_event_listener(
  self : XRSession,
  type_ : String,
  listener : (@core.JsValue) -> Unit,
) -> Unit = "(s, t, l) => s.removeEventListener(t, l)"

///|
/// `session.updateRenderState( { baseLayer: layer } )`.
pub extern "js" fn XRSession::update_render_state_base_layer(
  self : XRSession,
  layer : XRWebGLLayer,
) -> Unit = "(s, l) => s.updateRenderState({ baseLayer: l })"

///|
/// `session.updateRenderState( { layers } )`.
pub extern "js" fn XRSession::update_render_state_layers(
  self : XRSession,
  layers : FixedArray[XRProjectionLayer],
) -> Unit = "(s, l) => s.updateRenderState({ layers: l })"

///|
/// `session.updateRenderState( { depthNear, depthFar } )`.
pub extern "js" fn XRSession::update_render_state_depth(
  self : XRSession,
  depth_near : Double,
  depth_far : Double,
) -> Unit = "(s, n, f) => s.updateRenderState({ depthNear: n, depthFar: f })"

///|
extern "js" fn ffi_xr_session_request_reference_space(
  session : XRSession,
  type_ : String,
  on_done : (XRReferenceSpace) -> Unit,
) -> Unit = "(s, t, f) => { s.requestReferenceSpace(t).then(f); }"

///|
/// `await session.requestReferenceSpace( type )`: `on_done` gets the space.
pub fn XRSession::request_reference_space(
  self : XRSession,
  type_ : String,
  on_done : (XRReferenceSpace) -> Unit,
) -> Unit {
  ffi_xr_session_request_reference_space(self, type_, on_done)
}

///|
/// `session.environmentBlendMode`.
pub extern "js" fn XRSession::environment_blend_mode(
  self : XRSession,
) -> String = "(s) => s.environmentBlendMode"

///|
extern "js" fn ffi_xr_session_enabled_features(
  session : XRSession,
) -> @core.JsValue = "(s) => s.enabledFeatures"

///|
/// `session.enabledFeatures`; `None` where the browser does not report them.
pub fn XRSession::enabled_features(self : XRSession) -> Array[String]? {
  let features = ffi_xr_session_enabled_features(self)
  if xr_truthy(features) {
    Some(xr_array_of(features))
  } else {
    None
  }
}

///|
/// `session.depthUsage == value`.
pub extern "js" fn XRSession::depth_usage_is(
  self : XRSession,
  value : String,
) -> Bool = "(s, v) => s.depthUsage == v"

///|
/// `session.renderState`.
pub extern "js" fn XRSession::render_state(self : XRSession) -> XRRenderState = "(s) => s.renderState"

///|
/// `session.visibilityState`.
pub extern "js" fn XRSession::visibility_state(self : XRSession) -> String = "(s) => s.visibilityState"

///|
/// The session as the `requestAnimationFrame` provider of `WebGLAnimation`.
pub fn XRSession::as_animation_frame_provider(
  self : XRSession,
) -> AnimationFrameProvider {
  @core.JsValue::of(self).cast()
}

///|
/// `renderState.depthNear`.
pub extern "js" fn XRRenderState::depth_near(self : XRRenderState) -> Double = "(r) => r.depthNear"

///|
/// `renderState.depthFar`.
pub extern "js" fn XRRenderState::depth_far(self : XRRenderState) -> Double = "(r) => r.depthFar"

// --- XRFrame -----------------------------------------------------------------

///|
extern "js" fn ffi_xr_frame_get_viewer_pose(
  frame : XRFrame,
  space : @core.JsValue,
) -> @core.JsValue = "(f, s) => f.getViewerPose(s)"

///|
/// `frame.getViewerPose( referenceSpace )`.
pub fn XRFrame::get_viewer_pose(
  self : XRFrame,
  reference_space : XRReferenceSpace?,
) -> XRViewerPose? {
  gl_option(ffi_xr_frame_get_viewer_pose(self, gl_nullable(reference_space)))
}

///|
/// `frame.session`.
pub extern "js" fn XRFrame::session(self : XRFrame) -> XRSession = "(f) => f.session"

///|
extern "js" fn ffi_xr_frame_get_pose(
  frame : XRFrame,
  space : XRSpace,
  base : @core.JsValue,
) -> @core.JsValue = "(f, s, b) => f.getPose(s, b)"

///|
/// `frame.getPose( space, baseSpace )`.
pub fn XRFrame::get_pose(
  self : XRFrame,
  space : XRSpace,
  base_space : XRReferenceSpace?,
) -> XRPose? {
  gl_option(ffi_xr_frame_get_pose(self, space, gl_nullable(base_space)))
}

///|
extern "js" fn ffi_xr_frame_get_joint_pose(
  frame : XRFrame,
  joint : XRJointSpace,
  base : @core.JsValue,
) -> @core.JsValue = "(f, j, b) => f.getJointPose(j, b)"

///|
/// `frame.getJointPose( joint, baseSpace )`.
pub fn XRFrame::get_joint_pose(
  self : XRFrame,
  joint : XRJointSpace,
  base_space : XRReferenceSpace?,
) -> XRJointPose? {
  gl_option(ffi_xr_frame_get_joint_pose(self, joint, gl_nullable(base_space)))
}

///|
/// `!! frame.detectedPlanes`.
pub extern "js" fn XRFrame::has_detected_planes(self : XRFrame) -> Bool = "(f) => !!f.detectedPlanes"

// --- poses and views ---------------------------------------------------------

///|
extern "js" fn ffi_xr_viewer_pose_views(pose : XRViewerPose) -> @core.JsValue = "(p) => p.views"

///|
/// `pose.views`.
pub fn XRViewerPose::views(self : XRViewerPose) -> Array[XRView] {
  xr_array_of(ffi_xr_viewer_pose_views(self))
}

///|
/// `view.transform`.
pub extern "js" fn XRView::transform(self : XRView) -> XRRigidTransform = "(v) => v.transform"

///|
extern "js" fn ffi_xr_view_projection_matrix(view : XRView) -> @core.JsValue = "(v) => v.projectionMatrix"

///|
/// `view.projectionMatrix`, a `Float32Array` of 16 values.
pub fn XRView::projection_matrix(self : XRView) -> Array[Double] {
  xr_numbers_of(ffi_xr_view_projection_matrix(self))
}

///|
extern "js" fn ffi_xr_view_camera(view : XRView) -> @core.JsValue = "(v) => v.camera"

///|
/// `view.camera` (raw camera access); `None` when the view has none.
pub fn XRView::camera(self : XRView) -> XRCamera? {
  let camera = ffi_xr_view_camera(self)
  if xr_truthy(camera) {
    Some(camera.cast())
  } else {
    None
  }
}

///|
extern "js" fn ffi_xr_rigid_transform_matrix(
  transform : XRRigidTransform,
) -> @core.JsValue = "(t) => t.matrix"

///|
/// `transform.matrix`, a `Float32Array` of 16 values.
pub fn XRRigidTransform::matrix(self : XRRigidTransform) -> Array[Double] {
  xr_numbers_of(ffi_xr_rigid_transform_matrix(self))
}

///|
/// `pose.transform`.
pub extern "js" fn XRPose::transform(self : XRPose) -> XRRigidTransform = "(p) => p.transform"

///|
extern "js" fn ffi_xr_pose_linear_velocity(pose : XRPose) -> @core.JsValue = "(p) => p.linearVelocity"

///|
extern "js" fn ffi_xr_pose_angular_velocity(pose : XRPose) -> @core.JsValue = "(p) => p.angularVelocity"

///|
/// `pose.linearVelocity`; `None` when it is not reported.
pub fn XRPose::linear_velocity(self : XRPose) -> DOMPointReadOnly? {
  let value = ffi_xr_pose_linear_velocity(self)
  if xr_truthy(value) {
    Some(value.cast())
  } else {
    None
  }
}

///|
/// `pose.angularVelocity`; `None` when it is not reported.
pub fn XRPose::angular_velocity(self : XRPose) -> DOMPointReadOnly? {
  let value = ffi_xr_pose_angular_velocity(self)
  if xr_truthy(value) {
    Some(value.cast())
  } else {
    None
  }
}

///|
/// `jointPose.transform`.
pub extern "js" fn XRJointPose::transform(
  self : XRJointPose,
) -> XRRigidTransform = "(p) => p.transform"

///|
/// `jointPose.radius`.
pub extern "js" fn XRJointPose::radius(self : XRJointPose) -> Double = "(p) => p.radius"

///|
/// `point.x`.
pub extern "js" fn DOMPointReadOnly::x(self : DOMPointReadOnly) -> Double = "(p) => p.x"

///|
/// `point.y`.
pub extern "js" fn DOMPointReadOnly::y(self : DOMPointReadOnly) -> Double = "(p) => p.y"

///|
/// `point.z`.
pub extern "js" fn DOMPointReadOnly::z(self : DOMPointReadOnly) -> Double = "(p) => p.z"

///|
/// `viewport.x`.
pub extern "js" fn XRViewport::x(self : XRViewport) -> Double = "(v) => v.x"

///|
/// `viewport.y`.
pub extern "js" fn XRViewport::y(self : XRViewport) -> Double = "(v) => v.y"

///|
/// `viewport.width`.
pub extern "js" fn XRViewport::width(self : XRViewport) -> Double = "(v) => v.width"

///|
/// `viewport.height`.
pub extern "js" fn XRViewport::height(self : XRViewport) -> Double = "(v) => v.height"

// --- input sources -----------------------------------------------------------

///|
extern "js" fn ffi_xr_input_source_hand(
  source : XRInputSource,
) -> @core.JsValue = "(s) => s.hand"

///|
/// `inputSource.hand`; `None` for controllers without hand tracking.
pub fn XRInputSource::hand(self : XRInputSource) -> XRHand? {
  let hand = ffi_xr_input_source_hand(self)
  if xr_truthy(hand) {
    Some(hand.cast())
  } else {
    None
  }
}

///|
/// `inputSource.handedness`.
pub extern "js" fn XRInputSource::handedness(self : XRInputSource) -> String = "(s) => s.handedness"

///|
extern "js" fn ffi_xr_input_source_grip_space(
  source : XRInputSource,
) -> @core.JsValue = "(s) => s.gripSpace"

///|
/// `inputSource.gripSpace`; `None` when the source has none.
pub fn XRInputSource::grip_space(self : XRInputSource) -> XRSpace? {
  let space = ffi_xr_input_source_grip_space(self)
  if xr_truthy(space) {
    Some(space.cast())
  } else {
    None
  }
}

///|
/// `inputSource.targetRaySpace`.
pub extern "js" fn XRInputSource::target_ray_space(
  self : XRInputSource,
) -> XRSpace = "(s) => s.targetRaySpace"

///|
extern "js" fn ffi_xr_hand_values(hand : XRHand) -> @core.JsValue = "(h) => Array.from(h.values())"

///|
/// `hand.values()`, in iteration order.
pub fn XRHand::values(self : XRHand) -> Array[XRJointSpace] {
  xr_array_of(ffi_xr_hand_values(self))
}

///|
/// `joint.jointName`.
pub extern "js" fn XRJointSpace::joint_name(self : XRJointSpace) -> String = "(j) => j.jointName"

///|
/// `event.inputSource`.
pub extern "js" fn XRInputSourceEvent::input_source(
  self : XRInputSourceEvent,
) -> XRInputSource = "(e) => e.inputSource"

///|
/// `event.frame`.
pub extern "js" fn XRInputSourceEvent::frame(
  self : XRInputSourceEvent,
) -> XRFrame = "(e) => e.frame"

///|
/// `event.type`.
pub extern "js" fn XRInputSourceEvent::type_(
  self : XRInputSourceEvent,
) -> String = "(e) => e.type"

///|
extern "js" fn ffi_xr_change_event_added(
  event : XRInputSourcesChangeEvent,
) -> @core.JsValue = "(e) => e.added"

///|
extern "js" fn ffi_xr_change_event_removed(
  event : XRInputSourcesChangeEvent,
) -> @core.JsValue = "(e) => e.removed"

///|
/// `event.added`.
pub fn XRInputSourcesChangeEvent::added(
  self : XRInputSourcesChangeEvent,
) -> Array[XRInputSource] {
  xr_array_of(ffi_xr_change_event_added(self))
}

///|
/// `event.removed`.
pub fn XRInputSourcesChangeEvent::removed(
  self : XRInputSourcesChangeEvent,
) -> Array[XRInputSource] {
  xr_array_of(ffi_xr_change_event_removed(self))
}

// --- layers ------------------------------------------------------------------

///|
/// `new XRWebGLLayer( session, gl, { antialias, alpha, depth, stencil,
/// framebufferScaleFactor } )`; `antialias`, `depth` and `stencil` are passed as given.
pub extern "js" fn XRWebGLLayer::new(
  session : XRSession,
  gl : WebGL2RenderingContext,
  antialias : @core.JsValue,
  alpha : Bool,
  depth : @core.JsValue,
  stencil : @core.JsValue,
  framebuffer_scale_factor : Double,
) -> XRWebGLLayer = "(s, gl, aa, al, d, st, f) => new XRWebGLLayer(s, gl, { antialias: aa, alpha: al, depth: d, stencil: st, framebufferScaleFactor: f })"

///|
/// `layer.framebufferWidth`.
pub extern "js" fn XRWebGLLayer::framebuffer_width(
  self : XRWebGLLayer,
) -> Int32 = "(l) => l.framebufferWidth"

///|
/// `layer.framebufferHeight`.
pub extern "js" fn XRWebGLLayer::framebuffer_height(
  self : XRWebGLLayer,
) -> Int32 = "(l) => l.framebufferHeight"

///|
extern "js" fn ffi_xr_webgl_layer_framebuffer(
  layer : XRWebGLLayer,
) -> @core.JsValue = "(l) => l.framebuffer"

///|
/// `layer.framebuffer`; `None` is the opaque default framebuffer (`null`).
pub fn XRWebGLLayer::framebuffer(self : XRWebGLLayer) -> GLFramebuffer? {
  gl_option(ffi_xr_webgl_layer_framebuffer(self))
}

///|
/// `layer.ignoreDepthValues === false`.
pub extern "js" fn XRWebGLLayer::keeps_depth_values(
  self : XRWebGLLayer,
) -> Bool = "(l) => l.ignoreDepthValues === false"

///|
/// `layer.fixedFoveation !== undefined`.
pub extern "js" fn XRWebGLLayer::has_fixed_foveation(
  self : XRWebGLLayer,
) -> Bool = "(l) => l.fixedFoveation !== undefined"

///|
/// `layer.fixedFoveation = value`.
pub extern "js" fn XRWebGLLayer::set_fixed_foveation(
  self : XRWebGLLayer,
  value : Double,
) -> Unit = "(l, v) => { l.fixedFoveation = v; }"

///|
/// `layer.getViewport( view )`.
pub extern "js" fn XRWebGLLayer::get_viewport(
  self : XRWebGLLayer,
  view : XRView,
) -> XRViewport = "(l, v) => l.getViewport(v)"

///|
/// `layer.textureWidth`.
pub extern "js" fn XRProjectionLayer::texture_width(
  self : XRProjectionLayer,
) -> Int32 = "(l) => l.textureWidth"

///|
/// `layer.textureHeight`.
pub extern "js" fn XRProjectionLayer::texture_height(
  self : XRProjectionLayer,
) -> Int32 = "(l) => l.textureHeight"

///|
/// `layer.ignoreDepthValues === false`.
pub extern "js" fn XRProjectionLayer::keeps_depth_values(
  self : XRProjectionLayer,
) -> Bool = "(l) => l.ignoreDepthValues === false"

///|
/// `layer.fixedFoveation = value`.
pub extern "js" fn XRProjectionLayer::set_fixed_foveation(
  self : XRProjectionLayer,
  value : Double,
) -> Unit = "(l, v) => { l.fixedFoveation = v; }"

// --- XRWebGLBinding ----------------------------------------------------------

///|
/// `typeof XRWebGLBinding !== 'undefined'`.
pub extern "js" fn xr_webgl_binding_supported() -> Bool = "() => typeof XRWebGLBinding !== 'undefined'"

///|
/// `'createProjectionLayer' in XRWebGLBinding.prototype`.
pub extern "js" fn xr_webgl_binding_supports_layers() -> Bool = "() => 'createProjectionLayer' in XRWebGLBinding.prototype"

///|
/// `new XRWebGLBinding( session, gl )`.
pub extern "js" fn XRWebGLBinding::new(
  session : XRSession,
  gl : WebGL2RenderingContext,
) -> XRWebGLBinding = "(s, gl) => new XRWebGLBinding(s, gl)"

///|
extern "js" fn ffi_xr_binding_create_projection_layer(
  binding : XRWebGLBinding,
  color_format : Int32,
  depth_format : @core.JsValue,
  scale_factor : Double,
) -> XRProjectionLayer = "(b, c, d, s) => b.createProjectionLayer({ colorFormat: c, depthFormat: d, scaleFactor: s })"

///|
/// `binding.createProjectionLayer( { colorFormat, depthFormat, scaleFactor } )`;
/// `None` depth format is `null`.
pub fn XRWebGLBinding::create_projection_layer(
  self : XRWebGLBinding,
  color_format : Int32,
  depth_format : Int32?,
  scale_factor : Double,
) -> XRProjectionLayer {
  ffi_xr_binding_create_projection_layer(
    self,
    color_format,
    gl_nullable(depth_format),
    scale_factor,
  )
}

///|
/// `binding.getViewSubImage( layer, view )`.
pub extern "js" fn XRWebGLBinding::get_view_sub_image(
  self : XRWebGLBinding,
  layer : XRProjectionLayer,
  view : XRView,
) -> XRWebGLSubImage = "(b, l, v) => b.getViewSubImage(l, v)"

///|
extern "js" fn ffi_xr_binding_get_depth_information(
  binding : XRWebGLBinding,
  view : XRView,
) -> @core.JsValue = "(b, v) => b.getDepthInformation(v)"

///|
/// `binding.getDepthInformation( view )`; `None` when there is none.
pub fn XRWebGLBinding::get_depth_information(
  self : XRWebGLBinding,
  view : XRView,
) -> XRWebGLDepthInformation? {
  let depth = ffi_xr_binding_get_depth_information(self, view)
  if xr_truthy(depth) {
    Some(depth.cast())
  } else {
    None
  }
}

///|
extern "js" fn ffi_xr_binding_get_camera_image(
  binding : XRWebGLBinding,
  camera : XRCamera,
) -> @core.JsValue = "(b, c) => b.getCameraImage(c)"

///|
/// `binding.getCameraImage( camera )`.
pub fn XRWebGLBinding::get_camera_image(
  self : XRWebGLBinding,
  camera : XRCamera,
) -> GLTexture? {
  gl_option(ffi_xr_binding_get_camera_image(self, camera))
}

///|
/// `subImage.viewport`.
pub extern "js" fn XRWebGLSubImage::viewport(
  self : XRWebGLSubImage,
) -> XRViewport = "(s) => s.viewport"

///|
extern "js" fn ffi_xr_sub_image_color_texture(
  image : XRWebGLSubImage,
) -> @core.JsValue = "(s) => s.colorTexture"

///|
extern "js" fn ffi_xr_sub_image_depth_stencil_texture(
  image : XRWebGLSubImage,
) -> @core.JsValue = "(s) => s.depthStencilTexture"

///|
/// `subImage.colorTexture`.
pub fn XRWebGLSubImage::color_texture(self : XRWebGLSubImage) -> GLTexture? {
  gl_option(ffi_xr_sub_image_color_texture(self))
}

///|
/// `subImage.depthStencilTexture`.
pub fn XRWebGLSubImage::depth_stencil_texture(
  self : XRWebGLSubImage,
) -> GLTexture? {
  gl_option(ffi_xr_sub_image_depth_stencil_texture(self))
}

///|
/// `!! depthData.isValid`.
pub extern "js" fn XRWebGLDepthInformation::is_valid(
  self : XRWebGLDepthInformation,
) -> Bool = "(d) => !!d.isValid"

///|
extern "js" fn ffi_xr_depth_information_texture(
  depth : XRWebGLDepthInformation,
) -> @core.JsValue = "(d) => d.texture"

///|
/// `depthData.texture`; `None` when it is falsy.
pub fn XRWebGLDepthInformation::texture(
  self : XRWebGLDepthInformation,
) -> GLTexture? {
  let texture = ffi_xr_depth_information_texture(self)
  if xr_truthy(texture) {
    Some(texture.cast())
  } else {
    None
  }
}

///|
/// `depthData.depthNear`.
pub extern "js" fn XRWebGLDepthInformation::depth_near(
  self : XRWebGLDepthInformation,
) -> Double = "(d) => d.depthNear"

///|
/// `depthData.depthFar`.
pub extern "js" fn XRWebGLDepthInformation::depth_far(
  self : XRWebGLDepthInformation,
) -> Double = "(d) => d.depthFar"

// --- WebGL context -----------------------------------------------------------

///|
/// `attributes.xrCompatible === true` on `gl.getContextAttributes()`.
pub extern "js" fn xr_compatible_attribute(attributes : @core.JsValue) -> Bool = "(a) => a.xrCompatible === true"

///|
extern "js" fn ffi_gl_make_xr_compatible(
  gl : WebGL2RenderingContext,
  on_done : () -> Unit,
) -> Unit = "(gl, f) => { gl.makeXRCompatible().then(() => f()); }"

///|
/// `await gl.makeXRCompatible()`: `on_done` runs when the promise resolves.
pub fn WebGL2RenderingContext::make_xr_compatible(
  self : WebGL2RenderingContext,
  on_done : () -> Unit,
) -> Unit {
  ffi_gl_make_xr_compatible(self, on_done)
}
