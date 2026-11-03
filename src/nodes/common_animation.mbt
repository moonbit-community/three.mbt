// renderers/common/Animation.js

///|
/// Runs the renderer's animation loop on `requestAnimationFrame`.
pub struct Animation {
  renderer : Renderer
  nodes : NodeManager
  info : Info
  priv mut _context : @webgl.AnimationFrameProvider?
  priv mut _animation_loop : ((Double, @core.JsValue) -> Unit)?
  /// `null` until the loop starts.
  priv mut _request_id : @core.JsValue?
}

///|
/// `new Animation( renderer, nodes, info )`.
pub fn Animation::new(
  renderer : Renderer,
  nodes : NodeManager,
  info : Info,
) -> Animation {
  {
    renderer,
    nodes,
    info,
    _context: @webgl.global_self(),
    _animation_loop: None,
    _request_id: None,
  }
}

///|
/// `start()`: runs one update now and keeps requesting frames.
pub fn Animation::start(self : Animation) -> Unit {
  if self._request_id is Some(_) {
    return
  }
  fn update(time : Double, xr_frame : @core.JsValue) -> Unit {
    match self._context {
      Some(context) =>
        self._request_id = Some(context.request_animation_frame(update))
      None =>
        abort(
          "TypeError: Cannot read properties of null (reading 'requestAnimationFrame')",
        )
    }
    if self.renderer._inspector.is_running {
      self.renderer._inspector.finish()
    }
    if self.info.auto_reset {
      self.info.reset()
    }
    self.nodes.node_frame.update()
    self.info.frame = self.nodes.node_frame.frame_id
    self.renderer._inspector.begin()
    match self._animation_loop {
      Some(f) => f(time, xr_frame)
      None => ()
    }
  }

  update(@core.JsValue::undefined().cast(), @core.JsValue::undefined())
}

///|
/// `stop()`.
pub fn Animation::stop(self : Animation) -> Unit {
  if self.renderer._inspector.is_running {
    self.renderer._inspector.finish()
  }
  match self._context {
    Some(context) =>
      context.cancel_animation_frame(
        match self._request_id {
          Some(id) => id
          None => @core.JsValue::null()
        },
      )
    None => ()
  }
  self._request_id = None
}

///|
/// `getAnimationLoop()`.
pub fn Animation::get_animation_loop(
  self : Animation,
) -> ((Double, @core.JsValue) -> Unit)? {
  self._animation_loop
}

///|
/// `setAnimationLoop( callback )`.
pub fn Animation::set_animation_loop(
  self : Animation,
  callback : ((Double, @core.JsValue) -> Unit)?,
) -> Unit {
  self._animation_loop = callback
}

///|
/// `getContext()`.
pub fn Animation::get_context(
  self : Animation,
) -> @webgl.AnimationFrameProvider? {
  self._context
}

///|
/// `setContext( context )`.
pub fn Animation::set_context(
  self : Animation,
  context : @webgl.AnimationFrameProvider?,
) -> Unit {
  self._context = context
}

///|
/// `dispose()`.
pub fn Animation::dispose(self : Animation) -> Unit {
  self.stop()
  self._animation_loop = None
}
