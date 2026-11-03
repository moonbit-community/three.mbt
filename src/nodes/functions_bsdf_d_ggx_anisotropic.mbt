// nodes/functions/BSDF/D_GGX_Anisotropic.js

///|
let d_ggx_anisotropic_reciprocal_pi : Node = module_nodes(
  "nodes/functions/BSDF/D_GGX_Anisotropic.js:RECIPROCAL_PI",
  fn() { float(1.0 / bsdf_pi) },
)

///|
/// `D_GGX_Anisotropic( { alphaT, alphaB, dotNH, dotTH, dotBH } )`.
pub let d_ggx_anisotropic : Node = module_nodes(
  "nodes/functions/BSDF/D_GGX_Anisotropic.js:D_GGX_Anisotropic",
  fn() {
    fn_(
      fn(inputs, _) {
        let alpha_t = inputs.named("alphaT").unwrap()
        let alpha_b = inputs.named("alphaB").unwrap()
        let dot_nh = inputs.named("dotNH").unwrap()
        let dot_th = inputs.named("dotTH").unwrap()
        let dot_bh = inputs.named("dotBH").unwrap()
        let a2 = alpha_t.mul(alpha_b)
        let v = vec3_of([
          alpha_b.mul(dot_th),
          alpha_t.mul(dot_bh),
          a2.mul(dot_nh),
        ])
        let v2 = v.dot(v)
        let w2 = a2.div(v2)
        Some(d_ggx_anisotropic_reciprocal_pi.mul(a2.mul(w2.pow2())))
      },
      layout=FnLayout::short(
        [
          ("alphaT", "float"),
          ("alphaB", "float"),
          ("dotNH", "float"),
          ("dotTH", "float"),
          ("dotBH", "float"),
        ],
        return_="float",
        upstream="nodes/functions/BSDF/D_GGX_Anisotropic.js:D_GGX_Anisotropic",
      ),
    )
  },
)
