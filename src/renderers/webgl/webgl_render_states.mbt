// Upstream src/renderers/webgl/WebGLRenderStates.js.

///|
/// `renderState.state`.
pub(all) struct WebGLRenderStateData {
  lights_array : Array[@core.Object3D]
  shadows_array : Array[@core.Object3D]
  /// addon `LightProbeGrid` objects (`is_light_probe_grid`)
  light_probe_grid_array : Array[@core.Object3D]
  mut camera : @core.Object3D?
  lights : WebGLLights
  /// camera id -> transmission render target
  transmission_render_target : Map[Int32, @core.RenderTarget]
  mut texture_units : Int32
}

///|
pub struct WebGLRenderState {
  extensions : WebGLExtensions
  state : WebGLRenderStateData
}

///|
/// `new WebGLRenderState( extensions )`.
pub fn WebGLRenderState::new(extensions : WebGLExtensions) -> WebGLRenderState {
  let lights = WebGLLights::new(extensions)
  {
    extensions,
    state: {
      lights_array: [],
      shadows_array: [],
      light_probe_grid_array: [],
      camera: None,
      lights,
      transmission_render_target: {},
      texture_units: 0,
    },
  }
}

///|
/// `renderState.init( camera )`.
pub fn WebGLRenderState::init(
  self : WebGLRenderState,
  camera : @core.Object3D,
) -> Unit {
  self.state.camera = Some(camera)
  self.state.lights_array.clear()
  self.state.shadows_array.clear()
  self.state.light_probe_grid_array.clear()
}

///|
/// `renderState.pushLight( light )`.
pub fn WebGLRenderState::push_light(
  self : WebGLRenderState,
  light : @core.Object3D,
) -> Unit {
  if is_light_probe_grid(light) {
    self.state.light_probe_grid_array.push(light)
  } else {
    self.state.lights_array.push(light)
  }
}

///|
/// `renderState.pushShadow( shadowLight )`.
pub fn WebGLRenderState::push_shadow(
  self : WebGLRenderState,
  shadow_light : @core.Object3D,
) -> Unit {
  self.state.shadows_array.push(shadow_light)
}

///|
fn webgl_light_probe_grid_priority(grid : @core.Object3D) -> Double {
  match light_probe_grid_of(grid) {
    Some(source) => source.priority()
    None => 0.0
  }
}

///|
/// `renderState.setupLights()`.
pub fn WebGLRenderState::setup_lights(self : WebGLRenderState) -> Unit {
  self.state.lights.setup(self.state.lights_array)
  stable_sort_by(self.state.light_probe_grid_array, (a, b) => {
    let by_priority = webgl_light_probe_grid_priority(a) -
      webgl_light_probe_grid_priority(b)
    // `a.priority - b.priority || a.id - b.id`: 0 and NaN fall through
    if by_priority != 0.0 && !by_priority.is_nan() {
      by_priority
    } else {
      (a.id - b.id).to_double()
    }
  })
}

///|
/// `renderState.setupLightsView( camera )`.
pub fn WebGLRenderState::setup_lights_view(
  self : WebGLRenderState,
  camera : @core.Object3D,
) -> Unit {
  self.state.lights.setup_view(self.state.lights_array, camera)
}

///|
pub struct WebGLRenderStates {
  extensions : WebGLExtensions
  /// scene -> one state per nested render call depth
  mut render_states : WeakMap[@core.Object3D, Array[WebGLRenderState]]
}

///|
/// `new WebGLRenderStates( extensions )`.
pub fn WebGLRenderStates::new(
  extensions : WebGLExtensions,
) -> WebGLRenderStates {
  { extensions, render_states: WeakMap::new(), }
}

///|
/// `renderStates.get( scene, renderCallDepth )`.
pub fn WebGLRenderStates::get(
  self : WebGLRenderStates,
  scene : @core.Object3D,
  render_call_depth~ : Int32 = 0,
) -> WebGLRenderState {
  match self.render_states.get(scene) {
    None => {
      let render_state = WebGLRenderState::new(self.extensions)
      self.render_states.set(scene, [render_state])
      render_state
    }
    Some(render_state_array) =>
      if render_call_depth >= render_state_array.length() {
        let render_state = WebGLRenderState::new(self.extensions)
        render_state_array.push(render_state)
        render_state
      } else {
        render_state_array[render_call_depth]
      }
  }
}

///|
/// `renderStates.dispose()`.
pub fn WebGLRenderStates::dispose(self : WebGLRenderStates) -> Unit {
  self.render_states = WeakMap::new()
}
