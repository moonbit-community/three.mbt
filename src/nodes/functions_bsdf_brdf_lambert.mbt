// nodes/functions/BSDF/BRDF_Lambert.js

///|
/// `BRDF_Lambert( { diffuseColor } )`.
pub let brdf_lambert : Node = module_nodes(
  "nodes/functions/BSDF/BRDF_Lambert.js:BRDF_Lambert",
  fn() {
    fn_(fn(inputs, _) {
      Some(inputs.named("diffuseColor").unwrap().mul(1.0 / bsdf_pi))
    })
  },
)

///|
/// `Math.PI`.
let bsdf_pi : Double = 3.141592653589793
