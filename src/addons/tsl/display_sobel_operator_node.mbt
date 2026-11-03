// examples/jsm/tsl/display/SobelOperatorNode.js

///|
/// Post processing node for detecting edges with a sobel filter.
pub(all) struct SobelOperatorNode {
  mut texture_node : @nodes.Node
  _inv_size : @nodes.Node
}

///|
pub impl @nodes.NodeClass for SobelOperatorNode with fn class_name(_) {
  "SobelOperatorNode"
}

///|
pub impl @nodes.NodeClass for SobelOperatorNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
}

///|
pub impl @nodes.NodeClass for SobelOperatorNode with fn update_before(
  self,
  _,
  _,
) {
  let map = @nodes.TextureNode::get_value(self.texture_node)
  a4_uniform_vector2(self._inv_size).set(
    1.0 / map.image().width(),
    1.0 / map.image().height(),
  )
  |> ignore
  None
}

///|
pub impl @nodes.NodeClass for SobelOperatorNode with fn setup(self, _, _) {
  let texture_node = self.texture_node
  let uv_node = match a4_texture_uv_node(texture_node) {
    Some(n) => n
    None => @nodes.uv()
  }
  let sample_texture = fn(uv : @nodes.Node) { texture_node.sample(uv) }
  let sobel = @nodes.fn_(fn(_, _) {
    // Sobel Edge Detection (see https://youtu.be/uihBwtPIBxM)
    let texel = self._inv_size
    // kernel definition (in glsl matrices are filled in column-major order)
    let gx = @nodes.mat3_of([-1, -2, -1, 0, 0, 0, 1, 2, 1]) // x direction kernel
    let gy = @nodes.mat3_of([-1, 0, 1, -2, 0, 2, -1, 0, 1]) // y direction kernel
    // fetch the 3x3 neighbourhood of a fragment
    let lum = fn(x : Double, y : Double) {
      @nodes.luminance(
        sample_texture(uv_node.add(texel.mul(@nodes.vec2_of([x, y])))).xyz(),
      )
    }
    // first column
    let tx0y0 = lum(-1, -1)
    let tx0y1 = lum(-1, 0)
    let tx0y2 = lum(-1, 1)
    // second column
    let tx1y0 = lum(0, -1)
    let tx1y1 = lum(0, 0)
    let tx1y2 = lum(0, 1)
    // third column
    let tx2y0 = lum(1, -1)
    let tx2y1 = lum(1, 0)
    let tx2y2 = lum(1, 1)
    // gradient value in x direction
    let value_gx = @nodes.add_of([
      gx[0][0].mul(tx0y0),
      gx[1][0].mul(tx1y0),
      gx[2][0].mul(tx2y0),
      gx[0][1].mul(tx0y1),
      gx[1][1].mul(tx1y1),
      gx[2][1].mul(tx2y1),
      gx[0][2].mul(tx0y2),
      gx[1][2].mul(tx1y2),
      gx[2][2].mul(tx2y2),
    ])
    // gradient value in y direction
    let value_gy = @nodes.add_of([
      gy[0][0].mul(tx0y0),
      gy[1][0].mul(tx1y0),
      gy[2][0].mul(tx2y0),
      gy[0][1].mul(tx0y1),
      gy[1][1].mul(tx1y1),
      gy[2][1].mul(tx2y1),
      gy[0][2].mul(tx0y2),
      gy[1][2].mul(tx1y2),
      gy[2][2].mul(tx2y2),
    ])
    // magnitude of the total gradient
    let g = value_gx.mul(value_gx).add(value_gy.mul(value_gy)).sqrt()
    Some(@nodes.vec4_of([@nodes.vec3(g), 1]))
  })
  let output_node = sobel.call([])
  Some(output_node)
}

///|
/// `new SobelOperatorNode( textureNode )`.
pub fn SobelOperatorNode::new(texture_node : @nodes.Node) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  node.update_before_type = @nodes.NodeUpdateType::frame()
  let _inv_size = @nodes.uniform(@math.Vector2::new(0.0, 0.0))
  node.set_class(SobelOperatorNode::{ texture_node, _inv_size, })
}

///|
pub fn SobelOperatorNode::of(node : @nodes.Node) -> SobelOperatorNode? {
  addon_class_of(node, "SobelOperatorNode")
}

///|
/// `sobel( node )`.
pub fn sobel(node : @nodes.Node) -> @nodes.Node {
  SobelOperatorNode::new(@nodes.convert_to_texture(node))
}
