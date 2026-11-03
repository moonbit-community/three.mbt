// examples/jsm/tsl/display/SSRNode.js

///|
/// Maximum ray-march step count; `quality` (0..1) scales it to a fixed per-ray count.
const SSR_NODE_MAX_STEPS : Int32 = 64

///|
/// The module's top-level state: `_quadMesh`, `_size`, `_rendererState`.
priv struct SSRNodeModule {
  quad_mesh : @nodes.QuadMesh
  size : @math.Vector2
  mut renderer_state : @nodes.RendererState?
}

///|
let display_ssr_node_module : AddonModule[SSRNodeModule] = AddonModule::new(fn() {
  // imports: RNoise.js (no module-level state), SpecularHelpers.js, boxBlur.js,
  // ImportanceSampledEnvironment.js
  load_utils_specular_helpers()
  load_display_box_blur()
  load_display_importance_sampled_environment()
  {
    quad_mesh: @nodes.QuadMesh::new(),
    size: @math.Vector2::new(0.0, 0.0),
    renderer_state: None,
  }
})

///|
/// Evaluates SSRNode.js, as `import` does.
pub fn load_display_ssr_node() -> Unit {
  display_ssr_node_module.get() |> ignore
}

///|
extern "js" fn ssr_node_math_round(x : Double) -> Double = "Math.round"

///|
/// Post processing node for computing screen space reflections (SSR).
pub(all) struct SSRNode {
  /// Stochastic GGX rays (second-generation SSR) instead of a mirror ray + blur.
  stochastic : Bool
  /// Whether env-luminance CDF tables and MIS are used for environment misses.
  env_importance_sampling : Bool
  mut color_node : @nodes.Node
  mut diffuse_node : @nodes.Node?
  mut depth_node : @nodes.Node
  mut normal_node : @nodes.Node
  mut metalness_node : @nodes.Node?
  mut specular_node : @nodes.Node?
  mut specular_f90_node : @nodes.Node?
  mut roughness_node : @nodes.Node?
  mut _reflect_non_metals : Bool
  /// The resolution scale, in `[0,1]`.
  mut resolution_scale : Double
  max_distance : @nodes.Node
  thickness : @nodes.Node
  intensity : @nodes.Node
  screen_edge_fade : @nodes.Node
  mut _screen_edge_fade_black : Bool
  max_luminance : @nodes.Node
  quality : @nodes.Node
  mirror_bias : @nodes.Node
  mut _blur_quality : Int32
  mut _binary_refine : Bool
  mut _step_exponent : Double
  mut environment_node : @core.Texture?
  mut history_texture : @core.Texture?
  mut velocity_texture : @nodes.Node?
  camera : @core.Object3D
  _blur_spread : @nodes.Node
  _camera_projection_matrix : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _camera_world_matrix : @nodes.Node
  _camera_world_position : @nodes.Node
  _camera_view_matrix : @nodes.Node
  _camera_view_matrix_inverse : @nodes.Node
  _resolution : @nodes.Node
  _noise_index : @nodes.Node
  mut _importance_environment : ImportanceSampledEnvironment?
  environment_intensity : @nodes.Node
  _ssr_render_target : @core.RenderTarget
  _blur_render_target : @core.RenderTarget
  _ssr_material : @core.Material
  mut _ssr_fn : @nodes.Node?
  mut _shared_context : @nodes.NodeContext?
  _blur_material : @core.Material
  _copy_material : @core.Material
  mut _texture_node : @nodes.Node
  mut _blurred_texture_node : @nodes.Node?
}

///|
pub impl @nodes.NodeClass for SSRNode with fn class_name(_) {
  "SSRNode"
}

///|
pub impl @nodes.NodeClass for SSRNode with fn children(self, _, out) {
  @nodes.push_child(out, "colorNode", Some(self.color_node))
  @nodes.push_child(out, "diffuseNode", self.diffuse_node)
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "normalNode", Some(self.normal_node))
  @nodes.push_child(out, "metalnessNode", self.metalness_node)
  @nodes.push_child(out, "specularNode", self.specular_node)
  @nodes.push_child(out, "specularF90Node", self.specular_f90_node)
  @nodes.push_child(out, "roughnessNode", self.roughness_node)
  @nodes.push_child(out, "maxDistance", Some(self.max_distance))
  @nodes.push_child(out, "thickness", Some(self.thickness))
  @nodes.push_child(out, "intensity", Some(self.intensity))
  @nodes.push_child(out, "screenEdgeFade", Some(self.screen_edge_fade))
  @nodes.push_child(out, "maxLuminance", Some(self.max_luminance))
  @nodes.push_child(out, "quality", Some(self.quality))
  @nodes.push_child(out, "mirrorBias", Some(self.mirror_bias))
  @nodes.push_child(out, "velocityTexture", self.velocity_texture)
  @nodes.push_child(
    out,
    "environmentIntensity",
    Some(self.environment_intensity),
  )
}

///|
/// `get stepExponent()`.
pub fn SSRNode::step_exponent(self : SSRNode) -> Double {
  self._step_exponent
}

///|
/// `set stepExponent( value )`: recompiles the SSR material.
pub fn SSRNode::set_step_exponent(self : SSRNode, value : Double) -> Unit {
  if value != self._step_exponent {
    self._step_exponent = value
    self.build_ssr_material()
  }
}

///|
/// `get blurQuality()`.
pub fn SSRNode::blur_quality(self : SSRNode) -> Int32 {
  self._blur_quality
}

///|
/// `set blurQuality( value )`: rebuilds the blur material.
pub fn SSRNode::set_blur_quality(self : SSRNode, value : Int32) -> Unit {
  if value != self._blur_quality {
    self._blur_quality = value
    // The size is baked into the boxBlur node tree, so rebuild it.
    if self.stochastic == false {
      self.build_blur_material()
    }
  }
}

///|
/// `_buildBlurMaterial()`: bakes the current `blurQuality` as the kernel size.
fn SSRNode::build_blur_material(self : SSRNode) -> Unit {
  @nodes.NodeMaterial::of(self._blur_material).unwrap().fragment_node = Some(
    box_blur().call([
      @nodes.texture(self._ssr_render_target.texture()),
      addon_options([
        ("size", self._blur_quality),
        ("separation", self._blur_spread),
      ]),
    ]),
  )
  self._blur_material.set_needs_update(true)
}

///|
/// `get screenEdgeFadeBlack()`.
pub fn SSRNode::screen_edge_fade_black(self : SSRNode) -> Bool {
  self._screen_edge_fade_black
}

///|
/// `set screenEdgeFadeBlack( value )`: recompiles the SSR material.
pub fn SSRNode::set_screen_edge_fade_black(
  self : SSRNode,
  value : Bool,
) -> Unit {
  if value != self._screen_edge_fade_black {
    self._screen_edge_fade_black = value
    self.build_ssr_material()
  }
}

///|
/// `get binaryRefine()`.
pub fn SSRNode::binary_refine(self : SSRNode) -> Bool {
  self._binary_refine
}

///|
/// `set binaryRefine( value )`: rebuilds the SSR material.
pub fn SSRNode::set_binary_refine(self : SSRNode, value : Bool) -> Unit {
  if value != self._binary_refine {
    self._binary_refine = value
    self.build_ssr_material()
  }
}

///|
/// `get reflectNonMetals()`.
pub fn SSRNode::reflect_non_metals(self : SSRNode) -> Bool {
  self._reflect_non_metals
}

///|
/// `set reflectNonMetals( value )`: rebuilds the SSR material.
pub fn SSRNode::set_reflect_non_metals(self : SSRNode, value : Bool) -> Unit {
  if value != self._reflect_non_metals {
    self._reflect_non_metals = value
    self.build_ssr_material()
  }
}

///|
/// `_buildSSRMaterial()`: re-invokes the fragment `Fn` (a no-op before `setup`).
fn SSRNode::build_ssr_material(self : SSRNode) -> Unit {
  guard self._ssr_fn is Some(ssr_fn) else { return }
  let m = @nodes.NodeMaterial::of(self._ssr_material).unwrap()
  m.context_node = Some(@nodes.context(value=self._shared_context.unwrap()))
  m.fragment_node = Some(ssr_fn.call([]))
  self._ssr_material.set_needs_update(true)
}

///|
/// `getTextureNode()`: the result of the effect (the blurred mips with a roughness
/// node in mirror mode).
pub fn SSRNode::get_texture_node(self : SSRNode) -> @nodes.Node {
  if self.stochastic == false && self.roughness_node is Some(_) {
    self._blurred_texture_node.unwrap()
  } else {
    self._texture_node
  }
}

///|
/// `setSize( width, height )`.
pub fn SSRNode::set_size(
  self : SSRNode,
  width : Double,
  height : Double,
) -> Unit {
  let width = ssr_node_math_round(self.resolution_scale * width)
  let height = ssr_node_math_round(self.resolution_scale * height)
  a4_uniform_vector2(self._resolution).set(width, height) |> ignore
  self._ssr_render_target.set_size(width.to_int(), height.to_int())
  self._blur_render_target.set_size(width.to_int(), height.to_int())
}

///|
/// `setHistory( history, velocity )`: the previous frame's denoised result (a
/// RecurrentDenoiseNode / SSRNode, whose output render target is used, or a texture)
/// and the velocity used to reproject it; `None` disables multi-bounce.
pub fn SSRNode::set_history(
  self : SSRNode,
  history : &@nodes.IntoTsl?,
  velocity : @nodes.Node?,
) -> Unit {
  self.history_texture = match history {
    None => None
    Some(h) =>
      match h.to_tsl() {
        Texture(t) => Some(t)
        Node(n) =>
          match RecurrentDenoiseNode::of(n) {
            Some(p) => Some(p.get_render_target().texture())
            None =>
              match SSRNode::of(n) {
                Some(p) => Some(p.get_render_target().texture())
                None => None
              }
          }
        _ => None
      }
  }
  self.velocity_texture = velocity
}

///|
/// `setEnvMap( hdr )`: the equirectangular HDR environment map (with CPU-side image
/// data) sampled when screen-space rays miss; `None` disables it.
pub fn SSRNode::set_env_map(self : SSRNode, hdr : @core.Texture?) -> Unit {
  guard hdr is Some(hdr) else {
    match self._importance_environment {
      Some(e) => {
        e.clear()
        self._importance_environment = None
      }
      None => ()
    }
    self.build_ssr_material()
    return
  }
  let has_data = match hdr.image() {
    DataImage({ data: Some(_), .. }) => true
    _ => false
  }
  if !has_data {
    @core.warn(
      "SSRNode: `environmentNode` / `setEnvMap()` expects an equirectangular HDR texture with CPU-side image data (e.g. RGBELoader). PMREM cubemaps and `scene.environment` are not supported.",
    )
    return
  }
  let environment = match self._importance_environment {
    Some(e) => e
    None => {
      let e = ImportanceSampledEnvironment::new(
        importance_sampling=self.env_importance_sampling,
      )
      self._importance_environment = Some(e)
      e
    }
  }
  environment.update_from(hdr)
  self.build_ssr_material()
}

///|
/// `get envMapIntensity()`: the importance-sampled env intensity (after `setEnvMap`).
pub fn SSRNode::env_map_intensity(self : SSRNode) -> @nodes.Node? {
  match self._importance_environment {
    Some(e) => Some(e.intensity)
    None => None
  }
}

///|
/// `getRenderTarget()`.
pub fn SSRNode::get_render_target(self : SSRNode) -> @core.RenderTarget {
  self._ssr_render_target
}

///|
fn ssr_node_copy_matrix4(node : @nodes.Node, m : @math.Matrix4) -> Unit {
  match @nodes.InputNode::get_value(node) {
    Matrix4(v) => v.copy(m) |> ignore
    _ => ()
  }
}

///|
pub impl @nodes.NodeClass for SSRNode with fn update_before(self, _, frame) {
  let m = display_ssr_node_module.get()
  let renderer = frame.renderer.unwrap()
  ssr_node_copy_matrix4(self._camera_world_matrix, self.camera.matrix_world)
  a4_uniform_vector3(self._camera_world_position).copy(self.camera.position)
  |> ignore
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  let ssr_render_target = self._ssr_render_target
  let blur_render_target = self._blur_render_target
  let size = renderer.get_drawing_buffer_size(m.size)
  m.quad_mesh.set_material(self._ssr_material)
  self.set_size(size.x, size.y)
  // Advance the noise index once per frame (matches SSGI / Denoise).
  a4_set_uniform_number(
    self._noise_index,
    ssr_node_js_mod(a4_uniform_number(self._noise_index) + 1.0, 2147483647.0),
  )
  // clear
  renderer.set_mrt(None) |> ignore
  renderer.set_clear_color_hex(0x000000, alpha=0.0)
  // ssr
  renderer.set_render_target(Some(ssr_render_target))
  m.quad_mesh.object.name = "SSR [ Reflections ]"
  m.quad_mesh.render(renderer)
  // blur (optional)
  if self.stochastic == false && self.roughness_node is Some(_) {
    // blur mips but leave the base mip unblurred
    for i = 0; i < blur_render_target.texture().mipmaps.length(); i = i + 1 {
      m.quad_mesh.set_material(
        if i == 0 {
          self._copy_material
        } else {
          self._blur_material
        },
      )
      a4_set_uniform_number(self._blur_spread, i.to_double())
      renderer.set_render_target(
        Some(blur_render_target),
        active_cube_face=0,
        active_mipmap_level=i,
      )
      m.quad_mesh.object.name = "SSR [ Blur Level " + i.to_string() + " ]"
      m.quad_mesh.render(renderer)
    }
  }
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
extern "js" fn ssr_node_js_mod(a : Double, b : Double) -> Double = "(a, b) => a % b"

///|
pub impl @nodes.NodeClass for SSRNode with fn setup(self, _, builder) {
  let uv_node = @nodes.uv()
  let point_to_line_distance = @nodes.fn_(
    fn(inputs, _) {
      let point = addon_arg(inputs, 0)
      let line_point_a = addon_arg(inputs, 1)
      let line_point_b = addon_arg(inputs, 2)
      // https://mathworld.wolfram.com/Point-LineDistance3-Dimensional.html
      Some(
        @nodes.cross(point.sub(line_point_a), point.sub(line_point_b))
        .length()
        .div(line_point_b.sub(line_point_a).length()),
      )
    },
    layout=addon_short_layout(
      [("point", "vec3"), ("linePointA", "vec3"), ("linePointB", "vec3")],
      "float",
    ),
  )
  let point_plane_distance = @nodes.fn_(
    fn(inputs, _) {
      let point = addon_arg(inputs, 0)
      let plane_point = addon_arg(inputs, 1)
      let plane_normal = addon_arg(inputs, 2)
      // planeNormal is already normalized, so the denominator is 1.
      let d = @nodes.mul(plane_normal.x(), plane_point.x())
        .add(@nodes.mul(plane_normal.y(), plane_point.y()))
        .add(@nodes.mul(plane_normal.z(), plane_point.z()))
        .negate()
        .to_var()
      let distance = @nodes.mul(plane_normal.x(), point.x())
        .add(@nodes.mul(plane_normal.y(), point.y()))
        .add(@nodes.mul(plane_normal.z(), point.z()))
        .add(d)
      Some(distance)
    },
    layout=addon_short_layout(
      [("point", "vec3"), ("planePoint", "vec3"), ("planeNormal", "vec3")],
      "float",
    ),
  )
  let get_view_z = @nodes.fn_(fn(inputs, _) {
    let depth = addon_arg(inputs, 0)
    let view_z_node = if self.camera.is_perspective_camera() {
      @nodes.perspective_depth_to_view_z.call([
        depth,
        self._camera_near,
        self._camera_far,
      ])
    } else {
      @nodes.orthographic_depth_to_view_z.call([
        depth,
        self._camera_near,
        self._camera_far,
      ])
    }
    Some(view_z_node)
  })
  let sample_depth = fn(uv : @nodes.Node) {
    @nodes.projection_depth.call([
      self.depth_node.sample(uv).r(),
      self._camera_near,
      self._camera_far,
    ])
  }
  let sample_march_noise = if self.stochastic == true {
    Some(bind_analytic_noise(self._resolution, seed=47))
  } else {
    None
  }
  let compute_screen_border_factor = @nodes.fn_(
    fn(inputs, _) {
      let uv_coord = addon_arg(inputs, 0)
      let border_width = addon_arg(inputs, 1)
      let border = border_width.max(0.0001)
      // Distance to the nearest screen edge — uniform falloff at corners.
      let edge_dist = @nodes.min(
        @nodes.min(uv_coord.x(), @nodes.float(1).sub(uv_coord.x())),
        @nodes.min(uv_coord.y(), @nodes.float(1).sub(uv_coord.y())),
      )
      // Two smoothsteps for a softer ease-in-out than a single ramp.
      let t = edge_dist.smoothstep(0, border)
      Some(t.smoothstep(0, 1).pow(0.125))
    },
    layout=addon_short_layout(
      [("uvCoord", "vec2"), ("borderWidth", "float")],
      "float",
    ),
  )
  let ssr = @nodes.fn_(fn(_, _) {
    let is_perspective = self.camera.is_perspective_camera()
    let noise = match sample_march_noise {
      Some(f) => Some(f.call([uv_node, self._noise_index]))
      None => None
    }
    // reconstruct at the depth texel center
    let depth_size = @nodes.vec2(@nodes.texture_size(self.depth_node)).to_const()
    let uv_pos = uv_node
      .mul(depth_size)
      .floor()
      .add(0.5)
      .div(depth_size)
      .to_var()
    let depth = sample_depth(uv_pos).to_var()
    // Skip background pixels (cleared far-plane depth).
    @nodes.is_background_depth.call([depth]).discard()
    let view_position = @nodes.get_view_position
      .call([uv_pos, depth, self._camera_projection_matrix_inverse])
      .to_var()
    let world_position = self._camera_world_matrix
      .mul(@nodes.vec4_of([view_position, 1.0]))
      .xyz()
      .to_var()
    let view_normal = self.normal_node.rgb().normalize().to_var()
    let view_incident_dir = (if is_perspective {
      @nodes.normalize(view_position)
    } else {
      @nodes.vec3_of([0, 0, -1])
    }).to_var()
    // The node system samples the metalness/roughness textures at the current uv.
    let metalness = @nodes.float(ssr_node_or_null(self.metalness_node))
    if self.stochastic == false && self._reflect_non_metals == false {
      metalness.less_than_equal(0.0).discard()
    }
    let roughness = @nodes.float(ssr_node_or_null(self.roughness_node))
    let glossiness = @nodes.min(roughness.div(0.25), 1).one_minus()
    // Only the fade-to-black miss path reads this.
    let surface_border_factor = if self.screen_edge_fade_black() {
      Some(compute_screen_border_factor.call([uv_pos, self.screen_edge_fade]))
    } else {
      None
    }
    let hit_border_width = self.screen_edge_fade.mul(glossiness)
    let v = view_incident_dir.negate().normalize().to_var()
    let mut view_reflect_dir = view_incident_dir
    let mut final_sample_weight = view_incident_dir
    let mut spec_dominant_factor = view_incident_dir
    let mut sample_env_reflection : (() -> @nodes.Node)? = None
    if self.stochastic == false {
      view_reflect_dir = @nodes.reflect(view_incident_dir, view_normal)
        .normalize()
        .to_var()
      final_sample_weight = @nodes.vec3(metalness)
      spec_dominant_factor = @nodes.float(1)
    } else {
      let xi = noise.unwrap().to_var()
      // mirror bias trades the unbiased GGX lobe for lower variance
      xi
      .y()
      .assign(@nodes.mix(xi.y(), 0.0, self.mirror_bias.mul(xi.w().sqrt())))
      // The base color only feeds the metalness F0 fallback.
      let albedo = (match (self.specular_node, self.diffuse_node) {
        (None, Some(d)) => d.sample(uv_pos).rgb()
        _ => @nodes.vec3(1)
      }).to_var()
      let f90 : &@nodes.IntoTsl = match self.specular_f90_node {
        Some(n) => (n : &@nodes.IntoTsl)
        None => (1 : &@nodes.IntoTsl)
      }
      let ggx = fn(xi_arg : @nodes.Node) {
        match self.specular_node {
          Some(s) =>
            ggx_reflection_sample(
              view_normal,
              v,
              roughness,
              metalness,
              albedo,
              xi_arg,
              f0=s,
              f90~,
            )
          None =>
            ggx_reflection_sample(
              view_normal,
              v,
              roughness,
              metalness,
              albedo,
              xi_arg,
              f90~,
            )
        }
      }
      let ggx_sample = ggx(xi).to_var()
      // Sometimes the GGX sample is facing away from the surface, so re-sample.
      @nodes.if_(ggx_sample.get("reflectDir").dot(view_normal).less_than(0), fn() {
        ggx_sample.assign(ggx(xi.add(xi.mul(7)).fract()))
      })
      |> ignore
      view_reflect_dir = ggx_sample.get("reflectDir").to_var()
      final_sample_weight = ggx_sample.get("sampleWeight").to_var()
      spec_dominant_factor = get_specular_dominant_factor()
        .call([ggx_sample.get("NdotV"), roughness])
        .to_var()
      let view_reflect_dir_ = view_reflect_dir
      sample_env_reflection = Some(fn() {
        guard self._importance_environment is Some(environment) else {
          return @nodes.vec3(0)
        }
        let env_color = @nodes.vec3(0).to_var()
        if self.env_importance_sampling {
          let xi2 = bind_analytic_noise(self._resolution, seed=59).call([
            uv_pos,
            self._noise_index,
          ])
          env_color.assign(
            environment.sample_environment_mis(
              camera_world_matrix=self._camera_world_matrix,
              view_reflect_dir=view_reflect_dir_,
              n=view_normal,
              v~,
              alpha=ggx_sample.get("alpha"),
              f0=ggx_sample.get("f0"),
              f90=ggx_sample.get("f90"),
              xi2~,
            ),
          )
        } else {
          env_color.assign(
            environment.sample_environment_brdf(
              camera_world_matrix=self._camera_world_matrix,
              view_reflect_dir=view_reflect_dir_,
              n=view_normal,
              v~,
              alpha=ggx_sample.get("alpha"),
              f0=ggx_sample.get("f0"),
              f90=ggx_sample.get("f90"),
            ),
          )
        }
        env_color
      })
    }
    let view_reflect_dir = view_reflect_dir
    let final_sample_weight = final_sample_weight
    let spec_dominant_factor = spec_dominant_factor
    // Multi-bounce: fold in the previous frame's reflection at the hit point.
    let reproject_hit_point_history = fn(
      uv_hit : @nodes.Node,
      color : @nodes.Node,
    ) {
      match (self.history_texture, self.velocity_texture) {
        (Some(history_texture), Some(velocity_texture)) => {
          let velocity = velocity_texture.sample(uv_hit).xy()
          let history_uv = uv_hit.sub(velocity)
          let history_bounce = @nodes.texture(
            history_texture,
            uv_node=history_uv,
          ).to_var()
          let sample_decay = history_bounce.a().one_minus()
          color.add(history_bounce.rgb().mul(sample_decay))
        }
        _ => color
      }
    }
    // Fades a screen-space hit near the screen borders.
    let apply_hit_edge_fade = fn(
      reflect_color : @nodes.Node,
      uv_s : @nodes.Node,
      hit_border_width : @nodes.Node,
    ) {
      if self.screen_edge_fade_black() {
        let hit_border_factor = compute_screen_border_factor.call([
          uv_s,
          self.screen_edge_fade,
        ])
        reflect_color.rgb().mul_assign(hit_border_factor)
      } else {
        let hit_border_factor = compute_screen_border_factor.call([
          uv_s, hit_border_width,
        ])
        @nodes.if_(hit_border_factor.less_than(1), fn() {
          reflect_color
          .rgb()
          .assign(
            @nodes.mix(
              sample_env_reflection.unwrap()().mul(self.environment_intensity),
              reflect_color.rgb(),
              hit_border_factor,
            ),
          )
        })
        |> ignore
      }
    }
    let max_reflect_ray_len = self.max_distance
      .div(@nodes.dot(view_incident_dir.negate(), view_normal).max(0.0001))
      .to_var()
    let d1view_position = view_position
      .add(view_reflect_dir.mul(max_reflect_ray_len))
      .to_var()
    // Camera type is fixed at build time.
    if is_perspective {
      @nodes.if_(d1view_position.z().greater_than(self._camera_near.negate()), fn() {
        let t = @nodes.sub(self._camera_near.negate(), view_position.z()).div(
          view_reflect_dir.z(),
        )
        d1view_position.assign(view_position.add(view_reflect_dir.mul(t)))
      })
      |> ignore
    }
    let d0 = uv_pos.mul(self._resolution).xy().to_var()
    let d1 = @nodes.get_screen_position
      .call([d1view_position, self._camera_projection_matrix])
      .mul(self._resolution)
      .to_var()
    // clip the ray to the screen so all steps land on visible texels
    let extent = d1.sub(d0).to_var()
    let exit_t = @nodes.vec2_of([
      extent
      .x()
      .greater_than_equal(0)
      .select(self._resolution.x().sub(d0.x()), else_node=d0.x()),
      extent
      .y()
      .greater_than_equal(0)
      .select(self._resolution.y().sub(d0.y()), else_node=d0.y()),
    ]).div(extent.abs().max(0.000001))
    let clip_t = @nodes.min(exit_t.x(), exit_t.y()).min(1).to_const()
    @nodes.if_(clip_t.less_than(1), fn() {
      d1.assign(d0.add(extent.mul(clip_t)))
      d1view_position.assign(
        if is_perspective {
          @nodes.mix(
            view_position.div(view_position.z()),
            d1view_position.div(d1view_position.z()),
            clip_t,
          ).div(
            @nodes.mix(
              view_position.z().reciprocal(),
              d1view_position.z().reciprocal(),
              clip_t,
            ),
          )
        } else {
          @nodes.mix(view_position, d1view_position, clip_t)
        },
      )
    })
    |> ignore
    let x_len = d1.x().sub(d0.x()).to_var()
    let y_len = d1.y().sub(d0.y()).to_var()
    // dominant-axis ray length in texels
    let ray_len = @nodes.max(x_len.abs(), y_len.abs()).max(1).to_var()
    let total_step = @nodes.int(
      if self.stochastic == false {
        @nodes.trunc(
          @nodes.max(@nodes.abs(x_len), @nodes.abs(y_len)).mul(
            self.quality.clamp(),
          ),
        )
        .max(@nodes.int(1))
        .to_const()
      } else {
        self.quality.clamp().mul(SSR_NODE_MAX_STEPS).max(@nodes.float(1))
      },
    ).to_const()
    let x_span = x_len.div(total_step).to_var()
    let y_span = y_len.div(total_step).to_var()
    let step_vec = @nodes.vec2_of([x_span, y_span]).to_var()
    let inv_resolution = @nodes.vec2_of([@nodes.float(1), @nodes.float(1)])
      .div(self._resolution)
      .to_var()
    let uv_pixel_step_x = @nodes.vec2_of([inv_resolution.x(), @nodes.float(0)]).to_var()
    let output = @nodes.vec4(0).to_var()
    let hit = @nodes.float(0).to_var()
    // Reflected-ray view-space Z at ray parameter s (linear in 1/z for perspective).
    let recip_vpz = @nodes.float(1).div(view_position.z()).to_const()
    let recip_d1_vpz = @nodes.float(1).div(d1view_position.z()).to_const()
    let reflect_ray_z_at = fn(s_val : @nodes.Node) {
      if is_perspective {
        @nodes.float(1).div(
          recip_vpz.add(s_val.mul(recip_d1_vpz.sub(recip_vpz))),
        )
      } else {
        view_position
        .z()
        .add(s_val.mul(d1view_position.z().sub(view_position.z())))
      }
    }
    // view-space point on the reflected ray at s
    let ray_point_at = fn(s_val : @nodes.Node) {
      if is_perspective {
        @nodes.mix(
          view_position.div(view_position.z()),
          d1view_position.div(d1view_position.z()),
          s_val,
        ).mul(reflect_ray_z_at(s_val))
      } else {
        @nodes.mix(view_position, d1view_position, s_val)
      }
    }
    // Screen-space position along the ray for a given s.
    let screen_pos_at = fn(s_val : @nodes.Node) {
      d0.add(step_vec.mul(s_val.mul(total_step)))
    }
    // Ray parameter s for step `idx`.
    let sample_fraction = fn(idx : @nodes.Node) {
      if self.stochastic == false {
        idx.div(total_step)
      } else {
        @nodes.max(
          idx
          .add(noise.unwrap().z().sub(0.5))
          .div(total_step)
          .pow(self.step_exponent()),
          idx.div(ray_len),
        )
      }
    }
    // Carry the hit out of the loop so refinement runs after the march.
    let found_hit = @nodes.bool(false).to_var()
    let hit_s_lo = @nodes.float(0).to_var()
    let hit_s_hi = @nodes.float(0).to_var()
    let hit_uv_s = @nodes.vec2(0).to_var()
    let hit_d = @nodes.float(0).to_var()
    let previous_s = @nodes.float(0).to_var()
    let previous_in_front = @nodes.bool(true).to_var()
    let can_refine = @nodes.bool(false).to_var()
    // March from d0 toward d1, looking for an intersection with the depth buffer.
    @nodes.loop_([@nodes.loop_range(start=@nodes.int(1), end=total_step)], fn(
      inputs,
    ) {
      let i = inputs.named("i").unwrap()
      let s = sample_fraction(@nodes.float(i)).to_var()
      @nodes.if_(s.greater_than(1), fn() { @nodes.break_() }) |> ignore
      let xy = screen_pos_at(s).to_var()
      @nodes.if_(
        xy
        .x()
        .less_than(0)
        .or(xy.x().greater_than(self._resolution.x()))
        .or(xy.y().less_than(0))
        .or(xy.y().greater_than(self._resolution.y())),
        fn() { @nodes.break_() },
      )
      |> ignore
      let uv_s = xy.mul(inv_resolution).to_var()
      let d = sample_depth(uv_s).to_var()
      let v_z = get_view_z.call([d]).to_var()
      let view_reflect_ray_z = reflect_ray_z_at(s).to_var()
      // Advance the previous sample before any Continue().
      let last_s = previous_s.to_var()
      let last_in_front = previous_in_front.to_var()
      previous_s.assign(s)
      previous_in_front.assign(view_reflect_ray_z.greater_than(v_z))
      @nodes.if_(
        @nodes.is_background_depth
        .call([d])
        .not_()
        .and_(view_reflect_ray_z.less_than_equal(v_z)),
        fn() {
          // Depth crossing: gate by thickness before stopping.
          let v_p = @nodes.get_view_position
            .call([uv_s, d, self._camera_projection_matrix_inverse])
            .to_var()
          let away = point_to_line_distance
            .call([v_p, view_position, d1view_position])
            .to_var()
          let uv_neighbor = uv_s.add(uv_pixel_step_x).to_var()
          let v_p_neighbor = @nodes.get_view_position
            .call([uv_neighbor, d, self._camera_projection_matrix_inverse])
            .to_var()
          let min_thickness = v_p_neighbor.x().sub(v_p.x()).mul(3).to_var()
          // Only refinement may use a wider coarse tolerance.
          let step_length = @nodes.distance(
            ray_point_at(last_s),
            ray_point_at(s),
          )
          let tk = (if self.binary_refine() {
            @nodes.max(@nodes.max(min_thickness, self.thickness), step_length)
          } else {
            @nodes.max(min_thickness, self.thickness)
          }).to_var()
          @nodes.if_(away.less_than_equal(tk), fn() {
            let v_n = self.normal_node.sample(uv_s).rgb().normalize().to_var()
            // the reflected ray points to the same side as the fragment's normal
            @nodes.if_(
              @nodes.dot(view_reflect_dir, v_n).greater_than_equal(0),
              fn() { @nodes.continue_() },
            )
            |> ignore
            if self.stochastic == false {
              // the depth of the intersection between the reflected ray and the scene
              let distance = point_plane_distance
                .call([v_p, view_position, view_normal])
                .to_var()
              // Distance exceeding limit
              @nodes.if_(distance.greater_than(self.max_distance), fn() {
                @nodes.break_()
              })
              |> ignore
            }
            found_hit.assign(true)
            hit_uv_s.assign(uv_s)
            hit_d.assign(d)
            if self.binary_refine() {
              // refine only front-to-back crossings
              can_refine.assign(last_in_front)
              hit_s_lo.assign(last_s)
              hit_s_hi.assign(s)
            }
            @nodes.break_()
          })
          |> ignore
        },
      )
      |> ignore
    })
    @nodes.if_(found_hit, fn() {
      // Bisect the bracketed crossing toward the exact intersection.
      if self.binary_refine() {
        @nodes.if_(can_refine, fn() {
          @nodes.loop_(
            [
              @nodes.loop_range(
                start=@nodes.int(0),
                end=@nodes.int(8),
                type_="int",
                condition="<",
              ),
            ],
            fn(_) {
              let s_mid = hit_s_lo.add(hit_s_hi).mul(0.5).to_var()
              let uv_mid = screen_pos_at(s_mid).mul(inv_resolution).to_const()
              let scene_z_mid = get_view_z.call([sample_depth(uv_mid)])
              let front_facing = @nodes.dot(
                view_reflect_dir,
                self.normal_node.sample(uv_mid).rgb().normalize(),
              ).less_than(0)
              @nodes.if_(
                reflect_ray_z_at(s_mid)
                .less_than_equal(scene_z_mid)
                .and_(front_facing),
                fn() { hit_s_hi.assign(s_mid) },
              ).else_(fn() { hit_s_lo.assign(s_mid) })
            },
          )
          // re-fetch UV/depth at the refined `s`
          hit_uv_s.assign(screen_pos_at(hit_s_hi).mul(inv_resolution))
          hit_d.assign(sample_depth(hit_uv_s))
        })
        |> ignore
      }
      // Shade the hit, reusing the depth fetched during the march (or refinement).
      let uv_s = hit_uv_s
      let v_p = @nodes.get_view_position
        .call([uv_s, hit_d, self._camera_projection_matrix_inverse])
        .to_var()
      // In blur mode over-range hits fall back to env.
      let distance_point_plane = if self.stochastic == false {
        point_plane_distance.call([v_p, view_position, view_normal]).to_var()
      } else {
        @nodes.float(0)
      }
      let within_range = distance_point_plane
        .less_than_equal(self.max_distance)
        .to_var()
      if self.binary_refine() {
        // bisection can land on a depth discontinuity, so validate the refined hit
        let neighbor = @nodes.get_view_position.call([
          uv_s.add(uv_pixel_step_x),
          hit_d,
          self._camera_projection_matrix_inverse,
        ])
        let tk = @nodes.max(neighbor.x().sub(v_p.x()).mul(3), self.thickness)
        within_range.assign(
          within_range
          .and_(@nodes.is_background_depth.call([hit_d]).not_())
          .and_(
            point_to_line_distance
            .call([v_p, view_position, d1view_position])
            .less_than_equal(tk),
          ),
        )
        within_range.assign(
          within_range.and_(
            @nodes.dot(
              view_reflect_dir,
              self.normal_node.sample(uv_s).rgb().normalize(),
            ).less_than(0),
          ),
        )
      }
      @nodes.if_(within_range, fn() {
        let hit_world_position = self._camera_world_matrix
          .mul(@nodes.vec4_of([v_p, 1.0]))
          .xyz()
          .to_var()
        let world_distance = @nodes.distance(world_position, hit_world_position)
          .mul(spec_dominant_factor)
          .to_var()
        let reflect_color = self.color_node.sample(uv_s).to_var()
        // Multi-bounce: add the reprojected previous-frame reflection at the hit point.
        reflect_color
        .rgb()
        .assign(reproject_hit_point_history(uv_s, reflect_color.rgb()))
        if self.stochastic == true {
          apply_hit_edge_fade(reflect_color, uv_s, hit_border_width)
        }
        // The mirror/blur path reapplies distance attenuation and grazing Fresnel.
        let mut weighted_color = reflect_color.rgb().mul(final_sample_weight)
        if self.stochastic == false {
          let ratio = @nodes.float(1)
            .sub(distance_point_plane.div(self.max_distance))
            .to_var()
          let attenuation = ratio.mul(ratio).to_var()
          let fresnel_coe = @nodes.div(
            @nodes.dot(view_incident_dir, view_reflect_dir).add(1),
            2,
          ).to_var()
          weighted_color = weighted_color.mul(attenuation.mul(fresnel_coe))
        }
        hit.assign(1)
        output.assign(@nodes.vec4_of([weighted_color, world_distance]))
      })
      |> ignore
    })
    |> ignore
    // Screen-space ray missed: environment fallback.
    @nodes.if_(hit.equal(0), fn() {
      if self.stochastic == true {
        output.assign(
          @nodes.vec4_of([
            sample_env_reflection.unwrap()().mul(self.environment_intensity),
            @nodes.float(ENV_RAY_LENGTH),
          ]),
        )
        // Misses fade by the surface pixel UV.
        if self.screen_edge_fade_black() {
          output.rgb().mul_assign(surface_border_factor.unwrap())
        }
      }
    })
    |> ignore
    let lum = @nodes.luminance(output.rgb()).max(0.0001).to_var()
    output.rgb().mul_assign(self.max_luminance.div(lum).min(1))
    // scale the reflection color by the user-controlled intensity
    output.rgb().mul_assign(self.intensity)
    Some(output.max(0))
  })
  self._ssr_fn = Some(ssr)
  self._shared_context = Some(builder.get_shared_context())
  self.build_ssr_material()
  let reflection_buffer = @nodes.texture(self._ssr_render_target.texture())
  if self.stochastic == false {
    self.build_blur_material()
  }
  @nodes.NodeMaterial::of(self._copy_material).unwrap().fragment_node = Some(
    reflection_buffer,
  )
  self._copy_material.set_needs_update(true)
  Some(self.get_texture_node())
}

///|
/// `float( node )` of a node that may be `null`.
fn ssr_node_or_null(node : @nodes.Node?) -> @nodes.TslValue {
  match node {
    Some(n) => Node(n)
    None => Null
  }
}

///|
pub impl @nodes.NodeClass for SSRNode with fn dispose(self, node) {
  node.dispose_base()
  self._ssr_render_target.dispose()
  self._blur_render_target.dispose()
  self._ssr_material.dispose()
  self._blur_material.dispose()
  self._copy_material.dispose()
  match self._importance_environment {
    Some(e) => {
      e.dispose()
      self._importance_environment = None
    }
    None => ()
  }
}

///|
/// `new SSRNode( colorNode, depthNode, normalNode, options )`; the options are
/// upstream's (`stochastic`, `metalnessNode`, `specularNode`, `specularF90Node`,
/// `roughnessNode`, `reflectNonMetals`, `environmentNode`, `envImportanceSampling`,
/// `diffuseNode`, `binaryRefine`, `camera`).
pub fn SSRNode::new(
  color_node : @nodes.Node,
  depth_node : @nodes.Node,
  normal_node : @nodes.Node,
  stochastic~ : Bool = false,
  metalness_node? : @nodes.Node,
  specular_node? : @nodes.Node,
  specular_f90_node? : @nodes.Node,
  roughness_node? : @nodes.Node,
  reflect_non_metals~ : Bool = false,
  environment_node? : @core.Texture,
  env_importance_sampling~ : Bool = false,
  diffuse_node? : &@nodes.IntoTsl,
  binary_refine~ : Bool = false,
  camera? : @core.Object3D,
) -> @nodes.Node {
  load_display_ssr_node()
  let node = @nodes.Node::alloc(node_type="vec4")
  let diffuse_node = match diffuse_node {
    Some(d) if !d.to_tsl().is_nullish() => Some(@nodes.node_object(d.to_tsl()))
    _ => None
  }
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let max_distance = @nodes.uniform(1)
  let thickness = @nodes.uniform(0.1)
  let intensity = @nodes.uniform(1)
  let screen_edge_fade = @nodes.uniform(0.2)
  let max_luminance = @nodes.uniform(10)
  let quality = @nodes.uniform(0.5)
  let mirror_bias = @nodes.uniform(0)
  let camera = match camera {
    Some(c) => c
    None =>
      match @nodes.PassTextureNode::of(color_node) {
        Some(p) if p.pass_node.has_flag("isPassNode") =>
          @nodes.PassNode::of(p.pass_node).unwrap().camera
        _ => abort("THREE.SSRNode: No camera found. ssr() requires a camera.")
      }
  }
  let _blur_spread = @nodes.uniform(1)
  let _camera_projection_matrix = @nodes.uniform(camera.projection_matrix())
  let _camera_projection_matrix_inverse = @nodes.uniform(
    camera.projection_matrix_inverse(),
  )
  let _camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let _camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let _camera_world_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world),
  )
  let _camera_world_position = @nodes.uniform(
    @math.Vector3::new(0.0, 0.0, 0.0).copy(camera.position),
  )
  let _camera_view_matrix = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world),
  )
  let _camera_view_matrix_inverse = @nodes.uniform(
    @math.Matrix4::new().copy(camera.matrix_world_inverse()),
  )
  let _resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let _noise_index = @nodes.uniform(0)
  let environment_intensity = @nodes.uniform(ADDON_PI)
  let _ssr_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
  )
  _ssr_render_target.texture().name = "SSRNode.SSR"
  let _blur_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    type_=@core.HalfFloatType,
    min_filter=@core.LinearMipmapLinearFilter,
    mag_filter=@core.LinearFilter,
  )
  _blur_render_target.texture().name = "SSRNode.Blur"
  for _ in 0..<5 {
    _blur_render_target.texture().mipmaps.push(
      DomImage(@core.JsValue::object()),
    )
  }
  let _ssr_material = @nodes.NodeMaterial::new()
  _ssr_material.name = "SSRNode.SSR"
  let _blur_material = @nodes.NodeMaterial::new()
  _blur_material.name = "SSRNode.Blur"
  let _copy_material = @nodes.NodeMaterial::new()
  _copy_material.name = "SSRNode.Copy"
  let _texture_node = @nodes.pass_texture(node, _ssr_render_target.texture())
  let blurred_texture_node = match roughness_node {
    Some(r) if stochastic == false => {
      let mips = _blur_render_target.texture().mipmaps.length() - 1
      let lod = r.mul(r).mul(mips).clamp(low=0, high=mips)
      Some(@nodes.pass_texture(node, _blur_render_target.texture()).level(lod))
    }
    _ => None
  }
  let p = SSRNode::{
    stochastic,
    env_importance_sampling,
    color_node,
    diffuse_node,
    depth_node,
    normal_node,
    metalness_node,
    specular_node,
    specular_f90_node,
    roughness_node,
    _reflect_non_metals: reflect_non_metals,
    resolution_scale: 1.0,
    max_distance,
    thickness,
    intensity,
    screen_edge_fade,
    _screen_edge_fade_black: false,
    max_luminance,
    quality,
    mirror_bias,
    _blur_quality: 2,
    _binary_refine: binary_refine,
    _step_exponent: 2.0,
    environment_node,
    history_texture: None,
    velocity_texture: None,
    camera,
    _blur_spread,
    _camera_projection_matrix,
    _camera_projection_matrix_inverse,
    _camera_near,
    _camera_far,
    _camera_world_matrix,
    _camera_world_position,
    _camera_view_matrix,
    _camera_view_matrix_inverse,
    _resolution,
    _noise_index,
    _importance_environment: None,
    environment_intensity,
    _ssr_render_target,
    _blur_render_target,
    _ssr_material,
    _ssr_fn: None,
    _shared_context: None,
    _blur_material,
    _copy_material,
    _texture_node,
    _blurred_texture_node: blurred_texture_node,
  }
  if environment_node is Some(e) {
    p.set_env_map(Some(e))
  }
  node.set_class(p)
}

///|
pub fn SSRNode::of(node : @nodes.Node) -> SSRNode? {
  addon_class_of(node, "SSRNode")
}

///|
/// `ssr( colorNode, depthNode, normalNode, options )`.
pub fn ssr(
  color_node : &@nodes.IntoTsl,
  depth_node : &@nodes.IntoTsl,
  normal_node : &@nodes.IntoTsl,
  stochastic~ : Bool = false,
  metalness_node? : @nodes.Node,
  specular_node? : @nodes.Node,
  specular_f90_node? : @nodes.Node,
  roughness_node? : @nodes.Node,
  reflect_non_metals~ : Bool = false,
  environment_node? : @core.Texture,
  env_importance_sampling~ : Bool = false,
  diffuse_node? : &@nodes.IntoTsl,
  binary_refine~ : Bool = false,
  camera? : @core.Object3D,
) -> @nodes.Node {
  load_display_ssr_node()
  SSRNode::new(
    @nodes.node_object(color_node.to_tsl()),
    @nodes.node_object(depth_node.to_tsl()),
    @nodes.node_object(normal_node.to_tsl()),
    stochastic~,
    metalness_node?,
    specular_node?,
    specular_f90_node?,
    roughness_node?,
    reflect_non_metals~,
    environment_node?,
    env_importance_sampling~,
    diffuse_node?,
    binary_refine~,
    camera?,
  )
}
