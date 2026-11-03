// examples/jsm/tsl/display/RecurrentDenoiseNode.js

///|
const RECURRENT_DENOISE_KERNEL_SAMPLES : Int32 = 8

///|
const RECURRENT_DENOISE_NOISE_ROTATION_SEED : Int32 = 83

///|
const RECURRENT_DENOISE_WORLD_RADIUS_SCALE : Double = 0.1

///|
const RECURRENT_DENOISE_AO_EDGE_STOPPING_BIAS : Double = 0.05

///|
const RECURRENT_DENOISE_AGGRESSIVITY_RADIUS_MIN : Double = 0.001

///|
const RECURRENT_DENOISE_DIFFUSE_CHROMA_WEIGHT : Double = 2.0

///|
// Neighborhood luma coefficient-of-variation thresholds for gating the temporal
// inverse-luminance (firefly) suppression.
const RECURRENT_DENOISE_FLICKER_COV_GATE_MIN : Double = 0.1

///|
const RECURRENT_DENOISE_FLICKER_COV_GATE_MAX : Double = 2.0

///|
const RECURRENT_DENOISE_EXP_WEIGHT_SCALE : Double = 4.0

///|
/// `1.5 / 255`.
let recurrent_denoise_normal_encoding_error : Double = 1.5 / 255.0

///|
/// The module's top-level state: `_quadMesh`, `_size`, `_rendererState` and the
/// module-level `Fn`s, in statement order.
priv struct RecurrentDenoiseModule {
  quad_mesh : @nodes.QuadMesh
  size : @math.Vector2
  mut renderer_state : @nodes.RendererState?
  vogel_disk : @nodes.Node
  diffuse_color_distance : @nodes.Node
  temporal_weight : @nodes.Node
  get_temporal_variance_factor : @nodes.Node
  compute_frustum_size : @nodes.Node
  compute_hit_dist_factor : @nodes.Node
  map_ao : @nodes.Node
  get_specular_dominant_direction : @nodes.Node
  specular_lobe_tan_half_angle : @nodes.Node
  lobe_normal_falloff : @nodes.Node
  lobe_normal_weight : @nodes.Node
  plane_distance : @nodes.Node
  karis_temporal_blend : @nodes.Node
}

///|
let display_recurrent_denoise_node_module : AddonModule[RecurrentDenoiseModule] = AddonModule::new(fn() {
    // imports: RNoise.js (no module-level state), SpecularHelpers.js
    load_utils_specular_helpers()
    let quad_mesh = @nodes.QuadMesh::new()
    let size = @math.Vector2::new(0.0, 0.0)
    // Golden-angle Vogel disk offset.
    let vogel_disk = @nodes.fn_(
      fn(inputs, _) {
        let i = addon_arg(inputs, 0)
        let radius = addon_arg(inputs, 1)
        let sample_count = 8
        let theta = i.add(0.5).mul(2.399827721492203)
        let r = radius.mul(@nodes.sqrt(i.add(0.5).div(sample_count)))
        Some(@nodes.vec2_of([@nodes.cos(theta), @nodes.sin(theta)]).mul(r))
      },
      layout=addon_short_layout([("i", "float"), ("radius", "float")], "vec2"),
    )
    // Chromatic color-similarity distance between two linear base colors (albedo).
    let diffuse_color_distance = @nodes.fn_(
      fn(inputs, _) {
        let a = addon_arg(inputs, 0)
        let b = addon_arg(inputs, 1)
        let compress_luma = addon_arg(inputs, 2)
        let to_y_co_cg = fn(c : @nodes.Node) {
          @nodes.vec3_of([
            @nodes.dot(c, @nodes.vec3_of([0.25, 0.5, 0.25])),
            c.r().sub(c.b()),
            c.g().sub(c.r().add(c.b()).mul(0.5)),
          ])
        }
        let ya = to_y_co_cg(a)
        let yb = to_y_co_cg(b)
        // `compressLuma` (0/1) range-compresses the luma term with log(1+L)
        let compress = fn(l : @nodes.Node) {
          @nodes.mix(l, @nodes.log(l.add(1)), compress_luma)
        }
        let d_luma = @nodes.abs(compress(ya.x()).sub(compress(yb.x())))
        let d_chroma = @nodes.vec2_of([ya.y().sub(yb.y()), ya.z().sub(yb.z())]).length()
        Some(d_luma.add(d_chroma.mul(RECURRENT_DENOISE_DIFFUSE_CHROMA_WEIGHT)))
      },
      layout=addon_short_layout(
        [("a", "vec3"), ("b", "vec3"), ("compressLuma", "float")],
        "float",
      ),
    )
    let temporal_weight = @nodes.fn_(
      fn(inputs, _) {
        let x = addon_arg(inputs, 0)
        let strength = addon_arg(inputs, 1)
        Some(@nodes.float(1).div(x.pow(strength)))
      },
      layout=addon_short_layout(
        [("x", "float"), ("strength", "float")],
        "float",
      ),
    )
    // Temporal accumulation variance factor in `[0, 1]`.
    let get_temporal_variance_factor = @nodes.fn_(
      fn(inputs, _) {
        let frame_num = addon_arg(inputs, 0)
        let strength = addon_arg(inputs, 1)
        Some(temporal_weight.call([frame_num, strength]).max(0.05))
      },
      layout=addon_short_layout(
        [("frameNum", "float"), ("strength", "float")],
        "float",
      ),
    )
    // World-space frustum height at `viewZ` (REBLUR).
    let compute_frustum_size = @nodes.fn_(
      fn(inputs, _) {
        let view_z = addon_arg(inputs, 0)
        let tan_half_fov_y = addon_arg(inputs, 1)
        Some(@nodes.float(2).mul(view_z).mul(tan_half_fov_y))
      },
      layout=addon_short_layout(
        [("viewZ", "float"), ("tanHalfFovY", "float")],
        "float",
      ),
    )
    // Maps world-space SSR ray length to `[0, 1]` (REBLUR).
    let compute_hit_dist_factor = @nodes.fn_(
      fn(inputs, _) {
        let world_ray_length = addon_arg(inputs, 0)
        let view_z = addon_arg(inputs, 1)
        let tan_half_fov_y = addon_arg(inputs, 2)
        let frustum_size = compute_frustum_size.call([view_z, tan_half_fov_y])
        let factor = world_ray_length
          .div(frustum_size.max(@nodes.epsilon))
          .clamp(low=0, high=1)
        Some(factor)
      },
      layout=addon_short_layout(
        [
          ("worldRayLength", "float"),
          ("viewZ", "float"),
          ("tanHalfFovY", "float"),
        ],
        "float",
      ),
    )
    // Maps an AO factor for edge-stopping comparisons.
    let map_ao = @nodes.fn_(
      fn(inputs, _) { Some(addon_arg(inputs, 0).pow(0.1)) },
      layout=addon_short_layout([("aoVal", "float")], "float"),
    )
    // Specular dominant direction.
    let get_specular_dominant_direction = @nodes.fn_(
      fn(inputs, _) {
        let n = addon_arg(inputs, 0)
        let v = addon_arg(inputs, 1)
        let roughness = addon_arg(inputs, 2)
        Some(
          @nodes.normalize(
            @nodes.mix(n, @nodes.reflect(v.negate(), n), roughness.one_minus()),
          ),
        )
      },
      layout=addon_short_layout(
        [("N", "vec3"), ("V", "vec3"), ("roughness", "float")],
        "vec3",
      ),
    )
    // GGX inverse-CDF: half-angle tangent enclosing `percent` of the lobe volume.
    let specular_lobe_tan_half_angle = @nodes.fn_(
      fn(inputs, _) {
        let roughness = addon_arg(inputs, 0)
        let percent = addon_arg(inputs, 1)
        let alpha = roughness.mul(roughness)
        Some(
          alpha.mul(
            @nodes.sqrt(
              percent.div(@nodes.float(1).sub(percent).max(@nodes.epsilon)),
            ),
          ),
        )
      },
      layout=addon_short_layout(
        [("roughness", "float"), ("percent", "float")],
        "float",
      ),
    )
    // Loop-invariant part of the adaptive normal edge-stopping weight.
    let lobe_normal_falloff = @nodes.fn_(
      fn(inputs, _) {
        let roughness = addon_arg(inputs, 0)
        let aggressivity = addon_arg(inputs, 1)
        let inv_normal_phi = addon_arg(inputs, 2)
        let percent = @nodes.mix(
          inv_normal_phi.pow2(),
          @nodes.float(0),
          aggressivity.sqrt(),
        ).clamp(low=0.1, high=0.99)
        let tan_half_angle = specular_lobe_tan_half_angle.call([
          roughness, percent,
        ])
        let lobe_half_angle = @nodes.max(
          @nodes.atan(tan_half_angle),
          @nodes.float(recurrent_denoise_normal_encoding_error),
        )
        let inv_half_angle = @nodes.float(1).div(lobe_half_angle)
        Some(
          inv_half_angle
          .mul(inv_half_angle)
          .mul(2.0 * RECURRENT_DENOISE_EXP_WEIGHT_SCALE),
        )
      },
      layout=addon_short_layout(
        [
          ("roughness", "float"),
          ("aggressivity", "float"),
          ("invNormalPhi", "float"),
        ],
        "float",
      ),
    )
    // Adaptive lobe normal edge-stopping weight, in cosine space.
    let lobe_normal_weight = @nodes.fn_(
      fn(inputs, _) {
        let view_normal = addon_arg(inputs, 0)
        let n_normal_v = addon_arg(inputs, 1)
        let lobe_falloff = addon_arg(inputs, 2)
        let cos_a = @nodes.dot(view_normal, n_normal_v)
        Some(@nodes.exp(cos_a.sub(1).mul(lobe_falloff)))
      },
      layout=addon_short_layout(
        [("viewNormal", "vec3"), ("nNormalV", "vec3"), ("lobeFalloff", "float")],
        "float",
      ),
    )
    // View-space plane distance between two surface points.
    let plane_distance = @nodes.fn_(
      fn(inputs, _) {
        let position = addon_arg(inputs, 0)
        let n_position = addon_arg(inputs, 1)
        let normal = addon_arg(inputs, 2)
        Some(@nodes.abs(@nodes.dot(position.sub(n_position), normal)))
      },
      layout=addon_short_layout(
        [("position", "vec3"), ("nPosition", "vec3"), ("normal", "vec3")],
        "float",
      ),
    )
    // Inverse-luminance temporal blend with optional adaptive trust (Karis-style).
    let karis_temporal_blend = @nodes.fn_(fn(inputs, _) {
      let denoised_rgb = addon_arg(inputs, 0)
      let denoised_raw = addon_arg(inputs, 1)
      let a = addon_arg(inputs, 2)
      let flicker_suppression = addon_arg(inputs, 3)
      let adaptive_trust = addon_arg(inputs, 4)
      let nbhd_mean_luma = addon_arg(inputs, 5)
      let nbhd_stddev_luma = addon_arg(inputs, 6)
      let local_co_v = nbhd_stddev_luma.div(nbhd_mean_luma.max(0.0001))
      let trust_suppress = local_co_v
        .mul(adaptive_trust)
        .mul(a.one_minus())
        .clamp(low=0, high=0.9)
      let a_trust = a.mul(trust_suppress.one_minus())
      // In flicker-free neighborhoods, back off the inverse-luminance weighting.
      let noisy = @nodes.smoothstep(
        RECURRENT_DENOISE_FLICKER_COV_GATE_MIN,
        RECURRENT_DENOISE_FLICKER_COV_GATE_MAX,
        local_co_v,
      )
      let eff_flicker = flicker_suppression.mul(
        @nodes.mix(adaptive_trust.one_minus(), @nodes.float(1), noisy),
      )
      let w_hist = @nodes.float(1)
        .sub(a_trust)
        .div(@nodes.luminance(denoised_rgb).mul(eff_flicker).mul(10).add(1))
      let w_raw = a_trust.div(
        @nodes.luminance(denoised_raw).mul(eff_flicker).mul(10).add(1),
      )
      Some(
        denoised_rgb
        .mul(w_hist)
        .add(denoised_raw.mul(w_raw))
        .div(w_hist.add(w_raw).max(@nodes.epsilon)),
      )
    })
    {
      quad_mesh,
      size,
      renderer_state: None,
      vogel_disk,
      diffuse_color_distance,
      temporal_weight,
      get_temporal_variance_factor,
      compute_frustum_size,
      compute_hit_dist_factor,
      map_ao,
      get_specular_dominant_direction,
      specular_lobe_tan_half_angle,
      lobe_normal_falloff,
      lobe_normal_weight,
      plane_distance,
      karis_temporal_blend,
    }
  },
)

///|
/// Evaluates RecurrentDenoiseNode.js (its module-level `Fn`s), as `import` does.
pub fn load_display_recurrent_denoise_node() -> Unit {
  display_recurrent_denoise_node_module.get() |> ignore
}

///|
/// `toTextureNode( value )`: `null` stays `None`, a texture becomes `texture( value )`,
/// a node with `getTextureNode()` (a pass, SSR or denoise node) its texture node, other
/// nodes `convertToTexture( value )`.
fn recurrent_denoise_to_texture_node(value : @nodes.TslValue) -> @nodes.Node? {
  match value {
    Undefined | Null => None
    Texture(t) => Some(@nodes.texture(t))
    v => {
      let node = @nodes.node_object(v)
      let texture_node = match recurrent_denoise_get_texture_node(node) {
        Some(t) => t
        None => node
      }
      Some(@nodes.convert_to_texture(texture_node))
    }
  }
}

///|
/// `value.getTextureNode?.()` for the classes of this package and PassNode that have it.
fn recurrent_denoise_get_texture_node(node : @nodes.Node) -> @nodes.Node? {
  if node.has_flag("isPassNode") {
    return Some(node.get_texture_node())
  }
  match RecurrentDenoiseNode::of(node) {
    Some(p) => return Some(p._texture_node)
    None => ()
  }
  match SSRNode::of(node) {
    Some(p) => return Some(p.get_texture_node())
    None => ()
  }
  None
}

///|
/// Post processing node for denoising temporally-accumulated screen-space effects such
/// as SSGI (`mode = "diffuse"`) and SSR (`mode = "specular"`).
pub(all) struct RecurrentDenoiseNode {
  mut camera : @core.Object3D
  /// Denoising kernel type: `"diffuse"` or `"specular"`.
  mut mode : String
  /// Whether the spatially-denoised result is blended temporally.
  mut accumulate : Bool
  mut texture_node : @nodes.Node
  mut depth_node : @nodes.Node?
  mut normal_node : @nodes.Node?
  mut raw_node : @nodes.Node?
  mut roughness_metalness_node : @nodes.Node?
  mut diffuse_node : @nodes.Node?
  _noise_index : @nodes.Node
  luma_phi : @nodes.Node
  depth_phi : @nodes.Node
  normal_phi : @nodes.Node
  radius : @nodes.Node
  alpha_phi : @nodes.Node
  roughness_phi : @nodes.Node
  diffuse_phi : @nodes.Node
  adapt : @nodes.Node
  smooth_disocclusions : @nodes.Node
  strength : @nodes.Node
  max_frames : @nodes.Node
  /// Which channel of the raw texture drives alpha-based edge stopping:
  /// `"raylength"`, `"ao"` or `"none"`.
  mut alpha_source : String
  flicker_suppression : @nodes.Node
  adaptive_trust : @nodes.Node
  _resolution : @nodes.Node
  _fov_y : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _camera_projection_matrix : @nodes.Node
  _view_matrix : @nodes.Node
  _render_target : @core.RenderTarget
  _material : @core.Material
  mut _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for RecurrentDenoiseNode with fn class_name(_) {
  "RecurrentDenoiseNode"
}

///|
pub impl @nodes.NodeClass for RecurrentDenoiseNode with fn has_flag(_, flag) {
  flag == "isRecurrentDenoiseNode"
}

///|
pub impl @nodes.NodeClass for RecurrentDenoiseNode with fn children(
  self,
  _,
  out,
) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "depthNode", self.depth_node)
  @nodes.push_child(out, "normalNode", self.normal_node)
  @nodes.push_child(out, "rawNode", self.raw_node)
  @nodes.push_child(
    out,
    "roughnessMetalnessNode",
    self.roughness_metalness_node,
  )
  @nodes.push_child(out, "diffuseNode", self.diffuse_node)
  @nodes.push_child(out, "lumaPhi", Some(self.luma_phi))
  @nodes.push_child(out, "depthPhi", Some(self.depth_phi))
  @nodes.push_child(out, "normalPhi", Some(self.normal_phi))
  @nodes.push_child(out, "radius", Some(self.radius))
  @nodes.push_child(out, "alphaPhi", Some(self.alpha_phi))
  @nodes.push_child(out, "roughnessPhi", Some(self.roughness_phi))
  @nodes.push_child(out, "diffusePhi", Some(self.diffuse_phi))
  @nodes.push_child(out, "adapt", Some(self.adapt))
  @nodes.push_child(out, "smoothDisocclusions", Some(self.smooth_disocclusions))
  @nodes.push_child(out, "strength", Some(self.strength))
  @nodes.push_child(out, "maxFrames", Some(self.max_frames))
  @nodes.push_child(out, "flickerSuppression", Some(self.flicker_suppression))
  @nodes.push_child(out, "adaptiveTrust", Some(self.adaptive_trust))
}

///|
/// `setSize( width, height )`.
pub fn RecurrentDenoiseNode::set_size(
  self : RecurrentDenoiseNode,
  width : Double,
  height : Double,
) -> Unit {
  self._render_target.set_size(width.to_int(), height.to_int())
  a4_uniform_vector2(self._resolution).set(width, height) |> ignore
}

///|
/// `getTextureNode()`: the result of the effect.
pub fn RecurrentDenoiseNode::get_texture_node(
  self : RecurrentDenoiseNode,
) -> @nodes.Node {
  self._texture_node
}

///|
/// `getRenderTarget()`: the internal output render target (for feedback loops).
pub fn RecurrentDenoiseNode::get_render_target(
  self : RecurrentDenoiseNode,
) -> @core.RenderTarget {
  self._render_target
}

///|
/// `MathUtils.degToRad( camera.fov )`; `camera.fov` is `undefined` (NaN) for other
/// cameras.
fn recurrent_denoise_fov_rad(camera : @core.Object3D) -> Double {
  match camera.kind {
    Camera({ kind: PerspectiveCamera(p), .. }) => @math.deg_to_rad(p.fov)
    _ => @math.deg_to_rad(0.0 / 0.0)
  }
}

///|
pub impl @nodes.NodeClass for RecurrentDenoiseNode with fn update_before(
  self,
  _,
  frame,
) {
  let m = display_recurrent_denoise_node_module.get()
  let renderer = frame.renderer.unwrap()
  let drawing_buffer_size = renderer.get_drawing_buffer_size(m.size)
  let width = drawing_buffer_size.x
  let height = drawing_buffer_size.y
  let needs_restart = self._render_target.width.to_double() != width ||
    self._render_target.height.to_double() != height
  self.set_size(width, height)
  match @nodes.InputNode::get_value(self._camera_projection_matrix) {
    Matrix4(v) => v.copy(self.camera.projection_matrix()) |> ignore
    _ => ()
  }
  match @nodes.InputNode::get_value(self._camera_projection_matrix_inverse) {
    Matrix4(v) => v.copy(self.camera.projection_matrix_inverse()) |> ignore
    _ => ()
  }
  match @nodes.InputNode::get_value(self._view_matrix) {
    Matrix4(v) => v.copy(self.camera.matrix_world_inverse()) |> ignore
    _ => ()
  }
  if self.camera.is_perspective_camera() {
    a4_set_uniform_number(self._fov_y, recurrent_denoise_fov_rad(self.camera))
  }
  a4_set_uniform_number(self._noise_index, frame.frame_id.to_double())
  // Upstream passes referenced by a PassTextureNode input are otherwise never scheduled.
  if self.texture_node.has_flag("isPassTextureNode") {
    frame.update_before_node(
      @nodes.PassTextureNode::of(self.texture_node).unwrap().pass_node,
    )
  }
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  if needs_restart == true {
    renderer.set_render_target(Some(self._render_target))
    renderer.clear()
    renderer.set_render_target(None)
  }
  renderer.set_render_target(Some(self._render_target))
  m.quad_mesh.set_material(self._material)
  m.quad_mesh.object.name = "RecurrentDenoise"
  m.quad_mesh.render(renderer)
  renderer.set_render_target(None)
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for RecurrentDenoiseNode with fn setup(
  self,
  _,
  builder,
) {
  let m = display_recurrent_denoise_node_module.get()
  let sample_analytic_noise = bind_analytic_noise(
    self._resolution,
    seed=RECURRENT_DENOISE_NOISE_ROTATION_SEED,
  )
  let noise_rotation_matrix = @nodes.fn_(
    fn(inputs, _) {
      let r = addon_arg(inputs, 0)
      let angle = r.mul(2).mul(@nodes.pi)
      Some(
        @nodes.mat2_of([
          @nodes.cos(angle),
          @nodes.sin(angle).negate(),
          @nodes.sin(angle),
          @nodes.cos(angle),
        ]),
      )
    },
    layout=addon_short_layout([("r", "float")], "mat2"),
  )
  let sample_texture = fn(uv_coord : @nodes.Node) {
    @nodes.texture(self.texture_node, uv_node=uv_coord).max(0)
  }
  let sample_raw = fn(uv_coord : @nodes.Node) {
    match self.raw_node {
      Some(r) => r.sample(uv_coord).max(0)
      None => @nodes.vec3(0).max(0)
    }
  }
  let sample_depth = fn(uv_coord : @nodes.Node) {
    match self.depth_node {
      Some(d) => d.sample(uv_coord).x()
      None => @nodes.float(0.5)
    }
  }
  let sample_normal = fn(uv_coord : @nodes.Node) {
    @nodes.unpack_rgb_to_normal(
      match self.normal_node {
        Some(n) => n.sample(uv_coord).rgb()
        None => @nodes.vec3_of([0, 0, 1])
      },
    )
  }
  let sample_roughness_metalness = fn(uv_coord : @nodes.Node) {
    match self.roughness_metalness_node {
      Some(n) => n.sample(uv_coord).rg()
      None => @nodes.vec2_of([0, 1])
    }
  }
  let sample_diffuse = fn(uv_coord : @nodes.Node) {
    match self.diffuse_node {
      Some(n) => n.sample(uv_coord).rgb()
      None => @nodes.vec3(0)
    }
  }
  // Neighborhood luma moments for the adaptive-trust (firefly) gating.
  let get_neighborhood_stats = @nodes.fn_(fn(inputs, _) {
    let uv_coord = addon_arg(inputs, 0)
    let center_sample = addon_arg(inputs, 1)
    let rl_sum = @nodes.float(0).to_var()
    let rl_sum_w = @nodes.float(0).to_var()
    let mean_luma = @nodes.float(0).to_var()
    let m2_luma = @nodes.float(0).to_var()
    let luma_count = @nodes.float(0).to_var()
    let has_env_ray = @nodes.bool(false).to_var()
    // 4-tap cross (pre-sampled center + 4 axis neighbors).
    let accumulate = fn(dx : Double, dy : Double, sample : @nodes.Node?) {
      let neighbor = match sample {
        Some(s) => s
        None => {
          let raw : &@nodes.IntoTsl = match self.raw_node {
            Some(r) => (r : &@nodes.IntoTsl)
            None => (@nodes.TslValue::Null : &@nodes.IntoTsl)
          }
          @nodes.texture(
            raw,
            uv_node=uv_coord.add(@nodes.vec2_of([dx, dy]).div(self._resolution)),
          )
          .max(0)
          .to_const()
        }
      }
      if self.alpha_source == "raylength" {
        let sample_rl = neighbor.a().to_var()
        @nodes.if_(sample_rl.greater_than(ENV_RAY_LENGTH_THRESHOLD), fn() {
          sample_rl.assign(0.25)
          has_env_ray.assign(true)
        })
        |> ignore
        let w = @nodes.float(1).div(sample_rl.add(0.001))
        rl_sum.add_assign(sample_rl.mul(w))
        rl_sum_w.add_assign(w)
      }
      @nodes.if_(self.adaptive_trust.greater_than(0), fn() {
        let n_luma = @nodes.luminance(neighbor.rgb())
        luma_count.add_assign(1)
        let delta = n_luma.sub(mean_luma).to_const()
        mean_luma.add_assign(delta.div(luma_count))
        m2_luma.add_assign(delta.mul(n_luma.sub(mean_luma)))
      })
      |> ignore
    }
    accumulate(0, 0, Some(center_sample))
    accumulate(-1, 0, None)
    accumulate(1, 0, None)
    accumulate(0, -1, None)
    accumulate(0, 1, None)
    let avg_ray_length = if self.alpha_source == "raylength" {
      rl_sum.div(rl_sum_w)
    } else {
      @nodes.float(1)
    }
    let stddev_luma = @nodes.sqrt(m2_luma.div(luma_count.max(1)))
    Some(
      @nodes.vec4_of([
        avg_ray_length,
        mean_luma,
        stddev_luma,
        has_env_ray.to_float(),
      ]),
    )
  })
  let denoise_fn = @nodes.fn_(fn(inputs, _) {
    let uv_coord = addon_arg(inputs, 0)
    let result = @nodes.property("vec4")
    let depth = sample_depth(uv_coord).to_const()
    let run_denoise = fn() {
      let view_normal = sample_normal(uv_coord).to_const()
      let world_normal = view_normal
        .transform_normal_by_inverse_view_matrix(self._view_matrix)
        .to_const()
      let texel = sample_texture(uv_coord).max(0).to_const()
      let view_position = @nodes.get_view_position
        .call([uv_coord, depth, self._camera_projection_matrix_inverse])
        .to_const()
      let roughness_metalness = sample_roughness_metalness(uv_coord).to_const()
      let roughness = roughness_metalness.g()
      let metalness = roughness_metalness.r()
      let noise_texel = sample_analytic_noise.call([uv_coord, self._noise_index])
      let rotation_matrix = noise_rotation_matrix.call([noise_texel.r()])
      let frame_num = @nodes.float(1).div(texel.a())
      let variance_factor = m.get_temporal_variance_factor.call([
        frame_num,
        self.strength.one_minus(),
      ])
      let aggressivity = variance_factor.one_minus()
      let raw = sample_raw(uv_coord).to_const()
      let view_z = @nodes.abs(view_position.z())
      let rl = @nodes.float(1).to_var()
      let nbhd_mean_luma = @nodes.float(0).to_var()
      let nbhd_stddev_luma = @nodes.float(0).to_var()
      let has_env_ray = @nodes.bool(false).to_var()
      if self.alpha_source == "raylength" {
        let stats = get_neighborhood_stats.call([uv_coord, raw])
        rl.assign(stats.x())
        nbhd_mean_luma.assign(stats.y())
        nbhd_stddev_luma.assign(stats.z())
        has_env_ray.assign(stats.w().greater_than(0.5))
      } else {
        @nodes.if_(self.adaptive_trust.greater_than(0), fn() {
          let stats = get_neighborhood_stats.call([uv_coord, raw])
          nbhd_mean_luma.assign(stats.y())
          nbhd_stddev_luma.assign(stats.z())
        })
        |> ignore
      }
      let tan_half_fov_y = if self.alpha_source == "raylength" {
        Some(@nodes.tan(self._fov_y.mul(0.5)).to_const())
      } else {
        None
      }
      let hit_dist_factor = if self.alpha_source == "raylength" {
        m.compute_hit_dist_factor
        .call([rl, view_z, tan_half_fov_y.unwrap()])
        .to_const()
      } else {
        @nodes.float(1)
      }
      let denoised = texel.rgb().to_var()
      let total_weight = @nodes.float(1).to_var()
      let denoised_frame = frame_num.to_var()
      let total_frame_weight = @nodes.float(1).to_var()
      let denoised_raw = raw.rgb().to_var()
      let total_weight_raw = @nodes.float(1).to_var()
      @nodes.if_(raw.rgb().length().less_than(0.0001), fn() {
        denoised_raw.assign(@nodes.vec3(0))
        total_weight_raw.assign(0)
      })
      |> ignore
      let avg_ao = if self.alpha_source == "ao" {
        raw.a().to_const()
      } else {
        @nodes.float(1)
      }
      let mapped_avg_ao = if self.alpha_source == "ao" {
        m.map_ao.call([avg_ao])
      } else {
        @nodes.float(0)
      }
      let world_radius = self.radius
        .mul(RECURRENT_DENOISE_WORLD_RADIUS_SCALE)
        .to_var()
      if self.mode == "specular" {
        world_radius.mul_assign(rl.mul(view_position.z().abs()))
        world_radius.mul_assign(roughness.sqrt().max(0.01))
      } else {
        world_radius.mul_assign(avg_ao.pow(2).mul(view_position.z().abs()))
      }
      world_radius.mul_assign(
        @nodes.mix(1, RECURRENT_DENOISE_AGGRESSIVITY_RADIUS_MIN, aggressivity),
      )
      let t = @nodes.vec3(0).to_var()
      let b = @nodes.vec3(0).to_var()
      if self.mode == "specular" {
        let v = @nodes.normalize(view_position).negate()
        let d = m.get_specular_dominant_direction.call([
          view_normal, v, roughness,
        ])
        let r = @nodes.reflect(d.negate(), view_normal)
        let tv = @nodes.normalize(@nodes.cross(view_normal, r))
        let bv = @nodes.cross(r, tv)
        let view_angle = @nodes.abs(view_normal.z())
          .acos()
          .div(@nodes.float(ADDON_PI * 0.5))
          .clamp(low=0, high=1)
        let skew_factor = @nodes.mix(1.0, roughness, view_angle)
        t.assign(tv.mul(skew_factor))
        b.assign(bv)
      } else {
        let up = @nodes.vec3_of([0, 0, 1])
        let tv = @nodes.cross(up, view_normal).normalize().to_var()
        @nodes.if_(tv.length().less_than(@nodes.epsilon), fn() {
          tv.assign(
            @nodes.cross(@nodes.vec3_of([0, 1, 0]), view_normal).normalize(),
          )
        })
        |> ignore
        t.assign(tv)
        b.assign(@nodes.cross(view_normal, tv).normalize())
      }
      t.mul_assign(world_radius)
      b.mul_assign(world_radius)
      let center_diffuse = sample_diffuse(uv_coord).to_const()
      let radius_shrink = @nodes.float(1).to_var()
      // An accumulated tangent-space shift that skews taps toward high-weight directions.
      let polar_bias = @nodes.vec2(0).to_var()
      let depth_weight_scale = self.depth_phi
        .mul(500)
        .mul(view_normal.z().abs())
        .div(view_position.z().abs())
      // Lobe geometry depends only on per-pixel terms.
      let lobe_falloff = m.lobe_normal_falloff
        .call([roughness, aggressivity, self.normal_phi.one_minus()])
        .to_const()
      @nodes.loop_(
        [
          @nodes.loop_range(
            start=@nodes.int(0),
            end=@nodes.int(RECURRENT_DENOISE_KERNEL_SAMPLES),
            type_="int",
            condition="<",
            name="i",
          ),
        ],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let base_offset = m.vogel_disk.call([@nodes.float(i), 1]).to_var()
          let sample_dir = base_offset.normalize().to_const()
          // Blend the tap direction toward the polar bias.
          let skewed_dir = @nodes.mix(
            sample_dir,
            polar_bias.max(@nodes.epsilon).normalize(),
            self.adapt
            .mul(aggressivity)
            .mul(
              polar_bias
              .dot(polar_bias)
              .greater_than(0.001)
              .select(1, else_node=0),
            ),
          )
          let offset = rotation_matrix
            .mul(skewed_dir.mul(base_offset.length().mul(radius_shrink)))
            .to_var()
          // Exact per-sample view-space projection (both paths)
          let sample_view_pos = view_position.add(
            b.mul(offset.x()).add(t.mul(offset.y())),
          )
          let sample_uv = @nodes.get_screen_position
            .call([sample_view_pos, self._camera_projection_matrix])
            .to_var()
          sample_uv.assign(
            sample_uv.abs().one_minus().abs().one_minus().clamp(),
          )
          let neighbor_color = sample_texture(sample_uv).max(0).to_const()
          let raw_neighbor_color = sample_raw(sample_uv).max(0).to_var()
          let n_depth = sample_depth(sample_uv)
          let n_view_position = @nodes.get_view_position
            .call([sample_uv, n_depth, self._camera_projection_matrix_inverse])
            .to_const()
          let n_view_z = @nodes.abs(n_view_position.z()).to_const()
          let kernel_diff = @nodes.float(0).to_var()
          // Luma edge stopping
          kernel_diff.add_assign(
            @nodes.luminance(raw_neighbor_color.rgb())
            .sub(@nodes.luminance(raw.rgb()))
            .abs()
            .mul(self.luma_phi)
            .mul(10),
          )
          // Diffuse edge stopping
          if self.diffuse_node is Some(_) {
            kernel_diff.add_assign(
              m.diffuse_color_distance
              .call([center_diffuse, sample_diffuse(sample_uv), @nodes.float(0)])
              .mul(self.diffuse_phi)
              .mul(metalness),
            )
          }
          // AO edge stopping
          if self.alpha_source == "ao" {
            let neighbor_mapped_ao = m.map_ao.call([raw_neighbor_color.a()])
            let ao_w = mapped_avg_ao
              .div(
                mapped_avg_ao
                .add(neighbor_mapped_ao)
                .add(RECURRENT_DENOISE_AO_EDGE_STOPPING_BIAS),
              )
              .mul(self.alpha_phi)
              .mul(aggressivity)
            kernel_diff.add_assign(ao_w)
          } else if self.alpha_source == "raylength" {
            // Ray length edge stopping
            let neighbor_hit_dist_factor = m.compute_hit_dist_factor.call([
              raw_neighbor_color.a(),
              n_view_z,
              tan_half_fov_y.unwrap(),
            ])
            let hdf_diff = hit_dist_factor.sub(neighbor_hit_dist_factor).abs()
            let ray_length_factor = hdf_diff
              .mul(self.alpha_phi)
              .div(view_position.z().abs())
            kernel_diff.add_assign(
              raw_neighbor_color
              .a()
              .greater_than(ENV_RAY_LENGTH_THRESHOLD)
              .and_(has_env_ray)
              .select(1, else_node=ray_length_factor),
            )
          }
          // Roughness edge stopping
          if self.mode == "specular" {
            kernel_diff.add_assign(
              @nodes.abs(
                roughness.sub(sample_roughness_metalness(sample_uv).g()),
              ).mul(self.roughness_phi),
            )
          }
          let n_view_normal = sample_normal(sample_uv)
          let n_world_normal = n_view_normal.transform_normal_by_inverse_view_matrix(
            self._view_matrix,
          )
          let dist_to_plane = m.plane_distance.call([
            view_position, n_view_position, view_normal,
          ])
          // Geometric edge stopping (depth and normal)
          let depth_diff = dist_to_plane.mul(depth_weight_scale)
          let normal_w = m.lobe_normal_weight.call([
            world_normal, n_world_normal, lobe_falloff,
          ])
          // Sum every negative-exponent edge-stopping term
          let w = @nodes.exp(
              kernel_diff.mul(aggressivity).add(depth_diff).negate(),
            )
            .mul(normal_w)
            .to_var()
          // Feedback to shrink radius based on the weight
          radius_shrink.assign(@nodes.mix(radius_shrink, w, self.adapt))
          // Polar feedback
          polar_bias.assign(
            @nodes.mix(polar_bias, sample_dir.mul(w.sub(0.5)), 0.5),
          )
          // weigh by the inverse luminance for the first 5 frames
          w.mul_assign(
            @nodes.mix(
              @nodes.float(1).div(
                @nodes.luminance(raw_neighbor_color.rgb()).pow(2).add(0.01),
              ),
              1,
              frame_num.div(5).min(1),
            ),
          )
          denoised_raw.add_assign(raw_neighbor_color.rgb().mul(w))
          total_weight_raw.add_assign(w)
          denoised.add_assign(neighbor_color.rgb().mul(w))
          total_weight.add_assign(w)
          // Denoising the alpha (accumulation speed)
          @nodes.if_(self.smooth_disocclusions, fn() {
            let neighbor_a_weight = neighbor_color
              .a()
              .greater_than(texel.a())
              .select(w.mul(0.33), else_node=0)
            denoised_frame.add_assign(
              @nodes.float(1).div(neighbor_color.a()).mul(neighbor_a_weight),
            )
            total_frame_weight.add_assign(neighbor_a_weight)
          })
          |> ignore
        },
      )
      denoised.div_assign(total_weight.max(@nodes.epsilon))
      denoised.assign(denoised.max(@nodes.epsilon))
      denoised_raw.div_assign(total_weight_raw.max(@nodes.epsilon))
      if self.accumulate {
        let computed_frame = denoised_frame.div(
          total_frame_weight.max(@nodes.epsilon),
        )
        let a = @nodes.float(1)
          .div(computed_frame.max(@nodes.epsilon))
          .to_const()
        if self.raw_node is Some(_) {
          let blended = m.karis_temporal_blend.call([
            denoised,
            denoised_raw,
            a,
            self.flicker_suppression,
            self.adaptive_trust,
            nbhd_mean_luma,
            nbhd_stddev_luma,
          ])
          result.assign(@nodes.vec4_of([blended, a]))
        } else {
          let final_denoised = @nodes.mix(denoised, denoised_raw, a)
          result.assign(@nodes.vec4_of([final_denoised, a]))
        }
      } else {
        result.assign(@nodes.vec4_of([denoised, texel.a()]))
      }
    }
    @nodes.if_(@nodes.is_background_depth.call([depth]), fn() {
      @nodes.discard()
    }).else_(run_denoise)
    Some(result)
  })
  let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(denoise_fn.call([@nodes.uv()]))
  self._material.set_needs_update(true)
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for RecurrentDenoiseNode with fn dispose(self, node) {
  node.dispose_base()
  self._render_target.dispose()
  self._material.dispose()
}

///|
/// `new RecurrentDenoiseNode( inputTexture, camera, options )`; the options are
/// upstream's (`depth`, `normal`, `metalRoughness`, `diffuse`, `raw`, `mode`,
/// `accumulate`).
pub fn RecurrentDenoiseNode::new(
  input_texture : @nodes.Node,
  camera : @core.Object3D,
  depth? : &@nodes.IntoTsl,
  normal? : &@nodes.IntoTsl,
  metal_roughness? : &@nodes.IntoTsl,
  diffuse? : &@nodes.IntoTsl,
  raw? : &@nodes.IntoTsl,
  mode~ : String = "diffuse",
  accumulate~ : Bool = true,
) -> @nodes.Node {
  load_display_recurrent_denoise_node()
  let node = @nodes.Node::alloc(node_type="vec4")
  let object_or_none = fn(v : &@nodes.IntoTsl?) -> @nodes.Node? {
    match v {
      Some(v) if !v.to_tsl().is_nullish() =>
        Some(@nodes.node_object(v.to_tsl()))
      _ => None
    }
  }
  let depth_node = object_or_none(depth)
  let normal_node = object_or_none(normal)
  let raw_node = match raw {
    Some(r) => recurrent_denoise_to_texture_node(r.to_tsl())
    None => None
  }
  let roughness_metalness_node = object_or_none(metal_roughness)
  let diffuse_node = object_or_none(diffuse)
  let _noise_index = @nodes.uniform(0)
  let luma_phi = @nodes.uniform(5)
  let depth_phi = @nodes.uniform(5)
  let normal_phi = @nodes.uniform(5)
  let radius = @nodes.uniform(5)
  let alpha_phi = @nodes.uniform(1)
  let roughness_phi = @nodes.uniform(100)
  let diffuse_phi = @nodes.uniform(100)
  let adapt = @nodes.uniform(0.5)
  let smooth_disocclusions = @nodes.uniform(true, type_="bool")
  let strength = @nodes.uniform(0.25)
  let max_frames = @nodes.uniform(32)
  let flicker_suppression = @nodes.uniform(1)
  let adaptive_trust = @nodes.uniform(0)
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let _resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let _fov_y = @nodes.uniform(recurrent_denoise_fov_rad(camera))
  let _camera_projection_matrix_inverse = @nodes.uniform(
    @math.Matrix4::new().copy(camera.projection_matrix_inverse()),
  )
  let _camera_projection_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.projection_matrix()),
  )
  let _view_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world_inverse()),
  )
  let _render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _render_target.texture().name = "RecurrentDenoiseNode.output"
  let _material = @nodes.NodeMaterial::new()
  _material.name = "RecurrentDenoise"
  let _texture_node = @nodes.pass_texture(node, _render_target.texture())
  node.set_class(RecurrentDenoiseNode::{
    camera,
    mode,
    accumulate,
    texture_node: input_texture,
    depth_node,
    normal_node,
    raw_node,
    roughness_metalness_node,
    diffuse_node,
    _noise_index,
    luma_phi,
    depth_phi,
    normal_phi,
    radius,
    alpha_phi,
    roughness_phi,
    diffuse_phi,
    adapt,
    smooth_disocclusions,
    strength,
    max_frames,
    alpha_source: "raylength",
    flicker_suppression,
    adaptive_trust,
    _resolution,
    _fov_y,
    _camera_projection_matrix_inverse,
    _camera_projection_matrix,
    _view_matrix,
    _render_target,
    _material,
    _texture_node,
  })
}

///|
pub fn RecurrentDenoiseNode::of(node : @nodes.Node) -> RecurrentDenoiseNode? {
  addon_class_of(node, "RecurrentDenoiseNode")
}

///|
/// `recurrentDenoise( inputTexture, camera, options )`: `inputTexture` is a texture or a
/// node (a pass, SSR or denoise node gives its texture node).
pub fn recurrent_denoise(
  input_texture : &@nodes.IntoTsl,
  camera : @core.Object3D,
  depth? : &@nodes.IntoTsl,
  normal? : &@nodes.IntoTsl,
  metal_roughness? : &@nodes.IntoTsl,
  diffuse? : &@nodes.IntoTsl,
  raw? : &@nodes.IntoTsl,
  mode~ : String = "diffuse",
  accumulate~ : Bool = true,
) -> @nodes.Node {
  load_display_recurrent_denoise_node()
  RecurrentDenoiseNode::new(
    recurrent_denoise_to_texture_node(input_texture.to_tsl()).unwrap(),
    camera,
    depth?,
    normal?,
    metal_roughness?,
    diffuse?,
    raw?,
    mode~,
    accumulate~,
  )
}
