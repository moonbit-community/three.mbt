// nodes/functions/BSDF/V_GGX_SmithCorrelated.js

///|
/// `V_GGX_SmithCorrelated( { alpha, dotNL, dotNV } )`.
pub let v_ggx_smith_correlated : Node = module_nodes(
  "nodes/functions/BSDF/V_GGX_SmithCorrelated.js:V_GGX_SmithCorrelated",
  fn() {
    fn_(
      fn(inputs, _) {
        let alpha = inputs.named("alpha").unwrap()
        let dot_nl = inputs.named("dotNL").unwrap()
        let dot_nv = inputs.named("dotNV").unwrap()
        let a2 = alpha.pow2()
        let gv = dot_nl.mul(a2.add(a2.one_minus().mul(dot_nv.pow2())).sqrt())
        let gl = dot_nv.mul(a2.add(a2.one_minus().mul(dot_nl.pow2())).sqrt())
        Some(div(0.5, gv.add(gl).max(epsilon)))
      },
      layout=FnLayout::short(
        [("alpha", "float"), ("dotNL", "float"), ("dotNV", "float")],
        return_="float",
        upstream="nodes/functions/BSDF/V_GGX_SmithCorrelated.js:V_GGX_SmithCorrelated",
      ),
    )
  },
)
