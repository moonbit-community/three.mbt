// NodeFrame update bookkeeping (upstream NodeFrame.js semantics).

///|
test "NodeFrame updates frame nodes once per frame and render nodes once per render" {
  let frame = @nodes.NodeFrame::new()
  let calls = Ref(0)
  let result : Ref[Bool?] = Ref(None)
  let n = @nodes.Node::new().on_frame_update(fn(_, _) {
    calls.val += 1
    result.val
  })
  // The maps start at frame 0, so nothing runs before the first frame.
  frame.update_node(n)
  assert_eq(calls.val, 0)
  frame.frame_id += 1
  frame.update_node(n)
  frame.update_node(n)
  assert_eq(calls.val, 1)
  frame.frame_id += 1
  frame.update_node(n)
  frame.update_node(n)
  assert_eq(calls.val, 2)
  // `false` keeps the node pending for the frame.
  result.val = Some(false)
  frame.frame_id += 1
  frame.update_node(n)
  frame.update_node(n)
  assert_eq(calls.val, 4)
  let renders = Ref(0)
  let r = @nodes.Node::new().on_render_update(fn(_, _) {
    renders.val += 1
    None
  })
  frame.update_node(r)
  assert_eq(renders.val, 0)
  frame.render_id += 1
  frame.update_node(r)
  frame.update_node(r)
  assert_eq(renders.val, 1)
  let objects = Ref(0)
  let o = @nodes.Node::new().on_object_update(fn(_, _) {
    objects.val += 1
    None
  })
  frame.update_node(o)
  frame.update_node(o)
  assert_eq(objects.val, 2)
}

///|
test "NodeFrame update advances the frame and the clock" {
  let frame = @nodes.NodeFrame::new()
  frame.update()
  assert_eq(frame.frame_id, 1)
  assert_true(frame.last_time is Some(_))
  assert_true(frame.delta_time >= 0.0)
  frame.update()
  assert_eq(frame.frame_id, 2)
  assert_true(frame.time >= frame.delta_time)
}

///|
test "UniformNode onUpdate stores a returned value" {
  let frame = @nodes.NodeFrame::new()
  let u = @nodes.uniform(1).on_frame_update(fn(_, _) { Some(true) })
  frame.frame_id = 1
  frame.update_node(u)
  match @nodes.InputNode::get_value(u) {
    Bool(b) => assert_true(b)
    _ => fail("the callback result became the value")
  }
}
