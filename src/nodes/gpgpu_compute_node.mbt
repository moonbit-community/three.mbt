// nodes/gpgpu/ComputeNode.js

///|
/// `computeNode.dispatchSize` and the `dispatchSize` of `renderer.compute( node,
/// dispatchSize )`: a count, `[ x, y, z ]` workgroups, or an
/// `IndirectStorageBufferAttribute`.
pub(all) enum ComputeDispatchSize {
  Count(Int32)
  Size(Array[Int32])
  Indirect(@core.BufferAttribute)
}

///|
/// A compute kernel: `computeNode` runs once per invocation.
pub(all) struct ComputeNode {
  mut compute_node : Node
  /// `[ x, y, z ]`, filled up with 1s.
  mut workgroup_size : Array[Int32]
  /// The invocation count of `compute( node, count )`; `None` is `null`.
  mut count : Int32?
  /// `None` is `null`.
  mut dispatch_size : ComputeDispatchSize?
  /// `onInit( callback )`: called with the node and `{ renderer }` before the first
  /// dispatch.
  mut on_init_function : ((Node, Renderer) -> Unit)?
  /// The `uint` uniform holding `count`, created by `setup`.
  mut count_node : Node?
}

///|
pub impl NodeClass for ComputeNode with fn class_name(_) {
  "ComputeNode"
}

///|
pub impl NodeClass for ComputeNode with fn has_flag(_, flag) {
  flag == "isComputeNode"
}

///|
pub impl NodeClass for ComputeNode with fn children(self, _, out) {
  push_child(out, "computeNode", Some(self.compute_node))
  push_child(out, "countNode", self.count_node)
}

///|
pub impl NodeClass for ComputeNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ComputeNode with fn set_name(_, node, name) {
  node.name = Some(name)
  Some(node)
}

///|
pub impl NodeClass for ComputeNode with fn label(_, node, name) {
  @core.warn("TSL: \"label()\" has been deprecated. Use \"setName()\" instead.")
  Some(node.set_name(name))
}

///|
pub impl NodeClass for ComputeNode with fn get_update_before_type(
  _,
  node,
  frame,
) {
  match frame {
    Some(frame) if frame.compute is Some(c) && physical_equal(c, node) =>
      NodeUpdateType::none()
    _ => node.update_before_type
  }
}

///|
pub impl NodeClass for ComputeNode with fn update_before(_, node, frame) {
  match frame.renderer {
    Some(renderer) => renderer_compute(renderer, node)
    None =>
      abort("TypeError: Cannot read properties of null (reading 'compute')")
  }
  None
}

///|
pub impl NodeClass for ComputeNode with fn setup(self, node, builder) {
  if self.count is Some(count) && self.count_node is None {
    self.count_node = Some(
      uniform(count, type_="uint").on_object_update(fn(n, _) {
        // `onObjectUpdate( () => this.count )`
        match self.count {
          Some(c) => InputNode::set_value(n, Number(c.to_double()))
          None => InputNode::set_value(n, Null)
        }
        None
      }),
    )
  }
  let result = self.compute_node.build_node(builder)
  if result is Some(result) {
    let properties = builder.get_node_properties(node)
    // `result.outputNode`: the output of the stack a `Fn` call builds to.
    match StackNode::of(result) {
      Some(stack) => {
        properties.set_node_or_null("outputComputeNode", stack.output_node)
        stack.output_node = None
      }
      None => properties.set("outputComputeNode", Null)
    }
  }
  result
}

///|
pub impl NodeClass for ComputeNode with fn generate(self, node, builder, output) {
  if builder.shader_stage == Some("compute") {
    let snippet = self.compute_node.build(builder, output="void")
    if snippet != "" {
      builder.add_line_flow_code(snippet, node~) |> ignore
    }
    if self.count is Some(_) && builder.allow_early_returns == true {
      let count_snippet = match self.count_node {
        Some(c) => c.build(builder, output="uint")
        None =>
          abort("TypeError: Cannot read properties of null (reading 'build')")
      }
      let index_snippet = instance_index.build(builder, output="uint")
      builder.flow.code = "\{builder.tab}if ( \{index_snippet} >= \{count_snippet} ) { return; }\n\n\{builder.flow.code}"
    }
    None
  } else {
    let properties = builder.get_node_properties(node)
    match properties.get_node("outputComputeNode") {
      Some(output_compute_node) =>
        Some(output_compute_node.build(builder, output?))
      None => None
    }
  }
}

///|
/// `renderer.compute( this )`.
fn renderer_compute(renderer : Renderer, node : Node) -> Unit {
  renderer.compute(node)
}

///|
pub fn ComputeNode::construct(
  node : Node,
  compute_node : Node,
  workgroup_size : Array[Int32],
) -> ComputeNode {
  node.version = 1
  node.name = Some("")
  node.update_before_type = NodeUpdateType::frame()
  {
    compute_node,
    workgroup_size,
    count: None,
    dispatch_size: None,
    on_init_function: None,
    count_node: None,
  }
}

///|
/// `new ComputeNode( computeNode, workgroupSize )`.
pub fn ComputeNode::new(
  compute_node : Node,
  workgroup_size : Array[Int32],
) -> Node {
  let node = Node::alloc(node_type="void")
  node.set_class(ComputeNode::construct(node, compute_node, workgroup_size))
}

///|
pub fn ComputeNode::of(node : Node) -> ComputeNode? {
  match node.class_payload("ComputeNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn compute_node_payload(node : Node, name : String) -> ComputeNode {
  match ComputeNode::of(node) {
    Some(c) => c
    None => abort("TypeError: \{node.type_()}.\{name} is not a function")
  }
}

///|
/// `onInit( callback )`.
pub fn Node::on_init(self : Node, callback : (Node, Renderer) -> Unit) -> Node {
  compute_node_payload(self, "onInit").on_init_function = Some(callback)
  self
}

///|
/// `computeKernel( node, workgroupSize = [ 64 ] )`: a kernel dispatched with an
/// explicit dispatch size.
pub fn compute_kernel(
  node : &IntoTsl,
  workgroup_size~ : Array[Int32] = [64],
) -> Node {
  if workgroup_size.length() == 0 || workgroup_size.length() > 3 {
    @core.error("TSL: compute() workgroupSize must have 1, 2, or 3 elements")
  }
  for i, val in workgroup_size {
    if val <= 0 {
      @core.error(
        "TSL: compute() workgroupSize element at index [ \{i} ] must be a positive integer",
      )
    }
  }
  // Implicit fill-up to [ x, y, z ] with 1s, just like WGSL treats @workgroup_size when fewer dimensions are specified
  while workgroup_size.length() < 3 {
    workgroup_size.push(1)
  }
  ComputeNode::new(node_object(node.to_tsl()), workgroup_size)
}

///|
/// `compute( node, count, workgroupSize )`: a kernel run `count` times.
pub fn compute(
  node : &IntoTsl,
  count : Int32,
  workgroup_size? : Array[Int32],
) -> Node {
  let compute_node = compute_kernel(node, workgroup_size?)
  compute_node_payload(compute_node, "compute").count = Some(count)
  compute_node
}

///|
/// `compute( node, dispatchSize, workgroupSize )` with a dispatch size that is not a
/// number (`[ x, y, z ]` or an indirect attribute); `Count(n)` is `compute( node, n )`.
pub fn compute_dispatch(
  node : &IntoTsl,
  dispatch_size : ComputeDispatchSize,
  workgroup_size? : Array[Int32],
) -> Node {
  let compute_node = compute_kernel(node, workgroup_size?)
  let payload = compute_node_payload(compute_node, "compute")
  match dispatch_size {
    Count(n) => payload.count = Some(n)
    other => payload.dispatch_size = Some(other)
  }
  compute_node
}

///|
/// `node.compute( count, workgroupSize )`.
pub fn Node::compute(
  self : Node,
  count : Int32,
  workgroup_size? : Array[Int32],
) -> Node {
  compute(self, count, workgroup_size?)
}

///|
/// `node.compute( dispatchSize, workgroupSize )` with a non-number dispatch size.
pub fn Node::compute_dispatch(
  self : Node,
  dispatch_size : ComputeDispatchSize,
  workgroup_size? : Array[Int32],
) -> Node {
  compute_dispatch(self, dispatch_size, workgroup_size?)
}

///|
/// `node.computeKernel( workgroupSize )`.
pub fn Node::compute_kernel(
  self : Node,
  workgroup_size~ : Array[Int32] = [64],
) -> Node {
  compute_kernel(self, workgroup_size~)
}
