// examples/jsm/tsl/display/DotScreenNode.js

///|
/// Post processing node for a dot-screen effect.
pub(all) struct DotScreenNode {
  mut input_node : @nodes.Node
  mut angle : @nodes.Node
  mut scale : @nodes.Node
}

///|
pub impl @nodes.NodeClass for DotScreenNode with fn class_name(_) {
  "DotScreenNode"
}

///|
pub impl @nodes.NodeClass for DotScreenNode with fn children(self, _, out) {
  @nodes.push_child(out, "inputNode", Some(self.input_node))
  @nodes.push_child(out, "angle", Some(self.angle))
  @nodes.push_child(out, "scale", Some(self.scale))
}

///|
pub impl @nodes.NodeClass for DotScreenNode with fn setup(self, _, _) {
  let input_node = self.input_node
  let pattern = @nodes.fn_(fn(_, _) {
    let s = @nodes.sin(self.angle)
    let c = @nodes.cos(self.angle)
    let tex = @nodes.uv().mul(@nodes.screen_size)
    let point = @nodes.vec2_of([
      c.mul(tex.x()).sub(s.mul(tex.y())),
      s.mul(tex.x()).add(c.mul(tex.y())),
    ]).mul(self.scale)
    Some(@nodes.sin(point.x()).mul(@nodes.sin(point.y())).mul(4))
  })
  let dot_screen = @nodes.fn_(fn(_, _) {
    let color = input_node
    let average = @nodes.add_of([color.r(), color.g(), color.b()]).div(3)
    Some(
      @nodes.vec4_of([
        @nodes.vec3(average.mul(10).sub(5).add(pattern.call([]))),
        color.a(),
      ]),
    )
  })
  let output_node = dot_screen.call([])
  Some(output_node)
}

///|
/// `new DotScreenNode( inputNode, angle = 1.57, scale = 1 )`.
pub fn DotScreenNode::new(
  input_node : @nodes.Node,
  angle? : &@nodes.IntoTsl,
  scale? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let angle = a4_node_object_or(angle, Number(1.57))
  let scale = a4_node_object_or(scale, Number(1.0))
  node.set_class(DotScreenNode::{ input_node, angle, scale, })
}

///|
pub fn DotScreenNode::of(node : @nodes.Node) -> DotScreenNode? {
  addon_class_of(node, "DotScreenNode")
}

///|
/// `dotScreen( node, angle, scale )`.
pub fn dot_screen(
  node : &@nodes.IntoTsl,
  angle? : &@nodes.IntoTsl,
  scale? : &@nodes.IntoTsl,
) -> @nodes.Node {
  DotScreenNode::new(@nodes.node_object(node.to_tsl()), angle?, scale?)
}
