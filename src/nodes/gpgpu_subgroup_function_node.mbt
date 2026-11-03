// nodes/gpgpu/SubgroupFunctionNode.js

///|
/// A subgroup or quad operation (`subgroupAdd`, `subgroupBroadcast`, `quadSwapX`, ...).
pub(all) struct SubgroupFunctionNode {
  mut method_ : String
  mut a_node : Node?
  mut b_node : Node?
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn class_name(_) {
  "SubgroupFunctionNode"
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn children(self, _, out) {
  push_child(out, "aNode", self.a_node)
  push_child(out, "bNode", self.b_node)
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn setup(_, node, builder) {
  builder.enable_sub_groups()
  node.setup_base(builder)
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn generate_node_type(
  self,
  _,
  builder,
  _,
) {
  let method_ = self.method_
  if method_ == SubgroupFunctionNode::subgroup_elect() {
    Some("bool")
  } else if method_ == SubgroupFunctionNode::subgroup_ballot() {
    Some("uvec4")
  } else {
    self.get_input_type(builder)
  }
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn generate(
  self,
  node,
  builder,
  output,
) {
  let method_ = self.method_
  if builder.shader_stage == Some("vertex") {
    @core.error(
      "TSL: \"\{self.method_}\" is not supported in the vertex shader stage.",
    )
  }
  let type_ = node.get_node_type(builder)
  let input_type = self.get_input_type(builder)
  let a = self.a_node
  let b = self.b_node
  let params = []
  if method_ == SubgroupFunctionNode::subgroup_broadcast() ||
    method_ == SubgroupFunctionNode::subgroup_shuffle() ||
    method_ == SubgroupFunctionNode::quad_broadcast() {
    let a = subgroup_function_required(a)
    let b = subgroup_function_required(b)
    let b_type = b.get_node_type(builder)
    params.push(a.build(builder, output?=type_))
    params.push(
      b.build(
        builder,
        output?=if b_type == Some("float") { Some("int") } else { type_ },
      ),
    )
  } else if method_ == SubgroupFunctionNode::subgroup_shuffle_xor() ||
    method_ == SubgroupFunctionNode::subgroup_shuffle_down() ||
    method_ == SubgroupFunctionNode::subgroup_shuffle_up() {
    let a = subgroup_function_required(a)
    let b = subgroup_function_required(b)
    params.push(a.build(builder, output?=type_))
    params.push(b.build(builder, output="uint"))
  } else {
    if a is Some(a) {
      params.push(a.build(builder, output?=input_type))
    }
    if b is Some(b) {
      params.push(b.build(builder, output?=input_type))
    }
  }
  let params_string = if params.length() == 0 {
    "()"
  } else {
    "( \{params.join(", ")} )"
  }
  Some(
    builder.format(
      "\{builder.get_method(method_, output?=type_)}\{params_string}",
      type_,
      output,
    ),
  )
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn serialize(self, node, data) {
  node.serialize_base(data)
  data.set("method", @core.JsValue::of(self.method_))
}

///|
pub impl NodeClass for SubgroupFunctionNode with fn deserialize(
  self,
  node,
  data,
) {
  node.deserialize_base(data)
  self.method_ = data.get("method").cast()
}

///|
fn subgroup_function_required(node : Node?) -> Node {
  match node {
    Some(n) => n
    None =>
      abort("TypeError: Cannot read properties of null (reading 'getNodeType')")
  }
}

///|
/// `getInputType( builder )`: the longer of the two input types.
fn SubgroupFunctionNode::get_input_type(
  self : SubgroupFunctionNode,
  builder : NodeBuilder,
) -> String? {
  let a_type = match self.a_node {
    Some(a) => a.get_node_type(builder)
    None => None
  }
  let b_type = match self.b_node {
    Some(b) => b.get_node_type(builder)
    None => None
  }
  let a_len = if builder.is_matrix(a_type) {
    0
  } else {
    builder.get_type_length(a_type)
  }
  let b_len = if builder.is_matrix(b_type) {
    0
  } else {
    builder.get_type_length(b_type)
  }
  if a_len > b_len {
    a_type
  } else {
    b_type
  }
}

///|
pub fn SubgroupFunctionNode::construct(
  _node : Node,
  method_ : String,
  a_node : Node?,
  b_node : Node?,
) -> SubgroupFunctionNode {
  { method_, a_node, b_node, }
}

///|
/// `new SubgroupFunctionNode( method, aNode = null, bNode = null )`.
pub fn SubgroupFunctionNode::new(
  method_ : String,
  a_node? : Node,
  b_node? : Node,
) -> Node {
  let node = Node::alloc()
  node.set_class(SubgroupFunctionNode::construct(node, method_, a_node, b_node))
}

///|
pub fn SubgroupFunctionNode::of(node : Node) -> SubgroupFunctionNode? {
  match node.class_payload("SubgroupFunctionNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
pub fn SubgroupFunctionNode::subgroup_elect() -> String {
  "subgroupElect"
}

///|
pub fn SubgroupFunctionNode::subgroup_ballot() -> String {
  "subgroupBallot"
}

///|
pub fn SubgroupFunctionNode::subgroup_add() -> String {
  "subgroupAdd"
}

///|
pub fn SubgroupFunctionNode::subgroup_inclusive_add() -> String {
  "subgroupInclusiveAdd"
}

///|
pub fn SubgroupFunctionNode::subgroup_exclusive_add() -> String {
  "subgroupExclusiveAdd"
}

///|
pub fn SubgroupFunctionNode::subgroup_mul() -> String {
  "subgroupMul"
}

///|
pub fn SubgroupFunctionNode::subgroup_inclusive_mul() -> String {
  "subgroupInclusiveMul"
}

///|
pub fn SubgroupFunctionNode::subgroup_exclusive_mul() -> String {
  "subgroupExclusiveMul"
}

///|
pub fn SubgroupFunctionNode::subgroup_and() -> String {
  "subgroupAnd"
}

///|
pub fn SubgroupFunctionNode::subgroup_or() -> String {
  "subgroupOr"
}

///|
pub fn SubgroupFunctionNode::subgroup_xor() -> String {
  "subgroupXor"
}

///|
pub fn SubgroupFunctionNode::subgroup_min() -> String {
  "subgroupMin"
}

///|
pub fn SubgroupFunctionNode::subgroup_max() -> String {
  "subgroupMax"
}

///|
pub fn SubgroupFunctionNode::subgroup_all() -> String {
  "subgroupAll"
}

///|
pub fn SubgroupFunctionNode::subgroup_any() -> String {
  "subgroupAny"
}

///|
pub fn SubgroupFunctionNode::subgroup_broadcast_first() -> String {
  "subgroupBroadcastFirst"
}

///|
pub fn SubgroupFunctionNode::quad_swap_x() -> String {
  "quadSwapX"
}

///|
pub fn SubgroupFunctionNode::quad_swap_y() -> String {
  "quadSwapY"
}

///|
pub fn SubgroupFunctionNode::quad_swap_diagonal() -> String {
  "quadSwapDiagonal"
}

///|
pub fn SubgroupFunctionNode::subgroup_broadcast() -> String {
  "subgroupBroadcast"
}

///|
pub fn SubgroupFunctionNode::subgroup_shuffle() -> String {
  "subgroupShuffle"
}

///|
pub fn SubgroupFunctionNode::subgroup_shuffle_xor() -> String {
  "subgroupShuffleXor"
}

///|
pub fn SubgroupFunctionNode::subgroup_shuffle_up() -> String {
  "subgroupShuffleUp"
}

///|
pub fn SubgroupFunctionNode::subgroup_shuffle_down() -> String {
  "subgroupShuffleDown"
}

///|
pub fn SubgroupFunctionNode::quad_broadcast() -> String {
  "quadBroadcast"
}

///|
/// `nodeProxyAssignable( SubgroupFunctionNode, method )`: an assignable call.
fn subgroup_function(method_ : String, params : Array[TslValue]) -> Node {
  let nodes = node_array(params).map(fn(v) {
    match v {
      Node(n) => Some(n)
      _ => None
    }
  })
  let a_node = if nodes.length() > 0 { nodes[0] } else { None }
  let b_node = if nodes.length() > 1 { nodes[1] } else { None }
  SubgroupFunctionNode::new(method_, a_node?, b_node?).to_assignable()
}

///|
/// `subgroupElect()`.
pub fn subgroup_elect() -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_elect(), [])
}

///|
/// `subgroupBallot( e )`.
pub fn subgroup_ballot(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_ballot(), [e.to_tsl()])
}

///|
/// `subgroupAdd( e )`.
pub fn subgroup_add(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_add(), [e.to_tsl()])
}

///|
/// `subgroupInclusiveAdd( e )`.
pub fn subgroup_inclusive_add(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_inclusive_add(), [e.to_tsl()])
}

///|
/// `subgroupExclusiveAdd( e )`.
pub fn subgroup_exclusive_add(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_exclusive_add(), [e.to_tsl()])
}

///|
/// `subgroupMul( e )`.
pub fn subgroup_mul(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_mul(), [e.to_tsl()])
}

///|
/// `subgroupInclusiveMul( e )`.
pub fn subgroup_inclusive_mul(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_inclusive_mul(), [e.to_tsl()])
}

///|
/// `subgroupExclusiveMul( e )`.
pub fn subgroup_exclusive_mul(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_exclusive_mul(), [e.to_tsl()])
}

///|
/// `subgroupAnd( e )`.
pub fn subgroup_and(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_and(), [e.to_tsl()])
}

///|
/// `subgroupOr( e )`.
pub fn subgroup_or(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_or(), [e.to_tsl()])
}

///|
/// `subgroupXor( e )`.
pub fn subgroup_xor(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_xor(), [e.to_tsl()])
}

///|
/// `subgroupMin( e )`.
pub fn subgroup_min(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_min(), [e.to_tsl()])
}

///|
/// `subgroupMax( e )`.
pub fn subgroup_max(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_max(), [e.to_tsl()])
}

///|
/// `subgroupAll( e )`.
pub fn subgroup_all(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_all(), [e.to_tsl()])
}

///|
/// `subgroupAny( e )`.
pub fn subgroup_any(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_any(), [e.to_tsl()])
}

///|
/// `subgroupBroadcastFirst( e )`.
pub fn subgroup_broadcast_first(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_broadcast_first(), [
    e.to_tsl(),
  ])
}

///|
/// `quadSwapX( e )`.
pub fn quad_swap_x(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::quad_swap_x(), [e.to_tsl()])
}

///|
/// `quadSwapY( e )`.
pub fn quad_swap_y(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::quad_swap_y(), [e.to_tsl()])
}

///|
/// `quadSwapDiagonal( e )`.
pub fn quad_swap_diagonal(e : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::quad_swap_diagonal(), [e.to_tsl()])
}

///|
/// `subgroupBroadcast( e, id )`.
pub fn subgroup_broadcast(e : &IntoTsl, id : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_broadcast(), [
    e.to_tsl(),
    id.to_tsl(),
  ])
}

///|
/// `subgroupShuffle( e, id )`.
pub fn subgroup_shuffle(e : &IntoTsl, id : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_shuffle(), [
    e.to_tsl(),
    id.to_tsl(),
  ])
}

///|
/// `subgroupShuffleXor( e, id )`.
pub fn subgroup_shuffle_xor(e : &IntoTsl, id : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_shuffle_xor(), [
    e.to_tsl(),
    id.to_tsl(),
  ])
}

///|
/// `subgroupShuffleUp( e, id )`.
pub fn subgroup_shuffle_up(e : &IntoTsl, id : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_shuffle_up(), [
    e.to_tsl(),
    id.to_tsl(),
  ])
}

///|
/// `subgroupShuffleDown( e, id )`.
pub fn subgroup_shuffle_down(e : &IntoTsl, id : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::subgroup_shuffle_down(), [
    e.to_tsl(),
    id.to_tsl(),
  ])
}

///|
/// `quadBroadcast( e, id )`.
pub fn quad_broadcast(e : &IntoTsl, id : &IntoTsl) -> Node {
  subgroup_function(SubgroupFunctionNode::quad_broadcast(), [
    e.to_tsl(),
    id.to_tsl(),
  ])
}
