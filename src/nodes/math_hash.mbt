// nodes/math/Hash.js: `hash( seed )`, a PCG hash in [0, 1). TSL's `hash` is `hash_tsl`
// here: NodeUtils' `hash` has the name in this package.

///|
/// `hash( seed )`: a pseudo-random float in [0, 1) from a `uint` seed.
pub let hash_tsl : Node = module_nodes("nodes/math/Hash.js:hash", fn() {
  fn_(
    fn(inputs, _) {
      let seed = operator_node_input(inputs, 0)
      // Taken from https://www.shadertoy.com/view/XlGcRh, originally from pcg-random.org
      let state = seed.to_uint().mul(747796405).add(2891336453.0)
      let word = state
        .shift_right(state.shift_right(28).add(4))
        .bit_xor(state)
        .mul(277803737)
      let result = word.shift_right(22).bit_xor(word)
      Some(result.to_float().mul(1.0 / 4294967296.0)) // Convert to range [0, 1)
    },
    layout=FnLayout::short(
      [("seed", "uint")],
      return_="float",
      upstream="nodes/math/Hash.js:hash",
    ),
  )
})
