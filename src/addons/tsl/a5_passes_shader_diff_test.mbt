// Group `passes` of the A5 shader scenarios (upstream: shader_diff/a5/passes.mjs): the
// pass-based display nodes BloomNode, SMAANode, SSAONode, FSR1Node and OutlineNode, with
// their internal materials.

///|
fn a5p_scene_tex() -> @nodes.Node {
  @nodes.texture(a5_tex("scene"))
}

///|
fn a5p_bloom_internals(node : @nodes.Node) -> Array[(String, @core.Material)] {
  let b = @tsl.BloomNode::of(node).unwrap()
  let out = [("highPass", b._high_pass_filter_material.unwrap())]
  for i, blur in b._separable_blur_materials {
    // as updateBefore's horizontal pass sets them
    @nodes.TextureNode::set_value(
      blur.color_texture,
      Some(
        if i == 0 {
          b._render_target_bright.texture()
        } else {
          b._render_targets_vertical[i - 1].texture()
        },
      ),
    )
    out.push(("blur\{i}", blur.material))
  }
  out.push(("composite", b._composite_material.unwrap()))
  out
}

///|
/// Installs a stub `Image` (an unloaded `HTMLImageElement`) when the runtime has none,
/// as passes.mjs does upstream.
extern "js" fn a5p_install_image_stub() -> Unit =
  #|() => {
  #|  if ( typeof globalThis.Image === 'undefined' ) {
  #|    globalThis.Image = class Image { constructor() { this.src = ''; this.onload = null; this.width = 0; this.height = 0; } };
  #|  }
  #|}

///|
fn a5p_smaa_internals(node : @nodes.Node) -> Array[(String, @core.Material)] {
  let n = @tsl.SMAANode::of(node).unwrap()
  [
    ("edges", n._material_edges),
    ("weights", n._material_weights),
    ("blend", n._material_blend),
  ]
}

///|
fn a5p_fsr1_internals(node : @nodes.Node) -> Array[(String, @core.Material)] {
  let n = @tsl.FSR1Node::of(node).unwrap()
  [("easu", n._easu_material.unwrap()), ("rcas", n._rcas_material.unwrap())]
}

///|
fn a5p_outline_internals(node : @nodes.Node) -> Array[(String, @core.Material)] {
  let n = @tsl.OutlineNode::of(node).unwrap()
  [
    ("depth", n._depth_material),
    ("depthSprite", n._depth_sprite_material),
    ("prepareMask", n._prepare_mask_material),
    ("prepareMaskSprite", n._prepare_mask_sprite_material),
    ("copy", n._material_copy),
    ("edgeDetection", n._edge_detection_material),
    ("separableBlur", n._separable_blur_material),
    ("separableBlur2", n._separable_blur_material2),
    ("composite", n._composite_material),
  ]
}

///|
fn a5p_ssao_internals(node : @nodes.Node) -> Array[(String, @core.Material)] {
  let n = @tsl.SSAONode::of(node).unwrap()
  [("ao", n._ao_material), ("blur", n._blur_material)]
}

///|
fn a5p_ssao() -> @nodes.Node {
  @tsl.ssao(
    @nodes.texture(a5_depth_tex("depth")),
    @nodes.texture(a5_tex("normal")),
    @core.PerspectiveCamera::new(),
  )
}

///|
extern "js" fn a5p_str(x : Double) -> String = "(x) => String(x)"

///|
fn a5p_rt(rt : @core.RenderTarget) -> String {
  "\{rt.width}x\{rt.height}"
}

///|
fn a5p_v2(node : @nodes.Node) -> String {
  match @nodes.InputNode::get_value(node) {
    Vector2(v) => a5p_str(v.x) + "," + a5p_str(v.y)
    _ => "?"
  }
}

///|
/// `setSize( 301, 157 )` of each node (after its setup): render target sizes and the
/// size uniforms.
fn a5p_set_sizes(renderer : @nodes.Renderer, glsl : Bool) -> String {
  let mesh = @core.Mesh::new(
    geometry=a5_geometry(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  let setup = fn(node : @nodes.Node) {
    let b = a5_builder(Object3D(mesh), renderer, glsl)
    b.camera = Some(@core.PerspectiveCamera::new())
    b.set_shader_stage(Some("fragment"))
    b.flow_stages_node(node) |> ignore
    node.set_size(301, 157)
  }
  let out = []
  let bloom = @tsl.bloom(a5p_scene_tex())
  setup(bloom)
  let b = @tsl.BloomNode::of(bloom).unwrap()
  out.push("bloom " + a5p_rt(b._render_target_bright))
  for i in 0..<5 {
    out.push(
      "  \{i} " +
      a5p_rt(b._render_targets_horizontal[i]) +
      " " +
      a5p_rt(b._render_targets_vertical[i]) +
      " " +
      a5p_v2(b._separable_blur_materials[i].inv_size),
    )
  }
  let b2 = @tsl.BloomNode::of(@tsl.bloom(a5p_scene_tex())).unwrap()
  b2.set_resolution_scale(0.3) |> ignore
  out.push("bloom scale " + a5p_str(b2.get_resolution_scale()))
  let smaa = @tsl.smaa(a5p_scene_tex())
  setup(smaa)
  let n = @tsl.SMAANode::of(smaa).unwrap()
  out.push(
    "smaa " +
    a5p_rt(n._render_target_edges) +
    " " +
    a5p_rt(n._render_target_weights) +
    " " +
    a5p_rt(n._render_target_blend) +
    " " +
    a5p_v2(n._inv_size),
  )
  let ssao = a5p_ssao()
  setup(ssao)
  let n = @tsl.SSAONode::of(ssao).unwrap()
  out.push(
    "ssao " +
    a5p_rt(n._ao_render_target) +
    " " +
    a5p_rt(n._blur_render_target) +
    " " +
    a5p_str(n.resolution.x) +
    "," +
    a5p_str(n.resolution.y),
  )
  let fsr1 = @tsl.fsr1(a5p_scene_tex())
  setup(fsr1)
  let n = @tsl.FSR1Node::of(fsr1).unwrap()
  out.push("fsr1 " + a5p_rt(n._easu_rt) + " " + a5p_rt(n._rcas_rt))
  for ratio in [2.0, 3.0] {
    let outline = @tsl.outline(
      @core.Scene::new(),
      @core.PerspectiveCamera::new(),
      down_sample_ratio=ratio,
    )
    setup(outline)
    let n = @tsl.OutlineNode::of(outline).unwrap()
    out.push(
      "outline " +
      a5p_rt(n._render_target_depth_buffer) +
      " " +
      a5p_rt(n._render_target_mask_buffer) +
      " " +
      a5p_rt(n._render_target_composite) +
      " " +
      a5p_rt(n._render_target_mask_down_sample_buffer) +
      " " +
      a5p_rt(n._render_target_edge_buffer1) +
      " " +
      a5p_rt(n._render_target_blur_buffer1) +
      " " +
      a5p_rt(n._render_target_edge_buffer2) +
      " " +
      a5p_rt(n._render_target_blur_buffer2),
    )
  }
  out.join("\n")
}

///|
test "a5 passes shader scenarios (compared with upstream by run.mjs)" {
  a5_run(
    fn() {
      a5p_install_image_stub()
      @tsl.load_display_bloom_node()
      @tsl.load_display_smaa_node()
      @tsl.load_display_ssao_node()
      @tsl.load_display_fsr1_node()
      @tsl.load_display_outline_node()
    },
    fn() {
      let s = A5Scenarios::new()
      s.flow(
        "bloom_default",
        fn() { @tsl.bloom(a5p_scene_tex()) },
        glsl=true,
        internals=a5p_bloom_internals,
      )
      s.flow(
        "bloom_numbers",
        fn() {
          @tsl.bloom(a5p_scene_tex(), strength=2.5, radius=0.4, threshold=0.2)
        },
        internals=a5p_bloom_internals,
      )
      s.flow(
        "bloom_nodes",
        fn() {
          @tsl.bloom(
            a5p_scene_tex(),
            strength=@nodes.uniform(1.5),
            radius=@nodes.float(0.3),
            threshold=@nodes.uniform(0.1),
          )
        },
        glsl=true,
        internals=a5p_bloom_internals,
      )
      s.flow(
        "bloom_high_pass_fn",
        fn() {
          let node = @tsl.bloom(a5p_scene_tex(), threshold=0.5)
          let b = @tsl.BloomNode::of(node).unwrap()
          b.high_pass_fn = @nodes.fn_(fn(inputs, _) {
            let input = inputs.named("input").unwrap()
            let threshold = inputs.named("threshold").unwrap()
            Some(input.mul(threshold))
          })
          b.smooth_width = @nodes.float(0.2)
          node
        },
        internals=a5p_bloom_internals,
      )
      s.flow(
        "smaa_default",
        fn() { @tsl.smaa(a5p_scene_tex()) },
        glsl=true,
        internals=a5p_smaa_internals,
      )
      s.flow(
        "smaa_uv",
        fn() {
          @tsl.smaa(
            @nodes.texture(a5_tex("scene"), uv_node=@nodes.uv().mul(0.5)),
          )
        },
        internals=a5p_smaa_internals,
      )
      s.flow(
        "smaa_rtt",
        fn() { @tsl.smaa(@nodes.vec4_of([0.2, 0.4, 0.6, 1.0])) },
        internals=a5p_smaa_internals,
      )
      s.flow(
        "ssao_default",
        fn() { a5p_ssao() },
        glsl=true,
        internals=a5p_ssao_internals,
      )
      s.flow(
        "ssao_fields",
        fn() {
          let node = a5p_ssao()
          let n = @tsl.SSAONode::of(node).unwrap()
          n.radius = @nodes.float(0.25)
          n.samples = @nodes.uniform(8)
          n.blur_sharpness = @nodes.float(4)
          n.intensity = @nodes.float(1.5)
          n.blur_enabled = false
          node
        },
        glsl=true,
        internals=a5p_ssao_internals,
      )
      s.flow(
        "fsr1_default",
        fn() { @tsl.fsr1(a5p_scene_tex()) },
        glsl=true,
        internals=a5p_fsr1_internals,
      )
      s.flow(
        "fsr1_denoise",
        fn() { @tsl.fsr1(a5p_scene_tex(), sharpness=1.0, denoise=true) },
        glsl=true,
        internals=a5p_fsr1_internals,
      )
      s.flow(
        "fsr1_uniform",
        fn() { @tsl.fsr1(a5p_scene_tex(), sharpness=@nodes.uniform(0.5)) },
        internals=a5p_fsr1_internals,
      )
      s.flow(
        "outline_default",
        fn() {
          @tsl.outline(@core.Scene::new(), @core.PerspectiveCamera::new())
        },
        glsl=true,
        internals=a5p_outline_internals,
      )
      s.flow(
        "outline_params",
        fn() {
          let scene = @core.Scene::new()
          let mesh = @core.Mesh::new(
            geometry=a5_geometry(),
            material=Single(@core.MeshBasicMaterial::new()),
          )
          scene.add(mesh) |> ignore
          @tsl.outline(
            scene,
            @core.OrthographicCamera::new(),
            selected_objects=[mesh],
            edge_thickness=@nodes.uniform(2),
            edge_glow=@nodes.uniform(1),
            down_sample_ratio=4.0,
          )
        },
        glsl=true,
        internals=a5p_outline_internals,
      )
      s.flow(
        "outline_numbers",
        fn() {
          @tsl.outline(
            @core.Scene::new(),
            @core.PerspectiveCamera::new(),
            edge_thickness=3,
            edge_glow=0.5,
          )
        },
        internals=a5p_outline_internals,
      )
      s.custom("set_sizes", a5p_set_sizes, glsl=true)
      s.flow("outline_edges", fn() {
        let o = @tsl.outline(@core.Scene::new(), @core.PerspectiveCamera::new())
        @tsl.OutlineNode::visible_edge(o).add(@tsl.OutlineNode::hidden_edge(o))
      })
      s
    },
  )
}
