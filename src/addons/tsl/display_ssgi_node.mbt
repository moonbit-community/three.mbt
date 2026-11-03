// examples/jsm/tsl/display/SSGINode.js

///|
/// The module-level state of SSGINode.js (`_quadMesh`, `_size`, `_rendererState`).
priv struct SSGINodeModule {
  quad_mesh : @nodes.QuadMesh
  size : @math.Vector2
  mut renderer_state : @nodes.RendererState?
}

///|
let _ssgi_node_module : AddonModule[SSGINodeModule] = AddonModule::new(fn() {
  {
    quad_mesh: @nodes.QuadMesh::new(),
    size: @math.Vector2::new(0.0, 0.0),
    renderer_state: None,
  }
})

///|
/// Evaluates SSGINode.js's module-level statements (as its ES `import` does).
pub fn load_display_ssgi_node() -> Unit {
  _ssgi_node_module.get() |> ignore
}

///|
// From Activision GTAO paper: https://www.activision.com/cdn/research/s2016_pbs_activision_occlusion.pptx
let _ssgi_node_temporal_rotations : Array[Double] = [60, 300, 180, 240, 120, 0]

///|
let _ssgi_node_spatial_offsets : Array[Double] = [0, 0.5, 0.25, 0.75]

///|
extern "js" fn ssgi_node_math_round(x : Double) -> Double = "Math.round"

///|
/// `console.error( message )`.
extern "js" fn ssgi_node_console_error(message : String) -> Unit = "(m) => console.error( m )"

///|
extern "js" fn ssgi_node_nan() -> Double = "() => NaN"

///|
extern "js" fn ssgi_node_math_tan(x : Double) -> Double = "Math.tan"

///|
/// Post processing node for screen space global illumination (SSGI, after SSRT3): renders
/// AO and indirect diffuse light of a beauty, depth and normal buffer.
pub(all) struct SSGINode {
  mut beauty_node : @nodes.Node
  mut depth_node : @nodes.Node
  mut normal_node : @nodes.Node?
  mut resolution_scale : Double
  slice_count : @nodes.Node
  step_count : @nodes.Node
  ao_intensity : @nodes.Node
  gi_intensity : @nodes.Node
  radius : @nodes.Node
  use_screen_space_sampling : @nodes.Node
  exp_factor : @nodes.Node
  thickness : @nodes.Node
  use_linear_thickness : @nodes.Node
  backface_lighting : @nodes.Node
  mut use_temporal_filtering : Bool
  _resolution : @nodes.Node
  _half_proj_scale : @nodes.Node
  _temporal_direction : @nodes.Node
  _temporal_offset : @nodes.Node
  _resolution_scale : @nodes.Node
  _camera_projection_matrix : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _camera : @core.Object3D
  _ssgi_render_target : @core.RenderTarget
  _material : @core.Material
  mut _ao_node : @nodes.Node
  mut _gi_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for SSGINode with fn class_name(_) {
  "SSGINode"
}

///|
pub impl @nodes.NodeClass for SSGINode with fn children(self, _, out) {
  @nodes.push_child(out, "beautyNode", Some(self.beauty_node))
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "normalNode", self.normal_node)
  @nodes.push_child(out, "sliceCount", Some(self.slice_count))
  @nodes.push_child(out, "stepCount", Some(self.step_count))
  @nodes.push_child(out, "aoIntensity", Some(self.ao_intensity))
  @nodes.push_child(out, "giIntensity", Some(self.gi_intensity))
  @nodes.push_child(out, "radius", Some(self.radius))
  @nodes.push_child(
    out,
    "useScreenSpaceSampling",
    Some(self.use_screen_space_sampling),
  )
  @nodes.push_child(out, "expFactor", Some(self.exp_factor))
  @nodes.push_child(out, "thickness", Some(self.thickness))
  @nodes.push_child(out, "useLinearThickness", Some(self.use_linear_thickness))
  @nodes.push_child(out, "backfaceLighting", Some(self.backface_lighting))
}

///|
pub impl @nodes.NodeClass for SSGINode with fn set_size(self, _, width, height) {
  self.set_size(width, height)
  true
}

///|
/// `getAONode()`: the texture node holding the AO.
pub fn SSGINode::get_ao_node(self : SSGINode) -> @nodes.Node {
  self._ao_node
}

///|
/// `getGINode()`: the texture node holding the indirect diffuse light.
pub fn SSGINode::get_gi_node(self : SSGINode) -> @nodes.Node {
  self._gi_node
}

///|
/// `this._camera.fov` (`undefined`, so NaN, for other cameras).
fn ssgi_node_camera_fov(camera : @core.Object3D) -> Double {
  match camera.kind {
    Camera(c) =>
      match c.kind {
        PerspectiveCamera(p) => p.fov
        _ => ssgi_node_nan()
      }
    _ => ssgi_node_nan()
  }
}

///|
/// `setSize( width, height )`.
pub fn SSGINode::set_size(
  self : SSGINode,
  width : Double,
  height : Double,
) -> Unit {
  let width = ssgi_node_math_round(self.resolution_scale * width)
  let height = ssgi_node_math_round(self.resolution_scale * height)
  a4_set_uniform_number(self._resolution_scale, self.resolution_scale)
  a4_uniform_vector2(self._resolution).set(width, height) |> ignore
  self._ssgi_render_target.set_size(width.to_int(), height.to_int())
  a4_set_uniform_number(
    self._half_proj_scale,
    height /
    (
      ssgi_node_math_tan(
        ssgi_node_camera_fov(self._camera) * @math.DEG2RAD * 0.5,
      ) *
      2
    ) *
    0.5,
  )
}

///|
pub impl @nodes.NodeClass for SSGINode with fn update_before(self, _, frame) {
  let m = _ssgi_node_module.get()
  let renderer = frame.renderer.unwrap()
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  //
  let size = renderer.get_drawing_buffer_size(m.size)
  self.set_size(size.x, size.y)
  // update temporal uniforms
  if self.use_temporal_filtering == true {
    let frame_id = frame.frame_id
    a4_set_uniform_number(
      self._temporal_direction,
      _ssgi_node_temporal_rotations[frame_id % 6] / 360.0,
    )
    a4_set_uniform_number(
      self._temporal_offset,
      _ssgi_node_spatial_offsets[frame_id % 4],
    )
  } else {
    a4_set_uniform_number(self._temporal_direction, 1)
    a4_set_uniform_number(self._temporal_offset, 1)
  }
  //
  m.quad_mesh.set_material(self._material)
  m.quad_mesh.object.name = "SSGI"
  // clear (white for the AO attachement)
  renderer.set_clear_color_hex(0xffffff, alpha=1)
  // gi
  renderer.set_render_target(Some(self._ssgi_render_target))
  m.quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for SSGINode with fn setup(self, _, builder) {
  let renderer = builder.renderer
  if renderer.backend.has_flag("isWebGPUBackend") == true &&
    renderer.has_feature("rg11b10ufloat-renderable") == false {
    ssgi_node_console_error(
      "THREE.SSGINode: The device does not support the \"rg11b10ufloat-renderable\" feature which is required for SSGI.",
    )
  }
  let uv_node = @nodes.uv()
  let max_ray = @nodes.uint(32)
  let global_occluded_bitfield = @nodes.uint(0)
  let sample_depth = fn(uv : @nodes.Node) {
    @nodes.projection_depth.call([
      self.depth_node.sample(uv).r(),
      self._camera_near,
      self._camera_far,
    ])
  }
  let sample_center_depth = fn(uv : @nodes.Node) {
    // Sidestep the nearest-rounding during depth access for the unjittered center pixel to avoid banding
    let g = self.depth_node.gather().sample(uv)
    let depth = if builder.renderer.reversed_depth_buffer == true {
      @nodes.max(@nodes.max(g.x(), g.y()), @nodes.max(g.z(), g.w()))
    } else {
      @nodes.min(@nodes.min(g.x(), g.y()), @nodes.min(g.z(), g.w()))
    }
    @nodes.projection_depth.call([depth, self._camera_near, self._camera_far])
  }
  let sample_normal = fn(uv : @nodes.Node) {
    match self.normal_node {
      Some(normal_node) => normal_node.sample(uv).rgb().normalize()
      None =>
        @nodes.get_normal_from_depth.call([
          uv,
          @nodes.TextureNode::get_value(self.depth_node),
          self._camera_projection_matrix_inverse,
        ])
    }
  }
  let sample_beauty = fn(uv : @nodes.Node) { self.beauty_node.sample(uv) }
  // From Activision GTAO paper: https://www.activision.com/cdn/research/s2016_pbs_activision_occlusion.pptx
  let spatial_offsets = @nodes.fn_(
    fn(inputs, _) {
      let position = inputs.get(0).unwrap()
      Some(
        @nodes.float(0.25).mul(
          @nodes.sub(position.y(), position.x()).bit_and(3),
        ),
      )
    },
    layout=@nodes.FnLayout::short([("position", "vec2")], return_="float"),
  )
  let gtao_fast_acos = @nodes.fn_(
    fn(inputs, _) {
      let value = inputs.get(0).unwrap()
      let out_val = @nodes.abs(value)
        .mul(@nodes.float(-0.156583))
        .add(@nodes.half_pi)
      out_val.mul_assign(@nodes.sqrt(@nodes.abs(value).one_minus()))
      let x = value
        .x()
        .greater_than_equal(0)
        .select(out_val.x(), else_node=@nodes.pi.sub(out_val.x()))
      let y = value
        .y()
        .greater_than_equal(0)
        .select(out_val.y(), else_node=@nodes.pi.sub(out_val.y()))
      Some(@nodes.vec2_of([x, y]))
    },
    layout=@nodes.FnLayout::short([("value", "vec2")], return_="vec2"),
  )
  let horizon_sampling = @nodes.fn_(fn(inputs, _) {
    let direction_is_right = inputs.get(0).unwrap()
    let step_radius = inputs.get(1).unwrap()
    let radius_vs = inputs.get(2).unwrap()
    let view_position = inputs.get(3).unwrap()
    let slide_dir_texel_size = inputs.get(4).unwrap()
    let initial_ray_step = inputs.get(5).unwrap()
    let uv_node = inputs.get(6).unwrap()
    let view_dir = inputs.get(7).unwrap()
    let view_normal = inputs.get(8).unwrap()
    let n = inputs.get(9).unwrap()
    let step_count = self.step_count.to_const()
    let exp_factor = self.exp_factor.to_const()
    let thickness = self.thickness.to_const()
    let backface_lighting = self.backface_lighting.to_const()
    let uv_direction = direction_is_right.select(
      @nodes.vec2_of([1, -1]),
      else_node=@nodes.vec2_of([-1, 1]),
    ) // Port note: Because of different uv conventions, uv-y has a different sign
    let sampling_direction = direction_is_right.select(1, else_node=-1)
    let color = @nodes.vec3(0)
    @nodes.loop_(
      [
        @nodes.loop_range(
          start=@nodes.uint(0),
          end=step_count,
          type_="uint",
          condition="<",
        ),
      ],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        let offset = @nodes.pow(
            @nodes.abs(
              @nodes.mul(step_radius, @nodes.float(i).add(initial_ray_step)).div(
                radius_vs,
              ),
            ),
            exp_factor,
          )
          .mul(radius_vs)
          .to_const()
        let uv_offset = slide_dir_texel_size
          .mul(@nodes.max(offset, @nodes.float(i).add(1)))
          .to_const()
        let sample_uv = uv_node.add(uv_offset.mul(uv_direction)).to_const()
        @nodes.if_(
          sample_uv
          .x()
          .less_than_equal(0)
          .or(sample_uv.y().less_than_equal(0))
          .or(sample_uv.x().greater_than_equal(1))
          .or(sample_uv.y().greater_than_equal(1)),
          fn() { @nodes.break_() },
        )
        |> ignore
        let sample_view_position = @nodes.get_view_position
          .call([
            sample_uv,
            sample_depth(sample_uv),
            self._camera_projection_matrix_inverse,
          ])
          .to_const()
        let pixel_to_sample = sample_view_position
          .sub(view_position)
          .normalize()
          .to_const()
        let linear_thickness_multiplier = self.use_linear_thickness.select(
          sample_view_position
          .z()
          .negate()
          .div(self._camera_far)
          .clamp()
          .mul(100),
          else_node=@nodes.float(1),
        )
        let pixel_to_sample_backface = @nodes.normalize(
          sample_view_position
          .sub(linear_thickness_multiplier.mul(view_dir).mul(thickness))
          .sub(view_position),
        )
        let mut front_back_horizon = @nodes.vec2_of([
          @nodes.dot(pixel_to_sample, view_dir),
          @nodes.dot(pixel_to_sample_backface, view_dir),
        ])
        front_back_horizon = gtao_fast_acos.call([
          @nodes.clamp(front_back_horizon, low=-1, high=1),
        ])
        front_back_horizon = @nodes.clamp(
          @nodes.div(
            @nodes.mul(sampling_direction, front_back_horizon.negate()).sub(
              n.sub(@nodes.half_pi),
            ),
            @nodes.pi,
          ),
        ) // Port note: subtract half pi instead of adding it
        front_back_horizon = direction_is_right.select(
          front_back_horizon.yx(),
          else_node=front_back_horizon.xy(),
        ) // Front/Back get inverted depending on angle
        // inline ComputeOccludedBitfield() for easier debugging
        let min_horizon = front_back_horizon.x().to_const()
        let max_horizon = front_back_horizon.y().to_const()
        let start_horizon_int = @nodes.uint(
          front_back_horizon.mul(@nodes.float(max_ray)),
        ).to_const()
        let angle_horizon_int = @nodes.uint(
          @nodes.ceil(max_horizon.sub(min_horizon).mul(@nodes.float(max_ray))),
        ).to_const()
        let angle_horizon_bitfield = angle_horizon_int
          .greater_than(@nodes.uint(0))
          .select(
            @nodes.uint(
              @nodes.shift_right(
                @nodes.uint(4294967295.0),
                @nodes.uint(32).sub(max_ray).add(max_ray.sub(angle_horizon_int)),
              ),
            ),
            else_node=@nodes.uint(0),
          )
          .to_const()
        let mut current_occluded_bitfield = angle_horizon_bitfield.shift_left(
          start_horizon_int,
        )
        current_occluded_bitfield = current_occluded_bitfield.bit_and(
          global_occluded_bitfield.bit_not(),
        )
        global_occluded_bitfield.assign(
          global_occluded_bitfield.bit_or(current_occluded_bitfield),
        )
        let num_occluded_zones = @nodes.count_one_bits(
          current_occluded_bitfield,
        )
        //
        @nodes.if_(num_occluded_zones.greater_than(0), fn() { // If a ray hit the sample, that sample is visible from shading point
          let light_color = sample_beauty(sample_uv)
          @nodes.if_(@nodes.luminance(light_color).greater_than(0.001), fn() { // Continue if there is light at that location (intensity > 0)
            let light_direction_vs = @nodes.normalize(pixel_to_sample)
            let normal_dot_light_direction = @nodes.clamp(
              @nodes.dot(view_normal, light_direction_vs),
            )
            @nodes.if_(normal_dot_light_direction.greater_than(0.001), fn() { // Continue if light is facing surface normal
              let light_normal_vs = sample_normal(sample_uv)
              // Intensity of outgoing light in the direction of the shading point
              let mut light_normal_dot_light_direction = @nodes.dot(
                light_normal_vs,
                light_direction_vs.negate(),
              )
              let d = @nodes.sign(light_normal_dot_light_direction)
                .less_than(0)
                .select(
                  @nodes.abs(light_normal_dot_light_direction).mul(
                    backface_lighting,
                  ),
                  else_node=@nodes.abs(light_normal_dot_light_direction),
                )
              light_normal_dot_light_direction = backface_lighting
                .greater_than(0)
                .and_(@nodes.dot(light_normal_vs, view_dir).greater_than(0))
                .select(
                  d,
                  else_node=@nodes.clamp(light_normal_dot_light_direction),
                )
              color
              .rgb()
              .add_assign(
                @nodes.float(num_occluded_zones)
                .div(@nodes.float(max_ray))
                .mul(light_color)
                .mul(normal_dot_light_direction)
                .mul(light_normal_dot_light_direction),
              )
            })
            |> ignore
          })
          |> ignore
        })
        |> ignore
      },
    )
    Some(color)
  })
  let ao_field = @nodes.property("float")
  let gi_field = @nodes.property("vec3")
  let output_node = @nodes.output_struct([ao_field, gi_field])
  let gi = @nodes.fn_(fn(_, _) {
    let depth = self._resolution_scale
      .less_than(1)
      .select(sample_center_depth(uv_node), else_node=sample_depth(uv_node))
      .to_const()
    @nodes.is_background_depth.call([depth]).discard()
    let view_position = @nodes.get_view_position
      .call([uv_node, depth, self._camera_projection_matrix_inverse])
      .to_var()
    let view_normal = sample_normal(uv_node).to_var()
    let view_dir = @nodes.normalize(view_position.xyz().negate()).to_var()
    //
    let noise_offset = spatial_offsets.call([@nodes.screen_coordinate])
    let noise_direction = @nodes.interleaved_gradient_noise.call([
      @nodes.screen_coordinate,
    ])
    let noise_jitter_idx = self._temporal_direction.mul(0.02) // Port: Add noiseJitterIdx here for slightly better noise convergence with TRAA (see #31890 for more details)
    let initial_ray_step = @nodes.fract(noise_offset.add(self._temporal_offset)).add(
      @nodes.rand.call([uv_node.add(noise_jitter_idx).mul(2).sub(1)]),
    )
    let ao = @nodes.float(0)
    let color = @nodes.vec3(0)
    let rotation_count = self.slice_count.to_const()
    let step_count = self.step_count.to_const()
    let ao_intensity = self.ao_intensity.to_const()
    let gi_intensity = self.gi_intensity.to_const()
    let radius = self.radius.to_const()
    let step_radius = @nodes.float(0).to_var()
    @nodes.if_(self.use_screen_space_sampling, fn() {
      step_radius.assign(
        radius.mul(self._resolution.x().div(2)).div(@nodes.float(16)),
      ) // SSRT3 has a bug where stepRadius is divided by STEP_COUNT twice; fix here
    }).else_(fn() {
      step_radius.assign(
        @nodes.max(
          radius.mul(self._half_proj_scale).div(view_position.z().negate()),
          @nodes.float(step_count),
        ),
      ) // Port note: viewZ is negative so a negate is required
    })
    step_radius.div_assign(@nodes.float(step_count).add(1))
    let radius_vs = @nodes.max(1, @nodes.float(step_count.sub(1)))
      .mul(step_radius)
      .to_const()
    //
    @nodes.loop_(
      [
        @nodes.loop_range(
          start=@nodes.uint(0),
          end=rotation_count,
          type_="uint",
          condition="<",
        ),
      ],
      fn(inputs) {
        let i = inputs.named("i").unwrap()
        let rotation_angle = @nodes.mul(
          @nodes.float(i).add(noise_direction).add(self._temporal_direction),
          @nodes.pi.div(@nodes.float(rotation_count)),
        ).to_const()
        let slice_dir = @nodes.vec3_of([
          @nodes.vec2_of([
            @nodes.cos(rotation_angle),
            @nodes.sin(rotation_angle),
          ]),
          0,
        ]).to_const()
        let slide_dir_texel_size = slice_dir
          .xy()
          .mul(@nodes.float(1).div(self._resolution))
          .to_const()
        let plane_normal = @nodes.normalize(@nodes.cross(slice_dir, view_dir)).to_const()
        let tangent = @nodes.cross(view_dir, plane_normal).to_const()
        let projected_normal = view_normal
          .sub(plane_normal.mul(@nodes.dot(view_normal, plane_normal)))
          .to_const()
        let projected_normal_normalized = @nodes.normalize(projected_normal).to_const()
        let cos_n = @nodes.clamp(
          @nodes.dot(projected_normal_normalized, view_dir),
          low=-1,
          high=1,
        ).to_const()
        let n = @nodes.sign(@nodes.dot(projected_normal, tangent))
          .negate()
          .mul(@nodes.acos(cos_n))
          .to_const()
        global_occluded_bitfield.assign(0)
        color.add_assign(
          horizon_sampling.call([
            @nodes.bool(true),
            step_radius,
            radius_vs,
            view_position,
            slide_dir_texel_size,
            initial_ray_step,
            uv_node,
            view_dir,
            view_normal,
            n,
          ]),
        )
        color.add_assign(
          horizon_sampling.call([
            @nodes.bool(false),
            step_radius,
            radius_vs,
            view_position,
            slide_dir_texel_size,
            initial_ray_step,
            uv_node,
            view_dir,
            view_normal,
            n,
          ]),
        )
        ao.add_assign(
          @nodes.float(@nodes.count_one_bits(global_occluded_bitfield)).div(
            @nodes.float(max_ray),
          ),
        )
      },
    )
    ao.div_assign(@nodes.float(rotation_count))
    ao.assign(@nodes.pow(ao.clamp().one_minus(), ao_intensity).clamp())
    color.div_assign(@nodes.float(rotation_count))
    color.mul_assign(gi_intensity)
    // scale color based on luminance
    let max_luminance = @nodes.float(7).to_const() // 7 represent a HDR luminance value
    let current_luminance = @nodes.luminance(color)
    let scale = current_luminance
      .greater_than(max_luminance)
      .select(max_luminance.div(current_luminance), else_node=@nodes.float(1))
    color.mul_assign(scale)
    ao_field.assign(ao)
    gi_field.assign(color)
    Some(@nodes.vec4(0))
  })
  let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.color_node = Some(gi.call([]))
  node_material.output_node = Some(output_node)
  self._material.set_needs_update(true)
  //
  Some(self._ao_node)
}

///|
pub impl @nodes.NodeClass for SSGINode with fn dispose(self, node) {
  node.dispose_base()
  self._ssgi_render_target.dispose()
  self._material.dispose()
}

///|
/// `new SSGINode( beautyNode, depthNode, normalNode, camera )`; `normal_node` `None` is
/// `null` (the normals are reconstructed from the depth).
pub fn SSGINode::new(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  normal_node : @nodes.Node?,
  camera : @core.Object3D,
) -> @nodes.Node {
  _ssgi_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="vec4")
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let slice_count = @nodes.uniform(1, type_="uint")
  let step_count = @nodes.uniform(12, type_="uint")
  let ao_intensity = @nodes.uniform(1, type_="float")
  let gi_intensity = @nodes.uniform(10, type_="float")
  let radius = @nodes.uniform(12, type_="float")
  let use_screen_space_sampling = @nodes.uniform(true, type_="bool")
  let exp_factor = @nodes.uniform(2, type_="float")
  let thickness = @nodes.uniform(1, type_="float")
  let use_linear_thickness = @nodes.uniform(false, type_="bool")
  let backface_lighting = @nodes.uniform(0, type_="float")
  // private uniforms
  let resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let half_proj_scale = @nodes.uniform(1)
  let temporal_direction = @nodes.uniform(0)
  let temporal_offset = @nodes.uniform(0)
  let resolution_scale = @nodes.uniform(0)
  let camera_projection_matrix = @nodes.uniform(camera.projection_matrix())
  let camera_projection_matrix_inverse = @nodes.uniform(
    camera.projection_matrix_inverse(),
  )
  let camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let ssgi_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    count=2,
  )
  let ao_texture = ssgi_render_target.textures[0]
  ao_texture.name = "SSGI.AO"
  ao_texture.type_ = @core.UnsignedByteType
  ao_texture.format = @core.RedFormat
  let gi_texture = ssgi_render_target.textures[1]
  gi_texture.name = "SSGI.GI"
  gi_texture.type_ = @core.UnsignedInt101111Type
  gi_texture.format = @core.RGBFormat
  let material = @nodes.NodeMaterial::new()
  material.name = "SSGI"
  let payload = SSGINode::{
    beauty_node,
    depth_node,
    normal_node,
    resolution_scale: 1.0,
    slice_count,
    step_count,
    ao_intensity,
    gi_intensity,
    radius,
    use_screen_space_sampling,
    exp_factor,
    thickness,
    use_linear_thickness,
    backface_lighting,
    use_temporal_filtering: true,
    _resolution: resolution,
    _half_proj_scale: half_proj_scale,
    _temporal_direction: temporal_direction,
    _temporal_offset: temporal_offset,
    _resolution_scale: resolution_scale,
    _camera_projection_matrix: camera_projection_matrix,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _camera_near: camera_near,
    _camera_far: camera_far,
    _camera: camera,
    _ssgi_render_target: ssgi_render_target,
    _material: material,
    _ao_node: node,
    _gi_node: node,
  }
  payload._ao_node = @nodes.pass_texture(node, ssgi_render_target.textures[0])
  payload._gi_node = @nodes.pass_texture(node, ssgi_render_target.textures[1])
  node.set_class(payload)
}

///|
pub fn SSGINode::of(node : @nodes.Node) -> SSGINode? {
  addon_class_of(node, "SSGINode")
}

///|
/// `ssgi( beautyNode, depthNode, normalNode, camera )`.
pub fn ssgi(
  beauty_node : @nodes.Node,
  depth_node : @nodes.Node,
  normal_node : @nodes.Node?,
  camera : @core.Object3D,
) -> @nodes.Node {
  SSGINode::new(
    @nodes.convert_to_texture(beauty_node),
    depth_node,
    normal_node,
    camera,
  )
}
