// nodes/geometry/RangeNode.js: per-instance random values between two constants,
// hashed from the instance index, an object seed and a per-node salt.

///|
/// `_rangeId`.
let _range_node_id : Ref[Int32] = Ref(0)

///|
/// `Math.imul( a, b ) >>> 0`.
extern "js" fn range_node_imul_u32(a : Double, b : Double) -> Double = "(a, b) => Math.imul( a, b ) >>> 0"

///|
/// `objectSeed`: the per-object seed shared by all range nodes, so the values differ
/// between objects.
let _range_node_object_seed : Node = module_nodes(
  "nodes/geometry/RangeNode.js:objectSeed",
  fn() {
    uniform(0, type_="uint").on_object_update(fn(n, frame) {
      let object_id = match frame.object {
        Some(o) => o.id.to_double()
        None => 0.0 // compute has no object
      }
      InputNode::set_value(
        n,
        Number(range_node_imul_u32(object_id, 2654435769.0)),
      )
      None
    })
  },
)

///|
pub(all) struct RangeNode {
  mut min_node : Node
  mut max_node : Node
  /// `_salt`.
  _salt : Double
}

///|
pub impl NodeClass for RangeNode with fn class_name(_) {
  "RangeNode"
}

///|
pub impl NodeClass for RangeNode with fn children(self, _, out) {
  push_child(out, "minNode", Some(self.min_node))
  push_child(out, "maxNode", Some(self.max_node))
}

///|
pub impl NodeClass for RangeNode with fn is_cacheable(_, _, _) {
  false
}

///|
/// `getConstNode( node )`: the last `ConstNode` in the graph of `node`.
pub fn RangeNode::get_const_node(_self : RangeNode, node : Node) -> Node {
  let mut output : Node? = None
  node.traverse(fn(n) { if n.has_flag("isConstNode") { output = Some(n) } })
  match output {
    Some(n) => n
    None => abort("THREE.TSL: No \"ConstNode\" found in node graph.")
  }
}

///|
/// `getVectorLength( builder )`.
pub fn RangeNode::get_vector_length(
  self : RangeNode,
  builder : NodeBuilder,
) -> Int32 {
  let min_node = self.get_const_node(self.min_node)
  let max_node = self.get_const_node(self.max_node)
  let min_length = builder.get_type_length(
    get_value_type(InputNode::get_value(min_node)),
  )
  let max_length = builder.get_type_length(
    get_value_type(InputNode::get_value(max_node)),
  )
  if min_length > max_length {
    min_length
  } else {
    max_length
  }
}

///|
pub impl NodeClass for RangeNode with fn generate_node_type(self, _, builder, _) {
  Some(builder.get_type_from_length(self.get_vector_length(builder)))
}

///|
/// `x || 0`.
fn range_node_or_zero(x : Double) -> Double {
  if x == 0.0 || x != x {
    0.0
  } else {
    x
  }
}

///|
/// The `Vector4` of a range bound.
fn range_node_bound(value : TslValue, length : Int32) -> @math.Vector4 {
  let v = @math.Vector4::new(0.0, 0.0, 0.0, 1.0)
  if length == 1 {
    v.set_scalar(tsl_to_number(value)) |> ignore
  } else {
    match value {
      Color(c) => v.set(c.r, c.g, c.b, 1.0) |> ignore
      Vector2(p) => v.set(p.x, p.y, 0.0, 0.0) |> ignore
      Vector3(p) => v.set(p.x, p.y, range_node_or_zero(p.z), 0.0) |> ignore
      Vector4(p) =>
        v.set(p.x, p.y, range_node_or_zero(p.z), range_node_or_zero(p.w))
        |> ignore
      _ => abort("RangeNode: unsupported range value")
    }
  }
  v
}

///|
pub impl NodeClass for RangeNode with fn setup(self, node, builder) {
  let min_node = self.get_const_node(self.min_node)
  let max_node = self.get_const_node(self.max_node)
  let min_value = InputNode::get_value(min_node)
  let max_value = InputNode::get_value(max_node)
  let min_length = builder.get_type_length(get_value_type(min_value))
  let max_length = builder.get_type_length(get_value_type(max_value))
  let min = range_node_bound(min_value, min_length)
  let max = range_node_bound(max_value, max_length)
  // The values are hashed from the instance index instead of stored per object, so
  // they work for any instance count. The salt decorrelates range nodes.
  let seed = _range_node_object_seed.bit_xor(uint(self._salt))
  let index = instance_index.mul(4).add(seed)
  let random = vec4_of([
    hash_tsl.call([index]),
    hash_tsl.call([index.add(1)]),
    hash_tsl.call([index.add(2)]),
    hash_tsl.call([index.add(3)]),
  ])
  Some(
    mix(vec4(min), vec4(max), random).convert(
      operator_node_str(node.get_node_type(builder)),
    ),
  )
}

///|
/// The constructor body: `super()` has run in `Node::alloc`.
pub fn RangeNode::construct(
  _node : Node,
  min_node : Node,
  max_node : Node,
) -> RangeNode {
  let salt = range_node_imul_u32(_range_node_id.val.to_double(), 2246822507.0)
  _range_node_id.val += 1
  { min_node, max_node, _salt: salt, }
}

///|
/// `new RangeNode( minNode = float(), maxNode = float() )`.
pub fn RangeNode::new(min_node? : Node, max_node? : Node) -> Node {
  let min_node = match min_node {
    Some(n) => n
    None => float_of([])
  }
  let max_node = match max_node {
    Some(n) => n
    None => float_of([])
  }
  let node = Node::alloc()
  node.set_class(RangeNode::construct(node, min_node, max_node))
}

///|
pub fn RangeNode::of(node : Node) -> RangeNode? {
  match node.class_payload("RangeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `range( min, max )` (`nodeProxy( RangeNode )`).
pub fn range(min_node : &IntoTsl, max_node : &IntoTsl) -> Node {
  let p = tsl_verify_params(
    "RangeNode",
    [min_node.to_tsl(), max_node.to_tsl()],
    2,
    2,
  )
  let nodes = p.map(tsl_proxy_arg)
  RangeNode::new(min_node?=nodes[0], max_node?=nodes[1])
}
