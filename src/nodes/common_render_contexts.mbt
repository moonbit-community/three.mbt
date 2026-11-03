// renderers/common/RenderContexts.js

///|
/// One `RenderContext` per attachment state, MRT, camera type and call depth.
pub struct RenderContexts {
  renderer : Renderer
  priv mut _render_contexts : Map[String, RenderContext]
}

///|
/// `new RenderContexts( renderer )`.
pub fn RenderContexts::new(renderer : Renderer) -> RenderContexts {
  { renderer, _render_contexts: Map([]), }
}

///|
/// `get( renderTarget = null, mrt = null, callDepth = 0, camera = null )`.
pub fn RenderContexts::get(
  self : RenderContexts,
  render_target? : @core.RenderTarget,
  mrt? : Node,
  call_depth~ : Int32 = 0,
  camera? : @core.Object3D,
) -> RenderContext {
  let attachment_state = match render_target {
    None => "default"
    Some(rt) => {
      let format = _render_contexts_optional_int(
        rt.textures.get(0).map(fn(t) { t.format }),
      )
      let type_ = _render_contexts_optional_int(
        rt.textures.get(0).map(fn(t) { t.type_ }),
      )
      let count = rt.textures.length()
      "\{count}:\{format}:\{type_}:\{rt.samples}:\{rt.depth_buffer}:\{rt.stencil_buffer}"
    }
  }
  let mrt_state = match mrt {
    Some(m) => m.id.to_string()
    None => "default"
  }
  let camera_state = match camera {
    Some(c) if c.is_orthographic_camera() => "orthographic"
    _ => "perspective"
  }
  let state_key = attachment_state + "-" + mrt_state + "-" + camera_state
  let render_state_key = state_key + "-" + call_depth.to_string() // one render context per call depth keeps the bindings of nested renders separate
  let render_state = match self._render_contexts.get(render_state_key) {
    Some(s) => s
    None => {
      let s = RenderContext::new()
      s.mrt = mrt
      s.state_key = state_key
      self._render_contexts.set(render_state_key, s)
      s
    }
  }
  match render_target {
    Some(rt) =>
      render_state.sample_count = if rt.samples == 0 { 1 } else { rt.samples }
    None => ()
  }
  render_state.clear_depth_value = self.renderer.get_clear_depth()
  render_state.clear_stencil_value = self.renderer.get_clear_stencil()
  render_state
}

///|
/// `${ value }` of an optional number (`undefined` when absent).
fn _render_contexts_optional_int(value : Int32?) -> String {
  match value {
    Some(v) => v.to_string()
    None => "undefined"
  }
}

///|
/// `dispose()`.
pub fn RenderContexts::dispose(self : RenderContexts) -> Unit {
  self._render_contexts = Map([])
}
