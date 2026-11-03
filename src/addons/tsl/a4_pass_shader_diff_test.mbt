// A4 shader scenarios, group `pass` (harness/shader_diff/a4/pass.mjs): the PassNode
// subclasses PixelationPassNode, RetroPassNode, SSAAPassNode, StereoPassNode and
// AnaglyphPassNode. See a4_shader_diff_test.mbt for the scenario kinds.

///|
fn a4_pass_scene() -> @core.Object3D {
  @core.Scene::new()
}

///|
fn a4_pass_camera() -> @core.Object3D {
  @core.PerspectiveCamera::new()
}

///|
test "a4 pass shader scenarios (compared with upstream by run.mjs)" {
  // the upstream group's module imports, in order
  @tsl.load_display_retro_pass_node()
  @tsl.load_display_anaglyph_pass_node()
  let s = A4Scenarios::new()
  // PixelationPassNode: its own setup (not PassNode's), sampling output / depth / normal
  s.flow(
    "pass_pixelation",
    fn() { @tsl.pixelation_pass(a4_pass_scene(), a4_pass_camera()) },
    glsl=true,
  )
  s.flow("pass_pixelation_options", fn() {
    @tsl.pixelation_pass(
      a4_pass_scene(),
      a4_pass_camera(),
      pixel_size=4,
      normal_edge_strength=0.5,
      depth_edge_strength=@nodes.uniform(0.2),
    )
  })
  s.flow("pass_pixelation_no_edges", fn() {
    @tsl.pixelation_pass(
      a4_pass_scene(),
      a4_pass_camera(),
      pixel_size=8,
      normal_edge_strength=0,
      depth_edge_strength=0,
    )
  })
  s.flow("pass_pixelation_uses", fn() {
    let p = @tsl.pixelation_pass(
      a4_pass_scene(),
      a4_pass_camera(),
      pixel_size=6,
    )
    p.mul(0.5).add(p.get_texture_node(name="normal"))
  })
  // SSAAPassNode: the accumulation material (the MRT ones need the pass's render target
  // in the builder, so only the mock-GPU scenarios build them)
  let ssaa_material = fn(n : @nodes.Node) {
    [("ssaa", @tsl.SSAAPassNode::of(n).unwrap()._quad_mesh.material())]
  }
  s.flow(
    "pass_ssaa",
    fn() { @tsl.ssaa_pass(a4_pass_scene(), a4_pass_camera()) },
    glsl=true,
    internals=ssaa_material,
  )
  s.flow(
    "pass_ssaa_options",
    fn() {
      let p = @tsl.ssaa_pass(a4_pass_scene(), a4_pass_camera())
      let payload = @tsl.SSAAPassNode::of(p).unwrap()
      payload.sample_level = 2
      payload.unbiased = false
      p
    },
    internals=ssaa_material,
  )
  s.flow(
    "pass_ssaa_mrt",
    fn() {
      let p = @tsl.ssaa_pass(a4_pass_scene(), a4_pass_camera())
      p.set_mrt(
        Some(
          @nodes.mrt(
            Map::from_array([
              ("output", @nodes.output),
              ("normal", @nodes.normal_view),
            ]),
          ),
        ),
      )
      |> ignore
      p.add(p.get_texture_node(name="normal"))
    },
    glsl=true,
  )
  s.flow("pass_ssaa_mrt_missing", fn() {
    let p = @tsl.ssaa_pass(a4_pass_scene(), a4_pass_camera())
    p.set_mrt(
      Some(
        @nodes.mrt(
          Map::from_array([
            ("output", @nodes.output),
            ("emissive", @nodes.vec4(1)),
          ]),
        ),
      ),
    )
    |> ignore
    p
  })
  // StereoPassNode: PassNode's setup
  s.flow(
    "pass_stereo",
    fn() { @tsl.stereo_pass(a4_pass_scene(), a4_pass_camera()) },
    glsl=true,
  )
  s.flow("pass_stereo_depth", fn() {
    @tsl.stereo_pass(a4_pass_scene(), a4_pass_camera()).get_view_z_node()
  })
  // AnaglyphPassNode: the composite material (algorithms only change uniform values)
  let anaglyph_ref : Ref[@nodes.Node?] = Ref(None)
  let anaglyph_material = fn(n : @nodes.Node) {
    let n = match anaglyph_ref.val {
      Some(p) => p
      None => n
    }
    [
      (
        "anaglyph",
        @tsl.AnaglyphPassNode::of(n).unwrap().stereo._material.unwrap(),
      ),
    ]
  }
  s.flow(
    "pass_anaglyph",
    fn() {
      anaglyph_ref.val = None
      @tsl.anaglyph_pass(a4_pass_scene(), a4_pass_camera())
    },
    glsl=true,
    internals=anaglyph_material,
  )
  s.flow(
    "pass_anaglyph_options",
    fn() {
      let p = @tsl.anaglyph_pass(a4_pass_scene(), a4_pass_camera())
      anaglyph_ref.val = Some(p)
      let payload = @tsl.AnaglyphPassNode::of(p).unwrap()
      payload.set_algorithm(Grey)
      payload.set_color_mode(MagentaGreen)
      payload.eye_sep = 0.1
      p.mul(2)
    },
    internals=anaglyph_material,
  )
  // RetroPassNode: PassNode's setup (its materials are made while rendering)
  s.flow(
    "pass_retro",
    fn() { @tsl.retro_pass(a4_pass_scene(), a4_pass_camera()) },
    glsl=true,
  )
  s.flow("pass_retro_options", fn() {
    @tsl.retro_pass(
      a4_pass_scene(),
      a4_pass_camera(),
      affine_distortion=@nodes.uniform(0.5),
      filter_textures=true,
    )
  })
  a4_run(s)
}
