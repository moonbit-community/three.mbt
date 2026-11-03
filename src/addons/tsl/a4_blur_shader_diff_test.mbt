// A4 shader scenarios, group `blur` (upstream: harness/shader_diff/a4/blur.mjs):
// GaussianBlurNode, DepthOfFieldNode, SharpenNode and their internal pass materials.

///|
fn a4_blur_gauss(n : @nodes.Node) -> Array[(String, @core.Material)] {
  let g = @tsl.GaussianBlurNode::of(n).unwrap()
  [("horizontal", g._h_material.unwrap()), ("vertical", g._v_material.unwrap())]
}

///|
fn a4_blur_dof_internals(n : @nodes.Node) -> Array[(String, @core.Material)] {
  let d = @tsl.DepthOfFieldNode::of(n).unwrap()
  [
    ("coc", d._coc_material),
    ("coc_blurred", d._coc_blurred_material),
    ("blur64", d._blur64_material),
    ("blur16", d._blur16_material),
    ("composite", d._composite_material),
  ]
}

///|
fn a4_blur_rtt_material(texture_node : @nodes.Node) -> @core.Material {
  @nodes.RTTNode::of(texture_node).unwrap()._quad_mesh.material()
}

///|
fn a4_blur_color() -> @nodes.Node {
  @nodes.texture(a4_tex("color"))
}

///|
test "a4 blur shader scenarios (compared with upstream by run.mjs)" {
  @tsl.load_display_gaussian_blur_node()
  @tsl.load_display_depth_of_field_node()
  @tsl.load_display_sharpen_node()
  let s = A4Scenarios::new()
  // GaussianBlurNode
  s.flow(
    "blur_gaussian",
    fn() { @tsl.gaussian_blur(a4_blur_color()) },
    internals=a4_blur_gauss,
  )
  s.flow(
    "blur_gaussian_direction_sigma",
    fn() {
      @tsl.gaussian_blur(
        a4_blur_color(),
        direction_node=@nodes.uniform(2),
        sigma=2,
      )
    },
    internals=a4_blur_gauss,
    glsl=true,
  )
  s.flow(
    "blur_gaussian_vec2_direction",
    fn() {
      @tsl.gaussian_blur(
        @nodes.texture(a4_tex("color"), uv_node=@nodes.uv().mul(0.5)),
        direction_node=@nodes.vec2_of([1, 0.5]),
        sigma=1,
      )
    },
    internals=a4_blur_gauss,
  )
  s.flow(
    "blur_gaussian_fractional_sigma",
    fn() { @tsl.gaussian_blur(a4_blur_color(), sigma=2.5) },
    internals=a4_blur_gauss,
  )
  s.flow(
    "blur_gaussian_premultiplied",
    fn() {
      @tsl.gaussian_blur(
        a4_blur_color(),
        direction_node=1.5,
        sigma=3,
        premultiplied_alpha=true,
        resolution_scale=0.5,
      )
    },
    internals=a4_blur_gauss,
    glsl=true,
  )
  s.flow(
    "blur_premultiplied_gaussian_blur",
    fn() {
      @tsl.premultiplied_gaussian_blur(
        a4_blur_color(),
        direction_node=2,
        sigma=1,
      )
    },
    internals=a4_blur_gauss,
  )
  s.flow(
    "blur_gaussian_rtt",
    fn() { @tsl.gaussian_blur(@nodes.vec4_of([@nodes.uv(), 0, 1])) },
    internals=fn(n) {
      let t = @tsl.GaussianBlurNode::of(n).unwrap().texture_node
      [("rtt", a4_blur_rtt_material(t))] + a4_blur_gauss(n)
    },
  )
  // DepthOfFieldNode
  s.flow(
    "blur_dof",
    fn() { @tsl.dof(a4_blur_color(), @nodes.uniform(-5)) },
    internals=a4_blur_dof_internals,
  )
  s.flow(
    "blur_dof_params",
    fn() {
      @tsl.dof(
        a4_blur_color(),
        @nodes.uniform(-4),
        focus_distance=@nodes.uniform(2),
        focal_length=3,
        bokeh_scale=@nodes.uniform(1.5),
      )
    },
    internals=a4_blur_dof_internals,
    glsl=true,
  )
  s.flow(
    "blur_dof_coc_blur",
    fn() {
      let d = @tsl.dof(
        a4_blur_color(),
        -3,
        focus_distance=0.5,
        focal_length=2,
        bokeh_scale=0.25,
      )
      @tsl.DepthOfFieldNode::of(d).unwrap()._coc_blur_node
    },
    internals=a4_blur_gauss,
  )
  s.flow(
    "blur_dof_rtt",
    fn() { @tsl.dof(@nodes.vec4_of([@nodes.uv(), 1, 1]), @nodes.uniform(-2)) },
    internals=fn(n) {
      let t = @tsl.DepthOfFieldNode::of(n).unwrap().texture_node
      [("rtt", a4_blur_rtt_material(t))] + a4_blur_dof_internals(n)
    },
  )
  // SharpenNode
  let rcas = fn(n : @nodes.Node) {
    [("rcas", @tsl.SharpenNode::of(n).unwrap()._material.unwrap())]
  }
  s.flow("blur_sharpen", fn() { @tsl.sharpen(a4_blur_color()) }, internals=rcas)
  s.flow(
    "blur_sharpen_options",
    fn() {
      @tsl.sharpen(
        a4_blur_color(),
        sharpness=@nodes.uniform(0.5),
        denoise=@nodes.uniform(true),
      )
    },
    internals=rcas,
    glsl=true,
  )
  s.flow(
    "blur_sharpen_denoise",
    fn() { @tsl.sharpen(a4_blur_color(), sharpness=1, denoise=true) },
    internals=rcas,
  )
  a4_run(s)
}
