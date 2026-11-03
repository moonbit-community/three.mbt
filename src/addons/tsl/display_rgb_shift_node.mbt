// examples/jsm/tsl/display/RGBShiftNode.js

///|
/// Post processing node for shifting/splitting RGB color channels: the red and blue
/// channels are sampled with an offset along `angle`.
pub(all) struct RGBShiftNode {
  mut texture_node : @nodes.Node
  mut amount : @nodes.Node
  mut angle : @nodes.Node
}

///|
pub impl @nodes.NodeClass for RGBShiftNode with fn class_name(_) {
  "RGBShiftNode"
}

///|
pub impl @nodes.NodeClass for RGBShiftNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "amount", Some(self.amount))
  @nodes.push_child(out, "angle", Some(self.angle))
}

///|
pub impl @nodes.NodeClass for RGBShiftNode with fn setup(self, _, _) {
  let texture_node = self.texture_node
  let uv_node = match a4_texture_uv_node(texture_node) {
    Some(n) => n
    None => @nodes.uv()
  }
  let sample_texture = fn(uv : @nodes.Node) { texture_node.sample(uv) }
  let rgb_shift = @nodes.fn_(fn(_, _) {
    let offset = @nodes.vec2_of([@nodes.cos(self.angle), @nodes.sin(self.angle)]).mul(
      self.amount,
    )
    let cr = sample_texture(uv_node.add(offset))
    let cga = sample_texture(uv_node)
    let cb = sample_texture(uv_node.sub(offset))
    Some(@nodes.vec4_of([cr.r(), cga.g(), cb.b(), cga.a()]))
  })
  Some(rgb_shift.call([]))
}

///|
/// `new RGBShiftNode( textureNode, amount = 0.005, angle = 0 )`.
pub fn RGBShiftNode::new(
  texture_node : @nodes.Node,
  amount? : &@nodes.IntoTsl,
  angle? : &@nodes.IntoTsl,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  let amount = a4_node_object_or(amount, Number(0.005))
  let angle = a4_node_object_or(angle, Number(0.0))
  node.set_class(RGBShiftNode::{ texture_node, amount, angle, })
}

///|
pub fn RGBShiftNode::of(node : @nodes.Node) -> RGBShiftNode? {
  match node.class_payload("RGBShiftNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `rgbShift( node, amount, angle )`.
pub fn rgb_shift(
  node : @nodes.Node,
  amount? : &@nodes.IntoTsl,
  angle? : &@nodes.IntoTsl,
) -> @nodes.Node {
  RGBShiftNode::new(@nodes.convert_to_texture(node), amount?, angle?)
}
