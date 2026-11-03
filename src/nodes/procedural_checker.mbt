// nodes/procedural/Checker.js: a 2D checkerboard pattern.

///|
/// `checker( coord = uv() )`: `0` or `1` per checker cell.
pub let checker : Node = module_nodes("nodes/procedural/Checker.js:checker", fn() {
  fn_(
    fn(inputs, _) {
      let coord = inputs.get(0).unwrap_or_else(fn() { uv() })
      let uv_node = coord.mul(2.0)
      let cx = uv_node.x().floor()
      let cy = uv_node.y().floor()
      let result = cx.add(cy).mod(2.0)
      Some(result.sign())
    },
    layout=FnLayout::short(
      [("coord", "vec2")],
      return_="float",
      upstream="nodes/procedural/Checker.js:checker",
    ),
  )
})
