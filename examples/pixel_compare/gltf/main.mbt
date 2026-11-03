// The MoonBit half of the glTF pixel comparison (gltf.html): the scenes of
// gltf_scenes.js, line for line. Each loads a model with the port's GLTFLoader (Draco
// through the port's DRACOLoader), poses animated models at a fixed time with an
// AnimationMixer, renders with the port's WebGPURenderer into a render target and reads
// the pixels back.

///|
const WIDTH : Int32 = 128

///|
const HEIGHT : Int32 = 96

///|
const MODELS : String = "../../.repos/three.js/examples/models/gltf/"

///|
const DRACO_PATH : String = "../../.repos/three.js/examples/jsm/libs/draco/gltf/"

///|
let names : Array[String] = [
  "damaged_helmet", "draco_duck", "skinned_robot", "skinned_soldier", "draco_tokyo",
]

///|
/// The scene names, in page order.
pub fn scene_names() -> Array[String] {
  names
}

///|
/// A scene description: model, camera, look-at target, animation and time.
priv struct Setup {
  url : String
  camera : (Double, Double, Double)
  target : (Double, Double, Double)
  clip : String?
  time : Double
}

///|
fn setup(name : String) -> Setup? {
  match name {
    "damaged_helmet" =>
      Some({
        url: MODELS + "DamagedHelmet/glTF/DamagedHelmet.gltf",
        camera: (1.2, 0.6, 2.6),
        target: (0.0, 0.0, 0.0),
        clip: None,
        time: 0.0,
      })
    "draco_duck" =>
      Some({
        url: MODELS + "duck.glb",
        camera: (0.25, 0.2, 0.35),
        target: (0.0, 0.09, 0.02),
        clip: None,
        time: 0.0,
      })
    "skinned_robot" =>
      Some({
        url: MODELS + "RobotExpressive/RobotExpressive.glb",
        camera: (2.0, 3.0, 8.0),
        target: (0.0, 2.2, 0.0),
        clip: Some("Dance"),
        time: 1.25,
      })
    "skinned_soldier" =>
      Some({
        url: MODELS + "Soldier.glb",
        camera: (1.0, 1.4, 3.2),
        target: (0.0, 0.9, 0.0),
        clip: Some("Walk"),
        time: 0.4,
      })
    "draco_tokyo" =>
      Some({
        url: MODELS + "LittlestTokyo.glb",
        camera: (300.0, 250.0, 500.0),
        target: (0.0, 50.0, 0.0),
        clip: Some("Take 001"),
        time: 2.0,
      })
    _ => None
  }
}

///|
/// Builds the scene around the loaded asset: lights, camera, the posed animation.
fn build(s : Setup, gltf : @gltf.GLTFResult) -> (@three.Object3D, @three.Object3D) {
  let scene = @three.Scene::new()
  scene.as_scene().background = Some(Color(@three.Color::from_hex(0x334455)))
  scene.add(
    @three.HemisphereLight::new(
      sky_color=@three.Color::from_hex(0xffffff),
      ground_color=@three.Color::from_hex(0x444444),
      intensity=1.5,
    ),
  )
  |> ignore
  let sun = @three.DirectionalLight::new(
    color=@three.Color::from_hex(0xffffff),
    intensity=2.5,
  )
  sun.position.set(3.0, 5.0, 4.0) |> ignore
  scene.add(sun) |> ignore
  let model = gltf.scene.unwrap()
  scene.add(model) |> ignore
  if s.clip is Some(clip_name) {
    let mixer = @three.AnimationMixer::new(model)
    match @three.AnimationClip::find_by_name(gltf.animations, clip_name) {
      Some(clip) => mixer.clip_action(clip).play() |> ignore
      None => abort("no clip " + clip_name)
    }
    mixer.update(s.time) |> ignore
  }
  let camera = @three.PerspectiveCamera::new(
    fov=45.0,
    aspect=WIDTH.to_double() / HEIGHT.to_double(),
    near=0.01,
    far=2000.0,
  )
  camera.position.set(s.camera.0, s.camera.1, s.camera.2) |> ignore
  camera.look_at_xyz(s.target.0, s.target.1, s.target.2)
  (scene, camera)
}

///|
/// Renders scene `name` into `canvas` and passes the pixels (or `null` for an unknown
/// name) to `done`; `fail` receives a loading error.
pub fn render_scene(
  name : String,
  canvas : @three.JsValue,
  done : (@three.JsValue) -> Unit,
  fail : (@three.JsValue) -> Unit,
  force_webgl~ : Bool = false,
) -> Unit {
  guard setup(name) is Some(s) else { done(@three.JsValue::null()) }
  let draco = @gltf.DRACOLoader::new()
  draco.set_decoder_path(DRACO_PATH) |> ignore
  let loader = @gltf.GLTFLoader::new().set_draco_loader(draco)
  loader.load(
    s.url,
    fn(gltf) {
      draco.dispose() |> ignore
      let (scene, camera) = build(s, gltf)
      let renderer = @three.WebGPURenderer::new(
        canvas~,
        antialias=false,
        force_webgl~,
      )
      renderer.set_pixel_ratio(1.0)
      renderer.set_size(WIDTH.to_double(), HEIGHT.to_double(), update_style=false)
      renderer.init(on_done=fn(_) {
        let target = @three.RenderTarget::new(width=WIDTH, height=HEIGHT)
        renderer.set_render_target(Some(target))
        renderer.render(scene, camera)
        renderer.read_render_target_pixels_async(target, 0, 0, WIDTH, HEIGHT, fn(
          pixels,
        ) {
          let result = match pixels {
            Some(p) => @three.JsValue::of(p)
            None => @three.JsValue::null()
          }
          renderer.dispose(on_done=fn() { done(result) })
        })
      })
    },
    on_error=fn(e) {
      draco.dispose() |> ignore
      fail(e)
    },
  )
}

///|
fn main {

}
