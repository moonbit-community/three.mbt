// A4 shader scenarios of group `ssr` (harness/shader_diff/a4/ssr.mjs): SSRNode and
// RecurrentDenoiseNode, through WGSLNodeBuilder (and GLSLNodeBuilder for `glsl=true`).

///|
fn a4_ssr_persp() -> @core.Object3D {
  let c = @core.PerspectiveCamera::new(fov=50.0, aspect=1.5, near=0.1, far=20.0)
  c.position.set(0.0, 1.0, 3.0) |> ignore
  c.update_matrix_world()
  c
}

///|
fn a4_ssr_ortho() -> @core.Object3D {
  let c = @core.OrthographicCamera::new(
    left=-2.0,
    right=2.0,
    top=1.5,
    bottom=-1.5,
    near=0.1,
    far=10.0,
  )
  c.position.set(0.0, 0.0, 4.0) |> ignore
  c.update_matrix_world()
  c
}

///|
/// An equirectangular half-float HDR (4x2) with CPU-side data.
fn a4_ssr_hdr() -> @core.Texture {
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
  t.name = "hdr"
  t
}

///|
priv struct A4SSRInputs {
  color : @nodes.Node
  depth : @nodes.Node
  normal : @nodes.Node
  mr : @nodes.Node
}

///|
fn a4_ssr_inputs() -> A4SSRInputs {
  let color = @nodes.texture(a4_tex("color"))
  let depth = @nodes.texture(a4_depth_tex("depth"))
  let normal = @nodes.texture(a4_tex("normal"))
  let mr = @nodes.texture(a4_tex("metalrough"))
  { color, depth, normal, mr, }
}

///|
fn a4_ssr_internals(n : @nodes.Node) -> Array[(String, @core.Material)] {
  let p = @tsl.SSRNode::of(n).unwrap()
  let list = [("ssr", p._ssr_material)]
  if p.stochastic == false {
    list.push(("blur", p._blur_material))
  }
  list.push(("copy", p._copy_material))
  list
}

///|
fn a4_rd_internals(n : @nodes.Node) -> Array[(String, @core.Material)] {
  [("denoise", @tsl.RecurrentDenoiseNode::of(n).unwrap()._material)]
}

///|
fn a4_ssr_set(node : @nodes.Node, value : Double) -> Unit {
  @nodes.InputNode::set_value(node, Number(value))
}

///|
test "a4 ssr shader scenarios (compared with upstream by run.mjs)" {
  // the upstream group imports SSRNode.js, then RecurrentDenoiseNode.js
  @tsl.load_display_ssr_node()
  @tsl.load_display_recurrent_denoise_node()
  let s = A4Scenarios::new()
  s.flow(
    "ssr_ssr_mirror_roughness",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=a4_ssr_persp(),
      )
    },
    internals=a4_ssr_internals,
    glsl=true,
  )
  s.flow(
    "ssr_ssr_mirror_scalar_roughness",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        metalness_node=i.mr.r(),
        roughness_node=@nodes.float(0.2),
        camera=a4_ssr_persp(),
      )
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_mirror_options",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        reflect_non_metals=true,
        binary_refine=true,
        camera=a4_ssr_persp(),
      )
      let p = @tsl.SSRNode::of(n).unwrap()
      p.set_blur_quality(3)
      p.resolution_scale = 0.5
      a4_ssr_set(p.max_distance, 4)
      a4_ssr_set(p.thickness, 0.02)
      a4_ssr_set(p.quality, 0.8)
      a4_ssr_set(p.intensity, 0.7)
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_mirror_ortho",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=a4_ssr_ortho(),
      )
    },
    internals=a4_ssr_internals,
    glsl=true,
  )
  s.flow(
    "ssr_ssr_mirror_ortho_refine",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=a4_ssr_ortho(),
      )
      @tsl.SSRNode::of(n).unwrap().set_binary_refine(true)
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_stochastic",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=a4_ssr_persp(),
      )
    },
    internals=a4_ssr_internals,
    glsl=true,
  )
  s.flow(
    "ssr_ssr_stochastic_specular",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        specular_node=@nodes.texture(a4_tex("spec")).rgb(),
        specular_f90_node=@nodes.texture(a4_tex("f90")).r(),
        diffuse_node=@nodes.texture(a4_tex("diffuse")),
        camera=a4_ssr_persp(),
      )
      let p = @tsl.SSRNode::of(n).unwrap()
      p.set_step_exponent(3)
      a4_ssr_set(p.mirror_bias, 0.5)
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_stochastic_diffuse_fade_black",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        diffuse_node=@nodes.texture(a4_tex("diffuse")),
        camera=a4_ssr_persp(),
      )
      @tsl.SSRNode::of(n).unwrap().set_screen_edge_fade_black(true)
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_stochastic_env_brdf",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        environment_node=a4_ssr_hdr(),
        camera=a4_ssr_persp(),
      )
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_stochastic_env_mis",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        environment_node=a4_ssr_hdr(),
        env_importance_sampling=true,
        binary_refine=true,
        camera=a4_ssr_persp(),
      )
      @tsl.SSRNode::of(n).unwrap().set_screen_edge_fade_black(true)
      n
    },
    internals=a4_ssr_internals,
    glsl=true,
  )
  s.flow(
    "ssr_ssr_stochastic_env_ortho",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=a4_ssr_ortho(),
      )
      @tsl.SSRNode::of(n).unwrap().set_env_map(Some(a4_ssr_hdr()))
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_history",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=a4_ssr_persp(),
      )
      @tsl.SSRNode::of(n)
      .unwrap()
      .set_history(
        Some(a4_tex("history")),
        Some(@nodes.texture(a4_tex("velocity"))),
      )
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_history_denoise",
    fn() {
      let i = a4_ssr_inputs()
      let cam = a4_ssr_persp()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=cam,
      )
      let d = @tsl.recurrent_denoise(
        n,
        cam,
        depth=i.depth,
        normal=i.normal,
        raw=n,
        mode="specular",
        metal_roughness=i.mr,
      )
      @tsl.SSRNode::of(n)
      .unwrap()
      .set_history(Some(d), Some(@nodes.texture(a4_tex("velocity"))))
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_ssr_env_cleared",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        environment_node=a4_ssr_hdr(),
        camera=a4_ssr_persp(),
      )
      @tsl.SSRNode::of(n).unwrap().set_env_map(None)
      n
    },
    internals=a4_ssr_internals,
  )
  s.flow(
    "ssr_rd_diffuse",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.recurrent_denoise(
        @nodes.texture(a4_tex("in")),
        a4_ssr_persp(),
        depth=i.depth,
        normal=i.normal,
        raw=@nodes.texture(a4_tex("raw")),
      )
    },
    internals=a4_rd_internals,
    glsl=true,
  )
  s.flow(
    "ssr_rd_specular",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.recurrent_denoise(
        @nodes.texture(a4_tex("in")),
        a4_ssr_persp(),
        depth=i.depth,
        normal=i.normal,
        raw=a4_tex("raw"),
        metal_roughness=i.mr,
        diffuse=@nodes.texture(a4_tex("diffuse")),
        mode="specular",
      )
      a4_ssr_set(@tsl.RecurrentDenoiseNode::of(n).unwrap().radius, 3)
      n
    },
    internals=a4_rd_internals,
    glsl=true,
  )
  s.flow(
    "ssr_rd_ao",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.recurrent_denoise(
        a4_tex("in"),
        a4_ssr_persp(),
        depth=i.depth,
        normal=i.normal,
        raw=@nodes.texture(a4_tex("raw")),
      )
      @tsl.RecurrentDenoiseNode::of(n).unwrap().alpha_source = "ao"
      n
    },
    internals=a4_rd_internals,
  )
  s.flow(
    "ssr_rd_none_spatial",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.recurrent_denoise(
        @nodes.texture(a4_tex("in")),
        a4_ssr_persp(),
        depth=i.depth,
        raw=@nodes.texture(a4_tex("raw")),
        accumulate=false,
        mode="specular",
      )
      @tsl.RecurrentDenoiseNode::of(n).unwrap().alpha_source = "none"
      n
    },
    internals=a4_rd_internals,
  )
  s.flow(
    "ssr_rd_none_ortho",
    fn() {
      let i = a4_ssr_inputs()
      let n = @tsl.recurrent_denoise(
        @nodes.texture(a4_tex("in")),
        a4_ssr_ortho(),
        normal=i.normal,
        raw=@nodes.texture(a4_tex("raw")),
        metal_roughness=i.mr,
      )
      @tsl.RecurrentDenoiseNode::of(n).unwrap().alpha_source = "none"
      n
    },
    internals=a4_rd_internals,
  )
  s.flow(
    "ssr_rd_raw_node",
    fn() {
      let i = a4_ssr_inputs()
      @tsl.recurrent_denoise(
        @nodes.vec4_of([@nodes.uv(), 0, 1]),
        a4_ssr_persp(),
        depth=i.depth,
        normal=i.normal,
        raw=@nodes.texture(a4_tex("raw")).mul(2),
      )
    },
    internals=fn(n) {
      let p = @tsl.RecurrentDenoiseNode::of(n).unwrap()
      [
        ("denoise", p._material),
        (
          "rtt",
          @nodes.RTTNode::of(p.texture_node).unwrap()._quad_mesh.material(),
        ),
        (
          "rtt_raw",
          @nodes.RTTNode::of(p.raw_node.unwrap()).unwrap()._quad_mesh.material(),
        ),
      ]
    },
  )
  s.flow(
    "ssr_rd_of_ssr",
    fn() {
      let i = a4_ssr_inputs()
      let cam = a4_ssr_persp()
      let s = @tsl.ssr(
        i.color,
        i.depth,
        i.normal,
        stochastic=true,
        metalness_node=i.mr.r(),
        roughness_node=i.mr.g(),
        camera=cam,
      )
      @tsl.recurrent_denoise(
        s,
        cam,
        depth=i.depth,
        normal=i.normal,
        raw=s,
        mode="specular",
        metal_roughness=i.mr,
      )
    },
    internals=a4_rd_internals,
  )
  a4_run(s)
}
