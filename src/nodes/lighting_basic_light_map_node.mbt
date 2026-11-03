// nodes/lighting/BasicLightMapNode.js

///|
pub(all) struct BasicLightMapNode {
  lighting : LightingNode
  mut light_map_node : Node?
}

///|
pub impl NodeClass for BasicLightMapNode with fn class_name(_) {
  "BasicLightMapNode"
}

///|
pub impl NodeClass for BasicLightMapNode with fn parent(self) {
  Some(self.lighting)
}

///|
pub impl NodeClass for BasicLightMapNode with fn children(self, node, out) {
  NodeClass::children(self.lighting, node, out)
  push_child(out, "lightMapNode", self.light_map_node)
}

///|
pub impl NodeClass for BasicLightMapNode with fn setup(self, _, builder) {
  // `irradianceLightMap` is read by BasicLightingModel's `indirect`.
  let reciprocal_pi = float(1.0 / bsdf_pi)
  builder.context.set(
    "irradianceLightMap",
    Node(self.light_map_node.unwrap().mul(reciprocal_pi)),
  )
  None
}

///|
/// `new BasicLightMapNode( lightMapNode = null )`.
pub fn BasicLightMapNode::new(light_map_node? : Node) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(BasicLightMapNode::{
    lighting: LightingNode::construct(node),
    light_map_node,
  })
}

///|
pub fn BasicLightMapNode::of(node : Node) -> BasicLightMapNode? {
  match node.class_payload("BasicLightMapNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
