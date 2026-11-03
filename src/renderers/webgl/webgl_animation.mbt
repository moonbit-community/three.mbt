// Upstream src/renderers/webgl/WebGLAnimation.js.

///|
pub struct WebGLAnimation {
  mut context : AnimationFrameProvider?
  mut is_animating : Bool
  mut animation_loop : ((Double, @core.JsValue) -> Unit)?
  /// The last `requestAnimationFrame` id; `null` before the first request.
  mut request_id : @core.JsValue
}

///|
/// `new WebGLAnimation()`.
pub fn WebGLAnimation::new() -> WebGLAnimation {
  {
    context: None,
    is_animating: false,
    animation_loop: None,
    request_id: @core.JsValue::null(),
  }
}

///|
fn WebGLAnimation::on_animation_frame(
  self : WebGLAnimation,
  time : Double,
  frame : @core.JsValue,
) -> Unit {
  guard self.context is Some(context) else { return }
  self.request_id = context.request_animation_frame((t, f) => {
    self.on_animation_frame(t, f)
  })
  if self.animation_loop is Some(animation_loop) {
    animation_loop(time, frame)
  }
}

///|
/// `animation.start()`.
pub fn WebGLAnimation::start(self : WebGLAnimation) -> Unit {
  if self.is_animating {
    return
  }
  if self.animation_loop is None {
    return
  }
  guard self.context is Some(context) else { return }
  self.request_id = context.request_animation_frame((t, f) => {
    self.on_animation_frame(t, f)
  })
  self.is_animating = true
}

///|
/// `animation.stop()`.
pub fn WebGLAnimation::stop(self : WebGLAnimation) -> Unit {
  if self.context is Some(context) {
    context.cancel_animation_frame(self.request_id)
  }
  self.is_animating = false
}

///|
/// `animation.setAnimationLoop( callback )`.
pub fn WebGLAnimation::set_animation_loop(
  self : WebGLAnimation,
  callback : ((Double, @core.JsValue) -> Unit)?,
) -> Unit {
  self.animation_loop = callback
}

///|
/// `animation.setContext( value )`.
pub fn WebGLAnimation::set_context(
  self : WebGLAnimation,
  value : AnimationFrameProvider?,
) -> Unit {
  self.context = value
}
