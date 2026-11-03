// nodes/functions/BSDF/BRDF_EON.js: Portsmouth et al. 2025, "EON: A Practical
// Energy-Preserving Rough Diffuse BRDF".

///|
let brdf_eon_epsilon : Double = 1.0e-7

///|
let brdf_eon_fon_a_coefficient : Double = 0.5 - 2.0 / (3.0 * bsdf_pi)

///|
let brdf_eon_fon_average_albedo_coefficient : Double = 2.0 / 3.0 -
  28.0 / (15.0 * bsdf_pi)

///|
/// `FON_DirectionalAlbedo( { mu, roughness, A } )`.
let brdf_eon_fon_directional_albedo : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_EON.js:FON_DirectionalAlbedo",
  fn() {
    fn_(
      fn(inputs, _) {
        let mu = inputs.named("mu").unwrap()
        let roughness = inputs.named("roughness").unwrap()
        let a = inputs.named("A").unwrap()
        let mu_comp = mu.one_minus()
        let g_over_pi = mu_comp.mul(
          mu_comp
          .mul(
            mu_comp
            .mul(mu_comp.mul(0.0714429953).sub(0.332181442))
            .add(0.491881867),
          )
          .add(0.0571085289),
        )
        Some(a.mul(roughness.mul(g_over_pi).add(1.0)))
      },
      layout=FnLayout::short(
        [("mu", "float"), ("roughness", "float"), ("A", "float")],
        return_="float",
        upstream="nodes/functions/BSDF/BRDF_EON.js:FON_DirectionalAlbedo",
      ),
    )
  },
)

///|
/// `BRDF_EON( { lightDirection, diffuseColor, roughness, normalView, viewDirection } )`.
pub let brdf_eon : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_EON.js:BRDF_EON",
  fn() {
    fn_(fn(inputs, _) {
      let light_direction = inputs.named("lightDirection").unwrap()
      let diffuse_color = inputs.named("diffuseColor").unwrap()
      let roughness = inputs.named("roughness").unwrap()
      let normal_view = inputs.named("normalView").or_else(fn() { normal_view })
      let view_direction = inputs
        .named("viewDirection")
        .or_else(fn() { position_view_direction })
      let rho = diffuse_color.clamp()
      let dot_nl = normal_view.dot(light_direction).clamp()
      let dot_nv = normal_view.dot(view_direction).clamp()
      let s = light_direction.dot(view_direction).sub(dot_nl.mul(dot_nv))
      let s_over_t = s
        .greater_than(0.0)
        .select(s.div(dot_nl.max(dot_nv).max(brdf_eon_epsilon)), else_node=s)
      let a = roughness.mul(brdf_eon_fon_a_coefficient).add(1.0).reciprocal()
      let single_scatter = rho.mul_of([
        1.0 / bsdf_pi,
        a,
        roughness.mul(s_over_t).add(1.0),
      ])
      let average_albedo = a.mul(
        roughness.mul(brdf_eon_fon_average_albedo_coefficient).add(1.0),
      )
      let albedo_v = brdf_eon_fon_directional_albedo.call_named({
        "mu": dot_nv,
        "roughness": roughness,
        "A": a,
      })
      let albedo_l = brdf_eon_fon_directional_albedo.call_named({
        "mu": dot_nl,
        "roughness": roughness,
        "A": a,
      })
      let rho_multi_scatter = rho
        .mul_of([rho, average_albedo])
        .div(
          rho.mul(average_albedo.one_minus()).one_minus().max(brdf_eon_epsilon),
        )
      let multi_scatter = rho_multi_scatter
        .mul_of([
          1.0 / bsdf_pi,
          albedo_v.one_minus().max(brdf_eon_epsilon),
          albedo_l.one_minus().max(brdf_eon_epsilon),
        ])
        .div(average_albedo.one_minus().max(brdf_eon_epsilon))
      let eon = single_scatter.add(multi_scatter)
      Some(
        roughness
        .less_than_equal(brdf_eon_epsilon)
        .select(rho.mul(1.0 / bsdf_pi), else_node=eon),
      )
    })
  },
)

///|
/// `EON_DirectionalAlbedo( { diffuseColor, roughness, dotNV } )`.
pub let eon_directional_albedo : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_EON.js:EON_DirectionalAlbedo",
  fn() {
    fn_(
      fn(inputs, _) {
        let diffuse_color = inputs.named("diffuseColor").unwrap()
        let roughness = inputs.named("roughness").unwrap()
        let dot_nv = inputs.named("dotNV").unwrap()
        let rho = diffuse_color.clamp()
        let a = roughness.mul(brdf_eon_fon_a_coefficient).add(1.0).reciprocal()
        let directional_albedo = brdf_eon_fon_directional_albedo.call_named({
          "mu": dot_nv.clamp(),
          "roughness": roughness,
          "A": a,
        })
        let average_albedo = a.mul(
          roughness.mul(brdf_eon_fon_average_albedo_coefficient).add(1.0),
        )
        let rho_multi_scatter = rho
          .mul_of([rho, average_albedo])
          .div(
            rho
            .mul(average_albedo.one_minus())
            .one_minus()
            .max(brdf_eon_epsilon),
          )
        let eon_albedo = rho
          .mul(directional_albedo)
          .add(rho_multi_scatter.mul(directional_albedo.one_minus()))
        Some(
          roughness
          .less_than_equal(brdf_eon_epsilon)
          .select(rho, else_node=eon_albedo),
        )
      },
      layout=FnLayout::short(
        [("diffuseColor", "vec3"), ("roughness", "float"), ("dotNV", "float")],
        return_="vec3",
        upstream="nodes/functions/BSDF/BRDF_EON.js:EON_DirectionalAlbedo",
      ),
    )
  },
)
