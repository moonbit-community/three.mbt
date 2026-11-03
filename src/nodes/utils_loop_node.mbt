// nodes/utils/LoopNode.js: `for`/`while` loops, `Break()`, `Continue()`.
//
// `Loop( a, b, ..., ( { i, j } ) => { ... } )` is `loop_([a, b], fn(inputs) { ... })`:
// each parameter is a count (a node or number: `for ( int i = 0; i < n; i ++ )`), a
// `bool` node (`while`), or a range object (`loop_range(start=..., end=..., ...)`). The
// body reads the loop variables with `inputs.named("i")`.

///|
pub(all) struct LoopNode {
  /// The converted parameters; the last one is the body `Fn`.
  mut params : Array[TslValue]
}

///|
pub impl NodeClass for LoopNode with fn class_name(_) {
  "LoopNode"
}

///|
pub impl NodeClass for LoopNode with fn children(self, _, out) {
  for i, value in self.params {
    if value is Node(child_node) {
      out.push({ property: "params", index: Some(Index(i)), child_node, })
    }
  }
}

///|
pub impl NodeClass for LoopNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for LoopNode with fn is_cacheable(_, _, _) {
  false
}

///|
/// `getVarName( index )`: `i`, `j`, `k`, ...
pub fn LoopNode::get_var_name(_self : LoopNode, index : Int32) -> String {
  ('i'.to_int() + index).unsafe_to_char().to_string()
}

///|
/// A member of a range parameter (`param.start`, ...); `Undefined` when absent.
fn loop_node_member(param : TslValue, key : String) -> TslValue {
  match param {
    Object(m) => m.get(key).unwrap_or(Undefined)
    _ => Undefined
  }
}

///|
/// `( param.isNode !== true && param[ key ] ) || fallback` for string members.
fn loop_node_string_member(
  param : TslValue,
  key : String,
  fallback : String,
) -> String {
  match param {
    Node(_) => fallback
    _ =>
      match loop_node_member(param, key) {
        String(s) if s != "" => s
        _ => fallback
      }
  }
}

///|
/// `_getInternalParams()`: a lone body loops `while ( true )`.
fn LoopNode::get_internal_params(self : LoopNode) -> Array[TslValue] {
  let params = self.params
  if params.length() > 0 &&
    params[0] is Node(first) &&
    FnNode::of(first) is Some(_) {
    return [Node(bool(true)), params[0]]
  }
  params
}

///|
/// `getProperties( builder )`: builds the body (and a function `update`) once, in a
/// stack of its own.
pub fn LoopNode::get_properties(
  self : LoopNode,
  node : Node,
  builder : NodeBuilder,
) -> NodeProperties {
  let properties = builder.get_node_properties(node)
  if properties.get("stackNode") is Some(_) {
    return properties
  }
  let inputs : Map[String, TslValue] = Map([])
  let params = self.get_internal_params()
  for i in 0..<(params.length() - 1) {
    let param = params[i]
    let name = loop_node_string_member(param, "name", self.get_var_name(i))
    let type_ = loop_node_string_member(param, "type", "int")
    inputs[name] = Node(expression(name, node_type=type_))
  }
  let stack = builder.add_stack()
  let fn_call = match params[params.length() - 1] {
    Node(body) => body.call([TslValue::Object(inputs)])
    _ => abort("TypeError: params[ params.length - 1 ] is not a function")
  }
  properties.set_node(
    "returnsNode",
    fn_call.context(
      value=node_context([
        ("nodeLoop", Node(node)),
        ("nodeBlock", Block(builder.create_block())),
      ]),
    ),
  )
  properties.set_node("stackNode", stack.node)
  let base_param = params[0]
  if loop_node_member(base_param, "update") is Shader(update) &&
    !(base_param is Node(_)) {
    let fn_update_call = fn_(update.f).call([TslValue::Object(inputs)])
    properties.set_node(
      "updateNode",
      fn_update_call.context(value=node_context([("nodeLoop", Node(node))])),
    )
  }
  builder.remove_stack() |> ignore
  properties
}

///|
pub impl NodeClass for LoopNode with fn setup(self, node, builder) {
  // setup properties
  self.get_properties(node, builder) |> ignore
  None
}

///|
/// A loop bound: a number (`generateConst`), a node (built) or anything else as is.
fn loop_node_bound(
  value : TslValue,
  builder : NodeBuilder,
  type_ : String,
) -> TslValue {
  match value {
    Number(_) => String(builder.generate_const(type_, value~))
    Node(n) => String(n.build(builder, output=type_))
    v => v
  }
}

///|
/// `${ value }` of a loop bound.
fn loop_node_bound_string(value : TslValue) -> String {
  match value {
    String(s) => s
    Undefined => "undefined"
    Null => "null"
    Bool(b) => b.to_string()
    Number(n) => @webgl.js_to_string(@core.JsValue::of(n))
    _ => "[object Object]"
  }
}

///|
extern "js" fn loop_node_js_number(value : String) -> Double = "(s) => Number( s )"

///|
extern "js" fn loop_node_strip_update(code : String) -> String =
  #|(c) => c.replace( /\t|;/g, '' )

///|
pub impl NodeClass for LoopNode with fn generate(self, node, builder, _) {
  let properties = self.get_properties(node, builder)
  let params = self.get_internal_params()
  let stack_node = properties.get_node("stackNode").unwrap()
  for i in 0..<(params.length() - 1) {
    let param = params[i]
    let mut is_while = false
    let mut start : TslValue = Null
    let mut end : TslValue = Null
    let mut name = "null"
    let mut type_ = "null"
    let mut condition : TslValue = Null
    let mut update : TslValue = Null
    match param {
      Node(p) =>
        if p.get_node_type(builder) == Some("bool") {
          is_while = true
          type_ = "bool"
          end = String(p.build(builder, output=type_))
        } else {
          type_ = "int"
          name = self.get_var_name(i)
          start = String("0")
          end = String(p.build(builder, output=type_))
          condition = String("<")
        }
      _ => {
        type_ = loop_node_string_member(param, "type", "int")
        name = loop_node_string_member(param, "name", self.get_var_name(i))
        start = loop_node_member(param, "start")
        end = loop_node_member(param, "end")
        condition = loop_node_member(param, "condition")
        update = loop_node_member(param, "update")
        start = loop_node_bound(start, builder, type_)
        end = loop_node_bound(end, builder, type_)
        if !(start is Undefined) && end is Undefined {
          start = String(loop_node_bound_string(start) + " - 1")
          end = String("0")
          condition = String(">=")
        } else if !(end is Undefined) && start is Undefined {
          start = String("0")
          condition = String("<")
        }
        if condition is Undefined {
          let s = loop_node_js_number(loop_node_bound_string(start))
          let e = loop_node_js_number(loop_node_bound_string(end))
          condition = String(if s > e { ">=" } else { "<" })
        }
      }
    }
    let loop_snippet = if is_while {
      "while ( \{loop_node_bound_string(end)} )"
    } else {
      let start_snippet = loop_node_bound_string(start)
      let end_snippet = loop_node_bound_string(end)
      let condition_string = loop_node_bound_string(condition)
      let delta_operator = fn() {
        if condition_string.contains("<") {
          "+="
        } else {
          "-="
        }
      }
      let update_snippet = match update {
        Undefined | Null =>
          if type_ == "int" || type_ == "uint" {
            let update = if condition_string.contains("<") {
              "++"
            } else {
              "--"
            }
            name + " " + update
          } else {
            name + " " + (delta_operator() + " 1.")
          }
        Shader(_) => {
          let update_node = properties.get_node("updateNode").unwrap()
          let flow = builder.flow_stages_node(update_node, output="void")
          loop_node_strip_update(flow.code)
        }
        Number(_) =>
          name +
          " " +
          delta_operator() +
          " " +
          builder.generate_const(type_, value=update)
        String(s) => name + " " + s
        Node(n) => name + " " + delta_operator() + " " + n.build(builder)
        _ => {
          @core.error(
            "TSL: 'Loop( { update: ... } )' is not a function, string or number.",
          )
          "break /* invalid update */"
        }
      }
      let declaration_snippet = builder.get_var(type_, name) +
        " = " +
        start_snippet
      let conditional_snippet = name +
        " " +
        condition_string +
        " " +
        end_snippet
      "for ( \{declaration_snippet}; \{conditional_snippet}; \{update_snippet} )"
    }
    builder
    .add_flow_code(
      (if i == 0 { "\n" } else { "" }) + builder.tab + loop_snippet + " {\n\n",
    )
    .add_flow_tab()
    |> ignore
  }
  let flow_block = builder.flow_block
  builder.flow_block = Some({ parent: flow_block, guard_: None, })
  let stack_snippet = stack_node.build(builder, output="void")
  properties.get_node("returnsNode").unwrap().build(builder, output="void")
  |> ignore
  builder.flow_block = flow_block
  builder.remove_flow_tab().add_flow_code("\n" + builder.tab + stack_snippet)
  |> ignore
  for i in 0..<(params.length() - 1) {
    builder
    .add_flow_code((if i == 0 { "" } else { builder.tab }) + "}\n\n")
    .remove_flow_tab()
    |> ignore
  }
  builder.add_flow_tab() |> ignore
  None
}

///|
/// The constructor body: `super( 'void' )` has run in `Node::alloc`.
pub fn LoopNode::construct(_node : Node, params : Array[TslValue]) -> LoopNode {
  { params, }
}

///|
/// `new LoopNode( params = [] )`.
pub fn LoopNode::new(params~ : Array[TslValue] = []) -> Node {
  let node = Node::alloc(node_type="void")
  node.set_class(LoopNode::construct(node, params))
}

///|
pub fn LoopNode::of(node : Node) -> LoopNode? {
  match node.class_payload("LoopNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// A range parameter of `loop_`: `{ start, end, type, condition, name, update }`. An
/// `update` may be a number, a string (`'+= 2'`), a node or a `ShaderFn`.
pub fn loop_range(
  start? : &IntoTsl,
  end? : &IntoTsl,
  type_? : String,
  condition? : String,
  name? : String,
  update? : &IntoTsl,
) -> TslValue {
  let object : Map[String, TslValue] = Map([])
  if start is Some(s) {
    object["start"] = s.to_tsl()
  }
  if end is Some(e) {
    object["end"] = e.to_tsl()
  }
  if type_ is Some(t) {
    object["type"] = String(t)
  }
  if condition is Some(c) {
    object["condition"] = String(c)
  }
  if name is Some(n) {
    object["name"] = String(n)
  }
  if update is Some(u) {
    object["update"] = u.to_tsl()
  }
  Object(object)
}

///|
/// `Loop( ...params, body )`: adds the loop to the current stack (a statement).
pub fn loop_(params : Array[&IntoTsl], body : (FnInputs) -> Unit) -> Unit {
  let values = params.map(fn(p) {
    node_object_value(p.to_tsl(), alt_type="int")
  })
  let body_fn = fn_(fn(inputs, _) {
    body(inputs)
    None
  })
  values.push(Node(body_fn))
  LoopNode::new(params=values).to_stack() |> ignore
}

///|
/// `Continue()`.
pub fn continue_() -> Unit {
  expression("continue").to_stack() |> ignore
}

///|
/// `Break()`.
pub fn break_() -> Unit {
  expression("break").to_stack() |> ignore
}
