// nodes/code/CodeNode.js: raw shader code with includes (the class was ported by the
// foundation for FunctionNode, which NodeBuilder creates).

///|
pub(all) struct CodeNode {
  mut code : String
  mut includes : Array[Node]
  mut language : String
}

///|
pub impl NodeClass for CodeNode with fn class_name(_) {
  "CodeNode"
}

///|
pub impl NodeClass for CodeNode with fn has_flag(_, flag) {
  flag == "isCodeNode"
}

///|
pub impl NodeClass for CodeNode with fn children(self, _, out) {
  push_children(out, "includes", self.includes.map(fn(n) { Some(n) }))
}

///|
pub impl NodeClass for CodeNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for CodeNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for CodeNode with fn generate(self, node, builder, _) {
  Some(self.generate_code(node, builder))
}

///|
pub impl NodeClass for CodeNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("code", @core.JsValue::of(self.code))
  data.set("language", @core.JsValue::of(self.language))
}

///|
pub impl NodeClass for CodeNode with fn deserialize(self, node, data) {
  node.deserialize_base(data)
  self.code = @webgl.js_to_string(data.get("code"))
  self.language = @webgl.js_to_string(data.get("language"))
}

///|
/// The constructor body: `super( 'code' )` has run in `Node::alloc`.
pub fn CodeNode::construct(
  node : Node,
  code : String,
  includes : Array[Node],
  language : String,
) -> CodeNode {
  node.global = true
  { code, includes, language, }
}

///|
/// `new CodeNode( code = '', includes = [], language = '' )`.
pub fn CodeNode::new(
  code~ : String = "",
  includes~ : Array[Node] = [],
  language~ : String = "",
) -> Node {
  let node = Node::alloc(node_type="code")
  node.set_class(CodeNode::construct(node, code, includes, language))
}

///|
pub fn CodeNode::of(node : Node) -> CodeNode? {
  match node.class_payload("CodeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub fn CodeNode::set_includes(
  self : CodeNode,
  includes : Array[Node],
) -> CodeNode {
  self.includes = includes
  self
}

///|
pub fn CodeNode::get_includes(
  self : CodeNode,
  _builder : NodeBuilder,
) -> Array[Node] {
  self.includes
}

///|
/// `CodeNode.prototype.generate( builder )`.
pub fn CodeNode::generate_code(
  self : CodeNode,
  node : Node,
  builder : NodeBuilder,
) -> String {
  let includes = self.get_includes(builder)
  for include_node in includes {
    include_node.build(builder, output="void") |> ignore
  }
  let node_type = match node.get_node_type(builder) {
    Some(t) => t
    None => "null"
  }
  let node_code = builder.get_code_from_node(node, node_type)
  node_code.code = self.code
  node_code.code
}

///|
/// `code( code, includes, language )` (`nodeProxy( CodeNode )`).
pub fn code(code : String, includes? : Array[Node], language? : String) -> Node {
  CodeNode::new(code~, includes?, language?)
}

///|
/// `js( src, includes )`.
pub fn js(src : String, includes? : Array[Node]) -> Node {
  code(src, includes?, language="js")
}

///|
/// `wgsl( src, includes )`.
pub fn wgsl(src : String, includes? : Array[Node]) -> Node {
  code(src, includes?, language="wgsl")
}

///|
/// `glsl( src, includes )`.
pub fn glsl(src : String, includes? : Array[Node]) -> Node {
  code(src, includes?, language="glsl")
}

///|
/// `node.setIncludes( includes )` on a `CodeNode`.
pub fn Node::set_includes(self : Node, includes : Array[Node]) -> Node {
  match CodeNode::of(self) {
    Some(c) => c.set_includes(includes) |> ignore
    None => abort("TypeError: node.setIncludes is not a function")
  }
  self
}
