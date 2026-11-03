// nodes/utils/EquirectUV.js: equirectangular uv from a direction, and back.

///|
let _equirect_uv_pi : Double = 3.141592653589793

///|
/// `equirectUV( direction = positionWorldDirection )`.
pub let equirect_uv : Node = module_nodes(
  "nodes/utils/EquirectUV.js:equirectUV",
  fn() {
    fn_(fn(inputs, _) {
      let direction = inputs
        .get(0)
        .unwrap_or_else(fn() { position_world_direction })
      let u = direction
        .z()
        .atan(x=direction.x())
        .mul(1.0 / (_equirect_uv_pi * 2.0))
        .add(0.5)
      let v = direction
        .y()
        .clamp(low=-1.0, high=1.0)
        .asin()
        .mul(1.0 / _equirect_uv_pi)
        .add(0.5)
      Some(vec2_of([u, v]))
    })
  },
)

///|
/// `equirectDirection( uv = uv() )`.
pub let equirect_direction : Node = module_nodes(
  "nodes/utils/EquirectUV.js:equirectDirection",
  fn() {
    fn_(fn(inputs, _) {
      let uv_node = inputs.get(0).unwrap_or_else(fn() { uv() })
      let theta = uv_node.x().sub(0.5).mul(_equirect_uv_pi * 2.0)
      let phi = uv_node.y().sub(0.5).mul(_equirect_uv_pi)
      let cos_phi = phi.cos()
      let x = cos_phi.mul(theta.cos())
      let y = phi.sin()
      let z = cos_phi.mul(theta.sin())
      Some(vec3_of([x, y, z]))
    })
  },
)
