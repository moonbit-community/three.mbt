// nodes/accessors/Object3DNode.js: uniforms derived from an object's transform.

///|
let _object3d_node_sphere : @math.Sphere = @math.Sphere::new()

///|
/// An object passes to TSL functions as itself (`skinning( mesh )`, `batch( mesh )`).
pub impl IntoTsl for @core.Object3D with fn to_tsl(self) {
  Js(@core.JsValue::of(self))
}

///|
pub(all) struct Object3DNode {
  mut scope : String
  mut object3d : @core.Object3D?
  uniform_node : Node
}

///|
/// `Object3DNode.WORLD_MATRIX` and the other scopes.
pub fn Object3DNode::world_matrix() -> String {
  "worldMatrix"
}

///|
pub fn Object3DNode::position() -> String {
  "position"
}

///|
pub fn Object3DNode::scale() -> String {
  "scale"
}

///|
pub fn Object3DNode::view_position() -> String {
  "viewPosition"
}

///|
pub fn Object3DNode::direction() -> String {
  "direction"
}

///|
pub fn Object3DNode::radius() -> String {
  "radius"
}

///|
pub impl NodeClass for Object3DNode with fn class_name(_) {
  "Object3DNode"
}

///|
pub impl NodeClass for Object3DNode with fn children(self, _, out) {
  push_child(out, "uniformNode", Some(self.uniform_node))
}

///|
pub impl NodeClass for Object3DNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for Object3DNode with fn is_cacheable(_, _, _) {
  false
}

///|
fn object3d_node_type(scope : String) -> String? {
  if scope == Object3DNode::world_matrix() {
    Some("mat4")
  } else if scope == Object3DNode::position() ||
    scope == Object3DNode::view_position() ||
    scope == Object3DNode::direction() ||
    scope == Object3DNode::scale() {
    Some("vec3")
  } else if scope == Object3DNode::radius() {
    Some("float")
  } else {
    None
  }
}

///|
pub impl NodeClass for Object3DNode with fn generate_node_type(self, _, _, _) {
  object3d_node_type(self.scope)
}

///|
pub impl NodeClass for Object3DNode with fn update(self, _, frame) {
  Object3DNode::update_base(self, frame)
  None
}

///|
pub impl NodeClass for Object3DNode with fn generate(self, _, builder, _) {
  match object3d_node_type(self.scope) {
    Some(t) => self.uniform_node.node_type = Some(t)
    None => ()
  }
  Some(self.uniform_node.build(builder))
}

///|
pub impl NodeClass for Object3DNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("scope", @core.JsValue::of(self.scope))
}

///|
pub impl NodeClass for Object3DNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self.scope = data.get("scope").cast()
}

///|
/// `uniformNode.value || new Vector3()`.
fn object3d_node_vector(uniform_node : Node) -> @math.Vector3 {
  match InputNode::get_value(uniform_node) {
    Vector3(v) => v
    _ => {
      let v = @math.Vector3::new(0.0, 0.0, 0.0)
      InputNode::set_value(uniform_node, Vector3(v))
      v
    }
  }
}

///|
/// Object3DNode's `update( frame )`.
pub fn Object3DNode::update_base(
  self : Object3DNode,
  frame : NodeFrame,
) -> Unit {
  let object = self.object3d.unwrap()
  let uniform_node = self.uniform_node
  let scope = self.scope
  if scope == Object3DNode::world_matrix() {
    InputNode::set_value(uniform_node, Matrix4(object.matrix_world))
  } else if scope == Object3DNode::position() {
    object3d_node_vector(uniform_node).set_from_matrix_position(
      object.matrix_world,
    )
    |> ignore
  } else if scope == Object3DNode::scale() {
    object3d_node_vector(uniform_node).set_from_matrix_scale(
      object.matrix_world,
    )
    |> ignore
  } else if scope == Object3DNode::direction() {
    object.get_world_direction(object3d_node_vector(uniform_node)) |> ignore
  } else if scope == Object3DNode::view_position() {
    let camera = frame.camera.unwrap()
    let v = object3d_node_vector(uniform_node)
    v.set_from_matrix_position(object.matrix_world) |> ignore
    v.apply_matrix4(camera_data(camera).matrix_world_inverse) |> ignore
  } else if scope == Object3DNode::radius() {
    let geometry = frame.object.unwrap().get_geometry().unwrap()
    if geometry.bounding_sphere is None {
      geometry.compute_bounding_sphere()
    }
    _object3d_node_sphere
    .copy(geometry.bounding_sphere.unwrap())
    .apply_matrix4(object.matrix_world)
    |> ignore
    InputNode::set_value(uniform_node, Number(_object3d_node_sphere.radius))
  }
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn Object3DNode::construct(
  node : Node,
  scope : String,
  object3d : @core.Object3D?,
) -> Object3DNode {
  node.update_type = NodeUpdateType::object()
  { scope, object3d, uniform_node: UniformNode::new(Null), }
}

///|
/// `new Object3DNode( scope, object3d = null )`.
pub fn Object3DNode::new(scope : String, object3d? : @core.Object3D) -> Node {
  let node = Node::alloc()
  node.set_class(Object3DNode::construct(node, scope, object3d))
}

///|
pub fn Object3DNode::of(node : Node) -> Object3DNode? {
  match node.class_payload("Object3DNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `objectDirection( object3d )`.
pub fn object_direction(object3d : @core.Object3D) -> Node {
  Object3DNode::new(Object3DNode::direction(), object3d~)
}

///|
/// `objectWorldMatrix( object3d )`.
pub fn object_world_matrix(object3d : @core.Object3D) -> Node {
  Object3DNode::new(Object3DNode::world_matrix(), object3d~)
}

///|
/// `objectPosition( object3d )`.
pub fn object_position(object3d : @core.Object3D) -> Node {
  Object3DNode::new(Object3DNode::position(), object3d~)
}

///|
/// `objectScale( object3d )`.
pub fn object_scale(object3d : @core.Object3D) -> Node {
  Object3DNode::new(Object3DNode::scale(), object3d~)
}

///|
/// `objectViewPosition( object3d )`.
pub fn object_view_position(object3d : @core.Object3D) -> Node {
  Object3DNode::new(Object3DNode::view_position(), object3d~)
}

///|
/// `objectRadius( object3d )`.
pub fn object_radius(object3d : @core.Object3D) -> Node {
  Object3DNode::new(Object3DNode::radius(), object3d~)
}
