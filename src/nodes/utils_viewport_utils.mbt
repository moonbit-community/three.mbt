// nodes/utils/ViewportUtils.js: `viewportSafeUV`, a screen uv that avoids sampling in
// front of the fragment (for refraction-like effects).

///|
/// `viewportSafeUV( uv = null )`: `screenUV` where the depth at `uv` is in front of
/// the fragment, else `uv`.
pub let viewport_safe_uv : Node = module_nodes(
  "nodes/utils/ViewportUtils.js:viewportSafeUV",
  fn() {
    fn_(fn(inputs, _) {
      // `[ uv = null ]`
      let uv_node = inputs.get(0)
      let uv_arg : TslValue = match uv_node {
        Some(n) => Node(n)
        None => Null
      }
      let depth = linear_depth()
      let depth_diff = linear_depth(
        value_node=viewport_depth_texture(uv_node=uv_arg),
      ).sub(depth)
      let final_uv = depth_diff
        .less_than(0)
        .select(screen_uv, else_node?=uv_node.map(fn(n) -> &IntoTsl { n }))
      Some(final_uv)
    })
  },
)
