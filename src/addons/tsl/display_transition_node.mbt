// examples/jsm/tsl/display/TransitionNode.js

///|
/// Post processing node for creating a transition between two textures.
pub(all) struct TransitionNode {
  /// A texture node that represents the beauty pass of the first scene.
  mut texture_node_a : @nodes.Node
  /// A texture node that represents the beauty pass of the second scene.
  mut texture_node_b : @nodes.Node
  /// A texture that defines how the transition effect should look like.
  mut mix_texture_node : @nodes.Node
  /// The interpolation factor that controls the mix.
  mut mix_ratio_node : @nodes.Node
  /// Can be used to tweak the linear interpolation.
  mut threshold_node : @nodes.Node
  /// Whether `mixTextureNode` should influence the transition or not.
  mut use_texture_node : @nodes.Node
}

///|
pub impl @nodes.NodeClass for TransitionNode with fn class_name(_) {
  "TransitionNode"
}

///|
pub impl @nodes.NodeClass for TransitionNode with fn children(self, _, out) {
  @nodes.push_child(out, "textureNodeA", Some(self.texture_node_a))
  @nodes.push_child(out, "textureNodeB", Some(self.texture_node_b))
  @nodes.push_child(out, "mixTextureNode", Some(self.mix_texture_node))
  @nodes.push_child(out, "mixRatioNode", Some(self.mix_ratio_node))
  @nodes.push_child(out, "thresholdNode", Some(self.threshold_node))
  @nodes.push_child(out, "useTextureNode", Some(self.use_texture_node))
}

///|
pub impl @nodes.NodeClass for TransitionNode with fn setup(self, _, _) {
  let {
    texture_node_a,
    texture_node_b,
    mix_texture_node,
    mix_ratio_node,
    threshold_node,
    use_texture_node,
  } = self
  let sample_texture = fn(texture_node : @nodes.Node) {
    let uv_node_texture = match addon_texture_uv_node(texture_node) {
      Some(u) => u
      None => @nodes.uv()
    }
    texture_node.sample(uv_node_texture)
  }
  let transition = @nodes.fn_(fn(_, _) {
    let texel_one = sample_texture(texture_node_a)
    let texel_two = sample_texture(texture_node_b)
    let color = @nodes.vec4_of([]).to_var()
    @nodes.if_(use_texture_node.equal(@nodes.int(1)), fn() {
      let transition_texel = sample_texture(mix_texture_node)
      let r = mix_ratio_node
        .mul(threshold_node.mul(2.0).add(1.0))
        .sub(threshold_node)
      let mixf = @nodes.clamp(
        @nodes.sub(transition_texel.r(), r).mul(
          @nodes.float(1.0).div(threshold_node),
        ),
        low=0.0,
        high=1.0,
      )
      color.assign(@nodes.mix(texel_one, texel_two, mixf))
    }).else_(fn() {
      color.assign(@nodes.mix(texel_two, texel_one, mix_ratio_node))
    })
    Some(color)
  })
  let output_node = transition.call([])
  Some(output_node)
}

///|
/// `new TransitionNode( textureNodeA, textureNodeB, mixTextureNode, mixRatioNode,
/// thresholdNode, useTextureNode )`.
pub fn TransitionNode::new(
  texture_node_a : @nodes.Node,
  texture_node_b : @nodes.Node,
  mix_texture_node : @nodes.Node,
  mix_ratio_node : @nodes.Node,
  threshold_node : @nodes.Node,
  use_texture_node : @nodes.Node,
) -> @nodes.Node {
  let node = @nodes.Node::alloc(node_type="vec4")
  node.set_class(TransitionNode::{
    texture_node_a,
    texture_node_b,
    mix_texture_node,
    mix_ratio_node,
    threshold_node,
    use_texture_node,
  })
}

///|
pub fn TransitionNode::of(node : @nodes.Node) -> TransitionNode? {
  addon_class_of(node, "TransitionNode")
}

///|
/// `transition( nodeA, nodeB, mixTextureNode, mixRatio, threshold, useTexture )`.
pub fn transition(
  node_a : @nodes.Node,
  node_b : @nodes.Node,
  mix_texture_node : @nodes.Node,
  mix_ratio : &@nodes.IntoTsl,
  threshold : &@nodes.IntoTsl,
  use_texture : &@nodes.IntoTsl,
) -> @nodes.Node {
  let texture_node_a = @nodes.convert_to_texture(node_a)
  let texture_node_b = @nodes.convert_to_texture(node_b)
  let mix_texture_node = @nodes.convert_to_texture(mix_texture_node)
  let mix_ratio = addon_node_object(mix_ratio)
  let threshold = addon_node_object(threshold)
  let use_texture = addon_node_object(use_texture)
  TransitionNode::new(
    texture_node_a, texture_node_b, mix_texture_node, mix_ratio, threshold, use_texture,
  )
}
