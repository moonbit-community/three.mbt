// nodes/functions/BSDF/EnvironmentBRDF.js

///|
/// `EnvironmentBRDF( { dotNV, specularColor, specularF90, roughness } )`.
pub let environment_brdf : Node = module_nodes(
  "nodes/functions/BSDF/EnvironmentBRDF.js:EnvironmentBRDF",
  fn() {
    fn_(fn(inputs, _) {
      let dot_nv = inputs.named("dotNV").unwrap()
      let specular_color = inputs.named("specularColor").unwrap()
      let specular_f90 = inputs.named("specularF90").unwrap()
      let roughness = inputs.named("roughness").unwrap()
      let fab = dfglut.call_named({ "dotNV": dot_nv, "roughness": roughness })
      Some(specular_color.mul(fab.x()).add(specular_f90.mul(fab.y())))
    })
  },
)
