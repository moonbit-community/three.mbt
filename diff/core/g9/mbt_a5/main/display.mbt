// A5 mock-GPU scenarios of the display add-ons (harness/a5_scenarios.mjs, step for step).

///|
fn register_display() -> Unit {
  scenario("a5_bloom", @tsl.load_display_bloom_node, fn(env, done) {
    pipeline(env, done, 2, fn(p, _, _, _) {
      p.add(@tsl.bloom(p, strength=1.2, radius=0.3, threshold=0.1))
    })
  })
  scenario("a5_bloom_nodes", @tsl.load_display_bloom_node, fn(env, done) {
    pipeline(
      env,
      done,
      2,
      fn(p, _, _, _) {
        let b = @tsl.bloom(
          p.get_texture_node(),
          strength=@nodes.uniform(1),
          radius=@nodes.uniform(0.5),
          threshold=@nodes.uniform(0.2),
        )
        @tsl.BloomNode::of(b).unwrap().set_resolution_scale(0.25) |> ignore
        b
      },
      options={ ..no_options, after: Some(fn(pp) { pp.output_node.dispose() }) },
    )
  })
  scenario("a5_smaa", @tsl.load_display_smaa_node, fn(env, done) {
    pipeline(env, done, 2, fn(p, _, _, _) { @tsl.smaa(p) })
  })
  scenario("a5_ssao", @tsl.load_display_ssao_node, fn(env, done) {
    pipeline(
      env,
      done,
      2,
      fn(p, c, _, _) {
        let ao = @tsl.ssao(
          p.get_texture_node(name="depth"),
          p.get_texture_node(name="normal"),
          c,
        )
        @nodes.InputNode::set_value(
          @tsl.SSAONode::of(ao).unwrap().radius,
          Number(0.6),
        )
        p.mul(ao.r())
      },
      options={ ..no_options, mrt: Some(normal_mrt) },
    )
  })
  scenario("a5_outline", @tsl.load_display_outline_node, fn(env, done) {
    pipeline(env, done, 2, fn(p, c, s, _) {
      let o = @tsl.outline(
        s,
        c,
        selected_objects=[child(s, 2)],
        edge_thickness=@nodes.uniform(2),
        edge_glow=@nodes.uniform(1),
      )
      p
      .add(@tsl.OutlineNode::visible_edge(o).mul(3))
      .add(@tsl.OutlineNode::hidden_edge(o))
    })
  })
  scenario(
    "a5_film_chromatic_lut",
    no_modules,
    fn(env, done) {
      pipeline(env, done, 2, fn(p, _, _, _) {
        let data = @core.TypedArray::uint8(4 * 4 * 4 * 4)
        for i in 0..<data.length() {
          data.set(i, (i * 37 % 256).to_double())
        }
        let lut = @core.Data3DTexture::new(data~, width=4, height=4, depth=4)
        lut.set_needs_update(true)
        let ca = @tsl.chromatic_aberration(
          p,
          strength=1.5,
          center=@nodes.vec2_of([0.5, 0.5]),
          scale=1.2,
        )
        @tsl.film(
          @tsl.lut3_d(ca, @nodes.texture3d(lut), 4, @nodes.uniform(0.8)),
          intensity_node=@nodes.uniform(0.4),
        )
      })
    },
  )
  scenario(
    "a5_motion_blur_sepia",
    fn() {
      @tsl.load_display_motion_blur()
      @tsl.load_display_sepia()
    },
    fn(env, done) {
      pipeline(
        env,
        done,
        3,
        fn(p, _, _, _) {
          @tsl.sepia().call([
            @tsl.motion_blur().call([
              p.get_texture_node(),
              p.get_texture_node(name="velocity").mul(2),
              @nodes.int(4),
            ]),
          ])
        },
        options={ ..no_options, mrt: Some(velocity_mrt), step: Some(move_box) },
      )
    },
  )
  scenario("a5_after_image", @tsl.load_display_after_image_node, fn(env, done) {
    pipeline(
      env,
      done,
      3,
      fn(p, _, _, _) { @tsl.after_image(p, damp=0.9) },
      options={ ..no_options, step: Some(move_box) },
    )
  })
  scenario("a5_fsr1", @tsl.load_display_fsr1_node, fn(env, done) {
    pipeline(env, done, 2, fn(p, _, _, _) {
      @tsl.fsr1(p, sharpness=0.3, denoise=true)
    })
  })
  scenario(
    "a5_bilateral_lensflare",
    fn() {
      @tsl.load_display_bilateral_blur_node()
      @tsl.load_display_lensflare_node()
    },
    fn(env, done) {
      pipeline(env, done, 2, fn(p, _, _, _) {
        @tsl.bilateral_blur(
          p,
          direction_node=@nodes.vec2_of([1, 1]),
          sigma=3.0,
          sigma_color=0.2,
        ).add(@tsl.lensflare(p, threshold=@nodes.float(0.3)))
      })
    },
  )
  scenario("a5_denoise", no_modules, fn(env, done) {
    pipeline(
      env,
      done,
      2,
      fn(p, c, _, _) {
        @tsl.denoise(
          p.get_texture_node(),
          p.get_texture_node(name="depth"),
          Some(p.get_texture_node(name="normal")),
          c,
        )
      },
      options={ ..no_options, mrt: Some(normal_mrt) },
    )
  })
  scenario(
    "a5_parallax_barrier",
    @tsl.load_display_parallax_barrier_pass_node,
    fn(env, done) {
      let r = renderer(env)
      r.init(on_done=fn(_) {
        let pp = @nodes.RenderPipeline::new(r)
        pp.output_node = @tsl.parallax_barrier_pass(lit_scene(), camera())
        pp.render()
        tick(r)
        pp.render()
        pp.output_node.dispose()
        done()
      })
    },
  )
  scenario(
    "a5_transition_blurs",
    fn() {
      @tsl.load_display_box_blur()
      @tsl.load_display_hash_blur()
      @tsl.load_display_shape()
    },
    fn(env, done) {
      pipeline(env, done, 2, fn(p, _, _, _) {
        let a = @tsl.box_blur().call([
          p.get_texture_node(),
          @tsl.addon_options([
            ("size", @nodes.int(1)),
            ("separation", @nodes.int(2)),
          ]),
        ])
        let b = @tsl.hash_blur().call([
          p.get_texture_node(),
          0.05,
          @tsl.addon_options([("repeats", 4)]),
        ])
        @tsl.transition(
          a,
          b,
          @tsl.circle().call([0.5, 0.2]),
          @nodes.uniform(0.4),
          @nodes.uniform(0.1),
          @nodes.uniform(1),
        )
      })
    },
  )
}

///|
fn register_temporal() -> Unit {
  scenario("a5_traa", @tsl.load_display_traa_node, fn(env, done) {
    pipeline(
      env,
      done,
      4,
      fn(p, c, _, _) {
        @tsl.traa(
          p.get_texture_node(),
          p.get_texture_node(name="depth"),
          p.get_texture_node(name="velocity"),
          c,
        )
      },
      options={ ..no_options, mrt: Some(velocity_mrt), step: Some(move_box) },
    )
  })
  scenario("a5_taau", @tsl.load_display_taau_node, fn(env, done) {
    pipeline(
      env,
      done,
      4,
      fn(p, c, _, _) {
        @tsl.taau(
          p.get_texture_node(),
          p.get_texture_node(name="depth"),
          p.get_texture_node(name="velocity"),
          c,
        )
      },
      options={ ..no_options, mrt: Some(velocity_mrt), step: Some(move_box) },
    )
  })
  scenario(
    "a5_temporal_reproject",
    @tsl.load_display_temporal_reproject_node,
    fn(env, done) {
      pipeline(
        env,
        done,
        3,
        fn(p, c, _, _) {
          @tsl.temporal_reproject(
            p.get_texture_node(),
            p.get_texture_node(name="depth"),
            p.get_texture_node(name="normal"),
            p.get_texture_node(name="velocity"),
            c,
          )
        },
        options={ ..no_options, mrt: Some(all_mrt), step: Some(move_box) },
      )
    },
  )
  scenario("a5_oit", @tsl.load_display_oit_pass_node, fn(env, done) {
    let r = renderer(env)
    r.init(on_done=fn(_) {
      let scene = lit_scene()
      for i in 0..<2 {
        let m = @nodes.MeshStandardNodeMaterial::new()
        m.transparent = true
        m.opacity = 0.5
        m.color.unwrap().set_hex(if i == 0 { 0xff4400 } else { 0x00ff88 })
        |> ignore
        let s = @core.Mesh::new(
          geometry=@geometries.SphereGeometry::new(
            radius=0.4,
            width_segments=8,
            height_segments=6,
          ),
          material=Single(m),
        )
        s.position.set(i.to_double() * 0.5 - 0.25, 0.0, 0.8) |> ignore
        scene.add(s) |> ignore
      }
      let cam = camera()
      let pp = @nodes.RenderPipeline::new(r)
      pp.output_node = @tsl.oit_pass(scene, cam)
      pp.render()
      tick(r)
      pp.render()
      // the transparent materials again outside the OIT pass (their own depthWrite)
      tick(r)
      r.render(scene, cam)
      done()
    })
  })
}
