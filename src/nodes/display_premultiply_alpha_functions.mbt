// nodes/display/PremultiplyAlphaFunctions.js

///|
/// `premultiplyAlpha( color )`: `rgb * a`.
pub let premultiply_alpha : Node = module_nodes(
  "nodes/display/PremultiplyAlphaFunctions.js:premultiplyAlpha",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        Some(vec4_of([color.rgb().mul(color.a()), color.a()]))
      },
      layout=FnLayout::short(
        [("color", "vec4")],
        return_="vec4",
        upstream="nodes/display/PremultiplyAlphaFunctions.js:premultiplyAlpha",
      ),
    )
  },
)

///|
/// `unpremultiplyAlpha( color )`: `rgb / a`, or 0 where `a` is 0.
pub let unpremultiply_alpha : Node = module_nodes(
  "nodes/display/PremultiplyAlphaFunctions.js:unpremultiplyAlpha",
  fn() {
    fn_(
      fn(inputs, _) {
        let color = inputs.get(0).unwrap()
        Some(
          color
          .a()
          .equal(0)
          .select(
            vec4(0),
            else_node=vec4_of([color.rgb().div(color.a()), color.a()]),
          ),
        )
      },
      layout=FnLayout::short(
        [("color", "vec4")],
        return_="vec4",
        upstream="nodes/display/PremultiplyAlphaFunctions.js:unpremultiplyAlpha",
      ),
    )
  },
)
