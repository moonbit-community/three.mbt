// nodes/code/FunctionCallNode.js: a call of a `FunctionNode` (`wgslFn`/`glslFn`, or a
// layout `Fn`'s function) with positional or named parameters. The chained `call` is
// `Node::call` in tsl_core.mbt.

///|
/// `parameters`: an array (positional) or a plain object (by input name).
pub(all) enum FunctionCallParameters {
  Positional(Array[TslValue])
  Named(Map[String, TslValue])
}

///|
pub(all) struct FunctionCallNode {
  mut function_node : Node?
  mut parameters : FunctionCallParameters
}

///|
pub impl NodeClass for FunctionCallNode with fn class_name(_) {
  "FunctionCallNode"
}

///|
pub impl NodeClass for FunctionCallNode with fn children(self, _, out) {
  push_child(out, "functionNode", self.function_node)
  match self.parameters {
    Positional(values) =>
      for i, value in values {
        if value is Node(child_node) {
          out.push({
            property: "parameters",
            index: Some(Index(i)),
            child_node,
          })
        }
      }
    Named(values) =>
      for key, value in values {
        if !key.has_prefix("_") && value is Node(child_node) {
          out.push({
            property: "parameters",
            index: Some(Key(key)),
            child_node,
          })
        }
      }
  }
}

///|
pub impl NodeClass for FunctionCallNode with fn generate_uses_output(_) {
  false
}

///|
fn function_call_node_function(call : FunctionCallNode) -> Node {
  match call.function_node {
    Some(f) => f
    None =>
      abort("TypeError: Cannot read properties of null (reading 'getNodeType')")
  }
}

///|
pub impl NodeClass for FunctionCallNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  function_call_node_function(self).get_node_type(builder)
}

///|
pub impl NodeClass for FunctionCallNode with fn get_member_type(
  self,
  _,
  builder,
  name,
) {
  function_call_node_function(self).get_member_type(builder, name)
}

///|
fn function_call_node_input(value : TslValue) -> Node {
  match value {
    Node(n) => n
    _ => abort("TypeError: node.build is not a function")
  }
}

///|
pub impl NodeClass for FunctionCallNode with fn generate(self, _, builder, _) {
  let params : Array[String] = []
  let function_node = function_call_node_function(self)
  let inputs = FunctionNode::get_inputs(function_node, builder)
  let generate_input = fn(
    node : Node,
    input_node : NodeFunctionInput,
  ) -> String {
    let type_ = input_node.type_
    let pointer = type_ == "pointer"
    if pointer {
      "&" + node.build(builder)
    } else {
      node.build(builder, output=type_)
    }
  }
  match self.parameters {
    Positional(parameters) => {
      if parameters.length() > inputs.length() {
        @core.error(
          "TSL: The number of provided parameters exceeds the expected number of inputs in 'Fn()'.",
        )
        while parameters.length() > inputs.length() {
          parameters.pop() |> ignore
        }
      } else if parameters.length() < inputs.length() {
        @core.error(
          "TSL: The number of provided parameters is less than the expected number of inputs in 'Fn()'.",
        )
        while parameters.length() < inputs.length() {
          parameters.push(Node(float(0)))
        }
      }
      for i in 0..<parameters.length() {
        params.push(
          generate_input(function_call_node_input(parameters[i]), inputs[i]),
        )
      }
    }
    Named(parameters) =>
      for input_node in inputs {
        match parameters.get(input_node.name) {
          Some(Undefined) | None => {
            @core.error("TSL: Input '\{input_node.name}' not found in 'Fn()'.")
            params.push(generate_input(float(0), input_node))
          }
          Some(node) =>
            params.push(
              generate_input(function_call_node_input(node), input_node),
            )
        }
      }
  }
  let function_name = function_node.build(builder, output="property")
  Some("\{function_name}( \{params.join(", ")} )")
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn FunctionCallNode::construct(
  _node : Node,
  function_node : Node?,
  parameters : FunctionCallParameters,
) -> FunctionCallNode {
  { function_node, parameters, }
}

///|
/// `new FunctionCallNode( functionNode = null, parameters = {} )`.
pub fn FunctionCallNode::new(
  function_node? : Node,
  parameters~ : FunctionCallParameters = Named(Map([])),
) -> Node {
  let node = Node::alloc()
  node.set_class(FunctionCallNode::construct(node, function_node, parameters))
}

///|
pub fn FunctionCallNode::of(node : Node) -> FunctionCallNode? {
  match node.class_payload("FunctionCallNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `setParameters( parameters )`.
pub fn Node::set_parameters(
  self : Node,
  parameters : FunctionCallParameters,
) -> Node {
  match FunctionCallNode::of(self) {
    Some(f) => f.parameters = parameters
    None => abort("TypeError: node.setParameters is not a function")
  }
  self
}

///|
/// `getParameters()`.
pub fn Node::get_parameters(self : Node) -> FunctionCallParameters {
  match FunctionCallNode::of(self) {
    Some(f) => f.parameters
    None => abort("TypeError: node.getParameters is not a function")
  }
}

///|
/// `call( func, ...params )`: a `FunctionCallNode` of `func` with `params` (several
/// values, or one node: positional; one array or plain object: as given).
pub fn function_call(func : &IntoTsl, params : Array[TslValue]) -> Node {
  let positional = params.length() > 1 ||
    (params.length() > 0 && params[0] is Node(_))
  let parameters : FunctionCallParameters? = if positional {
    Some(Positional(node_array(params.copy())))
  } else {
    // `nodeObjects( params[ 0 ] )`: converts the members in place; `undefined` stays
    // `undefined`, so the constructor default `{}` applies.
    match params.get(0) {
      Some(Array(values)) => Some(Positional(node_array(values)))
      Some(Object(values)) => Some(Named(node_objects(values)))
      _ => None
    }
  }
  let function_node = match node_object_value(func.to_tsl()) {
    Node(n) => Some(n)
    Undefined | Null => None
    _ => abort("TypeError: functionNode.getNodeType is not a function")
  }
  FunctionCallNode::new(function_node?, parameters?)
}

///|
/// `node.callAssign( ...params )`: assigns `call( node, ...params )` to `node`.
pub fn Node::call_assign(self : Node, params : Array[&IntoTsl]) -> Unit {
  self.chain_assign(
    fn(p) {
      let func = p.get(0).unwrap_or(Undefined)
      let rest = if p.length() > 0 { p[1:].to_owned() } else { [] }
      function_call(func, rest)
    },
    params.map(fn(v) { v.to_tsl() }),
  )
}
