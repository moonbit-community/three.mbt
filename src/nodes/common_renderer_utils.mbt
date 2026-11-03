// renderers/common/RendererUtils.js: saving, resetting and restoring renderer and scene
// state around nested renders.

///|
/// The state object of `saveRendererState` / `saveSceneState`.
pub(all) struct RendererState {
  mut tone_mapping : Int32
  mut tone_mapping_exposure : Double
  mut output_color_space : String
  mut render_target : @core.RenderTarget?
  mut active_cube_face : Int32
  mut active_mipmap_level : Int32
  mut render_object_function : RenderObjectFunction?
  mut pixel_ratio : Double
  mut mrt : Node?
  /// `state.clearColor`; reused by later saves.
  mut clear_color : @math.Color?
  mut clear_alpha : Double
  mut auto_clear : Bool
  mut auto_clear_color : Bool
  mut auto_clear_depth : Bool
  mut auto_clear_stencil : Bool
  mut opaque_ : Bool
  mut transparent : Bool
  mut scissor_test : Bool
  mut background : @core.SceneBackground?
  mut background_node : @core.JsValue?
  mut override_material : @core.Material?
}

///|
/// `{}`.
pub fn RendererState::new() -> RendererState {
  {
    tone_mapping: 0,
    tone_mapping_exposure: 0.0,
    output_color_space: "",
    render_target: None,
    active_cube_face: 0,
    active_mipmap_level: 0,
    render_object_function: None,
    pixel_ratio: 0.0,
    mrt: None,
    clear_color: None,
    clear_alpha: 0.0,
    auto_clear: false,
    auto_clear_color: false,
    auto_clear_depth: false,
    auto_clear_stencil: false,
    opaque_: false,
    transparent: false,
    scissor_test: false,
    background: None,
    background_node: None,
    override_material: None,
  }
}

///|
/// `saveRendererState( renderer, state = {} )`.
pub fn save_renderer_state(
  renderer : Renderer,
  state? : RendererState,
) -> RendererState {
  let state = match state {
    Some(s) => s
    None => RendererState::new()
  }
  state.tone_mapping = renderer.tone_mapping
  state.tone_mapping_exposure = renderer.tone_mapping_exposure
  state.output_color_space = renderer.output_color_space
  state.render_target = renderer.get_render_target()
  state.active_cube_face = renderer.get_active_cube_face()
  state.active_mipmap_level = renderer.get_active_mipmap_level()
  state.render_object_function = renderer.get_render_object_function()
  state.pixel_ratio = renderer.get_pixel_ratio()
  state.mrt = renderer.get_mrt()
  state.clear_color = Some(
    renderer.get_clear_color(
      match state.clear_color {
        Some(c) => c
        None => @math.Color::new(1.0, 1.0, 1.0)
      },
    ),
  )
  state.clear_alpha = renderer.get_clear_alpha()
  state.auto_clear = renderer.auto_clear
  state.auto_clear_color = renderer.auto_clear_color
  state.auto_clear_depth = renderer.auto_clear_depth
  state.auto_clear_stencil = renderer.auto_clear_stencil
  state.opaque_ = renderer.opaque_
  state.transparent = renderer.transparent
  state.scissor_test = renderer.get_scissor_test()
  state
}

///|
/// `resetRendererState( renderer, state )`: saves, then resets to the defaults.
pub fn reset_renderer_state(
  renderer : Renderer,
  state? : RendererState,
) -> RendererState {
  let state = save_renderer_state(renderer, state?)
  renderer.set_mrt(None) |> ignore
  renderer.set_render_object_function(None)
  renderer.set_clear_color_hex(0x000000, alpha=1.0)
  renderer.auto_clear = true
  renderer.auto_clear_color = true
  renderer.auto_clear_depth = true
  renderer.auto_clear_stencil = true
  renderer.opaque_ = true
  renderer.transparent = true
  state
}

///|
/// `restoreRendererState( renderer, state )`.
pub fn restore_renderer_state(
  renderer : Renderer,
  state : RendererState,
) -> Unit {
  renderer.tone_mapping = state.tone_mapping
  renderer.tone_mapping_exposure = state.tone_mapping_exposure
  renderer.output_color_space = state.output_color_space
  renderer.set_render_target(
    state.render_target,
    active_cube_face=state.active_cube_face,
    active_mipmap_level=state.active_mipmap_level,
  )
  renderer.set_render_object_function(state.render_object_function)
  renderer.set_pixel_ratio(state.pixel_ratio)
  renderer.set_mrt(state.mrt) |> ignore
  match state.clear_color {
    Some(c) => renderer.set_clear_color(c, alpha=state.clear_alpha)
    None => abort("restoreRendererState: the state has no clearColor")
  }
  renderer.auto_clear = state.auto_clear
  renderer.auto_clear_color = state.auto_clear_color
  renderer.auto_clear_depth = state.auto_clear_depth
  renderer.auto_clear_stencil = state.auto_clear_stencil
  renderer.opaque_ = state.opaque_
  renderer.transparent = state.transparent
  renderer.set_scissor_test(state.scissor_test)
}

///|
fn _renderer_utils_scene(scene : @core.Object3D) -> @core.Scene {
  match scene.kind {
    Scene(s) => s
    _ => abort("RendererUtils: not a Scene")
  }
}

///|
/// `saveSceneState( scene, state = {} )`.
pub fn save_scene_state(
  scene : @core.Object3D,
  state? : RendererState,
) -> RendererState {
  let state = match state {
    Some(s) => s
    None => RendererState::new()
  }
  let s = _renderer_utils_scene(scene)
  state.background = s.background
  state.background_node = s.background_node
  state.override_material = s.override_material
  state
}

///|
/// `resetSceneState( scene, state )`: saves, then clears background and override.
pub fn reset_scene_state(
  scene : @core.Object3D,
  state? : RendererState,
) -> RendererState {
  let state = save_scene_state(scene, state?)
  let s = _renderer_utils_scene(scene)
  s.background = None
  s.background_node = None
  s.override_material = None
  state
}

///|
/// `restoreSceneState( scene, state )`.
pub fn restore_scene_state(
  scene : @core.Object3D,
  state : RendererState,
) -> Unit {
  let s = _renderer_utils_scene(scene)
  s.background = state.background
  s.background_node = state.background_node
  s.override_material = state.override_material
}

///|
/// `saveRendererAndSceneState( renderer, scene, state = {} )`.
pub fn save_renderer_and_scene_state(
  renderer : Renderer,
  scene : @core.Object3D,
  state? : RendererState,
) -> RendererState {
  let state = save_renderer_state(renderer, state?)
  save_scene_state(scene, state~)
}

///|
/// `resetRendererAndSceneState( renderer, scene, state )`.
pub fn reset_renderer_and_scene_state(
  renderer : Renderer,
  scene : @core.Object3D,
  state? : RendererState,
) -> RendererState {
  let state = reset_renderer_state(renderer, state?)
  reset_scene_state(scene, state~)
}

///|
/// `restoreRendererAndSceneState( renderer, scene, state )`.
pub fn restore_renderer_and_scene_state(
  renderer : Renderer,
  scene : @core.Object3D,
  state : RendererState,
) -> Unit {
  restore_renderer_state(renderer, state)
  restore_scene_state(scene, state)
}
