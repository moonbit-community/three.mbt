// examples/jsm/tsl/display/TemporalReprojectNode.js

///|
const TEMPORAL_REPROJECT_VARIANCE_CLIP_LUMA_SCALE : Int32 = 10

///|
const TEMPORAL_REPROJECT_DEFAULT_MAX_VELOCITY_LENGTH : Double = 128.0

///|
const TEMPORAL_REPROJECT_VARIANCE_GAMMA_MIN : Double = 0.5

///|
const TEMPORAL_REPROJECT_VARIANCE_GAMMA_MAX : Double = 1.0

///|
/// The module's top-level `Fn`s that later code calls, and `_quadMesh` (the initializer
/// creates every top-level `Fn` and struct in upstream statement order).
priv struct TemporalReprojectModule {
  beauty_texel_from_screen : @nodes.Node
  collect_neighborhood : @nodes.Node
  apply_variance_clipping : @nodes.Node
  sample_history4_tap : @nodes.Node
  reprojection_stretch_confidence : @nodes.Node
  reproject_hit_point : @nodes.Node
  velocity_to_uv_offset : @nodes.Node
  quad_mesh : @nodes.QuadMesh
}

///|
let _temporal_reproject_node_size : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _temporal_reproject_node_renderer_state : Ref[@nodes.RendererState?] = Ref(
  None,
)

// YCoCg variance clipping

///|
fn temporal_reproject_rgb_to_y_co_cg(c : @nodes.Node) -> @nodes.Node {
  @nodes.vec3_of([
    @nodes.dot(c, @nodes.vec3_of([0.25, 0.5, 0.25])),
    @nodes.dot(c, @nodes.vec3_of([0.5, 0.0, -0.5])),
    @nodes.dot(c, @nodes.vec3_of([-0.25, 0.5, -0.25])),
  ])
}

///|
fn temporal_reproject_ycocg_to_rgb(c : @nodes.Node) -> @nodes.Node {
  @nodes.vec3_of([
    c.x().add(c.y()).sub(c.z()),
    c.x().add(c.z()),
    c.x().sub(c.y()).sub(c.z()),
  ])
}

///|
/// Inverse-luminance compression for HDR variance clipping (Karis-style).
fn temporal_reproject_dampen_for_variance_clip(
  rgb : @nodes.Node,
  flicker_suppression : @nodes.Node,
) -> @nodes.Node {
  let scale = @nodes.luminance(rgb)
    .mul(flicker_suppression)
    .mul(TEMPORAL_REPROJECT_VARIANCE_CLIP_LUMA_SCALE)
    .add(1)
  rgb.div(scale)
}

///|
/// Shared `sampleBilinearTap` inputs plus `reprojICoord` (`tapCtx`).
priv struct TemporalReprojectTapContext {
  history_texture : @nodes.Node
  previous_depth_node : @nodes.Node
  previous_normal_node : @nodes.Node
  resolution : @nodes.Node
  previous_projection_matrix_inverse : @nodes.Node
  previous_camera_world_matrix : @nodes.Node
  previous_camera_view_matrix : @nodes.Node
  reproj_i_coord : @nodes.Node
  world_position : @nodes.Node
  world_normal : @nodes.Node
}

///|
fn temporal_reproject_bilinear_history_tap(
  sample_bilinear_tap : @nodes.Node,
  ctx : TemporalReprojectTapContext,
  tap_offset : @nodes.Node,
  bilinear_weight : @nodes.Node,
) -> @nodes.Node {
  sample_bilinear_tap.call([
    ctx.history_texture,
    ctx.previous_depth_node,
    ctx.previous_normal_node,
    ctx.resolution,
    ctx.previous_projection_matrix_inverse,
    ctx.previous_camera_world_matrix,
    ctx.previous_camera_view_matrix,
    ctx.reproj_i_coord.add(tap_offset),
    bilinear_weight,
    ctx.world_position,
    ctx.world_normal,
  ])
}

///|
let display_temporal_reproject_node_module : AddonModule[
  TemporalReprojectModule,
] = AddonModule::new(fn() {
  // imports: SpecularHelpers.js
  load_utils_specular_helpers()
  // Reprojection helpers
  // Maps a resolve (screen) texel to the corresponding beauty-input texel when resolutions differ.
  let beauty_texel_from_screen = @nodes.fn_(
    fn(inputs, _) {
      let screen_texel = addon_arg(inputs, 0)
      let beauty_size = addon_arg(inputs, 1)
      let resolve_size = addon_arg(inputs, 2)
      Some(
        @nodes.ivec2(
          @nodes.floor(
            @nodes.vec2(screen_texel).mul(beauty_size).div(resolve_size),
          ),
        ),
      )
    },
    layout=addon_short_layout(
      [
        ("screenTexel", "ivec2"),
        ("beautySize", "vec2"),
        ("resolveSize", "vec2"),
      ],
      "ivec2",
    ),
  )
  // Projects a world-space position into previous-frame UV coordinates.
  let project_world_to_uv = @nodes.fn_(
    fn(inputs, _) {
      let world_pos = addon_arg(inputs, 0)
      let previous_view_matrix = addon_arg(inputs, 1)
      let previous_projection_matrix = addon_arg(inputs, 2)
      let result_uv = @nodes.vec2(-1).to_var()
      let view_space = previous_view_matrix.mul(
        @nodes.vec4_of([world_pos, 1.0]),
      )
      let clip_space = previous_projection_matrix.mul(view_space).to_var()
      let clip_w = clip_space.w().to_var()
      @nodes.if_(@nodes.abs(clip_w).greater_than(@nodes.float(1.0e-5)), fn() {
        let ndc = clip_space.xyz().div(clip_w)
        result_uv.assign(ndc.xy().mul(0.5).add(0.5))
        result_uv.y().assign(result_uv.y().one_minus())
      })
      |> ignore
      Some(result_uv)
    },
    layout=addon_short_layout(
      [
        ("worldPos", "vec3"),
        ("previousViewMatrix", "mat4"),
        ("previousProjectionMatrix", "mat4"),
      ],
      "vec2",
    ),
  )
  // Clips the history sample to the neighbourhood AABB by projecting it toward the box centre.
  // Reference: https://github.com/playdeadgames/temporal
  let clip_to_aabb = @nodes.fn_(
    fn(inputs, _) {
      let history = addon_arg(inputs, 0)
      let box_min = addon_arg(inputs, 1)
      let box_max = addon_arg(inputs, 2)
      let p_clip = box_max.add(box_min).mul(0.5)
      let e_clip = box_max.sub(box_min).mul(0.5).add(1.0e-7)
      let v_clip = history.sub(p_clip)
      let v_unit = v_clip.div(e_clip)
      let abs_unit = v_unit.abs()
      let max_unit = @nodes.max_of([abs_unit.x(), abs_unit.y(), abs_unit.z()])
      Some(
        max_unit
        .greater_than(1)
        .select(p_clip.add(v_clip.div(max_unit)), else_node=history),
      )
    },
    layout=addon_short_layout(
      [("history", "vec3"), ("boxMin", "vec3"), ("boxMax", "vec3")],
      "vec3",
    ),
  )
  let neighborhood_struct = @nodes.struct_([
    @nodes.StructMember::new("mean", "vec3"),
    @nodes.StructMember::new("stdColor", "vec3"),
    @nodes.StructMember::new("rayLength", "float"),
    @nodes.StructMember::new("envProbability", "float"),
    @nodes.StructMember::new("stdDevRayLength", "float"),
  ])
  // Single 3×3 neighbourhood pass over the beauty buffer.
  let collect_neighborhood = @nodes.fn_(fn(inputs, _) {
    let beauty_texture = addon_arg(inputs, 0)
    let beauty_texel = addon_arg(inputs, 1)
    let input_color = addon_arg(inputs, 2)
    let flicker_suppression = addon_arg(inputs, 3)
    let offsets = [
      (-1, -1),
      (-1, 1),
      (1, -1),
      (1, 1),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, 0),
    ]
    // Colour moments (YCoCg) — centre reuses the already-fetched inputColor.
    let center = temporal_reproject_rgb_to_y_co_cg(
      temporal_reproject_dampen_for_variance_clip(
        input_color.rgb(),
        flicker_suppression,
      ),
    )
    let moment1 = center.to_var()
    let moment2 = center.pow2().to_var()
    // Ray-length statistics (Welford) over screen-space hits only.
    let ray_length_sum = @nodes.float(0).to_var()
    let ray_length_count = @nodes.float(0).to_var()
    let mean_ray_length = @nodes.float(0).to_var()
    let m2_ray_length = @nodes.float(0).to_var()
    let accumulate_ray_length = fn(alpha : @nodes.Node) {
      @nodes.if_(alpha.less_than(ENV_RAY_LENGTH_THRESHOLD), fn() {
        ray_length_sum.add_assign(alpha)
        ray_length_count.add_assign(1)
        let delta = alpha.sub(mean_ray_length).to_var()
        mean_ray_length.add_assign(delta.div(ray_length_count))
        m2_ray_length.add_assign(delta.mul(alpha.sub(mean_ray_length)))
      })
      |> ignore
    }
    accumulate_ray_length(input_color.a())
    for offset in offsets {
      let (x, y) = offset
      let neighbor = @nodes.texture_load(
          beauty_texture,
          uv_node=beauty_texel.add(@nodes.ivec2_of([x, y])),
        )
        .max(0)
        .to_var()
      let c = temporal_reproject_rgb_to_y_co_cg(
        temporal_reproject_dampen_for_variance_clip(
          neighbor.rgb(),
          flicker_suppression,
        ),
      )
      moment1.add_assign(c)
      moment2.add_assign(c.pow2())
      accumulate_ray_length(neighbor.a())
    }
    let n = @nodes.float(offsets.length() + 1)
    let mean = moment1.div(n)
    let std_color = moment2.div(n).sub(mean.pow2()).max(0).sqrt()
    // Continuous environment probability: fraction of the 3×3 neighbourhood that missed in screen space
    // and fell back to env (0 = all hits, 1 = all env), for smooth reflection/environment transitions.
    let env_probability = ray_length_count.div(@nodes.float(9)).one_minus()
    let ray_length = ray_length_count
      .less_than(0.5)
      .select(
        @nodes.float(ENV_RAY_LENGTH),
        else_node=ray_length_sum.div(
          @nodes.max(ray_length_count, @nodes.float(1.0e-4)),
        ),
      )
    let std_dev_ray_length = @nodes.sqrt(
      m2_ray_length.div(@nodes.max(ray_length_count, @nodes.float(1.0))),
    ).max(1.0e-3)
    Some(
      neighborhood_struct.call([
        mean, std_color, ray_length, env_probability, std_dev_ray_length,
      ]),
    )
  })
  // Variance clipping in YCoCg space (Salvi, GDC 2016).
  let apply_variance_clipping = @nodes.fn_(fn(inputs, _) {
    let history_color = addon_arg(inputs, 0)
    let mean = addon_arg(inputs, 1)
    let std_color = addon_arg(inputs, 2)
    let gamma = addon_arg(inputs, 3)
    let flicker_suppression = addon_arg(inputs, 4)
    let stddev = std_color.mul(gamma)
    let box_min = mean.sub(stddev)
    let box_max = mean.add(stddev)
    let history_rgb = history_color.rgb().to_var()
    let history_scale = @nodes.luminance(history_rgb)
      .mul(flicker_suppression)
      .mul(TEMPORAL_REPROJECT_VARIANCE_CLIP_LUMA_SCALE)
      .add(1)
    let clipped = clip_to_aabb.call([
      temporal_reproject_rgb_to_y_co_cg(history_rgb.div(history_scale)),
      box_min,
      box_max,
    ])
    Some(temporal_reproject_ycocg_to_rgb(clipped).mul(history_scale))
  })
  // History sampling
  let bilinear_tap_struct = @nodes.struct_([
    @nodes.StructMember::new("color", "vec4"),
    @nodes.StructMember::new("weight", "float"),
    @nodes.StructMember::new("confidence", "float"),
  ])
  let history_result_struct = @nodes.struct_([
    @nodes.StructMember::new("color", "vec4"),
    @nodes.StructMember::new("tapConfidence", "float"),
    @nodes.StructMember::new("minConfidence", "float"),
  ])
  // Single bilinear history tap with plane-distance and normal confidence.
  let sample_bilinear_tap = @nodes.fn_(fn(inputs, _) {
    let history_texture = addon_arg(inputs, 0)
    let previous_depth_node = addon_arg(inputs, 1)
    let previous_normal_node = addon_arg(inputs, 2)
    let resolution = addon_arg(inputs, 3)
    let previous_projection_matrix_inverse = addon_arg(inputs, 4)
    let previous_camera_world_matrix = addon_arg(inputs, 5)
    let previous_camera_view_matrix = addon_arg(inputs, 6)
    let tap_coord = addon_arg(inputs, 7)
    let bilinear_weight = addon_arg(inputs, 8)
    let world_position = addon_arg(inputs, 9)
    let world_normal = addon_arg(inputs, 10)
    let color = @nodes.texture_load(history_texture, uv_node=tap_coord).max(0)
    let reproj_depth = @nodes.texture_load(
      previous_depth_node,
      uv_node=tap_coord,
    ).r()
    let reproj_view_pos = @nodes.get_view_position.call([
      @nodes.vec2(tap_coord).add(0.5).div(resolution),
      reproj_depth,
      previous_projection_matrix_inverse,
    ])
    let reproj_world_pos = previous_camera_world_matrix
      .mul(@nodes.vec4_of([reproj_view_pos, 1.0]))
      .xyz()
    let reproj_world_norm = @nodes.unpack_rgb_to_normal(
      @nodes.texture_load(previous_normal_node, uv_node=tap_coord).rgb(),
    ).transform_normal_by_inverse_view_matrix(previous_camera_view_matrix)
    let plane_diff = @nodes.abs(
      @nodes.dot(reproj_world_pos.sub(world_position), world_normal),
    ).to_var()
    plane_diff.div_assign(@nodes.abs(reproj_view_pos.z()))
    let normal_confidence = @nodes.smoothstep(
      0.95,
      0.999,
      reproj_world_norm.dot(world_normal),
    )
    let confidence = @nodes.smoothstep(0, 0.01, plane_diff)
      .one_minus()
      .mul(normal_confidence)
    let weight = bilinear_weight.mul(confidence)
    Some(bilinear_tap_struct.call([color.mul(weight), weight, confidence]))
  })
  // Geometrically-weighted 4-tap bilinear history sample.
  let sample_history4_tap = @nodes.fn_(fn(inputs, _) {
    let history_texture = addon_arg(inputs, 0)
    let previous_depth_node = addon_arg(inputs, 1)
    let previous_normal_node = addon_arg(inputs, 2)
    let resolution = addon_arg(inputs, 3)
    let previous_projection_matrix_inverse = addon_arg(inputs, 4)
    let previous_camera_world_matrix = addon_arg(inputs, 5)
    let previous_camera_view_matrix = addon_arg(inputs, 6)
    let reproj_uv = addon_arg(inputs, 7)
    let world_position = addon_arg(inputs, 8)
    let world_normal = addon_arg(inputs, 9)
    let input_color = addon_arg(inputs, 10)
    let reproj_pixel_coord = reproj_uv.mul(resolution).sub(0.5).to_var()
    let reproj_i_coord = @nodes.ivec2(@nodes.floor(reproj_pixel_coord))
    let f_coord = reproj_pixel_coord.fract()
    let fx = f_coord.x()
    let fy = f_coord.y()
    let f00 = @nodes.float(1).sub(fx).mul(@nodes.float(1).sub(fy))
    let f10 = fx.mul(@nodes.float(1).sub(fy))
    let f01 = @nodes.float(1).sub(fx).mul(fy)
    let f11 = fx.mul(fy)
    let tap_ctx = TemporalReprojectTapContext::{
      history_texture,
      previous_depth_node,
      previous_normal_node,
      resolution,
      previous_projection_matrix_inverse,
      previous_camera_world_matrix,
      previous_camera_view_matrix,
      reproj_i_coord,
      world_position,
      world_normal,
    }
    let tap00 = temporal_reproject_bilinear_history_tap(
      sample_bilinear_tap,
      tap_ctx,
      @nodes.ivec2_of([0, 0]),
      f00,
    )
    let tap10 = temporal_reproject_bilinear_history_tap(
      sample_bilinear_tap,
      tap_ctx,
      @nodes.ivec2_of([1, 0]),
      f10,
    )
    let tap01 = temporal_reproject_bilinear_history_tap(
      sample_bilinear_tap,
      tap_ctx,
      @nodes.ivec2_of([0, 1]),
      f01,
    )
    let tap11 = temporal_reproject_bilinear_history_tap(
      sample_bilinear_tap,
      tap_ctx,
      @nodes.ivec2_of([1, 1]),
      f11,
    )
    let color_sum = tap00
      .get("color")
      .add(tap10.get("color"))
      .add(tap01.get("color"))
      .add(tap11.get("color"))
    let weight_sum = tap00
      .get("weight")
      .add(tap10.get("weight"))
      .add(tap01.get("weight"))
      .add(tap11.get("weight"))
    let max_conf = @nodes.max(
      @nodes.max(tap00.get("confidence"), tap10.get("confidence")),
      @nodes.max(tap01.get("confidence"), tap11.get("confidence")),
    )
    let min_conf = @nodes.min(
      @nodes.min(tap00.get("confidence"), tap10.get("confidence")),
      @nodes.min(tap01.get("confidence"), tap11.get("confidence")),
    )
    Some(
      history_result_struct.call([
        @nodes.select(
          weight_sum.greater_than(0.01),
          color_sum.div(weight_sum),
          else_node=@nodes.vec4_of([input_color.rgb(), @nodes.float(1)]),
        ),
        max_conf,
        min_conf,
      ]),
    )
  })
  // Diffuse reprojection
  // Reprojection-stretch confidence — detects history magnification (surface stretching).
  let reprojection_stretch_confidence = @nodes.fn_(
    fn(inputs, _) {
      let history_uv = addon_arg(inputs, 0)
      let resolution = addon_arg(inputs, 1)
      // Jacobian columns in pixels: how the history sample position moves per screen pixel.
      let jx = @nodes.d_fdx(history_uv).mul(resolution).to_var()
      let jy = @nodes.d_fdy(history_uv).mul(resolution).to_var()
      // Singular values of the 2×2 J are sqrt( eigenvalues of JᵀJ ), with
      // trace( JᵀJ ) = ‖J‖²_F and det( JᵀJ ) = det( J )².
      let det = jx.x().mul(jy.y()).sub(jx.y().mul(jy.x()))
      let fro2 = @nodes.dot(jx, jx).add(@nodes.dot(jy, jy))
      let disc = fro2.mul(fro2).mul(0.25).sub(det.mul(det)).max(0).sqrt()
      let sig_min = fro2.mul(0.5).sub(disc).max(0).sqrt()
      Some(sig_min.saturate())
    },
    layout=addon_short_layout(
      [("historyUV", "vec2"), ("resolution", "vec2")],
      "float",
    ),
  )
  // Specular reprojection
  // Parallax-corrected hit-point reprojection into previous-frame UVs.
  let reproject_hit_point = @nodes.fn_(
    fn(inputs, _) {
      let ray_orig = addon_arg(inputs, 0)
      let ray_length = addon_arg(inputs, 1)
      let camera_world_position = addon_arg(inputs, 2)
      let previous_view_matrix = addon_arg(inputs, 3)
      let previous_projection_matrix = addon_arg(inputs, 4)
      let camera_ray = @nodes.normalize(ray_orig.sub(camera_world_position)).to_var()
      let parallax_hit_point = ray_orig.add(camera_ray.mul(ray_length))
      Some(
        project_world_to_uv.call([
          parallax_hit_point, previous_view_matrix, previous_projection_matrix,
        ]),
      )
    },
    layout=addon_short_layout(
      [
        ("rayOrig", "vec3"),
        ("rayLength", "float"),
        ("cameraWorldPosition", "vec3"),
        ("previousViewMatrix", "mat4"),
        ("previousProjectionMatrix", "mat4"),
      ],
      "vec2",
    ),
  )
  // Converts screen-space velocity (NDC derivative) to a UV reprojection offset.
  let velocity_to_uv_offset = @nodes.fn_(
    fn(inputs, _) {
      let velocity = addon_arg(inputs, 0)
      Some(velocity.mul(@nodes.vec2_of([0.5, -0.5])))
    },
    layout=addon_short_layout([("velocity", "vec2")], "vec2"),
  )
  let quad_mesh = @nodes.QuadMesh::new()
  {
    beauty_texel_from_screen,
    collect_neighborhood,
    apply_variance_clipping,
    sample_history4_tap,
    reprojection_stretch_confidence,
    reproject_hit_point,
    velocity_to_uv_offset,
    quad_mesh,
  }
})

///|
/// Evaluates TemporalReprojectNode.js (its module-level `Fn`s, structs and `_quadMesh`),
/// as `import` does.
pub fn load_display_temporal_reproject_node() -> Unit {
  display_temporal_reproject_node_module.get() |> ignore
}

///|
/// Current and previous-frame camera matrices for temporal reprojection passes
/// (`bindTemporalCameraUniforms( camera )`).
pub(all) struct TemporalReprojectCameraUniforms {
  world_matrix : @nodes.Node
  view_matrix : @nodes.Node
  projection_matrix : @nodes.Node
  projection_matrix_inverse : @nodes.Node
  world_position : @nodes.Node
  previous_world_matrix : @nodes.Node
  previous_view_matrix : @nodes.Node
  previous_projection_matrix : @nodes.Node
  previous_projection_matrix_inverse : @nodes.Node
}

///|
fn temporal_reproject_bind_camera_uniforms(
  camera : @core.Object3D,
) -> TemporalReprojectCameraUniforms {
  let world_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world),
  )
  let view_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world_inverse()),
  )
  let projection_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.projection_matrix()),
  )
  let projection_matrix_inverse = @nodes.uniform(
    @math.Matrix4::new().copy(camera.projection_matrix_inverse()),
  )
  let world_position = @nodes.uniform(
    @math.Vector3::new(0.0, 0.0, 0.0).copy(camera.position),
  )
  let previous_world_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world),
  )
  let previous_view_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world_inverse()),
  )
  let previous_projection_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.projection_matrix()),
  )
  let previous_projection_matrix_inverse = @nodes.uniform(
    @math.Matrix4::new().copy(camera.projection_matrix_inverse()),
  )
  {
    world_matrix,
    view_matrix,
    projection_matrix,
    projection_matrix_inverse,
    world_position,
    previous_world_matrix,
    previous_view_matrix,
    previous_projection_matrix,
    previous_projection_matrix_inverse,
  }
}

///|
/// `updateFromCamera( cam )`: the current matrices become the previous ones.
pub fn TemporalReprojectCameraUniforms::update_from_camera(
  self : TemporalReprojectCameraUniforms,
  cam : @core.Object3D,
) -> Unit {
  traa_uniform_matrix4(self.previous_world_matrix).copy(
    traa_uniform_matrix4(self.world_matrix),
  )
  |> ignore
  traa_uniform_matrix4(self.previous_view_matrix).copy(
    traa_uniform_matrix4(self.view_matrix),
  )
  |> ignore
  traa_uniform_matrix4(self.previous_projection_matrix).copy(
    traa_uniform_matrix4(self.projection_matrix),
  )
  |> ignore
  traa_uniform_matrix4(self.previous_projection_matrix_inverse).copy(
    traa_uniform_matrix4(self.projection_matrix_inverse),
  )
  |> ignore
  traa_uniform_matrix4(self.world_matrix).copy(cam.matrix_world) |> ignore
  traa_uniform_matrix4(self.view_matrix).copy(cam.matrix_world_inverse())
  |> ignore
  traa_uniform_matrix4(self.projection_matrix).copy(cam.projection_matrix())
  |> ignore
  traa_uniform_matrix4(self.projection_matrix_inverse).copy(
    cam.projection_matrix_inverse(),
  )
  |> ignore
  traa_uniform_vector3(self.world_position).copy(cam.position) |> ignore
}

///|
/// The source of `setHistoryTexture( source )`: a texture, or an object with
/// `getRenderTarget()` (e.g. a RecurrentDenoiseNode), whose texture is used.
pub(all) enum TemporalReprojectHistorySource {
  Texture(@core.Texture)
  RenderTargetSource(() -> @core.RenderTarget)
}

///|
/// Temporal reprojection pass for denoising screen-space effects (SSGI, SSR, etc.).
pub(all) struct TemporalReprojectNode {
  mut beauty_node : @nodes.Node
  mut depth_node : @nodes.Node
  mut normal_node : @nodes.Node
  mut velocity_node : @nodes.Node
  mut camera : @core.Object3D
  /// `"diffuse"` or `"specular"`.
  mut mode : String
  /// Whether the resolve output is copied into the internal history each frame.
  mut accumulate : Bool
  mut max_velocity_length : Double
  _resolution : @nodes.Node
  _camera_uniforms : TemporalReprojectCameraUniforms
  max_frames : @nodes.Node
  hit_point_reprojection : @nodes.Node
  clamp_intensity : @nodes.Node
  flicker_suppression : @nodes.Node
  _history_render_target : @core.RenderTarget
  _history_texture_node : @nodes.Node
  _resolve_render_target : @core.RenderTarget
  _resolve_material : @core.Material
  _seed_material : @core.Material
  _texture_node : @nodes.Node
  _original_projection_matrix : @math.Matrix4
  _placeholder_previous_depth_texture : @core.Texture
  _previous_depth_node : @nodes.Node
  mut _previous_normal_texture : @core.Texture
  _previous_normal_node : @nodes.Node
  mut _needs_post_processing_sync : Bool
  mut _external_history_texture : @core.Texture?
}

///|
pub impl @nodes.NodeClass for TemporalReprojectNode with fn class_name(_) {
  "TemporalReprojectNode"
}

///|
pub impl @nodes.NodeClass for TemporalReprojectNode with fn has_flag(_, flag) {
  flag == "isTemporalReprojectNode"
}

///|
pub impl @nodes.NodeClass for TemporalReprojectNode with fn children(
  self,
  _,
  out,
) {
  @nodes.push_child(out, "beautyNode", Some(self.beauty_node))
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "normalNode", Some(self.normal_node))
  @nodes.push_child(out, "velocityNode", Some(self.velocity_node))
  @nodes.push_child(out, "maxFrames", Some(self.max_frames))
  @nodes.push_child(
    out,
    "hitPointReprojection",
    Some(self.hit_point_reprojection),
  )
  @nodes.push_child(out, "clampIntensity", Some(self.clamp_intensity))
  @nodes.push_child(out, "flickerSuppression", Some(self.flicker_suppression))
}

///|
/// `getTextureNode()`: the result of the effect.
pub fn TemporalReprojectNode::get_texture_node(
  self : TemporalReprojectNode,
) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`.
pub fn TemporalReprojectNode::set_size(
  self : TemporalReprojectNode,
  width : Double,
  height : Double,
) -> Unit {
  self._history_render_target.set_size(width.to_int(), height.to_int())
  self._resolve_render_target.set_size(width.to_int(), height.to_int())
  traa_uniform_vector2(self._resolution).set(width, height) |> ignore
}

///|
/// `setViewOffset()`: hands the unjittered projection matrix to the velocity pass.
pub fn TemporalReprojectNode::set_view_offset(
  self : TemporalReprojectNode,
) -> Unit {
  self.camera.update_projection_matrix()
  self._original_projection_matrix.copy(self.camera.projection_matrix())
  |> ignore
  @nodes.VelocityNode::set_projection_matrix(
    @nodes.velocity,
    Some(self._original_projection_matrix),
  )
}

///|
/// `clearViewOffset()`.
pub fn TemporalReprojectNode::clear_view_offset(
  _self : TemporalReprojectNode,
) -> Unit {
  @nodes.VelocityNode::set_projection_matrix(@nodes.velocity, None)
}

///|
pub impl @nodes.NodeClass for TemporalReprojectNode with fn update_before(
  self,
  _,
  frame,
) {
  let quad_mesh = display_temporal_reproject_node_module.get().quad_mesh
  let renderer = frame.renderer.unwrap()
  self._camera_uniforms.update_from_camera(self.camera)
  let drawing_buffer_size = renderer.get_drawing_buffer_size(
    _temporal_reproject_node_size,
  )
  let width = drawing_buffer_size.x
  let height = drawing_buffer_size.y
  if self._needs_post_processing_sync == true {
    self.set_view_offset()
    self._needs_post_processing_sync = false
  }
  _temporal_reproject_node_renderer_state.val = Some(
    @nodes.reset_renderer_state(
      renderer,
      state?=_temporal_reproject_node_renderer_state.val,
    ),
  )
  let current_depth = @nodes.TextureNode::get_value(self.depth_node)
  let history_depth = self._history_render_target.depth_texture().unwrap()
  let depth_format_changed = history_depth.format != current_depth.format ||
    history_depth.type_ != current_depth.type_
  // The texture copy requires matching formats, e.g. float depth with reversed depth or depth/stencil.
  // Checked here since updateBefore() can run before setup() when driven by another node.
  if depth_format_changed == true {
    history_depth.format = current_depth.format
    history_depth.type_ = current_depth.type_
    history_depth.set_needs_update(true)
  }
  let needs_restart = depth_format_changed == true ||
    self._history_render_target.width.to_double() != width ||
    self._history_render_target.height.to_double() != height
  self.set_size(width, height)
  let mut history_swapped_for_restart = false
  if needs_restart == true {
    self._previous_normal_texture.dispose()
    self._previous_normal_texture = @nodes.TextureNode::get_value(
      self.normal_node,
    ).clone()
    @nodes.TextureNode::set_value(
      self._previous_normal_node,
      Some(self._previous_normal_texture),
    )
    // External history (e.g. denoise feedback) is stale at the old resolution — use
    // freshly seeded internal history for this frame instead.
    if self.accumulate == false && self._external_history_texture is Some(_) {
      @nodes.TextureNode::set_value(
        self._history_texture_node,
        Some(self._history_render_target.texture()),
      )
      history_swapped_for_restart = true
    }
    renderer.set_render_target(Some(self._history_render_target))
    quad_mesh.set_material(self._seed_material)
    quad_mesh.object.name = "TemporalReproject.seed"
    quad_mesh.render(renderer)
    renderer.set_render_target(None)
  }
  renderer.set_render_target(Some(self._resolve_render_target))
  quad_mesh.set_material(self._resolve_material)
  quad_mesh.object.name = "TemporalReproject"
  quad_mesh.render(renderer)
  renderer.set_render_target(None)
  if history_swapped_for_restart == true {
    self._sync_history_texture_binding()
  } else if self.accumulate == true {
    renderer.copy_texture_to_texture(
      self._resolve_render_target.texture(),
      self._history_render_target.texture(),
    )
  }
  let src_w = traa_image_width(current_depth)
  let src_h = traa_image_height(current_depth)
  if src_w > 0.0 && src_h > 0.0 {
    renderer.copy_texture_to_texture(current_depth, history_depth)
    renderer.copy_texture_to_texture(
      @nodes.TextureNode::get_value(self.normal_node),
      self._previous_normal_texture,
    )
    @nodes.TextureNode::set_value(
      self._previous_depth_node,
      Some(history_depth),
    )
  }
  @nodes.restore_renderer_state(
    renderer,
    _temporal_reproject_node_renderer_state.val.unwrap(),
  )
  None
}

///|
pub impl @nodes.NodeClass for TemporalReprojectNode with fn setup(
  self,
  node,
  builder,
) {
  // Ensures the pass providing the depth updates before this node.
  self.depth_node.build(builder) |> ignore
  let shared_context = @nodes.context(value=builder.get_shared_context())
  if traa_claim_view_offset(builder, node) {
    self._needs_post_processing_sync = true
    @nodes.on_before_render_pipeline(fn() { self.set_view_offset() }) |> ignore
    @nodes.on_after_render_pipeline(fn() { self.clear_view_offset() }) |> ignore
  }
  let resolve_material = @nodes.NodeMaterial::of(self._resolve_material).unwrap()
  resolve_material.context_node = Some(shared_context)
  resolve_material.fragment_node = Some(self._build_resolve())
  self._resolve_material.set_needs_update(true)
  self._build_seed(shared_context)
  Some(self._texture_node)
}

///|
/// `_buildSeed( sharedContext )`.
fn TemporalReprojectNode::_build_seed(
  self : TemporalReprojectNode,
  shared_context : @nodes.Node,
) -> Unit {
  let m = display_temporal_reproject_node_module.get()
  let seed = @nodes.fn_(fn(_, _) {
    let screen_texel = @nodes.ivec2(
      @nodes.floor(@nodes.screen_coordinate.xy().sub(0.5)),
    )
    let beauty_size = self.beauty_node.size()
    let beauty_texel = m.beauty_texel_from_screen.call([
      screen_texel,
      beauty_size,
      self._resolution,
    ])
    Some(@nodes.texture_load(self.beauty_node, uv_node=beauty_texel).max(0))
  })
  let seed_material = @nodes.NodeMaterial::of(self._seed_material).unwrap()
  seed_material.context_node = Some(shared_context)
  seed_material.fragment_node = Some(seed.call([]))
  self._seed_material.set_needs_update(true)
}

///|
/// `_buildResolve()`.
fn TemporalReprojectNode::_build_resolve(
  self : TemporalReprojectNode,
) -> @nodes.Node {
  let m = display_temporal_reproject_node_module.get()
  let is_specular = self.mode == "specular"
  let camera_uniforms = self._camera_uniforms
  let resolve = @nodes.fn_(fn(_, _) {
    let uv_node = @nodes.uv()
    let screen_texel = @nodes.ivec2(
      @nodes.floor(@nodes.screen_coordinate.xy().sub(0.5)),
    )
    let depth = @nodes.texture_load(self.depth_node, uv_node=screen_texel)
      .r()
      .to_var()
    @nodes.is_background_depth.call([depth]).discard()
    let beauty_size = self.beauty_node.size()
    let beauty_texel = m.beauty_texel_from_screen.call([
      screen_texel,
      beauty_size,
      self._resolution,
    ])
    let input_color = @nodes.texture_load(
        self.beauty_node,
        uv_node=beauty_texel,
      )
      .max(0)
      .to_var()
    let view_normal = @nodes.unpack_rgb_to_normal(
      @nodes.texture_load(self.normal_node, uv_node=screen_texel).rgb(),
    ).to_var()
    // Shared 3×3 beauty fetch: feeds both the variance-clip box and the SSR ray-length stats.
    let neighborhood = m.collect_neighborhood.call([
      self.beauty_node,
      beauty_texel,
      input_color,
      self.flicker_suppression,
    ])
    let world_normal = view_normal
      .transform_normal_by_inverse_view_matrix(camera_uniforms.view_matrix)
      .to_var()
    let view_position = @nodes.get_view_position
      .call([uv_node, depth, camera_uniforms.projection_matrix_inverse])
      .to_var()
    let world_position = camera_uniforms.world_matrix
      .mul(@nodes.vec4_of([view_position, 1.0]))
      .xyz()
      .to_var()
    let sample_history = fn(reproj_uv : @nodes.Node) {
      m.sample_history4_tap.call([
        self._history_texture_node,
        self._previous_depth_node,
        self._previous_normal_node,
        self._resolution,
        camera_uniforms.previous_projection_matrix_inverse,
        camera_uniforms.previous_world_matrix,
        camera_uniforms.previous_view_matrix,
        reproj_uv,
        world_position,
        world_normal,
        input_color.rgb(),
      ])
    }
    // Surface-velocity reprojection — the base history for both modes. `historyUV` is
    // reused below for the stretch guard, so it is computed once here.
    let velocity_off = m.velocity_to_uv_offset
      .call([@nodes.texture_load(self.velocity_node, uv_node=screen_texel).xy()])
      .to_var()
    let motion_factor = velocity_off
      .mul(self._resolution)
      .length()
      .div(@nodes.float(self.max_velocity_length))
      .saturate()
    let history_uv = uv_node.sub(velocity_off).to_var()
    let surf = sample_history(history_uv)
    let history_color = surf.get("color").to_var()
    let total_confidence = @nodes.float(1).to_var()
    let history_trust = @nodes.float(0).to_var()
    // Specular: blend parallax hit-point history on top of the surface result. Returns the resolved
    // color (rgb from the blend, alpha from the surface tap), its confidence, and the hit-vs-surface trust.
    let resolve_specular_history = fn() {
      let surf_valid = history_uv
        .x()
        .greater_than_equal(0)
        .and_(history_uv.x().less_than_equal(1))
        .and_(history_uv.y().greater_than_equal(0))
        .and_(history_uv.y().less_than_equal(1))
      let history_uv_hit = m.reproject_hit_point
        .call([
          world_position,
          neighborhood.get("rayLength"),
          camera_uniforms.world_position,
          camera_uniforms.previous_view_matrix,
          camera_uniforms.previous_projection_matrix,
        ])
        .to_var()
      let hit_valid = history_uv_hit
        .x()
        .greater_than_equal(0)
        .and_(history_uv_hit.x().less_than_equal(1))
        .and_(history_uv_hit.y().greater_than_equal(0))
        .and_(history_uv_hit.y().less_than_equal(1))
        .and_(self.hit_point_reprojection)
      let hit = sample_history(history_uv_hit)
      let hc_hit = hit.get("color").rgb().max(0)
      let hc_surf = surf.get("color").rgb().max(0)
      let conf_hit = hit_valid.select(
        hit.get("tapConfidence"),
        else_node=@nodes.float(0),
      )
      let conf_surf = surf_valid.select(
        surf.get("tapConfidence"),
        else_node=@nodes.float(0),
      )
      let min_conf_hit = hit.get("minConfidence")
      let reflection_edge_factor = neighborhood.get("stdDevRayLength")
      reflection_edge_factor.assign(
        reflection_edge_factor
        .mul(motion_factor.mul(100).min(1))
        .mul(3.5)
        .min(1)
        .one_minus(),
      )
      let curvature_factor = @nodes.fwidth(world_normal.xyz())
        .length()
        .mul(50)
        .clamp()
      let env_probability = neighborhood.get("envProbability")
      let w_hit_raw = min_conf_hit
        .mul(reflection_edge_factor)
        .mul(curvature_factor.one_minus())
        .mul(conf_hit)
        .to_const()
      let w_hit = w_hit_raw.mul(env_probability.pow2().one_minus())
      let w_surf = w_hit.one_minus().mul(conf_surf)
      let w_sum = @nodes.max(w_hit.add(w_surf), @nodes.float(@nodes.epsilon))
      let color = @nodes.vec4_of([
        hc_hit.mul(w_hit).add(hc_surf.mul(w_surf)).div(w_sum),
        surf.get("color").a(),
      ]).to_var()
      let confidence = conf_hit.mul(w_hit).add(conf_surf.mul(w_surf)).div(w_sum)
      // Near-black blend means neither tap was usable — fall back to the current frame.
      @nodes.if_(color.rgb().length().less_than(@nodes.epsilon), fn() {
        color.assign(@nodes.vec4_of([input_color.rgb(), 1]))
      })
      |> ignore
      (color, confidence, w_hit_raw) // without env probability
    }
    if is_specular {
      let (color, confidence, trust) = resolve_specular_history()
      history_color.assign(color)
      total_confidence.assign(confidence)
      history_trust.assign(trust)
    }
    let a = history_color.a().max(@nodes.epsilon)
    // Universal stretch guard: reduce confidence where a "small area" is projected over a "large area".
    let stretch_confidence = m.reprojection_stretch_confidence.call([
      history_uv,
      self._resolution,
    ])
    total_confidence.mul_assign(stretch_confidence.pow(2))
    let variance_gamma = @nodes.mix(
      @nodes.float(TEMPORAL_REPROJECT_VARIANCE_GAMMA_MIN),
      @nodes.float(TEMPORAL_REPROJECT_VARIANCE_GAMMA_MAX),
      motion_factor.one_minus().pow2(),
    )
    let clipped_rgb = m.apply_variance_clipping
      .call([
        history_color,
        neighborhood.get("mean"),
        neighborhood.get("stdColor"),
        variance_gamma,
        self.flicker_suppression,
      ])
      .to_var()
    let clamp_intensity = self.clamp_intensity
      .mul(@nodes.max(motion_factor.mul(10).min(1), 0.25))
      .mul(
        @nodes.float(1).add(
          stretch_confidence.one_minus().add(history_trust.one_minus()).clamp(),
        ),
      )
    let original_history_color = @nodes.vec3(history_color.rgb())
    history_color
    .rgb()
    .assign(@nodes.mix(history_color.rgb(), clipped_rgb, clamp_intensity))
    total_confidence.mul_assign(
      @nodes.exp(
        original_history_color
        .sub(clipped_rgb)
        .length()
        .mul(clamp_intensity)
        .mul(30)
        .negate(),
      ),
    )
    total_confidence.mul_assign(
      @nodes.mix(
        @nodes.float(1),
        history_trust.mul(0.05).add(0.95),
        motion_factor.mul(100).clamp(),
      ),
    )
    @nodes.if_(total_confidence.less_than(@nodes.epsilon), fn() {
      history_color.assign(@nodes.vec4_of([input_color.rgb(), 1]))
    })
    |> ignore
    let current_frame_count = @nodes.float(1)
      .div(a)
      .mul(total_confidence)
      .add(1)
      .min(self.max_frames)
      .to_var()
    if is_specular {
      // A black current sample means no reflection was found this frame (a miss, not dark).
      // Since no valid sample was found, decrement the frame count (as the next accumulating pass will increase it).
      @nodes.if_(input_color.rgb().length().less_than(@nodes.epsilon), fn() {
        current_frame_count.assign(current_frame_count.sub(1).max(1))
      })
      |> ignore
    }
    Some(
      @nodes.vec4_of([
        history_color.rgb(),
        @nodes.float(1).div(current_frame_count),
      ]),
    )
  })
  resolve.call([])
}

///|
/// `_syncHistoryTextureBinding()`.
fn TemporalReprojectNode::_sync_history_texture_binding(
  self : TemporalReprojectNode,
) -> Unit {
  match self._external_history_texture {
    Some(external) if self.accumulate != true =>
      @nodes.TextureNode::set_value(self._history_texture_node, Some(external))
    _ =>
      @nodes.TextureNode::set_value(
        self._history_texture_node,
        Some(self._history_render_target.texture()),
      )
  }
}

///|
/// `setHistoryTexture( source )`: an external history source (only used when
/// `accumulate` is `false`); `None` is `null`.
pub fn TemporalReprojectNode::set_history_texture(
  self : TemporalReprojectNode,
  source : TemporalReprojectHistorySource?,
) -> Unit {
  self._external_history_texture = match source {
    Some(RenderTargetSource(get_render_target)) =>
      Some(get_render_target().texture())
    Some(Texture(texture)) => Some(texture)
    None => None
  }
  self._sync_history_texture_binding()
}

///|
pub impl @nodes.NodeClass for TemporalReprojectNode with fn dispose(self, node) {
  node.dispose_base()
  self._previous_normal_texture.dispose()
  let history_depth = self._history_render_target.depth_texture()
  let previous_depth = @nodes.TextureNode::get_value(self._previous_depth_node)
  if !(history_depth is Some(d) && physical_equal(previous_depth, d)) {
    previous_depth.dispose()
  }
  if !(history_depth is Some(d) &&
    physical_equal(self._placeholder_previous_depth_texture, d)) {
    self._placeholder_previous_depth_texture.dispose()
  }
  self._history_render_target.dispose()
  self._resolve_render_target.dispose()
  self._resolve_material.dispose()
  self._seed_material.dispose()
}

///|
/// The constructor body (after `Node::alloc(node_type="vec4")`); the options are
/// upstream's (`mode`, `hitPointReprojection`, `accumulate`).
pub fn TemporalReprojectNode::construct(
  node : @nodes.Node,
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  normal_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
  mode~ : String = "diffuse",
  hit_point_reprojection? : Bool,
  accumulate~ : Bool = false,
) -> TemporalReprojectNode {
  let hit_point_reprojection = match hit_point_reprojection {
    Some(h) => h
    None => mode == "specular"
  }
  if mode != "specular" && mode != "diffuse" {
    abort("TemporalReprojectNode: `mode` must be `diffuse` or `specular`.")
  }
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let camera_uniforms = temporal_reproject_bind_camera_uniforms(camera)
  let max_frames = @nodes.uniform(32)
  let hit_point_reprojection = @nodes.uniform(
    hit_point_reprojection,
    type_="bool",
  )
  let clamp_intensity = @nodes.uniform(1)
  let flicker_suppression = @nodes.uniform(1)
  let history_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
    depth_texture=@core.DepthTexture::new(),
  )
  history_render_target.texture().name = "TemporalReprojectNode.history"
  let history_texture_node = @nodes.texture(history_render_target.texture())
  let resolve_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  resolve_render_target.texture().name = "TemporalReprojectNode.resolve"
  let resolve_material = @nodes.NodeMaterial::new()
  resolve_material.name = "TemporalReproject.resolve"
  let seed_material = @nodes.NodeMaterial::new()
  seed_material.name = "TemporalReproject.seed"
  let texture_node = @nodes.pass_texture(node, resolve_render_target.texture())
  let original_projection_matrix = @math.Matrix4::new()
  let placeholder_previous_depth_texture = @core.DepthTexture::new(
    width=1,
    height=1,
  )
  let previous_depth_node = @nodes.texture(placeholder_previous_depth_texture)
  let previous_normal_texture = @nodes.TextureNode::get_value(normal_node).clone()
  let previous_normal_node = @nodes.texture(previous_normal_texture)
  let p = TemporalReprojectNode::{
    beauty_node,
    depth_node,
    normal_node,
    velocity_node,
    camera,
    mode,
    accumulate,
    max_velocity_length: TEMPORAL_REPROJECT_DEFAULT_MAX_VELOCITY_LENGTH,
    _resolution: resolution,
    _camera_uniforms: camera_uniforms,
    max_frames,
    hit_point_reprojection,
    clamp_intensity,
    flicker_suppression,
    _history_render_target: history_render_target,
    _history_texture_node: history_texture_node,
    _resolve_render_target: resolve_render_target,
    _resolve_material: resolve_material,
    _seed_material: seed_material,
    _texture_node: texture_node,
    _original_projection_matrix: original_projection_matrix,
    _placeholder_previous_depth_texture: placeholder_previous_depth_texture,
    _previous_depth_node: previous_depth_node,
    _previous_normal_texture: previous_normal_texture,
    _previous_normal_node: previous_normal_node,
    _needs_post_processing_sync: false,
    _external_history_texture: None,
  }
  p._sync_history_texture_binding()
  p
}

///|
/// `new TemporalReprojectNode( beautyNode, depthNode, normalNode, velocityNode, camera,
/// options )`.
pub fn TemporalReprojectNode::new(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  normal_node : @nodes.Node,
  velocity_node : @nodes.Node,
  camera : @core.Object3D,
  mode~ : String = "diffuse",
  hit_point_reprojection? : Bool,
  accumulate~ : Bool = false,
) -> @nodes.Node {
  display_temporal_reproject_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(
    TemporalReprojectNode::construct(
      node,
      beauty_node,
      depth_node,
      normal_node,
      velocity_node,
      camera,
      mode~,
      hit_point_reprojection?,
      accumulate~,
    ),
  )
}

///|
pub fn TemporalReprojectNode::of(node : @nodes.Node) -> TemporalReprojectNode? {
  addon_class_of(node, "TemporalReprojectNode")
}

///|
/// `temporalReproject( beautyNode, depthNode, normalNode, velocityNode, camera, options )`.
pub fn temporal_reproject(
  beauty_node : @nodes.Node,
  depth_node : &@nodes.IntoTsl,
  normal_node : &@nodes.IntoTsl,
  velocity_node : &@nodes.IntoTsl,
  camera : @core.Object3D,
  mode~ : String = "diffuse",
  hit_point_reprojection? : Bool,
  accumulate~ : Bool = false,
) -> @nodes.Node {
  display_temporal_reproject_node_module.get() |> ignore
  TemporalReprojectNode::new(
    @nodes.convert_to_texture(beauty_node),
    addon_node_object(depth_node),
    addon_node_object(normal_node),
    addon_node_object(velocity_node),
    camera,
    mode~,
    hit_point_reprojection?,
    accumulate~,
  )
}
