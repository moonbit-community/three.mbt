// nodes/core/ConstNode.js

///|
pub(all) struct ConstNode {
  input : InputNode
  mut is_weak : Bool
}

///|
pub impl NodeClass for ConstNode with fn class_name(_) {
  "ConstNode"
}

///|
pub impl NodeClass for ConstNode with fn parent(self) {
  Some(self.input)
}

///|
pub impl NodeClass for ConstNode with fn has_flag(self, flag) {
  flag == "isConstNode" || self.input.has_flag(flag)
}

///|
pub impl NodeClass for ConstNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for ConstNode with fn generate(self, node, builder, output) {
  let type_ = node.get_node_type(builder)
  if const_node_is_num(type_) && const_node_is_num(output) {
    let mut value = self.input.value
    if value is Number(x) {
      if type_ == Some("int") {
        value = Number(const_node_trunc(x))
      } else if type_ == Some("uint") {
        value = Number(if x >= 0.0 { const_node_trunc(x) } else { 0.0 })
      }
    }
    return Some(builder.generate_const(output.unwrap(), value~))
  }
  Some(builder.format(ConstNode::generate_const(node, builder), type_, output))
}

///|
pub impl NodeClass for ConstNode with fn serialize(self, node, data) {
  self.input.serialize(node, data)
  data.set("isWeak", @core.JsValue::of(self.is_weak))
}

///|
pub impl NodeClass for ConstNode with fn deserialize(self, node, data) {
  self.input.deserialize(node, data)
  self.is_weak = const_node_js_is_true(data.get("isWeak"))
}

///|
pub fn ConstNode::construct(node : Node, value : TslValue) -> ConstNode {
  { input: InputNode::construct(node, value), is_weak: false, }
}

///|
/// `new ConstNode( value, nodeType = null )`.
pub fn ConstNode::new(value : TslValue, node_type? : String) -> Node {
  let node = Node::alloc(node_type?)
  let const_ = ConstNode::construct(node, value)
  const_.input.class_ = const_
  node.set_class(const_)
}

///|
pub impl InputNodeClass for ConstNode with fn input_parent(self) {
  Some(self.input)
}

///|
pub fn ConstNode::of(node : Node) -> ConstNode? {
  match node.class_payload("ConstNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `generateConst( builder )`: the constant's shader code.
pub fn ConstNode::generate_const(node : Node, builder : NodeBuilder) -> String {
  let value = InputNode::get_value(node)
  builder.generate_const(node.get_node_type(builder).unwrap_or("null"), value~)
}

///|
/// `_regNum.test( type )`: `/float|u?int/` on `String( type )`.
fn const_node_is_num(type_ : String?) -> Bool {
  let s = match type_ {
    Some(s) => s
    None => "null"
  }
  s.contains("float") || s.contains("int")
}

///|
extern "js" fn const_node_trunc(x : Double) -> Double = "Math.trunc"

///|
extern "js" fn const_node_js_is_true(value : @core.JsValue) -> Bool = "(v) => v === true"
