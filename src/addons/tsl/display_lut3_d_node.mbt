// examples/jsm/tsl/display/Lut3DNode.js

///|
/// A post processing node for color grading via lookup tables.
pub(all) struct Lut3DNode {
  /// The node that represents the input of the effect.
  mut input_node : @nodes.Node
  /// A texture node that represents the lookup table.
  mut lut_node : @nodes.Node
  /// The size of the lookup table (a uniform).
  mut size : @nodes.Node
  /// Controls the intensity of the effect.
  mut intensity_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for Lut3DNode with fn class_name(_) {
  "Lut3DNode"
}

///|
pub impl @nodes.NodeClass for Lut3DNode with fn children(self, _, out) {
  @nodes.push_child(out, "inputNode", Some(self.input_node))
  @nodes.push_child(out, "lutNode", Some(self.lut_node))
  @nodes.push_child(out, "size", Some(self.size))
  @nodes.push_child(out, "intensityNode", Some(self.intensity_node))
}

///|
pub impl @nodes.NodeClass for Lut3DNode with fn setup(self, _, _) {
  let input_node = self.input_node
  let lut_node = self.lut_node
  let sample_lut = fn(uv : @nodes.Node) { lut_node.sample(uv) }
  let lut3_d = @nodes.fn_(fn(_, _) {
    let base = input_node
    // pull the sample in by half a pixel so the sample begins at the center of the edge pixels.
    let pixel_width = @nodes.float(1.0).div(self.size)
    let half_pixel_width = @nodes.float(0.5).div(self.size)
    let uvw = @nodes.vec3(half_pixel_width).add(
      base.rgb().mul(@nodes.float(1.0).sub(pixel_width)),
    )
    let lut_value = @nodes.vec4_of([sample_lut(uvw).rgb(), base.a()])
    Some(@nodes.vec4(@nodes.mix(base, lut_value, self.intensity_node)))
  })
  let output_node = lut3_d.call([])
  Some(output_node)
}

///|
/// `new Lut3DNode( inputNode, lutNode, size, intensityNode )` (`size` goes into a uniform).
pub fn Lut3DNode::new(
  input_node : @nodes.Node,
  lut_node : @nodes.Node,
  size : &@nodes.IntoTsl,
  intensity_node : @nodes.Node,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let size = @nodes.uniform(size)
  node.set_class(Lut3DNode::{ input_node, lut_node, size, intensity_node, })
}

///|
pub fn Lut3DNode::of(node : @nodes.Node) -> Lut3DNode? {
  addon_class_of(node, "Lut3DNode")
}

///|
/// `lut3D( node, lut, size, intensity )`.
pub fn lut3_d(
  node : &@nodes.IntoTsl,
  lut : &@nodes.IntoTsl,
  size : &@nodes.IntoTsl,
  intensity : &@nodes.IntoTsl,
) -> @nodes.Node {
  let node = addon_node_object(node)
  let lut = addon_node_object(lut)
  let intensity = addon_node_object(intensity)
  Lut3DNode::new(node, lut, size, intensity)
}
