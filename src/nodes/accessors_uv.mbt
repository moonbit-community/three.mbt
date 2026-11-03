// nodes/accessors/UV.js

///|
/// `uv( index = 0 )`: the `uv`, `uv1`, ... attribute.
pub fn uv(index~ : Int32 = 0) -> Node {
  attribute(
    "uv" + (if index > 0 { index.to_string() } else { "" }),
    node_type="vec2",
  )
}
