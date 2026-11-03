// examples/jsm/tsl/display/ChromaticAberrationNode.js

///|
/// Post processing node for applying chromatic aberration effect.
pub(all) struct ChromaticAberrationNode {
  /// The texture node that represents the input of the effect.
  mut texture_node : @nodes.Node
  /// The strength of the effect.
  mut strength_node : @nodes.Node
  /// The center point of the effect (`null` is passed through as upstream does).
  mut center_node : @nodes.Node?
  /// The scale factor for stepped scaling from center.
  mut scale_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for ChromaticAberrationNode with fn class_name(_) {
  "ChromaticAberrationNode"
}

///|
pub impl @nodes.NodeClass for ChromaticAberrationNode with fn children(
  self,
  _,
  out,
) {
  @nodes.push_child(out, "textureNode", Some(self.texture_node))
  @nodes.push_child(out, "strengthNode", Some(self.strength_node))
  @nodes.push_child(out, "centerNode", self.center_node)
  @nodes.push_child(out, "scaleNode", Some(self.scale_node))
}

///|
pub impl @nodes.NodeClass for ChromaticAberrationNode with fn setup(self, _, _) {
  let texture_node = self.texture_node
  let uv_node = match addon_texture_uv_node(texture_node) {
    Some(u) => u
    None => @nodes.uv()
  }
  let apply_chromatic_aberration = @nodes.fn_(fn(inputs, _) {
    let uv = addon_arg(inputs, 0)
    let strength = addon_arg(inputs, 1)
    let center = addon_arg(inputs, 2)
    let scale = addon_arg(inputs, 3)
    // Calculate distance from center
    let offset = uv.sub(center)
    let distance = offset.length()
    // Create stepped scaling zones based on distance
    // Each channel gets different scaling steps
    let red_scale = @nodes.float(1.0).add(scale.mul(0.02).mul(strength)) // Red channel scaled outward
    let green_scale = @nodes.float(1.0) // Green stays at original scale
    let blue_scale = @nodes.float(1.0).sub(scale.mul(0.02).mul(strength)) // Blue channel scaled inward
    // Create radial distortion based on distance from center
    let aberration_strength = strength.mul(distance)
    // Calculate scaled UV coordinates for each channel
    let red_uv = center.add(offset.mul(red_scale))
    let green_uv = center.add(offset.mul(green_scale))
    let blue_uv = center.add(offset.mul(blue_scale))
    // Apply additional chromatic offset based on aberration strength
    let r_offset = offset.mul(aberration_strength).mul(@nodes.float(0.01))
    let g_offset = offset.mul(aberration_strength).mul(@nodes.float(0.0))
    let b_offset = offset.mul(aberration_strength).mul(@nodes.float(-0.01))
    // Final UV coordinates combining scale and chromatic aberration
    let final_red_uv = red_uv.add(r_offset)
    let final_green_uv = green_uv.add(g_offset)
    let final_blue_uv = blue_uv.add(b_offset)
    // Sample texture for each channel
    let r = texture_node.sample(final_red_uv).r()
    let g = texture_node.sample(final_green_uv).g()
    let b = texture_node.sample(final_blue_uv).b()
    // Get original alpha
    let a = texture_node.sample(uv).a()
    Some(@nodes.vec4_of([r, g, b, a]))
  })
  let chromatic_aberration_fn = @nodes.fn_(fn(_, _) {
    let center : @nodes.TslValue = match self.center_node {
      Some(c) => Node(c)
      None => Null
    }
    Some(
      apply_chromatic_aberration.call([
        uv_node,
        self.strength_node,
        center,
        self.scale_node,
      ]),
    )
  })
  let output_node = chromatic_aberration_fn.call([])
  Some(output_node)
}

///|
/// `new ChromaticAberrationNode( textureNode, strengthNode, centerNode, scaleNode )`.
pub fn ChromaticAberrationNode::new(
  texture_node : @nodes.Node,
  strength_node : @nodes.Node,
  center_node : @nodes.Node?,
  scale_node : @nodes.Node,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(ChromaticAberrationNode::{
    texture_node,
    strength_node,
    center_node,
    scale_node,
  })
}

///|
pub fn ChromaticAberrationNode::of(
  node : @nodes.Node,
) -> ChromaticAberrationNode? {
  addon_class_of(node, "ChromaticAberrationNode")
}

///|
/// `chromaticAberration( node, strength = 1.0, center = null, scale = 1.1 )`.
pub fn chromatic_aberration(
  node : @nodes.Node,
  strength~ : &@nodes.IntoTsl = 1.0,
  center? : &@nodes.IntoTsl,
  scale~ : &@nodes.IntoTsl = 1.1,
) -> @nodes.Node {
  let texture_node = @nodes.convert_to_texture(node)
  let strength = addon_node_object(strength)
  let center = match center {
    Some(c) =>
      match c.to_tsl() {
        Null | Undefined => None
        v => Some(@nodes.node_object(v))
      }
    None => None
  }
  let scale = addon_node_object(scale)
  ChromaticAberrationNode::new(texture_node, strength, center, scale)
}
