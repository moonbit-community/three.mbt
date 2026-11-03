///|
trait Class {
  check(Self, Node) -> Bool
}

///|
struct Special {}

///|
impl Class for Special with check(_, n) {
  physical_equal(n, special)
}

///|
struct Node {
  kind : String?
  class_ : &Class
}

///|
fn alloc(kind? : String) -> Node {
  { kind, class_: Special::{  } }
}

///|
/// The literal passed to the optional argument is hoisted into a constant in release.
fn make() -> Node {
  alloc(kind="float")
}
