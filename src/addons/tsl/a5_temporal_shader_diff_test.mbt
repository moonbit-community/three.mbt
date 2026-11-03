// Group `temporal` of the A5 shader scenarios (upstream: shader_diff/a5/temporal.mjs):
// tsl/display TRAANode, TAAUNode, TemporalReprojectNode, OITPassNode.

///|
extern "js" fn a5_temporal_nums(a : FixedArray[Double]) -> String = "(a) => Array.from(a).map(String).join(',')"

///|
fn a5_temporal_mat(m : @math.Matrix4) -> String {
  a5_temporal_nums(FixedArray::from_array(m.elements))
}

///|
fn a5_temporal_beauty() -> @nodes.Node {
  @nodes.texture(a5_tex("beauty"))
}

///|
fn a5_temporal_depth() -> @nodes.Node {
  @nodes.texture(a5_depth_tex("depth"))
}

///|
fn a5_temporal_vel() -> @nodes.Node {
  @nodes.texture(a5_tex("velocity"))
}

///|
fn a5_temporal_normal() -> @nodes.Node {
  @nodes.texture(a5_tex("normal"))
}

///|
fn a5_temporal_persp() -> @core.Object3D {
  @core.PerspectiveCamera::new(fov=50, aspect=2, near=0.1, far=100)
}

///|
fn a5_temporal_ortho() -> @core.Object3D {
  @core.OrthographicCamera::new(
    left=-2,
    right=2,
    top=1,
    bottom=-1,
    near=0.1,
    far=100,
  )
}

///|
/// A flow build of `node` in a fresh builder (as `flow` does); returns the code.
fn a5_temporal_flow_code(
  node : @nodes.Node,
  renderer : @nodes.Renderer,
  glsl : Bool,
) -> String {
  let b = a5_builder(
    Object3D(
      @core.Mesh::new(
        geometry=a5_geometry(),
        material=Single(@core.MeshBasicMaterial::new()),
      ),
    ),
    renderer,
    glsl,
  )
  b.camera = Some(@core.PerspectiveCamera::new())
  b.set_shader_stage(Some("fragment"))
  b.flow_stages_node(node).code
}

///|
/// The context a RenderPipeline gives its output node.
priv struct A5TemporalPipeline {
  state : @nodes.RenderPipelineState
  before : Array[() -> Unit]
  after : Array[() -> Unit]
}

///|
fn a5_temporal_pipeline_context(
  node : @nodes.Node,
) -> (A5TemporalPipeline, @nodes.Node) {
  let p = A5TemporalPipeline::{
    state: { view_offset_owner: None, },
    before: [],
    after: [],
  }
  let ctx = a5_temporal_pipeline_node_context(p)
  (
    p,
    @nodes.context(node=@nodes.fn_(fn(_, _) { Some(node) }).call([]), value=ctx),
  )
}

///|
fn a5_temporal_pipeline_node_context(
  p : A5TemporalPipeline,
) -> @nodes.NodeContext {
  @nodes.node_context([
    ("renderPipeline", Other(@core.JsValue::object())),
    ("renderPipelineState", Other(@core.JsValue::of(p.state))),
    ("onBeforePipelineCallbacks", Other(@core.JsValue::of(p.before))),
    ("onAfterPipelineCallbacks", Other(@core.JsValue::of(p.after))),
  ])
}

///|
fn a5_temporal_is_owner(p : A5TemporalPipeline, node : @nodes.Node) -> Bool {
  match p.state.view_offset_owner {
    Some(o) => physical_equal(o, @core.JsValue::of(node))
    None => false
  }
}

///|
fn a5_temporal_velocity_matrix(v : @nodes.Node) -> String {
  match @nodes.VelocityNode::of(v).unwrap().projection_matrix {
    Some(m) => a5_temporal_mat(m)
    None => "null"
  }
}

///|
fn a5_temporal_traa_internals(
  n : @nodes.Node,
) -> Array[(String, @core.Material)] {
  [("resolve", @tsl.TRAANode::of(n).unwrap()._resolve_material)]
}

///|
fn a5_temporal_taau_internals(
  n : @nodes.Node,
) -> Array[(String, @core.Material)] {
  let p = @tsl.TAAUNode::of(n).unwrap()
  [("resolve", p._resolve_material), ("seed", p._seed_material)]
}

///|
fn a5_temporal_tr_internals(n : @nodes.Node) -> Array[(String, @core.Material)] {
  let p = @tsl.TemporalReprojectNode::of(n).unwrap()
  [("resolve", p._resolve_material), ("seed", p._seed_material)]
}

///|
fn a5_temporal_oit_mrt(weight : Bool) -> (@nodes.Renderer, Bool) -> String {
  fn(renderer, glsl) {
    let n = @tsl.oit_pass(@core.Scene::new(), a5_temporal_persp())
    let p = @tsl.OITPassNode::of(n).unwrap()
    if weight {
      p.weight_node = Some(@nodes.uniform(2).mul(@nodes.output.a()))
    }
    let m = @nodes.MeshBasicNodeMaterial::new()
    m.transparent = true
    let nm = @nodes.NodeMaterial::of(m).unwrap()
    nm.color_node = Some(@nodes.vec3_of([0.2, 0.4, 0.6]))
    nm.opacity_node = Some(@nodes.float(0.5))
    renderer.set_render_target(Some(p._oit_render_target))
    renderer.set_mrt(Some(p._get_mrt_node())) |> ignore
    let text = a5_build_material(m, renderer, glsl)
    renderer.set_mrt(None) |> ignore
    renderer.set_render_target(None)
    let rt = p._oit_render_target
    let t = rt.textures
    let same_depth = match
      (rt.depth_texture(), p.pass.render_target.depth_texture()) {
      (Some(a), Some(b)) => physical_equal(a, b)
      _ => false
    }
    text +
    "\n" +
    [
      same_depth.to_string(),
      t.length().to_string(),
      t[0].name,
      t[0].type_.to_string(),
      t[1].name,
      t[1].format.to_string(),
      t[1].type_.to_string(),
    ].join(" ")
  }
}

///|
test "a5 temporal shader scenarios (compared with upstream by run.mjs)" {
  a5_run(
    fn() {
      @tsl.load_display_traa_node()
      @tsl.load_display_taau_node()
      @tsl.load_display_temporal_reproject_node()
      @tsl.load_display_oit_pass_node()
    },
    fn() {
      let s = A5Scenarios::new()
      // TRAANode
      s.flow(
        "traa",
        fn() {
          @tsl.traa(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            a5_temporal_persp(),
          )
        },
        glsl=true,
        internals=a5_temporal_traa_internals,
      )
      s.flow(
        "traa_ortho_options",
        fn() {
          let n = @tsl.traa(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            a5_temporal_ortho(),
          )
          let p = @tsl.TRAANode::of(n).unwrap()
          p.use_subpixel_correction = false
          p.depth_threshold = 0.002
          p.edge_depth_diff = 0.01
          p.max_velocity_length = 64
          n
        },
        glsl=true,
        internals=a5_temporal_traa_internals,
      )
      s.flow(
        "traa_pass",
        fn() {
          let p = @nodes.pass(@core.Scene::new(), a5_temporal_persp())
          @tsl.traa(
            p,
            p.get_texture_node(name="depth"),
            p.get_texture_node(name="velocity"),
            a5_temporal_persp(),
          )
        },
        internals=a5_temporal_traa_internals,
      )
      s.flow(
        "traa_rtt",
        fn() {
          @tsl.traa(
            @nodes.vec4_of([@nodes.uv(), 0, 1]),
            a5_temporal_depth(),
            a5_temporal_vel(),
            a5_temporal_persp(),
          )
        },
        internals=a5_temporal_traa_internals,
      )
      s.flow(
        "traa_class",
        fn() {
          @tsl.TRAANode::new(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            a5_temporal_persp(),
          )
        },
        internals=a5_temporal_traa_internals,
      )
      s.custom(
        "traa_jitter",
        fn(renderer, glsl) {
          let camera = a5_temporal_persp()
          let v = @nodes.VelocityNode::new()
          let n = @tsl.traa(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            camera,
          )
          let p = @tsl.TRAANode::of(n).unwrap()
          let (ctx, node) = a5_temporal_pipeline_context(
            @nodes.context(
              node=n,
              value=@nodes.node_context([("velocity", Node(v))]),
            ),
          )
          let code = a5_temporal_flow_code(node, renderer, glsl)
          let out = [
            code,
            "owner \{a5_temporal_is_owner(ctx, n)}",
            "callbacks \{ctx.before.length()} \{ctx.after.length()}",
          ]
          for _ in 0..<3 {
            for f in ctx.before {
              f()
            }
            out.push("jitter " + a5_temporal_mat(camera.projection_matrix()))
            out.push(
              "velocity " +
              a5_temporal_velocity_matrix(v) +
              " " +
              (@nodes.VelocityNode::of(@nodes.velocity).unwrap().projection_matrix
              is None).to_string(),
            )
            for f in ctx.after {
              f()
            }
            out.push(
              "cleared " +
              a5_temporal_mat(camera.projection_matrix()) +
              " " +
              a5_temporal_velocity_matrix(v) +
              " " +
              p._jitter_index.to_string(),
            )
          }
          // a second TRAA in the same pipeline does not take the view offset
          let n2 = @tsl.traa(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            camera,
          )
          a5_temporal_flow_code(
            @nodes.context(
              node=n2,
              value=a5_temporal_pipeline_node_context(ctx),
            ),
            renderer,
            glsl,
          )
          |> ignore
          out.push(
            "second \{a5_temporal_is_owner(ctx, n)} \{ctx.before.length()}",
          )
          // setSize and the halton offsets directly
          p.set_size(64, 32)
          let inv_size = match @nodes.InputNode::get_value(p._inv_size) {
            Vector2(v) => v
            _ => abort("invSize")
          }
          let previous_depth = p._previous_depth_render_target
            .depth_texture()
            .unwrap()
          out.push(
            "size \{p._history_render_target.width} \{p._resolve_render_target.height} " +
            a5_temporal_nums(FixedArray::from_array(inv_size.to_array())) +
            " \{previous_depth.image().width()} \{previous_depth.format}",
          )
          for i in 0..<33 {
            p.set_view_offset(64, 32)
            if i == 31 || i == 32 {
              out.push(
                "offset \{i} " + a5_temporal_mat(camera.projection_matrix()),
              )
            }
            p.clear_view_offset()
          }
          out.join("\n")
        },
        glsl=true,
      )
      // TAAUNode
      s.flow(
        "taau",
        fn() {
          @tsl.taau(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            a5_temporal_persp(),
          )
        },
        glsl=true,
        internals=a5_temporal_taau_internals,
      )
      s.flow(
        "taau_ortho_options",
        fn() {
          let n = @tsl.taau(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_vel(),
            a5_temporal_ortho(),
          )
          let p = @tsl.TAAUNode::of(n).unwrap()
          p.current_frame_weight = 0.1
          p.depth_threshold = 0.002
          p.edge_depth_diff = 0.01
          p.max_velocity_length = 64
          n
        },
        glsl=true,
        internals=a5_temporal_taau_internals,
      )
      s.flow(
        "taau_pass",
        fn() {
          let p = @nodes.pass(@core.Scene::new(), a5_temporal_persp())
          @tsl.taau(
            p,
            p.get_texture_node(name="depth"),
            p.get_texture_node(name="velocity"),
            a5_temporal_persp(),
          )
        },
        internals=a5_temporal_taau_internals,
      )
      s.custom("taau_jitter", fn(renderer, glsl) {
        let camera = a5_temporal_persp()
        let pass = @nodes.pass(@core.Scene::new(), camera)
        let n = @tsl.taau(pass, a5_temporal_depth(), a5_temporal_vel(), camera)
        let p = @tsl.TAAUNode::of(n).unwrap()
        let (ctx, node) = a5_temporal_pipeline_context(n)
        let code = a5_temporal_flow_code(node, renderer, glsl)
        let out = [
          code,
          "owner \{a5_temporal_is_owner(ctx, n)}",
          "callbacks \{ctx.before.length()} \{ctx.after.length()}",
        ]
        pass.set_size(40, 20)
        for _ in 0..<3 {
          for f in ctx.before {
            f()
          }
          let jitter = match @nodes.InputNode::get_value(p._jitter_offset) {
            Vector2(v) => v
            _ => abort("jitterOffset")
          }
          out.push(
            "jitter " +
            a5_temporal_mat(camera.projection_matrix()) +
            " " +
            a5_temporal_nums(FixedArray::from_array(jitter.to_array())),
          )
          out.push("velocity " + a5_temporal_velocity_matrix(@nodes.velocity))
          for f in ctx.after {
            f()
          }
          out.push(
            "cleared " +
            a5_temporal_mat(camera.projection_matrix()) +
            " " +
            a5_temporal_velocity_matrix(@nodes.velocity) +
            " " +
            p._jitter_index.to_string(),
          )
        }
        p.set_size(80, 40)
        out.push(
          "size \{p._history_render_target.width} \{p._history_render_target.height} \{p._resolve_render_target.width} \{p._previous_depth_render_target.depth_texture().unwrap().format}",
        )
        out.join("\n")
      })
      // TemporalReprojectNode
      s.flow(
        "temporal_reproject",
        fn() {
          @tsl.temporal_reproject(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_normal(),
            a5_temporal_vel(),
            a5_temporal_persp(),
          )
        },
        glsl=true,
        internals=a5_temporal_tr_internals,
      )
      s.flow(
        "temporal_reproject_specular",
        fn() {
          @tsl.temporal_reproject(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_normal(),
            a5_temporal_vel(),
            a5_temporal_persp(),
            mode="specular",
          )
        },
        glsl=true,
        internals=a5_temporal_tr_internals,
      )
      s.flow(
        "temporal_reproject_specular_no_hit",
        fn() {
          @tsl.temporal_reproject(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_normal(),
            a5_temporal_vel(),
            a5_temporal_ortho(),
            mode="specular",
            hit_point_reprojection=false,
          )
        },
        internals=a5_temporal_tr_internals,
      )
      s.flow(
        "temporal_reproject_accumulate",
        fn() {
          let n = @tsl.temporal_reproject(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_normal(),
            a5_temporal_vel(),
            a5_temporal_persp(),
            mode="diffuse",
            hit_point_reprojection=true,
            accumulate=true,
          )
          @tsl.TemporalReprojectNode::of(n).unwrap().max_velocity_length = 64
          n
        },
        internals=a5_temporal_tr_internals,
      )
      s.flow(
        "temporal_reproject_external_history",
        fn() {
          let n = @tsl.TemporalReprojectNode::new(
            a5_temporal_beauty(),
            a5_temporal_depth(),
            a5_temporal_normal(),
            a5_temporal_vel(),
            a5_temporal_persp(),
          )
          @tsl.TemporalReprojectNode::of(n)
          .unwrap()
          .set_history_texture(Some(Texture(a5_tex("external"))))
          n
        },
        internals=a5_temporal_tr_internals,
      )
      s.flow(
        "temporal_reproject_pass",
        fn() {
          let p = @nodes.pass(@core.Scene::new(), a5_temporal_persp())
          @tsl.temporal_reproject(
            p,
            p.get_texture_node(name="depth"),
            p.get_texture_node(name="normal"),
            p.get_texture_node(name="velocity"),
            a5_temporal_persp(),
            mode="specular",
          )
        },
        internals=a5_temporal_tr_internals,
      )
      s.custom("temporal_reproject_state", fn(renderer, glsl) {
        let camera = a5_temporal_persp()
        camera.position.set(1, 2, 3) |> ignore
        camera.update_matrix_world()
        let n = @tsl.temporal_reproject(
          a5_temporal_beauty(),
          a5_temporal_depth(),
          a5_temporal_normal(),
          a5_temporal_vel(),
          camera,
          accumulate=false,
        )
        let p = @tsl.TemporalReprojectNode::of(n).unwrap()
        let (ctx, node) = a5_temporal_pipeline_context(n)
        let code = a5_temporal_flow_code(node, renderer, glsl)
        let out = [
          code,
          "owner \{a5_temporal_is_owner(ctx, n)} \{p._needs_post_processing_sync}",
          "callbacks \{ctx.before.length()} \{ctx.after.length()}",
        ]
        for f in ctx.before {
          f()
        }
        out.push("velocity " + a5_temporal_velocity_matrix(@nodes.velocity))
        for f in ctx.after {
          f()
        }
        out.push("cleared " + a5_temporal_velocity_matrix(@nodes.velocity))
        camera.position.set(4, 5, 6) |> ignore
        camera.update_matrix_world()
        p._camera_uniforms.update_from_camera(camera)
        let u = p._camera_uniforms
        let mat = fn(n : @nodes.Node) {
          match @nodes.InputNode::get_value(n) {
            Matrix4(m) => a5_temporal_mat(m)
            _ => abort("matrix")
          }
        }
        let world_position = match
          @nodes.InputNode::get_value(u.world_position) {
          Vector3(v) => a5_temporal_nums(FixedArray::from_array(v.to_array()))
          _ => abort("worldPosition")
        }
        out.push(
          "uniforms " +
          mat(u.world_matrix) +
          " " +
          mat(u.previous_world_matrix) +
          " " +
          world_position +
          " " +
          mat(u.previous_view_matrix),
        )
        let history_name = fn() {
          @nodes.TextureNode::get_value(p._history_texture_node).name
        }
        let ext = a5_tex("external")
        p.set_history_texture(Some(Texture(ext)))
        out.push("history " + history_name())
        p.set_history_texture(
          Some(RenderTargetSource(fn() { p._resolve_render_target })),
        )
        out.push("history " + history_name())
        p.accumulate = true
        p.set_history_texture(Some(Texture(ext)))
        out.push("history " + history_name())
        p.accumulate = false
        p.set_history_texture(None)
        out.push("history " + history_name())
        p.set_size(48, 24)
        let resolution = match @nodes.InputNode::get_value(p._resolution) {
          Vector2(v) => a5_temporal_nums(FixedArray::from_array(v.to_array()))
          _ => abort("resolution")
        }
        out.push(
          "size \{p._history_render_target.width} \{p._resolve_render_target.height} " +
          resolution,
        )
        out.join("\n")
      })
      // OITPassNode
      s.flow(
        "oit",
        fn() { @tsl.oit_pass(@core.Scene::new(), a5_temporal_persp()) },
        glsl=true,
      )
      s.flow(
        "oit_class_options",
        fn() {
          @tsl.OITPassNode::new(@core.Scene::new(), a5_temporal_persp(), options={
            ..@nodes.PassNodeOptions::default(),
            samples: Some(4),
            type_: Some(@core.FloatType),
          })
        },
        glsl=true,
      )
      s.custom("oit_mrt", a5_temporal_oit_mrt(false), glsl=true)
      s.custom("oit_mrt_weight", a5_temporal_oit_mrt(true))
      s.custom(
        "oit_size",
        fn(renderer, glsl) {
          let n = @tsl.oit_pass(@core.Scene::new(), a5_temporal_persp())
          let p = @tsl.OITPassNode::of(n).unwrap()
          n.set_resolution_scale(0.5) |> ignore
          n.set_size(64, 32)
          let code = a5_temporal_flow_code(n, renderer, glsl)
          code +
          "\n" +
          [
            p.pass.render_target.width,
            p.pass.render_target.height,
            p._oit_render_target.width,
            p._oit_render_target.height,
            p.pass.render_target.samples,
            p._oit_render_target.samples,
          ]
          .map(fn(x) { x.to_string() })
          .join(" ")
        },
        glsl=true,
      )
      s
    },
  )
}
