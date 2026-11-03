// examples/jsm/tsl/display/ParallaxBarrierPassNode.js

///|
/// A special type of render pass implementation for a parallax barrier effect.
pub(all) struct ParallaxBarrierPassNode {
  stereo : StereoCompositePassNode
}

///|
pub impl @nodes.NodeClass for ParallaxBarrierPassNode with fn class_name(_) {
  "ParallaxBarrierPassNode"
}

///|
pub impl @nodes.NodeClass for ParallaxBarrierPassNode with fn parent(self) {
  Some(self.stereo)
}

///|
pub impl @nodes.NodeClass for ParallaxBarrierPassNode with fn has_flag(
  self,
  flag,
) {
  flag == "isParallaxBarrierPassNode" || self.stereo.has_flag(flag)
}

///|
pub impl @nodes.NodeClass for ParallaxBarrierPassNode with fn setup(
  self,
  node,
  builder,
) {
  let uv_node = @nodes.uv()
  let parallax_barrier = @nodes.fn_(fn(_, _) {
    let color = @nodes.vec4_of([]).to_var()
    @nodes.if_(@nodes.mod(@nodes.screen_coordinate.y(), 2).greater_than(1), fn() {
      color.assign(self.stereo._map_left.sample(uv_node))
    }).else_(fn() { color.assign(self.stereo._map_right.sample(uv_node)) })
    Some(color)
  })
  let material = match self.stereo._material {
    Some(m) => m
    None => {
      let m = @nodes.NodeMaterial::new()
      self.stereo._material = Some(m)
      m
    }
  }
  let node_material = @nodes.NodeMaterial::of(material).unwrap()
  node_material.context_node = Some(
    @nodes.context(value=builder.get_shared_context()),
  )
  node_material.fragment_node = Some(parallax_barrier.call([]))
  material.set_needs_update(true)
  @nodes.NodeClass::setup(self.stereo, node, builder)
}

///|
/// Evaluates ParallaxBarrierPassNode.js (it imports StereoCompositePassNode.js), as
/// `import` does.
pub fn load_display_parallax_barrier_pass_node() -> Unit {
  load_display_stereo_composite_pass_node()
}

///|
/// `new ParallaxBarrierPassNode( scene, camera )`.
pub fn ParallaxBarrierPassNode::new(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  load_display_stereo_composite_pass_node()
  let node = @nodes.Node::alloc(node_type="vec4")
  let stereo = StereoCompositePassNode::construct(node, scene, camera)
  node.set_class(ParallaxBarrierPassNode::{ stereo, })
}

///|
pub fn ParallaxBarrierPassNode::of(
  node : @nodes.Node,
) -> ParallaxBarrierPassNode? {
  addon_class_of(node, "ParallaxBarrierPassNode")
}

///|
/// `parallaxBarrierPass( scene, camera )`.
pub fn parallax_barrier_pass(
  scene : @core.Object3D,
  camera : @core.Object3D,
) -> @nodes.Node {
  ParallaxBarrierPassNode::new(scene, camera)
}
