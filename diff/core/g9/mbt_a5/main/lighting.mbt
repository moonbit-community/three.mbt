// A5 mock-GPU scenarios of tsl/lighting and tsl/shadows (harness/a5_scenarios.mjs).

///|
extern "js" fn js_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn js_sin(x : Double) -> Double = "Math.sin"

///|
/// `customLighting( THREE, make )`: a Lighting whose `createNode( lights )` is
/// `make().setLights( lights )`.
priv struct CustomLighting {
  make : () -> @nodes.Node
}

///|
impl @nodes.LightingClass for CustomLighting with fn create_node(self, _, lights) {
  @nodes.LightsNode::set_lights((self.make)(), lights)
}

///|
fn custom_lighting(make : () -> @nodes.Node) -> @nodes.Lighting {
  @nodes.Lighting::new(class_={ make, })
}

///|
fn point_lights(scene : @core.Object3D, count : Int) -> Unit {
  for i in 0..<count {
    let l = @core.PointLight::new(
      color=@math.Color::from_hex(0xffffff * (i + 1) / count),
      intensity=2.0,
      distance=5.0,
      decay=2.0,
    )
    l.position.set(
      js_cos(i.to_double()) * 1.5,
      js_sin(i.to_double()) * 1.5,
      1.0,
    )
    |> ignore
    scene.add(l) |> ignore
  }
  let spot = @core.SpotLight::new(
    color=@math.Color::from_hex(0xffaa00),
    intensity=3.0,
    distance=6.0,
    angle=0.6,
    penumbra=0.2,
  )
  spot.position.set(0.0, 2.0, 2.0) |> ignore
  scene.add(spot) |> ignore
  scene.add(
    @core.HemisphereLight::new(
      sky_color=@math.Color::from_hex(0x8888ff),
      ground_color=@math.Color::from_hex(0x442200),
      intensity=0.5,
    ),
  )
  |> ignore
}

///|
fn register_lighting() -> Unit {
  scenario("a5_dynamic_lights", no_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      r.lighting = custom_lighting(fn() {
        @tsl.DynamicLightsNode::new(max_point_lights=4)
      })
      let scene = lit_scene()
      point_lights(scene, 3)
      let cam = camera()
      r.render(scene, cam)
      tick(r)
      point_lights(scene, 1)
      r.render(scene, cam)
      done()
    })
  })
  scenario("a5_clustered_lights", no_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      r.lighting = custom_lighting(fn() { @tsl.ClusteredLightsNode::new() })
      let scene = lit_scene()
      point_lights(scene, 4)
      let cam = camera()
      r.render(scene, cam)
      tick(r)
      child(scene, 2).rotation.set_y(1.0)
      r.render(scene, cam)
      done()
    })
  })
  scenario("a5_tile_shadow", no_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      r.shadow_map.enabled = true
      let scene = lit_scene()
      child(scene, 2).cast_shadow = true
      child(scene, 3).receive_shadow = true
      let dl = child(scene, 1)
      dl.cast_shadow = true
      let shadow = dl.as_light().shadow.unwrap()
      shadow.map_size.set(64.0, 64.0) |> ignore
      // a non-square shadow frustum (tile widths and heights differ)
      match shadow.camera.as_camera().kind {
        OrthographicCamera(o) => {
          o.left = -3.0
          o.right = 3.0
          o.top = 2.0
          o.bottom = -1.5
        }
        _ => ()
      }
      shadow.shadow_node = Some(
        @core.JsValue::of(@tsl.TileShadowNode::new(dl, tiles_x=2, tiles_y=2)),
      )
      let cam = camera()
      r.render(scene, cam)
      tick(r)
      dl.position.set(2.0, 2.0, 2.0) |> ignore
      r.render(scene, cam)
      done()
    })
  })
}
