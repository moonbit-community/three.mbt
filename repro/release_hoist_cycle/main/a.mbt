///|
/// `special` is built by `make`; its class's `check` (an impl reached through a trait
/// object) refers back to `special`.
let special : Node = make()

///|
fn main {
  println(special.kind.unwrap_or("none"))
}
