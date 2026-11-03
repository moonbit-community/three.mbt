// Construction, flags, type names and `_getChildren` of the nodes/core classes of
// foundation group C. Expected values come from upstream run in Node (`import * as T
// from 'nodes/TSL.js'`, then `n._getChildren()`, `n.type`, ...).

///|
fn c_children(n : @nodes.Node) -> Array[String] {
  n
  ._get_children()
  .map(fn(c) {
    let index = match c.index {
      Some(Index(i)) => "[\{i}]"
      Some(Key(k)) => "[\{k}]"
      None => ""
    }
    "\{c.property}\{index}:\{c.child_node.type_()}"
  })
}

///|
fn c_const(x : Double) -> @nodes.Node {
  @nodes.ConstNode::new(Number(x))
}

///|
test "InputNode, ConstNode and UniformNode construction" {
  let c = c_const(1.0)
  assert_eq(c.type_(), "ConstNode")
  assert_true(c.has_flag("isConstNode"))
  assert_true(c.has_flag("isInputNode"))
  assert_true(c.has_flag("isNode"))
  assert_false(c.has_flag("isUniformNode"))
  assert_eq(c_children(c), [])
  assert_eq(@nodes.ConstNode::of(c).unwrap().is_weak, false)
  let u = @nodes.uniform(1)
  assert_eq(u.type_(), "UniformNode")
  assert_eq(u.node_type, None)
  assert_eq(u.name, Some(""))
  assert_eq(c_children(u), ["groupNode:UniformGroupNode"])
  assert_true(physical_equal(u.get_group(), @nodes.object_group))
  assert_true(u.has_flag("isUniformNode") && u.has_flag("isInputNode"))
  let v = @nodes.uniform("vec3")
  assert_eq(v.node_type, Some("vec3"))
  match @nodes.InputNode::get_value(v) {
    Vector3(p) => assert_eq((p.x, p.y, p.z), (0.0, 0.0, 0.0))
    _ => fail("uniform('vec3') holds a Vector3")
  }
  // `uniform( node )` takes the value of the constant inside.
  let w = @nodes.uniform(c_const(2.0))
  match @nodes.InputNode::get_value(w) {
    Number(x) => assert_eq(x, 2.0)
    _ => fail("uniform( const ) holds the number")
  }
  let g = @nodes.uniform_group("g")
  u.set_group(g) |> ignore
  assert_true(physical_equal(u.get_group(), g))
  assert_eq(u.set_name("u_x").name, Some("u_x"))
  u.set_precision(Some("high")) |> ignore
  assert_eq(@nodes.InputNode::of(u).unwrap().precision, Some("high"))
}

///|
test "UniformGroupNode and the predefined groups" {
  let o = @nodes.object_group
  assert_eq(o.name, Some("object"))
  assert_eq(o.update_type, "object")
  assert_eq(o.node_type, Some("string"))
  assert_eq(@nodes.UniformGroupNode::of(o).unwrap().shared, false)
  assert_eq(@nodes.UniformGroupNode::of(o).unwrap().order, 1)
  assert_eq(@nodes.frame_group.update_type, "frame")
  assert_eq(
    @nodes.UniformGroupNode::of(@nodes.render_group).unwrap().shared,
    true,
  )
  assert_eq(@nodes.UniformGroupNode::of(@nodes.render_group).unwrap().order, 0)
  assert_true(o.has_flag("isUniformGroup"))
  let version = o.version
  o.update(@nodes.NodeFrame::new()) |> ignore
  assert_eq(o.version, version + 1)
}

///|
test "PropertyNode, ParameterNode and AttributeNode" {
  let p = @nodes.property("vec3", name="P")
  assert_eq(c_children(p), [])
  assert_true(p.global)
  assert_eq(p.custom_cache_key(), 4667749260357379.0)
  let ao = @nodes.ambient_occlusion
  assert_eq(c_children(ao), ["varying:ConstNode", "placeholderNode:ConstNode"])
  assert_eq(ao.custom_cache_key(), 5293873607016555.0)
  let q = @nodes.parameter("vec3", name="q")
  assert_eq(q.type_(), "ParameterNode")
  assert_true(q.global)
  assert_true(q.has_flag("isPropertyNode") && q.has_flag("isParameterNode"))
  let a = @nodes.attribute("position")
  assert_eq(c_children(a), [])
  assert_true(a.global)
  assert_eq(a.node_type, None)
  assert_eq(@nodes.AttributeNode::get_attribute_name(a), "position")
  a.set_attribute_name("normal") |> ignore
  assert_eq(@nodes.AttributeNode::get_attribute_name(a), "normal")
}

///|
test "VarNode, VaryingNode and SubBuildNode" {
  let v = c_const(1.0).to_var(name="a")
  assert_eq(v.type_(), "VarNode")
  assert_eq(c_children(v), ["node:ConstNode"])
  assert_eq(v.name, Some("a"))
  assert_true(v.parents && v.global)
  assert_false(v.assignable)
  // `Const` passes `readOnly = true` through `nodeObject`: a bool constant child.
  let k = c_const(1.0).to_const(name="k")
  assert_eq(c_children(k), ["node:ConstNode", "readOnly:ConstNode"])
  assert_eq(c_const(1.0).to_var().name, None)
  let y = @nodes.varying(c_const(1.0), name="vv")
  assert_eq(c_children(y), ["node:SubBuild"])
  let sub = @nodes.VaryingNode::of(y).unwrap().node
  assert_eq(sub.name, Some("VERTEX"))
  assert_eq(c_children(sub), ["node:ConstNode"])
  assert_true(sub.has_flag("isSubBuildNode"))
  let s = @nodes.sub_build(c_const(1.0), "X")
  assert_eq(s.type_(), "SubBuild")
  assert_eq(s.name, Some("X"))
}

///|
test "ContextNode and OverrideContextNode" {
  let value = @nodes.node_context([
    ("a", Node(c_const(2.0))),
    ("_b", Node(c_const(3.0))),
    ("c", Number(4.0)),
  ])
  let c = @nodes.context(node=c_const(1.0), value~)
  assert_eq(c_children(c), ["node:ConstNode", "value[a]:ConstNode"])
  assert_true(c.has_flag("isContextNode"))
  let target = c_const(5.0)
  let o = c_const(1.0).override_node(
    target,
    Some(@nodes.OverrideCallback::of_node(c_const(2.0))),
  )
  assert_eq(o.type_(), "OverrideContextNode")
  assert_eq(c_children(o), ["node:ConstNode"])
  assert_true(
    o.has_flag("isContextNode") && o.has_flag("isOverrideContextNode"),
  )
  let overrides = @nodes.ContextNode::of(o).unwrap().value.get_override_nodes()
  assert_eq(overrides.unwrap().entries.length(), 1)
  let f = @nodes.override_nodes([(target, None)], shader_stage="fragment")
  let ctx = @nodes.ContextNode::of(f).unwrap().value
  assert_eq(ctx.get_bool("inlineVaryings"), Some(true))
  assert_true(
    physical_equal(
      ctx.get_override_nodes().unwrap().get(target).unwrap(),
      @nodes.override_callback_null,
    ),
  )
  // `getFlowContextData` merges every context value of the tree.
  let outer = @nodes.context(
    node=c,
    value=@nodes.node_context([("d", Bool(true))]),
  )
  let data = @nodes.ContextNode::get_flow_context_data(outer)
  assert_eq(data.values.keys().collect(), ["d", "a", "_b", "c"])
}

///|
test "Isolate, Bypass, Assign, Array and Index nodes" {
  let i = @nodes.isolate(c_const(1.0))
  assert_eq(c_children(i), ["node:ConstNode"])
  assert_true(i.get_parent())
  assert_false(i.set_parent(false).get_parent())
  let b = @nodes.bypass(c_const(1.0), c_const(2.0))
  assert_eq(c_children(b), ["outputNode:ConstNode", "callNode:ConstNode"])
  let a = @nodes.assign(c_const(1.0).to_var(), 3)
  assert_eq(c_children(a), ["targetNode:VarNode", "sourceNode:ConstNode"])
  let arr = @nodes.array([c_const(1.0), 2])
  assert_eq(c_children(arr), ["values[0]:ConstNode", "values[1]:ConstNode"])
  assert_eq(@nodes.ArrayNode::of(arr).unwrap().count, 2)
  assert_eq(arr.node_type, None)
  let t = c_const(1.0).to_array(3)
  assert_eq(c_children(t).length(), 3)
  let vi = @nodes.vertex_index
  assert_eq(vi.node_type, Some("uint"))
  assert_eq(@nodes.IndexNode::of(vi).unwrap().scope, "vertex")
  assert_eq(c_children(vi), [])
  assert_eq(
    @nodes.IndexNode::of(@nodes.invocation_local_index).unwrap().scope,
    "invocationLocal",
  )
}

///|
test "OutputStruct, MRT, Struct and StructType nodes" {
  let os = @nodes.output_struct([c_const(1.0), c_const(2.0)])
  assert_eq(c_children(os), ["members[0]:ConstNode", "members[1]:ConstNode"])
  let outputs = Map::new()
  outputs.set("output", c_const(1.0))
  outputs.set("emissive", c_const(2.0))
  let m = @nodes.mrt(outputs)
  assert_eq(c_children(m), [
    "outputNodes[output]:ConstNode", "outputNodes[emissive]:ConstNode",
  ])
  assert_true(m.has_flag("isMRTNode") && m.has_flag("isOutputStructNode"))
  let mrt = @nodes.MRTNode::of(m).unwrap()
  assert_eq(mrt.get_blend_mode("output").blending, 6)
  assert_eq(mrt.get_blend_mode("x").blending, 0)
  assert_true(mrt.has("emissive"))
  m.set_clear_color("emissive", @math.Color::new(0.5, 0.25, 1.0), alpha=0.5)
  |> ignore
  let cc = mrt.get_clear_color("emissive").unwrap()
  assert_eq((cc.color.r, cc.color.g, cc.a), (0.5, 0.25, 0.5))
  let s = @nodes.struct_(
    [
      @nodes.StructMember::new("a", "float"),
      @nodes.StructMember::new("b", "vec3", atomic_=true),
    ],
    name="S",
  )
  let sn = s.call([c_const(1.0), c_const(2.0)])
  assert_eq(c_children(sn), [
    "values[a]:ConstNode", "values[b]:ConstNode", "structTypeNode:StructTypeNode",
  ])
  assert_eq(sn.node_type, Some("vec3"))
  assert_eq(s.node.name, Some("S"))
  let layout = @nodes.StructTypeNode::of(s.node).unwrap().members_layout
  assert_eq(layout.map(fn(m) { (m.name, m.type_, m.atomic_) }), [
    ("a", "float", false),
    ("b", "vec3", true),
  ])
}

///|
test "InspectorNode and TempNode" {
  let n = c_const(1.0).to_inspector(name="nm")
  assert_eq(n.type_(), "ConstNode")
  let inspector = n._inspector_node.unwrap()
  assert_eq(inspector.type_(), "InspectorNode")
  assert_eq(inspector.update_type, "frame")
  assert_eq(inspector.name, Some("nm"))
  assert_eq(c_children(inspector), ["node:ConstNode"])
  assert_eq(@nodes.InspectorNode::get_name(inspector), Some("nm"))
}

///|
test "BlendMode and Color4" {
  let b = @nodes.BlendMode::new()
  assert_eq(
    (b.blending, b.blend_src, b.blend_dst, b.blend_equation),
    (1, 204, 205, 100),
  )
  b.premultiply_alpha = true
  assert_true(b.clone().premultiply_alpha)
  let c = @nodes.Color4::new()
  assert_eq((c.color.r, c.color.g, c.color.b, c.a), (1.0, 1.0, 1.0, 1.0))
  c.set(0.1, 0.2, 0.3, a=0.4) |> ignore
  let d = @nodes.Color4::new().copy(c)
  assert_eq((d.color.r, d.color.g, d.color.b, d.a), (0.1, 0.2, 0.3, 0.4))
}
