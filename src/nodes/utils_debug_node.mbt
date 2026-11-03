// nodes/utils/DebugNode.js: logs the shader code generated up to a node (or hands the
// snippet to a callback). TSL `debug` is `debug_` here (`debug` is a prelude function).

///|
pub(all) struct DebugNode {
  mut node : Node
  /// `callback( builder, snippet )`; `null` logs the code.
  mut callback : ((NodeBuilder, String) -> Unit)?
}

///|
pub impl NodeClass for DebugNode with fn class_name(_) {
  "DebugNode"
}

///|
pub impl NodeClass for DebugNode with fn children(self, _, out) {
  push_child(out, "node", Some(self.node))
}

///|
pub impl NodeClass for DebugNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for DebugNode with fn generate_node_type(self, _, builder, _) {
  self.node.get_node_type(builder)
}

///|
pub impl NodeClass for DebugNode with fn setup(self, _, builder) {
  self.node.build_node(builder)
}

///|
pub impl NodeClass for DebugNode with fn analyze(self, _, builder, _) {
  self.node.build_output(builder, NoOutput) |> ignore
}

///|
extern "js" fn utils_debug_node_untab(code : String) -> String =
  #|(c) => c.replace( /^\t/mg, '' )

///|
pub impl NodeClass for DebugNode with fn generate(self, _, builder, _) {
  let callback = self.callback
  let snippet = self.node.build(builder)
  match callback {
    Some(f) => f(builder, snippet)
    None => {
      let stage = operator_node_str(builder.shader_stage)
      let title = "--- TSL debug - " + stage + " shader ---"
      let border = "-".repeat(title.length())
      let mut code = ""
      code += "// #" + title + "#\n"
      code += utils_debug_node_untab(builder.flow.code) + "\n"
      code += "/* ... */ " + snippet + " /* ... */\n"
      code += "// #" + border + "#\n"
      @core.log(code)
    }
  }
  Some(snippet)
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn DebugNode::construct(
  _node : Node,
  node : Node,
  callback : ((NodeBuilder, String) -> Unit)?,
) -> DebugNode {
  { node, callback, }
}

///|
/// `new DebugNode( node, callback = null )`.
pub fn DebugNode::new(
  node : Node,
  callback? : (NodeBuilder, String) -> Unit,
) -> Node {
  let n = Node::alloc()
  n.set_class(DebugNode::construct(n, node, callback))
}

///|
pub fn DebugNode::of(node : Node) -> DebugNode? {
  match node.class_payload("DebugNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `debug( node, callback = null )`: adds the `DebugNode` to the current stack.
pub fn debug_(
  node : &IntoTsl,
  callback? : (NodeBuilder, String) -> Unit,
) -> Node {
  DebugNode::new(node_object(node.to_tsl()), callback?).to_stack()
}

///|
/// `node.debug( callback )`.
pub fn Node::debug(
  self : Node,
  callback? : (NodeBuilder, String) -> Unit,
) -> Node {
  self.chain(
    fn(p) {
      let node = p.get(0).unwrap_or(Undefined)
      debug_(node, callback?)
    },
    [],
  )
}

///|
pub fn Node::debug_assign(
  self : Node,
  callback? : (NodeBuilder, String) -> Unit,
) -> Unit {
  self.chain_assign(
    fn(p) {
      let node = p.get(0).unwrap_or(Undefined)
      debug_(node, callback?)
    },
    [],
  )
}
