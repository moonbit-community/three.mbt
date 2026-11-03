// A4 mock-GPU scenarios of group `ssr` (harness/a4_ssr_scenarios.mjs, step for step).

///|
fn ssr_modules() -> Unit {
  @tsl.load_display_ssr_node()
  @tsl.load_display_recurrent_denoise_node()
}

///|
priv struct SSRGBuffer {
  cam : @core.Object3D
  color : @nodes.Node
  normal : @nodes.Node
  depth : @nodes.Node
  mr : @nodes.Node
}

///|
/// The lit scene with a metallic box and the g-buffer pass: output, view normal,
/// metal/rough.
fn ssr_gbuffer() -> SSRGBuffer {
  let scene = lit_scene()
  let box = scene.children[2]
  match box.kind {
    Mesh({ material: Single(m), .. }) => {
      m.metalness = Some(1.0)
      m.roughness = Some(0.3)
    }
    _ => ()
  }
  let cam = camera()
  let scene_pass = @nodes.pass(scene, cam)
  scene_pass.set_mrt(
    Some(
      @nodes.mrt(
        Map::from_array([
          ("output", @nodes.output),
          ("normal", @nodes.normal_view),
          ("metalrough", @nodes.vec2_of([@nodes.metalness, @nodes.roughness])),
        ]),
      ),
    ),
  )
  |> ignore
  {
    cam,
    color: scene_pass.get_texture_node(name="output"),
    normal: scene_pass.get_texture_node(name="normal"),
    depth: scene_pass.get_texture_node(name="depth"),
    mr: scene_pass.get_texture_node(name="metalrough"),
  }
}

///|
fn ssr_hdr() -> @core.Texture {
  let data = @core.TypedArray::uint16(4 * 2 * 4)
  for i = 0; i < data.length(); i = i + 1 {
    data.set(i, @core.to_half_float((i % 7).to_double() * 0.5 + 0.25))
  }
  let t = @core.DataTexture::new(
    data~,
    width=4,
    height=2,
    format=@core.RGBAFormat,
    type_=@core.HalfFloatType,
  )
  t.set_needs_update(true)
  t
}

///|
fn register_ssr() -> Unit {
  scenario("a4_ssr_mirror", ssr_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let g = ssr_gbuffer()
      let pp = @nodes.RenderPipeline::new(r)
      let s = @tsl.ssr(
        g.color,
        g.depth,
        g.normal,
        metalness_node=g.mr.r(),
        roughness_node=g.mr.g(),
        camera=g.cam,
      )
      @tsl.SSRNode::of(s).unwrap().set_blur_quality(1)
      pp.output_node = @nodes.vec4_of([g.color.rgb().add(s.rgb()), g.color.a()])
      pp.render()
      pp.render()
      done()
    })
  })
  scenario("a4_ssr_stochastic_denoise", ssr_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let g = ssr_gbuffer()
      let pp = @nodes.RenderPipeline::new(r)
      let s = @tsl.ssr(
        g.color,
        g.depth,
        g.normal,
        stochastic=true,
        metalness_node=g.mr.r(),
        roughness_node=g.mr.g(),
        camera=g.cam,
      )
      let d = @tsl.recurrent_denoise(
        s,
        g.cam,
        depth=g.depth,
        normal=g.normal,
        raw=s,
        mode="specular",
        metal_roughness=g.mr,
      )
      pp.output_node = @nodes.vec4_of([g.color.rgb().add(d.rgb()), g.color.a()])
      pp.render()
      pp.render()
      pp.render()
      done()
    })
  })
  scenario("a4_ssr_env_refine", ssr_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let g = ssr_gbuffer()
      let pp = @nodes.RenderPipeline::new(r)
      let s = @tsl.ssr(
        g.color,
        g.depth,
        g.normal,
        stochastic=true,
        metalness_node=g.mr.r(),
        roughness_node=g.mr.g(),
        environment_node=ssr_hdr(),
        env_importance_sampling=true,
        binary_refine=true,
        camera=g.cam,
      )
      let p = @tsl.SSRNode::of(s).unwrap()
      p.set_screen_edge_fade_black(true)
      p.resolution_scale = 0.5
      pp.output_node = @nodes.vec4_of([g.color.rgb().add(s.rgb()), g.color.a()])
      pp.render()
      pp.render()
      done()
    })
  })
  scenario("a4_ssr_denoise_diffuse_ao", ssr_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let g = ssr_gbuffer()
      let pp = @nodes.RenderPipeline::new(r)
      let d = @tsl.recurrent_denoise(
        g.color,
        g.cam,
        depth=g.depth,
        normal=g.normal,
        raw=g.color,
        accumulate=true,
      )
      @tsl.RecurrentDenoiseNode::of(d).unwrap().alpha_source = "ao"
      pp.output_node = d
      pp.render()
      pp.render()
      done()
    })
  })
}
