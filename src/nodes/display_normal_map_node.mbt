// nodes/display/NormalMapNode.js

///|
/// Turns a normal map sample into a view-space normal.
pub(all) struct NormalMapNode {
  mut node : Node
  /// `None` is `null`.
  mut scale_node : Node?
  /// `TangentSpaceNormalMap` or `ObjectSpaceNormalMap`.
  mut normal_map_type : Int32
  /// `NoNormalPacking`, `NormalRGPacking` or `NormalGAPacking`.
  mut unpack_normal_mode : String
}

///|
pub impl NodeClass for NormalMapNode with fn class_name(_) {
  "NormalMapNode"
}

///|
pub impl NodeClass for NormalMapNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
  push_child(out, "scaleNode", self.scale_node)
}

///|
pub impl NodeClass for NormalMapNode with fn setup(self, _, builder) {
  let normal_map_type = self.normal_map_type
  let scale_node = self.scale_node
  let unpack_normal_mode = self.unpack_normal_mode
  let mut normal_map = self.node.mul(2.0).sub(1.0)
  if normal_map_type == @core.TangentSpaceNormalMap {
    if unpack_normal_mode == @core.NormalRGPacking {
      normal_map = unpack_normal(normal_map.xy())
    } else if unpack_normal_mode == @core.NormalGAPacking {
      normal_map = unpack_normal(normal_map.yw())
    } else if unpack_normal_mode != @core.NoNormalPacking {
      @core.error(
        "THREE.NodeMaterial: Unexpected unpack normal mode: \{unpack_normal_mode}",
      )
    }
  } else if unpack_normal_mode != @core.NoNormalPacking {
    @core.error(
      "THREE.NodeMaterial: Normal map type '\{normal_map_type}' is not compatible with unpack normal mode '\{unpack_normal_mode}'",
    )
  }
  if scale_node is Some(scale_node) {
    let mut scale = scale_node
    if builder.is_flat_shading() == true {
      scale = negate_on_back_side.call([scale])
    }
    normal_map = vec3_of([normal_map.xy().mul(scale), normal_map.z()])
  }
  let output = if normal_map_type == @core.ObjectSpaceNormalMap {
    transform_normal_to_view.call([normal_map])
  } else if normal_map_type == @core.TangentSpaceNormalMap {
    tbn_view_matrix.mul(normal_map).normalize()
  } else {
    @core.error("NodeMaterial: Unsupported normal map type: \{normal_map_type}")
    normal_view // Fallback to default normal view
  }
  Some(output)
}

///|
pub fn NormalMapNode::construct(
  _node : Node,
  node : Node,
  scale_node : Node?,
) -> NormalMapNode {
  {
    node,
    scale_node,
    normal_map_type: @core.TangentSpaceNormalMap,
    unpack_normal_mode: @core.NoNormalPacking,
  }
}

///|
/// `new NormalMapNode( node, scaleNode = null )`.
pub fn NormalMapNode::new(node : Node, scale_node? : Node) -> Node {
  let n = Node::alloc(node_type="vec3")
  n.set_class(NormalMapNode::construct(n, node, scale_node))
}

///|
pub fn NormalMapNode::of(node : Node) -> NormalMapNode? {
  match node.class_payload("NormalMapNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `normalMap( node, scaleNode )`.
pub fn normal_map(node : &IntoTsl, scale_node? : &IntoTsl) -> Node {
  NormalMapNode::new(
    node_object(node.to_tsl()),
    scale_node?=scale_node.map(fn(s) { node_object(s.to_tsl()) }),
  )
}
