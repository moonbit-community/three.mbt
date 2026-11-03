// examples/jsm/tsl/display/ImportanceSampledEnvironment.js

///|
/// Evaluates ImportanceSampledEnvironment.js (it imports SpecularHelpers.js), as `import`
/// does.
pub fn load_display_importance_sampled_environment() -> Unit {
  load_utils_specular_helpers()
}

///|
fn importance_sampled_environment_color_to_luminance(
  r : Double,
  g : Double,
  b : Double,
) -> Double {
  0.2126 * r + 0.7152 * g + 0.0722 * b
}

///|
fn importance_sampled_environment_binary_search(
  array : @core.TypedArray,
  target_value : Double,
  offset~ : Int32 = 0,
  count? : Int32,
) -> Int32 {
  let count = count.unwrap_or(array.length())
  let mut lower = offset
  let mut upper = offset + count - 1
  while lower < upper {
    let mid = (lower + upper) >> 1
    if array.get(mid) < target_value {
      lower = mid + 1
    } else {
      upper = mid
    }
  }
  lower - offset
}

///|
fn importance_sampled_environment_image(map : @core.Texture) -> @core.DataImage {
  match map.image() {
    DataImage(image) => image
    _ => abort("ImportanceSampledEnvironment: the environment map has no data")
  }
}

///|
/// `preprocessEnvMap( envMap )`: a half-float, unflipped copy of the map.
fn importance_sampled_environment_preprocess_env_map(
  env_map : @core.Texture,
) -> @core.Texture {
  let map = env_map.clone()
  let image = importance_sampled_environment_image(map)
  map.source = @core.TextureSource::new(
    data=DataImage({
      data: image.data,
      width: image.width,
      height: image.height,
      depth: image.depth,
      mipmaps: image.mipmaps,
    }),
  )
  let image = importance_sampled_environment_image(map)
  let width = image.width
  let height = image.height
  let data = image.data.unwrap()
  let mut new_data = data
  if map.type_ != @core.HalfFloatType {
    new_data = @core.TypedArray::uint16(data.length())
    let max_int_value = match data.kind() {
      Int8Array | Int16Array | Int32Array =>
        addon_js_pow(2.0, (8 * data.bytes_per_element() - 1).to_double()) - 1.0
      _ => addon_js_pow(2.0, (8 * data.bytes_per_element()).to_double()) - 1.0
    }
    for i in 0..<data.length() {
      let mut v = data.get(i)
      if map.type_ == @core.HalfFloatType {
        v = @core.from_half_float(data.get(i))
      }
      if map.type_ != @core.FloatType && map.type_ != @core.HalfFloatType {
        v /= max_int_value
      }
      new_data.set(i, @core.to_half_float(v))
    }
    image.data = Some(new_data)
    map.type_ = @core.HalfFloatType
  }
  if map.flip_y {
    let og_data = new_data
    new_data = new_data.slice()
    for y in 0..<height {
      for x in 0..<width {
        let new_y = height - y - 1
        let og_index = 4 * (y * width + x)
        let new_index = 4 * (new_y * width + x)
        new_data.set(new_index + 0, og_data.get(og_index + 0))
        new_data.set(new_index + 1, og_data.get(og_index + 1))
        new_data.set(new_index + 2, og_data.get(og_index + 2))
        new_data.set(new_index + 3, og_data.get(og_index + 3))
      }
    }
    map.flip_y = false
    image.data = Some(new_data)
  }
  map
}

///|
/// `EnvMapCDFGenerator`: the half-float map and its marginal / conditional inverse CDFs.
priv struct EnvMapCDFGenerator {
  mut map : @core.Texture?
  mut marginal_weights : @core.Texture?
  mut conditional_weights : @core.Texture?
  mut total_sum : Double
}

///|
fn EnvMapCDFGenerator::new() -> EnvMapCDFGenerator {
  {
    map: None,
    marginal_weights: None,
    conditional_weights: None,
    total_sum: 0.0,
  }
}

///|
fn importance_sampled_environment_weights_texture(
  data : @core.TypedArray,
  width : Int32,
  height : Int32,
) -> @core.Texture {
  let t = @core.DataTexture::new(data~, width~, height~)
  t.type_ = @core.HalfFloatType
  t.format = @core.RedFormat
  t.min_filter = @core.LinearFilter
  t.mag_filter = @core.LinearFilter
  t.wrap_s = @core.ClampToEdgeWrapping
  t.wrap_t = @core.ClampToEdgeWrapping
  t.generate_mipmaps = false
  t.set_needs_update(true)
  t
}

///|
fn EnvMapCDFGenerator::update_from(
  self : EnvMapCDFGenerator,
  hdr : @core.Texture,
) -> Unit {
  self.update_map_only(hdr)
  let image = importance_sampled_environment_image(self.map.unwrap())
  let width = image.width
  let height = image.height
  let data = image.data.unwrap()
  let pdf_conditional = @core.TypedArray::float32(width * height)
  let cdf_conditional = @core.TypedArray::float32(width * height)
  let pdf_marginal = @core.TypedArray::float32(height)
  let cdf_marginal = @core.TypedArray::float32(height)
  let mut total_sum_value = 0.0
  let mut cumulative_weight_marginal = 0.0
  for y in 0..<height {
    let mut cumulative_row_weight = 0.0
    for x in 0..<width {
      let i = y * width + x
      let r = @core.from_half_float(data.get(4 * i + 0))
      let g = @core.from_half_float(data.get(4 * i + 1))
      let b = @core.from_half_float(data.get(4 * i + 2))
      let weight = importance_sampled_environment_color_to_luminance(r, g, b)
      cumulative_row_weight += weight
      total_sum_value += weight
      pdf_conditional.set(i, weight)
      cdf_conditional.set(i, cumulative_row_weight)
    }
    if cumulative_row_weight != 0.0 {
      for i in (y * width)..<(y * width + width) {
        pdf_conditional.set(i, pdf_conditional.get(i) / cumulative_row_weight)
        cdf_conditional.set(i, cdf_conditional.get(i) / cumulative_row_weight)
      }
    }
    cumulative_weight_marginal += cumulative_row_weight
    pdf_marginal.set(y, cumulative_row_weight)
    cdf_marginal.set(y, cumulative_weight_marginal)
  }
  if cumulative_weight_marginal != 0.0 {
    for i in 0..<pdf_marginal.length() {
      pdf_marginal.set(i, pdf_marginal.get(i) / cumulative_weight_marginal)
      cdf_marginal.set(i, cdf_marginal.get(i) / cumulative_weight_marginal)
    }
  }
  let marginal_data_array = @core.TypedArray::uint16(height)
  let conditional_data_array = @core.TypedArray::uint16(width * height)
  for i in 0..<height {
    let dist = (i + 1).to_double() / height.to_double()
    let row = importance_sampled_environment_binary_search(cdf_marginal, dist)
    marginal_data_array.set(
      i,
      @core.to_half_float((row.to_double() + 0.5) / height.to_double()),
    )
  }
  for y in 0..<height {
    for x in 0..<width {
      let i = y * width + x
      let dist = (x + 1).to_double() / width.to_double()
      let col = importance_sampled_environment_binary_search(
        cdf_conditional,
        dist,
        offset=y * width,
        count=width,
      )
      conditional_data_array.set(
        i,
        @core.to_half_float((col.to_double() + 0.5) / width.to_double()),
      )
    }
  }
  if self.marginal_weights is Some(t) {
    t.dispose()
  }
  if self.conditional_weights is Some(t) {
    t.dispose()
  }
  self.marginal_weights = Some(
    importance_sampled_environment_weights_texture(
      marginal_data_array, height, 1,
    ),
  )
  self.conditional_weights = Some(
    importance_sampled_environment_weights_texture(
      conditional_data_array, width, height,
    ),
  )
  self.total_sum = total_sum_value
}

///|
fn EnvMapCDFGenerator::update_map_only(
  self : EnvMapCDFGenerator,
  hdr : @core.Texture,
) -> Unit {
  if self.map is Some(map) {
    map.dispose()
  }
  let map = importance_sampled_environment_preprocess_env_map(hdr)
  map.wrap_s = @core.RepeatWrapping
  map.wrap_t = @core.ClampToEdgeWrapping
  self.map = Some(map)
  self.total_sum = 0.0
}

///|
fn EnvMapCDFGenerator::dispose(self : EnvMapCDFGenerator) -> Unit {
  if self.marginal_weights is Some(t) {
    t.dispose()
    self.marginal_weights = None
  }
  if self.conditional_weights is Some(t) {
    t.dispose()
    self.conditional_weights = None
  }
  if self.map is Some(t) {
    t.dispose()
    self.map = None
  }
}

///|
/// An equirectangular environment for screen-space reflections: plain reflection lookups,
/// BRDF-weighted lookups, and multiple importance sampling of the BRDF and the map's
/// luminance CDF.
pub struct ImportanceSampledEnvironment {
  priv _importance_sampling : Bool
  priv mut _cdf : EnvMapCDFGenerator
  priv _total_sum : @nodes.Node
  priv _size : @nodes.Node
  /// `intensity`, a float uniform.
  intensity : @nodes.Node
  priv mut _map_node : @nodes.Node?
  priv mut _marginal_node : @nodes.Node?
  priv mut _conditional_node : @nodes.Node?
}

///|
/// `new ImportanceSampledEnvironment( importanceSampling = false )`.
pub fn ImportanceSampledEnvironment::new(
  importance_sampling~ : Bool = false,
) -> ImportanceSampledEnvironment {
  let cdf = EnvMapCDFGenerator::new()
  let total_sum = @nodes.uniform(0.0, type_="float")
  let size = @nodes.uniform(@math.Vector2::new(1.0, 1.0))
  let intensity = @nodes.uniform(1.0, type_="float")
  {
    _importance_sampling: importance_sampling,
    _cdf: cdf,
    _total_sum: total_sum,
    _size: size,
    intensity,
    _map_node: None,
    _marginal_node: None,
    _conditional_node: None,
  }
}

///|
fn ImportanceSampledEnvironment::size_value(
  self : ImportanceSampledEnvironment,
) -> @math.Vector2 {
  match @nodes.InputNode::get_value(self._size) {
    Vector2(v) => v
    _ => abort("ImportanceSampledEnvironment: _size")
  }
}

///|
/// `updateFrom( hdr )`: prepares the map (and its CDFs with importance sampling).
pub fn ImportanceSampledEnvironment::update_from(
  self : ImportanceSampledEnvironment,
  hdr : @core.Texture,
) -> Unit {
  if self._importance_sampling {
    self._cdf.update_from(hdr)
    @nodes.InputNode::set_value(self._total_sum, Number(self._cdf.total_sum))
  } else {
    self._cdf.update_map_only(hdr)
  }
  let image = importance_sampled_environment_image(self._cdf.map.unwrap())
  self.size_value().set(image.width.to_double(), image.height.to_double())
  |> ignore
  match self._map_node {
    None => {
      self._map_node = Some(@nodes.texture(self._cdf.map.unwrap()))
      if self._importance_sampling {
        self._marginal_node = Some(
          @nodes.texture(self._cdf.marginal_weights.unwrap()),
        )
        self._conditional_node = Some(
          @nodes.texture(self._cdf.conditional_weights.unwrap()),
        )
      }
    }
    Some(map_node) => {
      @nodes.InputNode::set_value(map_node, Texture(self._cdf.map.unwrap()))
      if self._importance_sampling {
        @nodes.InputNode::set_value(
          self._marginal_node.unwrap(),
          Texture(self._cdf.marginal_weights.unwrap()),
        )
        @nodes.InputNode::set_value(
          self._conditional_node.unwrap(),
          Texture(self._cdf.conditional_weights.unwrap()),
        )
      }
    }
  }
}

///|
/// `clear()`: disposes the textures and resets the state.
pub fn ImportanceSampledEnvironment::clear(
  self : ImportanceSampledEnvironment,
) -> Unit {
  self.dispose()
  self._cdf = EnvMapCDFGenerator::new()
  self._map_node = None
  self._marginal_node = None
  self._conditional_node = None
  @nodes.InputNode::set_value(self._total_sum, Number(0.0))
  self.size_value().set(1.0, 1.0) |> ignore
}

///|
fn ImportanceSampledEnvironment::map_node(
  self : ImportanceSampledEnvironment,
) -> @nodes.Node {
  match self._map_node {
    Some(n) => n
    None => abort("ImportanceSampledEnvironment: updateFrom() was not called")
  }
}

///|
/// `sampleReflect( { cameraWorldMatrix, viewReflectDir, sampleWeight = float( 1 ) } )`.
pub fn ImportanceSampledEnvironment::sample_reflect(
  self : ImportanceSampledEnvironment,
  camera_world_matrix~ : @nodes.Node,
  view_reflect_dir~ : @nodes.Node,
  sample_weight? : @nodes.Node,
) -> @nodes.Node {
  let sample_weight = match sample_weight {
    Some(w) => w
    None => @nodes.float(1)
  }
  let world_reflect_dir = camera_world_matrix
    .mul(@nodes.vec4_of([view_reflect_dir, @nodes.float(0)]))
    .xyz()
    .normalize()
  let env_uv = @nodes.equirect_uv.call([world_reflect_dir])
  @nodes.texture(self.map_node(), uv_node=env_uv)
  .level(0)
  .rgb()
  .mul(self.intensity)
  .mul(sample_weight)
}

///|
/// `sampleEnvironmentBRDF( { cameraWorldMatrix, viewReflectDir, N, V, alpha, f0, f90 =
/// float( 1 ) } )`.
pub fn ImportanceSampledEnvironment::sample_environment_brdf(
  self : ImportanceSampledEnvironment,
  camera_world_matrix~ : @nodes.Node,
  view_reflect_dir~ : @nodes.Node,
  n~ : @nodes.Node,
  v~ : @nodes.Node,
  alpha~ : @nodes.Node,
  f0~ : @nodes.Node,
  f90? : @nodes.Node,
) -> @nodes.Node {
  let f90 = match f90 {
    Some(f) => f
    None => @nodes.float(1)
  }
  let world_normal = camera_world_matrix
    .mul(@nodes.vec4_of([n, 0]))
    .xyz()
    .normalize()
    .to_var()
  let world_v = camera_world_matrix
    .mul(@nodes.vec4_of([v, 0]))
    .xyz()
    .normalize()
    .to_var()
  let n_dot_v = @nodes.max(@nodes.float(0), @nodes.dot(world_normal, world_v)).to_var()
  let l1 = camera_world_matrix
    .mul(@nodes.vec4_of([view_reflect_dir, @nodes.float(0)]))
    .xyz()
    .normalize()
    .to_var()
  let brdf_env_color = @nodes.texture(
      self.map_node(),
      uv_node=@nodes.equirect_uv.call([l1]),
    )
    .level(0)
    .rgb()
  let h1 = @nodes.normalize(world_v.add(l1)).to_var()
  let n_dot_l1 = @nodes.max(@nodes.float(0), @nodes.dot(world_normal, l1)).to_var()
  let v_dot_h1 = @nodes.max(@nodes.float(0), @nodes.dot(world_v, h1)).to_var()
  let w1 = f_schlick()
    .call([f0, v_dot_h1, f90])
    .mul(geometry_term().call([n_dot_l1, n_dot_v, alpha]))
    .div(smith_g().call([n_dot_v, alpha]).max(@nodes.float(1.0e-4)))
  brdf_env_color.mul(w1).mul(self.intensity)
}

///|
/// `sampleEnvironmentMIS( { cameraWorldMatrix, viewReflectDir, N, V, alpha, f0, f90 =
/// float( 1 ), Xi2 } )`: the BRDF lobe sample and an environment CDF sample, combined
/// with the power heuristic.
pub fn ImportanceSampledEnvironment::sample_environment_mis(
  self : ImportanceSampledEnvironment,
  camera_world_matrix~ : @nodes.Node,
  view_reflect_dir~ : @nodes.Node,
  n~ : @nodes.Node,
  v~ : @nodes.Node,
  alpha~ : @nodes.Node,
  f0~ : @nodes.Node,
  f90? : @nodes.Node,
  xi2~ : @nodes.Node,
) -> @nodes.Node {
  let f90 = match f90 {
    Some(f) => f
    None => @nodes.float(1)
  }
  let map_node = self.map_node()
  let marginal_node = self._marginal_node
  let conditional_node = self._conditional_node
  let total_sum = self._total_sum
  let env_w = self._size.x()
  let env_h = self._size.y()
  let env_map_intensity = self.intensity
  let world_normal = camera_world_matrix
    .mul(@nodes.vec4_of([n, 0]))
    .xyz()
    .normalize()
    .to_var()
  let world_v = camera_world_matrix
    .mul(@nodes.vec4_of([v, 0]))
    .xyz()
    .normalize()
    .to_var()
  let n_dot_v = @nodes.max(@nodes.float(0), @nodes.dot(world_normal, world_v)).to_var()
  let l1 = camera_world_matrix
    .mul(@nodes.vec4_of([view_reflect_dir, @nodes.float(0)]))
    .xyz()
    .normalize()
    .to_var()
  let brdf_env_color = @nodes.texture(
      map_node,
      uv_node=@nodes.equirect_uv.call([l1]),
    )
    .level(0)
    .rgb()
  let h1 = @nodes.normalize(world_v.add(l1)).to_var()
  let n_dot_l1 = @nodes.max(@nodes.float(0), @nodes.dot(world_normal, l1)).to_var()
  let n_dot_h1 = @nodes.max(@nodes.float(0), @nodes.dot(world_normal, h1)).to_var()
  let v_dot_h1 = @nodes.max(@nodes.float(0), @nodes.dot(world_v, h1)).to_var()
  let pdf_brdf1 = d_gtr()
    .call([alpha, n_dot_h1, @nodes.float(2)])
    .mul(smith_g().call([n_dot_v, alpha]))
    .div(@nodes.max(@nodes.float(1.0e-6), @nodes.float(4).mul(n_dot_v)))
    .max(@nodes.float(1.0e-8))
  let pdf_env1 = env_w
    .mul(env_h)
    .mul(@nodes.luminance(brdf_env_color).div(total_sum))
    .mul(equirect_dir_pdf().call([l1]))
    .max(@nodes.float(1.0e-8))
  let w1 = mis_power_heuristic().call([pdf_brdf1, pdf_env1])
  let big_w1 = f_schlick()
    .call([f0, v_dot_h1, f90])
    .mul(geometry_term().call([n_dot_l1, n_dot_v, alpha]))
    .div(smith_g().call([n_dot_v, alpha]).max(@nodes.float(1.0e-4)))
  let result = brdf_env_color.mul(big_w1).mul(w1).to_var()
  @nodes.if_(alpha.greater_than(0.01), fn() {
    let r_env = @nodes.vec2_of([xi2.z(), xi2.w()])
    let v_cdf = @nodes.texture(
      marginal_node,
      uv_node=@nodes.vec2_of([r_env.x(), @nodes.float(0)]),
    ).r()
    let u_cdf = @nodes.texture(
      conditional_node,
      uv_node=@nodes.vec2_of([r_env.y(), v_cdf]),
    ).r()
    let is_env_uv = @nodes.vec2_of([u_cdf, v_cdf])
    let env_dir_ws = @nodes.equirect_uv.call([is_env_uv])
    let env_half = @nodes.normalize(world_v.add(env_dir_ws))
    let env_n_dot_l = @nodes.max(
      @nodes.float(0),
      @nodes.dot(world_normal, env_dir_ws),
    )
    let env_n_dot_h = @nodes.max(
      @nodes.float(0),
      @nodes.dot(world_normal, env_half),
    )
    let env_v_dot_h = @nodes.max(@nodes.float(0), @nodes.dot(world_v, env_half))
    @nodes.if_(env_n_dot_l.greater_than(0.001), fn() {
      let d = d_gtr().call([alpha, env_n_dot_h, @nodes.float(2)]).to_var()
      let sampled_color = @nodes.texture(map_node, uv_node=is_env_uv)
        .level(0)
        .rgb()
      let pdf_env2 = env_w
        .mul(env_h)
        .mul(@nodes.luminance(sampled_color).div(total_sum))
        .mul(equirect_dir_pdf().call([env_dir_ws]))
        .max(@nodes.float(1.0e-8))
      let pdf_brdf2 = d
        .mul(smith_g().call([n_dot_v, alpha]))
        .div(@nodes.max(@nodes.float(1.0e-6), @nodes.float(4).mul(n_dot_v)))
        .max(@nodes.float(1.0e-8))
      let w2 = mis_power_heuristic().call([pdf_env2, pdf_brdf2])
      let env_brdf_spec = d
        .mul(geometry_term().call([env_n_dot_l, n_dot_v, alpha]))
        .div(
          @nodes.max(
            @nodes.float(1.0e-6),
            @nodes.float(4).mul(env_n_dot_l).mul(n_dot_v),
          ),
        )
      let env_fresnel_weight = f_schlick().call([f0, env_v_dot_h, f90]) // vec3 — chromatic metal tint
      result.add_assign(
        sampled_color
        .mul(env_brdf_spec)
        .mul(env_fresnel_weight)
        .mul(env_n_dot_l)
        .div(pdf_env2)
        .mul(w2),
      )
    })
    |> ignore
  })
  |> ignore
  result.mul(env_map_intensity)
}

///|
/// `dispose()`.
pub fn ImportanceSampledEnvironment::dispose(
  self : ImportanceSampledEnvironment,
) -> Unit {
  self._cdf.dispose()
}
