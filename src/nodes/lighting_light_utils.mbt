// nodes/lighting/LightUtils.js

///|
/// `getDistanceAttenuation( { lightDistance, cutoffDistance, decayExponent } )`
/// (Frostbite 3, "Moving to Physically-based Rendering", equation 26).
pub let get_distance_attenuation : Node = module_nodes(
  "nodes/lighting/LightUtils.js:getDistanceAttenuation",
  fn() {
    fn_(
      fn(inputs, _) {
        let light_distance = inputs.named("lightDistance").unwrap()
        let cutoff_distance = inputs.named("cutoffDistance").unwrap()
        let decay_exponent = inputs.named("decayExponent").unwrap()
        let distance_falloff = light_distance
          .pow(decay_exponent)
          .max(0.01)
          .reciprocal()
        Some(
          cutoff_distance
          .greater_than(0)
          .select(
            distance_falloff.mul(
              light_distance
              .div(cutoff_distance)
              .pow4()
              .one_minus()
              .clamp()
              .pow2(),
            ),
            else_node=distance_falloff,
          ),
        )
      },
      layout=FnLayout::short(
        [
          ("lightDistance", "float"),
          ("cutoffDistance", "float"),
          ("decayExponent", "float"),
        ],
        return_="float",
        upstream="nodes/lighting/LightUtils.js:getDistanceAttenuation",
      ),
    )
  },
)
