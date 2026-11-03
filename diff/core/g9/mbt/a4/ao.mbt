// A4 mock-GPU scenarios of group `ao` (harness/a4_ao_scenarios.mjs, step for step).

///|
/// `mrtPass( ctx, scene, cam )`: a pass with an MRT of output + normalView.
fn ao_mrt_pass(scene : @core.Object3D, cam : @core.Object3D) -> @nodes.Node {
  let scene_pass = @nodes.pass(scene, cam)
  scene_pass.set_mrt(
    Some(@nodes.mrt({ "output": @nodes.output, "normal": @nodes.normal_view })),
  )
  |> ignore
  scene_pass
}

///|
fn ao_shadow_of(light : @core.Object3D) -> @core.LightShadow {
  match light.kind {
    Light(l) => l.shadow.unwrap()
    _ => abort("not a light")
  }
}

///|
/// `shadowScene( ctx, light )`.
fn ao_shadow_scene(light : @core.Object3D) -> @core.Object3D {
  let scene = lit_scene()
  for child in scene.children {
    if child.kind is Mesh(_) {
      child.cast_shadow = true
      child.receive_shadow = true
    }
  }
  light.cast_shadow = true
  ao_shadow_of(light).map_size.set(64.0, 64.0) |> ignore
  scene.add(light) |> ignore
  scene
}

///|
fn register_ao() -> Unit {
  scenario("a4_ao_gtao", @tsl.load_display_gtao_node, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = lit_scene()
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = ao_mrt_pass(scene, cam)
      let ao_pass = @tsl.ao(
        scene_pass.get_texture_node(name="depth"),
        Some(scene_pass.get_texture_node(name="normal")),
        cam,
      )
      let p = @tsl.GTAONode::of(ao_pass).unwrap()
      p.use_temporal_filtering = true
      pp.output_node = p
        .get_texture_node()
        .mul(scene_pass.get_texture_node(name="output"))
      pp.render()
      r._nodes.unwrap().node_frame.update() // next frame
      pp.render()
      done()
    })
  })
  scenario("a4_ao_gtao_no_normal", @tsl.load_display_gtao_node, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = lit_scene()
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = @nodes.pass(scene, cam)
      let ao_pass = @tsl.ao(
        scene_pass.get_texture_node(name="depth"),
        None,
        cam,
      )
      let p = @tsl.GTAONode::of(ao_pass).unwrap()
      @nodes.InputNode::set_value(p.samples, Number(8))
      p.resolution_scale = 0.5
      pp.output_node = @nodes.vec4_of([@nodes.vec3(p.get_texture_node().r()), 1])
      pp.render()
      // a sample count change rebuilds the material
      @nodes.InputNode::set_value(p.samples, Number(32))
      r._nodes.unwrap().node_frame.update()
      pp.render()
      done()
    })
  })
  scenario("a4_ao_ssgi", @tsl.load_display_ssgi_node, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = lit_scene()
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = ao_mrt_pass(scene, cam)
      let color = scene_pass.get_texture_node(name="output")
      let gi_pass = @tsl.ssgi(
        color,
        scene_pass.get_texture_node(name="depth"),
        Some(scene_pass.get_texture_node(name="normal")),
        cam,
      )
      let p = @tsl.SSGINode::of(gi_pass).unwrap()
      @nodes.InputNode::set_value(p.slice_count, Number(2))
      @nodes.InputNode::set_value(p.step_count, Number(8))
      pp.output_node = @nodes.vec4_of([
        color.rgb().mul(p.get_ao_node().r()).add(p.get_gi_node().rgb()),
        color.a(),
      ])
      pp.render()
      p.use_temporal_filtering = false
      r._nodes.unwrap().node_frame.update()
      pp.render()
      done()
    })
  })
  scenario("a4_ao_sss", @tsl.load_display_sss_node, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      r.shadow_map.enabled = true
      let light = @core.DirectionalLight::new(
        color=@math.Color::from_hex(0xffffff),
        intensity=2.0,
      )
      light.position.set(1.0, 2.0, 3.0) |> ignore
      let scene = ao_shadow_scene(light)
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = @nodes.pass(scene, cam)
      let sss_pass = @tsl.sss(
        scene_pass.get_texture_node(name="depth"),
        cam,
        light,
      )
      let p = @tsl.SSSNode::of(sss_pass).unwrap()
      p.use_temporal_filtering = true
      pp.output_node = scene_pass
        .get_texture_node(name="output")
        .mul(p.get_texture_node().r())
      pp.render()
      r._nodes.unwrap().node_frame.update() // next frame
      pp.render()
      p.use_temporal_filtering = false
      r._nodes.unwrap().node_frame.update()
      pp.render()
      done()
    })
  })
  for kind in ["directional", "point"] {
    scenario("a4_ao_godrays_" + kind, @tsl.load_display_godrays_node, fn(
      env,
      done,
    ) {
      let r = renderer(env)
      r.init(on_done=fn(_) {
        r.shadow_map.enabled = true
        let light = if kind == "point" {
          @core.PointLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=3.0,
            distance=10.0,
            decay=2.0,
          )
        } else {
          @core.DirectionalLight::new(
            color=@math.Color::from_hex(0xffffff),
            intensity=2.0,
          )
        }
        light.position.set(-1.0, 2.0, 2.0) |> ignore
        let scene = ao_shadow_scene(light)
        let cam = camera()
        // the shadow map exists once the scene has been rendered
        r.render(scene, cam)
        let pp = @nodes.RenderPipeline::new(r)
        let scene_pass = @nodes.pass(scene, cam)
        let godrays_pass = @tsl.godrays(
          scene_pass.get_texture_node(name="depth"),
          cam,
          light,
        )
        let p = @tsl.GodraysNode::of(godrays_pass).unwrap()
        @nodes.InputNode::set_value(p.raymarch_steps, Number(24))
        pp.output_node = scene_pass
          .get_texture_node(name="output")
          .add(p.get_texture_node())
        pp.render()
        r._nodes.unwrap().node_frame.update()
        pp.render()
        done()
      })
    })
  }
}
