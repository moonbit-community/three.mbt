// A4 mock-GPU scenarios of group `blur` (harness/a4_blur_scenarios.mjs, step for step).

///|
fn blur_run(output : (@nodes.Node) -> @nodes.Node) -> (Env, () -> Unit) -> Unit {
  fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = lit_scene()
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      let scene_pass = @nodes.pass(scene, cam)
      pp.output_node = output(scene_pass)
      pp.render()
      pp.render()
      done()
    })
  }
}

///|
fn register_blur() -> Unit {
  scenario(
    "a4_blur_gaussian",
    fn() { @tsl.load_display_gaussian_blur_node() },
    blur_run(fn(scene_pass) { @tsl.gaussian_blur(scene_pass, sigma=2) }),
  )
  scenario(
    "a4_blur_gaussian_premultiplied",
    fn() { @tsl.load_display_gaussian_blur_node() },
    blur_run(fn(scene_pass) {
      @tsl.gaussian_blur(
        scene_pass,
        direction_node=@nodes.vec2_of([1, 0.5]),
        sigma=3,
        premultiplied_alpha=true,
        resolution_scale=0.5,
      )
    }),
  )
  scenario(
    "a4_blur_dof",
    fn() {
      @tsl.load_display_gaussian_blur_node()
      @tsl.load_display_depth_of_field_node()
    },
    blur_run(fn(scene_pass) {
      @tsl.dof(
        scene_pass,
        scene_pass.get_view_z_node(),
        focus_distance=@nodes.uniform(2),
        focal_length=@nodes.uniform(1),
        bokeh_scale=@nodes.uniform(1),
      )
    }),
  )
  scenario(
    "a4_blur_sharpen",
    fn() { @tsl.load_display_sharpen_node() },
    blur_run(fn(scene_pass) {
      @tsl.sharpen(scene_pass, sharpness=0.5, denoise=true)
    }),
  )
}
