// nodes/core/InputNode.js: the base of nodes holding a value (constants, uniforms,
// buffers). `getInputType`, overridden by UniformNode, TextureNode, BufferNode, ...,
// and UniformNode's `getUniformHash` dispatch through `InputNodeClass`.

///|
/// Virtual methods of the `InputNode` family; defaults walk to the parent payload.
pub(open) trait InputNodeClass {
  /// The superclass payload in the family, `None` for `InputNode`.
  fn input_parent(Self) -> &InputNodeClass? = _
  /// `getInputType( builder )`.
  fn get_input_type(Self, Node, NodeBuilder) -> String? = _
  /// `getUniformHash( builder )`, introduced by `UniformNode`.
  fn get_uniform_hash(Self, Node, NodeBuilder) -> String = _
}

///|
impl InputNodeClass with fn input_parent(_) {
  None
}

///|
impl InputNodeClass with fn get_input_type(self, node, builder) {
  match self.input_parent() {
    Some(p) => p.get_input_type(node, builder)
    None => node.get_node_type(builder)
  }
}

///|
impl InputNodeClass with fn get_uniform_hash(self, node, builder) {
  match self.input_parent() {
    Some(p) => p.get_uniform_hash(node, builder)
    None => node.get_hash(builder)
  }
}

///|
pub(all) struct InputNode {
  mut value : TslValue
  /// `'low'`, `'medium'`, `'high'` or `null`.
  mut precision : String?
  /// The most derived payload of the family, set at the end of construction.
  mut class_ : &InputNodeClass
}

///|
/// A placeholder class until construction installs the most derived payload.
priv struct InputNodeUnset {}

///|
impl InputNodeClass for InputNodeUnset

///|
pub impl InputNodeClass for InputNode

///|
pub impl NodeClass for InputNode with fn class_name(_) {
  "InputNode"
}

///|
pub impl NodeClass for InputNode with fn has_flag(_, flag) {
  flag == "isInputNode"
}

///|
pub impl NodeClass for InputNode with fn children(_, node, out) {
  push_tsl_child(out, "value", InputNode::get_value(node))
}

///|
pub impl NodeClass for InputNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for InputNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for InputNode with fn generate_node_type(self, node, _, _) {
  match node.node_type {
    None => get_value_type(self.value)
    t => t
  }
}

///|
pub impl NodeClass for InputNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("value", input_node_value_to_js(self.value))
  let value_type = get_value_type(self.value)
  data.set("valueType", input_node_js_string(value_type))
  data.set("nodeType", input_node_js_string(node.node_type))
  if value_type == Some("ArrayBuffer") {
    data.set(
      "value",
      @core.JsValue::of(array_buffer_to_base64(data.get("value").cast())),
    )
  }
  data.set("precision", input_node_js_string(self.precision))
}

///|
pub impl NodeClass for InputNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  node.node_type = input_node_js_to_string(data.get("nodeType"))
  let value = data.get("value")
  self.value = if input_node_js_is_array(value) {
    let params : Array[Double] = value.cast()
    get_value_from_type(
      input_node_js_to_string(data.get("valueType")),
      params.map(fn(p) { TslValue::Number(p) }),
    )
  } else {
    input_node_js_to_value(value)
  }
  self.precision = match input_node_js_to_string(data.get("precision")) {
    Some("") | None => None
    p => p
  }
  if input_node_js_is_array(value) {
    let array : Array[Double] = value.cast()
    match self.value {
      Vector2(v) => v.from_array(array) |> ignore
      Vector3(v) => v.from_array(array) |> ignore
      Vector4(v) => v.from_array(array) |> ignore
      Color(c) => c.from_array(array) |> ignore
      Matrix2(m) => m.from_array(array) |> ignore
      Matrix3(m) => m.from_array(array) |> ignore
      Matrix4(m) => m.from_array(array) |> ignore
      _ => ()
    }
  }
}

///|
pub impl NodeClass for InputNode with fn generate(_, _, _, _) {
  @core.warn("Abstract function.")
  None
}

///|
/// The constructor body: `super( nodeType )` has run in `Node::alloc`.
pub fn InputNode::construct(_node : Node, value : TslValue) -> InputNode {
  { value, precision: None, class_: InputNodeUnset::{ }, }
}

///|
/// `new InputNode( value, nodeType = null )`.
pub fn InputNode::new(value : TslValue, node_type? : String) -> Node {
  let node = Node::alloc(node_type?)
  let input = InputNode::construct(node, value)
  input.class_ = input
  node.set_class(input)
}

///|
pub fn InputNode::of(node : Node) -> InputNode? {
  match node.class_payload("InputNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `node.value` of an `InputNode` (or subclass); aborts for other nodes.
pub fn InputNode::get_value(node : Node) -> TslValue {
  match InputNode::of(node) {
    Some(i) => i.value
    None => abort("InputNode::get_value: \{node.type_()} is not an InputNode")
  }
}

///|
pub fn InputNode::set_value(node : Node, value : TslValue) -> Unit {
  match InputNode::of(node) {
    Some(i) => i.value = value
    None => abort("InputNode::set_value: \{node.type_()} is not an InputNode")
  }
}

///|
/// `getInputType( builder )`, dispatched to the most derived class.
pub fn InputNode::get_input_type(node : Node, builder : NodeBuilder) -> String? {
  match InputNode::of(node) {
    Some(i) => i.class_.get_input_type(node, builder)
    None =>
      abort("InputNode::get_input_type: \{node.type_()} is not an InputNode")
  }
}

///|
/// `setPrecision( precision )`, chained.
pub fn Node::set_precision(self : Node, precision : String?) -> Node {
  match InputNode::of(self) {
    Some(i) => i.precision = precision
    None => abort("setPrecision: \{self.type_()} is not an InputNode")
  }
  self
}

///|
/// Appends the nodes of a `TslValue` property, as `_getChildren` does.
pub fn push_tsl_child(
  out : Array[NodeChild],
  property : String,
  value : TslValue,
) -> Unit {
  match value {
    Node(child_node) => out.push({ property, index: None, child_node, })
    Array(items) =>
      for i, item in items {
        if item is Node(child_node) {
          out.push({ property, index: Some(Index(i)), child_node, })
        }
      }
    Object(object) =>
      for key, item in object {
        if !key.has_prefix("_") && item is Node(child_node) {
          out.push({ property, index: Some(Key(key)), child_node, })
        }
      }
    _ => ()
  }
}

///|
/// `data.value = this.value`, with `value.toArray()` for vectors, colors, matrices.
fn input_node_value_to_js(value : TslValue) -> @core.JsValue {
  match value {
    Undefined => @core.JsValue::undefined()
    Null => @core.JsValue::null()
    Node(n) => @core.JsValue::of(n)
    Number(x) => @core.JsValue::of(x)
    Bool(b) => @core.JsValue::of(b)
    String(s) => @core.JsValue::of(s)
    Vector2(v) => @core.JsValue::of(v.to_array())
    Vector3(v) => @core.JsValue::of(v.to_array())
    Vector4(v) => @core.JsValue::of(v.to_array())
    Color(c) => @core.JsValue::of(c.to_array())
    Matrix2(m) => @core.JsValue::of(m)
    Matrix3(m) => @core.JsValue::of(m.to_array())
    Matrix4(m) => @core.JsValue::of(m.to_array())
    Texture(t) => @core.JsValue::of(t)
    Array(a) => @core.JsValue::of(a.map(input_node_value_to_js))
    Object(o) => {
      let object = @core.JsValue::object()
      for k, v in o {
        object.set(k, input_node_value_to_js(v))
      }
      object
    }
    Shader(f) => @core.JsValue::of(f)
    Js(v) => v
  }
}

///|
fn input_node_js_string(value : String?) -> @core.JsValue {
  match value {
    Some(s) => @core.JsValue::of(s)
    None => @core.JsValue::null()
  }
}

///|
extern "js" fn input_node_js_is_array(value : @core.JsValue) -> Bool = "(v) => Array.isArray(v)"

///|
extern "js" fn input_node_js_type_of(value : @core.JsValue) -> String = "(v) => v === null ? 'null' : typeof v"

///|
fn input_node_js_to_string(value : @core.JsValue) -> String? {
  if input_node_js_type_of(value) == "string" {
    Some(value.cast())
  } else {
    None
  }
}

///|
/// A JSON value back to the `TslValue` it serializes.
fn input_node_js_to_value(value : @core.JsValue) -> TslValue {
  match input_node_js_type_of(value) {
    "undefined" => Undefined
    "null" => Null
    "number" => Number(value.cast())
    "boolean" => Bool(value.cast())
    "string" => String(value.cast())
    _ => Js(value)
  }
}
