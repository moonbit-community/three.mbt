// nodes/utils/Remap.js: `remap` (a `Fn`) and `remapClamp`.

///|
/// `remap( node, inLowNode, inHighNode, outLowNode = float( 0 ), outHighNode =
/// float( 1 ), doClamp = bool( false ) )`: call it with `remap.call([...])`.
pub let remap : Node = module_nodes("nodes/utils/Remap.js:remap", fn() {
  fn_(fn(inputs, _) {
    let node = operator_node_input(inputs, 0)
    let in_low_node = operator_node_input(inputs, 1)
    let in_high_node = operator_node_input(inputs, 2)
    let out_low_node = inputs.get(3).unwrap_or_else(fn() { float(0) })
    let out_high_node = inputs.get(4).unwrap_or_else(fn() { float(1) })
    let do_clamp = inputs.get(5).unwrap_or_else(fn() { bool(false) })
    let mut t = node.sub(in_low_node).div(in_high_node.sub(in_low_node))
    if defined(Node(do_clamp)) {
      t = t.clamp()
    }
    Some(t.mul(out_high_node.sub(out_low_node)).add(out_low_node))
  })
})

///|
fn utils_remap_element(p : Array[TslValue]) -> Node {
  tsl_call(remap, p)
}

///|
fn utils_remap_clamp_element(p : Array[TslValue]) -> Node {
  let arg = fn(i : Int32) { p.get(i).unwrap_or(Undefined) }
  let out_low_node = match arg(3) {
    Undefined => TslValue::Node(float(0))
    v => v
  }
  let out_high_node = match arg(4) {
    Undefined => TslValue::Node(float(1))
    v => v
  }
  tsl_call(remap, [
    arg(0),
    arg(1),
    arg(2),
    out_low_node,
    out_high_node,
    Bool(true),
  ])
}

///|
/// The provided optional arguments, `undefined` for gaps before the last given one.
fn utils_remap_params(params : Array[&IntoTsl?]) -> Array[TslValue] {
  math_node_optional_params(params)
}

///|
/// `remapClamp( node, inLowNode, inHighNode, outLowNode = float( 0 ), outHighNode =
/// float( 1 ) )`.
pub fn remap_clamp(
  node : &IntoTsl,
  in_low_node : &IntoTsl,
  in_high_node : &IntoTsl,
  out_low_node? : &IntoTsl,
  out_high_node? : &IntoTsl,
) -> Node {
  utils_remap_clamp_element(
    utils_remap_params([
      Some(node),
      Some(in_low_node),
      Some(in_high_node),
      out_low_node,
      out_high_node,
    ]),
  )
}

///|
/// `node.remap( inLow, inHigh, outLow, outHigh, doClamp )`.
pub fn Node::remap(
  self : Node,
  in_low_node : &IntoTsl,
  in_high_node : &IntoTsl,
  out_low_node? : &IntoTsl,
  out_high_node? : &IntoTsl,
  do_clamp? : &IntoTsl,
) -> Node {
  self.chain(
    utils_remap_element,
    utils_remap_params([
      Some(in_low_node),
      Some(in_high_node),
      out_low_node,
      out_high_node,
      do_clamp,
    ]),
  )
}

///|
pub fn Node::remap_assign(
  self : Node,
  in_low_node : &IntoTsl,
  in_high_node : &IntoTsl,
  out_low_node? : &IntoTsl,
  out_high_node? : &IntoTsl,
  do_clamp? : &IntoTsl,
) -> Unit {
  self.chain_assign(
    utils_remap_element,
    utils_remap_params([
      Some(in_low_node),
      Some(in_high_node),
      out_low_node,
      out_high_node,
      do_clamp,
    ]),
  )
}

///|
/// `node.remapClamp( inLow, inHigh, outLow, outHigh )`.
pub fn Node::remap_clamp(
  self : Node,
  in_low_node : &IntoTsl,
  in_high_node : &IntoTsl,
  out_low_node? : &IntoTsl,
  out_high_node? : &IntoTsl,
) -> Node {
  self.chain(
    utils_remap_clamp_element,
    utils_remap_params([
      Some(in_low_node),
      Some(in_high_node),
      out_low_node,
      out_high_node,
    ]),
  )
}

///|
pub fn Node::remap_clamp_assign(
  self : Node,
  in_low_node : &IntoTsl,
  in_high_node : &IntoTsl,
  out_low_node? : &IntoTsl,
  out_high_node? : &IntoTsl,
) -> Unit {
  self.chain_assign(
    utils_remap_clamp_element,
    utils_remap_params([
      Some(in_low_node),
      Some(in_high_node),
      out_low_node,
      out_high_node,
    ]),
  )
}
