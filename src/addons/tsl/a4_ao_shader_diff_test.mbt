// Group `ao` of the A4 shader scenarios (upstream: shader_diff/a4/ao.mjs): GTAONode,
// SSGINode, SSSNode and GodraysNode, each flowed and its internal material built.

///|
fn a4_ao_persp() -> @core.Object3D {
  @core.PerspectiveCamera::new(fov=60, aspect=1.5, near=0.1, far=50)
}

///|
fn a4_ao_ortho() -> @core.Object3D {
  @core.OrthographicCamera::new(
    left=-2,
    right=2,
    top=1,
    bottom=-1,
    near=0.5,
    far=20,
  )
}

///|
fn a4_ao_gtao_internals(n : @nodes.Node) -> Array[(String, @core.Material)] {
  [("ao", @tsl.GTAONode::of(n).unwrap()._material)]
}

///|
test "a4 ao shader scenarios (compared with upstream by run.mjs)" {
  @tsl.load_display_gtao_node()
  @tsl.load_display_ssgi_node()
  @tsl.load_display_sss_node()
  @tsl.load_display_godrays_node()
  let s = A4Scenarios::new()
  // GTAO
  s.flow(
    "ao_gtao",
    fn() {
      @tsl.ao(
        @nodes.texture(a4_depth_tex("depth")),
        Some(@nodes.texture(a4_tex("normal"))),
        a4_ao_persp(),
      )
    },
    internals=a4_ao_gtao_internals,
    glsl=true,
  )
  s.flow(
    "ao_gtao_no_normal",
    fn() { @tsl.ao(@nodes.texture(a4_depth_tex("depth")), None, a4_ao_persp()) },
    internals=a4_ao_gtao_internals,
  )
  s.flow(
    "ao_gtao_ortho",
    fn() {
      @tsl.ao(
        @nodes.texture(a4_depth_tex("depth")),
        Some(@nodes.texture(a4_tex("normal"))),
        a4_ao_ortho(),
      )
    },
    internals=a4_ao_gtao_internals,
    glsl=true,
  )
  s.flow(
    "ao_gtao_options",
    fn() {
      let n = @tsl.ao(
        @nodes.texture(a4_depth_tex("depth")),
        Some(@nodes.texture(a4_tex("normal"))),
        a4_ao_persp(),
      )
      let p = @tsl.GTAONode::of(n).unwrap()
      @nodes.InputNode::set_value(p.samples, Number(32))
      @nodes.InputNode::set_value(p.radius, Number(0.5))
      @nodes.InputNode::set_value(p.distance_exponent, Number(2))
      @nodes.InputNode::set_value(p.thickness, Number(0.5))
      @nodes.InputNode::set_value(p.scale, Number(1.5))
      p.resolution_scale = 0.5
      p.use_temporal_filtering = true
      n
    },
    internals=a4_ao_gtao_internals,
  )
  s.flow(
    "ao_gtao_samples_8",
    fn() {
      let n = @tsl.ao(
        @nodes.texture(a4_depth_tex("depth")),
        None,
        a4_ao_ortho(),
      )
      @nodes.InputNode::set_value(
        @tsl.GTAONode::of(n).unwrap().samples,
        Number(8),
      )
      n
    },
    internals=a4_ao_gtao_internals,
  )
  // SSGI
  let ssgi_internals = fn(n : @nodes.Node) -> Array[(String, @core.Material)] {
    [("ssgi", @tsl.SSGINode::of(n).unwrap()._material)]
  }
  let ssgi_default = fn() {
    @tsl.ssgi(
      @nodes.texture(a4_tex("beauty")),
      @nodes.texture(a4_depth_tex("depth")),
      Some(@nodes.texture(a4_tex("normal"))),
      a4_ao_persp(),
    )
  }
  s.flow("ao_ssgi", ssgi_default, internals=ssgi_internals, glsl=true)
  s.flow("ao_ssgi_gi_node", fn() {
    let n = @tsl.SSGINode::of(ssgi_default()).unwrap()
    @nodes.vec4_of([n.get_gi_node().rgb(), n.get_ao_node().r()])
  })
  s.flow(
    "ao_ssgi_no_normal_ortho",
    fn() {
      @tsl.ssgi(
        @nodes.vec4_of([@nodes.uv(), 0, 1]),
        @nodes.texture(a4_depth_tex("depth")),
        None,
        a4_ao_ortho(),
      )
    },
    internals=fn(n) {
      let p = @tsl.SSGINode::of(n).unwrap()
      [
        ("ssgi", p._material),
        (
          "rtt",
          @nodes.RTTNode::of(p.beauty_node).unwrap()._quad_mesh.material(),
        ),
      ]
    },
  )
  s.flow(
    "ao_ssgi_options",
    fn() {
      let n = ssgi_default()
      let p = @tsl.SSGINode::of(n).unwrap()
      @nodes.InputNode::set_value(p.slice_count, Number(2))
      @nodes.InputNode::set_value(p.step_count, Number(8))
      @nodes.InputNode::set_value(p.ao_intensity, Number(0.5))
      @nodes.InputNode::set_value(p.gi_intensity, Number(4))
      @nodes.InputNode::set_value(p.radius, Number(6))
      @nodes.InputNode::set_value(p.use_screen_space_sampling, Bool(false))
      @nodes.InputNode::set_value(p.exp_factor, Number(1.5))
      @nodes.InputNode::set_value(p.thickness, Number(0.25))
      @nodes.InputNode::set_value(p.use_linear_thickness, Bool(true))
      @nodes.InputNode::set_value(p.backface_lighting, Number(0.5))
      p.use_temporal_filtering = false
      p.resolution_scale = 0.5
      n
    },
    internals=ssgi_internals,
  )
  // SSS
  let sss_internals = fn(n : @nodes.Node) -> Array[(String, @core.Material)] {
    [("sss", @tsl.SSSNode::of(n).unwrap()._material)]
  }
  s.flow(
    "ao_sss",
    fn() {
      @tsl.sss(
        @nodes.texture(a4_depth_tex("depth")),
        a4_ao_persp(),
        a4_ao_dir_light(),
      )
    },
    internals=sss_internals,
    glsl=true,
  )
  s.flow(
    "ao_sss_ortho_point",
    fn() {
      @tsl.sss(
        @nodes.texture(a4_depth_tex("depth")),
        a4_ao_ortho(),
        a4_ao_point_light(),
      )
    },
    internals=sss_internals,
    glsl=true,
  )
  s.flow(
    "ao_sss_options",
    fn() {
      let n = @tsl.sss(
        @nodes.texture(a4_depth_tex("depth")),
        a4_ao_persp(),
        a4_ao_dir_light(),
      )
      let p = @tsl.SSSNode::of(n).unwrap()
      @nodes.InputNode::set_value(p.max_distance, Number(0.2))
      @nodes.InputNode::set_value(p.thickness, Number(0.05))
      @nodes.InputNode::set_value(p.shadow_intensity, Number(0.75))
      @nodes.InputNode::set_value(p.quality, Number(1))
      p.resolution_scale = 0.5
      p.use_temporal_filtering = true
      n
    },
    internals=sss_internals,
  )
  // Godrays
  let godrays_internals = fn(
    n : @nodes.Node,
  ) -> Array[(String, @core.Material)] {
    [("godrays", @tsl.GodraysNode::of(n).unwrap()._material)]
  }
  s.flow(
    "ao_godrays_directional",
    fn() {
      @tsl.godrays(
        @nodes.texture(a4_depth_tex("depth")),
        a4_ao_persp(),
        a4_ao_with_shadow_map(
          a4_ao_dir_light(),
          @core.DepthTexture::new(width=4, height=4),
        ),
      )
    },
    internals=godrays_internals,
    glsl=true,
  )
  s.flow(
    "ao_godrays_point",
    fn() {
      @tsl.godrays(
        @nodes.texture(a4_depth_tex("depth")),
        a4_ao_persp(),
        a4_ao_with_shadow_map(
          a4_ao_point_light(),
          @core.CubeDepthTexture::new(size=4),
        ),
      )
    },
    internals=godrays_internals,
    glsl=true,
  )
  s.flow(
    "ao_godrays_options",
    fn() {
      let n = @tsl.godrays(
        @nodes.texture(a4_depth_tex("depth")),
        a4_ao_ortho(),
        a4_ao_with_shadow_map(
          a4_ao_dir_light(),
          @core.DepthTexture::new(width=4, height=4),
        ),
      )
      let p = @tsl.GodraysNode::of(n).unwrap()
      @nodes.InputNode::set_value(p.raymarch_steps, Number(30))
      @nodes.InputNode::set_value(p.density, Number(0.5))
      @nodes.InputNode::set_value(p.max_density, Number(0.8))
      @nodes.InputNode::set_value(p.distance_attenuation, Number(1))
      p.resolution_scale = 1
      n
    },
    internals=godrays_internals,
  )
  a4_run(s)
}

///|
fn a4_ao_dir_light() -> @core.Object3D {
  let l = @core.DirectionalLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=2,
  )
  l.position.set(1, 2, 3) |> ignore
  l.cast_shadow = true
  l
}

///|
fn a4_ao_point_light() -> @core.Object3D {
  let l = @core.PointLight::new(
    color=@math.Color::from_hex(0xffffff),
    intensity=3,
    distance=10,
    decay=2,
  )
  l.position.set(-1, 2, 1) |> ignore
  l.cast_shadow = true
  l
}

///|
/// `light.shadow.map = new RenderTarget( 4, 4, { depthTexture } )`.
fn a4_ao_with_shadow_map(
  l : @core.Object3D,
  depth_texture : @core.Texture,
) -> @core.Object3D {
  match l.kind {
    Light(light) =>
      light.shadow.unwrap().map = Some(
        @core.RenderTarget::new(width=4, height=4, depth_texture~),
      )
    _ => ()
  }
  l
}
