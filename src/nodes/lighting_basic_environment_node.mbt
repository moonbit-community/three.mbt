// nodes/lighting/BasicEnvironmentNode.js

///|
pub(all) struct BasicEnvironmentNode {
  lighting : LightingNode
  mut env_node : Node?
}

///|
pub impl NodeClass for BasicEnvironmentNode with fn class_name(_) {
  "BasicEnvironmentNode"
}

///|
pub impl NodeClass for BasicEnvironmentNode with fn parent(self) {
  Some(self.lighting)
}

///|
pub impl NodeClass for BasicEnvironmentNode with fn children(self, node, out) {
  NodeClass::children(self.lighting, node, out)
  push_child(out, "envNode", self.env_node)
}

///|
pub impl NodeClass for BasicEnvironmentNode with fn setup(self, _, builder) {
  // `environment` is read by BasicLightingModel's `finish`.
  let get_uv = ContextGetUV::{
    f: fn(texture_node, _) {
      let uv = match TextureNode::of(texture_node).unwrap().uv_node {
        Some(uv) => uv
        None => TextureNode::get_default_uv(texture_node)
      }
      material_env_rotation.mul(uv)
    },
  }
  builder.context.set(
    "environment",
    Node(
      cube_map_node(physical_optional(self.env_node)).context(
        value=node_context([
          ("getUV", Other(@core.JsValue::of(get_uv))),
          ("forceUVContext", Bool(true)),
        ]),
      ),
    ),
  )
  None
}

///|
/// `new BasicEnvironmentNode( envNode = null )`.
pub fn BasicEnvironmentNode::new(env_node? : Node) -> Node {
  let node = Node::alloc(node_type="vec3")
  node.set_class(BasicEnvironmentNode::{
    lighting: LightingNode::construct(node),
    env_node,
  })
}

///|
pub fn BasicEnvironmentNode::of(node : Node) -> BasicEnvironmentNode? {
  match node.class_payload("BasicEnvironmentNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}
