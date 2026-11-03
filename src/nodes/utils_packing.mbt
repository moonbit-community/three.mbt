// nodes/utils/Packing.js: normals to colors and back. The deprecated
// `directionToColor`/`colorToDirection` are not ported.

///|
/// `packNormalToRGB( node )`: `node * 0.5 + 0.5`.
pub fn pack_normal_to_rgb(node : &IntoTsl) -> Node {
  node_object(node.to_tsl()).mul(0.5).add(0.5)
}

///|
/// `unpackRGBToNormal( node )`: `node * 2 - 1`.
pub fn unpack_rgb_to_normal(node : &IntoTsl) -> Node {
  node_object(node.to_tsl()).mul(2.0).sub(1)
}

///|
/// `unpackNormal( xy )`: the normal with `z = sqrt( 1 - dot( xy, xy ) )`.
pub fn unpack_normal(xy : &IntoTsl) -> Node {
  vec3_of([xy, sqrt(saturate(float(1.0).sub(dot(xy, xy))))])
}
