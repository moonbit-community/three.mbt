// Group `utils` of the A5 shader scenarios (upstream: shader_diff/a5/utils.mjs):
// tsl/utils (SpecularHelpers, TAAUtils, RNoise, GroundedSkybox, Raymarching,
// SoftParticles) and tsl/math (Bayer, curlNoise, voronoiNoise).

///|
fn a5_fv(v : Double, name : String) -> @nodes.Node {
  @nodes.float(v).to_var(name~)
}

///|
fn a5_v2(name : String) -> @nodes.Node {
  @nodes.vec2_of([0.25, 0.5]).to_var(name~)
}

///|
fn a5_v3(name : String) -> @nodes.Node {
  @nodes.vec3_of([0.1, 0.2, 0.3]).to_var(name~)
}

///|
fn a5_v4(name : String) -> @nodes.Node {
  @nodes.vec4_of([0.1, 0.2, 0.3, 0.4]).to_var(name~)
}

///|
test "a5 utils shader scenarios (compared with upstream by run.mjs)" {
  a5_run(
    fn() {
      @tsl.load_utils_specular_helpers()
      @tsl.load_utils_taa_utils()
      @tsl.load_utils_grounded_skybox()
      @tsl.load_utils_raymarching()
      @tsl.load_utils_soft_particles()
      @tsl.load_math_bayer()
      @tsl.load_math_curl_noise()
      @tsl.load_math_voronoi_noise()
    },
    fn() {
      let s = A5Scenarios::new()
      s.flow("specular_d_gtr", fn() {
        @tsl.d_gtr().call([a5_fv(0.5, "r"), a5_fv(0.8, "h"), @nodes.float(2)])
      })
      s.flow(
        "specular_terms",
        fn() {
          @tsl.f_schlick()
          .call([a5_v3("f0"), a5_fv(0.3, "t")])
          .mul(
            @tsl.geometry_term().call([a5_fv(0.5, "l"), a5_fv(0.6, "v"), 0.4]),
          )
          .add(
            @tsl.f_schlick().call([
              a5_v3("f1"),
              a5_fv(0.2, "t2"),
              a5_fv(0.9, "f90"),
            ]),
          )
          .mul(@tsl.smith_g().call([a5_fv(0.5, "x"), 0.3]))
        },
        glsl=true,
      )
      s.flow("specular_dominant", fn() {
        @tsl.get_specular_dominant_factor().call([
          a5_fv(0.5, "nov"),
          a5_fv(0.3, "rough"),
        ])
      })
      s.flow(
        "specular_ggx_sample",
        fn() {
          let r = @tsl.ggx_reflection_sample(
            a5_v3("n"),
            a5_v3("v"),
            a5_fv(0.4, "rough"),
            a5_fv(0.2, "metal"),
            a5_v3("albedo"),
            a5_v4("xi"),
          )
          @nodes.vec4_of([r.get("reflectDir"), r.get("pdf")])
        },
        glsl=true,
      )
      s.flow("specular_ggx_sample_f0", fn() {
        let r = @tsl.ggx_reflection_sample(
          a5_v3("n"),
          a5_v3("v"),
          a5_fv(0.4, "rough"),
          a5_fv(0.2, "metal"),
          a5_v3("albedo"),
          a5_v4("xi"),
          f0=a5_v3("f0"),
          f90=0.5,
        )
        r.get("sampleWeight")
      })
      s.flow("specular_equirect", fn() {
        @tsl.equirect_uv_to_dir()
        .call([a5_v2("uv")])
        .mul(@tsl.equirect_dir_pdf().call([a5_v3("dir")]))
        .mul(@tsl.mis_power_heuristic().call([a5_fv(1, "a"), a5_fv(2, "b")]))
      })
      s.flow(
        "taa_clip_flicker",
        fn() {
          @tsl.clip_aabb()
          .call([a5_v4("c"), a5_v4("h"), a5_v4("mn"), a5_v4("mx")])
          .add(
            @tsl.flicker_reduction().call([
              a5_v4("c2"),
              a5_v4("h2"),
              a5_fv(0.1, "w"),
            ]),
          )
        },
        glsl=true,
      )
      s.flow("taa_sample_depth", fn() {
        let r = @tsl.sample_current_depth().call([
          @nodes.texture(a5_depth_tex("depth")),
          @nodes.vec2_of([4, 4]),
          @nodes.uniform(@math.Vector2::new(0.1, 100.0)),
        ])
        @nodes.vec4_of([
          r.get("closestDepth"),
          r.get("closestPositionTexel"),
          r.get("farthestDepth"),
        ])
      })
      s.flow("taa_previous_depth", fn() {
        @tsl.sample_previous_depth().call([
          @nodes.texture(a5_depth_tex("prev")),
          @nodes.uv(),
          @nodes.uniform(@math.Matrix4::new()),
          @nodes.uniform(@math.Matrix4::new()),
          @nodes.uniform(@math.Matrix4::new()),
          @nodes.uniform(@math.Vector2::new(0.1, 100.0)),
          @core.PerspectiveCamera::new(),
        ])
      })
      s.flow("taa_previous_depth_ortho", fn() {
        @tsl.sample_previous_depth().call([
          @nodes.texture(a5_depth_tex("prev")),
          @nodes.uv(),
          @nodes.uniform(@math.Matrix4::new()),
          @nodes.uniform(@math.Matrix4::new()),
          @nodes.uniform(@math.Matrix4::new()),
          @nodes.uniform(@math.Vector2::new(0.1, 100.0)),
          @core.OrthographicCamera::new(),
        ])
      })
      s.flow(
        "rnoise",
        fn() {
          @tsl.bind_analytic_noise(
            @nodes.uniform(@math.Vector2::new(64, 32)),
            seed=3,
          ).call([@nodes.uv(), @nodes.int(2)])
        },
        glsl=true,
      )
      s.flow("rnoise_default_seed", fn() {
        @tsl.bind_analytic_noise(@nodes.vec2_of([8, 8])).call([@nodes.uv(), 1])
      })
      s.flow(
        "grounded_skybox",
        fn() {
          @tsl.get_ground_projected_normal().call([
            @nodes.float(15),
            @nodes.uniform(3),
          ])
        },
        glsl=true,
      )
      s.whole(
        "raymarching",
        fn() {
          let m = @nodes.MeshBasicNodeMaterial::new()
          let color = @nodes.vec4(0).to_var(name="acc")
          @nodes.NodeMaterial::of(m).unwrap().fragment_node = Some(
            @nodes.fn_(fn(_, _) {
              @tsl.raymarching_box(8, fn(position_ray, step_size) {
                color.add_assign(@nodes.vec4_of([position_ray, step_size]))
              })
              Some(color)
            }).call([]),
          )
          m
        },
        glsl=true,
      )
      s.whole("soft_particles", fn() {
        let m = @nodes.MeshBasicNodeMaterial::new()
        @nodes.NodeMaterial::of(m).unwrap().opacity_node = Some(
          @tsl.soft_particles(distance=@nodes.uniform(2), contrast=3),
        )
        m
      })
      s.whole("soft_particles_default", fn() {
        let m = @nodes.MeshBasicNodeMaterial::new()
        @nodes.NodeMaterial::of(m).unwrap().opacity_node = Some(
          @tsl.soft_particles(opacity=@nodes.uniform(0.5)),
        )
        m
      })
      s.flow(
        "bayer",
        fn() {
          @tsl.bayer16()
          .call([@nodes.screen_coordinate])
          .r()
          .add(@tsl.bayer_dither().call([a5_v3("c")]).x())
          .add(@tsl.bayer_dither().call([a5_v3("c2"), 8]).y())
        },
        glsl=true,
      )
      s.flow(
        "curl_noise",
        fn() { @tsl.curl_noise().call([a5_v3("p")]) },
        glsl=true,
      )
      s.flow("snoise", fn() {
        @tsl.snoise()
        .call([a5_v3("p")])
        .add(@tsl.permute().call([a5_v4("x")]).x())
      })
      s.flow(
        "voronoi",
        fn() {
          @tsl.voronoi2d()
          .call([a5_v2("p"), @nodes.uniform(1.5)])
          .add(@tsl.voronoi3d().call([a5_v3("q"), @nodes.uniform(0.5)]))
          .add(@tsl.hash2d().call([a5_v2("h")]).x())
          .add(@tsl.hash3d().call([a5_v3("h3")]).y())
        },
        glsl=true,
      )
      s
    },
  )
}
