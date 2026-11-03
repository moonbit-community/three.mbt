// nodes/functions/material/getRoughness.js

///|
/// `getRoughness( { roughness } )`: the roughness clamped to a minimum, plus the
/// geometry roughness.
pub let get_roughness : Node = module_nodes(
  "nodes/functions/material/getRoughness.js:getRoughness",
  fn() {
    fn_(fn(inputs, _) {
      let roughness = inputs.named("roughness").unwrap()
      let geometry_roughness = get_geometry_roughness.call([])
      let mut roughness_factor = roughness.max(0.045)
      roughness_factor = roughness_factor.add(geometry_roughness)
      roughness_factor = roughness_factor.min(1.0)
      Some(roughness_factor)
    })
  },
)
