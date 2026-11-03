// nodes/accessors/UserDataNode.js: a reference to a property of `object.userData`.

///|
pub(all) struct UserDataNode {
  reference_node : ReferenceNode
  user_data : @core.JsValue?
}

///|
pub impl NodeClass for UserDataNode with fn class_name(_) {
  "UserDataNode"
}

///|
pub impl NodeClass for UserDataNode with fn parent(self) {
  Some(self.reference_node)
}

///|
pub impl NodeClass for UserDataNode with fn update_reference(self, _, state) {
  let user_data = match self.user_data {
    Some(u) => Some(u)
    None =>
      match reference_state_object(state) {
        Some(o) => Some(o.user_data)
        None =>
          abort(
            "TypeError: Cannot read properties of null (reading 'userData')",
          )
      }
  }
  self.reference_node.reference = user_data.map(fn(u) { Js(u) })
  self.reference_node.reference_identity()
}

///|
/// `new UserDataNode( property, inputType, userData = null )`.
pub fn UserDataNode::new(
  property : String,
  input_type : String?,
  user_data? : @core.JsValue,
) -> Node {
  let node = Node::alloc()
  let reference_node = ReferenceNode::construct(
    node,
    property,
    input_type,
    user_data.map(fn(u) { Js(u) }),
    None,
  )
  node.set_class(UserDataNode::{ reference_node, user_data, })
}

///|
pub fn UserDataNode::of(node : Node) -> UserDataNode? {
  match node.class_payload("UserDataNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `userData( name, inputType, userData )`.
pub fn user_data(
  name : String,
  input_type : String,
  user_data? : @core.JsValue,
) -> Node {
  UserDataNode::new(name, Some(input_type), user_data?)
}
