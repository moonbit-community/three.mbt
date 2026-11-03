// StackNode bookkeeping that needs no builder; expected orders checked against
// upstream StackNode.js in Node.

///|
fn stack_ids(
  stack : @nodes.StackNode,
  nodes : Array[@nodes.Node],
) -> Array[Int32] {
  stack.nodes.map(fn(n) {
    for i, m in nodes {
      if physical_equal(n, m) {
        return i
      }
    }
    -1
  })
}

///|
test "StackNode addToStack keeps nodes added while building after the current node" {
  let s = @nodes.StackNode::create()
  assert_eq(s.node.type_(), "StackNode")
  assert_true(s.node.has_flag("isStackNode"))
  let n = Array::makei(5, fn(i) { @nodes.ConstNode::new(Number(i.to_double())) })
  s.add_to_stack(n[0]).add_to_stack(n[1]) |> ignore
  s._current_node = Some(n[0])
  s.add_to_stack(n[2]) |> ignore
  s.add_to_stack(n[3]) |> ignore
  assert_eq(stack_ids(s, n), [0, 2, 3, 1])
  s.add_to_stack_before(n[4]) |> ignore
  assert_eq(stack_ids(s, n), [4, 0, 2, 3, 1])
  s._current_node = None
  let m = @nodes.ConstNode::new(Number(9.0))
  s.add_to_stack_before(m) |> ignore
  assert_true(physical_equal(s.nodes[0], m))
  // children: `nodes[i]`, then `outputNode`, then `parent`.
  let child = @nodes.StackNode::create(parent=s)
  child.add_to_stack(n[0]) |> ignore
  child.output_node = Some(n[1])
  let props = child.node
    ._get_children()
    .map(fn(c) {
      match c.index {
        Some(Index(i)) => c.property + "[" + i.to_string() + "]"
        _ => c.property
      }
    })
  assert_eq(props, ["nodes[0]", "outputNode", "parent"])
}

///|
test "StackNode If/ElseIf/Else chain conditional nodes" {
  let s = @nodes.StackNode::create()
  let c1 = @nodes.ConstNode::new(Bool(true))
  let c2 = @nodes.ConstNode::new(Bool(false))
  s.if_(c1, fn() {  }).else_if(c2, fn() {  }).else_(fn() {  })
  assert_eq(s.nodes.length(), 1)
  let first = @nodes.ConditionalNode::of(s.nodes[0]).unwrap()
  assert_true(physical_equal(first.cond_node, c1))
  assert_true(@nodes.ShaderNodeInternal::of(first.if_node) is Some(_))
  let second = @nodes.ConditionalNode::of(first.else_node.unwrap()).unwrap()
  assert_true(physical_equal(second.cond_node, c2))
  assert_true(
    @nodes.ShaderNodeInternal::of(second.else_node.unwrap()) is Some(_),
  )
  // upstream ShaderNodeInternal has no `static get type()`
  assert_eq(second.if_node.type_(), "Node")
  assert_true(
    physical_equal(s._current_cond.unwrap(), first.else_node.unwrap()),
  )
}
