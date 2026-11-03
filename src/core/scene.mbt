// Upstream src/scenes/Scene.js. `Scene` is the payload struct, so `Scene::new` returns
// the `Object3D` that holds it.

///|
/// `new Scene()`.
pub fn Scene::new() -> Object3D {
  Object3D::new(
    kind=Scene({
      background: None,
      environment: None,
      fog: None,
      background_blurriness: 0.0,
      background_intensity: 1.0,
      background_rotation: @math.Euler::new(0.0, 0.0, 0.0),
      environment_intensity: 1.0,
      environment_rotation: @math.Euler::new(0.0, 0.0, 0.0),
      override_material: None,
      background_node: None,
      environment_node: None,
      fog_node: None,
      on_before_render: (_, _, _, _) => (),
      on_after_render: (_, _, _) => (),
    }),
    type_="Scene",
  )
}

///|
/// The `Scene` data. Aborts on other kinds.
pub fn Object3D::as_scene(self : Object3D) -> Scene {
  guard self.kind is Scene(scene) else { abort("Object3D: not a scene") }
  scene
}

///|
/// `scene.onBeforeRender = callback`. Aborts on other kinds.
pub fn Object3D::set_scene_on_before_render(
  self : Object3D,
  callback : (JsValue, Object3D, Object3D, RenderTarget?) -> Unit,
) -> Unit {
  self.as_scene().on_before_render = callback
}

///|
/// `scene.onAfterRender = callback`. Aborts on other kinds.
pub fn Object3D::set_scene_on_after_render(
  self : Object3D,
  callback : (JsValue, Object3D, Object3D) -> Unit,
) -> Unit {
  self.as_scene().on_after_render = callback
}

///|
pub fn SceneFog::clone(self : SceneFog) -> SceneFog {
  match self {
    Fog(fog) => Fog(fog.clone())
    FogExp2(fog) => FogExp2(fog.clone())
  }
}

///|
pub fn SceneFog::to_json(self : SceneFog) -> Json {
  match self {
    Fog(fog) => fog.to_json()
    FogExp2(fog) => fog.to_json()
  }
}

///|
pub fn SceneBackground::clone(self : SceneBackground) -> SceneBackground {
  match self {
    Color(color) => Color(color.clone())
    Texture(texture) => Texture(texture.clone())
  }
}

///|
/// `new this.constructor()`.
fn hook_scene_new_like(_object : Object3D) -> Object3D {
  Scene::new()
}

///|
/// Upstream `copy`.
fn hook_scene_copy(
  object : Object3D,
  source : Object3D,
  recursive : Bool,
) -> Unit {
  object.copy_base(source, recursive)
  let scene = object.as_scene()
  let source_scene = source.as_scene()
  scene.background = match source_scene.background {
    Some(background) => Some(background.clone())
    None => None
  }
  scene.environment = match source_scene.environment {
    Some(environment) => Some(environment.clone())
    None => None
  }
  scene.fog = match source_scene.fog {
    Some(fog) => Some(fog.clone())
    None => None
  }
  scene.background_blurriness = source_scene.background_blurriness
  scene.background_intensity = source_scene.background_intensity
  ignore(scene.background_rotation.copy(source_scene.background_rotation))
  scene.environment_intensity = source_scene.environment_intensity
  ignore(scene.environment_rotation.copy(source_scene.environment_rotation))
  scene.override_material = match source_scene.override_material {
    Some(material) => Some(material.clone())
    None => None
  }
  object.matrix_auto_update = source.matrix_auto_update
}

///|
/// Upstream `toJSON`.
fn hook_scene_to_json(
  object : Object3D,
  _meta : ToJsonMeta,
  data : Map[String, Json],
) -> Unit {
  let scene = object.as_scene()
  if scene.fog is Some(fog) {
    data["fog"] = fog.to_json()
  }
  data["backgroundBlurriness"] = @math.json_number(scene.background_blurriness)
  data["backgroundIntensity"] = @math.json_number(scene.background_intensity)
  data["backgroundRotation"] = Json::array(scene.background_rotation.to_array())
  data["environmentIntensity"] = @math.json_number(scene.environment_intensity)
  data["environmentRotation"] = Json::array(
    scene.environment_rotation.to_array(),
  )
}
