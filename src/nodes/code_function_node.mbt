// nodes/code/FunctionNode.js: a shader-language function parsed by the backend's
// `NodeParser` (the class was ported by the foundation; NodeBuilder creates it).
// `wgslFn( code )` returns the `FunctionNode`; `f.call([a, b])` is upstream's `f( a, b )`.

///|
pub(all) struct FunctionNode {
  code_node : CodeNode
}

///|
pub impl NodeClass for FunctionNode with fn class_name(_) {
  "FunctionNode"
}

///|
pub impl NodeClass for FunctionNode with fn parent(self) {
  Some(self.code_node)
}

///|
pub impl NodeClass for FunctionNode with fn generate_uses_output(_) {
  true
}

///|
pub impl NodeClass for FunctionNode with fn generate_node_type(
  _,
  node,
  builder,
  _,
) {
  Some(FunctionNode::get_node_function(node, builder).type_)
}

///|
pub impl NodeClass for FunctionNode with fn get_member_type(
  _,
  node,
  builder,
  name,
) {
  let type_ = match node.get_node_type(builder) {
    Some(t) => t
    None => "null"
  }
  match builder.get_struct_type_node(type_) {
    Some(struct_type) => struct_type.get_member_type(builder, name)
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'getMemberType')",
      )
  }
}

///|
pub impl NodeClass for FunctionNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let node_function = FunctionNode::get_node_function(node, builder)
  let node_data = builder.get_data_from_node(node)
  let type_ = node_function.type_
  let property_name = match node_data.function_property_name {
    Some(p) => p
    None => {
      // The includes and the function code are generated once per builder and shader
      // stage, further calls only need the function name.
      self.code_node.generate_code(node, builder) |> ignore
      let name = node_function.name
      let node_code = builder.get_code_from_node(node, type_)
      if name != "" {
        // use a custom property name
        node_code.name = name
        builder.register_declaration(Code(node_code))
      }
      let property_name = builder.get_property_name(Code(node_code))
      node_code.code = node_function.get_code(name=property_name) + "\n"
      node_data.function_property_name = Some(property_name)
      property_name
    }
  }
  if output == Some("property") {
    Some(property_name)
  } else {
    Some(builder.format("\{property_name}()", Some(type_), output))
  }
}

///|
/// `new FunctionNode( code = '', includes = [], language = '' )`.
pub fn FunctionNode::new(
  code~ : String = "",
  includes~ : Array[Node] = [],
  language~ : String = "",
) -> Node {
  let node = Node::alloc(node_type="code")
  let code_node = CodeNode::construct(node, code, includes, language)
  node.set_class(FunctionNode::{ code_node, })
}

///|
pub fn FunctionNode::of(node : Node) -> FunctionNode? {
  match node.class_payload("FunctionNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `getInputs( builder )`.
pub fn FunctionNode::get_inputs(
  node : Node,
  builder : NodeBuilder,
) -> Array[NodeFunctionInput] {
  FunctionNode::get_node_function(node, builder).inputs
}

///|
/// `getNodeFunction( builder )`: the parsed function, once per builder and stage.
pub fn FunctionNode::get_node_function(
  node : Node,
  builder : NodeBuilder,
) -> NodeFunction {
  let node_data = builder.get_data_from_node(node)
  match node_data.node_function {
    Some(f) => f
    None => {
      let code = match CodeNode::of(node) {
        Some(c) => c.code
        None => ""
      }
      let parser = match builder.parser {
        Some(p) => p
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'parseFunction')",
          )
      }
      let node_function = match parser.parse_function(code) {
        Some(f) => f
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'type')",
          )
      }
      node_data.node_function = Some(node_function)
      node_function
    }
  }
}

///|
/// `nativeFn( code, includes = [], language = '' )`: the `FunctionNode`, called with
/// `Node::call`.
fn function_node_native_fn(
  code : String,
  includes : Array[Node],
  language : String,
) -> Node {
  FunctionNode::new(code~, includes~, language~)
}

///|
/// `glslFn( code, includes )`.
pub fn glsl_fn(code : String, includes~ : Array[Node] = []) -> Node {
  function_node_native_fn(code, includes, "glsl")
}

///|
/// `wgslFn( code, includes )`.
pub fn wgsl_fn(code : String, includes~ : Array[Node] = []) -> Node {
  function_node_native_fn(code, includes, "wgsl")
}
