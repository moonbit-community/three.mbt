// TSLCore and NodeUtils without a NodeBuilder. Expectations come from upstream run in
// Node (`import * as T from '.../src/nodes/tsl/TSLCore.js'`), printed with the same
// `describe` shape: class(type, value, weak, assignable).

///|
/// `inspect` (the package defines its own `inspect`, TSL's).
fn tsl_inspect(value : &Show, content~ : String) -> Unit raise {
  let actual = value.to_string()
  if actual != content {
    fail("expected \{content}, got \{actual}")
  }
}

///|
fn tsl_opt(value : String?) -> String {
  match value {
    Some(s) => "Some(\{s})"
    None => "None"
  }
}

///|
fn tsl_test_value(value : @nodes.TslValue) -> String {
  match value {
    Number(d) => d.to_string()
    Bool(b) => b.to_string()
    String(s) => s
    Vector2(v) => "\{v.x},\{v.y}"
    Vector3(v) => "\{v.x},\{v.y},\{v.z}"
    Vector4(v) => "\{v.x},\{v.y},\{v.z},\{v.w}"
    Color(c) => "\{c.r},\{c.g},\{c.b}"
    Matrix2(m) => m.elements.map(fn(e) { e.to_string() }).join(",")
    Matrix3(m) => m.elements.map(fn(e) { e.to_string() }).join(",")
    Null => "null"
    Undefined => "undefined"
    _ => "?"
  }
}

///|
fn tsl_test_describe(node : @nodes.Node) -> String {
  let (value, weak) = match @nodes.ConstNode::of(node) {
    Some(c) => (tsl_test_value(c.input.value), c.is_weak.to_string())
    None => ("undefined", "undefined")
  }
  let type_ = node.node_type.unwrap_or("null")
  "\{node.class_.class_name()}(type=\{type_}, value=\{value}, weak=\{weak}, assignable=\{node.assignable})"
}

///|
/// The number of a `fn<id>` layout name.
fn tsl_test_fn_number(name : String) -> Int32 {
  let mut n = 0
  for c in name {
    if c >= '0' && c <= '9' {
      n = n * 10 + (c.to_int() - '0'.to_int())
    }
  }
  n
}

///|
fn shared(value : @nodes.TslValue) -> @nodes.Node {
  @nodes.node_object(value)
}

///|
test "shared constants" {
  // nodeObject( v ) returns the same constant for cached numbers and booleans
  tsl_inspect(
    tsl_test_describe(shared(Number(0.7))),
    content="ConstNode(type=null, value=0.7, weak=true, assignable=false)",
  )
  assert_false(shared(Number(0.7)).same(shared(Number(0.7))))
  assert_true(shared(Number(-0.0)).same(shared(Number(0.0))))
  let pi = 3.141592653589793
  assert_true(shared(Number(pi / 2.0)).same(shared(Number(pi / 2.0))))
  assert_true(shared(Number(-1.0 / 3.0)).same(shared(Number(-1.0 / 3.0))))
  assert_true(shared(Bool(true)).same(shared(Bool(true))))
  // creation order: bools (2), uints (4), ints (6), floats (28), then the shared numbers
  let zero = shared(Number(0.0))
  tsl_inspect(zero.id - shared(Bool(false)).id, content="40")
  tsl_inspect(shared(Number(1.0)).id - zero.id, content="1")
  tsl_inspect(shared(Number(0.5)).id - zero.id, content="6")
  tsl_inspect(shared(Number(-0.5)).id - zero.id, content="17")
  tsl_inspect(shared(Bool(true)).id - shared(Bool(false)).id, content="1")
  // nodeObjectAssignable copies a shared constant
  let copy = @nodes.node_object_assignable(0.5)
  assert_false(copy.same(shared(Number(0.5))))
  tsl_inspect(
    tsl_test_describe(copy),
    content="ConstNode(type=null, value=0.5, weak=true, assignable=true)",
  )
}

///|
test "convert type scalars" {
  let f = @nodes.float(0.5)
  tsl_inspect(
    tsl_test_describe(f),
    content="ConstNode(type=null, value=0.5, weak=false, assignable=true)",
  )
  assert_false(f.same(shared(Number(0.5))))
  tsl_inspect(
    tsl_test_describe(@nodes.float(2.7)),
    content="ConstNode(type=float, value=2.7, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.float_of([])),
    content="ConstNode(type=null, value=0, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.int(1)),
    content="ConstNode(type=int, value=1, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.int(7)),
    content="ConstNode(type=int, value=7, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.int(-2)),
    content="ConstNode(type=int, value=-2, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.uint(3)),
    content="ConstNode(type=uint, value=3, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.uint(4)),
    content="ConstNode(type=uint, value=4, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.bool(true)),
    content="ConstNode(type=null, value=true, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.bool_of([])),
    content="ConstNode(type=null, value=false, weak=false, assignable=true)",
  )
  // a boolean is a shared constant, converted
  let ft = @nodes.float(true)
  tsl_inspect(
    tsl_test_describe(ft),
    content="ConvertNode(type=null, value=undefined, weak=undefined, assignable=true)",
  )
  let convert = @nodes.ConvertNode::of(ft).unwrap()
  assert_true(convert.node.same(shared(Bool(true))))
  tsl_inspect(
    tsl_test_describe(convert.node),
    content="ConstNode(type=null, value=true, weak=false, assignable=false)",
  )
}

///|
test "convert type vectors" {
  tsl_inspect(
    tsl_test_describe(@nodes.vec3(0.1)),
    content="ConstNode(type=vec3, value=0.1,0.1,0.1, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.vec3_of([1, 0.5, 0])),
    content="ConstNode(type=vec3, value=1,0.5,0, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.vec2_of([])),
    content="ConstNode(type=vec2, value=0,0, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.color(0xff0000)),
    content="ConstNode(type=color, value=1,0,0, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.color_of([0, 1, 0.5])),
    content="ConstNode(type=color, value=0,1,0.5, weak=false, assignable=true)",
  )
  tsl_inspect(
    tsl_test_describe(@nodes.color_of([])),
    content="ConstNode(type=color, value=1,1,1, weak=false, assignable=true)",
  )
  // Matrix2 elements are column-major
  tsl_inspect(
    tsl_test_describe(@nodes.mat2_of([1, 2, 3, 4])),
    content="ConstNode(type=mat2, value=1,3,2,4, weak=false, assignable=true)",
  )
  let x = @nodes.ConstNode::new(Number(2.0), node_type="float")
  let join = @nodes.vec3_of([x, 1])
  tsl_inspect(
    tsl_test_describe(join),
    content="JoinNode(type=vec3, value=undefined, weak=undefined, assignable=true)",
  )
  let nodes = @nodes.JoinNode::of(join).unwrap().nodes
  tsl_inspect(nodes.length(), content="2")
  assert_true(nodes[0].same(x))
  assert_true(nodes[1].same(shared(Number(1.0))))
  // a node of the requested type is wrapped, not reused
  let fx = @nodes.float(x)
  tsl_inspect(@nodes.ConvertNode::of(fx).unwrap().convert_to, content="float")
  assert_true(@nodes.ConvertNode::of(fx).unwrap().node.same(x))
  tsl_inspect(
    @nodes.ConvertNode::of(x.to_vec3()).unwrap().convert_to,
    content="vec3",
  )
}

///|
test "const node type and defined" {
  let x = @nodes.ConstNode::new(Number(2.0), node_type="float")
  let v = @nodes.vec3(x)
  tsl_inspect(
    tsl_opt(@nodes.get_const_node_type(Node(x))),
    content="Some(float)",
  )
  tsl_inspect(
    tsl_opt(@nodes.get_const_node_type(Node(v))),
    content="Some(vec3)",
  )
  tsl_inspect(
    tsl_opt(@nodes.get_const_node_type(String("vec4"))),
    content="Some(vec4)",
  )
  tsl_inspect(tsl_opt(@nodes.get_const_node_type(Number(5.0))), content="None")
  tsl_inspect(tsl_opt(@nodes.get_const_node_type(Null)), content="None")
  assert_false(@nodes.defined(Node(shared(Number(0.0)))))
  assert_true(@nodes.defined(Node(shared(Number(1.0)))))
  assert_false(@nodes.defined(Number(0.0)))
  assert_true(@nodes.defined(String("a")))
  assert_true(@nodes.defined(Node(v)))
  assert_false(@nodes.defined(Node(@nodes.vec3_of([x, 0]))))
}

///|
test "node utils" {
  tsl_inspect(
    tsl_opt(@nodes.get_value_type(Number(1.0))),
    content="Some(float)",
  )
  tsl_inspect(tsl_opt(@nodes.get_value_type(Bool(true))), content="Some(bool)")
  tsl_inspect(
    tsl_opt(@nodes.get_value_type(String("s"))),
    content="Some(string)",
  )
  tsl_inspect(
    tsl_opt(@nodes.get_value_type(Shader({ f: fn(_, _) { None }, }))),
    content="Some(shader)",
  )
  tsl_inspect(tsl_opt(@nodes.get_value_type(Null)), content="None")
  tsl_inspect(tsl_opt(@nodes.get_value_type(Object({}))), content="None")
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("vec3"), [Number(2.0)])),
    content="2,2,2",
  )
  tsl_inspect(
    tsl_test_value(
      @nodes.get_value_from_type(Some("ivec2"), [Number(1.0), Number(2.0)]),
    ),
    content="1,2",
  )
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("float"), [])),
    content="0",
  )
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("bool"), [])),
    content="false",
  )
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("string"), [])),
    content="",
  )
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("mat3"), [])),
    content="1,0,0,0,1,0,0,0,1",
  )
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("x"), [])),
    content="null",
  )
  tsl_inspect(
    tsl_test_value(@nodes.get_value_from_type(Some("color"), [Number(65280.0)])),
    content="0,1,0",
  )
  let typed = ["ivec3", "uvec2", "mat3", "uint", "int", "vec4", "float"].map(fn(
    t,
  ) {
    match @nodes.get_typed_array_from_type(t) {
      Int32Array => "Int32Array"
      Uint32Array => "Uint32Array"
      Float32Array => "Float32Array"
      _ => "?"
    }
  })
  tsl_inspect(
    typed.join(" "),
    content="Int32Array Uint32Array Float32Array Uint32Array Int32Array Float32Array Float32Array",
  )
  let lengths = ["float", "vec3", "mat3", "mat4", "mat2", "bvec2"].map(fn(t) {
    "\{@nodes.get_length_from_type(t)}/\{@nodes.get_memory_length_from_type(t)}/\{@nodes.get_alignment_from_type(t)}"
  })
  tsl_inspect(
    lengths.join(" "),
    content="1/1/1 3/3/4 9/12/4 16/16/4 4/4/2 2/2/2",
  )
  let x = @nodes.ConstNode::new(Number(2.0), node_type="float")
  assert_true(@nodes.is_array_as_parameter([Node(x)]))
  assert_false(@nodes.is_array_as_parameter([Object({})]))
  assert_false(@nodes.is_array_as_parameter([]))
  assert_true(@nodes.is_array_as_parameter([Number(1.0)]))
  assert_false(@nodes.is_array_as_parameter([Null]))
  tsl_inspect(tsl_opt(@nodes.get_type_from_length(9)), content="Some(mat3)")
  tsl_inspect(tsl_opt(@nodes.get_type_from_length(5)), content="None")
}

///|
test "swizzles and elements" {
  let x = @nodes.ConstNode::new(Number(2.0), node_type="float")
  assert_true(x.xyz().same(x.rgb()))
  assert_true(x.stp().same(x.xyz()))
  tsl_inspect(@nodes.SplitNode::of(x.xyz()).unwrap().components, content="xyz")
  tsl_inspect(@nodes.SplitNode::of(x.zyx()).unwrap().components, content="zyx")
  assert_false(x.zyx().same(x.xyz()))
  let set = x.set_rgb(1)
  let payload = @nodes.SetNode::of(set).unwrap()
  tsl_inspect(set.class_.class_name(), content="SetNode")
  tsl_inspect(payload.components, content="xyz")
  assert_true(payload.target_node.same(shared(Number(1.0))))
  tsl_inspect(@nodes.SetNode::of(x.set_zx(1)).unwrap().components, content="xz")
  tsl_inspect(
    @nodes.FlipNode::of(x.flip_yx()).unwrap().components,
    content="xy",
  )
  let e2 = x[2]
  assert_true(e2.same(x[2]))
  tsl_inspect(e2.class_.class_name(), content="ArrayElementNode")
  tsl_inspect(
    tsl_test_describe(@nodes.ArrayElementNode::of(e2).unwrap().index_node),
    content="ConstNode(type=uint, value=2, weak=false, assignable=false)",
  )
  let el = x.element(3)
  let index = @nodes.ArrayElementNode::of(el).unwrap().index_node
  assert_true(index.same(shared(Number(3.0))))
  tsl_inspect(
    tsl_test_describe(index),
    content="ConstNode(type=null, value=3, weak=true, assignable=false)",
  )
  let member_node = x.get("position")
  tsl_inspect(
    @nodes.MemberNode::of(member_node).unwrap().property,
    content="position",
  )
}

///|
test "fn layouts and calls" {
  let f1 = @nodes.fn_(
    fn(_, _) { None },
    layout=@nodes.FnLayout::short([("a", "float")], return_="vec3"),
  )
  let f2 = @nodes.fn_(
    fn(_, _) { None },
    layout=@nodes.FnLayout::short([("b", "vec2")]),
  )
  let s1 = @nodes.ShaderNodeInternal::of(
    @nodes.FnNode::of(f1).unwrap().shader_node,
  ).unwrap()
  let s2 = @nodes.ShaderNodeInternal::of(
    @nodes.FnNode::of(f2).unwrap().shader_node,
  ).unwrap()
  let l1 = s1.layout.unwrap()
  let l2 = s2.layout.unwrap()
  // `'fn' + fnId++`: consecutive names
  let n1 = tsl_test_fn_number(l1.name)
  let n2 = tsl_test_fn_number(l2.name)
  assert_true(l1.name.has_prefix("fn"))
  tsl_inspect(n2 - n1, content="1")
  tsl_inspect(tsl_opt(l1.type_), content="Some(vec3)")
  tsl_inspect(tsl_opt(l2.type_), content="None")
  tsl_inspect(
    l1.inputs.map(fn(i) { "\{i.name}:\{i.type_}" }).join(","),
    content="a:float",
  )
  let shader1 = @nodes.FnNode::of(f1).unwrap().shader_node
  tsl_inspect(tsl_opt(shader1.node_type), content="Some(vec3)")
  tsl_inspect(f1.type_(), content="Node")
  tsl_inspect(shader1.type_(), content="Node")
  assert_true(shader1.global)
  // a `void` function call is a statement, not assignable
  let x = @nodes.ConstNode::new(Number(2.0), node_type="float")
  let f3 = @nodes.fn_(fn(_, _) { None }, layout=ReturnType("void"))
  let call3 = f3.call([x])
  tsl_inspect(call3.class_.class_name(), content="ShaderCallNodeInternal")
  assert_false(call3.assignable)
  tsl_inspect(call3.type_(), content="Node")
  let raw3 = @nodes.ShaderCallNodeInternal::of(call3).unwrap().raw_inputs.unwrap()
  tsl_inspect(raw3.length(), content="1")
  assert_true(raw3[0] is Node(n) && n.same(x))
  let call1 = f1.call([x, 2])
  assert_true(call1.assignable)
  tsl_inspect(
    call1._get_children().map(fn(c) { c.property }).join(","),
    content="shaderNode,rawInputs",
  )
  let fo = @nodes.fn_(fn(_, _) { None }).once(sub_builds=["NORMAL"])
  let so = @nodes.ShaderNodeInternal::of(
    @nodes.FnNode::of(fo).unwrap().shader_node,
  ).unwrap()
  assert_true(so.once)
  tsl_inspect(so.sub_builds.unwrap().join(","), content="NORMAL")
}

///|
test "fn inputs" {
  let a = @nodes.ConstNode::new(Number(1.0), node_type="float")
  let b = @nodes.ConstNode::new(Number(2.0), node_type="float")
  // `( { x, y } ) =>` over positional node arguments takes them in order
  let positional = @nodes.FnInputs::new([Node(a), Node(b)])
  assert_true(positional.named("x").unwrap().same(a))
  assert_true(positional.named("y").unwrap().same(b))
  assert_true(positional.named("z") is None)
  // `( [ x, y = d ] ) =>`
  let arr = @nodes.FnInputs::new([Node(a)])
  assert_true(arr.get(0).unwrap().same(a))
  assert_true(arr.get(1) is None)
  // `( { b } ) =>` over one plain object reads by name
  let object = @nodes.FnInputs::new([Object({ "a": Node(a), "b": Node(b) })])
  assert_true(object.named("b").unwrap().same(b))
  assert_true(object.named("a").unwrap().same(a))
  // the layout inputs object iterates its values
  assert_true(object.get(1).unwrap().same(b))
}
