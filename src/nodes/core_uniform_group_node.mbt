// nodes/core/UniformGroupNode.js

///|
/// Groups uniforms so they are updated and bound together.
pub(all) struct UniformGroupNode {
  mut shared : Bool
  mut order : Int32
}

///|
pub impl NodeClass for UniformGroupNode with fn class_name(_) {
  "UniformGroupNode"
}

///|
pub impl NodeClass for UniformGroupNode with fn has_flag(_, flag) {
  flag == "isUniformGroup"
}

///|
pub impl NodeClass for UniformGroupNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for UniformGroupNode with fn update(_, node, _) {
  node.set_needs_update(true)
  None
}

///|
pub impl NodeClass for UniformGroupNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("name", uniform_group_js_name(node.name))
  data.set("version", @core.JsValue::of(node.version.to_double()))
  data.set("shared", @core.JsValue::of(self.shared))
}

///|
pub impl NodeClass for UniformGroupNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  let name = data.get("name")
  node.name = if name.is_null() || name.is_undefined() {
    None
  } else {
    Some(name.cast())
  }
  let version : Double = data.get("version").cast()
  node.version = version.to_int()
  self.shared = data.get("shared").cast()
}

///|
/// The constructor body; a `null` update type is stored as `""`.
pub fn UniformGroupNode::construct(
  node : Node,
  name : String,
  shared : Bool,
  order : Int32,
  update_type : String?,
) -> UniformGroupNode {
  node.name = Some(name)
  node.update_type = update_type.unwrap_or("")
  { shared, order, }
}

///|
/// `new UniformGroupNode( name, shared = false, order = 1, updateType = null )`.
pub fn UniformGroupNode::new(
  name : String,
  shared~ : Bool = false,
  order~ : Int32 = 1,
  update_type? : String,
) -> Node {
  let node = Node::alloc(node_type="string")
  node.set_class(
    UniformGroupNode::construct(node, name, shared, order, update_type),
  )
}

///|
pub fn UniformGroupNode::of(node : Node) -> UniformGroupNode? {
  match node.class_payload("UniformGroupNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn uniform_group_js_name(name : String?) -> @core.JsValue {
  match name {
    Some(n) => @core.JsValue::of(n)
    None => @core.JsValue::null()
  }
}

///|
/// `uniformGroup( name, order = 1, updateType = null )`.
pub fn uniform_group(
  name : String,
  order~ : Int32 = 1,
  update_type? : String,
) -> Node {
  UniformGroupNode::new(name, shared=false, order~, update_type?)
}

///|
/// `sharedUniformGroup( name, order = 0, updateType = null )`.
pub fn shared_uniform_group(
  name : String,
  order~ : Int32 = 0,
  update_type? : String,
) -> Node {
  UniformGroupNode::new(name, shared=true, order~, update_type?)
}

///|
pub let frame_group : Node = module_nodes(
  "nodes/core/UniformGroupNode.js:frameGroup",
  fn() {
    shared_uniform_group("frame", order=0, update_type=NodeUpdateType::frame())
  },
)

///|
pub let render_group : Node = module_nodes(
  "nodes/core/UniformGroupNode.js:renderGroup",
  fn() {
    shared_uniform_group(
      "render",
      order=0,
      update_type=NodeUpdateType::render(),
    )
  },
)

///|
pub let object_group : Node = module_nodes(
  "nodes/core/UniformGroupNode.js:objectGroup",
  fn() {
    uniform_group("object", order=1, update_type=NodeUpdateType::object())
  },
)
