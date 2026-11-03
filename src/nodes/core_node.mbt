// nodes/core/Node.js: the base of every node, and how node classes plug in.
//
// A node is one `Node` struct (upstream's own `Node` fields) whose `class_` is the
// payload of its most derived class, a struct implementing `NodeClass`. A payload
// embeds its superclass's payload, and `parent` returns it, so a method a class does
// not override falls through to the superclass, ending at `Node::m_base` (upstream's
// `Node.prototype.m`). An override reaches `super.m` by calling the method on its
// parent payload (or `node.m_base` for direct subclasses of `Node`). Methods always
// take the `Node` and call other virtual methods through it, so `this.foo()` inside a
// superclass method still reaches the most derived override. See PORTING.md.

///|
/// `_nodeId`: nodes created at run time count from upstream's first run-time id; the
/// module-level ones take upstream's ids through `module_nodes` (core_module_nodes.mbt).
let _node_id : Ref[Int32] = Ref(NODE_FIRST_RUNTIME_ID)

///|
/// `Node.captureStackTrace`.
pub let node_capture_stack_trace : Ref[Bool] = Ref(false)

///|
/// Where a child node sits in its parent: `this[property]`, `this[property][index]`
/// for arrays, or `this[property][key]` for plain objects.
#derive(Eq, Debug)
pub(all) enum NodeChildIndex {
  Index(Int32)
  Key(String)
}

///|
/// One entry of upstream's `_getChildren()`.
pub(all) struct NodeChild {
  property : String
  index : NodeChildIndex?
  child_node : Node
}

///|
/// The `output` argument of `build`: `null`, an output type in the generate stage, or
/// the parent node in the analyze stage.
pub(all) enum BuildOutput {
  NoOutput
  Type(String)
  Parent(Node)
}

///|
/// What `build` returns: `null` (analyze), a node (setup) or a snippet (generate).
pub(all) enum BuildResult {
  Null
  NodeResult(Node)
  Snippet(String)
}

///|
pub fn BuildResult::snippet(self : BuildResult) -> String? {
  match self {
    Snippet(s) => Some(s)
    _ => None
  }
}

///|
pub fn BuildResult::node(self : BuildResult) -> Node? {
  match self {
    NodeResult(n) => Some(n)
    _ => None
  }
}

///|
pub fn BuildOutput::of_type(output : String?) -> BuildOutput {
  match output {
    Some(t) => Type(t)
    None => NoOutput
  }
}

///|
/// The output type, `null` for no output or a parent node.
pub fn BuildOutput::type_(self : BuildOutput) -> String? {
  match self {
    Type(t) => Some(t)
    _ => None
  }
}

///|
/// Upstream's `Node` instance fields. `class_` is the most derived class payload.
pub(all) struct Node {
  id : Int32
  dispatcher : @core.EventDispatcher
  mut class_ : &NodeClass
  mut node_type : String?
  mut update_type : String
  mut update_before_type : String
  mut update_after_type : String
  mut version : Int32
  /// `null` for some subclasses (`VarNode`), `''` by default.
  mut name : String?
  mut global : Bool
  mut parents : Bool
  mut assignable : Bool
  mut _inspector_node : Node?
  mut _cache_key : Double?
  mut _uuid : String?
  mut _cache_key_version : Int32
  mut stack_trace : StackTrace?
  /// `this.update = callback.bind( this )` from `onUpdate`; overrides the class.
  mut update_override : ((Node, NodeFrame) -> Bool?)?
  /// `this.updateReference = callback.bind( this )` from `onReference`.
  mut update_reference_override : ((Node, NodeUpdateState) -> @core.JsValue)?
}

///|
/// The argument of `updateReference`, `update`, `updateBefore`: a builder during the
/// build, a frame when rendering.
pub(all) enum NodeUpdateState {
  Builder(NodeBuilder)
  Frame(NodeFrame)
}

///|
/// The overridable methods of upstream node classes. Every default walks to the parent
/// class payload, ending at the `Node::*_base` implementation.
pub(open) trait NodeClass {
  /// The JS class name, used to find a class payload in the chain (`X::of`).
  fn class_name(Self) -> String
  /// Upstream's `static get type()`. Defaults to `class_name`; a class without its
  /// own `static get type()` returns its parent's.
  fn type_name(Self) -> String = _
  /// The superclass payload, `None` for direct subclasses of `Node`.
  fn parent(Self) -> &NodeClass? = _
  /// The payload as a JS value, so `X::of` can cast it back.
  fn payload(Self) -> @core.JsValue = _
  /// Upstream `isFoo` flags set by this class or a superclass.
  fn has_flag(Self, String) -> Bool = _
  /// Appends this class's node-valued properties, in JS property order, after the
  /// parent's. Upstream's `_getChildren`, minus private (`_`) properties.
  fn children(Self, Node, Array[NodeChild]) -> Unit = _
  /// `generate.length >= 2`: whether `generate` takes the output type.
  fn generate_uses_output(Self) -> Bool = _
  fn is_cacheable(Self, Node, NodeBuilder) -> Bool = _
  fn is_global(Self, Node, NodeBuilder) -> Bool = _
  fn get_hash(Self, Node, NodeBuilder) -> String = _
  fn custom_cache_key(Self, Node) -> Double = _
  fn get_scope(Self, Node) -> Node = _
  fn get_update_type(Self, Node) -> String = _
  /// `getUpdateBeforeType( frame )`: NodeFrame passes itself (ComputeNode reads it).
  fn get_update_before_type(Self, Node, NodeFrame?) -> String = _
  fn get_update_after_type(Self, Node) -> String = _
  fn get_element_type(Self, Node, NodeBuilder) -> String? = _
  fn get_member_type(Self, Node, NodeBuilder, String) -> String = _
  fn get_node_type(Self, Node, NodeBuilder, String?) -> String? = _
  fn generate_node_type(Self, Node, NodeBuilder, String?) -> String? = _
  fn get_shared(Self, Node, NodeBuilder) -> Node = _
  fn get_array_count(Self, Node, NodeBuilder) -> Int32? = _
  fn update_reference(Self, Node, NodeUpdateState) -> @core.JsValue = _
  fn setup(Self, Node, NodeBuilder) -> Node? = _
  fn analyze(Self, Node, NodeBuilder, Node?) -> Unit = _
  fn generate(Self, Node, NodeBuilder, String?) -> String? = _
  fn build(Self, Node, NodeBuilder, BuildOutput) -> BuildResult = _
  fn update_before(Self, Node, NodeFrame) -> Bool? = _
  fn update_after(Self, Node, NodeFrame) -> Bool? = _
  fn update(Self, Node, NodeFrame) -> Bool? = _
  fn dispose(Self, Node) -> Unit = _
  fn serialize(Self, Node, @core.JsValue) -> Unit = _
  fn deserialize(Self, Node, @core.JsValue) -> Unit = _
  fn get_serialize_children(Self, Node) -> Array[NodeChild] = _
  fn declares_assignable(Self, Node) -> Bool = _
  fn is_function_scope(Self, Node) -> Bool = _
  /// Class overrides of the chained TSL methods `element`, `label`, `setName`;
  /// `None` falls back to the TSL function.
  fn element(Self, Node, Node) -> Node? = _
  fn label(Self, Node, String) -> Node? = _
  fn set_name(Self, Node, String) -> Node? = _
  /// `call( ...params )`: `FnNode` overrides it; `None` falls back to the chained
  /// `call` of FunctionCallNode.
  fn call(Self, Node, Array[TslValue]) -> Node? = _
  /// `onUpdate( callback, updateType )`; `None` uses `Node.prototype.onUpdate`.
  fn on_update(Self, Node, (Node, NodeFrame) -> Bool?, String) -> Node? = _
  /// `setAtomic( value )` of WorkgroupInfoNode and StorageBufferNode; `None` for other
  /// classes (a `TypeError` upstream).
  fn set_atomic(Self, Node, Bool) -> Node? = _
  /// An instance's own `assign` (upstream `depth.assign = ( value ) => ...`); `None`
  /// uses the chained `assign`.
  fn assign(Self, Node, TslValue) -> Node? = _
  /// `setSize( width, height )` of PassNode and RTTNode; `false` for other classes (a
  /// `TypeError` upstream).
  fn set_size(Self, Node, Double, Double) -> Bool = _
}

///|
impl NodeClass with fn type_name(self) {
  self.class_name()
}

///|
impl NodeClass with fn parent(_) {
  None
}

///|
impl NodeClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl NodeClass with fn has_flag(self, flag) {
  match self.parent() {
    Some(p) => p.has_flag(flag)
    None => false
  }
}

///|
impl NodeClass with fn children(self, node, out) {
  match self.parent() {
    Some(p) => p.children(node, out)
    None => ()
  }
}

///|
impl NodeClass with fn generate_uses_output(self) {
  match self.parent() {
    Some(p) => p.generate_uses_output()
    None => true
  }
}

///|
impl NodeClass with fn is_cacheable(self, node, builder) {
  match self.parent() {
    Some(p) => p.is_cacheable(node, builder)
    None => node.is_cacheable_base(builder)
  }
}

///|
impl NodeClass with fn is_global(self, node, builder) {
  match self.parent() {
    Some(p) => p.is_global(node, builder)
    None => node.is_global_base(builder)
  }
}

///|
impl NodeClass with fn get_hash(self, node, builder) {
  match self.parent() {
    Some(p) => p.get_hash(node, builder)
    None => node.get_hash_base(builder)
  }
}

///|
impl NodeClass with fn custom_cache_key(self, node) {
  match self.parent() {
    Some(p) => p.custom_cache_key(node)
    None => node.custom_cache_key_base()
  }
}

///|
impl NodeClass with fn get_scope(self, node) {
  match self.parent() {
    Some(p) => p.get_scope(node)
    None => node
  }
}

///|
impl NodeClass with fn get_update_type(self, node) {
  match self.parent() {
    Some(p) => p.get_update_type(node)
    None => node.update_type
  }
}

///|
impl NodeClass with fn get_update_before_type(self, node, frame) {
  match self.parent() {
    Some(p) => p.get_update_before_type(node, frame)
    None => node.update_before_type
  }
}

///|
impl NodeClass with fn get_update_after_type(self, node) {
  match self.parent() {
    Some(p) => p.get_update_after_type(node)
    None => node.update_after_type
  }
}

///|
impl NodeClass with fn get_element_type(self, node, builder) {
  match self.parent() {
    Some(p) => p.get_element_type(node, builder)
    None => node.get_element_type_base(builder)
  }
}

///|
impl NodeClass with fn get_member_type(self, node, builder, name) {
  match self.parent() {
    Some(p) => p.get_member_type(node, builder, name)
    None => "void"
  }
}

///|
impl NodeClass with fn get_node_type(self, node, builder, output) {
  match self.parent() {
    Some(p) => p.get_node_type(node, builder, output)
    None => node.get_node_type_base(builder, output)
  }
}

///|
impl NodeClass with fn generate_node_type(self, node, builder, output) {
  match self.parent() {
    Some(p) => p.generate_node_type(node, builder, output)
    None => node.generate_node_type_base(builder, output)
  }
}

///|
impl NodeClass with fn get_shared(self, node, builder) {
  match self.parent() {
    Some(p) => p.get_shared(node, builder)
    None => node.get_shared_base(builder)
  }
}

///|
impl NodeClass with fn get_array_count(self, node, builder) {
  match self.parent() {
    Some(p) => p.get_array_count(node, builder)
    None => None
  }
}

///|
impl NodeClass with fn update_reference(self, node, state) {
  match self.parent() {
    Some(p) => p.update_reference(node, state)
    None => @core.JsValue::of(node)
  }
}

///|
impl NodeClass with fn setup(self, node, builder) {
  match self.parent() {
    Some(p) => p.setup(node, builder)
    None => node.setup_base(builder)
  }
}

///|
impl NodeClass with fn analyze(self, node, builder, output) {
  match self.parent() {
    Some(p) => p.analyze(node, builder, output)
    None => node.analyze_base(builder, output)
  }
}

///|
impl NodeClass with fn generate(self, node, builder, output) {
  match self.parent() {
    Some(p) => p.generate(node, builder, output)
    None => node.generate_base(builder, output)
  }
}

///|
impl NodeClass with fn build(self, node, builder, output) {
  match self.parent() {
    Some(p) => p.build(node, builder, output)
    None => node.build_base(builder, output)
  }
}

///|
impl NodeClass with fn update_before(self, node, frame) {
  match self.parent() {
    Some(p) => p.update_before(node, frame)
    None => {
      @core.warn("Abstract function.")
      None
    }
  }
}

///|
impl NodeClass with fn update_after(self, node, frame) {
  match self.parent() {
    Some(p) => p.update_after(node, frame)
    None => {
      @core.warn("Abstract function.")
      None
    }
  }
}

///|
impl NodeClass with fn update(self, node, frame) {
  match self.parent() {
    Some(p) => p.update(node, frame)
    None => {
      @core.warn("Abstract function.")
      None
    }
  }
}

///|
impl NodeClass with fn dispose(self, node) {
  match self.parent() {
    Some(p) => p.dispose(node)
    None => node.dispose_base()
  }
}

///|
impl NodeClass with fn serialize(self, node, json) {
  match self.parent() {
    Some(p) => p.serialize(node, json)
    None => node.serialize_base(json)
  }
}

///|
impl NodeClass with fn deserialize(self, node, json) {
  match self.parent() {
    Some(p) => p.deserialize(node, json)
    None => node.deserialize_base(json)
  }
}

///|
impl NodeClass with fn get_serialize_children(self, node) {
  match self.parent() {
    Some(p) => p.get_serialize_children(node)
    None => node._get_children()
  }
}

///|
impl NodeClass with fn declares_assignable(self, node) {
  match self.parent() {
    Some(p) => p.declares_assignable(node)
    None => true
  }
}

///|
impl NodeClass with fn is_function_scope(self, node) {
  match self.parent() {
    Some(p) => p.is_function_scope(node)
    None => false
  }
}

///|
impl NodeClass with fn element(self, node, index) {
  match self.parent() {
    Some(p) => p.element(node, index)
    None => None
  }
}

///|
impl NodeClass with fn label(self, node, name) {
  match self.parent() {
    Some(p) => p.label(node, name)
    None => None
  }
}

///|
impl NodeClass with fn set_name(self, node, name) {
  match self.parent() {
    Some(p) => p.set_name(node, name)
    None => None
  }
}

///|
impl NodeClass with fn call(self, node, params) {
  match self.parent() {
    Some(p) => p.call(node, params)
    None => None
  }
}

///|
impl NodeClass with fn on_update(self, node, callback, update_type) {
  match self.parent() {
    Some(p) => p.on_update(node, callback, update_type)
    None => None
  }
}

///|
impl NodeClass with fn set_size(self, node, width, height) {
  match self.parent() {
    Some(p) => p.set_size(node, width, height)
    None => false
  }
}

///|
/// `setSize( width, height )` (PassNode, RTTNode).
pub fn Node::set_size(self : Node, width : Double, height : Double) -> Unit {
  if !self.class_.set_size(self, width, height) {
    abort("TypeError: \{self.type_()}.setSize is not a function")
  }
}

///|
impl NodeClass with fn assign(self, node, value) {
  match self.parent() {
    Some(p) => p.assign(node, value)
    None => None
  }
}

///|
impl NodeClass with fn set_atomic(self, node, value) {
  match self.parent() {
    Some(p) => p.set_atomic(node, value)
    None => None
  }
}

///|
/// `setAtomic( value )`, chained (WorkgroupInfoNode, StorageBufferNode).
pub fn Node::set_atomic(self : Node, value : Bool) -> Node {
  match self.class_.set_atomic(self, value) {
    Some(n) => n
    None => abort("TypeError: \{self.type_()}.setAtomic is not a function")
  }
}

///|
/// `toAtomic()`: `setAtomic( true )`.
pub fn Node::to_atomic(self : Node) -> Node {
  self.set_atomic(true)
}

///|
/// The class of a plain `new Node( nodeType )`, and of a node under construction.
pub(all) struct BaseNode {}

///|
pub impl NodeClass for BaseNode with fn class_name(_) {
  "Node"
}

///|
/// `super()`: allocates the node (taking the next id, as upstream's constructor does
/// before the subclass fields run). The subclass constructor then builds its payload
/// and calls `set_class`.
pub fn Node::alloc(node_type? : String) -> Node {
  let id = _node_id.val
  _node_id.val += 1
  let node = Node::{
    id,
    dispatcher: @core.EventDispatcher::new(),
    class_: BaseNode::{ },
    node_type,
    update_type: NodeUpdateType::none(),
    update_before_type: NodeUpdateType::none(),
    update_after_type: NodeUpdateType::none(),
    version: 0,
    name: Some(""),
    global: false,
    parents: false,
    assignable: false,
    _inspector_node: None,
    _cache_key: None,
    _uuid: None,
    _cache_key_version: 0,
    stack_trace: None,
    update_override: None,
    update_reference_override: None,
  }
  if node_capture_stack_trace.val {
    node.stack_trace = Some(StackTrace::new())
  }
  module_nodes_note(node)
  node
}

///|
/// `new Node( nodeType )`.
pub fn Node::new(node_type? : String) -> Node {
  Node::alloc(node_type?)
}

///|
/// Installs the most derived class payload; the last step of a constructor.
pub fn Node::set_class(self : Node, class_ : &NodeClass) -> Node {
  self.class_ = class_
  self
}

///|
/// Finds the payload of class `name` in the chain, as a JS value for `X::of` to cast.
pub fn Node::class_payload(self : Node, name : String) -> @core.JsValue? {
  let mut c : &NodeClass? = Some(self.class_)
  while c is Some(k) {
    if k.class_name() == name {
      return Some(k.payload())
    }
    c = k.parent()
  }
  None
}

///|
/// Whether the node is an instance of the class `name` (upstream `instanceof`).
pub fn Node::is_instance_of(self : Node, name : String) -> Bool {
  self.class_payload(name) is Some(_)
}

///|
/// An upstream `isFoo` flag: `node.has_flag("isStackNode")`. `isNode` is always true.
pub fn Node::has_flag(self : Node, flag : String) -> Bool {
  flag == "isNode" || self.class_.has_flag(flag)
}

///|
/// Identity, `a === b`.
pub fn Node::same(self : Node, other : Node) -> Bool {
  physical_equal(self, other)
}

///|
pub impl Eq for Node with fn equal(a, b) {
  physical_equal(a, b)
}

///|
pub impl Hash for Node with fn hash_combine(self, hasher) {
  hasher.combine_int(self.id)
}

///|
pub fn Node::event_dispatcher(self : Node) -> @core.EventDispatcher {
  self.dispatcher
}

///|
pub fn Node::add_event_listener(
  self : Node,
  type_ : String,
  listener : (@core.Event) -> Unit,
) -> Unit {
  self.dispatcher.add_event_listener(type_, listener)
}

///|
pub fn Node::remove_event_listener(
  self : Node,
  type_ : String,
  listener : (@core.Event) -> Unit,
) -> Unit {
  self.dispatcher.remove_event_listener(type_, listener)
}

///|
pub fn Node::dispatch_event(self : Node, event : @core.Event) -> Unit {
  self.dispatcher.dispatch_event(event)
}

// ---------------------------------------------------------------------------
// Dispatching methods: upstream's `this.m( ... )`.

///|
pub fn Node::is_cacheable(self : Node, builder : NodeBuilder) -> Bool {
  self.class_.is_cacheable(self, builder)
}

///|
pub fn Node::is_cacheable_base(_self : Node, _builder : NodeBuilder) -> Bool {
  true
}

///|
/// Makes this node assignable and adds it to the current stack.
pub fn Node::to_assignable(self : Node) -> Node {
  self.assignable = true
  self.to_stack()
}

///|
pub fn Node::is_assignable(self : Node, builder : NodeBuilder) -> Bool {
  let data = builder.get_data_from_node(self)
  if data.force_declaration == Some(true) {
    return false
  }
  self.assignable
}

///|
pub fn Node::is_assign(self : Node, builder : NodeBuilder) -> Bool? {
  let data = builder.get_data_from_node(self)
  data.assign
}

///|
/// `_updateAssignable( builder, data, valueNode = this )`.
pub fn Node::_update_assignable(
  self : Node,
  builder : NodeBuilder,
  data : NodeData,
  value_node? : Node,
) -> Unit {
  let value_node = value_node.unwrap_or(self)
  let node_loop = builder.context.get_node("nodeLoop")
  if data.stack is None && builder.build_stage == Some("setup") {
    data.stack = builder.declare_before_block(self)
  } else if self.assignable &&
    node_loop is Some(node_loop) &&
    builder.build_stage == Some("analyze") {
    if !value_node.is_cacheable(builder) &&
      !builder.is_deterministic(value_node) {
      let declaration_index = match data.stack {
        Some(s) => index_of_stack(builder.active_stacks, s)
        None => -1
      }
      let loop_index = match builder.get_data_from_node(node_loop).stack {
        Some(s) => index_of_stack(builder.active_stacks, s)
        None => -1
      }
      if declaration_index != -1 && loop_index >= declaration_index {
        data.force_declaration = Some(true)
      }
    }
  }
}

///|
fn index_of_stack(stacks : Array[StackNode], stack : StackNode) -> Int32 {
  for i, s in stacks {
    if physical_equal(s.node, stack.node) {
      return i
    }
  }
  -1
}

///|
pub fn Node::_declares_assignable(self : Node) -> Bool {
  self.class_.declares_assignable(self)
}

///|
/// Declares a variable for this node in the current flow, initialized with `snippet`.
pub fn Node::_declare_variable(
  self : Node,
  builder : NodeBuilder,
  snippet : String,
  type_ : String?,
  read_only : Bool,
  property : String,
) -> String {
  let node_var = builder.get_var_from_node(
    self,
    None,
    type_,
    None,
    read_only,
    true,
    property,
  )
  let property_name = builder.get_property_name(Var(node_var))
  let declaration_prefix = if read_only {
    builder.generate_let_statement(
      node_var.type_,
      property_name,
      node_var.count,
    )
  } else {
    builder.generate_var_statement(
      node_var.type_,
      property_name,
      node_var.count,
    )
  }
  builder.add_line_flow_code("\{declaration_prefix} = \{snippet}", node=self)
  |> ignore
  property_name
}

///|
pub fn Node::_is_variable(
  self : Node,
  builder : NodeBuilder,
  node_data : NodeData,
) -> Bool {
  (node_data.assign == Some(true) || node_data.force_declaration == Some(true)) &&
  self.get_node_type(builder) != Some("void")
}

///|
pub fn Node::_build_variable(
  self : Node,
  builder : NodeBuilder,
  node_data : NodeData,
  output : String?,
) -> String {
  let node_type = self.get_node_type(builder)
  let type_ = builder.get_vector_type(node_type)
  if node_data.property_name is None {
    let snippet = if !self.class_.generate_uses_output() {
      builder.format(
        self.generate(builder, None).unwrap_or(""),
        node_type,
        type_,
      )
    } else {
      self.generate(builder, type_).unwrap_or("")
    }
    node_data.property_name = Some(
      self._declare_variable(builder, snippet, type_, false, "variable"),
    )
  }
  builder.format(node_data.property_name.unwrap(), type_, output)
}

///|
pub fn Node::_is_function_scope(self : Node) -> Bool {
  self.class_.is_function_scope(self)
}

///|
/// Discards the generated value if it is not visible in the current flow block.
pub fn Node::_check_flow_block(
  self : Node,
  builder : NodeBuilder,
  node_data : NodeData,
) -> Unit {
  guard node_data.flow_block is Some(data_block) else { return }
  let guard_ = data_block.guard_
  let parent = data_block.parent
  let is_function_scope = guard_ is Some(_) && self._is_function_scope()
  let mut flow_block = builder.flow_block
  while flow_block is Some(block) && !physical_equal(block, data_block) {
    if is_function_scope &&
      same_guard(block.guard_, guard_) &&
      same_block(block.parent, parent) {
      break
    }
    flow_block = block.parent
  }
  if flow_block is None {
    node_data.flow_block = None
    node_data.property_name = None
    node_data.snippet = None
    node_data.generated = None
  }
}

///|
fn same_guard(a : String?, b : String?) -> Bool {
  a == b
}

///|
fn same_block(a : FlowBlock?, b : FlowBlock?) -> Bool {
  match (a, b) {
    (Some(x), Some(y)) => physical_equal(x, y)
    (None, None) => true
    _ => false
  }
}

///|
/// Keeps the block where a value was generated, so it is only reused where visible.
pub fn Node::_set_flow_block(
  self : Node,
  builder : NodeBuilder,
  node_data : NodeData,
  is_cached : Bool,
  flow_code_length : Int32,
) -> Unit {
  let is_local = !self.is_global(builder) ||
    builder.flow.code.length() != flow_code_length
  if !is_cached &&
    (node_data.property_name is Some(_) || node_data.snippet is Some(_)) &&
    is_local &&
    builder.flow_block is Some(block) {
    node_data.flow_block = Some(block)
  }
}

///|
/// `set needsUpdate( value )`.
pub fn Node::set_needs_update(self : Node, value : Bool) -> Unit {
  if value {
    self.version += 1
  }
}

///|
pub fn Node::uuid(self : Node) -> String {
  match self._uuid {
    Some(u) => u
    None => {
      let u = @math.generate_uuid()
      self._uuid = Some(u)
      u
    }
  }
}

///|
/// `get type()`, the class's `static type`.
pub fn Node::type_(self : Node) -> String {
  self.class_.type_name()
}

///|
/// `onUpdate( callback, updateType )`.
pub fn Node::on_update(
  self : Node,
  callback : (Node, NodeFrame) -> Bool?,
  update_type : String,
) -> Node {
  match self.class_.on_update(self, callback, update_type) {
    Some(n) => n
    None => self.on_update_base(callback, update_type)
  }
}

///|
pub fn Node::on_update_base(
  self : Node,
  callback : (Node, NodeFrame) -> Bool?,
  update_type : String,
) -> Node {
  self.update_type = update_type
  self.update_override = Some(callback)
  self
}

///|
pub fn Node::on_frame_update(
  self : Node,
  callback : (Node, NodeFrame) -> Bool?,
) -> Node {
  self.on_update(callback, NodeUpdateType::frame())
}

///|
pub fn Node::on_render_update(
  self : Node,
  callback : (Node, NodeFrame) -> Bool?,
) -> Node {
  self.on_update(callback, NodeUpdateType::render())
}

///|
pub fn Node::on_object_update(
  self : Node,
  callback : (Node, NodeFrame) -> Bool?,
) -> Node {
  self.on_update(callback, NodeUpdateType::object())
}

///|
pub fn Node::on_reference(
  self : Node,
  callback : (Node, NodeUpdateState) -> @core.JsValue,
) -> Node {
  self.update_reference_override = Some(callback)
  self
}

///|
/// Returns the object this node refers to for update tracking (default: the node).
pub fn Node::update_reference(
  self : Node,
  state : NodeUpdateState,
) -> @core.JsValue {
  match self.update_reference_override {
    Some(f) => f(self, state)
    None => self.class_.update_reference(self, state)
  }
}

///|
pub fn Node::is_global(self : Node, builder : NodeBuilder) -> Bool {
  self.class_.is_global(self, builder)
}

///|
pub fn Node::is_global_base(self : Node, _builder : NodeBuilder) -> Bool {
  self.global
}

///|
pub fn Node::get_children(self : Node) -> Array[Node] {
  self._get_children().map(fn(c) { c.child_node })
}

///|
pub fn Node::dispose(self : Node) -> Unit {
  self.class_.dispose(self)
}

///|
pub fn Node::dispose_base(self : Node) -> Unit {
  self.dispatch_event(@core.Event::new("dispose"))
}

///|
pub fn Node::traverse(self : Node, callback : (Node) -> Unit) -> Unit {
  callback(self)
  for child_node in self.get_children() {
    child_node.traverse(callback)
  }
}

///|
/// `_getChildren( ignores )`: the node-valued properties, skipping `ignores` (which
/// gains this node) to avoid circular references.
pub fn Node::_get_children(self : Node, ignores? : NodeSet) -> Array[NodeChild] {
  let ignores = match ignores {
    Some(s) => s
    None => NodeSet::new()
  }
  ignores.add(self)
  let all = []
  self.class_.children(self, all)
  // `ignores.has( object )` is checked per property value; for a node property that
  // is the child itself. Arrays and objects are skipped only when the container is
  // ignored, which cannot happen for nodes.
  all.filter(fn(c) { c.index is Some(_) || !ignores.has(c.child_node) })
}

///|
/// `getCacheKey( force, ignores )`.
pub fn Node::get_cache_key(
  self : Node,
  force~ : Bool = false,
  ignores? : NodeSet,
) -> Double {
  let force = force || self.version != self._cache_key_version
  if force || self._cache_key is None {
    let ignores = match ignores {
      Some(s) => s
      None => NodeSet::new()
    }
    let values : Array[Double] = []
    for child in self._get_children(ignores~) {
      let property = child.property
      let trimmed = if property.length() > 4 {
        property.unsafe_substring(start=0, end=property.length() - 4)
      } else {
        ""
      }
      values.push(hash_string(trimmed))
      values.push(child.child_node.get_cache_key(force~, ignores~))
    }
    self._cache_key = Some(hash([hash_array(values), self.custom_cache_key()]))
    self._cache_key_version = self.version
  }
  self._cache_key.unwrap()
}

///|
pub fn Node::custom_cache_key(self : Node) -> Double {
  self.class_.custom_cache_key(self)
}

///|
pub fn Node::custom_cache_key_base(self : Node) -> Double {
  self.id.to_double()
}

///|
pub fn Node::get_scope(self : Node) -> Node {
  self.class_.get_scope(self)
}

///|
pub fn Node::get_hash(self : Node, builder : NodeBuilder) -> String {
  self.class_.get_hash(self, builder)
}

///|
pub fn Node::get_hash_base(self : Node, _builder : NodeBuilder) -> String {
  self.id.to_string()
}

///|
pub fn Node::get_update_type(self : Node) -> String {
  self.class_.get_update_type(self)
}

///|
pub fn Node::get_update_before_type(self : Node, frame? : NodeFrame) -> String {
  self.class_.get_update_before_type(self, frame)
}

///|
pub fn Node::get_update_after_type(self : Node) -> String {
  self.class_.get_update_after_type(self)
}

///|
pub fn Node::get_element_type(self : Node, builder : NodeBuilder) -> String? {
  self.class_.get_element_type(self, builder)
}

///|
pub fn Node::get_element_type_base(
  self : Node,
  builder : NodeBuilder,
) -> String? {
  let type_ = self.get_node_type(builder)
  builder.get_element_type(type_)
}

///|
pub fn Node::get_member_type(
  self : Node,
  builder : NodeBuilder,
  name : String,
) -> String {
  self.class_.get_member_type(self, builder, name)
}

///|
/// `getNodeType( builder, output = null )`; `None` is upstream's `null` type.
pub fn Node::get_node_type(
  self : Node,
  builder : NodeBuilder,
  output? : String,
) -> String? {
  self.class_.get_node_type(self, builder, output)
}

///|
pub fn Node::get_node_type_base(
  self : Node,
  builder : NodeBuilder,
  output : String?,
) -> String? {
  let node_data = builder.get_data_from_node(self)
  match output {
    Some(output) => {
      let map = match node_data.type_from_output {
        Some(m) => m
        None => {
          let m = Map::new()
          node_data.type_from_output = Some(m)
          m
        }
      }
      match map.get(output) {
        Some(t) => t
        None => {
          let t = self.generate_node_type(builder, Some(output))
          map.set(output, t)
          t
        }
      }
    }
    None =>
      match node_data.type_ {
        Some(t) => t
        None => {
          let t = self.generate_node_type(builder, None)
          node_data.type_ = Some(t)
          t
        }
      }
  }
}

///|
pub fn Node::generate_node_type(
  self : Node,
  builder : NodeBuilder,
  output : String?,
) -> String? {
  self.class_.generate_node_type(self, builder, output)
}

///|
pub fn Node::generate_node_type_base(
  self : Node,
  builder : NodeBuilder,
  output : String?,
) -> String? {
  let node_properties = builder.get_node_properties(self)
  match node_properties.get_node("outputNode") {
    Some(output_node) => output_node.get_node_type(builder, output?)
    None => self.node_type
  }
}

///|
pub fn Node::get_shared(self : Node, builder : NodeBuilder) -> Node {
  self.class_.get_shared(self, builder)
}

///|
pub fn Node::get_shared_base(self : Node, builder : NodeBuilder) -> Node {
  let hash = self.get_hash(builder)
  let node_from_hash = builder.get_node_from_hash(hash)
  let mut shared_node : Node? = None
  match node_from_hash {
    Some(n) if !physical_equal(n, self) => shared_node = Some(n)
    _ =>
      match builder.context.get_override_nodes() {
        Some(override_nodes) =>
          match override_nodes.get(self) {
            // `if ( callback )`: a `null` entry cancels an outer override.
            Some(callback) if !physical_equal(callback, override_callback_null) => {
              let node_data = builder.get_data_from_node(self)
              let overrides = match node_data.overrides {
                Some(o) => o
                None => {
                  let o = []
                  node_data.overrides = Some(o)
                  o
                }
              }
              match
                overrides.search_by(fn(e) { physical_equal(e.0, callback) }) {
                None => {
                  let entry = (callback, Ref(None))
                  overrides.push(entry)
                  let n = (callback.f)(builder).override_node(self, None)
                  entry.1.val = Some(n)
                  shared_node = Some(n)
                }
                Some(i) => shared_node = overrides[i].1.val
              }
            }
            _ => ()
          }
        None => ()
      }
  }
  shared_node.unwrap_or(self)
}

///|
pub fn Node::get_array_count(self : Node, builder : NodeBuilder) -> Int32? {
  self.class_.get_array_count(self, builder)
}

///|
pub fn Node::setup(self : Node, builder : NodeBuilder) -> Node? {
  self.class_.setup(self, builder)
}

///|
pub fn Node::setup_base(self : Node, builder : NodeBuilder) -> Node? {
  let node_properties = builder.get_node_properties(self)
  let mut index = 0
  for child_node in self.get_children() {
    node_properties.set_node("node" + index.to_string(), child_node)
    index += 1
  }
  node_properties.get_node("outputNode")
}

///|
pub fn Node::analyze(
  self : Node,
  builder : NodeBuilder,
  output? : Node,
) -> Unit {
  self.class_.analyze(self, builder, output)
}

///|
pub fn Node::analyze_base(
  self : Node,
  builder : NodeBuilder,
  output : Node?,
) -> Unit {
  let usage_count = builder.increase_usage(self)
  if self.parents {
    let node_data = builder.get_data_from_node(self, shader_stage="any")
    let stages = match node_data.stages {
      Some(s) => s
      None => {
        let s = Map::new()
        node_data.stages = Some(s)
        s
      }
    }
    let stage = builder.shader_stage.unwrap_or("undefined")
    let list = match stages.get(stage) {
      Some(l) => l
      None => {
        let l = []
        stages.set(stage, l)
        l
      }
    }
    list.push(output)
  }
  if usage_count == 1 {
    let node_properties = builder.get_node_properties(self)
    for child_node in node_properties.node_values() {
      child_node.build_output(builder, Parent(self)) |> ignore
    }
  }
}

///|
/// `generate( builder, output )`; `None` is `undefined`.
pub fn Node::generate(
  self : Node,
  builder : NodeBuilder,
  output : String?,
) -> String? {
  self.class_.generate(self, builder, output)
}

///|
pub fn Node::generate_base(
  self : Node,
  builder : NodeBuilder,
  output : String?,
) -> String? {
  match builder.get_node_properties(self).get_node("outputNode") {
    Some(output_node) =>
      output_node.build_output(builder, BuildOutput::of_type(output)).snippet()
    None => None
  }
}

///|
pub fn Node::update_before(self : Node, frame : NodeFrame) -> Bool? {
  self.class_.update_before(self, frame)
}

///|
pub fn Node::update_after(self : Node, frame : NodeFrame) -> Bool? {
  self.class_.update_after(self, frame)
}

///|
/// `update( frame )`, or the callback installed by `onUpdate`.
pub fn Node::update(self : Node, frame : NodeFrame) -> Bool? {
  match self.update_override {
    Some(f) => f(self, frame)
    None => self.class_.update(self, frame)
  }
}

///|
/// Whether `update` does something: an `onUpdate` callback or a class override.
pub fn Node::_setup_inspector(self : Node, builder : NodeBuilder) -> Unit {
  if self._inspector_node is Some(inspector) &&
    builder.build_stage == Some("setup") {
    builder.add_node(inspector)
  }
}

///|
/// `build( builder, output )` in the generate stage: the snippet, or `''`.
pub fn Node::build(
  self : Node,
  builder : NodeBuilder,
  output? : String,
) -> String {
  match self.build_output(builder, BuildOutput::of_type(output)) {
    Snippet(s) => s
    _ => ""
  }
}

///|
/// `build( builder )` in the setup stage: the output node.
pub fn Node::build_node(self : Node, builder : NodeBuilder) -> Node? {
  self.build_output(builder, NoOutput).node()
}

///|
/// `build( builder, output )` with its full result.
pub fn Node::build_output(
  self : Node,
  builder : NodeBuilder,
  output : BuildOutput,
) -> BuildResult {
  self.class_.build(self, builder, output)
}

///|
/// `Node.prototype.build`.
pub fn Node::build_base(
  self : Node,
  builder : NodeBuilder,
  output : BuildOutput,
) -> BuildResult {
  self._setup_inspector(builder)
  let ref_node = self.get_shared(builder)
  if !physical_equal(self, ref_node) {
    return ref_node.build_output(builder, output)
  }
  let node_data = builder.get_data_from_node(self)
  if self.assignable && self._declares_assignable() {
    self._update_assignable(builder, node_data)
  }
  let build_stages = match node_data.build_stages {
    Some(s) => s
    None => {
      let s = BuildStages::{ setup: false, analyze: false, generate: false, }
      node_data.build_stages = Some(s)
      s
    }
  }
  let current_stage = builder.build_stage
  match current_stage {
    Some("setup") => build_stages.setup = true
    Some("analyze") => build_stages.analyze = true
    Some("generate") => build_stages.generate = true
    _ => ()
  }
  let parent_build_stage = match current_stage {
    Some("analyze") => Some("setup")
    Some("generate") => Some("analyze")
    _ => None
  }
  if parent_build_stage is Some(parent_stage) {
    let done = if parent_stage == "setup" {
      build_stages.setup
    } else {
      build_stages.analyze
    }
    if !done {
      let previous_build_stage = builder.get_build_stage()
      builder.set_build_stage(Some(parent_stage))
      self.build_output(builder, NoOutput) |> ignore
      builder.set_build_stage(previous_build_stage)
    }
  }
  builder.add_chain(self)
  let mut result : BuildResult = Null
  let build_stage = builder.get_build_stage()
  if build_stage == Some("setup") {
    builder.add_node(self)
    self.update_reference(Builder(builder)) |> ignore
    let properties = builder.get_node_properties(self)
    if properties.get_bool("initialized") != Some(true) {
      properties.set_bool("initialized", true)
      let output_node = match self.setup(builder) {
        Some(n) => Some(n)
        None => properties.get_node("outputNode")
      }
      properties.set_node_or_null("outputNode", output_node)
      for child_node in properties.node_values() {
        if child_node.parents {
          let child_properties = builder.get_node_properties(child_node)
          child_properties.push_parent(self)
        }
        child_node.build_output(builder, NoOutput) |> ignore
      }
      builder.add_sequential_node(self)
    }
    result = match properties.get_node("outputNode") {
      Some(n) => NodeResult(n)
      None => Null
    }
  } else if build_stage == Some("analyze") {
    let parent = match output {
      Parent(p) => Some(p)
      _ => None
    }
    self.analyze(builder, output?=parent)
  } else if build_stage == Some("generate") {
    let output = output.type_()
    self._check_flow_block(builder, node_data)
    let is_cached = node_data.property_name is Some(_) ||
      node_data.snippet is Some(_)
    let flow_code_length = builder.flow.code.length()
    let allowed_cache = self.is_cacheable(builder) &&
      !builder.is_reference(output)
    let type_ = if allowed_cache {
      builder.get_vector_type(self.get_node_type(builder, output?))
    } else {
      None
    }
    let cache_result = allowed_cache &&
      type_ != Some("void") &&
      output != Some("void") &&
      node_data.usage_count.unwrap_or(0) > 1
    let generate_output = if cache_result { type_ } else { output }
    let mut snippet = ""
    if self.assignable &&
      self._declares_assignable() &&
      self._is_variable(builder, node_data) {
      snippet = self._build_variable(builder, node_data, output)
    } else if allowed_cache && node_data.property_name is Some(property_name) {
      snippet = builder.format(property_name, type_, output)
    } else {
      let is_generate_once = !self.class_.generate_uses_output()
      if is_generate_once {
        let node_type = self.get_node_type(builder)
        let mut r = node_data.snippet
        if r is None {
          if node_data.generated is None {
            node_data.generated = Some(true)
            let s = self.generate(builder, None).unwrap_or("")
            node_data.snippet = Some(s)
            r = Some(s)
          } else {
            @core.warn("Node: Recursion detected.")
            r = Some("/* Recursion detected. */")
          }
        }
        snippet = builder.format(r.unwrap(), node_type, generate_output)
      } else {
        snippet = self.generate(builder, generate_output).unwrap_or("")
      }
      if snippet == "" &&
        generate_output is Some(go) &&
        go != "void" &&
        go != "OutputType" {
        @core.error("TSL: Invalid generated code, expected a \"\{go}\".")
        snippet = builder.generate_const(go)
      }
      if cache_result {
        let property_name = self._declare_variable(
          builder,
          snippet,
          type_,
          node_data.assign != Some(true),
          "cacheVariable",
        )
        node_data.snippet = Some(snippet)
        node_data.property_name = Some(property_name)
        snippet = builder.format(property_name, type_, output)
      }
    }
    self._set_flow_block(builder, node_data, is_cached, flow_code_length)
    result = Snippet(snippet)
  }
  builder.remove_chain(self)
  result
}

///|
pub fn Node::get_serialize_children(self : Node) -> Array[NodeChild] {
  self.class_.get_serialize_children(self)
}

///|
pub fn Node::serialize(self : Node, json : @core.JsValue) -> Unit {
  self.class_.serialize(self, json)
}

///|
pub fn Node::serialize_base(self : Node, json : @core.JsValue) -> Unit {
  let node_children = self.get_serialize_children()
  let input_nodes = @core.JsValue::object()
  let mut count = 0
  for child in node_children {
    let uuid = child.child_node.to_json(meta=json.get("meta")).get("uuid")
    match child.index {
      Some(index) => {
        let holder = input_nodes.get(child.property)
        let holder = if holder.is_undefined() {
          let h = match index {
            Index(_) => js_new_array()
            Key(_) => @core.JsValue::object()
          }
          input_nodes.set(child.property, h)
          count += 1
          h
        } else {
          holder
        }
        match index {
          Index(i) => js_set_index(holder, i, uuid)
          Key(k) => holder.set(k, uuid)
        }
      }
      None => {
        if input_nodes.get(child.property).is_undefined() {
          count += 1
        }
        input_nodes.set(child.property, uuid)
      }
    }
  }
  if count > 0 {
    json.set("inputNodes", input_nodes)
  }
}

///|
pub fn Node::deserialize(self : Node, json : @core.JsValue) -> Unit {
  self.class_.deserialize(self, json)
}

///|
/// `Node.prototype.deserialize` assigns `this[ property ]` by name, which needs the
/// class to map property names to fields: classes with input nodes override
/// `deserialize` and read `json.inputNodes` themselves.
pub fn Node::deserialize_base(_self : Node, _json : @core.JsValue) -> Unit {

}

///|
/// `toJSON( meta )`; `meta` is the shared JS object of a parent serialization.
pub fn Node::to_json(self : Node, meta? : @core.JsValue) -> @core.JsValue {
  let uuid = self.uuid()
  let type_ = self.type_()
  let is_root = match meta {
    None => true
    Some(m) => m.is_undefined() || js_is_string(m)
  }
  let meta = if is_root {
    let m = @core.JsValue::object()
    m.set("textures", @core.JsValue::object())
    m.set("images", @core.JsValue::object())
    m.set("nodes", @core.JsValue::object())
    m
  } else {
    meta.unwrap()
  }
  let mut data = meta.get("nodes").get(uuid)
  if data.is_undefined() {
    data = @core.JsValue::object()
    data.set("uuid", @core.JsValue::of(uuid))
    data.set("type", @core.JsValue::of(type_))
    data.set("meta", meta)
    let metadata = @core.JsValue::object()
    metadata.set("version", @core.JsValue::of(4.7))
    metadata.set("type", @core.JsValue::of("Node"))
    metadata.set("generator", @core.JsValue::of("Node.toJSON"))
    data.set("metadata", metadata)
    if !is_root {
      meta.get("nodes").set(uuid, data)
    }
    self.serialize(data)
    js_delete(data, "meta")
  }
  if is_root {
    let textures = js_extract_from_cache(meta.get("textures"))
    let images = js_extract_from_cache(meta.get("images"))
    let nodes = js_extract_from_cache(meta.get("nodes"))
    if js_length(textures) > 0 {
      data.set("textures", textures)
    }
    if js_length(images) > 0 {
      data.set("images", images)
    }
    if js_length(nodes) > 0 {
      data.set("nodes", nodes)
    }
  }
  data
}

///|
extern "js" fn js_new_array() -> @core.JsValue = "() => []"

///|
extern "js" fn js_set_index(
  array : @core.JsValue,
  index : Int32,
  value : @core.JsValue,
) -> Unit = "(a, i, v) => { a[i] = v; }"

///|
extern "js" fn js_is_string(value : @core.JsValue) -> Bool = "(v) => typeof v === 'string'"

///|
extern "js" fn js_delete(object : @core.JsValue, key : String) -> Unit = "(o, k) => { delete o[k]; }"

///|
extern "js" fn js_length(array : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn js_extract_from_cache(cache : @core.JsValue) -> @core.JsValue =
  #|(cache) => {
  #|  const values = [];
  #|  for ( const key in cache ) {
  #|    const data = cache[ key ];
  #|    delete data.metadata;
  #|    values.push( data );
  #|  }
  #|  return values;
  #|}

///|
/// A JS `Set` of nodes by identity, as upstream's `ignores`.
pub(all) struct NodeSet {
  ids : Map[Int32, Node]
}

///|
pub fn NodeSet::new() -> NodeSet {
  { ids: Map::new(), }
}

///|
pub fn NodeSet::add(self : NodeSet, node : Node) -> Unit {
  self.ids.set(node.id, node)
}

///|
pub fn NodeSet::has(self : NodeSet, node : Node) -> Bool {
  self.ids.contains(node.id)
}

///|
pub fn NodeSet::delete(self : NodeSet, node : Node) -> Unit {
  self.ids.remove(node.id)
}

///|
/// Members in insertion order.
pub fn NodeSet::values(self : NodeSet) -> Array[Node] {
  self.ids.values().collect()
}

///|
pub fn NodeSet::size(self : NodeSet) -> Int32 {
  self.ids.length()
}

///|
pub fn NodeSet::clear(self : NodeSet) -> Unit {
  self.ids.clear()
}

// Helpers for `children` implementations.

///|
/// Appends `this[ property ]` if it is a node.
pub fn push_child(
  out : Array[NodeChild],
  property : String,
  node : Node?,
) -> Unit {
  if node is Some(child_node) {
    out.push({ property, index: None, child_node, })
  }
}

///|
/// Appends the nodes of the array `this[ property ]`.
pub fn push_children(
  out : Array[NodeChild],
  property : String,
  nodes : Array[Node?],
) -> Unit {
  for i, n in nodes {
    if n is Some(child_node) {
      out.push({ property, index: Some(Index(i)), child_node, })
    }
  }
}

///|
/// Appends the nodes of the plain object `this[ property ]`, skipping `_` keys.
pub fn push_child_object(
  out : Array[NodeChild],
  property : String,
  object : Map[String, Node],
) -> Unit {
  for key, child_node in object {
    if !key.has_prefix("_") {
      out.push({ property, index: Some(Key(key)), child_node, })
    }
  }
}
