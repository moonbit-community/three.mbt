// renderers/common/CanvasTarget.js: the canvas a renderer draws to, with its size,
// pixel ratio, viewport and scissor. The DOM element is a JS value (a canvas or an
// `OffscreenCanvas`).

///|
extern "js" fn canvas_target_dom_width(dom_element : @core.JsValue) -> Double = "(d) => d.width"

///|
extern "js" fn canvas_target_dom_height(dom_element : @core.JsValue) -> Double = "(d) => d.height"

///|
extern "js" fn canvas_target_dom_set_size(
  dom_element : @core.JsValue,
  width : Double,
  height : Double,
) -> Unit = "(d, w, h) => { d.width = w; d.height = h; }"

///|
extern "js" fn canvas_target_dom_set_style_size(
  dom_element : @core.JsValue,
  width : Double,
  height : Double,
) -> Unit = "(d, w, h) => { d.style.width = w + 'px'; d.style.height = h + 'px'; }"

///|
extern "js" fn canvas_target_math_floor(x : Double) -> Double = "Math.floor"

///|
/// A canvas and its drawing state.
pub(all) struct CanvasTarget {
  dispatcher : @core.EventDispatcher
  dom_element : @core.JsValue
  mut _pixel_ratio : Double
  mut _width : Double
  mut _height : Double
  _viewport : @math.Vector4
  /// `_viewport.minDepth` / `maxDepth`; `None` is `undefined` (before `setViewport`).
  mut _viewport_min_depth : Double?
  mut _viewport_max_depth : Double?
  _scissor : @math.Vector4
  mut _scissor_test : Bool
  color_texture : @core.Texture
  depth_texture : @core.Texture
  /// `isDefaultCanvasTarget`, set by the renderer on its own canvas target.
  mut is_default_canvas_target : Bool
}

///|
pub impl @core.EventSource for CanvasTarget with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl @core.EventSource for CanvasTarget with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend CanvasTarget with @core.EventSource::{
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// `new CanvasTarget( domElement )`.
pub fn CanvasTarget::new(dom_element : @core.JsValue) -> CanvasTarget {
  let width = canvas_target_dom_width(dom_element)
  let height = canvas_target_dom_height(dom_element)
  {
    dispatcher: @core.EventDispatcher::new(),
    dom_element,
    _pixel_ratio: 1.0,
    _width: width,
    _height: height,
    _viewport: @math.Vector4::new(0.0, 0.0, width, height),
    _viewport_min_depth: None,
    _viewport_max_depth: None,
    _scissor: @math.Vector4::new(0.0, 0.0, width, height),
    _scissor_test: false,
    color_texture: @core.FramebufferTexture::new(),
    depth_texture: @core.DepthTexture::new(),
    is_default_canvas_target: false,
  }
}

///|
pub fn CanvasTarget::get_pixel_ratio(self : CanvasTarget) -> Double {
  self._pixel_ratio
}

///|
/// `getDrawingBufferSize( target )`: the size in pixels.
pub fn CanvasTarget::get_drawing_buffer_size(
  self : CanvasTarget,
  target : @math.Vector2,
) -> @math.Vector2 {
  target
  .set(self._width * self._pixel_ratio, self._height * self._pixel_ratio)
  .floor()
}

///|
/// `getSize( target )`: the size in CSS pixels.
pub fn CanvasTarget::get_size(
  self : CanvasTarget,
  target : @math.Vector2,
) -> @math.Vector2 {
  target.set(self._width, self._height)
}

///|
/// `setPixelRatio( value = 1 )`.
pub fn CanvasTarget::set_pixel_ratio(
  self : CanvasTarget,
  value~ : Double = 1.0,
) -> Unit {
  if self._pixel_ratio == value {
    return
  }
  self._pixel_ratio = value
  self.set_size(self._width, self._height, update_style=false)
}

///|
/// `setDrawingBufferSize( width, height, pixelRatio )`. (Upstream's `this.xr` test is
/// always false here: a canvas target has no `xr`.)
pub fn CanvasTarget::set_drawing_buffer_size(
  self : CanvasTarget,
  width : Double,
  height : Double,
  pixel_ratio : Double,
) -> Unit {
  self._width = width
  self._height = height
  self._pixel_ratio = pixel_ratio
  canvas_target_dom_set_size(
    self.dom_element,
    canvas_target_math_floor(width * pixel_ratio),
    canvas_target_math_floor(height * pixel_ratio),
  )
  self.set_viewport(0.0, 0.0, width, height)
  self._dispatch_resize()
}

///|
/// `setSize( width, height, updateStyle = true )`.
pub fn CanvasTarget::set_size(
  self : CanvasTarget,
  width : Double,
  height : Double,
  update_style~ : Bool = true,
) -> Unit {
  self._width = width
  self._height = height
  canvas_target_dom_set_size(
    self.dom_element,
    canvas_target_math_floor(width * self._pixel_ratio),
    canvas_target_math_floor(height * self._pixel_ratio),
  )
  if update_style {
    canvas_target_dom_set_style_size(self.dom_element, width, height)
  }
  self.set_viewport(0.0, 0.0, width, height)
  self._dispatch_resize()
}

///|
/// `getScissor( target )`.
pub fn CanvasTarget::get_scissor(
  self : CanvasTarget,
  target : @math.Vector4,
) -> @math.Vector4 {
  let scissor = self._scissor
  target.x = scissor.x
  target.y = scissor.y
  target.z = scissor.z
  target.w = scissor.w
  target
}

///|
/// `setScissor( x, y, width, height )`.
pub fn CanvasTarget::set_scissor(
  self : CanvasTarget,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit {
  self._scissor.set(x, y, width, height) |> ignore
}

///|
/// `setScissor( vector4 )`.
pub fn CanvasTarget::set_scissor_vector(
  self : CanvasTarget,
  x : @math.Vector4,
) -> Unit {
  self._scissor.copy(x) |> ignore
}

///|
pub fn CanvasTarget::get_scissor_test(self : CanvasTarget) -> Bool {
  self._scissor_test
}

///|
pub fn CanvasTarget::set_scissor_test(
  self : CanvasTarget,
  boolean : Bool,
) -> Unit {
  self._scissor_test = boolean
}

///|
/// `getViewport( target )`.
pub fn CanvasTarget::get_viewport(
  self : CanvasTarget,
  target : @math.Vector4,
) -> @math.Vector4 {
  target.copy(self._viewport)
}

///|
/// `setViewport( x, y, width, height, minDepth = 0, maxDepth = 1 )`.
pub fn CanvasTarget::set_viewport(
  self : CanvasTarget,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  min_depth~ : Double = 0.0,
  max_depth~ : Double = 1.0,
) -> Unit {
  self._viewport.set(x, y, width, height) |> ignore
  self._viewport_min_depth = Some(min_depth)
  self._viewport_max_depth = Some(max_depth)
}

///|
/// `setViewport( vector4, minDepth = 0, maxDepth = 1 )`.
pub fn CanvasTarget::set_viewport_vector(
  self : CanvasTarget,
  x : @math.Vector4,
  min_depth~ : Double = 0.0,
  max_depth~ : Double = 1.0,
) -> Unit {
  self._viewport.copy(x) |> ignore
  self._viewport_min_depth = Some(min_depth)
  self._viewport_max_depth = Some(max_depth)
}

///|
fn CanvasTarget::_dispatch_resize(self : CanvasTarget) -> Unit {
  self.dispatch_event(@core.Event::new("resize"))
}

///|
/// `dispose()`: dispatches `dispose`.
pub fn CanvasTarget::dispose(self : CanvasTarget) -> Unit {
  self.dispatch_event(@core.Event::new("dispose"))
}
