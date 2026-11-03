// Types for upstream src/scenes.

///|
pub(all) struct Fog {
  mut name : String
  mut color : @math.Color
  mut near : Double
  mut far : Double
}

///|
pub(all) struct FogExp2 {
  mut name : String
  mut color : @math.Color
  mut density : Double
}

///|
/// `scene.fog`.
pub(all) enum SceneFog {
  Fog(Fog)
  FogExp2(FogExp2)
}

///|
/// `scene.background`.
pub(all) enum SceneBackground {
  Color(@math.Color)
  Texture(Texture)
}

///|
pub(all) struct Scene {
  mut background : SceneBackground?
  mut environment : Texture?
  mut fog : SceneFog?
  mut background_blurriness : Double
  mut background_intensity : Double
  mut background_rotation : @math.Euler
  mut environment_intensity : Double
  mut environment_rotation : @math.Euler
  mut override_material : Material?
  /// Upstream's dynamic `backgroundNode`, `environmentNode`, `fogNode`: `nodes` values.
  mut background_node : JsValue?
  mut environment_node : JsValue?
  mut fog_node : JsValue?
  /// `scene.onBeforeRender( renderer, scene, camera, renderTarget )`, which the renderer
  /// calls with other arguments than `Object3D.on_before_render`.
  mut on_before_render : (JsValue, Object3D, Object3D, RenderTarget?) -> Unit
  /// `scene.onAfterRender( renderer, scene, camera )`.
  mut on_after_render : (JsValue, Object3D, Object3D) -> Unit
}
