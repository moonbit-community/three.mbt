// Group `simple` of the A5 shader scenarios (upstream: shader_diff/a5/simple.mjs):
// FilmNode, Sepia, MotionBlur, Lut3DNode, ChromaticAberrationNode, TransitionNode,
// hashBlur, ParallaxBarrierPassNode, AfterImageNode, BilateralBlurNode, LensflareNode,
// DenoiseNode, boxBlur and Shape.

///|
fn a5s_t(name : String) -> @nodes.Node {
  @nodes.texture(a5_tex(name))
}

///|
fn a5s_v4(name : String) -> @nodes.Node {
  @nodes.vec4_of([0.1, 0.2, 0.3, 0.4]).to_var(name~)
}

///|
fn a5s_opts(entries : Array[(String, &@nodes.IntoTsl)]) -> @nodes.TslValue {
  @tsl.addon_options(entries)
}

///|
test "a5 simple shader scenarios (compared with upstream by run.mjs)" {
  a5_run(
    fn() {
      @tsl.load_display_sepia()
      @tsl.load_display_motion_blur()
      @tsl.load_display_hash_blur()
      @tsl.load_display_stereo_composite_pass_node()
      @tsl.load_display_after_image_node()
      @tsl.load_display_bilateral_blur_node()
      @tsl.load_display_lensflare_node()
      @tsl.load_display_box_blur()
      @tsl.load_display_shape()
    },
    fn() {
      let s = A5Scenarios::new()
      let t = a5s_t
      let v4 = a5s_v4
      // FilmNode (nodeProxy)
      s.flow("film", fn() { @tsl.film(t("film")) }, glsl=true)
      s.flow(
        "film_intensity_uv",
        fn() {
          @tsl.film(
            t("film"),
            intensity_node=@nodes.uniform(0.5),
            uv_node=@nodes.uv().mul(2),
          )
        },
        glsl=true,
      )
      s.flow("film_number", fn() { @tsl.film(v4("c"), intensity_node=0.25) })
      s.flow("film_uv_only", fn() {
        @tsl.film(t("film"), uv_node=@nodes.uv(index=1))
      })

      // Sepia
      s.flow("sepia", fn() { @tsl.sepia().call([t("sepia")]) }, glsl=true)
      s.flow("sepia_var", fn() {
        @tsl.sepia().call([v4("c")]).add(@tsl.sepia().call([v4("d")]))
      })

      // MotionBlur
      s.flow(
        "motion_blur",
        fn() { @tsl.motion_blur().call([t("beauty"), t("velocity").xy()]) },
        glsl=true,
      )
      s.flow("motion_blur_samples", fn() {
        @tsl.motion_blur().call([
          t("beauty"),
          t("velocity").xy().mul(0.5),
          @nodes.int(8),
        ])
      })
      s.flow("motion_blur_number", fn() {
        @tsl.motion_blur().call([
          t("beauty"),
          @nodes.uniform(@math.Vector2::new(0.01, 0.0)),
          4,
        ])
      })

      // Lut3DNode
      s.flow(
        "lut3d",
        fn() {
          @tsl.lut3_d(
            t("in"),
            @nodes.texture3d(@core.Data3DTexture::new()),
            32,
            @nodes.uniform(1),
          )
        },
        glsl=true,
      )
      s.flow("lut3d_numbers", fn() {
        @tsl.lut3_d(
          v4("c"),
          @nodes.texture3d(@core.Data3DTexture::new()),
          16,
          0.5,
        )
      })

      // ChromaticAberrationNode
      s.flow(
        "chromatic_aberration",
        fn() {
          @tsl.chromatic_aberration(
            t("ca"),
            strength=@nodes.uniform(1.5),
            center=@nodes.uniform(@math.Vector2::new(0.5, 0.5)),
            scale=@nodes.uniform(1.2),
          )
        },
        glsl=true,
      )
      s.flow("chromatic_aberration_defaults", fn() {
        @tsl.chromatic_aberration(
          @nodes.texture(a5_tex("ca"), uv_node=@nodes.uv().mul(0.5)),
          center=@nodes.vec2_of([0.5, 0.25]),
        )
      })
      s.flow("chromatic_aberration_rtt", fn() {
        @tsl.chromatic_aberration(
          t("ca").mul(0.5),
          strength=2,
          center=@nodes.vec2(0.5),
          scale=1.5,
        )
      })

      // TransitionNode
      s.flow(
        "transition",
        fn() {
          @tsl.transition(
            t("a"),
            t("b"),
            t("mix"),
            @nodes.uniform(0.5),
            @nodes.uniform(0.1),
            @nodes.uniform(1, type_="int"),
          )
        },
        glsl=true,
      )
      s.flow("transition_numbers", fn() {
        @tsl.transition(
          t("a"),
          @nodes.texture(a5_tex("b"), uv_node=@nodes.uv().mul(2)),
          t("mix"),
          0.3,
          0.2,
          0,
        )
      })

      // hashBlur
      s.flow("hash_blur", fn() { @tsl.hash_blur().call([t("h")]) }, glsl=true)
      s.flow(
        "hash_blur_options",
        fn() {
          @tsl.hash_blur().call([
            t("h"),
            @nodes.uniform(0.05),
            a5s_opts([
              ("repeats", @nodes.uniform(10)),
              ("premultipliedAlpha", true),
            ]),
          ])
        },
        glsl=true,
      )
      s.flow("hash_blur_numbers", fn() {
        @tsl.hash_blur().call([
          @nodes.texture(a5_tex("h"), uv_node=@nodes.uv().mul(2)),
          0.2,
          a5s_opts([("repeats", 8)]),
        ])
      })
      s.flow("hash_blur_premult_false", fn() {
        @tsl.hash_blur().call([
          t("h"),
          0.1,
          a5s_opts([("premultipliedAlpha", false)]),
        ])
      })
      s.flow("hash_blur_rtt", fn() { @tsl.hash_blur().call([t("h").mul(0.5)]) })

      // ParallaxBarrierPassNode: its composite material
      let parallax_ref : Ref[@nodes.Node?] = Ref(None)
      let parallax_material = fn(n : @nodes.Node) {
        let n = match parallax_ref.val {
          Some(p) => p
          None => n
        }
        [
          (
            "parallax",
            @tsl.ParallaxBarrierPassNode::of(n).unwrap().stereo._material.unwrap(),
          ),
        ]
      }
      s.flow(
        "pass_parallax_barrier",
        fn() {
          parallax_ref.val = None
          @tsl.parallax_barrier_pass(
            @core.Scene::new(),
            @core.PerspectiveCamera::new(),
          )
        },
        glsl=true,
        internals=parallax_material,
      )
      s.flow(
        "pass_parallax_barrier_mul",
        fn() {
          let p = @tsl.parallax_barrier_pass(
            @core.Scene::new(),
            @core.PerspectiveCamera::new(),
          )
          parallax_ref.val = Some(p)
          p.mul(2)
        },
        internals=parallax_material,
      )

      // AfterImageNode: the composite material
      let after_image_material = fn(n : @nodes.Node) {
        [
          (
            "composed",
            @tsl.AfterImageNode::of(n).unwrap()._material_composed.unwrap(),
          ),
        ]
      }
      s.flow(
        "after_image",
        fn() { @tsl.after_image(t("ai")) },
        glsl=true,
        internals=after_image_material,
      )
      s.flow(
        "after_image_damp",
        fn() {
          @tsl.after_image(
            @nodes.texture(a5_tex("ai"), uv_node=@nodes.uv().mul(0.5)),
            damp=@nodes.uniform(0.9),
          )
        },
        glsl=true,
        internals=after_image_material,
      )
      s.flow(
        "after_image_number",
        fn() { @tsl.after_image(t("ai"), damp=0.8) },
        internals=after_image_material,
      )
      s.flow(
        "after_image_rtt",
        fn() { @tsl.after_image(t("ai").mul(0.5)) },
        internals=after_image_material,
      )

      // BilateralBlurNode: the blur material
      let bilateral_material = fn(n : @nodes.Node) {
        [("blur", @tsl.BilateralBlurNode::of(n).unwrap()._material.unwrap())]
      }
      s.flow(
        "bilateral_blur",
        fn() { @tsl.bilateral_blur(t("bb")) },
        glsl=true,
        internals=bilateral_material,
      )
      s.flow(
        "bilateral_blur_options",
        fn() {
          @tsl.bilateral_blur(
            @nodes.texture(a5_tex("bb"), uv_node=@nodes.uv().mul(2)),
            direction_node=@nodes.vec2_of([1, 0]),
            sigma=2,
            sigma_color=0.2,
          )
        },
        glsl=true,
        internals=bilateral_material,
      )
      s.flow(
        "bilateral_blur_number",
        fn() { @tsl.bilateral_blur(t("bb"), direction_node=2, sigma=1.5) },
        internals=bilateral_material,
      )
      s.flow(
        "bilateral_blur_vector",
        fn() {
          @tsl.bilateral_blur(
            t("bb"),
            direction_node=@math.Vector2::new(0.5, 2.0),
            sigma=1,
            sigma_color=0.05,
          )
        },
        internals=bilateral_material,
      )

      // LensflareNode: its material
      let lensflare_material = fn(n : @nodes.Node) {
        [("lensflare", @tsl.LensflareNode::of(n).unwrap()._material)]
      }
      s.flow(
        "lensflare",
        fn() { @tsl.lensflare(t("lf")) },
        glsl=true,
        internals=lensflare_material,
      )
      s.flow(
        "lensflare_params",
        fn() {
          @tsl.lensflare(
            t("lf"),
            ghost_tint=@nodes.uniform(@math.Color::new(1.0, 0.5, 0.2)),
            threshold=@nodes.uniform(0.7),
            ghost_samples=6,
            ghost_spacing=0.3,
            ghost_attenuation_factor=@nodes.uniform(20),
            down_sample_ratio=2,
          )
        },
        glsl=true,
        internals=lensflare_material,
      )
      s.flow(
        "lensflare_some",
        fn() {
          @tsl.lensflare(
            t("lf").mul(0.5),
            ghost_tint=@nodes.vec3_of([1, 0.8, 0.6]),
            ghost_samples=@nodes.uniform(3),
          )
        },
        internals=lensflare_material,
      )

      // DenoiseNode
      s.flow(
        "denoise",
        fn() {
          @tsl.denoise(
            t("ao"),
            @nodes.texture(a5_depth_tex("depth")),
            Some(t("normal")),
            @core.PerspectiveCamera::new(),
          )
        },
        glsl=true,
      )
      s.flow(
        "denoise_from_depth",
        fn() {
          @tsl.denoise(
            t("ao"),
            @nodes.texture(a5_depth_tex("depth")),
            None,
            @core.PerspectiveCamera::new(),
          )
        },
        glsl=true,
      )
      s.flow("denoise_uniforms", fn() {
        let d = @tsl.denoise(
          t("ao").mul(0.5),
          @nodes.texture(a5_depth_tex("depth")),
          Some(t("normal")),
          @core.OrthographicCamera::new(),
        )
        @nodes.InputNode::set_value(
          @tsl.DenoiseNode::of(d).unwrap().index,
          Number(2),
        )
        d
      })

      // boxBlur
      s.flow("box_blur", fn() { @tsl.box_blur().call([t("box")]) }, glsl=true)
      s.flow(
        "box_blur_options",
        fn() {
          @tsl.box_blur().call([
            t("box"),
            a5s_opts([
              ("size", 2),
              ("separation", 3),
              ("premultipliedAlpha", true),
            ]),
          ])
        },
        glsl=true,
      )
      s.flow("box_blur_nodes", fn() {
        @tsl.box_blur().call([
          @nodes.texture(a5_tex("box"), uv_node=@nodes.uv().mul(2)),
          a5s_opts([
            ("size", @nodes.int(1)),
            ("separation", @nodes.uniform(1.5)),
            ("premultipliedAlpha", false),
          ]),
        ])
      })
      s.flow("box_blur_rtt", fn() {
        @tsl.box_blur().call([t("box").mul(0.5), a5s_opts([("size", 1)])])
      })

      // Shape
      s.flow("circle", fn() { @tsl.circle().call([]) }, glsl=true)
      s.flow(
        "circle_args",
        fn() {
          @tsl.circle().call([@nodes.uniform(0.8), 0.2, @nodes.uv().mul(2)])
        },
        glsl=true,
      )
      s.flow("circle_scale", fn() { @tsl.circle().call([0.5]) })
      s
    },
  )
}
