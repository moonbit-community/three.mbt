// nodes/functions/BSDF/F_Schlick.js

///|
/// `F_Schlick( { f0, f90, dotVH } )`: Schlick's Fresnel approximation.
pub let f_schlick : Node = module_nodes(
  "nodes/functions/BSDF/F_Schlick.js:F_Schlick",
  fn() {
    fn_(fn(inputs, _) {
      let f0 = inputs.named("f0").unwrap()
      let f90 = inputs.named("f90").unwrap()
      let dot_vh = inputs.named("dotVH").unwrap()
      let fresnel = dot_vh.mul(-5.55473).sub(6.98316).mul(dot_vh).exp2()
      Some(f0.mul(fresnel.one_minus()).add(f90.mul(fresnel)))
    })
  },
)
