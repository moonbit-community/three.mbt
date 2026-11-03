// A product-style showroom built from the MoonBit port's add-ons: the DamagedHelmet glTF
// (GLTFLoader), lit and backed by an HDR sky (HDRLoader through PMREM), orbited with
// OrbitControls, and rendered through a RenderPipeline that adds TSL bloom to its emissive
// panels. Rendering is the port's WebGPURenderer.

///|
/// Assets are served from the three.js checkout next to the port.
const ASSETS : String = "../../.repos/three.js/examples/"

///|
struct App {
  renderer : @nodes.Renderer
  camera : @core.Object3D
}

///|
let app : Ref[App?] = { val: None, }

///|
let controls_ref : Ref[@controls.OrbitControls?] = { val: None, }

///|
/// Bloom strength, a uniform so the slider can change it without rebuilding the pipeline.
let bloom_strength : @nodes.Node = @nodes.uniform(0.45)

///|
/// Creates the renderer on `canvas` (CSS size `width` x `height`), loads the HDR sky and
/// the helmet, and starts rendering. `on_ready` gets an error message or `None`, plus the
/// backend name.
pub fn start(
  canvas : @core.JsValue,
  width : Double,
  height : Double,
  pixel_ratio : Double,
  on_ready : (String?, String) -> Unit,
) -> Unit {
  let renderer = @webgpu.WebGPURenderer::new(canvas~, antialias=true)
  renderer.set_pixel_ratio(pixel_ratio)
  renderer.set_size(width, height, update_style=false)
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  renderer.tone_mapping_exposure = 1.0
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(
    fov=45.0,
    aspect=width / height,
    near=0.25,
    far=20.0,
  )
  camera.position.set(-1.8, 0.6, 2.7) |> ignore
  app.val = Some({ renderer, camera, })

  // HDR sky: the environment lights the PBR materials, the blurred background frames them.
  @loaders.HDRLoader::new().load(
    ASSETS + "textures/equirectangular/venice_sunset_1k.hdr",
    on_load=fn(texture, _) {
      texture.mapping = @core.EquirectangularReflectionMapping
      let s = scene.as_scene()
      s.background = Some(Texture(texture))
      s.environment = Some(texture)
      s.background_blurriness = 0.35
    },
  )
  |> ignore

  // The helmet.
  @loaders.GLTFLoader::new().load(
    ASSETS + "models/gltf/DamagedHelmet/glTF/DamagedHelmet.gltf",
    fn(gltf) { if gltf.scene is Some(model) { scene.add(model) |> ignore } },
  )

  // Orbit with damping; slow auto-rotation until the user takes over.
  let controls = @controls.OrbitControls::new(camera, dom_element=canvas)
  controls.enable_damping = true
  controls.auto_rotate = true
  controls.auto_rotate_speed = 0.8
  controls.min_distance = 2.0
  controls.max_distance = 10.0
  controls.target.set(0.0, 0.0, -0.2) |> ignore
  controls.update() |> ignore
  controls_ref.val = Some(controls)

  // Scene pass plus bloom, which picks up the emissive visor and panels.
  @tsl.load_display_bloom_node()
  let pipeline = @nodes.RenderPipeline::new(renderer)
  let scene_pass = @nodes.pass(scene, camera)
  let scene_color = scene_pass.get_texture_node()
  pipeline.output_node = scene_color.add(
    @tsl.bloom(scene_color, strength=bloom_strength, radius=0.3, threshold=0.85),
  )
  renderer.init(on_done=fn(error) {
    if error is Some(_) {
      on_ready(error, "")
      return
    }
    renderer.set_animation_loop(
      Some(fn(_, _) {
        controls.update() |> ignore
        pipeline.render()
      }),
    )
    let backend = if renderer.backend.has_flag("isWebGPUBackend") {
      "WebGPU"
    } else {
      "WebGL 2 (fallback)"
    }
    on_ready(None, backend)
  })
}

///|
/// Follows a new CSS size of the canvas.
pub fn resize(width : Double, height : Double) -> Unit {
  guard app.val is Some({ renderer, camera, }) else { return }
  renderer.set_size(width, height, update_style=false)
  camera.as_perspective_camera().aspect = width / height
  camera.update_projection_matrix()
}

///|
/// Sets the bloom strength (0 turns it off).
pub fn set_bloom(strength : Double) -> Unit {
  @nodes.InputNode::set_value(bloom_strength, Number(strength))
}

///|
pub fn set_auto_rotate(on : Bool) -> Unit {
  if controls_ref.val is Some(controls) {
    controls.auto_rotate = on
  }
}

///|
fn main {

}
