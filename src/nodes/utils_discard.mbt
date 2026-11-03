// nodes/utils/Discard.js: `Discard( conditional )` and `Return()`, statements.

///|
fn utils_discard_element(p : Array[TslValue]) -> Node {
  let conditional = p.get(0).unwrap_or(Undefined)
  let node = if tsl_truthy(conditional) {
    select(conditional, expression("discard"))
  } else {
    expression("discard")
  }
  node.to_stack()
}

///|
/// `Discard( conditional )`: discards the fragment (when `conditional` holds).
pub fn discard(conditional? : &IntoTsl) -> Unit {
  match conditional {
    Some(c) => utils_discard_element([c.to_tsl()]) |> ignore
    None => utils_discard_element([]) |> ignore
  }
}

///|
/// `cond.discard()`.
pub fn Node::discard(self : Node) -> Unit {
  self.chain(utils_discard_element, []) |> ignore
}

///|
pub fn Node::discard_assign(self : Node) -> Unit {
  self.chain_assign(utils_discard_element, [])
}

///|
/// `Return()`.
pub fn return_() -> Unit {
  expression("return").to_stack() |> ignore
}
