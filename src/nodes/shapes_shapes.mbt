// nodes/shapes/Shapes.js: `shapeCircle`, a circle alpha mask (anti-aliased with
// alpha to coverage).

///|
/// `shapeCircle( coord = uv() )`.
pub let shape_circle : Node = module_nodes(
  "nodes/shapes/Shapes.js:shapeCircle",
  fn() {
    fn_(fn(inputs, builder) {
      let coord = inputs.get(0).unwrap_or_else(fn() { uv() })
      let renderer = builder.renderer
      let material = builder.material
      let len2 = length_sq(coord.mul(2).sub(1))
      let alpha_to_coverage = match material {
        Some(m) => m.alpha_to_coverage
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'alphaToCoverage')",
          )
      }
      let alpha = if alpha_to_coverage && renderer.current_samples() > 0 {
        let dlen = float(len2.fwidth()).to_var()
        smoothstep(dlen.one_minus(), dlen.add(1), len2).one_minus()
      } else {
        select(len2.greater_than(1.0), 0, else_node=1)
      }
      Some(alpha)
    })
  },
)
