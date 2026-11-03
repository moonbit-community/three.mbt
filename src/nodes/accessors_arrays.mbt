// nodes/accessors/Arrays.js

///|
/// `attributeArray( count, type = 'float' )`: a storage buffer node of `count`
/// elements; `type_` is a type name or a struct type node.
pub fn attribute_array(count : Int32, type_? : &IntoTsl) -> Node {
  let type_ : TslValue = match type_ {
    Some(t) => t.to_tsl()
    None => String("float")
  }
  let (item_size, typed_array) = arrays_layout(type_)
  let buffer = StorageBufferAttribute::new(
    count,
    item_size,
    type_class=typed_array,
  )
  storage(buffer, type_~, count=buffer.count)
}

///|
/// `instancedArray( count, type = 'float' )`: as `attributeArray`, per instance.
pub fn instanced_array(count : Int32, type_? : &IntoTsl) -> Node {
  let type_ : TslValue = match type_ {
    Some(t) => t.to_tsl()
    None => String("float")
  }
  let (item_size, typed_array) = arrays_layout(type_)
  let buffer = StorageInstancedBufferAttribute::new(
    count,
    item_size,
    type_class=typed_array,
  )
  storage(buffer, type_~, count=buffer.count)
}

///|
/// The item size and typed array kind of an element type.
fn arrays_layout(type_ : TslValue) -> (Int32, @math.TypedArrayKind) {
  match type_ {
    Node(n) if n.has_flag("isStructTypeNode") =>
      (
        StructTypeNode::of(n).unwrap().get_length(),
        get_typed_array_from_type("float"),
      )
    String(t) => (get_length_from_type(t), get_typed_array_from_type(t))
    _ => abort("attributeArray: type must be a type name or a struct type node")
  }
}
