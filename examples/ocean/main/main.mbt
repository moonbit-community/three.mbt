// Golden hour on the open sea, built from the MoonBit port's add-ons: SkyMesh (atmospheric
// scattering with clouds) over WaterMesh (reflections and sun glitter), a flotilla of
// rubber ducks loaded with GLTFLoader and bobbing on the swell, a chrome torus knot that
// mirrors the sky, OrbitControls, and TSL bloom on the glare. Whenever the sun moves the
// sky is re-baked through PMREMGenerator so every reflection follows it.

///|
const ASSETS : String = "../../.repos/three.js/examples/"

///|
const DUCKS : Int32 = 7

///|
struct App {
  renderer : @nodes.Renderer
  camera : @core.Object3D
}

///|
let app : Ref[App?] = { val: None, }

///|
/// Sun position in degrees: elevation above the horizon and azimuth.
let elevation : Ref[Double] = { val: 4.0, }

///|
let azimuth : Ref[Double] = { val: 180.0, }

///|
/// While true the sun drifts through sunset on its own.
let cycle : Ref[Bool] = { val: true, }

///|
/// Set by the sliders; the frame loop re-bakes the sky when it sees it.
let sun_dirty : Ref[Bool] = { val: true, }

///|
let sky_ref : Ref[@core.Object3D?] = { val: None, }

///|
fn deg(d : Double) -> Double {
  d * @cmath.PI / 180.0
}

///|
pub fn start(
  canvas : @core.JsValue,
  width : Double,
  height : Double,
  pixel_ratio : Double,
  on_ready : (String?, String) -> Unit,
) -> Unit {
  let renderer = @webgpu.WebGPURenderer::new(canvas~)
  renderer.set_pixel_ratio(pixel_ratio)
  renderer.set_size(width, height, update_style=false)
  renderer.tone_mapping = @core.ACESFilmicToneMapping
  renderer.tone_mapping_exposure = 0.12
  let scene = @core.Scene::new()
  let camera = @core.PerspectiveCamera::new(
    fov=55.0,
    aspect=width / height,
    near=1.0,
    far=20000.0,
  )
  camera.position.set(70.0, 24.0, 130.0) |> ignore
  app.val = Some({ renderer, camera, })

  // Water: a huge plane whose normal map scrolls; it reflects the sky and the floaters.
  let water_normals = @loaders.TextureLoader::new().load(
    ASSETS + "textures/waternormals.jpg",
  )
  water_normals.wrap_s = @core.RepeatWrapping
  water_normals.wrap_t = @core.RepeatWrapping
  let water = @objects.WaterMesh::new(
    Some(@geometries.PlaneGeometry::new(width=10000.0, height=10000.0)),
    water_normals~,
    sun_direction=@math.Vector3::new(0.0, 1.0, 0.0),
    sun_color=0xffffff,
    water_color=0x001e0f,
    distortion_scale=3.7,
  )
  water.rotation.set(-@cmath.PI / 2.0, 0.0, 0.0) |> ignore
  scene.add(water) |> ignore
  let water_data = @objects.WaterMesh::of(water).unwrap()

  // Sky: Preetham-style scattering with procedural clouds.
  let sky = @objects.SkyMesh::new()
  sky.scale.set(10000.0, 10000.0, 10000.0) |> ignore
  scene.add(sky) |> ignore
  sky_ref.val = Some(sky)
  let sky_data = @objects.SkyMesh::of(sky).unwrap()
  @nodes.InputNode::set_value(sky_data.turbidity, Number(10.0))
  @nodes.InputNode::set_value(sky_data.rayleigh, Number(2.0))
  @nodes.InputNode::set_value(sky_data.mie_coefficient, Number(0.005))
  @nodes.InputNode::set_value(sky_data.mie_directional_g, Number(0.8))
  @nodes.InputNode::set_value(sky_data.cloud_coverage, Number(0.4))
  @nodes.InputNode::set_value(sky_data.cloud_density, Number(0.5))
  @nodes.InputNode::set_value(sky_data.cloud_elevation, Number(0.5))

  // A chrome torus knot: a mirror for the baked sky.
  let chrome = @core.MeshStandardMaterial::new()
  chrome.roughness = Some(0.05)
  chrome.metalness = Some(1.0)
  let knot = @core.Mesh::new(
    geometry=@geometries.TorusKnotGeometry::new(
      radius=11.0,
      tube=3.2,
      tubular_segments=200.0,
      radial_segments=32.0,
    ),
    material=Single(chrome),
  )
  scene.add(knot) |> ignore

  // The flotilla: one duck loaded, the rest cloned, spread on a slowly turning ring.
  let ducks : Array[@core.Object3D] = []
  // duck.glb is Draco-compressed: decode it with the vendored wasm decoder.
  let draco = @addon_loaders.DRACOLoader::new().set_decoder_path(
    ASSETS + "jsm/libs/draco/gltf/",
  )
  let gltf_loader = @addon_loaders.GLTFLoader::new().set_draco_loader(draco)
  gltf_loader.load(ASSETS + "models/gltf/duck.glb", fn(gltf) {
    guard gltf.scene is Some(model) else { return }
    model.scale.set(48.0, 48.0, 48.0) |> ignore
    for i in 0..<DUCKS {
      let duck = if i == 0 { model } else { model.clone() }
      scene.add(duck) |> ignore
      ducks.push(duck)
    }
  })

  // Orbit, kept above the water.
  let controls = @controls.OrbitControls::new(camera, dom_element=canvas)
  controls.max_polar_angle = @cmath.PI * 0.495
  controls.target.set(0.0, 12.0, 0.0) |> ignore
  controls.min_distance = 40.0
  controls.max_distance = 320.0
  controls.enable_damping = true
  controls.update() |> ignore

  // Scene pass + bloom for the glare on the water and the knot.
  @tsl.load_display_bloom_node()
  let pipeline = @nodes.RenderPipeline::new(renderer)
  let scene_pass = @nodes.pass(scene, camera)
  let scene_color = scene_pass.get_texture_node()
  pipeline.output_node = scene_color.add(
    @tsl.bloom(scene_color, strength=0.18, radius=0.2, threshold=0.0),
  )

  // Re-bakes the sky into PMREM for the environment whenever the sun moved.
  let pmrem = @nodes.PMREMGenerator::new(renderer)
  let env_scene = @core.Scene::new()
  let env_target : Ref[@core.RenderTarget?] = { val: None, }
  let sun = @math.Vector3::new(0.0, 0.0, 0.0)
  let update_sun = fn() {
    sun.set_from_spherical_coords(
      1.0,
      deg(90.0 - elevation.val),
      deg(azimuth.val),
    )
    |> ignore
    @nodes.InputNode::set_value(sky_data.sun_position, Vector3(sun.clone()))
    @nodes.InputNode::set_value(
      water_data.sun_direction,
      Vector3(sun.clone().normalize()),
    )
    // Bake into the same render target every time. A new target per bake would give
    // `scene.environment` a new texture, and every lit material would recompile its
    // pipelines mid-animation: a visible hitch twice a second.
    env_scene.add(sky) |> ignore
    let target = pmrem.from_scene(env_scene, render_target?=env_target.val)
    scene.add(sky) |> ignore
    scene.as_scene().environment = Some(target.texture())
    env_target.val = Some(target)
  }
  renderer.init(on_done=fn(error) {
    if error is Some(_) {
      on_ready(error, "")
      return
    }
    let mut last_bake = -1.0
    renderer.set_animation_loop(
      Some(fn(now, _) {
        let t = now / 1000.0
        if cycle.val {
          // From late afternoon through sunset to dusk and back, every ~70 s.
          elevation.val = 5.5 + 6.5 * @cmath.sin(t * 0.09)
          // The sky is re-baked at most twice a second while it drifts.
          if t - last_bake > 0.5 {
            sun_dirty.val = true
          }
        }
        if sun_dirty.val {
          update_sun()
          sun_dirty.val = false
          last_bake = t
        }
        for i, duck in ducks {
          let phase = i.to_double() * 0.9
          let angle = t * 0.04 +
            i.to_double() * 2.0 * @cmath.PI / DUCKS.to_double()
          let r = 38.0 + 6.0 * @cmath.sin(t * 0.3 + phase)
          duck.position.set(
            r * @cmath.cos(angle),
            1.2 * @cmath.sin(t * 1.3 + phase),
            r * @cmath.sin(angle),
          )
          |> ignore
          // Face along the ring and rock with the swell.
          duck.rotation.set(
            0.12 * @cmath.sin(t * 1.1 + phase),
            -angle + @cmath.PI,
            0.1 * @cmath.sin(t * 0.9 + phase * 2.0),
          )
          |> ignore
        }
        knot.position.set(0.0, 26.0 + 4.0 * @cmath.sin(t * 0.7), 0.0) |> ignore
        knot.rotation.set(t * 0.3, t * 0.37, 0.0) |> ignore
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
pub fn resize(width : Double, height : Double) -> Unit {
  guard app.val is Some({ renderer, camera, }) else { return }
  renderer.set_size(width, height, update_style=false)
  camera.as_perspective_camera().aspect = width / height
  camera.update_projection_matrix()
}

///|
/// Moves the sun (degrees) and stops the automatic cycle.
pub fn set_sun(elevation_deg : Double, azimuth_deg : Double) -> Unit {
  elevation.val = elevation_deg
  azimuth.val = azimuth_deg
  cycle.val = false
  sun_dirty.val = true
}

///|
pub fn set_cycle(on : Bool) -> Unit {
  cycle.val = on
}

///|
pub fn set_exposure(exposure : Double) -> Unit {
  guard app.val is Some({ renderer, .. }) else { return }
  renderer.tone_mapping_exposure = exposure
}

///|
pub fn set_clouds(coverage : Double) -> Unit {
  guard sky_ref.val is Some(sky) else { return }
  @nodes.InputNode::set_value(
    @objects.SkyMesh::of(sky).unwrap().cloud_coverage,
    Number(coverage),
  )
  sun_dirty.val = true
}

///|
fn main {

}
