// nodes/utils/TriplanarTextures.js: triplanar mapping with up to three textures.

///|
/// `triplanarTextures( textureXNode, textureYNode = null, textureZNode = null,
/// scaleNode = float( 1 ), positionNode = positionLocal, normalNode = normalLocal )`.
pub let triplanar_textures : Node = module_nodes(
  "nodes/utils/TriplanarTextures.js:triplanarTextures",
  fn() {
    fn_(fn(inputs, _) {
      let texture_x_node = operator_node_input(inputs, 0)
      let texture_y_node = inputs.get(1)
      let texture_z_node = inputs.get(2)
      let scale_node = inputs.get(3).unwrap_or_else(fn() { float(1) })
      let position_node = inputs.get(4).unwrap_or(position_local)
      let normal_node = inputs.get(5).unwrap_or(normal_local)
      // Reference: https://github.com/keijiro/StandardTriplanar
      // Blending factor of triplanar mapping
      let mut bf = normal_node.abs().normalize()
      bf = bf.div(bf.dot(vec3(1.0)))
      // Triplanar mapping
      let tx = position_node.yz().mul(scale_node)
      let ty = position_node.zx().mul(scale_node)
      let tz = position_node.xy().mul(scale_node)
      // Base color
      let texture_x = utils_node_value(texture_x_node)
      let texture_y = match texture_y_node {
        Some(n) => utils_node_value(n)
        None => texture_x
      }
      let texture_z = match texture_z_node {
        Some(n) => utils_node_value(n)
        None => texture_x
      }
      let cx = texture(texture_x, uv_node=tx).mul(bf.x())
      let cy = texture(texture_y, uv_node=ty).mul(bf.y())
      let cz = texture(texture_z, uv_node=tz).mul(bf.z())
      Some(add_of([cx, cy, cz]))
    })
  },
)

///|
/// `triplanarTexture( ...params )`: `triplanarTextures( ...params )`.
pub fn triplanar_texture(params : Array[&IntoTsl]) -> Node {
  triplanar_textures.call(params)
}
