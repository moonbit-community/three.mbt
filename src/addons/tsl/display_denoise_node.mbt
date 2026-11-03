// examples/jsm/tsl/display/DenoiseNode.js

///|
extern "js" fn denoise_node_math_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn denoise_node_math_sin(x : Double) -> Double = "Math.sin"

///|
/// Post processing node for denoising data like raw screen-space ambient occlusion
/// output (a Poisson-disk-like filter guided by depth, normals and luma).
pub(all) struct DenoiseNode {
  /// The texture node that represents the input of the effect (e.g. AO).
  mut texture_node : @nodes.Node
  /// A node that represents the scene's depth.
  mut depth_node : @nodes.Node
  /// A node that represents the scene's normals (`None`: reconstructed from depth).
  mut normal_node : @nodes.Node?
  _noise_texture : @core.Texture
  /// The node that represents the noise texture.
  mut noise_node : @nodes.Node
  /// The luma Phi value.
  luma_phi : @nodes.Node
  /// The depth Phi value.
  depth_phi : @nodes.Node
  /// The normal Phi value.
  normal_phi : @nodes.Node
  /// The radius.
  radius : @nodes.Node
  /// The index.
  index : @nodes.Node
  _resolution : @nodes.Node
  _sample_vectors : @nodes.Node
  _camera_projection_matrix_inverse : @nodes.Node
}

///|
pub impl @nodes.NodeClass for DenoiseNode with fn class_name(_) {
  "DenoiseNode"
}

///|
pub impl @nodes.NodeClass for DenoiseNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "depthNode", Some(self.depth_node))
  @nodes.push_child(out, "normalNode", self.normal_node)
  @nodes.push_child(out, "noiseNode", Some(self.noise_node))
  @nodes.push_child(out, "lumaPhi", Some(self.luma_phi))
  @nodes.push_child(out, "depthPhi", Some(self.depth_phi))
  @nodes.push_child(out, "normalPhi", Some(self.normal_phi))
  @nodes.push_child(out, "radius", Some(self.radius))
  @nodes.push_child(out, "index", Some(self.index))
}

///|
pub impl @nodes.NodeClass for DenoiseNode with fn update_before(self, _, _) {
  let map = @nodes.TextureNode::get_value(self.texture_node)
  match @nodes.InputNode::get_value(self._resolution) {
    Vector2(v) => v.set(map.image().width(), map.image().height()) |> ignore
    _ => abort("uniform value is not a Vector2")
  }
  None
}

///|
pub impl @nodes.NodeClass for DenoiseNode with fn setup(self, _, _) {
  let uv_node = @nodes.uv()
  let sample_texture = fn(uv : @nodes.Node) { self.texture_node.sample(uv) }
  let sample_depth = fn(uv : @nodes.Node) { self.depth_node.sample(uv).x() }
  let sample_normal = fn(uv : @nodes.Node) {
    match self.normal_node {
      Some(normal_node) => normal_node.sample(uv).rgb().normalize()
      None =>
        @nodes.get_normal_from_depth.call([
          uv,
          @nodes.TslValue::Texture(
            @nodes.TextureNode::get_value(self.depth_node),
          ),
          self._camera_projection_matrix_inverse,
        ])
    }
  }
  let sample_noise = fn(uv : @nodes.Node) { self.noise_node.sample(uv) }
  let denoise_sample = @nodes.fn_(fn(inputs, _) {
    let center = addon_arg(inputs, 0)
    let view_normal = addon_arg(inputs, 1)
    let view_position = addon_arg(inputs, 2)
    let sample_uv = addon_arg(inputs, 3)
    let texel = sample_texture(sample_uv).to_var()
    let depth = sample_depth(sample_uv).to_var()
    let normal = sample_normal(sample_uv).to_var()
    let neighbor_color = texel.rgb()
    let view_pos = @nodes.get_view_position
      .call([sample_uv, depth, self._camera_projection_matrix_inverse])
      .to_var()
    let normal_diff = @nodes.dot(view_normal, normal).to_var()
    let normal_similarity = @nodes.pow(
      @nodes.max(normal_diff, 0),
      self.normal_phi,
    ).to_var()
    let luma_diff = @nodes.abs(
      @nodes.luminance(neighbor_color).sub(@nodes.luminance(center)),
    ).to_var()
    let luma_similarity = @nodes.max(
      @nodes.float(1.0).sub(luma_diff.div(self.luma_phi)),
      0,
    ).to_var()
    let depth_diff = @nodes.abs(
      @nodes.dot(view_position.sub(view_pos), view_normal),
    ).to_var()
    let depth_similarity = @nodes.max(
      @nodes.float(1.0).sub(depth_diff.div(self.depth_phi)),
      0,
    )
    let w = luma_similarity.mul(depth_similarity).mul(normal_similarity)
    Some(@nodes.vec4_of([neighbor_color.mul(w), w]))
  })
  let denoise = @nodes.fn_(fn(inputs, _) {
    let uv_node = addon_arg(inputs, 0)
    let depth = sample_depth(uv_node).to_var()
    let view_normal = sample_normal(uv_node).to_var()
    let texel = sample_texture(uv_node).to_var()
    let result = @nodes.property("vec4")
    @nodes.if_(
      @nodes.is_background_depth
      .call([depth])
      .or(@nodes.dot(view_normal, view_normal).equal(0.0)),
      fn() { result.assign(texel) },
    ).else_(fn() {
      let center = @nodes.vec3(texel.rgb())
      let view_position = @nodes.get_view_position
        .call([uv_node, depth, self._camera_projection_matrix_inverse])
        .to_const()
      let noise_resolution = @nodes.texture_size(self.noise_node, level_node=0)
      let mut noise_uv = @nodes.vec2_of([uv_node.x(), uv_node.y().one_minus()])
      noise_uv = noise_uv.mul(self._resolution.div(noise_resolution))
      let noise_texel = sample_noise(noise_uv).to_var()
      let x = @nodes.sin(
        noise_texel.element(self.index.mod(4).mul(2).mul(@nodes.pi)),
      )
      let y = @nodes.cos(
        noise_texel.element(self.index.mod(4).mul(2).mul(@nodes.pi)),
      )
      let noise_vec = @nodes.vec2_of([x, y])
      let rotation_matrix = @nodes.mat2_of([
        noise_vec.x(),
        noise_vec.y().negate(),
        noise_vec.x(),
        noise_vec.y(),
      ])
      let total_weight = @nodes.float(1.0).to_var()
      let denoised = @nodes.vec3(texel.rgb()).to_var()
      let start = @nodes.int(0)
      let end = @nodes.int(16)
      @nodes.loop_(
        [@nodes.loop_range(start~, end~, type_="int", condition="<")],
        fn(inputs) {
          let i = inputs.named("i").unwrap()
          let sample_dir = self._sample_vectors.element(i)
          let offset = rotation_matrix
            .mul(
              sample_dir
              .xy()
              .mul(
                @nodes.float(1.0).add(sample_dir.z().mul(self.radius.sub(1))),
              ),
            )
            .div(self._resolution)
          let sample_uv = uv_node.add(offset)
          let sample_result = denoise_sample.call([
            center, view_normal, view_position, sample_uv,
          ])
          denoised.add_assign(sample_result.xyz())
          total_weight.add_assign(sample_result.w())
        },
      )
      @nodes.if_(total_weight.greater_than(@nodes.float(0)), fn() {
        denoised.div_assign(total_weight)
      })
      |> ignore
      result.assign(@nodes.vec4_of([denoised, texel.a()]))
    })
    Some(result)
  }) // , { uv: 'vec2', return: 'vec4' }
  let output = @nodes.fn_(fn(_, _) { Some(denoise.call([uv_node])) })
  let output_node = output.call([])
  Some(output_node)
}

///|
pub impl @nodes.NodeClass for DenoiseNode with fn dispose(self, node) {
  node.dispose_base()
  self._noise_texture.dispose()
}

///|
fn denoise_node_generate_denoise_samples(
  num_samples : Int32,
  num_rings : Int32,
  radius_exponent : Double,
) -> Array[@math.Vector3] {
  let samples = []
  for i in 0..<num_samples {
    let angle = 2.0 *
      ADDON_PI *
      num_rings.to_double() *
      i.to_double() /
      num_samples.to_double()
    let radius = addon_js_pow(
      i.to_double() / (num_samples - 1).to_double(),
      radius_exponent,
    )
    samples.push(
      @math.Vector3::new(
        denoise_node_math_cos(angle),
        denoise_node_math_sin(angle),
        radius,
      ),
    )
  }
  samples
}

///|
fn denoise_node_generate_default_noise(size~ : Int32 = 64) -> @core.Texture {
  let simplex = @addon_math.SimplexNoise::new()
  let array_size = size * size * 4
  let data = @core.TypedArray::uint8(array_size)
  let s = size.to_double()
  for i in 0..<size {
    for j in 0..<size {
      let x = i.to_double()
      let y = j.to_double()
      data[(i * size + j) * 4] = (simplex.noise(x, y) * 0.5 + 0.5) * 255.0
      data[(i * size + j) * 4 + 1] = (simplex.noise(x + s, y) * 0.5 + 0.5) *
        255.0
      data[(i * size + j) * 4 + 2] = (simplex.noise(x, y + s) * 0.5 + 0.5) *
        255.0
      data[(i * size + j) * 4 + 3] = (simplex.noise(x + s, y + s) * 0.5 + 0.5) *
        255.0
    }
  }
  let noise_texture = @core.DataTexture::new(data~, width=size, height=size)
  noise_texture.wrap_s = @core.RepeatWrapping
  noise_texture.wrap_t = @core.RepeatWrapping
  noise_texture.set_needs_update(true)
  noise_texture
}

///|
/// `new DenoiseNode( textureNode, depthNode, normalNode, camera )`.
pub fn DenoiseNode::new(
  texture_node : @nodes.Node,
  depth_node : @nodes.Node,
  normal_node : @nodes.Node?,
  camera : @core.Object3D,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let noise_texture = denoise_node_generate_default_noise()
  let noise_node = @nodes.texture(noise_texture)
  let luma_phi = @nodes.uniform(5)
  let depth_phi = @nodes.uniform(5)
  let normal_phi = @nodes.uniform(5)
  let radius = @nodes.uniform(5)
  let index = @nodes.uniform(0)
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let resolution = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  let sample_vectors = @nodes.uniform_array(
    denoise_node_generate_denoise_samples(16, 2, 1).map(fn(v) {
      @nodes.TslValue::Vector3(v)
    }),
  )
  let camera_projection_matrix_inverse = @nodes.uniform(
    camera.projection_matrix_inverse(),
  )
  node.set_class(DenoiseNode::{
    texture_node,
    depth_node,
    normal_node,
    _noise_texture: noise_texture,
    noise_node,
    luma_phi,
    depth_phi,
    normal_phi,
    radius,
    index,
    _resolution: resolution,
    _sample_vectors: sample_vectors,
    _camera_projection_matrix_inverse: camera_projection_matrix_inverse,
  })
}

///|
pub fn DenoiseNode::of(node : @nodes.Node) -> DenoiseNode? {
  addon_class_of(node, "DenoiseNode")
}

///|
/// `denoise( node, depthNode, normalNode, camera )` (`normal_node = None` reconstructs
/// normals from depth, upstream's `null`).
pub fn denoise(
  node : @nodes.Node,
  depth_node : &@nodes.IntoTsl,
  normal_node : @nodes.Node?,
  camera : @core.Object3D,
) -> @nodes.Node {
  DenoiseNode::new(
    @nodes.convert_to_texture(node),
    addon_node_object(depth_node),
    normal_node,
    camera,
  )
}
