// nodes/core/NodeFunctionInput.js

///|
pub(all) struct NodeFunctionInput {
  mut type_ : String
  mut name : String
  mut count : Int32?
  /// `'in'`, `'out'`, `'inout'` or `''`.
  mut qualifier : String
  mut is_const : Bool
}

///|
pub fn NodeFunctionInput::new(
  type_ : String,
  name : String,
  count? : Int32,
  qualifier~ : String = "",
  is_const~ : Bool = false,
) -> NodeFunctionInput {
  { type_, name, count, qualifier, is_const, }
}
