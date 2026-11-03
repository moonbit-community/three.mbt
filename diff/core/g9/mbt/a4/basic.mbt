///|
fn register_basic() -> Unit {
  scenario("a4_rgb_shift", no_modules, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = lit_scene()
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = @nodes.pass(scene, cam)
      pp.output_node = @tsl.rgb_shift(scene_pass, amount=0.01, angle=0.3)
      pp.render()
      pp.render()
      done()
    })
  })
}

///|
/// `pipeline( ctx, output )`: a lit scene through a RenderPipeline, rendered twice.
fn pipeline(
  env : Env,
  done : () -> Unit,
  output : (@nodes.Node, @core.Object3D) -> @nodes.Node,
) -> Unit {
  let r = renderer(env)
  r.init(on_done=fn(_) {
    let scene = lit_scene()
    let cam = camera()
    let pp = @nodes.RenderPipeline::new(r)
    let scene_pass = @nodes.pass(scene, cam)
    pp.output_node = output(scene_pass, cam)
    pp.render()
    pp.render()
    done()
  })
}

///|
fn register_basic_more() -> Unit {
  scenario("a4_fxaa", no_modules, fn(env, done) {
    pipeline(env, done, fn(p, _) { @tsl.fxaa(p) })
  })
  scenario("a4_fxaa_rtt", no_modules, fn(env, done) {
    pipeline(env, done, fn(p, _) { @tsl.fxaa(p.mul(0.8)) })
  })
  scenario("a4_sobel", no_modules, fn(env, done) {
    pipeline(env, done, fn(p, _) { @tsl.sobel(p) })
  })
  scenario("a4_dot_screen", no_modules, fn(env, done) {
    pipeline(env, done, fn(p, _) {
      @tsl.dot_screen(p, angle=@nodes.uniform(0.5), scale=1.5)
    })
  })
  scenario(
    "a4_bleach_radial_blur",
    fn() {
      @tsl.load_display_bleach_bypass()
      @tsl.load_display_radial_blur()
    },
    fn(env, done) {
      pipeline(env, done, fn(p, _) {
        @tsl.bleach().call([
          @tsl.radial_blur().call([
            p,
            @tsl.addon_options([("count", 8), ("premultipliedAlpha", true)]),
          ]),
          0.7,
        ])
      })
    },
  )
  scenario(
    "a4_crt_lens_dirt",
    fn() {
      @tsl.load_display_crt()
      @tsl.load_display_lens_dirt()
    },
    fn(env, done) {
      pipeline(env, done, fn(p, _) {
        let distorted = @tsl.barrel_uv().call([0.1])
        let data = @core.TypedArray::uint8(16)
        for i in 0..<16 {
          data.set(i, 200.0)
        }
        let dirt = @core.DataTexture::new(data~, width=2, height=2)
        dirt.set_needs_update(true)
        let bled = @tsl.color_bleeding().call([p])
        @tsl.vignette()
        // (no scanlines: their `time` uniform reads the clock)
        .call([bled, 0.4])
        .add(@tsl.lens_dirt().call([p, @nodes.texture(dirt)]).rgb())
        .mul(@tsl.barrel_mask().call([distorted]))
      })
    },
  )
  scenario(
    "a4_depth_aware",
    fn() {
      @tsl.load_display_depth_aware_blur()
      @tsl.load_display_depth_aware_blend()
    },
    fn(env, done) {
      pipeline(env, done, fn(p, c) {
        let depth = p.get_texture_node(name="depth")
        let blurred = @tsl.depth_aware_blur().call([
          p.get_texture_node(),
          depth,
          @nodes.vec2_of([0.01, 0]),
          c,
        ])
        @tsl.depth_aware_blend()
        .call([
          p.get_texture_node(),
          p.get_texture_node(),
          depth,
          c,
          @tsl.addon_options([("edgeRadius", 2)]),
        ])
        .add(blurred)
      })
    },
  )
}
