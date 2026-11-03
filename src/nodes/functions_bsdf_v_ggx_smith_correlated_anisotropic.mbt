// nodes/functions/BSDF/V_GGX_SmithCorrelated_Anisotropic.js

///|
/// `V_GGX_SmithCorrelated_Anisotropic( { alphaT, alphaB, dotTV, dotBV, dotTL, dotBL,
/// dotNV, dotNL } )`.
pub let v_ggx_smith_correlated_anisotropic : Node = module_nodes(
  "nodes/functions/BSDF/V_GGX_SmithCorrelated_Anisotropic.js:V_GGX_SmithCorrelated_Anisotropic",
  fn() {
    fn_(
      fn(inputs, _) {
        let alpha_t = inputs.named("alphaT").unwrap()
        let alpha_b = inputs.named("alphaB").unwrap()
        let dot_tv = inputs.named("dotTV").unwrap()
        let dot_bv = inputs.named("dotBV").unwrap()
        let dot_tl = inputs.named("dotTL").unwrap()
        let dot_bl = inputs.named("dotBL").unwrap()
        let dot_nv = inputs.named("dotNV").unwrap()
        let dot_nl = inputs.named("dotNL").unwrap()
        let gv = dot_nl.mul(
          vec3_of([alpha_t.mul(dot_tv), alpha_b.mul(dot_bv), dot_nv]).length(),
        )
        let gl = dot_nv.mul(
          vec3_of([alpha_t.mul(dot_tl), alpha_b.mul(dot_bl), dot_nl]).length(),
        )
        Some(div(0.5, gv.add(gl).max(epsilon)))
      },
      layout=FnLayout::short(
        [
          ("alphaT", "float"),
          ("alphaB", "float"),
          ("dotTV", "float"),
          ("dotBV", "float"),
          ("dotTL", "float"),
          ("dotBL", "float"),
          ("dotNV", "float"),
          ("dotNL", "float"),
        ],
        return_="float",
        upstream="nodes/functions/BSDF/V_GGX_SmithCorrelated_Anisotropic.js:V_GGX_SmithCorrelated_Anisotropic",
      ),
    )
  },
)
