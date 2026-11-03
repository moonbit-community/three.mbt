// nodes/core/NodeVarying.js. Upstream extends NodeVar; the fields are repeated here
// and `NodeVariable::Varying` tells them apart (`isNodeVarying`).

///|
pub(all) struct NodeVarying {
  mut name : String
  mut type_ : String
  mut read_only : Bool
  mut local_ : Bool
  mut count : Int32?
  mut needs_interpolation : Bool
  mut interpolation_type : String?
  mut interpolation_sampling : String?
}

///|
pub fn NodeVarying::new(
  name : String,
  type_ : String,
  interpolation_type? : String,
  interpolation_sampling? : String,
) -> NodeVarying {
  {
    name,
    type_,
    read_only: false,
    local_: false,
    count: None,
    needs_interpolation: false,
    interpolation_type,
    interpolation_sampling,
  }
}
