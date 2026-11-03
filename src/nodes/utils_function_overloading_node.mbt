// nodes/utils/FunctionOverloadingNode.js: picks the layout `Fn` whose input types
// match the arguments best.

///|
pub(all) struct FunctionOverloadingNode {
  mut function_nodes : Array[Node]
  mut parameters_nodes : Array[Node]
  mut _candidate_fn : Node?
}

///|
pub impl NodeClass for FunctionOverloadingNode with fn class_name(_) {
  "FunctionOverloadingNode"
}

///|
pub impl NodeClass for FunctionOverloadingNode with fn children(self, _, out) {
  push_children(
    out,
    "functionNodes",
    self.function_nodes.map(fn(n) { Some(n) }),
  )
  push_children(
    out,
    "parametersNodes",
    self.parameters_nodes.map(fn(n) { Some(n) }),
  )
}

///|
pub impl NodeClass for FunctionOverloadingNode with fn is_cacheable(_, _, _) {
  false
}

///|
fn utils_function_overloading_layout(function_node : Node) -> FnLayout? {
  match FnNode::of(function_node) {
    Some(f) => ShaderNodeInternal::get_layout(f.shader_node)
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'layout')")
  }
}

///|
/// `getCandidateFn( builder )`: the `Fn` with the most matching input types.
pub fn FunctionOverloadingNode::get_candidate_fn(
  self : FunctionOverloadingNode,
  builder : NodeBuilder,
) -> Node? {
  let params = self.parameters_nodes
  let mut candidate_fn = self._candidate_fn
  if candidate_fn is None {
    let mut best_candidate_fn : Node? = None
    let mut best_score = -1
    for function_node in self.function_nodes {
      let layout = match utils_function_overloading_layout(function_node) {
        Some(l) => l
        None =>
          abort("THREE.FunctionOverloadingNode: FunctionNode must be a layout.")
      }
      let inputs = layout.inputs
      if params.length() == inputs.length() {
        let mut current_score = 0
        for i in 0..<params.length() {
          let param = params[i]
          let input = inputs[i]
          if builder.get_vector_type(param.get_node_type(builder)) ==
            Some(input.type_) {
            current_score += 1
          }
        }
        if current_score > best_score {
          best_candidate_fn = Some(function_node)
          best_score = current_score
        }
      }
    }
    candidate_fn = best_candidate_fn
    self._candidate_fn = candidate_fn
  }
  candidate_fn
}

///|
fn utils_function_overloading_candidate(
  overloading : FunctionOverloadingNode,
  builder : NodeBuilder,
) -> Node {
  match overloading.get_candidate_fn(builder) {
    Some(f) => f
    None =>
      abort("TypeError: Cannot read properties of null (reading 'shaderNode')")
  }
}

///|
pub impl NodeClass for FunctionOverloadingNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  let candidate_fn = utils_function_overloading_candidate(self, builder)
  match utils_function_overloading_layout(candidate_fn) {
    Some(layout) => layout.type_
    None => abort("TypeError: Cannot read properties of null (reading 'type')")
  }
}

///|
pub impl NodeClass for FunctionOverloadingNode with fn setup(self, _, builder) {
  let candidate_fn = utils_function_overloading_candidate(self, builder)
  Some(candidate_fn.call(self.parameters_nodes.map(fn(n) -> &IntoTsl { n })))
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn FunctionOverloadingNode::construct(
  node : Node,
  function_nodes : Array[Node],
  parameters_nodes : Array[Node],
) -> FunctionOverloadingNode {
  node.global = true
  { function_nodes, parameters_nodes, _candidate_fn: None, }
}

///|
/// `new FunctionOverloadingNode( functionNodes = [], ...parametersNodes )`.
pub fn FunctionOverloadingNode::new(
  function_nodes~ : Array[Node] = [],
  parameters_nodes~ : Array[Node] = [],
) -> Node {
  let node = Node::alloc()
  node.set_class(
    FunctionOverloadingNode::construct(node, function_nodes, parameters_nodes),
  )
}

///|
pub fn FunctionOverloadingNode::of(node : Node) -> FunctionOverloadingNode? {
  match node.class_payload("FunctionOverloadingNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `overloadingFn( functionNodes )`: a function taking the call arguments.
pub fn overloading_fn(
  function_nodes : Array[Node],
) -> (Array[&IntoTsl]) -> Node {
  fn(params) {
    let parameters_nodes = params.map(fn(p) {
      operator_node_required(tsl_proxy_arg(p.to_tsl()))
    })
    FunctionOverloadingNode::new(function_nodes~, parameters_nodes~)
  }
}
