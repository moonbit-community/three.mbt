// nodes/utils/UVUtils.js: `replaceDefaultUV`, `rotateUV`, `spherizeUV`.

///|
/// `context.getUV( textureNode, builder )`: the uv a texture node uses when it has
/// none, as `ContextValue::Other` (read with `NodeContext::get_uv`).
pub(all) struct ContextGetUV {
  f : (Node, NodeBuilder) -> Node
}

///|
/// `builder.context.getUV`, if set.
pub fn NodeContext::get_uv(self : NodeContext) -> ContextGetUV? {
  match self.get("getUV") {
    Other(_) as v => v.cast()
    _ => None
  }
}

///|
/// `replaceDefaultUV( callback, node = null )`: a context whose `getUV` returns the
/// node `callback` gives for a texture node.
pub fn replace_default_uv(
  callback : (Node, NodeBuilder) -> Node,
  node? : Node,
) -> Node {
  let get_uv = ContextGetUV::{ f: callback, }
  context(
    node?,
    value=node_context([("getUV", Other(@core.JsValue::of(get_uv)))]),
  )
}

///|
/// `replaceDefaultUV( uvNode, node = null )`: a context whose `getUV` is `uvNode`.
pub fn replace_default_uv_node(uv_node : Node, node? : Node) -> Node {
  replace_default_uv(fn(_, _) { uv_node }, node?)
}

///|
/// `rotateUV( uv, rotation, center = vec2( 0.5 ) )`.
pub let rotate_uv : Node = module_nodes("nodes/utils/UVUtils.js:rotateUV", fn() {
  fn_(
    fn(inputs, _) {
      let uv = operator_node_input(inputs, 0)
      let rotation = operator_node_input(inputs, 1)
      let center = inputs.get(2).unwrap_or_else(fn() { vec2(0.5) })
      Some(rotate(uv.sub(center), rotation).add(center))
    },
    layout=FnLayout::short(
      [("uv", "vec2"), ("rotation", "float"), ("center", "vec2")],
      return_="vec2",
      upstream="nodes/utils/UVUtils.js:rotateUV",
    ),
  )
})

///|
/// `spherizeUV( uv, strength, center = vec2( 0.5 ) )`.
pub let spherize_uv : Node = module_nodes("nodes/utils/UVUtils.js:spherizeUV", fn() {
  fn_(
    fn(inputs, _) {
      let uv = operator_node_input(inputs, 0)
      let strength = operator_node_input(inputs, 1)
      let center = inputs.get(2).unwrap_or_else(fn() { vec2(0.5) })
      let delta = uv.sub(center)
      let delta2 = delta.dot(delta)
      let delta4 = delta2.mul(delta2)
      let delta_offset = delta4.mul(strength)
      Some(uv.add(delta.mul(delta_offset)))
    },
    layout=FnLayout::short(
      [("uv", "vec2"), ("strength", "float"), ("center", "vec2")],
      return_="vec2",
      upstream="nodes/utils/UVUtils.js:spherizeUV",
    ),
  )
})
