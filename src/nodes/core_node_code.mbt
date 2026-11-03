// nodes/core/NodeCode.js

///|
pub(all) struct NodeCode {
  mut name : String
  mut type_ : String
  mut code : String
}

///|
pub fn NodeCode::new(
  name : String,
  type_ : String,
  code~ : String = "",
) -> NodeCode {
  { name, type_, code, }
}
