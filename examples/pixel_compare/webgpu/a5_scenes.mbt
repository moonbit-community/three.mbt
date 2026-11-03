// The add-on scenes of TSL agent A5 in the WebGPU pixel comparison (examples/jsm/tsl/display,
// tsl/lighting, tsl/shadows), mirroring webgpu_a5_scenes.js line for line; `build_addon`
// falls through to `build_a5_addon` and `load_addons` to `load_a5_addons`. The stage helpers
// (`camera_at`, `colored`, `mesh`, `view`, `addon_stage`) are main.mbt's.

///|
let a5_scene_names : Array[String] = [
  "addon_bloom", "addon_smaa", "addon_ssao", "addon_outline", "addon_film", "addon_chromatic_aberration",
  "addon_lut3d", "addon_after_image", "addon_traa", "addon_tile_shadow", "addon_dynamic_lights",
]

///|
/// The modules of `A5_ADDON_MODULES`, loaded in import order. False for other scenes.
fn load_a5_addons(name : String) -> Bool {
  match name {
    "addon_bloom" => @tsl.load_display_bloom_node()
    "addon_smaa" => @tsl.load_display_smaa_node()
    "addon_ssao" => @tsl.load_display_ssao_node()
    "addon_outline" => @tsl.load_display_outline_node()
    "addon_after_image" => @tsl.load_display_after_image_node()
    "addon_traa" => @tsl.load_display_traa_node()
    // no module-level state
    "addon_film"
    | "addon_chromatic_aberration"
    | "addon_lut3d"
    | "addon_tile_shadow"
    | "addon_dynamic_lights" => ()
    _ => return false
  }
  true
}

///|
/// `a5View( THREE, output, frames, step )`: the stage rendered `frames` times (one animation
/// frame each) through a
/// RenderPipeline whose output is `output(scene, camera)`.
fn a5_view(
  output : (@three.Object3D, @three.Object3D) -> @three.Node,
  frames~ : Int32 = 1,
  step? : (Int32, @three.Object3D) -> Unit,
) -> View {
  let scene = @three.Scene::new()
  let camera = addon_stage(scene)
  view(scene, camera, render=fn(renderer) {
    let pipeline = @three.RenderPipeline::new(renderer)
    pipeline.output_node = output(scene, camera)
    for i in 0..<frames {
      if i > 0 {
        a5_tick(renderer)
      }
      if i > 0 && step is Some(step) {
        step(i, scene)
      }
      pipeline.render()
    }
  })
}

///|
/// `a5Tick( renderer )`: one animation frame inside the synchronous render, the body of
/// Animation's `update`, so FRAME-updated nodes run again.
fn a5_tick(renderer : @three.Renderer) -> Unit {
  if renderer.info.auto_reset {
    renderer.info.reset()
  }
  let frame = renderer._nodes.unwrap().node_frame
  frame.update()
  renderer.info.frame = frame.frame_id
}

///|
/// `a5Move`: moves the box between frames.
fn a5_move(i : Int32, scene : @three.Object3D) -> Unit {
  let box = scene.children[0]
  box.rotation.set_y(box.rotation.y + 0.15)
  box.position.x = -0.6 + 0.04 * i.to_double()
}

///|
/// `examples/jsm/lighting/DynamicLighting.js`'s `createNode`.
priv struct A5DynamicLighting {}

///|
impl @nodes.LightingClass for A5DynamicLighting with fn create_node(
  _,
  _,
  lights,
) {
  @three.LightsNode::set_lights(
    @tsl.DynamicLightsNode::new(max_point_lights=4),
    lights,
  )
}

///|
/// The scenes; `None` for other names.
fn build_a5_addon(name : String) -> View? {
  match name {
    "addon_bloom" =>
      Some(
        a5_view(fn(scene, camera) {
          let scene_pass = @three.pass(scene, camera)
          scene_pass.add(
            @tsl.bloom(scene_pass, strength=1.5, radius=0.4, threshold=0.3),
          )
        }),
      )
    "addon_smaa" =>
      // (the area and search images decode asynchronously: both sides render before
      // they have loaded)
      Some(a5_view(fn(scene, camera) { @tsl.smaa(@three.pass(scene, camera)) }))
    "addon_ssao" =>
      Some(
        a5_view(fn(scene, camera) {
          let scene_pass = @three.pass(scene, camera)
          scene_pass.set_mrt(
            Some(
              @three.mrt({
                "output": @three.output,
                "normal": @three.normal_view,
              }),
            ),
          )
          |> ignore
          let ao_node = @tsl.ssao(
            scene_pass.get_texture_node(name="depth"),
            scene_pass.get_texture_node(name="normal"),
            camera,
          )
          @three.vec4_of([
            scene_pass.get_texture_node(name="output").rgb().mul(ao_node.r()),
            1,
          ])
        }),
      )
    "addon_outline" =>
      Some(
        a5_view(fn(scene, camera) {
          let outline_node = @tsl.outline(
            scene,
            camera,
            selected_objects=[scene.children[1]],
            edge_thickness=@three.uniform(1.5),
            edge_glow=@three.uniform(0.5),
          )
          let color = @tsl.OutlineNode::visible_edge(outline_node)
            .mul(@three.color(0xffffff))
            .add(
              @tsl.OutlineNode::hidden_edge(outline_node).mul(
                @three.color(0x4400ff),
              ),
            )
            .mul(4)
          @three.pass(scene, camera).add(@three.vec4_of([color, 0]))
        }),
      )
    "addon_film" =>
      // intensity 0: the grain reads the `time` uniform, which differs between the sides
      Some(
        a5_view(fn(scene, camera) {
          @tsl.film(
            @three.pass(scene, camera),
            intensity_node=@three.uniform(0),
          )
        }),
      )
    "addon_chromatic_aberration" =>
      Some(
        a5_view(fn(scene, camera) {
          @tsl.chromatic_aberration(
            @three.pass(scene, camera),
            strength=2,
            center=@three.vec2_of([0.4, 0.6]),
            scale=1.1,
          )
        }),
      )
    "addon_lut3d" =>
      Some(
        a5_view(fn(scene, camera) {
          let size = 8
          let data = @three.TypedArray::uint8(size * size * size * 4)
          for z in 0..<size {
            for y in 0..<size {
              for x in 0..<size {
                let i = ((z * size + y) * size + x) * 4
                data.set(i, (255 * y / (size - 1)).to_double())
                data.set(i + 1, (255 * z / (size - 1)).to_double())
                data.set(i + 2, (255 * x / (size - 1)).to_double())
                data.set(i + 3, 255.0)
              }
            }
          }
          let lut = @three.Data3DTexture::new(
            data~,
            width=size,
            height=size,
            depth=size,
          )
          // (nearest, the default: the port's 2D textures carry wrapR = ClampToEdge where
          // upstream's have none, so a linear clamped LUT would share the 2D textures'
          // sampler in the port; see the A5 report)
          lut.set_needs_update(true)
          @tsl.lut3_d(
            @three.pass(scene, camera),
            @three.texture3d(lut),
            size,
            @three.uniform(0.75),
          )
        }),
      )
    "addon_after_image" =>
      Some(
        a5_view(
          fn(scene, camera) {
            @tsl.after_image(@three.pass(scene, camera), damp=0.85)
          },
          frames=4,
          step=a5_move,
        ),
      )
    "addon_traa" =>
      Some(
        a5_view(
          fn(scene, camera) {
            let scene_pass = @three.pass(scene, camera)
            scene_pass.set_mrt(
              Some(
                @three.mrt({
                  "output": @three.output,
                  "velocity": @three.velocity,
                }),
              ),
            )
            |> ignore
            @tsl.traa(
              scene_pass.get_texture_node(name="output"),
              scene_pass.get_texture_node(name="depth"),
              scene_pass.get_texture_node(name="velocity"),
              camera,
            )
          },
          frames=5,
          step=a5_move,
        ),
      )
    "addon_tile_shadow" => {
      let scene = @three.Scene::new()
      let camera = addon_stage(scene)
      scene.children[0].cast_shadow = true
      scene.children[1].cast_shadow = true
      scene.children[2].receive_shadow = true
      let light = scene.children[4]
      light.cast_shadow = true
      let shadow = light.as_light().shadow.unwrap()
      shadow.map_size.set(256.0, 256.0) |> ignore
      match shadow.camera.as_camera().kind {
        OrthographicCamera(o) => {
          o.left = -2.0
          o.right = 2.0
          o.top = 2.0
          o.bottom = -2.0
        }
        _ => ()
      }
      shadow.shadow_node = Some(
        @three.JsValue::of(
          @tsl.TileShadowNode::new(light, tiles_x=2, tiles_y=2),
        ),
      )
      Some(
        view(scene, camera, before=fn(renderer, _) {
          renderer.shadow_map.enabled = true
        }),
      )
    }
    "addon_dynamic_lights" => {
      let scene = @three.Scene::new()
      let camera = addon_stage(scene)
      for i in 0..<3 {
        let l = @three.PointLight::new(
          color=@three.Color::from_hex([0xff2200, 0x22ff00, 0x0044ff][i]),
          intensity=3.0,
          distance=4.0,
          decay=2.0,
        )
        l.position.set(i.to_double() - 1.0, 0.8, 0.8) |> ignore
        scene.add(l) |> ignore
      }
      let spot = @three.SpotLight::new(
        color=@three.Color::from_hex(0xffffaa),
        intensity=6.0,
        distance=8.0,
        angle=0.5,
        penumbra=0.3,
        decay=2.0,
      )
      spot.position.set(0.0, 2.5, 1.0) |> ignore
      scene.add(spot) |> ignore
      Some(
        view(scene, camera, before=fn(renderer, _) {
          // examples/jsm/lighting/DynamicLighting.js's `createNode`
          renderer.lighting = @three.Lighting::new(class_=A5DynamicLighting::{ })
        }),
      )
    }
    _ => None
  }
}
