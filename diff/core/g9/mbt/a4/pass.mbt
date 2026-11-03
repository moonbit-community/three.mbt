// A4 mock-GPU scenarios of group `pass` (harness/a4_pass_scenarios.mjs, step for step).

///|
fn pass_face_texture(
  size : Int32,
  r : Int32,
  g : Int32,
  b : Int32,
) -> @core.Texture {
  let data = @core.TypedArray::uint8(size * size * 4)
  for i = 0; i < size * size; i = i + 1 {
    data.set(i * 4, (if i % 2 == 0 { r } else { r / 2 }).to_double())
    data.set(i * 4 + 1, g.to_double())
    data.set(i * 4 + 2, b.to_double())
    data.set(i * 4 + 3, 255.0)
  }
  let texture = @core.DataTexture::new(data~, width=size, height=size)
  texture.set_needs_update(true)
  texture
}

///|
/// `retroScene( THREE )`: a core MeshBasicMaterial box with a map, a core
/// MeshStandardMaterial sphere with an envMap and a metalnessMap, and a
/// MeshStandardNodeMaterial plane.
fn pass_retro_scene() -> (@core.Object3D, @core.Material, @core.Material) {
  let scene = @core.Scene::new()
  scene.add(
    @core.AmbientLight::new(
      color=@math.Color::from_hex(0x404040),
      intensity=1.0,
    ),
  )
  |> ignore
  let dl = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=2.0,
  )
  dl.position.set(1.0, 2.0, 3.0) |> ignore
  scene.add(dl) |> ignore
  let basic = @core.MeshBasicMaterial::new()
  basic.color.unwrap().set_hex(0x88cc44) |> ignore
  basic.map = Some(pass_face_texture(2, 255, 128, 64))
  let box = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(basic),
  )
  box.position.x = -0.8
  box.rotation.set(0.4, 0.6, 0.0) |> ignore
  scene.add(box) |> ignore
  let faces = [0, 1, 2, 3, 4, 5].map(fn(i) {
    pass_face_texture(2, 40 * i, 255 - 40 * i, 128)
  })
  let cube = @core.CubeTexture::new(
    images=faces.map(fn(face) { TextureImage(face) }),
  )
  cube.set_needs_update(true)
  let standard = @core.MeshStandardMaterial::new()
  standard.color.unwrap().set_hex(0x3366cc) |> ignore
  standard.metalness = Some(0.7)
  standard.env_map = Some(cube)
  standard.metalness_map = Some(pass_face_texture(2, 200, 200, 200))
  let sphere = @core.Mesh::new(
    geometry=@geometries.SphereGeometry::new(
      radius=0.5,
      width_segments=8,
      height_segments=6,
    ),
    material=Single(standard),
  )
  sphere.position.x = 0.8
  scene.add(sphere) |> ignore
  let plane = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(width=4.0, height=4.0),
    material=Single(@nodes.MeshStandardNodeMaterial::new()),
  )
  plane.position.z = -1.0
  scene.add(plane) |> ignore
  (scene, basic, standard)
}

///|
fn pass_pipeline(
  env : Env,
  done : () -> Unit,
  make : (@nodes.Renderer) -> @nodes.Node,
  after : (@nodes.RenderPipeline) -> Unit,
) -> Unit {
  let r = renderer(env)
  r.init(on_done=fn(_) {
    let pp = @nodes.RenderPipeline::new(r)
    pp.output_node = make(r)
    pp.render()
    pp.render()
    after(pp)
    done()
  })
}

///|
fn pass_nothing(_ : @nodes.RenderPipeline) -> Unit {

}

///|
fn register_pass() -> Unit {
  scenario("a4_pass_pixelation", no_modules, fn(env, done) {
    pass_pipeline(
      env,
      done,
      fn(_) {
        @tsl.pixelation_pass(
          lit_scene(),
          camera(),
          pixel_size=2,
          normal_edge_strength=0.3,
          depth_edge_strength=0.4,
        )
      },
      pass_nothing,
    )
  })
  scenario("a4_pass_pixelation_dispose", no_modules, fn(env, done) {
    pass_pipeline(
      env,
      done,
      fn(_) { @tsl.pixelation_pass(lit_scene(), camera()) },
      fn(pp) { pp.output_node.dispose() },
    )
  })
  scenario("a4_pass_ssaa", no_modules, fn(env, done) {
    pass_pipeline(
      env,
      done,
      fn(r) {
        r.set_clear_color_hex(0x223344, alpha=0.75)
        let p = @tsl.ssaa_pass(lit_scene(), camera())
        @tsl.SSAAPassNode::of(p).unwrap().sample_level = 2
        p
      },
      pass_nothing,
    )
  })
  scenario("a4_pass_ssaa_biased_view", no_modules, fn(env, done) {
    pass_pipeline(
      env,
      done,
      fn(_) {
        let cam = camera()
        cam.set_view_offset(8.0, 8.0, 1.0, 2.0, 4.0, 4.0)
        let p = @tsl.ssaa_pass(lit_scene(), cam)
        let payload = @tsl.SSAAPassNode::of(p).unwrap()
        payload.sample_level = 1
        payload.unbiased = false
        p
      },
      pass_nothing,
    )
  })
  scenario("a4_pass_ssaa_mrt", no_modules, fn(env, done) {
    pass_pipeline(
      env,
      done,
      fn(_) {
        let p = @tsl.ssaa_pass(lit_scene(), camera())
        @tsl.SSAAPassNode::of(p).unwrap().sample_level = 0
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
      pass_nothing,
    )
  })
  scenario("a4_pass_stereo", no_modules, fn(env, done) {
    pass_pipeline(
      env,
      done,
      fn(_) { @tsl.stereo_pass(lit_scene(), camera()) },
      pass_nothing,
    )
  })
  scenario("a4_pass_anaglyph", @tsl.load_display_anaglyph_pass_node, fn(
    env,
    done,
  ) {
    pass_pipeline(
      env,
      done,
      fn(_) { @tsl.anaglyph_pass(lit_scene(), camera()) },
      pass_nothing,
    )
  })
  scenario("a4_pass_anaglyph_modes", @tsl.load_display_anaglyph_pass_node, fn(
    env,
    done,
  ) {
    pass_pipeline(
      env,
      done,
      fn(_) {
        let p = @tsl.anaglyph_pass(lit_scene(), camera())
        let payload = @tsl.AnaglyphPassNode::of(p).unwrap()
        payload.set_algorithm(HalfColour)
        payload.set_color_mode(MagentaCyan)
        payload.eye_sep = 0.1
        payload.plane_distance = 2.0
        p
      },
      fn(pp) {
        let p = pp.output_node
        let payload = @tsl.AnaglyphPassNode::of(p).unwrap()
        let algorithms : Array[@tsl.AnaglyphAlgorithm] = [
          True_,
          Grey,
          Colour,
          Dubois,
          Optimised,
          Compromise,
        ]
        let modes : Array[@tsl.AnaglyphColorMode] = [RedCyan, MagentaGreen]
        for algorithm in algorithms {
          for mode in modes {
            payload.set_algorithm(algorithm)
            payload.set_color_mode(mode)
            pp.render()
          }
        }
        p.dispose()
      },
    )
  })
  scenario("a4_pass_retro", @tsl.load_display_retro_pass_node, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let (scene, basic, standard) = pass_retro_scene()
      let pp = @nodes.RenderPipeline::new(r)
      let p = @tsl.retro_pass(scene, camera())
      pp.output_node = p
      pp.render()
      pp.render()
      // a new material version replaces (and disposes) the retro material
      basic.set_needs_update(true)
      standard.metalness = Some(0.2)
      pp.render()
      p.dispose()
      done()
    })
  })
  scenario("a4_pass_retro_options", @tsl.load_display_retro_pass_node, fn(
    env,
    done,
  ) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let (scene, _, standard) = pass_retro_scene()
      scene.as_scene().environment = standard.env_map
      standard.env_map = None
      let pp = @nodes.RenderPipeline::new(r)
      pp.output_node = @tsl.retro_pass(
        scene,
        camera(),
        affine_distortion=@nodes.uniform(0.5),
        filter_textures=true,
      )
      pp.render()
      pp.render()
      done()
    })
  })
}
