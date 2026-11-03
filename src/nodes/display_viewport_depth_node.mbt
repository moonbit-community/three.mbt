// nodes/display/ViewportDepthNode.js

///|
/// The fragment depth (`depth`), the linear depth, or the writable depth base.
pub(all) struct ViewportDepthNode {
  mut scope : String
  /// `None` is `null`.
  mut value_node : Node?
}

///|
pub impl NodeClass for ViewportDepthNode with fn class_name(_) {
  "ViewportDepthNode"
}

///|
pub impl NodeClass for ViewportDepthNode with fn has_flag(_, flag) {
  flag == "isViewportDepthNode"
}

///|
pub impl NodeClass for ViewportDepthNode with fn children(self, _, out) {
  push_child(out, "valueNode", self.value_node)
}

///|
pub impl NodeClass for ViewportDepthNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for ViewportDepthNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ViewportDepthNode with fn generate(
  self,
  node,
  builder,
  _,
) {
  if self.scope == ViewportDepthNode::depth_base() {
    return Some(builder.get_frag_depth())
  }
  node.generate_base(builder, None)
}

///|
/// `depth.assign( value )` is `depthBase( value )` (upstream overrides `assign` on the
/// `depth` instance).
pub impl NodeClass for ViewportDepthNode with fn assign(_, node, value) {
  if physical_equal(node, depth) {
    Some(depth_base(value))
  } else {
    None
  }
}

///|
pub impl NodeClass for ViewportDepthNode with fn setup(self, _, builder) {
  let scope = self.scope
  let value = self.value_node
  let is_orthographic = match builder.camera {
    Some(camera) => camera.is_orthographic_camera()
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'isOrthographicCamera')",
      )
  }
  let mut node : Node? = None
  if scope == ViewportDepthNode::depth_base() {
    if value is Some(value) {
      node = Some(depth_base(Undefined).assign_node(value))
    }
  } else if scope == ViewportDepthNode::depth() {
    if is_orthographic != true {
      node = Some(
        view_z_to_perspective_depth(position_view.z(), camera_near, camera_far),
      )
    } else {
      node = Some(
        view_z_to_orthographic_depth(position_view.z(), camera_near, camera_far),
      )
    }
  } else if scope == ViewportDepthNode::linear_depth() {
    match value {
      Some(value) =>
        if is_orthographic != true {
          let view_z = perspective_depth_to_view_z.call([
            value, camera_near, camera_far,
          ])
          node = Some(
            view_z_to_orthographic_depth(view_z, camera_near, camera_far),
          )
        } else {
          node = Some(value)
        }
      None =>
        node = Some(
          view_z_to_orthographic_depth(
            position_view.z(),
            camera_near,
            camera_far,
          ),
        )
    }
  }
  node
}

///|
/// `ViewportDepthNode.DEPTH_BASE`.
pub fn ViewportDepthNode::depth_base() -> String {
  "depthBase"
}

///|
/// `ViewportDepthNode.DEPTH`.
pub fn ViewportDepthNode::depth() -> String {
  "depth"
}

///|
/// `ViewportDepthNode.LINEAR_DEPTH`.
pub fn ViewportDepthNode::linear_depth() -> String {
  "linearDepth"
}

///|
pub fn ViewportDepthNode::construct(
  _node : Node,
  scope : String,
  value_node : Node?,
) -> ViewportDepthNode {
  { scope, value_node, }
}

///|
/// `new ViewportDepthNode( scope, valueNode = null )`.
pub fn ViewportDepthNode::new(scope : String, value_node? : Node) -> Node {
  let node = Node::alloc(node_type="float")
  node.set_class(ViewportDepthNode::construct(node, scope, value_node))
}

///|
pub fn ViewportDepthNode::of(node : Node) -> ViewportDepthNode? {
  match node.class_payload("ViewportDepthNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

// NOTE: viewZ, the z-coordinate in camera space, is negative for points in front of the camera

///|
/// `viewZToOrthographicDepth( viewZ, near, far )`.
pub fn view_z_to_orthographic_depth(
  view_z : Node,
  near : Node,
  far : Node,
) -> Node {
  view_z.add(near).div(near.sub(far))
}

///|
/// `viewZToReversedOrthographicDepth( viewZ, near, far )`.
pub fn view_z_to_reversed_orthographic_depth(
  view_z : Node,
  near : Node,
  far : Node,
) -> Node {
  view_z.add(far).div(far.sub(near))
}

///|
/// `orthographicDepthToViewZ( depth, near, far )`.
pub let orthographic_depth_to_view_z : Node = module_nodes(
  "nodes/display/ViewportDepthNode.js:orthographicDepthToViewZ",
  fn() {
    fn_(fn(inputs, builder) {
      let depth = inputs.get(0).unwrap()
      let near = inputs.get(1).unwrap()
      let far = inputs.get(2).unwrap()
      if builder.renderer.reversed_depth_buffer == true {
        Some(far.sub(near).mul(depth).sub(far))
      } else {
        Some(near.sub(far).mul(depth).sub(near))
      }
    })
  },
)

///|
/// `viewZToPerspectiveDepth( viewZ, near, far )`.
pub fn view_z_to_perspective_depth(
  view_z : Node,
  near : Node,
  far : Node,
) -> Node {
  near.add(view_z).mul(far).div(far.sub(near).mul(view_z))
}

///|
/// `viewZToReversedPerspectiveDepth( viewZ, near, far )`.
pub fn view_z_to_reversed_perspective_depth(
  view_z : Node,
  near : Node,
  far : Node,
) -> Node {
  near.mul(view_z.add(far)).div(view_z.mul(near.sub(far)))
}

///|
/// `perspectiveDepthToViewZ( depth, near, far )`.
pub let perspective_depth_to_view_z : Node = module_nodes(
  "nodes/display/ViewportDepthNode.js:perspectiveDepthToViewZ",
  fn() {
    fn_(fn(inputs, builder) {
      let depth = inputs.get(0).unwrap()
      let near = inputs.get(1).unwrap()
      let far = inputs.get(2).unwrap()
      if builder.renderer.reversed_depth_buffer == true {
        Some(near.mul(far).div(near.sub(far).mul(depth).sub(near)))
      } else {
        Some(near.mul(far).div(far.sub(near).mul(depth).sub(far)))
      }
    })
  },
)

///|
/// `viewZToLogarithmicDepth( viewZ, near, far )`: Ulrich's logarithmic depth with the
/// near plane, using `log2` (see upstream for the derivation).
pub fn view_z_to_logarithmic_depth(
  view_z : Node,
  near : Node,
  far : Node,
) -> Node {
  let near = near.max(epsilon).to_var()
  let numerator = log2(view_z.negate().div(near))
  let denominator = log2(far.div(near))
  numerator.div(denominator)
}

///|
/// `logarithmicDepthToViewZ( depth, near, far )`.
pub fn logarithmic_depth_to_view_z(
  depth : Node,
  near : Node,
  far : Node,
) -> Node {
  // NOTE: we add a 'negate()' call to the return value here to maintain consistency with
  // the functions "orthographicDepthToViewZ" and "perspectiveDepthToViewZ" (they return
  // a negative viewZ).
  let exponent = depth.mul(log(far.div(near)))
  // `Math.E`
  float(2.718281828459045).pow(exponent).mul(near).negate()
}

///|
/// `projectionDepth( depth, near, far )`: the perspective depth of a logarithmic depth.
pub let projection_depth : Node = module_nodes(
  "nodes/display/ViewportDepthNode.js:projectionDepth",
  fn() {
    fn_(fn(inputs, builder) {
      let depth = inputs.get(0).unwrap()
      let near = inputs.get(1).unwrap()
      let far = inputs.get(2).unwrap()
      if renderer_logarithmic_depth_buffer(builder.renderer) == true {
        let view_z = logarithmic_depth_to_view_z(depth, near, far)
        return Some(view_z_to_perspective_depth(view_z, near, far))
      }
      Some(depth)
    })
  },
)

///|
/// `depthBase( value )`: a `ViewportDepthNode` writing the fragment depth.
fn depth_base(value : TslValue) -> Node {
  match node_object_value(value) {
    Node(n) =>
      ViewportDepthNode::new(ViewportDepthNode::depth_base(), value_node=n)
    _ => ViewportDepthNode::new(ViewportDepthNode::depth_base())
  }
}

///|
/// `depth`: the fragment depth; `depth.assign( value )` writes it.
pub let depth : Node = module_nodes(
  "nodes/display/ViewportDepthNode.js:depth",
  fn() { ViewportDepthNode::new(ViewportDepthNode::depth()) },
)

///|
/// `linearDepth( valueNode = null )`: the linear depth of a depth value, or of the
/// fragment.
pub fn linear_depth(value_node? : &IntoTsl) -> Node {
  match value_node {
    Some(v) =>
      ViewportDepthNode::new(
        ViewportDepthNode::linear_depth(),
        value_node=node_object(v.to_tsl()),
      )
    None => ViewportDepthNode::new(ViewportDepthNode::linear_depth())
  }
}

///|
/// `viewportLinearDepth`: the linear depth of the viewport depth texture.
pub let viewport_linear_depth : Node = module_nodes(
  "nodes/display/ViewportDepthNode.js:viewportLinearDepth",
  fn() { linear_depth(value_node=viewport_depth_texture()) },
)

///|
/// `renderer.logarithmicDepthBuffer`, which group G6 has not declared yet; it becomes
/// the field once it exists.
fn renderer_logarithmic_depth_buffer(renderer : Renderer) -> Bool {
  renderer.logarithmic_depth_buffer
}
