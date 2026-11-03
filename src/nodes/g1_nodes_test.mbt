// G1 behaviour outside the shader text: uniform and event updates, the per-object seed
// of range nodes, max mip levels, serialized fields. Expected values are upstream's
// (r187), computed with the same inputs.

///|
test "timer uniforms take the frame's time, delta and id on update" {
  let frame = @nodes.NodeFrame::new()
  frame.time = 1.5
  frame.delta_time = 0.25
  frame.frame_id = 7
  @nodes.time.update(frame) |> ignore
  @nodes.delta_time.update(frame) |> ignore
  @nodes.frame_id.update(frame) |> ignore
  assert_true(@nodes.InputNode::get_value(@nodes.time) is Number(1.5))
  assert_true(@nodes.InputNode::get_value(@nodes.delta_time) is Number(0.25))
  assert_true(@nodes.InputNode::get_value(@nodes.frame_id) is Number(7.0))
  assert_eq(@nodes.time.update_type, "render")
  assert_eq(@nodes.frame_id.node_type, Some("uint"))
}

///|
test "event nodes set their update types and run the callback" {
  let calls = []
  let frame = @nodes.NodeFrame::new()
  let object = @nodes.EventNode::new(
    @nodes.EventNode::object(),
    OnFrame(fn(_) { calls.push("object") }),
  )
  let before_frame = @nodes.EventNode::new(
    @nodes.EventNode::before_frame(),
    OnFrame(fn(_) { calls.push("beforeFrame") }),
  )
  let after_object = @nodes.EventNode::new(
    @nodes.EventNode::after_object(),
    OnFrame(fn(_) { calls.push("afterObject") }),
  )
  let material = @nodes.EventNode::new(
    @nodes.EventNode::material(),
    OnFrame(fn(_) { calls.push("material") }),
  )
  assert_eq(object.update_type, "object")
  assert_eq(material.update_type, "render")
  assert_eq(before_frame.update_before_type, "frame")
  assert_eq(before_frame.update_type, "none")
  assert_eq(after_object.update_after_type, "object")
  object.update(frame) |> ignore
  before_frame.update_before(frame) |> ignore
  after_object.update_after(frame) |> ignore
  assert_eq(calls, ["object", "beforeFrame", "afterObject"])
  assert_eq(object.node_type, Some("void"))
}

///|
test "render pipeline events add their callback to the context array" {
  let callbacks : Array[() -> Unit] = []
  let ran = []
  let event = @nodes.EventNode::new(
    @nodes.EventNode::before_render_pipeline(),
    OnPipeline(fn() { ran.push(1) }),
  )
  let b = @nodes.NodeBuilder::new(
    NoObject,
    @nodes.Renderer::foundation_stub(),
    None,
  )
  b.context.set(
    "onBeforePipelineCallbacks",
    Other(@core.JsValue::of(callbacks)),
  )
  b.set_shader_stage(Some("fragment"))
  b.flow_stages_node(event) |> ignore
  assert_eq(callbacks.length(), 1)
  callbacks[0]()
  assert_eq(ran, [1])
}

///|
test "range nodes salt by creation order and seed by object id" {
  let seed_node = @nodes.range(0, 1)
  let range = @nodes.RangeNode::of(seed_node).unwrap()
  // `Math.imul( id, 0x85EBCA6B ) >>> 0` for consecutive ids differ
  let next = @nodes.RangeNode::of(@nodes.range(0, 1)).unwrap()
  assert_true(range._salt != next._salt)
  assert_true(next._salt >= 0.0 && next._salt < 4294967296.0)
}

///|
test "max mip level is log2 of the largest image side" {
  let texture = @core.DataTexture::new(width=256, height=64)
  let node = @nodes.max_mip_level(@nodes.uniform(texture))
  node.update(@nodes.NodeFrame::new()) |> ignore
  assert_true(@nodes.InputNode::get_value(node) is Number(8.0))
  assert_eq(node.update_type, "frame")
}

///|
test "operator, math and packed nodes serialize their method" {
  let op = @nodes.add(@nodes.float(1).to_var(), 2)
  let data = op.to_json()
  assert_eq(@webgl.js_to_string(data.get("op")), "+")
  assert_eq(@webgl.js_to_string(data.get("type")), "OperatorNode")
  let math = @nodes.sin(@nodes.float(1).to_var())
  assert_eq(@webgl.js_to_string(math.to_json().get("method")), "sin")
  let rotate = @nodes.rotate(@nodes.vec2(1), 1, order="ZYX")
  assert_eq(@webgl.js_to_string(rotate.to_json().get("order")), "ZYX")
}

///|
test "variadic operators and max nest left to right" {
  let a = @nodes.float(1).to_var()
  let b = @nodes.float(2).to_var()
  let c = @nodes.float(3).to_var()
  let sum = @nodes.add_of([a, b, c])
  let outer = @nodes.OperatorNode::of(sum).unwrap()
  assert_true(outer.b_node.unwrap().same(c))
  let inner = @nodes.OperatorNode::of(outer.a_node).unwrap()
  assert_true(inner.a_node.same(a) && inner.b_node.unwrap().same(b))
  let m = @nodes.MathNode::of(@nodes.max_of([a, b, c])).unwrap()
  assert_true(m.b_node.unwrap().same(c) && m.c_node is None)
  assert_eq(@nodes.MathNode::of(m.a_node).unwrap().method_, "max")
}

///|
test "function call parameters keep their form" {
  let f = @nodes.wgsl_fn("fn f( a : float ) -> float { return a; }")
  let positional = @nodes.FunctionCallNode::of(f.call([@nodes.float(1)])).unwrap()
  assert_true(positional.parameters is Positional([_]))
  let named = @nodes.FunctionCallNode::of(
    f.call_named({ "a": @nodes.float(1) }),
  ).unwrap()
  assert_true(named.parameters is Named(_))
}
