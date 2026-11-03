// nodes/core/NodeVar.js

///|
/// A variable declaration of a shader stage.
pub(all) struct NodeVar {
  mut name : String
  mut type_ : String
  mut read_only : Bool
  mut local_ : Bool
  mut count : Int32?
}

///|
pub fn NodeVar::new(
  name : String,
  type_ : String,
  read_only~ : Bool = false,
  count? : Int32,
  local_~ : Bool = false,
) -> NodeVar {
  { name, type_, read_only, local_, count, }
}
