// nodes/functions/BSDF/D_GGX.js

///|
/// `D_GGX( { alpha, dotNH } )`: the GGX normal distribution.
pub let d_ggx : Node = module_nodes("nodes/functions/BSDF/D_GGX.js:D_GGX", fn() {
  fn_(
    fn(inputs, _) {
      let alpha = inputs.named("alpha").unwrap()
      let dot_nh = inputs.named("dotNH").unwrap()
      let a2 = alpha.pow2()
      let denom = dot_nh.pow2().mul(a2.one_minus()).one_minus()
      Some(a2.div(denom.pow2()).mul(1.0 / bsdf_pi))
    },
    layout=FnLayout::short(
      [("alpha", "float"), ("dotNH", "float")],
      return_="float",
      upstream="nodes/functions/BSDF/D_GGX.js:D_GGX",
    ),
  )
})
