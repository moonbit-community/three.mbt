// nodes/accessors/AccessorsUtils.js

///|
/// `TBNViewMatrix`.
pub let tbn_view_matrix : Node = module_nodes(
  "nodes/accessors/AccessorsUtils.js:TBNViewMatrix",
  fn() {
    mat3_of([tangent_view, bitangent_view, normal_view]).to_var(
      name="TBNViewMatrix",
    )
  },
)

///|
pub let parallax_direction : Node = module_nodes(
  "nodes/accessors/AccessorsUtils.js:parallaxDirection",
  fn() { position_view_direction.mul(tbn_view_matrix) },
)

///|
/// `parallaxUV( uv, scale )`.
pub fn parallax_uv(uv : Node, scale : &IntoTsl) -> Node {
  uv.sub(parallax_direction.mul(scale))
}

///|
pub let bent_normal_view : Node = module_nodes(
  "nodes/accessors/AccessorsUtils.js:bentNormalView",
  fn() {
    fn_(fn(_, _) {
      let mut bent_normal = anisotropy_b.cross(position_view_direction)
      bent_normal = bent_normal.cross(anisotropy_b).normalize()
      bent_normal = mix(
        bent_normal,
        normal_view,
        anisotropy.mul(roughness.one_minus()).one_minus().pow2().pow2(),
      ).normalize()
      Some(bent_normal)
    })
    .once()
    .call([])
  },
)
