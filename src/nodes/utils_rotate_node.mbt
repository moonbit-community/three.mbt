// nodes/utils/RotateNode.js: rotates a 2D position by an angle, or a 3D position by
// Euler angles in the given order.

///|
pub(all) struct RotateNode {
  mut position_node : Node
  mut rotation_node : Node
  /// `_order`, part of the cache key.
  mut _order : String
}

///|
pub impl NodeClass for RotateNode with fn class_name(_) {
  "RotateNode"
}

///|
pub impl NodeClass for RotateNode with fn children(self, _, out) {
  push_child(out, "positionNode", Some(self.position_node))
  push_child(out, "rotationNode", Some(self.rotation_node))
}

///|
pub impl NodeClass for RotateNode with fn custom_cache_key(self, _) {
  hash_string(self._order)
}

///|
pub impl NodeClass for RotateNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  self.position_node.get_node_type(builder)
}

///|
pub impl NodeClass for RotateNode with fn setup(self, node, builder) {
  let rotation_node = self.rotation_node
  let position_node = self.position_node
  let node_type = node.get_node_type(builder)
  if node_type == Some("vec2") {
    let cos_angle = rotation_node.cos()
    let sin_angle = rotation_node.sin()
    let rotation_matrix = mat2_of([
      cos_angle,
      sin_angle,
      sin_angle.negate(),
      cos_angle,
    ])
    Some(rotation_matrix.mul(position_node))
  } else {
    let rotation = rotation_node
    let order = self._order
    let rotation_x_matrix = mat4_of([
      vec4_of([1.0, 0.0, 0.0, 0.0]),
      vec4_of([0.0, cos(rotation.x()), sin(rotation.x()), 0.0]),
      vec4_of([0.0, sin(rotation.x()).negate(), cos(rotation.x()), 0.0]),
      vec4_of([0.0, 0.0, 0.0, 1.0]),
    ])
    let rotation_y_matrix = mat4_of([
      vec4_of([cos(rotation.y()), 0.0, sin(rotation.y()).negate(), 0.0]),
      vec4_of([0.0, 1.0, 0.0, 0.0]),
      vec4_of([sin(rotation.y()), 0.0, cos(rotation.y()), 0.0]),
      vec4_of([0.0, 0.0, 0.0, 1.0]),
    ])
    let rotation_z_matrix = mat4_of([
      vec4_of([cos(rotation.z()), sin(rotation.z()), 0.0, 0.0]),
      vec4_of([sin(rotation.z()).negate(), cos(rotation.z()), 0.0, 0.0]),
      vec4_of([0.0, 0.0, 1.0, 0.0]),
      vec4_of([0.0, 0.0, 0.0, 1.0]),
    ])
    let matrix_map = fn(axis : Int32) -> Node {
      let c = if axis < order.length() {
        order.unsafe_substring(start=axis, end=axis + 1)
      } else {
        ""
      }
      match c {
        "X" => rotation_x_matrix
        "Y" => rotation_y_matrix
        "Z" => rotation_z_matrix
        _ =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'mul')",
          )
      }
    }
    let matrix_chain = matrix_map(0).mul(matrix_map(1)).mul(matrix_map(2))
    Some(matrix_chain.mul(vec4_of([position_node, 1.0])).xyz())
  }
}

///|
pub impl NodeClass for RotateNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("order", @core.JsValue::of(self._order))
}

///|
pub impl NodeClass for RotateNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self._order = @webgl.js_to_string(data.get("order"))
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn RotateNode::construct(
  _node : Node,
  position_node : Node,
  rotation_node : Node,
  order : String,
) -> RotateNode {
  { position_node, rotation_node, _order: order, }
}

///|
/// `new RotateNode( positionNode, rotationNode, order = 'XYZ' )`.
pub fn RotateNode::new(
  position_node : Node,
  rotation_node : Node,
  order~ : String = "XYZ",
) -> Node {
  let node = Node::alloc()
  node.set_class(
    RotateNode::construct(node, position_node, rotation_node, order),
  )
}

///|
pub fn RotateNode::of(node : Node) -> RotateNode? {
  match node.class_payload("RotateNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn utils_rotate_node_of(node : Node, name : String) -> RotateNode {
  match RotateNode::of(node) {
    Some(r) => r
    None => abort("TypeError: node.\{name} is not a function")
  }
}

///|
/// `setOrder( value )`.
pub fn Node::set_order(self : Node, value : String) -> Node {
  utils_rotate_node_of(self, "setOrder")._order = value
  self
}

///|
/// `getOrder()`.
pub fn Node::get_order(self : Node) -> String {
  utils_rotate_node_of(self, "getOrder")._order
}

///|
/// `rotate( position, rotation, order )` (`nodeProxy( RotateNode )`).
pub fn rotate(
  position_node : &IntoTsl,
  rotation_node : &IntoTsl,
  order? : String,
) -> Node {
  let position_node = operator_node_required(
    tsl_proxy_arg(position_node.to_tsl()),
  )
  let rotation_node = operator_node_required(
    tsl_proxy_arg(rotation_node.to_tsl()),
  )
  match order {
    Some(o) => RotateNode::new(position_node, rotation_node, order=o)
    None => RotateNode::new(position_node, rotation_node)
  }
}
