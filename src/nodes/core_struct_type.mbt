// nodes/core/StructType.js

///|
/// One member of a struct layout: `{ name, type, atomic_, count }`; output structs
/// add `index`, the `@location` of the member.
pub(all) struct StructMember {
  mut name : String
  mut type_ : String
  mut atomic_ : Bool
  mut count : Int32?
  mut index : Int32?
}

///|
pub fn StructMember::new(
  name : String,
  type_ : String,
  atomic_~ : Bool = false,
  count? : Int32,
  index? : Int32,
) -> StructMember {
  { name, type_, atomic_, count, index, }
}

///|
pub(all) struct StructType {
  mut name : String
  mut members : Array[StructMember]
  mut output : Bool
}

///|
pub fn StructType::new(
  name : String,
  members : Array[StructMember],
) -> StructType {
  { name, members, output: false, }
}
