// nodes/pmrem/PMREMUtils.js: the PMREM generator's blur and GGX convolution shaders.

///|
let pmrem_utils_golden_angle : Double = 2.399963229728653

///|
/// `roughnessToMip( roughness, maxLod )`.
pub fn roughness_to_mip(roughness : &IntoTsl, max_lod : &IntoTsl) -> Node {
  let roughness = float(roughness).clamp()
  float(max_lod).mul(roughness).mul(float(2.0).sub(roughness))
}

///|
/// `sphericalGaussianBlur( { SAMPLES, sigma, direction, envMap } )`.
pub let spherical_gaussian_blur : Node = module_nodes(
  "nodes/pmrem/PMREMUtils.js:sphericalGaussianBlur",
  fn() {
    fn_(fn(inputs, _) {
      let samples = inputs.named("SAMPLES").unwrap()
      let sigma = inputs.named("sigma").unwrap()
      let direction = inputs.named("direction").unwrap()
      let env_map = inputs.named("envMap").unwrap()
      let output_direction = vec3(direction).to_var()
      let up = select(
        abs(output_direction.z()).less_than(0.999),
        vec3_of([0.0, 0.0, 1.0]),
        else_node=vec3_of([1.0, 0.0, 0.0]),
      )
      let tangent = normalize(cross(up, output_direction)).to_var()
      let bitangent = cross(output_direction, tangent).to_var()
      let theta_max = min(sigma.mul(3.0), bsdf_pi)
      let truncation = exp(
          theta_max.mul(theta_max).mul(-0.5).div(sigma.mul(sigma)),
        )
        .one_minus()
        .to_var()
      let color = vec3(0.0).to_var()
      let accum_weight = float(0.0).to_var()
      loop_([loop_range(start=int(0), end=samples)], fn(inputs) {
        let i = inputs.named("i").unwrap()
        let stratum = float(i).add(0.5).div(float(samples))
        let theta = sigma
          .mul(sqrt(log(stratum.mul(truncation).one_minus()).mul(-2.0)))
          .to_var()
        let phi = float(i).mul(pmrem_utils_golden_angle).to_var()
        let offset = tangent.mul(cos(phi)).add(bitangent.mul(sin(phi)))
        let sample_direction = output_direction
          .mul(cos(theta))
          .add(offset.mul(sin(theta)))
        let weight = sin(theta).div(theta).to_var()
        color.add_assign(
          env_map.sample(sample_direction).level(0).rgb().mul(weight),
        )
        accum_weight.add_assign(weight)
      })
      Some(vec4_of([color.div(accum_weight), 1.0]))
    })
  },
)

///|
/// `radicalInverse_VdC( bits )`.
let pmrem_utils_radical_inverse_vd_c : Node = module_nodes(
  "nodes/pmrem/PMREMUtils.js:radicalInverse_VdC",
  fn() {
    fn_(fn(inputs, _) {
      let bits_immutable = inputs.get(0).unwrap()
      let bits = uint(bits_immutable).to_var()
      bits.assign(bits.shift_left(uint(16)).bit_or(bits.shift_right(uint(16))))
      bits.assign(
        bits
        .bit_and(uint(0x55555555))
        .shift_left(uint(1))
        .bit_or(bits.bit_and(uint(2863311530.0)).shift_right(uint(1))),
      )
      bits.assign(
        bits
        .bit_and(uint(0x33333333))
        .shift_left(uint(2))
        .bit_or(bits.bit_and(uint(3435973836.0)).shift_right(uint(2))),
      )
      bits.assign(
        bits
        .bit_and(uint(0x0F0F0F0F))
        .shift_left(uint(4))
        .bit_or(bits.bit_and(uint(4042322160.0)).shift_right(uint(4))),
      )
      bits.assign(
        bits
        .bit_and(uint(0x00FF00FF))
        .shift_left(uint(8))
        .bit_or(bits.bit_and(uint(4278255360.0)).shift_right(uint(8))),
      )
      Some(float(bits).mul(2.3283064365386963e-10))
    })
  },
)

///|
/// `hammersley( i, N )`.
let pmrem_utils_hammersley : Node = module_nodes(
  "nodes/pmrem/PMREMUtils.js:hammersley",
  fn() {
    fn_(fn(inputs, _) {
      let i = inputs.get(0).unwrap()
      let n = inputs.get(1).unwrap()
      Some(
        vec2_of([
          float(i).div(float(n)),
          pmrem_utils_radical_inverse_vd_c.call([i]),
        ]),
      )
    })
  },
)

///|
/// `ggxConvolution( { roughness, lodBias, envMap, direction, GGX_SAMPLES } )`: the
/// GGX-prefiltered environment for a roughness, by importance sampling.
pub let ggx_convolution : Node = module_nodes(
  "nodes/pmrem/PMREMUtils.js:ggxConvolution",
  fn() {
    fn_(fn(inputs, _) {
      let roughness = inputs.named("roughness").unwrap()
      let lod_bias = inputs.named("lodBias").unwrap()
      let env_map = inputs.named("envMap").unwrap()
      let direction = inputs.named("direction").unwrap()
      let ggx_samples = inputs.named("GGX_SAMPLES").unwrap()
      let n = vec3(direction).to_var()
      let prefiltered_color = vec3(0.0).to_var()
      if_(roughness.less_than(0.001), fn() {
        prefiltered_color.assign(env_map.sample(n).level(0).rgb())
      }).else_(fn() {
        let alpha = roughness.mul(roughness).to_const()
        let alpha2 = alpha.mul(alpha).to_const()
        let up = select(
          abs(n.z()).less_than(0.999),
          vec3_of([0.0, 0.0, 1.0]),
          else_node=vec3_of([1.0, 0.0, 0.0]),
        )
        let tangent = normalize(cross(up, n)).to_var()
        let bitangent = cross(n, tangent).to_var()
        let total_weight = float(0.0).to_var()
        loop_([loop_range(start=uint(0), end=ggx_samples)], fn(inputs) {
          let i = inputs.named("i").unwrap()
          let xi = pmrem_utils_hammersley.call([i, ggx_samples])
          let inv_q = float(1.0)
            .div(xi.x().one_minus().add(alpha2.mul(xi.x())))
            .to_const()
          let n_dot_l = xi
            .x()
            .one_minus()
            .sub(alpha2.mul(xi.x()))
            .mul(inv_q)
            .to_const()
          if_(n_dot_l.greater_than(0.0), fn() {
            let phi = xi.y().mul(2.0 * bsdf_pi).to_const()
            let sin_theta = alpha
              .mul(2.0)
              .mul(sqrt(xi.x().mul(xi.x().one_minus())))
              .mul(inv_q)
              .to_const()
            let l = n
              .mul(n_dot_l)
              .add(
                tangent
                .mul(cos(phi))
                .add(bitangent.mul(sin(phi)))
                .mul(sin_theta),
              )
              .to_const()
            let d = alpha2.mul(inv_q)
            let lod = max(log2(d).add(lod_bias), 0.0)
            prefiltered_color.add_assign(
              env_map.sample(l).level(lod).rgb().mul(n_dot_l),
            )
            total_weight.add_assign(n_dot_l)
          })
          |> ignore
        })
        prefiltered_color.div_assign(total_weight)
      })
      Some(vec4_of([prefiltered_color, 1.0]))
    })
  },
)

///|
/// `ggxIntegration( { roughness, sourceLod, sourceSize, envMap, direction } )`: the
/// GGX-prefiltered environment by integrating every texel of a small source face set.
pub let ggx_integration : Node = module_nodes(
  "nodes/pmrem/PMREMUtils.js:ggxIntegration",
  fn() {
    fn_(fn(inputs, _) {
      let roughness = inputs.named("roughness").unwrap()
      let source_lod = inputs.named("sourceLod").unwrap()
      let source_size = inputs.named("sourceSize").unwrap()
      let env_map = inputs.named("envMap").unwrap()
      let direction = inputs.named("direction").unwrap()
      let n = vec3(direction).to_var()
      let alpha = roughness.mul(roughness).to_const()
      let alpha2 = alpha.mul(alpha).to_const()
      let texel_size = float(2.0).div(float(source_size)).to_const()
      let prefiltered_color = vec3(0.0).to_var()
      let total_weight = float(0.0).to_var()
      loop_([loop_range(start=int(0), end=int(3), name="face")], fn(inputs) {
        let face = inputs.named("face").unwrap()
        loop_([loop_range(start=int(0), end=source_size, name="y")], fn(
          inputs,
        ) {
          let y = inputs.named("y").unwrap()
          loop_([loop_range(start=int(0), end=source_size, name="x")], fn(
            inputs,
          ) {
            let x = inputs.named("x").unwrap()
            let uv = vec2_of([x, y])
              .add(0.5)
              .mul(texel_size)
              .sub(1.0)
              .to_const()
            let texel_direction = select(
              face.equal(0),
              vec3_of([1.0, uv]),
              else_node=select(
                face.equal(1),
                vec3_of([uv.x(), 1.0, uv.y()]),
                else_node=vec3_of([uv, 1.0]),
              ),
            ).to_var()
            let inv_distance = inverse_sqrt(dot(uv, uv).add(1.0)).to_const()
            let n_dot_l = dot(n, texel_direction).to_var()
            texel_direction.mul_assign(
              select(n_dot_l.less_than(0.0), -1.0, else_node=1.0),
            )
            n_dot_l.assign(abs(n_dot_l).mul(inv_distance))
            let d = alpha2.add(1.0).add(alpha2.sub(1.0).mul(n_dot_l))
            let weight = n_dot_l
              .mul(inv_distance)
              .mul(inv_distance)
              .mul(inv_distance)
              .div(d.mul(d))
              .to_const()
            prefiltered_color.add_assign(
              env_map
              .sample(texel_direction)
              .level(source_lod)
              .rgb()
              .mul(weight),
            )
            total_weight.add_assign(weight)
          })
        })
      })
      Some(vec4_of([prefiltered_color.div(total_weight), 1.0]))
    })
  },
)
