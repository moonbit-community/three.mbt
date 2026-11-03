// nodes/functions/BSDF/BRDF_Sheen.js

///|
/// `D_Charlie( { roughness, dotNH } )` (Estevez and Kulla 2017).
let brdf_sheen_d_charlie : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_Sheen.js:D_Charlie",
  fn() {
    fn_(
      fn(inputs, _) {
        let roughness = inputs.named("roughness").unwrap()
        let dot_nh = inputs.named("dotNH").unwrap()
        let alpha = roughness.pow2()
        let inv_alpha = float(1.0).div(alpha)
        let cos2h = dot_nh.pow2()
        let sin2h = cos2h.one_minus().max(0.0078125)
        Some(
          float(2.0)
          .add(inv_alpha)
          .mul(sin2h.pow(inv_alpha.mul(0.5)))
          .div(2.0 * bsdf_pi),
        )
      },
      layout=FnLayout::short(
        [("roughness", "float"), ("dotNH", "float")],
        return_="float",
        upstream="nodes/functions/BSDF/BRDF_Sheen.js:D_Charlie",
      ),
    )
  },
)

///|
/// `V_Neubelt( { dotNV, dotNL } )` (Neubelt and Pettineo 2013).
let brdf_sheen_v_neubelt : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_Sheen.js:V_Neubelt",
  fn() {
    fn_(
      fn(inputs, _) {
        let dot_nv = inputs.named("dotNV").unwrap()
        let dot_nl = inputs.named("dotNL").unwrap()
        Some(
          float(1.0)
          .div(float(4.0).mul(dot_nl.add(dot_nv).sub(dot_nl.mul(dot_nv))))
          .clamp(),
        )
      },
      layout=FnLayout::short(
        [("dotNV", "float"), ("dotNL", "float")],
        return_="float",
        upstream="nodes/functions/BSDF/BRDF_Sheen.js:V_Neubelt",
      ),
    )
  },
)

///|
/// `BRDF_Sheen( { lightDirection } )`.
pub let brdf_sheen : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_Sheen.js:BRDF_Sheen",
  fn() {
    fn_(fn(inputs, _) {
      let light_direction = inputs.named("lightDirection").unwrap()
      let half_dir = light_direction.add(position_view_direction).normalize()
      let dot_nl = normal_view.dot(light_direction).clamp()
      let dot_nv = normal_view.dot(position_view_direction).clamp()
      let dot_nh = normal_view.dot(half_dir).clamp()
      let d = brdf_sheen_d_charlie.call_named({
        "roughness": sheen_roughness,
        "dotNH": dot_nh,
      })
      let v = brdf_sheen_v_neubelt.call_named({
        "dotNV": dot_nv,
        "dotNL": dot_nl,
      })
      Some(sheen.mul(d).mul(v))
    })
  },
)
