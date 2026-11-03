// examples/jsm/tsl/display/FilmNode.js

///|
/// Post processing node for creating a film grain effect.
pub(all) struct FilmNode {
  /// The node that represents the input of the effect.
  mut input_node : @nodes.Node
  /// A node that represents the effect's intensity (`null` by default).
  mut intensity_node : @nodes.Node?
  /// A node that allows to pass custom (e.g. animated) uv data (`null` by default).
  mut uv_node : @nodes.Node?
}

///|
pub impl @nodes.NodeClass for FilmNode with fn class_name(_) {
  "FilmNode"
}

///|
pub impl @nodes.NodeClass for FilmNode with fn children(self, _, out) {
  @nodes.push_child(out, "inputNode", Some(self.input_node))
  @nodes.push_child(out, "intensityNode", self.intensity_node)
  @nodes.push_child(out, "uvNode", self.uv_node)
}

///|
pub impl @nodes.NodeClass for FilmNode with fn setup(self, _, _) {
  let uv_node = match self.uv_node {
    Some(u) => u
    None => @nodes.uv()
  }
  let film = @nodes.fn_(fn(_, _) {
    let base = self.input_node.rgb()
    let noise = @nodes.rand.call([@nodes.fract(uv_node.add(@nodes.time))])
    let mut color = base.add(
      base.mul(@nodes.clamp(noise.add(0.1), low=0, high=1)),
    )
    if self.intensity_node is Some(intensity_node) {
      color = @nodes.mix(base, color, intensity_node)
    }
    Some(@nodes.vec4_of([color, self.input_node.a()]))
  })
  let output_node = film.call([])
  Some(output_node)
}

///|
/// `new FilmNode( inputNode, intensityNode = null, uvNode = null )`.
pub fn FilmNode::new(
  input_node : @nodes.Node,
  intensity_node? : @nodes.Node,
  uv_node? : @nodes.Node,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(FilmNode::{ input_node, intensity_node, uv_node, })
}

///|
pub fn FilmNode::of(node : @nodes.Node) -> FilmNode? {
  addon_class_of(node, "FilmNode")
}

///|
/// `film( inputNode, intensityNode = null, uvNode = null )` (`nodeProxy( FilmNode )`).
pub fn film(
  input_node : &@nodes.IntoTsl,
  intensity_node? : &@nodes.IntoTsl,
  uv_node? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let input_node = addon_node_object(input_node)
  let intensity_node = intensity_node.map(addon_node_object)
  let uv_node = uv_node.map(addon_node_object)
  FilmNode::new(input_node, intensity_node?, uv_node?)
}
