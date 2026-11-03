// examples/jsm/tsl/display/GTAONode.js

///|
/// The module-level state of GTAONode.js (`_quadMesh`, `_size`, `_rendererState`).
priv struct GTAONodeModule {
  quad_mesh : @nodes.QuadMesh
  size : @math.Vector2
  mut renderer_state : @nodes.RendererState?
}

///|
let _gtao_node_module : AddonModule[GTAONodeModule] = AddonModule::new(fn() {
  {
    quad_mesh: @nodes.QuadMesh::new(),
    size: @math.Vector2::new(0.0, 0.0),
    renderer_state: None,
  }
})

///|
/// Evaluates GTAONode.js's module-level statements (as its ES `import` does).
pub fn load_display_gtao_node() -> Unit {
  _gtao_node_module.get() |> ignore
}

///|
// From Activision GTAO paper: https://www.activision.com/cdn/research/s2016_pbs_activision_occlusion.pptx
let _gtao_node_temporal_rotations : Array[Double] = [60, 300, 180, 240, 120, 0]

///|
let _gtao_node_spatial_offsets : Array[Double] = [0, 0.5, 0.25, 0.75]

///|
extern "js" fn gtao_node_math_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn gtao_node_math_ceil(x : Double) -> Double = "Math.ceil"

///|
extern "js" fn gtao_node_math_floor(x : Double) -> Double = "Math.floor"

///|
extern "js" fn gtao_node_math_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn gtao_node_math_sin(x : Double) -> Double = "Math.sin"

///|
/// Post processing node for ground truth ambient occlusion (GTAO): renders the AO of a
/// depth (and normal) buffer into a single-channel render target.
pub(all) struct GTAONode {
  mut depth_node : @nodes.Node
  mut normal_node : @nodes.Node?
  mut resolution_scale : Double
  _ao_render_target : @core.RenderTarget
  radius : @nodes.Node
  thickness : @nodes.Node
  distance_exponent : @nodes.Node
  distance_fall_off : @nodes.Node
  scale : @nodes.Node
  samples : @nodes.Node
  mut use_temporal_filtering : Bool
  _resolution : @nodes.Node
  _noise_texture : @core.Texture
  _noise_node : @nodes.Node
  _camera_projection_matrix : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
  _camera_near : @nodes.Node
  _camera_far : @nodes.Node
  _camera : @core.Object3D
  _temporal_direction : @nodes.Node
  _temporal_offset : @nodes.Node
  _resolution_scale : @nodes.Node
  mut _ao : @nodes.Node?
  mut _current_samples : Double
  mut _shared_context : @nodes.NodeContext?
  _material : @core.Material
  mut _texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for GTAONode with fn class_name(_) {
  "GTAONode"
}

///|
pub impl @nodes.NodeClass for GTAONode with fn children(self, _, out) {
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "normalNode", self.normal_node)
  @nodes.push_child(out, "radius", Some(self.radius))
  @nodes.push_child(out, "thickness", Some(self.thickness))
  @nodes.push_child(out, "distanceExponent", Some(self.distance_exponent))
  @nodes.push_child(out, "distanceFallOff", Some(self.distance_fall_off))
  @nodes.push_child(out, "scale", Some(self.scale))
  @nodes.push_child(out, "samples", Some(self.samples))
}

///|
pub impl @nodes.NodeClass for GTAONode with fn set_size(self, _, width, height) {
  self.set_size(width, height)
  true
}

///|
/// `getTextureNode()`: the texture node holding the AO.
pub fn GTAONode::get_texture_node(self : GTAONode) -> @nodes.Node {
  self._texture_node
}

///|
/// `setSize( width, height )`.
pub fn GTAONode::set_size(
  self : GTAONode,
  width : Double,
  height : Double,
) -> Unit {
  let width = gtao_node_math_round(self.resolution_scale * width)
  let height = gtao_node_math_round(self.resolution_scale * height)
  a4_set_uniform_number(self._resolution_scale, self.resolution_scale)
  a4_uniform_vector2(self._resolution).set(width, height) |> ignore
  self._ao_render_target.set_size(width.to_int(), height.to_int())
}

///|
pub impl @nodes.NodeClass for GTAONode with fn update_before(self, _, frame) {
  let m = _gtao_node_module.get()
  let renderer = frame.renderer.unwrap()
  m.renderer_state = Some(
    @nodes.reset_renderer_state(renderer, state?=m.renderer_state),
  )
  // update temporal uniforms
  if self.use_temporal_filtering == true {
    let frame_id = frame.frame_id
    a4_set_uniform_number(
      self._temporal_direction,
      _gtao_node_temporal_rotations[frame_id % 6] / 360.0,
    )
    a4_set_uniform_number(
      self._temporal_offset,
      _gtao_node_spatial_offsets[frame_id % 4],
    )
  } else {
    a4_set_uniform_number(self._temporal_direction, 0)
    a4_set_uniform_number(self._temporal_offset, 1)
  }
  // rebuild the material if the sample count has changed
  if a4_uniform_number(self.samples) != self._current_samples {
    self._current_samples = a4_uniform_number(self.samples)
    let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
    node_material.context_node = Some(
      match self._shared_context {
        Some(c) => @nodes.context(value=c)
        None => @nodes.context()
      },
    )
    node_material.fragment_node = Some(self._ao.unwrap().call([]))
    self._material.set_needs_update(true)
  }
  //
  let size = renderer.get_drawing_buffer_size(m.size)
  self.set_size(size.x, size.y)
  m.quad_mesh.set_material(self._material)
  m.quad_mesh.object.name = "AO"
  // clear
  renderer.set_clear_color_hex(0xffffff, alpha=1)
  // ao
  renderer.set_render_target(Some(self._ao_render_target))
  m.quad_mesh.render(renderer)
  // restore
  @nodes.restore_renderer_state(renderer, m.renderer_state.unwrap())
  None
}

///|
pub impl @nodes.NodeClass for GTAONode with fn setup(self, _, builder) {
  let uv_node = @nodes.uv()
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
  let sample_noise = fn(uv : @nodes.Node) { self._noise_node.sample(uv) }
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
  let is_valid_sample = @nodes.fn_(
    fn(inputs, _) {
      let uv = inputs.get(0).unwrap()
      let center_texel = inputs.get(1).unwrap()
      let size = inputs.get(2).unwrap()
      let texel = uv.mul(size).floor().to_const()
      // rejects off-screen samples and samples that fall into the center texel
      Some(
        uv
        .x()
        .greater_than(0)
        .and_(uv.x().less_than(1))
        .and_(uv.y().greater_than(0))
        .and_(uv.y().less_than(1))
        .and_(
          texel
          .x()
          .not_equal(center_texel.x())
          .or(texel.y().not_equal(center_texel.y())),
        ),
      )
    },
    layout=@nodes.FnLayout::short(
      [("uv", "vec2"), ("centerTexel", "vec2"), ("size", "vec2")],
      return_="bool",
    ),
  )
  self._ao = Some(
    @nodes.fn_(fn(_, _) {
      let depth = self._resolution_scale
        .less_than(1)
        .select(sample_center_depth(uv_node), else_node=sample_depth(uv_node))
        .to_const()
      @nodes.is_background_depth.call([depth]).discard()
      let depth_size = @nodes.vec2(
        @nodes.texture_size(self.depth_node, level_node=0),
      ).to_const()
      let center_texel = uv_node.mul(depth_size).floor().to_const()
      let view_position = @nodes.get_view_position
        .call([uv_node, depth, self._camera_projection_matrix_inverse])
        .to_const()
      let view_normal = sample_normal(uv_node).to_const()
      let radius = self.radius
      let inv_radius = radius.reciprocal().to_const()
      let view_dir = if self._camera.is_perspective_camera() == true {
        @nodes.normalize(view_position.xyz().negate()).to_const()
      } else {
        @nodes.vec3_of([0, 0, 1]).to_const()
      }
      let clip_position = self._camera_projection_matrix
        .mul(@nodes.vec4_of([view_position, 1.0]))
        .to_const()
      let noise_resolution = @nodes.texture_size(self._noise_node, level_node=0)
      let mut noise_uv = @nodes.vec2_of([uv_node.x(), uv_node.y().one_minus()])
      noise_uv = noise_uv.mul(self._resolution.div(noise_resolution))
      let noise_texel = sample_noise(noise_uv)
      let random_vec = noise_texel.xyz().mul(2.0).sub(1.0)
      let tangent = @nodes.vec3_of([random_vec.xy(), 0.0]).normalize()
      let bitangent = @nodes.vec3_of([tangent.y().mul(-1.0), tangent.x(), 0.0])
      let kernel_matrix = @nodes.mat3_of([
        tangent,
        bitangent,
        @nodes.vec3_of([0.0, 0.0, 1.0]),
      ])
      // The sample count is baked into the shader so loop unrolling works
      let samples = a4_uniform_number(self.samples)
      let directions = if samples < 30 { 3.0 } else { 5.0 }
      let steps = gtao_node_math_ceil(samples / directions)
      let inv_steps = 1.0 / steps
      let ao = @nodes.float(0).to_var()
      // Each iteration analyzes one vertical "slice" of the 3D space around the fragment.
      // Per-step phase jitter for spatio-temporal decorrelation.
      let noise_jitter_idx = self._temporal_direction.mul(0.02)
      let step_jitter = @nodes.interleaved_gradient_noise
        .call([@nodes.screen_coordinate.add(self._temporal_offset)])
        .add(@nodes.rand.call([uv_node.add(noise_jitter_idx).mul(2).sub(1)]))
      @nodes.loop_(
        [
          @nodes.loop_range(
            start=@nodes.int(0),
            end=@nodes.int(directions),
            type_="int",
            condition="<",
          ),
        ],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let angle = @nodes.float(i)
            .div(directions)
            .mul(@nodes.pi)
            .add(self._temporal_direction)
            .to_const()
          let sample_dir = kernel_matrix
            .mul(@nodes.vec3_of([@nodes.cos(angle), @nodes.sin(angle), 0]))
            .to_const()
          let clip_dir_radius = self._camera_projection_matrix
            .mul(@nodes.vec4_of([sample_dir, 0.0]))
            .mul(radius)
            .to_const()
          let slice_bitangent = @nodes.normalize(
            @nodes.cross(sample_dir, view_dir),
          ).to_const()
          let slice_tangent = @nodes.cross(slice_bitangent, view_dir).to_const()
          // Project the view normal onto the slice plane (remove component along sliceBitangent).
          // The unnormalized length is the foreshortening weight applied at slice integration.
          // (Activision GTAO paper, Section 3.2 "Per-pixel sampling".)
          let proj_n_raw = view_normal
            .sub(slice_bitangent.mul(@nodes.dot(view_normal, slice_bitangent)))
            .to_const()
          let proj_n_len = proj_n_raw.length().to_const()
          let proj_n = proj_n_raw
            .div(@nodes.max(proj_n_len, @nodes.float(0.0001)))
            .to_const()
          // γ — angle of projN within the slice plane, signed by the tangent direction.
          let n_sin = @nodes.dot(proj_n, slice_tangent).to_const()
          let n_cos = @nodes.clamp(@nodes.dot(proj_n, view_dir), low=0, high=1).to_const()
          let sign_n_sin = n_sin
            .greater_than_equal(0)
            .select(@nodes.float(1), else_node=@nodes.float(-1))
          let angle_n = sign_n_sin.mul(@nodes.acos(n_cos)).to_const()
          let tangent_to_normal_in_slice = @nodes.cross(proj_n, slice_bitangent).to_const()
          let cos_horizon = @nodes.dot(view_dir, tangent_to_normal_in_slice).to_const()
          let cos_horizons = @nodes.vec2_of([cos_horizon, cos_horizon.negate()]).to_var()
          // For each slice, the inner loop performs ray marching to find the horizons.
          @nodes.loop_(
            [
              @nodes.loop_range(
                end=@nodes.int(steps),
                type_="int",
                name="j",
                condition="<",
              ),
            ],
            fn(inputs) {
              let j = inputs.named("j").unwrap()
              // Quadratic step distribution ( sampleDist = t² ) concentrates samples in the
              // near-field. (Blender's Eevee adaptation)
              let t = @nodes.float(j)
                .add(1.0)
                .add(step_jitter)
                .mul(inv_steps)
                .to_const()
              let sample_dist = t.mul(t)
              let clip_offset = clip_dir_radius.mul(sample_dist).to_const()
              // The loop marches in two opposite directions (x and y) along the slice's line to find the horizon on both sides.
              // x
              let sample_screen_position_x = @nodes.get_screen_position_from_clip
                .call([clip_position.add(clip_offset)])
                .to_const()
              let sample_depth_x = sample_depth(sample_screen_position_x).to_const()
              let sample_scene_view_position_x = @nodes.get_view_position
                .call([
                  sample_screen_position_x,
                  sample_depth_x,
                  self._camera_projection_matrix_inverse,
                ])
                .to_const()
              let view_delta_x = sample_scene_view_position_x
                .sub(view_position)
                .to_const()
              let len_x = view_delta_x.length().to_const()
              // Manual normalize guards against zero-length delta.
              let s_hx = @nodes.dot(view_dir, view_delta_x).div(
                @nodes.max(len_x, @nodes.float(0.0001)),
              )
              // Sphere falloff: ( dist / radius )² fades the sample's horizon contribution
              // back toward the prior horizon as it approaches the radius boundary.
              // (squared variant of the paper's near-field attenuation;
              // Activision GTAO paper, Section 4.3 "Bounding the sampling area")
              let dist_fac_x = @nodes.min(len_x.mul(inv_radius), 1)
              let dist_fac_sq_x = dist_fac_x.mul(dist_fac_x)
              @nodes.if_(
                is_valid_sample
                .call([sample_screen_position_x, center_texel, depth_size])
                .and_(@nodes.abs(view_delta_x.z()).less_than(self.thickness)),
                fn() {
                  cos_horizons
                  .x()
                  .assign(
                    @nodes.mix(
                      @nodes.max(cos_horizons.x(), s_hx),
                      cos_horizons.x(),
                      dist_fac_sq_x,
                    ),
                  )
                },
              )
              |> ignore
              // y
              let sample_screen_position_y = @nodes.get_screen_position_from_clip
                .call([clip_position.sub(clip_offset)])
                .to_const()
              let sample_depth_y = sample_depth(sample_screen_position_y).to_const()
              let sample_scene_view_position_y = @nodes.get_view_position
                .call([
                  sample_screen_position_y,
                  sample_depth_y,
                  self._camera_projection_matrix_inverse,
                ])
                .to_const()
              let view_delta_y = sample_scene_view_position_y
                .sub(view_position)
                .to_const()
              let len_y = view_delta_y.length().to_const()
              let s_hy = @nodes.dot(view_dir, view_delta_y).div(
                @nodes.max(len_y, @nodes.float(0.0001)),
              )
              let dist_fac_y = @nodes.min(len_y.mul(inv_radius), 1)
              let dist_fac_sq_y = dist_fac_y.mul(dist_fac_y)
              @nodes.if_(
                is_valid_sample
                .call([sample_screen_position_y, center_texel, depth_size])
                .and_(@nodes.abs(view_delta_y.z()).less_than(self.thickness)),
                fn() {
                  cos_horizons
                  .y()
                  .assign(
                    @nodes.mix(
                      @nodes.max(cos_horizons.y(), s_hy),
                      cos_horizons.y(),
                      dist_fac_sq_y,
                    ),
                  )
                },
              )
              |> ignore
            },
          )
          // Cosine-weighted inner integral, closed-form (Activision GTAO paper, Eq. 7).
          // Per horizon h_i:    term_i = −cos( 2 h_i − γ ) + cos( γ ) + 2 h_i sin( γ )
          // The 0.25 factor is ½ (integral normalization) × ½ (averaging the two horizons).
          //
          // In this slice setup `sliceTangent = cross( sliceBitangent, viewDir )` works out
          // opposite to `sampleDir`, so the +sampleDir samples (cosHorizons.x) live on the
          // −T side of the slice and −sampleDir samples (cosHorizons.y) on the +T side.
          // γ is signed by +T (sliceTangent), so hPos must read from cosHorizons.y.
          let h_pos = @nodes.acos(cos_horizons.y()).to_const()
          let h_neg = @nodes.acos(cos_horizons.x()).negate().to_const()
          let term_pos = @nodes.cos(h_pos.mul(2).sub(angle_n))
            .negate()
            .add(n_cos)
            .add(h_pos.mul(2).mul(n_sin))
          let term_neg = @nodes.cos(h_neg.mul(2).sub(angle_n))
            .negate()
            .add(n_cos)
            .add(h_neg.mul(2).mul(n_sin))
          let a = term_pos.add(term_neg).mul(0.25)
          // |projN| is the foreshortening weight from the per-slice normal projection.
          ao.add_assign(proj_n_len.mul(a))
        },
      )
      ao.assign(@nodes.clamp(ao.div(directions), low=0, high=1))
      ao.assign(@nodes.pow(ao, self.scale))
      Some(ao)
    }),
  )
  self._shared_context = Some(builder.get_shared_context())
  self._current_samples = a4_uniform_number(self.samples)
  let node_material = @nodes.NodeMaterial::of(self._material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(self._ao.unwrap().call([]))
  self._material.set_needs_update(true)
  //
  Some(self._texture_node)
}

///|
pub impl @nodes.NodeClass for GTAONode with fn dispose(self, node) {
  node.dispose_base()
  self._ao_render_target.dispose()
  self._noise_texture.dispose()
  self._material.dispose()
}

///|
/// `new GTAONode( depthNode, normalNode, camera )`; `normal_node` `None` is `null` (the
/// normals are reconstructed from the depth).
pub fn GTAONode::new(
  depth_node : @nodes.Node,
  normal_node : @nodes.Node?,
  camera : @core.Object3D,
) -> @nodes.Node {
  _gtao_node_module.get() |> ignore
  let node = @nodes.Node::alloc(node_type="float")
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let ao_render_target = @core.RenderTarget::new(
    width=1,
    height=1,
    depth_buffer=false,
    format=@core.RedFormat,
  )
  ao_render_target.texture().name = "GTAONode.AO"
  // uniforms
  let radius = @nodes.uniform(0.25)
  let thickness = @nodes.uniform(1)
  let distance_exponent = @nodes.uniform(1)
  let distance_fall_off = @nodes.uniform(1)
  let scale = @nodes.uniform(1)
  let samples = @nodes.uniform(16)
  let resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let noise_texture = gtao_node_generate_magic_square_noise()
  let noise_node = @nodes.texture(noise_texture)
  let camera_projection_matrix = @nodes.uniform(camera.projection_matrix())
  let camera_projection_matrix_inverse = @nodes.uniform(
    camera.projection_matrix_inverse(),
  )
  let camera_near = @nodes.reference("near", "float", object=Object3D(camera))
  let camera_far = @nodes.reference("far", "float", object=Object3D(camera))
  let temporal_direction = @nodes.uniform(0)
  let temporal_offset = @nodes.uniform(0)
  let resolution_scale = @nodes.uniform(0)
  let material = @nodes.NodeMaterial::new()
  material.name = "GTAO"
  let payload = GTAONode::{
    depth_node,
    normal_node,
    resolution_scale: 1.0,
    _ao_render_target: ao_render_target,
    radius,
    thickness,
    distance_exponent,
    distance_fall_off,
    scale,
    samples,
    use_temporal_filtering: false,
    _resolution: resolution,
    _noise_texture: noise_texture,
    _noise_node: noise_node,
    _camera_projection_matrix: camera_projection_matrix,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
    _camera_near: camera_near,
    _camera_far: camera_far,
    _camera: camera,
    _temporal_direction: temporal_direction,
    _temporal_offset: temporal_offset,
    _resolution_scale: resolution_scale,
    _ao: None,
    _current_samples: -1.0,
    _shared_context: None,
    _material: material,
    _texture_node: node,
  }
  payload._texture_node = @nodes.pass_texture(node, ao_render_target.texture())
  node.set_class(payload)
}

///|
pub fn GTAONode::of(node : @nodes.Node) -> GTAONode? {
  addon_class_of(node, "GTAONode")
}

///|
/// `generateMagicSquareNoise( size = 5 )`.
fn gtao_node_generate_magic_square_noise(size~ : Double = 5) -> @core.Texture {
  let noise_size = if gtao_node_math_floor(size) % 2 == 0 {
    gtao_node_math_floor(size) + 1
  } else {
    gtao_node_math_floor(size)
  }
  let magic_square = gtao_node_generate_magic_square(noise_size)
  let noise_square_size = magic_square.length()
  let data = @core.TypedArray::uint8(noise_square_size * 4)
  for inx in 0..<noise_square_size {
    let i_ang = magic_square[inx]
    let angle = 2.0 * ADDON_PI * i_ang / noise_square_size.to_double()
    let random_vec = @math.Vector3::new(
      gtao_node_math_cos(angle),
      gtao_node_math_sin(angle),
      0.0,
    ).normalize()
    data.set(inx * 4, (random_vec.x * 0.5 + 0.5) * 255.0)
    data.set(inx * 4 + 1, (random_vec.y * 0.5 + 0.5) * 255.0)
    data.set(inx * 4 + 2, 127)
    data.set(inx * 4 + 3, 255)
  }
  let noise_texture = @core.DataTexture::new(
    data~,
    width=noise_size.to_int(),
    height=noise_size.to_int(),
  )
  noise_texture.wrap_s = @core.RepeatWrapping
  noise_texture.wrap_t = @core.RepeatWrapping
  noise_texture.set_needs_update(true)
  noise_texture
}

///|
/// `generateMagicSquare( size )`.
fn gtao_node_generate_magic_square(size : Double) -> Array[Double] {
  let noise_size = (if gtao_node_math_floor(size) % 2 == 0 {
    gtao_node_math_floor(size) + 1
  } else {
    gtao_node_math_floor(size)
  }).to_int()
  let noise_square_size = noise_size * noise_size
  let magic_square = Array::make(noise_square_size, 0.0)
  let mut i = noise_size / 2
  let mut j = noise_size - 1
  let mut num = 1
  while num <= noise_square_size {
    if i == -1 && j == noise_size {
      j = noise_size - 2
      i = 0
    } else {
      if j == noise_size {
        j = 0
      }
      if i < 0 {
        i = noise_size - 1
      }
    }
    if magic_square[i * noise_size + j] != 0 {
      j -= 2
      i += 1
      continue
    } else {
      magic_square[i * noise_size + j] = num.to_double()
      num += 1
    }
    j += 1
    i -= 1
  }
  magic_square
}

///|
/// `ao( depthNode, normalNode, camera )`.
pub fn ao(
  depth_node : &@nodes.IntoTsl,
  normal_node : &@nodes.IntoTsl?,
  camera : @core.Object3D,
) -> @nodes.Node {
  GTAONode::new(
    @nodes.node_object(depth_node.to_tsl()),
    match normal_node {
      Some(n) => Some(@nodes.node_object(n.to_tsl()))
      None => None
    },
    camera,
  )
}
