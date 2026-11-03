// nodes/core/NodeBuilder.js: the base class of WGSLNodeBuilder and GLSLNodeBuilder.
//
// `NodeBuilder` holds upstream's instance fields. Backends plug in through
// `NodeBuilderClass` (`class_`): every method a backend overrides, plus the backend-only
// methods that node classes call (`generateTextureLoad`, `getBitcastMethod`, ...), is
// `NodeBuilder::m` -> `class_.m` -> `NodeBuilder::m_base` (upstream's base method) or,
// for backend-only methods, an abort as upstream's `TypeError`. Backend payloads hold
// their own fields (WGSLNodeBuilder.builtins, ...) and reach the base through the
// `NodeBuilder` argument.

///|
let _node_builder_id : Ref[Int32] = Ref(0)

///|
/// `_functionNodeCache`: backend -> shader node -> `FunctionNode`.
let _node_builder_function_node_cache : @webgl.WeakMap[
  Backend,
  @webgl.WeakMap[Node, Node],
] = @webgl.WeakMap::new()

///|
/// `_layoutDefaultsCache`: shader node -> provided-inputs key -> defaults (`None` is
/// `null`).
let _node_builder_layout_defaults_cache : @webgl.WeakMap[
  Node,
  Map[String, Array[Node?]?],
] = @webgl.WeakMap::new()

///|
/// `_componentTypeRanks`.
let _node_builder_component_type_ranks : Map[String, Int32] = {
  "bool": 0,
  "uint": 1,
  "int": 2,
  "float": 3,
}

///|
/// `_toFloat( value )`, upstream's body verbatim (it relies on JS `String( n )`).
extern "js" fn _node_builder_to_float(value : @core.JsValue) -> String =
  #|( value ) => {
  #|  if ( /e/g.test( value ) ) {
  #|    return String( value ).replace( /\+/g, '' );
  #|  } else {
  #|    value = Number( value );
  #|    return value + ( value % 1 ? '' : '.0' );
  #|  }
  #|}

///|
/// `${ Math.trunc( value ) }`.
extern "js" fn _node_builder_trunc_string(value : @core.JsValue) -> String = "(v) => `${ Math.trunc( v ) }`"

///|
/// The `uint` constant: `value >= 0 ? `${ Math.trunc( value ) }u` : '0u'`.
extern "js" fn _node_builder_uint_string(value : @core.JsValue) -> String = "(v) => v >= 0 ? `${ Math.trunc( v ) }u` : '0u'"

///|
extern "js" fn _node_builder_truthy(value : @core.JsValue) -> Bool = "(v) => v ? true : false"

///|
/// `Math.trunc( value )` of a JS value.
extern "js" fn _node_builder_trunc(value : @core.JsValue) -> Double = "(v) => Math.trunc( v )"

///|
/// `new RegExp( source ).test( value )`.
extern "js" fn _node_builder_regex_test(
  source : String,
  value : String,
) -> Bool = "(s, v) => new RegExp( s ).test( v )"

///|
/// `/vec([2-4])/.exec( type )`: the number, or -1.
extern "js" fn _node_builder_vec_num(type_ : String) -> Int32 = "(t) => { const m = /vec([2-4])/.exec( t ); return m !== null ? Number( m[ 1 ] ) : -1; }"

///|
/// The component type that `/(b|i|u|)(vec|mat)([2-4])/` gives; `''` for `null`.
extern "js" fn _node_builder_component_type_of(type_ : String) -> String =
  #|( type ) => {
  #|  const componentType = /(b|i|u|)(vec|mat)([2-4])/.exec( type );
  #|  if ( componentType === null ) return '';
  #|  else if ( componentType[ 1 ] === 'b' ) return 'bool';
  #|  else if ( componentType[ 1 ] === 'i' ) return 'int';
  #|  else if ( componentType[ 1 ] === 'u' ) return 'uint';
  #|  return 'float';
  #|}

///|
/// `string.replace( a, b )` (first occurrence).
extern "js" fn _node_builder_replace(
  s : String,
  a : String,
  b : String,
) -> String = "(s, a, b) => s.replace( a, b )"

///|
/// `code.trimEnd().endsWith( ';' )`.
extern "js" fn _node_builder_ends_with_semicolon(code : String) -> Bool = "(c) => c.trimEnd().endsWith( ';' )"

///|
/// `a + b + c` with JS `+` (for `getHash`, where the shaders may be `null`).
extern "js" fn _node_builder_js_concat3(
  a : @core.JsValue,
  b : @core.JsValue,
  c : @core.JsValue,
) -> String = "(a, b, c) => String( a + b + c )"

///|
/// `yieldToMain()`: resolves after `scheduler.yield()` or the next animation frame.
extern "js" fn _node_builder_yield_to_main(callback : () -> Unit) -> Unit =
  #|( callback ) => {
  #|  if ( typeof self !== 'undefined' && typeof self.scheduler !== 'undefined' && typeof self.scheduler.yield !== 'undefined' ) {
  #|    self.scheduler.yield().then( () => callback() );
  #|  } else {
  #|    new Promise( resolve => { requestAnimationFrame( resolve ); } ).then( () => callback() );
  #|  }
  #|}

///|
/// A type as JS string conversion prints it: `null` for no type.
fn _node_builder_str(type_ : String?) -> String {
  match type_ {
    Some(s) => s
    None => "null"
  }
}

///|
/// The JS value of a TSL value, for the JS conversions of `generateConst`.
fn _node_builder_js(value : TslValue) -> @core.JsValue {
  match value {
    Undefined => @core.JsValue::undefined()
    Null => @core.JsValue::null()
    Number(d) => @core.JsValue::of(d)
    Bool(b) => @core.JsValue::of(b)
    String(s) => @core.JsValue::of(s)
    v => @core.JsValue::of(v)
  }
}

///|
/// `value[ key ]` for the members `generateConst` reads (`x`, `r`, ...).
fn _node_builder_member(value : TslValue, key : String) -> TslValue {
  match (value, key) {
    (Vector2(v), "x") => Number(v.x)
    (Vector2(v), "y") => Number(v.y)
    (Vector3(v), "x") => Number(v.x)
    (Vector3(v), "y") => Number(v.y)
    (Vector3(v), "z") => Number(v.z)
    (Vector4(v), "x") => Number(v.x)
    (Vector4(v), "y") => Number(v.y)
    (Vector4(v), "z") => Number(v.z)
    (Vector4(v), "w") => Number(v.w)
    (Color(c), "r") => Number(c.r)
    (Color(c), "g") => Number(c.g)
    (Color(c), "b") => Number(c.b)
    (Object(m), k) =>
      match m.get(k) {
        Some(v) => v
        None => Undefined
      }
    _ => Undefined
  }
}

///|
/// `String( result )` of a build result.
fn _node_builder_result_string(result : BuildResult) -> String {
  match result {
    Snippet(s) => s
    Null => "null"
    NodeResult(_) => "[object Object]"
  }
}

///|
/// The child `this[ property ]` of a node, through `_getChildren` (upstream names).
fn _node_builder_child(node : Node, property : String) -> Node? {
  for child in node._get_children() {
    if child.property == property && child.index is None {
      return Some(child.child_node)
    }
  }
  None
}

///|
/// `a === b` for context values.
fn _node_builder_same_context_value(a : ContextValue, b : ContextValue) -> Bool {
  match (a, b) {
    (Undefined, Undefined) | (Null, Null) => true
    (Bool(x), Bool(y)) => x == y
    (Number(x), Number(y)) => x == y
    (String(x), String(y)) => x == y
    (Node(x), Node(y)) => physical_equal(x, y)
    (Material(x), Material(y)) => physical_equal(x, y)
    (Block(x), Block(y)) => physical_equal(x, y)
    (Overrides(x), Overrides(y)) => physical_equal(x, y)
    (Other(x), Other(y)) => x.strict_equal(y)
    _ => false
  }
}

///|
/// `_hasContextOverrides( context, baseContext )`.
fn _node_builder_has_context_overrides(
  context : NodeContext,
  base_context : NodeContext,
) -> Bool {
  for key, value in context.values {
    if key != "nodeBlock" &&
      key != "nodeLoop" &&
      !_node_builder_same_context_value(value, base_context.get(key)) {
      return true
    }
  }
  false
}

///|
/// `_checkWriteUsage( data )`.
fn _node_builder_check_write_usage(data : NodeData) -> Bool {
  if data.write_usage_count.unwrap_or(0) > 0 {
    return true
  }
  if data.sub_builds_cache is Some(cache) {
    for _, sub_data in cache {
      if _node_builder_check_write_usage(sub_data) {
        return true
      }
    }
  }
  false
}

///|
/// `_createLayoutInputs( layout, values )`: `inputs[ input.name ] = values[ i ]`, in
/// layout order (array destructuring reads the values in that order).
fn _node_builder_create_layout_inputs(
  layout : FnLayout,
  values : Array[TslValue],
) -> Map[String, TslValue] {
  let inputs : Map[String, TslValue] = Map::new()
  for i, input in layout.inputs {
    inputs.set(
      input.name,
      if i < values.length() {
        values[i]
      } else {
        Undefined
      },
    )
  }
  inputs
}

///|
/// `buildStages` of a node's data.
pub(all) struct BuildStages {
  mut setup : Bool
  mut analyze : Bool
  mut generate : Bool
}

///|
/// `builder.flowBlock`: the block of an `if`/`else` branch being generated.
pub(all) struct FlowBlock {
  parent : FlowBlock?
  /// The snippet of the branch condition (`'!' + cond` for an else branch).
  guard_ : String?
}

///|
/// The result of `createBlock()`, stored as `context.nodeBlock`.
pub(all) struct NodeBlock {
  parent : NodeBlock?
  context : NodeContext
  stack : StackNode?
  node : Node?
}

///|
/// `builder.flow` and the result of `flowNode`/`flowChildNode`/`flowStagesNode`:
/// `{ code, result, vars }`.
pub(all) struct FlowData {
  mut code : String
  mut result : BuildResult
  mut vars : String?
}

///|
pub fn FlowData::new() -> FlowData {
  { code: "", result: Null, vars: None, }
}

///|
/// `flow.result` as a snippet (`''` when not a string).
pub fn FlowData::result_snippet(self : FlowData) -> String {
  match self.result {
    Snippet(s) => s
    _ => ""
  }
}

///|
/// A var, varying, uniform, attribute or struct: what `getPropertyName`,
/// `registerDeclaration` and `getDeclarationName` receive.
pub(all) enum NodeVariable {
  Var(NodeVar)
  Varying(NodeVarying)
  Uniform(NodeUniform)
  Attribute(NodeAttribute)
  Struct(StructType)
  /// A `NodeCode`: `FunctionNode` registers its code under the function name.
  Code(NodeCode)
}

///|
pub fn NodeVariable::name(self : NodeVariable) -> String {
  match self {
    Var(v) => v.name
    Varying(v) => v.name
    Uniform(v) => v.name
    Attribute(v) => v.name
    Struct(v) => v.name
    Code(v) => v.name
  }
}

///|
pub fn NodeVariable::set_name(self : NodeVariable, name : String) -> Unit {
  match self {
    Var(v) => v.name = name
    Varying(v) => v.name = name
    Uniform(v) => v.name = name
    Attribute(v) => v.name = name
    Struct(v) => v.name = name
    Code(v) => v.name = name
  }
}

///|
/// `node.type` as a template literal prints it (`undefined` for structs).
pub fn NodeVariable::type_(self : NodeVariable) -> String {
  match self {
    Var(v) => v.type_
    Varying(v) => v.type_
    Uniform(v) => v.type_
    Attribute(v) => v.type_
    Struct(_) => "undefined"
    Code(v) => v.type_
  }
}

///|
/// The value of an `overrideNodes` entry: `( builder ) => node`, boxed for identity.
pub(all) struct OverrideCallback {
  f : (NodeBuilder) -> Node
}

///|
/// `context.overrideNodes`, a JS `Map< Node, callback >` in insertion order.
pub(all) struct OverrideNodes {
  entries : Array[(Node, OverrideCallback)]
}

///|
pub fn OverrideNodes::get(
  self : OverrideNodes,
  node : Node,
) -> OverrideCallback? {
  for entry in self.entries {
    if physical_equal(entry.0, node) {
      return Some(entry.1)
    }
  }
  None
}

///|
pub fn OverrideNodes::set(
  self : OverrideNodes,
  node : Node,
  callback : OverrideCallback,
) -> Unit {
  for i, entry in self.entries {
    if physical_equal(entry.0, node) {
      self.entries[i] = (node, callback)
      return
    }
  }
  self.entries.push((node, callback))
}

///|
/// A value of the builder context (`builder.context.foo`).
pub(all) enum ContextValue {
  Undefined
  Null
  Bool(Bool)
  Number(Double)
  String(String)
  Node(Node)
  Material(@core.Material)
  Block(NodeBlock)
  Overrides(OverrideNodes)
  /// Callbacks and objects whose shape the key's owner knows (`getUV`, `getShadow`);
  /// `JsValue::of` a MoonBit closure, read back with `ContextValue::cast`.
  Other(@core.JsValue)
}

///|
pub fn[T] ContextValue::cast(self : ContextValue) -> T? {
  match self {
    Other(v) => Some(v.cast())
    _ => None
  }
}

///|
/// `builder.context`: a JS object, so keys keep insertion order and a copy is made
/// before each change (`{ ...context }`).
pub(all) struct NodeContext {
  values : Map[String, ContextValue]
}

///|
pub fn NodeContext::new() -> NodeContext {
  { values: Map::new(), }
}

///|
/// `{ ...context }`.
pub fn NodeContext::copy(self : NodeContext) -> NodeContext {
  let values = Map::new()
  for k, v in self.values {
    values.set(k, v)
  }
  { values, }
}

///|
pub fn NodeContext::get(self : NodeContext, key : String) -> ContextValue {
  match self.values.get(key) {
    Some(v) => v
    None => Undefined
  }
}

///|
pub fn NodeContext::set(
  self : NodeContext,
  key : String,
  value : ContextValue,
) -> Unit {
  self.values.set(key, value)
}

///|
/// `delete context.key`.
pub fn NodeContext::delete(self : NodeContext, key : String) -> Unit {
  self.values.remove(key)
}

///|
/// `context.key` when it is a node.
pub fn NodeContext::get_node(self : NodeContext, key : String) -> Node? {
  match self.values.get(key) {
    Some(Node(n)) => Some(n)
    _ => None
  }
}

///|
/// `context.key` truthiness for booleans (`context.isolate === true`).
pub fn NodeContext::get_bool(self : NodeContext, key : String) -> Bool? {
  match self.values.get(key) {
    Some(Bool(b)) => Some(b)
    _ => None
  }
}

///|
pub fn NodeContext::get_override_nodes(self : NodeContext) -> OverrideNodes? {
  match self.values.get("overrideNodes") {
    Some(Overrides(o)) => Some(o)
    _ => None
  }
}

///|
/// `mergeContext( target, source )` from NodeUtils.
pub fn NodeContext::merge(
  target : NodeContext,
  source : NodeContext,
) -> NodeContext {
  let context = target.copy()
  for k, v in source.values {
    context.values.set(k, v)
  }
  match
    (target.values.get("overrideNodes"), source.values.get("overrideNodes")) {
    (Some(Overrides(a)), Some(Overrides(b))) if !physical_equal(a, b) => {
      let merged = OverrideNodes::{ entries: [], }
      for e in a.entries {
        merged.set(e.0, e.1)
      }
      for e in b.entries {
        merged.set(e.0, e.1)
      }
      context.values.set("overrideNodes", Overrides(merged))
    }
    _ => ()
  }
  context
}

///|
/// A value of `builder.getNodeProperties( node )`, a JS object whose keys keep
/// insertion order (it starts as `{ outputNode: null }`).
pub(all) enum NodePropertyValue {
  Null
  Node(Node)
  Bool(Bool)
  String(String)
  Nodes(Array[Node])
  /// Anything else a class stores there; the class knows the type.
  Other(@core.JsValue)
}

///|
pub(all) struct NodeProperties {
  values : Map[String, NodePropertyValue]
}

///|
pub fn NodeProperties::new() -> NodeProperties {
  let values = Map::new()
  values.set("outputNode", NodePropertyValue::Null)
  { values, }
}

///|
pub fn NodeProperties::get(
  self : NodeProperties,
  key : String,
) -> NodePropertyValue? {
  self.values.get(key)
}

///|
pub fn NodeProperties::set(
  self : NodeProperties,
  key : String,
  value : NodePropertyValue,
) -> Unit {
  self.values.set(key, value)
}

///|
pub fn NodeProperties::get_node(self : NodeProperties, key : String) -> Node? {
  match self.values.get(key) {
    Some(Node(n)) => Some(n)
    _ => None
  }
}

///|
pub fn NodeProperties::set_node(
  self : NodeProperties,
  key : String,
  node : Node,
) -> Unit {
  self.values.set(key, Node(node))
}

///|
/// `properties[ key ] = node || null`.
pub fn NodeProperties::set_node_or_null(
  self : NodeProperties,
  key : String,
  node : Node?,
) -> Unit {
  match node {
    Some(n) => self.values.set(key, Node(n))
    None => self.values.set(key, NodePropertyValue::Null)
  }
}

///|
pub fn NodeProperties::get_bool(self : NodeProperties, key : String) -> Bool? {
  match self.values.get(key) {
    Some(Bool(b)) => Some(b)
    _ => None
  }
}

///|
pub fn NodeProperties::set_bool(
  self : NodeProperties,
  key : String,
  value : Bool,
) -> Unit {
  self.values.set(key, Bool(value))
}

///|
/// `Object.values( properties )` filtered to nodes (`childNode.isNode === true`).
pub fn NodeProperties::node_values(self : NodeProperties) -> Array[Node] {
  let out = []
  for _, v in self.values {
    if v is Node(n) {
      out.push(n)
    }
  }
  out
}

///|
/// `properties.parents = properties.parents || []; properties.parents.push( node )`.
pub fn NodeProperties::push_parent(self : NodeProperties, node : Node) -> Unit {
  match self.values.get("parents") {
    Some(Nodes(list)) => list.push(node)
    _ => self.values.set("parents", Nodes([node]))
  }
}

///|
/// The data of a node in a shader stage (upstream's `NodeData` class, plus the keys
/// nodes add). `None` is `undefined`. Add a key here when a class needs one.
pub(all) struct NodeData {
  mut properties : NodeProperties?
  /// `type`; `Some(None)` is a cached `null` type.
  mut type_ : String??
  mut type_from_output : Map[String, String?]?
  mut build_stages : BuildStages?
  mut usage_count : Int32?
  mut read_usage_count : Int32?
  mut write_usage_count : Int32?
  mut stack : StackNode?
  /// `stages[ shaderStage ]`: the parents a `parents` node was built for.
  mut stages : Map[String, Array[Node?]]?
  mut snippet : String?
  mut property_name : String?
  mut generated : Bool?
  mut flow_block : FlowBlock?
  mut assign : Bool?
  mut force_declaration : Bool?
  /// `nodeData[ property ]` of `getVarFromNode`: `variable`, `cacheVariable` and their
  /// sub-build variants.
  vars : Map[String, NodeVar]
  mut uniform : NodeUniform?
  mut sub_builds : Array[String]?
  mut sub_builds_cache : Map[String, NodeData]?
  /// `nodeData.overrides`: override callback -> overriding node (`null` while running).
  mut overrides : Array[(OverrideCallback, Ref[Node?])]?
  mut varying : NodeVarying?
  /// `nodeData[ subBuild + '_varying' ]` of `getVaryingFromNode` in a sub-build.
  sub_build_varyings : Map[String, NodeVarying]
  mut code : NodeCode?
  mut struct_type : StructType?
  mut buffer_attribute : NodeAttribute?
  /// `getCacheFromNode`.
  mut cache : NodeCache?
  /// `FunctionNode.getNodeFunction`.
  mut node_function : NodeFunction?
  /// `FunctionNode.generate`.
  mut function_property_name : String?
  /// Keys owned by one class, typed by that class.
  extra : Map[String, @core.JsValue]
}

///|
pub fn NodeData::new() -> NodeData {
  {
    properties: None,
    type_: None,
    type_from_output: None,
    build_stages: None,
    usage_count: None,
    read_usage_count: None,
    write_usage_count: None,
    stack: None,
    stages: None,
    snippet: None,
    property_name: None,
    generated: None,
    flow_block: None,
    assign: None,
    force_declaration: None,
    vars: Map::new(),
    uniform: None,
    sub_builds: None,
    sub_builds_cache: None,
    overrides: None,
    varying: None,
    sub_build_varyings: Map::new(),
    code: None,
    struct_type: None,
    buffer_attribute: None,
    cache: None,
    node_function: None,
    function_property_name: None,
    extra: Map::new(),
  }
}

///|
/// What `NodeBuilder.object` refers to: the rendered object, or a compute node.
pub(all) enum BuilderObject {
  NoObject
  Object3D(@core.Object3D)
  Compute(Node)
}

///|
/// `{ vertex: [], fragment: [], compute: [], index: 0 }`.
pub(all) struct StageArrays[T] {
  vertex : Array[T]
  fragment : Array[T]
  compute : Array[T]
  mut index : Int32
}

///|
pub fn[T] StageArrays::new() -> StageArrays[T] {
  { vertex: [], fragment: [], compute: [], index: 0, }
}

///|
/// `this.uniforms[ shaderStage ]`.
pub fn[T] StageArrays::stage(self : StageArrays[T], stage : String) -> Array[T] {
  match stage {
    "vertex" => self.vertex
    "fragment" => self.fragment
    "compute" => self.compute
    _ => abort("StageArrays::stage: no stage \{stage}")
  }
}

///|
/// The overridable methods of `NodeBuilder` (WGSL and GLSL builders implement it).
pub(open) trait NodeBuilderClass {
  fn class_name(Self) -> String
  fn payload(Self) -> @core.JsValue = _
  /// `isWGSLNodeBuilder`-style flags.
  fn has_flag(Self, String) -> Bool = _
  fn _get_bind_group(Self, NodeBuilder, String, Array[Binding]) -> BindGroup = _
  fn build_code(Self, NodeBuilder) -> Unit = _
  /// `prebuild()` (context and material setup before the build stages); added by G6
  /// so test builders can short-circuit the material build, as a JS subclass can.
  fn prebuild(Self, NodeBuilder) -> Unit = _
  fn build_function_code(Self, NodeBuilder, Node) -> String = _
  fn enable_dual_source_blending(Self, NodeBuilder) -> Unit = _
  fn enable_shader_f16(Self, NodeBuilder) -> Unit = _
  fn enable_sub_groups(Self, NodeBuilder) -> Unit = _
  fn generate_array_declaration(Self, NodeBuilder, String, Int32?) -> String = _
  fn generate_const_statement(Self, NodeBuilder, String, String, Int32?) -> String = _
  fn generate_let_statement(Self, NodeBuilder, String, String, Int32?) -> String = _
  fn generate_var_statement(Self, NodeBuilder, String, String, Int32?) -> String = _
  /// `generateTexture( texture, textureProperty, uvSnippet, depthSnippet, offsetSnippet,
  /// shaderStage )`.
  fn generate_texture(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String?,
    String?,
    String?,
  ) -> String = _
  /// `generateTextureLod( texture, textureProperty, uvSnippet, depthSnippet,
  /// offsetSnippet, levelSnippet )`.
  fn generate_texture_lod(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String?,
    String?,
    String,
  ) -> String = _
  fn generate_texture_size(Self, NodeBuilder, @core.Texture, String, String) -> String = _
  fn get_attributes(Self, NodeBuilder, String) -> String = _
  fn get_declaration_name(Self, NodeBuilder, NodeVariable) -> String = _
  fn get_draw_index(Self, NodeBuilder) -> String? = _
  fn get_frag_coord(Self, NodeBuilder) -> String = _
  fn get_front_facing(Self, NodeBuilder) -> String = _
  fn get_function_operator(Self, NodeBuilder, String) -> String? = _
  fn get_instance_index(Self, NodeBuilder) -> String = _
  fn get_invocation_subgroup_index(Self, NodeBuilder) -> String = _
  /// `getMethod( method, output )`.
  fn get_method(Self, NodeBuilder, String, String?) -> String = _
  fn get_output_struct_name(Self, NodeBuilder) -> String = _
  fn get_property_name(Self, NodeBuilder, NodeVariable, String?) -> String = _
  fn get_subgroup_index(Self, NodeBuilder) -> String = _
  fn get_subgroup_size(Self, NodeBuilder) -> String = _
  fn get_ternary(Self, NodeBuilder, String, String, String) -> String? = _
  fn get_type(Self, NodeBuilder, String) -> String = _
  fn get_type_from_attribute(Self, NodeBuilder, @core.GeometryAttribute) -> String = _
  fn get_uniform_from_node(Self, NodeBuilder, Node, String, String?, String?) -> NodeUniform = _
  fn get_uniforms(Self, NodeBuilder, String) -> String = _
  /// `getVar( type, name, count, qualifier )`.
  fn get_var(Self, NodeBuilder, String, String, Int32?, String) -> String = _
  fn get_vars(Self, NodeBuilder, String, Bool) -> String = _
  fn get_varyings(Self, NodeBuilder, String) -> String = _
  fn get_vector_select(Self, NodeBuilder, String, String, String, String?) -> String? = _
  fn get_vertex_index(Self, NodeBuilder) -> String = _
  fn is_available(Self, NodeBuilder, String) -> Bool = _
  fn is_flip_y(Self, NodeBuilder) -> Bool = _
  fn is_reserved_keyword(Self, NodeBuilder, String) -> Bool = _
  fn needs_to_working_color_space(Self, NodeBuilder, @core.Texture) -> Bool = _
  // Backend-only methods that node classes call.
  fn enable_hardware_clipping(Self, NodeBuilder, Int32) -> Unit = _
  fn generate_pbo(Self, NodeBuilder, Node) -> String = _
  fn setup_pbo(Self, NodeBuilder, Node) -> Unit = _
  /// `( texture, textureProperty, uvIndexSnippet, levelSnippet, depthSnippet,
  /// offsetSnippet )`.
  fn generate_texture_load(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String?,
    String?,
    String?,
  ) -> String = _
  fn generate_storage_texture_load(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String?,
    String?,
    String?,
  ) -> String = _
  /// `( texture, textureProperty, uvSnippet, levelSnippet, depthSnippet, offsetSnippet )`.
  fn generate_texture_level(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String,
    String?,
    String?,
  ) -> String = _
  /// `( texture, textureProperty, uvSnippet, biasSnippet, depthSnippet, offsetSnippet,
  /// shaderStage )`.
  fn generate_texture_bias(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String,
    String?,
    String?,
    String?,
  ) -> String = _
  /// `( texture, textureProperty, uvSnippet, gradSnippet( [ dx, dy ] ), depthSnippet,
  /// offsetSnippet, shaderStage )`.
  fn generate_texture_grad(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    Array[String],
    String?,
    String?,
    String?,
  ) -> String = _
  fn generate_texture_compare(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String,
    String?,
    String?,
    String?,
  ) -> String = _
  /// `( texture, textureProperty, uvSnippet, gatherSnippet, depthSnippet, offsetSnippet,
  /// flipYSnippet )`.
  fn generate_texture_gather(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String?,
    String?,
    String?,
    String?,
  ) -> String = _
  fn generate_texture_gather_compare(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String,
    String?,
    String?,
    String?,
  ) -> String = _
  /// `( texture, textureProperty, uvIndexSnippet, depthSnippet, valueSnippet )`.
  fn generate_texture_store(
    Self,
    NodeBuilder,
    @core.Texture,
    String,
    String,
    String?,
    String,
  ) -> String = _
  fn get_bitcast_method(Self, NodeBuilder, String, String?) -> String = _
  fn get_float_packing_method(Self, NodeBuilder, String, String) -> String = _
  fn get_float_unpacking_method(Self, NodeBuilder, String, String) -> String = _
  fn get_clip_distance(Self, NodeBuilder) -> String = _
  fn get_frag_depth(Self, NodeBuilder) -> String = _
  fn get_invocation_local_index(Self, NodeBuilder) -> String = _
  /// `getScopedArray( name, scope, bufferType, bufferCount, isAtomic )`.
  fn get_scoped_array(Self, NodeBuilder, String, String, String, Int32, Bool) -> String = _
  fn has_builtin(Self, NodeBuilder, String, String?) -> Bool = _
  fn register_transform(Self, NodeBuilder, String, Node) -> Unit = _
  /// `enableMultiview()` (GLSL builder only; declared by G7 for NodeManager).
  fn enable_multiview(Self, NodeBuilder) -> Unit = _
  /// `nodeBuilder.transforms` (GLSL builder only; `None` is `undefined`; declared by G7
  /// for NodeManager).
  fn transforms(Self, NodeBuilder) -> Array[NodeTransform]? = _
  /// `addNode( node )` (overridden by the WebGLNodesHandler add-on's WebGLNodeBuilder;
  /// the default is `NodeBuilder::add_node_base`).
  fn add_node(Self, NodeBuilder, Node) -> Unit = _
}

///|
impl NodeBuilderClass with fn enable_multiview(_, _) {
  abort("TypeError: nodeBuilder.enableMultiview is not a function")
}

///|
impl NodeBuilderClass with fn transforms(_, _) {
  None
}

///|
impl NodeBuilderClass with fn add_node(_, b, node) {
  b.add_node_base(node)
}

///|
/// `enableMultiview()`.
pub fn NodeBuilder::enable_multiview(self : NodeBuilder) -> Unit {
  self.class_.enable_multiview(self)
}

///|
/// `nodeBuilder.transforms`; `[]` when the builder has none (`NodeBuilderState`'s
/// default).
pub fn NodeBuilder::transforms(self : NodeBuilder) -> Array[NodeTransform] {
  match self.class_.transforms(self) {
    Some(t) => t
    None => []
  }
}

///|
fn not_a_function(name : String) -> Unit {
  abort("TypeError: builder.\{name} is not a function")
}

///|
impl NodeBuilderClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl NodeBuilderClass with fn has_flag(_, _) {
  false
}

///|
impl NodeBuilderClass with fn _get_bind_group(_, b, group_name, bindings) {
  b._get_bind_group_base(group_name, bindings)
}

///|
impl NodeBuilderClass with fn build_code(_, _) {
  @core.warn("Abstract function.")
}

///|
impl NodeBuilderClass with fn prebuild(_, builder) {
  builder.prebuild_base()
}

///|
impl NodeBuilderClass with fn build_function_code(_, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn enable_dual_source_blending(_, _) {
  @core.warn("Abstract function.")
}

///|
impl NodeBuilderClass with fn enable_shader_f16(_, _) {
  @core.warn("Abstract function.")
}

///|
impl NodeBuilderClass with fn enable_sub_groups(_, _) {
  @core.warn("Abstract function.")
}

///|
impl NodeBuilderClass with fn generate_array_declaration(_, b, type_, count) {
  b.generate_array_declaration_base(type_, count)
}

///|
impl NodeBuilderClass with fn generate_const_statement(_, b, type_, name, count) {
  b.generate_const_statement_base(type_, name, count)
}

///|
impl NodeBuilderClass with fn generate_let_statement(_, b, type_, name, count) {
  b.generate_let_statement_base(type_, name, count)
}

///|
impl NodeBuilderClass with fn generate_var_statement(_, b, type_, name, count) {
  b.generate_var_statement_base(type_, name, count)
}

///|
impl NodeBuilderClass with fn generate_texture(_, _, _, _, _, _, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_lod(_, _, _, _, _, _, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_size(_, _, _, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_attributes(_, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_declaration_name(_, b, node) {
  b.get_declaration_name_base(node)
}

///|
impl NodeBuilderClass with fn get_draw_index(_, _) {
  @core.warn("Abstract function.")
  None
}

///|
impl NodeBuilderClass with fn get_frag_coord(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_front_facing(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_function_operator(_, _, _) {
  None
}

///|
impl NodeBuilderClass with fn get_instance_index(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_invocation_subgroup_index(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_method(_, _, method_, _) {
  method_
}

///|
impl NodeBuilderClass with fn get_output_struct_name(_, _) {
  ""
}

///|
impl NodeBuilderClass with fn get_property_name(_, _, node, _) {
  node.name()
}

///|
impl NodeBuilderClass with fn get_subgroup_index(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_subgroup_size(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_ternary(_, _, _, _, _) {
  None
}

///|
impl NodeBuilderClass with fn get_type(_, b, type_) {
  b.get_type_base(type_)
}

///|
impl NodeBuilderClass with fn get_type_from_attribute(_, b, attribute) {
  b.get_type_from_attribute_base(attribute)
}

///|
impl NodeBuilderClass with fn get_uniform_from_node(
  _,
  b,
  node,
  type_,
  shader_stage,
  name,
) {
  b.get_uniform_from_node_base(node, type_, shader_stage, name)
}

///|
impl NodeBuilderClass with fn get_uniforms(_, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_var(_, b, type_, name, count, _) {
  b.get_var_base(type_, name, count)
}

///|
impl NodeBuilderClass with fn get_vars(_, b, shader_stage, global) {
  b.get_vars_base(shader_stage, global)
}

///|
impl NodeBuilderClass with fn get_varyings(_, _, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn get_vector_select(_, b, cond, if_, else_, _) {
  b.get_ternary(cond, if_, else_)
}

///|
impl NodeBuilderClass with fn get_vertex_index(_, _) {
  @core.warn("Abstract function.")
  ""
}

///|
impl NodeBuilderClass with fn is_available(_, _, _) {
  false
}

///|
impl NodeBuilderClass with fn is_flip_y(_, _) {
  false
}

///|
impl NodeBuilderClass with fn is_reserved_keyword(_, _, _) {
  false
}

///|
impl NodeBuilderClass with fn needs_to_working_color_space(_, _, _) {
  false
}

///|
impl NodeBuilderClass with fn enable_hardware_clipping(_, _, _) {
  not_a_function("enableHardwareClipping")
}

///|
impl NodeBuilderClass with fn generate_pbo(_, _, _) {
  not_a_function("generatePBO")
  ""
}

///|
impl NodeBuilderClass with fn setup_pbo(_, _, _) {
  not_a_function("setupPBO")
}

///|
impl NodeBuilderClass with fn generate_texture_load(_, _, _, _, _, _, _, _) {
  not_a_function("generateTextureLoad")
  ""
}

///|
impl NodeBuilderClass with fn generate_storage_texture_load(
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
) {
  not_a_function("generateStorageTextureLoad")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_level(_, _, _, _, _, _, _, _) {
  not_a_function("generateTextureLevel")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_bias(_, _, _, _, _, _, _, _, _) {
  not_a_function("generateTextureBias")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_grad(_, _, _, _, _, _, _, _, _) {
  not_a_function("generateTextureGrad")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_compare(
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
) {
  not_a_function("generateTextureCompare")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_gather(_, _, _, _, _, _, _, _, _) {
  not_a_function("generateTextureGather")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_gather_compare(
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
  _,
) {
  not_a_function("generateTextureGatherCompare")
  ""
}

///|
impl NodeBuilderClass with fn generate_texture_store(_, _, _, _, _, _, _) {
  not_a_function("generateTextureStore")
  ""
}

///|
impl NodeBuilderClass with fn get_bitcast_method(_, _, _, _) {
  not_a_function("getBitcastMethod")
  ""
}

///|
impl NodeBuilderClass with fn get_float_packing_method(_, _, _, _) {
  not_a_function("getFloatPackingMethod")
  ""
}

///|
impl NodeBuilderClass with fn get_float_unpacking_method(_, _, _, _) {
  not_a_function("getFloatUnpackingMethod")
  ""
}

///|
impl NodeBuilderClass with fn get_clip_distance(_, _) {
  not_a_function("getClipDistance")
  ""
}

///|
impl NodeBuilderClass with fn get_frag_depth(_, _) {
  not_a_function("getFragDepth")
  ""
}

///|
impl NodeBuilderClass with fn get_invocation_local_index(_, _) {
  not_a_function("getInvocationLocalIndex")
  ""
}

///|
impl NodeBuilderClass with fn get_scoped_array(_, _, _, _, _, _, _) {
  not_a_function("getScopedArray")
  ""
}

///|
impl NodeBuilderClass with fn has_builtin(_, _, _, _) {
  not_a_function("hasBuiltin")
  false
}

///|
impl NodeBuilderClass with fn register_transform(_, _, _, _) {
  not_a_function("registerTransform")
}

///|
/// The class of a plain `new NodeBuilder( object, renderer, parser )`.
pub(all) struct BaseNodeBuilder {}

///|
pub impl NodeBuilderClass for BaseNodeBuilder with fn class_name(_) {
  "NodeBuilder"
}

///|
/// Upstream's `NodeBuilder` instance fields.
pub(all) struct NodeBuilder {
  id : Int32
  mut class_ : &NodeBuilderClass
  mut object : BuilderObject
  mut material : @core.Material?
  mut geometry : @core.BufferGeometry?
  mut compute : Node?
  mut renderer : Renderer
  mut parser : NodeParser?
  mut scene : @core.Object3D?
  mut camera : @core.Object3D?
  nodes : NodeSet
  sequential_nodes : NodeSet
  update_nodes : Array[Node]
  update_before_nodes : Array[Node]
  update_after_nodes : Array[Node]
  /// `hashNodes`, keyed by `getHash()`.
  hash_nodes : Map[String, Node]
  mut observer : NodeMaterialObserver?
  mut lights_node : Node?
  mut environment_node : Node?
  mut fog_node : Node?
  mut clipping_context : ClippingContext?
  mut hardware_clipping : Bool
  mut object_specific : Bool
  mut vertex_shader : String?
  mut fragment_shader : String?
  mut compute_shader : String?
  /// `flowNodes[ shaderStage ]`.
  flow_nodes : Map[String, Array[Node]]
  /// `flowCode[ shaderStage ]`.
  flow_code : Map[String, String]
  uniforms : StageArrays[NodeUniform]
  structs : StageArrays[StructType]
  /// `types[ shaderStage ][ name ]`: the struct type node of a struct name.
  types : Map[String, Map[String, Node]]
  /// `bindings[ shaderStage ][ groupName ]`.
  bindings : Map[String, Map[String, Array[Binding]]]
  /// `bindingsIndexes[ groupName ]` = `{ binding, group }`.
  bindings_indexes : Map[String, (Int32, Int32)]
  mut bind_groups : Array[BindGroup]?
  attributes : Array[NodeAttribute]
  buffer_attributes : Array[NodeAttribute]
  varyings : Array[NodeVarying]
  /// `codes[ shaderStage ]`.
  codes : Map[String, Array[NodeCode]]
  /// `vars[ shaderStage ]`; replaced by `flowStagesNode`.
  mut vars : Map[String, Array[NodeVar]]
  /// `vars._var` and `vars._const`, the counters `getVarFromNode` keeps in `vars`.
  mut var_ids : Map[String, Int32]
  /// `declarations[ shaderStage ][ declarationName ]`.
  mut declarations : Map[String, Map[String, NodeVariable]]
  mut flow : FlowData
  chaining : Array[Node]
  mut stack : StackNode
  /// The current TSL stacks saved by `addStack` (`null` when there was none).
  stacks : Array[StackNode?]
  mut tab : String
  mut current_function_node : Node?
  mut context : NodeContext
  mut cache : NodeCache
  mut global_cache : NodeCache
  /// `flowsData`, a `WeakMap< Node, flow >`.
  flows_data : Map[Int32, FlowData]
  mut shader_stage : String?
  mut build_stage : String?
  /// The names of the active sub-builds (`SubBuildNode.name`).
  sub_build_layers : Array[String]
  active_stacks : Array[StackNode]
  mut sub_build_fn : String?
  mut fn_call : Node?
  mut flow_block : FlowBlock?
  /// `allowEarlyReturns` / `allowGlobalVariables` of WGSLNodeBuilder (which sets both
  /// to true); BarrierNode clears them, ComputeNode reads the first. `undefined` here.
  mut allow_early_returns : Bool
  mut allow_global_variables : Bool
}

///|
/// `new NodeBuilder( object, renderer, parser )`; backends pass their class payload.
pub fn NodeBuilder::new(
  object : BuilderObject,
  renderer : Renderer,
  parser : NodeParser?,
  class_? : &NodeBuilderClass,
) -> NodeBuilder {
  let class_ : &NodeBuilderClass = match class_ {
    Some(c) => c
    None => BaseNodeBuilder::{ }
  }
  // `( object && object.material ) || null`; an array of materials is left to the
  // caller, which assigns `builder.material`.
  let (material, geometry) = match object {
    Object3D(o) => {
      let material = match o.get_material() {
        Some(Single(m)) => Some(m)
        _ => None
      }
      (material, o.get_geometry())
    }
    _ => (None, None)
  }
  let flow_nodes : Map[String, Array[Node]] = Map::new()
  let flow_code : Map[String, String] = Map::new()
  let types : Map[String, Map[String, Node]] = Map::new()
  let bindings : Map[String, Map[String, Array[Binding]]] = Map::new()
  for stage in ["vertex", "fragment", "compute"] {
    flow_nodes.set(stage, [])
    flow_code.set(stage, "")
    types.set(stage, Map::new())
    bindings.set(stage, Map::new())
  }
  let stack = StackNode::create()
  let context = NodeContext::new()
  context.set(
    "material",
    match material {
      Some(m) => Material(m)
      None => Null
    },
  )
  let cache = NodeCache::new()
  let id = _node_builder_id.val
  _node_builder_id.val += 1
  {
    id,
    class_,
    object,
    material,
    geometry,
    compute: None,
    renderer,
    parser,
    scene: None,
    camera: None,
    nodes: NodeSet::new(),
    sequential_nodes: NodeSet::new(),
    update_nodes: [],
    update_before_nodes: [],
    update_after_nodes: [],
    hash_nodes: Map::new(),
    observer: None,
    lights_node: None,
    environment_node: None,
    fog_node: None,
    clipping_context: None,
    hardware_clipping: false,
    object_specific: false,
    vertex_shader: None,
    fragment_shader: None,
    compute_shader: None,
    flow_nodes,
    flow_code,
    uniforms: StageArrays::new(),
    structs: StageArrays::new(),
    types,
    bindings,
    bindings_indexes: Map::new(),
    bind_groups: None,
    attributes: [],
    buffer_attributes: [],
    varyings: [],
    codes: Map::new(),
    vars: Map::new(),
    var_ids: Map::new(),
    declarations: Map::new(),
    flow: FlowData::new(),
    chaining: [],
    stack,
    stacks: [],
    tab: "\t",
    current_function_node: None,
    context,
    cache,
    global_cache: cache,
    flows_data: Map::new(),
    shader_stage: None,
    build_stage: None,
    sub_build_layers: [],
    active_stacks: [],
    sub_build_fn: None,
    fn_call: None,
    flow_block: None,
    allow_early_returns: false,
    allow_global_variables: false,
  }
}

// ---------------------------------------------------------------------------
// Virtual methods: `m` dispatches through `class_`, `m_base` is upstream's body.

///|
pub fn NodeBuilder::_get_bind_group(
  self : NodeBuilder,
  group_name : String,
  bindings : Array[Binding],
) -> BindGroup {
  self.class_._get_bind_group(self, group_name, bindings)
}

///|
pub fn NodeBuilder::_get_bind_group_base(
  self : NodeBuilder,
  group_name : String,
  bindings : Array[Binding],
) -> BindGroup {
  let group_node = match bindings[0].group_node() {
    Some(g) => g
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'shared')")
  }
  let mut shared_group = match UniformGroupNode::of(group_node) {
    Some(u) => u.shared
    None => false
  }
  if shared_group {
    for i in 1..<bindings.length() {
      if !(bindings[i].group_node() is Some(g) && physical_equal(g, group_node)) {
        shared_group = false
      }
    }
  }
  let mut bind_group = BindGroup::new(name=group_name, bindings~)
  if shared_group && self.renderer._bindings is Some(renderer_bindings) {
    bind_group = renderer_bindings.get_shared_bind_group(bind_group)
  }
  bind_group
}

///|
pub fn NodeBuilder::build_code(self : NodeBuilder) -> Unit {
  self.class_.build_code(self)
}

///|
pub fn NodeBuilder::build_function_code(
  self : NodeBuilder,
  shader_node : Node,
) -> String {
  self.class_.build_function_code(self, shader_node)
}

///|
pub fn NodeBuilder::enable_dual_source_blending(self : NodeBuilder) -> Unit {
  self.class_.enable_dual_source_blending(self)
}

///|
pub fn NodeBuilder::enable_shader_f16(self : NodeBuilder) -> Unit {
  self.class_.enable_shader_f16(self)
}

///|
pub fn NodeBuilder::enable_sub_groups(self : NodeBuilder) -> Unit {
  self.class_.enable_sub_groups(self)
}

///|
pub fn NodeBuilder::generate_array_declaration(
  self : NodeBuilder,
  type_ : String,
  count : Int32?,
) -> String {
  self.class_.generate_array_declaration(self, type_, count)
}

///|
pub fn NodeBuilder::generate_array_declaration_base(
  self : NodeBuilder,
  type_ : String,
  count : Int32?,
) -> String {
  let count = match count {
    Some(c) => c.to_string()
    None => "null"
  }
  self.get_type(type_) + "[ " + count + " ]"
}

///|
pub fn NodeBuilder::generate_const_statement(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count? : Int32,
) -> String {
  self.class_.generate_const_statement(self, type_, name, count)
}

///|
pub fn NodeBuilder::generate_const_statement_base(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count : Int32?,
) -> String {
  let variable = self.get_var(type_, name, count?)
  "const \{variable}"
}

///|
pub fn NodeBuilder::generate_let_statement(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count : Int32?,
) -> String {
  self.class_.generate_let_statement(self, type_, name, count)
}

///|
pub fn NodeBuilder::generate_let_statement_base(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count : Int32?,
) -> String {
  self.generate_var_statement(type_, name, count)
}

///|
pub fn NodeBuilder::generate_var_statement(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count : Int32?,
) -> String {
  self.class_.generate_var_statement(self, type_, name, count)
}

///|
pub fn NodeBuilder::generate_var_statement_base(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count : Int32?,
) -> String {
  self.get_var(type_, name, count?)
}

///|
pub fn NodeBuilder::generate_texture(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  depth_snippet? : String,
  offset_snippet? : String,
  shader_stage? : String,
) -> String {
  self.class_.generate_texture(
    self, texture, texture_property, uv_snippet, depth_snippet, offset_snippet, shader_stage,
  )
}

///|
pub fn NodeBuilder::generate_texture_lod(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  depth_snippet : String?,
  offset_snippet : String?,
  level_snippet~ : String = "0u",
) -> String {
  self.class_.generate_texture_lod(
    self, texture, texture_property, uv_snippet, depth_snippet, offset_snippet, level_snippet,
  )
}

///|
pub fn NodeBuilder::generate_texture_size(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  level_snippet : String,
) -> String {
  self.class_.generate_texture_size(
    self, texture, texture_property, level_snippet,
  )
}

///|
pub fn NodeBuilder::get_attributes(
  self : NodeBuilder,
  shader_stage : String,
) -> String {
  self.class_.get_attributes(self, shader_stage)
}

///|
pub fn NodeBuilder::get_declaration_name(
  self : NodeBuilder,
  node : NodeVariable,
) -> String {
  self.class_.get_declaration_name(self, node)
}

///|
pub fn NodeBuilder::get_declaration_name_base(
  self : NodeBuilder,
  node : NodeVariable,
) -> String {
  self.get_property_name(node)
}

///|
pub fn NodeBuilder::get_draw_index(self : NodeBuilder) -> String? {
  self.class_.get_draw_index(self)
}

///|
pub fn NodeBuilder::get_frag_coord(self : NodeBuilder) -> String {
  self.class_.get_frag_coord(self)
}

///|
pub fn NodeBuilder::get_front_facing(self : NodeBuilder) -> String {
  self.class_.get_front_facing(self)
}

///|
pub fn NodeBuilder::get_function_operator(
  self : NodeBuilder,
  op : String,
) -> String? {
  self.class_.get_function_operator(self, op)
}

///|
pub fn NodeBuilder::get_instance_index(self : NodeBuilder) -> String {
  self.class_.get_instance_index(self)
}

///|
pub fn NodeBuilder::get_invocation_subgroup_index(self : NodeBuilder) -> String {
  self.class_.get_invocation_subgroup_index(self)
}

///|
pub fn NodeBuilder::get_method(
  self : NodeBuilder,
  method_ : String,
  output? : String,
) -> String {
  self.class_.get_method(self, method_, output)
}

///|
pub fn NodeBuilder::get_output_struct_name(self : NodeBuilder) -> String {
  self.class_.get_output_struct_name(self)
}

///|
pub fn NodeBuilder::get_property_name(
  self : NodeBuilder,
  node : NodeVariable,
  shader_stage? : String,
) -> String {
  let shader_stage = match shader_stage {
    Some(s) => Some(s)
    None => self.shader_stage
  }
  self.class_.get_property_name(self, node, shader_stage)
}

///|
pub fn NodeBuilder::get_subgroup_index(self : NodeBuilder) -> String {
  self.class_.get_subgroup_index(self)
}

///|
pub fn NodeBuilder::get_subgroup_size(self : NodeBuilder) -> String {
  self.class_.get_subgroup_size(self)
}

///|
/// `getTernary( condSnippet, ifSnippet, elseSnippet )`; `None` is upstream's `null`.
pub fn NodeBuilder::get_ternary(
  self : NodeBuilder,
  cond_snippet : String,
  if_snippet : String,
  else_snippet : String,
) -> String? {
  self.class_.get_ternary(self, cond_snippet, if_snippet, else_snippet)
}

///|
/// `getType( type )`: the shader-language name of a TSL type.
pub fn NodeBuilder::get_type(self : NodeBuilder, type_ : String) -> String {
  self.class_.get_type(self, type_)
}

///|
pub fn NodeBuilder::get_type_base(
  _self : NodeBuilder,
  type_ : String,
) -> String {
  if type_ == "color" {
    return "vec3"
  }
  type_
}

///|
pub fn NodeBuilder::get_type_from_attribute(
  self : NodeBuilder,
  attribute : @core.GeometryAttribute,
) -> String {
  self.class_.get_type_from_attribute(self, attribute)
}

///|
pub fn NodeBuilder::get_type_from_attribute_base(
  self : NodeBuilder,
  attribute : @core.GeometryAttribute,
) -> String {
  // `attribute.data.array` for interleaved attributes.
  let array = attribute.array()
  let item_size = attribute.item_size()
  let normalized = attribute.normalized()
  let is_float16 = match attribute {
    Buffer(b) => b.is_float16_buffer_attribute()
    _ => false
  }
  let array_type = if !is_float16 && normalized != true {
    self.get_type_from_array(array)
  } else {
    None
  }
  self.get_type_from_length(item_size, component_type?=array_type)
}

///|
/// `getUniformFromNode( node, type, shaderStage = this.shaderStage, name = null )`.
pub fn NodeBuilder::get_uniform_from_node(
  self : NodeBuilder,
  node : Node,
  type_ : String,
  shader_stage? : String,
  name? : String,
) -> NodeUniform {
  let shader_stage = match shader_stage {
    Some(s) => Some(s)
    None => self.shader_stage
  }
  self.class_.get_uniform_from_node(self, node, type_, shader_stage, name)
}

///|
pub fn NodeBuilder::get_uniform_from_node_base(
  self : NodeBuilder,
  node : Node,
  type_ : String,
  shader_stage : String?,
  name : String?,
) -> NodeUniform {
  let node_data = self.get_data_from_node(
    node,
    shader_stage?,
    cache=self.global_cache,
  )
  match node_data.uniform {
    Some(u) => u
    None => {
      let index = self.uniforms.index
      self.uniforms.index += 1
      let name = match name {
        Some(n) if n != "" => n
        _ => "nodeUniform" + index.to_string()
      }
      let node_uniform = NodeUniform::new(name, type_, node)
      self.uniforms.stage(_node_builder_str(shader_stage)).push(node_uniform)
      self.register_declaration(Uniform(node_uniform))
      node_data.uniform = Some(node_uniform)
      node_uniform
    }
  }
}

///|
pub fn NodeBuilder::get_uniforms(
  self : NodeBuilder,
  shader_stage : String,
) -> String {
  self.class_.get_uniforms(self, shader_stage)
}

///|
pub fn NodeBuilder::get_var(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count? : Int32,
  qualifier~ : String = "",
) -> String {
  self.class_.get_var(self, type_, name, count, qualifier)
}

///|
pub fn NodeBuilder::get_var_base(
  self : NodeBuilder,
  type_ : String,
  name : String,
  count : Int32?,
) -> String {
  let declaration = match count {
    Some(_) => self.generate_array_declaration(type_, count)
    None => self.get_type(type_)
  }
  "\{declaration} \{name}"
}

///|
pub fn NodeBuilder::get_vars(
  self : NodeBuilder,
  shader_stage : String,
  global~ : Bool = false,
) -> String {
  self.class_.get_vars(self, shader_stage, global)
}

///|
pub fn NodeBuilder::get_vars_base(
  self : NodeBuilder,
  shader_stage : String,
  global : Bool,
) -> String {
  let snippets = []
  match self.vars.get(shader_stage) {
    Some(vars) =>
      for variable in vars {
        let declaration = self.get_var(
          variable.type_,
          variable.name,
          count?=variable.count,
        )
        snippets.push("\{declaration};")
      }
    None => ()
  }
  snippets.join(if global { "\n" } else { "\n\t" })
}

///|
pub fn NodeBuilder::get_varyings(
  self : NodeBuilder,
  shader_stage : String,
) -> String {
  self.class_.get_varyings(self, shader_stage)
}

///|
pub fn NodeBuilder::get_vector_select(
  self : NodeBuilder,
  cond_snippet : String,
  if_snippet : String,
  else_snippet : String,
  type_? : String,
) -> String? {
  self.class_.get_vector_select(
    self, cond_snippet, if_snippet, else_snippet, type_,
  )
}

///|
pub fn NodeBuilder::get_vertex_index(self : NodeBuilder) -> String {
  self.class_.get_vertex_index(self)
}

///|
pub fn NodeBuilder::is_available(self : NodeBuilder, name : String) -> Bool {
  self.class_.is_available(self, name)
}

///|
pub fn NodeBuilder::is_flip_y(self : NodeBuilder) -> Bool {
  self.class_.is_flip_y(self)
}

///|
pub fn NodeBuilder::is_reserved_keyword(
  self : NodeBuilder,
  name : String,
) -> Bool {
  self.class_.is_reserved_keyword(self, name)
}

///|
pub fn NodeBuilder::needs_to_working_color_space(
  self : NodeBuilder,
  texture : @core.Texture,
) -> Bool {
  self.class_.needs_to_working_color_space(self, texture)
}

///|
pub fn NodeBuilder::enable_hardware_clipping(
  self : NodeBuilder,
  plane_count : Int32,
) -> Unit {
  self.class_.enable_hardware_clipping(self, plane_count)
}

///|
pub fn NodeBuilder::generate_pbo(
  self : NodeBuilder,
  storage_array_element_node : Node,
) -> String {
  self.class_.generate_pbo(self, storage_array_element_node)
}

///|
pub fn NodeBuilder::setup_pbo(
  self : NodeBuilder,
  storage_buffer_node : Node,
) -> Unit {
  self.class_.setup_pbo(self, storage_buffer_node)
}

///|
pub fn NodeBuilder::generate_texture_load(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_index_snippet : String,
  level_snippet : String?,
  depth_snippet : String?,
  offset_snippet : String?,
) -> String {
  self.class_.generate_texture_load(
    self, texture, texture_property, uv_index_snippet, level_snippet, depth_snippet,
    offset_snippet,
  )
}

///|
pub fn NodeBuilder::generate_storage_texture_load(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_index_snippet : String,
  level_snippet : String?,
  depth_snippet : String?,
  offset_snippet : String?,
) -> String {
  self.class_.generate_storage_texture_load(
    self, texture, texture_property, uv_index_snippet, level_snippet, depth_snippet,
    offset_snippet,
  )
}

///|
pub fn NodeBuilder::generate_texture_level(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  level_snippet : String,
  depth_snippet : String?,
  offset_snippet : String?,
) -> String {
  self.class_.generate_texture_level(
    self, texture, texture_property, uv_snippet, level_snippet, depth_snippet, offset_snippet,
  )
}

///|
pub fn NodeBuilder::generate_texture_bias(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  bias_snippet : String,
  depth_snippet : String?,
  offset_snippet : String?,
  shader_stage? : String,
) -> String {
  self.class_.generate_texture_bias(
    self, texture, texture_property, uv_snippet, bias_snippet, depth_snippet, offset_snippet,
    shader_stage,
  )
}

///|
pub fn NodeBuilder::generate_texture_grad(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  grad_snippet : Array[String],
  depth_snippet : String?,
  offset_snippet : String?,
  shader_stage? : String,
) -> String {
  self.class_.generate_texture_grad(
    self, texture, texture_property, uv_snippet, grad_snippet, depth_snippet, offset_snippet,
    shader_stage,
  )
}

///|
pub fn NodeBuilder::generate_texture_compare(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  compare_snippet : String,
  depth_snippet : String?,
  offset_snippet : String?,
  shader_stage? : String,
) -> String {
  self.class_.generate_texture_compare(
    self, texture, texture_property, uv_snippet, compare_snippet, depth_snippet,
    offset_snippet, shader_stage,
  )
}

///|
pub fn NodeBuilder::generate_texture_gather(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  gather_snippet : String?,
  depth_snippet : String?,
  offset_snippet : String?,
  flip_y_snippet? : String,
) -> String {
  self.class_.generate_texture_gather(
    self, texture, texture_property, uv_snippet, gather_snippet, depth_snippet, offset_snippet,
    flip_y_snippet,
  )
}

///|
pub fn NodeBuilder::generate_texture_gather_compare(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_snippet : String,
  compare_snippet : String,
  depth_snippet : String?,
  offset_snippet : String?,
  flip_y_snippet? : String,
) -> String {
  self.class_.generate_texture_gather_compare(
    self, texture, texture_property, uv_snippet, compare_snippet, depth_snippet,
    offset_snippet, flip_y_snippet,
  )
}

///|
pub fn NodeBuilder::generate_texture_store(
  self : NodeBuilder,
  texture : @core.Texture,
  texture_property : String,
  uv_index_snippet : String,
  depth_snippet : String?,
  value_snippet : String,
) -> String {
  self.class_.generate_texture_store(
    self, texture, texture_property, uv_index_snippet, depth_snippet, value_snippet,
  )
}

///|
pub fn NodeBuilder::get_bitcast_method(
  self : NodeBuilder,
  type_ : String,
  input_type? : String,
) -> String {
  self.class_.get_bitcast_method(self, type_, input_type)
}

///|
pub fn NodeBuilder::get_float_packing_method(
  self : NodeBuilder,
  encoding : String,
  layout~ : String = "2x16",
) -> String {
  self.class_.get_float_packing_method(self, encoding, layout)
}

///|
pub fn NodeBuilder::get_float_unpacking_method(
  self : NodeBuilder,
  encoding : String,
  layout~ : String = "2x16",
) -> String {
  self.class_.get_float_unpacking_method(self, encoding, layout)
}

///|
pub fn NodeBuilder::get_clip_distance(self : NodeBuilder) -> String {
  self.class_.get_clip_distance(self)
}

///|
pub fn NodeBuilder::get_frag_depth(self : NodeBuilder) -> String {
  self.class_.get_frag_depth(self)
}

///|
pub fn NodeBuilder::get_invocation_local_index(self : NodeBuilder) -> String {
  self.class_.get_invocation_local_index(self)
}

///|
pub fn NodeBuilder::get_scoped_array(
  self : NodeBuilder,
  name : String,
  scope : String,
  buffer_type : String,
  buffer_count : Int32,
  is_atomic : Bool,
) -> String {
  self.class_.get_scoped_array(
    self, name, scope, buffer_type, buffer_count, is_atomic,
  )
}

///|
pub fn NodeBuilder::has_builtin(
  self : NodeBuilder,
  name : String,
  shader_stage? : String,
) -> Bool {
  self.class_.has_builtin(self, name, shader_stage)
}

///|
pub fn NodeBuilder::register_transform(
  self : NodeBuilder,
  varying_name : String,
  attribute_node : Node,
) -> Unit {
  self.class_.register_transform(self, varying_name, attribute_node)
}

// ---------------------------------------------------------------------------
// Non-virtual methods.

///|
pub fn NodeBuilder::is_flat_shading(self : NodeBuilder) -> Bool {
  let material = match self.material {
    Some(m) => m
    None =>
      abort("TypeError: Cannot read properties of null (reading 'flatShading')")
  }
  if material.flat_shading == Some(true) {
    return true
  }
  match self.geometry {
    Some(g) => g.has_attribute("normal") == false
    None =>
      abort(
        "TypeError: Cannot read properties of null (reading 'hasAttribute')",
      )
  }
}

///|
pub fn NodeBuilder::is_opaque(self : NodeBuilder) -> Bool {
  let material = match self.material {
    Some(m) => m
    None =>
      abort("TypeError: Cannot read properties of null (reading 'transparent')")
  }
  material.transparent == false &&
  material.blending == @core.NormalBlending &&
  material.alpha_to_coverage == false
}

///|
/// `createRenderTarget( width, height, options )`.
pub fn NodeBuilder::create_render_target(
  _self : NodeBuilder,
  width : Int32,
  height : Int32,
  options~ : RenderTargetOptions = RenderTargetOptions::new(),
) -> @core.RenderTarget {
  @core.RenderTarget::new(
    width~,
    height~,
    type_?=options.type_,
    format?=options.format,
    depth_buffer?=options.depth_buffer,
    stencil_buffer?=options.stencil_buffer,
    samples?=options.samples,
    depth_texture?=options.depth_texture,
    min_filter?=options.min_filter,
    mag_filter?=options.mag_filter,
    generate_mipmaps?=options.generate_mipmaps,
    color_space?=options.color_space,
    count?=options.count,
    depth?=options.depth,
  )
}

///|
pub fn NodeBuilder::create_cube_render_target(
  _self : NodeBuilder,
  size : Int32,
  options? : RenderTargetOptions,
) -> @core.RenderTarget {
  CubeRenderTarget::new(size~, options?)
}

///|
pub fn NodeBuilder::includes(self : NodeBuilder, node : Node) -> Bool {
  self.nodes.has(node)
}

///|
pub fn NodeBuilder::get_output_type(
  self : NodeBuilder,
  index~ : Int32 = 0,
) -> String {
  match self.renderer.get_render_target() {
    Some(render_target) if index >= 0 && index < render_target.textures.length() =>
      get_texture_type(render_target.textures[index])
    _ => "vec4"
  }
}

///|
pub fn NodeBuilder::get_bind_group_array(
  self : NodeBuilder,
  group_name : String,
  shader_stage : String,
) -> Array[Binding] {
  let bindings = match self.bindings.get(shader_stage) {
    Some(b) => b
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading '\{group_name}')",
      )
  }
  match bindings.get(group_name) {
    Some(bind_group) => bind_group
    None => {
      if !self.bindings_indexes.contains(group_name) {
        self.bindings_indexes.set(
          group_name,
          (0, self.bindings_indexes.length()),
        )
      }
      let bind_group = []
      bindings.set(group_name, bind_group)
      bind_group
    }
  }
}

///|
pub fn NodeBuilder::get_bindings(self : NodeBuilder) -> Array[BindGroup] {
  match self.bind_groups {
    Some(groups) => groups
    None => {
      let groups : Map[String, Array[Binding]] = Map::new()
      for shader_stage in shader_stages {
        match self.bindings.get(shader_stage) {
          Some(stage_bindings) =>
            for group_name, uniforms in stage_bindings {
              let group_uniforms = match groups.get(group_name) {
                Some(g) => g
                None => {
                  let g = []
                  groups.set(group_name, g)
                  g
                }
              }
              for uniform in uniforms {
                if !group_uniforms
                  .iter()
                  .any(fn(u) { physical_equal(u, uniform) }) {
                  group_uniforms.push(uniform)
                }
              }
            }
          None => ()
        }
      }
      let bindings_groups = []
      for group_name, group in groups {
        bindings_groups.push(self._get_bind_group(group_name, group))
      }
      self.bind_groups = Some(bindings_groups)
      bindings_groups
    }
  }
}

///|
/// `groupNode.order` of a binding group's first binding (`NaN` if not a group).
fn _node_builder_group_order(group : BindGroup) -> Double {
  match group.bindings[0].group_node() {
    Some(group_node) =>
      match UniformGroupNode::of(group_node) {
        Some(u) => u.order.to_double()
        None => 0.0 / 0.0
      }
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'order')")
  }
}

///|
pub fn NodeBuilder::sort_binding_groups(self : NodeBuilder) -> Unit {
  let bindings_groups = self.get_bindings()
  @webgl.stable_sort_by(bindings_groups, fn(a, b) {
    _node_builder_group_order(a) - _node_builder_group_order(b)
  })
  for i, binding_group in bindings_groups {
    match self.bindings_indexes.get(binding_group.name) {
      Some((binding, _)) =>
        self.bindings_indexes.set(binding_group.name, (binding, i))
      None =>
        abort("TypeError: Cannot set properties of undefined (setting 'group')")
    }
  }
}

///|
pub fn NodeBuilder::set_hash_node(
  self : NodeBuilder,
  node : Node,
  hash : String,
) -> Unit {
  self.hash_nodes.set(hash, node)
}

///|
pub fn NodeBuilder::add_node(self : NodeBuilder, node : Node) -> Unit {
  self.class_.add_node(self, node)
}

///|
/// `NodeBuilder.prototype.addNode`.
pub fn NodeBuilder::add_node_base(self : NodeBuilder, node : Node) -> Unit {
  if self.nodes.has(node) == false {
    self.nodes.add(node)
    self.set_hash_node(node, node.get_hash(self))
  }
}

///|
pub fn NodeBuilder::add_sequential_node(
  self : NodeBuilder,
  node : Node,
) -> Unit {
  let update_before_type = node.update_before_type
  let update_after_type = node.update_after_type
  if update_before_type != NodeUpdateType::none() ||
    update_after_type != NodeUpdateType::none() {
    self.sequential_nodes.add(node)
  }
}

///|
pub fn NodeBuilder::build_update_nodes(self : NodeBuilder) -> Unit {
  for node in self.nodes.values() {
    let update_type = node.update_type
    if update_type != NodeUpdateType::none() {
      self.update_nodes.push(node)
    }
  }
  for node in self.sequential_nodes.values() {
    let update_before_type = node.update_before_type
    let update_after_type = node.update_after_type
    if update_before_type != NodeUpdateType::none() {
      self.update_before_nodes.push(node)
    }
    if update_after_type != NodeUpdateType::none() {
      self.update_after_nodes.push(node)
    }
  }
}

///|
/// `get currentNode()`: the last node of `chaining`.
pub fn NodeBuilder::current_node(self : NodeBuilder) -> Node? {
  self.chaining.last()
}

///|
/// `get renderPipeline()`: `context.renderPipeline`, a `RenderPipeline`.
pub fn NodeBuilder::render_pipeline(self : NodeBuilder) -> ContextValue {
  self.context.get("renderPipeline")
}

///|
fn _node_builder_is_linear_filter(filter : Int32) -> Bool {
  filter == @core.LinearFilter ||
  filter == @core.LinearMipmapNearestFilter ||
  filter == @core.NearestMipmapLinearFilter ||
  filter == @core.LinearMipmapLinearFilter
}

///|
pub fn NodeBuilder::is_filtered_texture(
  _self : NodeBuilder,
  texture : @core.Texture,
) -> Bool {
  _node_builder_is_linear_filter(texture.mag_filter) ||
  _node_builder_is_linear_filter(texture.min_filter)
}

///|
pub fn NodeBuilder::get_uniform_buffer_limit(self : NodeBuilder) -> Int32 {
  self.renderer.backend.get_uniform_buffer_limit()
}

///|
pub fn NodeBuilder::add_chain(self : NodeBuilder, node : Node) -> Unit {
  self.chaining.push(node)
}

///|
pub fn NodeBuilder::remove_chain(self : NodeBuilder, node : Node) -> Unit {
  let last_chain = self.chaining.pop()
  if !(last_chain is Some(n) && physical_equal(n, node)) {
    abort("THREE.NodeBuilder: Invalid node chaining!")
  }
}

///|
pub fn NodeBuilder::get_node_from_hash(
  self : NodeBuilder,
  hash : String,
) -> Node? {
  self.hash_nodes.get(hash)
}

///|
pub fn NodeBuilder::add_flow(
  self : NodeBuilder,
  shader_stage : String,
  node : Node,
) -> Node {
  match self.flow_nodes.get(shader_stage) {
    Some(flow_nodes) => flow_nodes.push(node)
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'push')")
  }
  node
}

///|
pub fn NodeBuilder::set_context(
  self : NodeBuilder,
  context : NodeContext,
) -> Unit {
  self.context = context
}

///|
pub fn NodeBuilder::get_context(self : NodeBuilder) -> NodeContext {
  self.context
}

///|
/// Merges `context` into the current context; returns the previous one.
pub fn NodeBuilder::add_context(
  self : NodeBuilder,
  context : NodeContext,
) -> NodeContext {
  let previous_context = self.get_context()
  self.set_context(NodeContext::merge(self.context, context))
  previous_context
}

///|
pub fn NodeBuilder::get_shared_context(self : NodeBuilder) -> NodeContext {
  let context = self.context.copy()
  for
    key in [
      "material", "getUV", "getOutput", "getTextureLevel", "getAO", "getGI", "getShadow",
      "nodeLoop", "nodeBlock",
    ] {
    context.delete(key)
  }
  context
}

///|
pub fn NodeBuilder::set_cache(self : NodeBuilder, cache : NodeCache) -> Unit {
  self.cache = cache
}

///|
pub fn NodeBuilder::get_cache(self : NodeBuilder) -> NodeCache {
  self.cache
}

///|
pub fn NodeBuilder::get_cache_from_node(
  self : NodeBuilder,
  node : Node,
  parent~ : Bool = true,
) -> NodeCache {
  let data = self.get_data_from_node(node)
  match data.cache {
    Some(c) => c
    None => {
      let c = if parent {
        NodeCache::new(parent=self.get_cache())
      } else {
        NodeCache::new()
      }
      data.cache = Some(c)
      c
    }
  }
}

///|
pub fn NodeBuilder::is_context_assign(self : NodeBuilder) -> Bool {
  self.context.get_bool("assign") == Some(true)
}

///|
pub fn NodeBuilder::increase_usage(self : NodeBuilder, node : Node) -> Int32 {
  let node_data = self.get_data_from_node(node)
  let usage_count = match node_data.usage_count {
    None => 1
    Some(c) => c + 1
  }
  node_data.usage_count = Some(usage_count)
  if self.is_context_assign() {
    node_data.write_usage_count = Some(
      match node_data.write_usage_count {
        None => 1
        Some(c) => c + 1
      },
    )
  } else {
    node_data.read_usage_count = Some(
      match node_data.read_usage_count {
        None => 1
        Some(c) => c + 1
      },
    )
  }
  usage_count
}

///|
pub fn NodeBuilder::has_write_usage(self : NodeBuilder, node : Node) -> Bool {
  let ref_node = node.get_shared(self)
  let cache = if ref_node.is_global(self) {
    self.global_cache
  } else {
    self.cache
  }
  match cache.get_data(ref_node) {
    Some(node_data) =>
      for _, data in node_data {
        if _node_builder_check_write_usage(data) {
          return true
        }
      }
    None => ()
  }
  false
}

///|
/// `generateArray( type, count, values = null )`.
pub fn NodeBuilder::generate_array(
  self : NodeBuilder,
  type_ : String,
  count : Int32?,
  values? : Array[Node],
) -> String {
  let mut snippet = self.generate_array_declaration(type_, count) + "( "
  let count = count.unwrap_or(0)
  for i in 0..<count {
    match values {
      Some(values) =>
        match values.get(i) {
          Some(value) => snippet += value.build(self, output=type_)
          None =>
            abort(
              "TypeError: Cannot read properties of undefined (reading 'build')",
            )
        }
      None => snippet += self.generate_const(type_)
    }
    if i < count - 1 {
      snippet += ", "
    }
  }
  snippet += " )"
  snippet
}

///|
/// `generateStruct( type, membersLayout, values )`; `values[ i ]` is the value of
/// `membersLayout[ i ]` (upstream's `values[ member.name ]`).
pub fn NodeBuilder::generate_struct(
  self : NodeBuilder,
  type_ : String,
  members_layout : Array[StructMember],
  values? : Array[Node?],
) -> String {
  let snippets = []
  for i, member in members_layout {
    let value = match values {
      Some(values) =>
        match values.get(i) {
          Some(v) => v
          None => None
        }
      None => None
    }
    match value {
      Some(v) => snippets.push(v.build(self, output=member.type_))
      None => snippets.push(self.generate_const(member.type_))
    }
  }
  type_ + "( " + snippets.join(", ") + " )"
}

///|
/// `generateConst( type, value = null )`.
pub fn NodeBuilder::generate_const(
  self : NodeBuilder,
  type_ : String,
  value~ : TslValue = Null,
) -> String {
  let value : TslValue = if value is Null {
    match type_ {
      "float" | "int" | "uint" => Number(0.0)
      "bool" => Bool(false)
      "color" => Color(@math.Color::new(1.0, 1.0, 1.0))
      "vec2" | "uvec2" | "ivec2" | "bvec2" =>
        Vector2(@math.Vector2::new(0.0, 0.0))
      "vec3" | "uvec3" | "ivec3" | "bvec3" =>
        Vector3(@math.Vector3::new(0.0, 0.0, 0.0))
      "vec4" | "uvec4" | "ivec4" | "bvec4" =>
        Vector4(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
      _ => Null
    }
  } else {
    value
  }
  if type_ == "float" {
    return _node_builder_to_float(_node_builder_js(value))
  }
  if type_ == "int" {
    return _node_builder_trunc_string(_node_builder_js(value))
  }
  if type_ == "uint" {
    return _node_builder_uint_string(_node_builder_js(value))
  }
  if type_ == "bool" {
    return if _node_builder_truthy(_node_builder_js(value)) {
      "true"
    } else {
      "false"
    }
  }
  if type_ == "color" {
    let vec3 = self.get_type("vec3")
    let r = _node_builder_to_float(
      _node_builder_js(_node_builder_member(value, "r")),
    )
    let g = _node_builder_to_float(
      _node_builder_js(_node_builder_member(value, "g")),
    )
    let b = _node_builder_to_float(
      _node_builder_js(_node_builder_member(value, "b")),
    )
    return "\{vec3}( \{r}, \{g}, \{b} )"
  }
  let type_length = self.get_type_length(Some(type_))
  let component_type = _node_builder_str(self.get_component_type(Some(type_)))
  let generate_const = fn(key : String) {
    self.generate_const(component_type, value=_node_builder_member(value, key))
  }
  let shader_type = self.get_type(type_)
  if type_length == 2 {
    let x = generate_const("x")
    let y = generate_const("y")
    return "\{shader_type}( \{x}, \{y} )"
  } else if type_length == 3 {
    let x = generate_const("x")
    let y = generate_const("y")
    let z = generate_const("z")
    return "\{shader_type}( \{x}, \{y}, \{z} )"
  } else if type_length == 4 && type_ != "mat2" {
    let x = generate_const("x")
    let y = generate_const("y")
    let z = generate_const("z")
    let w = generate_const("w")
    return "\{shader_type}( \{x}, \{y}, \{z}, \{w} )"
  } else if type_length >= 4 && value is (Matrix2(_) | Matrix3(_) | Matrix4(_)) {
    let elements = match value {
      Matrix2(m) => m.elements
      Matrix3(m) => m.elements
      Matrix4(m) => m.elements
      _ => []
    }
    let parts = elements.map(fn(e) {
      self.generate_const(component_type, value=Number(e))
    })
    let joined = parts.join(", ")
    return "\{shader_type}( \{joined} )"
  } else if type_length > 4 {
    return "\{shader_type}()"
  }
  abort(
    "THREE.NodeBuilder: Type '\{type_}' not found in generate constant attempt.",
  )
}

///|
pub fn NodeBuilder::has_geometry_attribute(
  self : NodeBuilder,
  name : String,
) -> Bool {
  match self.geometry {
    Some(geometry) => geometry.get_attribute(name) is Some(_)
    None => false
  }
}

///|
pub fn NodeBuilder::get_attribute(
  self : NodeBuilder,
  name : String,
  type_ : String,
) -> NodeAttribute {
  let attributes = self.attributes
  for attribute in attributes {
    if attribute.name == name {
      return attribute
    }
  }
  let attribute = NodeAttribute::new(name, type_)
  self.register_declaration(Attribute(attribute))
  attributes.push(attribute)
  attribute
}

///|
pub fn NodeBuilder::is_scalar(_self : NodeBuilder, type_ : String?) -> Bool {
  type_ is Some("float" | "bool" | "int" | "uint")
}

///|
pub fn NodeBuilder::is_vector(_self : NodeBuilder, type_ : String?) -> Bool {
  _node_builder_regex_test("vec\\d", _node_builder_str(type_))
}

///|
pub fn NodeBuilder::is_matrix(_self : NodeBuilder, type_ : String?) -> Bool {
  _node_builder_regex_test("mat\\d", _node_builder_str(type_))
}

///|
pub fn NodeBuilder::is_reference(_self : NodeBuilder, type_ : String?) -> Bool {
  type_
  is Some(
    "void"
    | "property"
    | "sampler"
    | "samplerComparison"
    | "texture"
    | "cubeTexture"
    | "storageTexture"
    | "depthTexture"
    | "texture3D"
  )
}

///|
pub fn NodeBuilder::get_component_type_from_texture(
  _self : NodeBuilder,
  texture : @core.Texture,
) -> String {
  let type_ = texture.type_
  if texture.is_depth_texture() {
    return "float"
  }
  if type_ == @core.IntType {
    return "int"
  }
  if type_ == @core.UnsignedIntType {
    return "uint"
  }
  "float"
}

///|
/// `getElementType( type )`; `null` in, `null` out.
pub fn NodeBuilder::get_element_type(
  self : NodeBuilder,
  type_ : String?,
) -> String? {
  match type_ {
    Some("mat2") => Some("vec2")
    Some("mat3") => Some("vec3")
    Some("mat4") => Some("vec4")
    _ => self.get_component_type(type_)
  }
}

///|
pub fn NodeBuilder::get_component_type(
  self : NodeBuilder,
  type_ : String?,
) -> String? {
  let type_ = self.get_vector_type(type_)
  if type_ is Some("float" | "bool" | "int" | "uint") {
    return type_
  }
  match _node_builder_component_type_of(_node_builder_str(type_)) {
    "" => None
    result => Some(result)
  }
}

///|
/// `getVectorType( type )`: `color` is `vec3`, textures are `vec4`; `null` stays.
pub fn NodeBuilder::get_vector_type(
  _self : NodeBuilder,
  type_ : String?,
) -> String? {
  match type_ {
    Some("color") => Some("vec3")
    Some("texture" | "cubeTexture" | "storageTexture" | "texture3D") =>
      Some("vec4")
    _ => type_
  }
}

///|
pub fn NodeBuilder::get_type_from_length(
  _self : NodeBuilder,
  length : Int32,
  component_type~ : String = "float",
) -> String {
  if length == 1 {
    return component_type
  }
  let mut base_type = get_type_from_length(length)
  let prefix = if component_type == "float" {
    ""
  } else if component_type == "" {
    "undefined"
  } else {
    component_type.unsafe_substring(start=0, end=1)
  }
  if _node_builder_regex_test("mat2", component_type) {
    base_type = match base_type {
      Some(b) => Some(_node_builder_replace(b, "vec", "mat"))
      None =>
        abort(
          "TypeError: Cannot read properties of undefined (reading 'replace')",
        )
    }
  }
  prefix + base_type.unwrap_or("undefined")
}

///|
/// `getTypeFromArray( array )`; `None` for arrays the map lacks (`undefined`).
pub fn NodeBuilder::get_type_from_array(
  _self : NodeBuilder,
  array : @core.TypedArray,
) -> String? {
  match array.kind() {
    Int8Array | Int16Array | Int32Array => Some("int")
    Uint8Array | Uint16Array | Uint32Array => Some("uint")
    Float32Array => Some("float")
    _ => None
  }
}

///|
pub fn NodeBuilder::is_integer(_self : NodeBuilder, type_ : String?) -> Bool {
  _node_builder_regex_test("int|uint|(i|u)vec", _node_builder_str(type_))
}

///|
pub fn NodeBuilder::get_type_length(
  self : NodeBuilder,
  type_ : String?,
) -> Int32 {
  let vec_type = _node_builder_str(self.get_vector_type(type_))
  let vec_num = _node_builder_vec_num(vec_type)
  if vec_num != -1 {
    return vec_num
  }
  if vec_type is ("float" | "bool" | "int" | "uint") {
    return 1
  }
  if _node_builder_regex_test("mat2", vec_type) {
    return 4
  }
  if _node_builder_regex_test("mat3", vec_type) {
    return 9
  }
  if _node_builder_regex_test("mat4", vec_type) {
    return 16
  }
  0
}

///|
pub fn NodeBuilder::get_vector_from_matrix(
  _self : NodeBuilder,
  type_ : String,
) -> String {
  _node_builder_replace(type_, "mat", "vec")
}

///|
pub fn NodeBuilder::change_component_type(
  self : NodeBuilder,
  type_ : String,
  new_component_type : String,
) -> String {
  self.get_type_from_length(
    self.get_type_length(Some(type_)),
    component_type=new_component_type,
  )
}

///|
/// `getPromotedComponentType( ...nodes )`; `None` entries are `null`/`undefined`.
pub fn NodeBuilder::get_promoted_component_type(
  self : NodeBuilder,
  nodes : Array[Node?],
) -> String {
  let mut type_ : String? = None
  let mut has_weak = false
  let mut fits_uint = true
  let mut fits_int = true
  for node in nodes {
    guard node is Some(node) else { continue }
    match ConstNode::of(node) {
      Some(c) if c.is_weak => {
        let value = _node_builder_trunc(_node_builder_js(c.input.value))
        has_weak = true
        fits_uint = fits_uint && value >= 0.0 && value <= 4294967295.0
        fits_int = fits_int && value >= -2147483648.0 && value <= 2147483647.0
      }
      _ => {
        let component_type = self.get_component_type(node.get_node_type(self))
        let greater = match (component_type, type_) {
          (Some(a), Some(b)) =>
            match
              (
                _node_builder_component_type_ranks.get(a),
                _node_builder_component_type_ranks.get(b),
              ) {
              (Some(ra), Some(rb)) => ra > rb
              _ => false
            }
          _ => false
        }
        if type_ is None || greater {
          type_ = component_type
        }
      }
    }
  }
  match type_ {
    None => "float"
    Some("bool") if has_weak => "float"
    Some("uint") if fits_uint == false => if fits_int { "int" } else { "float" }
    Some("int") if fits_int == false => "float"
    Some(t) => t
  }
}

///|
pub fn NodeBuilder::get_integer_type(
  self : NodeBuilder,
  type_ : String,
) -> String {
  let component_type = self.get_component_type(Some(type_))
  if component_type is Some("int" | "uint") {
    return type_
  }
  self.change_component_type(type_, "int")
}

///|
pub fn NodeBuilder::set_active_stack(
  self : NodeBuilder,
  stack : StackNode,
) -> Unit {
  self.active_stacks.push(stack)
}

///|
pub fn NodeBuilder::remove_active_stack(
  self : NodeBuilder,
  stack : StackNode,
) -> Unit {
  match self.active_stacks.last() {
    Some(s) if physical_equal(s, stack) => self.active_stacks.pop() |> ignore
    _ => abort("THREE.NodeBuilder: Invalid active stack removal.")
  }
}

///|
pub fn NodeBuilder::get_active_stack(self : NodeBuilder) -> StackNode? {
  self.active_stacks.last()
}

///|
pub fn NodeBuilder::get_base_stack(self : NodeBuilder) -> StackNode? {
  self.active_stacks.get(0)
}

///|
pub fn NodeBuilder::create_block(self : NodeBuilder) -> NodeBlock {
  let stack = self.get_active_stack()
  let parent = match self.context.get("nodeBlock") {
    Block(b) => Some(b)
    _ => None
  }
  {
    parent,
    context: self.context,
    stack,
    node: match stack {
      Some(s) => s._current_node
      None => None
    },
  }
}

///|
fn _node_builder_includes_stack(
  stacks : Array[StackNode],
  stack : StackNode?,
) -> Bool {
  match stack {
    Some(s) => stacks.iter().any(fn(a) { physical_equal(a, s) })
    None => false
  }
}

///|
/// `declareBeforeBlock( node )`; `None` is `undefined`.
pub fn NodeBuilder::declare_before_block(
  self : NodeBuilder,
  node : Node,
) -> StackNode? {
  if self.flow_block is Some(_) {
    return None
  }
  let mut block : NodeBlock? = None
  let mut node_block = match self.context.get("nodeBlock") {
    Block(b) => Some(b)
    _ => None
  }
  while node_block is Some(nb) {
    if _node_builder_includes_stack(self.active_stacks, nb.stack) == false ||
      _node_builder_has_context_overrides(self.context, nb.context) {
      break
    }
    block = Some(nb)
    node_block = nb.parent
  }
  guard block is Some(block) else { return None }
  if self.active_stacks
    .iter()
    .any(fn(active_stack) {
      active_stack.nodes.iter().any(fn(n) { physical_equal(n, node) })
    }) {
    return None
  }
  let stack = block.stack.unwrap()
  // `addToStackBefore( node, block.node )`.
  let index = match block.node {
    Some(before_node) => {
      let mut index = -1
      for i, n in stack.nodes {
        if physical_equal(n, before_node) {
          index = i
          break
        }
      }
      index
    }
    None => 0
  }
  stack.add_to_stack(node, index~) |> ignore
  Some(stack)
}

///|
pub fn NodeBuilder::add_stack(self : NodeBuilder) -> StackNode {
  self.stack = StackNode::create(parent=self.stack)
  let previous_stack = get_current_stack()
  self.stacks.push(previous_stack)
  set_current_stack(Some(self.stack))
  self.stack
}

///|
pub fn NodeBuilder::remove_stack(self : NodeBuilder) -> StackNode {
  let last_stack = self.stack
  for node in last_stack.nodes {
    let node_data = self.get_data_from_node(node)
    node_data.stack = Some(last_stack)
  }
  self.stack = match last_stack.parent {
    Some(parent) => parent
    None => abort("THREE.NodeBuilder: removeStack() without a parent stack.")
  }
  let previous = match self.stacks.pop() {
    Some(s) => s
    None => None
  }
  set_current_stack(previous)
  last_stack
}

///|
/// `getDataFromNode( node, shaderStage = this.shaderStage, cache = null )`.
pub fn NodeBuilder::get_data_from_node(
  self : NodeBuilder,
  node : Node,
  shader_stage? : String,
  cache? : NodeCache,
) -> NodeData {
  let shader_stage = match shader_stage {
    Some(s) => s
    None => _node_builder_str(self.shader_stage)
  }
  let cache = match cache {
    Some(c) => c
    None => if node.is_global(self) { self.global_cache } else { self.cache }
  }
  let node_data = match cache.get_data(node) {
    Some(d) => d
    None => {
      let d = Map::new()
      cache.set_data(node, d)
      d
    }
  }
  let mut data = match node_data.get(shader_stage) {
    Some(d) => d
    None => {
      let d = NodeData::new()
      node_data.set(shader_stage, d)
      d
    }
  }
  if self.sub_build_layers.length() == 0 {
    return data
  }
  let sub_builds = match node_data.get("any") {
    Some(any) => any.sub_builds
    None => None
  }
  let sub_build = self.get_closest_sub_build_of(sub_builds)
  if sub_build is Some(sub_build) && sub_build != "" {
    let sub_builds_cache = match data.sub_builds_cache {
      Some(c) => c
      None => {
        let c = Map::new()
        data.sub_builds_cache = Some(c)
        c
      }
    }
    data = match sub_builds_cache.get(sub_build) {
      Some(d) => d
      None => {
        let d = NodeData::new()
        sub_builds_cache.set(sub_build, d)
        d
      }
    }
    data.sub_builds = sub_builds
  }
  data
}

///|
/// `getNodeProperties( node, shaderStage = 'any' )`.
pub fn NodeBuilder::get_node_properties(
  self : NodeBuilder,
  node : Node,
  shader_stage~ : String = "any",
) -> NodeProperties {
  let node_data = self.get_data_from_node(node, shader_stage~)
  match node_data.properties {
    Some(p) => p
    None => {
      let p = NodeProperties::new()
      node_data.properties = Some(p)
      p
    }
  }
}

///|
pub fn NodeBuilder::get_buffer_attribute_from_node(
  self : NodeBuilder,
  node : Node,
  type_ : String,
  name? : String,
) -> NodeAttribute {
  let node_data = self.get_data_from_node(node, shader_stage="vertex")
  match node_data.buffer_attribute {
    Some(b) => b
    None => {
      let index = self.uniforms.index
      self.uniforms.index += 1
      let name = match name {
        Some(n) => n
        None => "nodeAttribute" + index.to_string()
      }
      let buffer_attribute = NodeAttribute::new(name, type_, node~)
      self.buffer_attributes.push(buffer_attribute)
      node_data.buffer_attribute = Some(buffer_attribute)
      buffer_attribute
    }
  }
}

///|
/// `getStructTypeNode( name, shaderStage )`: the struct type node of a struct name.
pub fn NodeBuilder::get_struct_type_node(
  self : NodeBuilder,
  name : String,
  shader_stage? : String,
) -> Node? {
  let shader_stage = match shader_stage {
    Some(s) => s
    None => _node_builder_str(self.shader_stage)
  }
  match self.types.get(shader_stage) {
    Some(types) => types.get(name)
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading '\{name}')",
      )
  }
}

///|
pub fn NodeBuilder::get_struct_type_from_node(
  self : NodeBuilder,
  node : Node,
  members_layout : Array[StructMember],
  name? : String,
  shader_stage? : String,
) -> StructType {
  let shader_stage = match shader_stage {
    Some(s) => s
    None => _node_builder_str(self.shader_stage)
  }
  let node_data = self.get_data_from_node(
    node,
    shader_stage~,
    cache=self.global_cache,
  )
  match node_data.struct_type {
    Some(s) => s
    None => {
      let index = self.structs.index
      self.structs.index += 1
      let name = match name {
        Some(n) => n
        None => "StructType" + index.to_string()
      }
      let struct_type = StructType::new(name, members_layout)
      self.structs.stage(shader_stage).push(struct_type)
      match self.types.get(shader_stage) {
        Some(types) => types.set(name, node)
        None => ()
      }
      node_data.struct_type = Some(struct_type)
      struct_type
    }
  }
}

///|
pub fn NodeBuilder::get_output_struct_type_from_node(
  self : NodeBuilder,
  node : Node,
  members_layout : Array[StructMember],
) -> StructType {
  let struct_type = self.get_struct_type_from_node(
    node,
    members_layout,
    name="OutputType",
    shader_stage="fragment",
  )
  struct_type.output = true
  struct_type
}

///|
/// `getVarFromNode( node, name, type = node.getNodeType( this ), shaderStage,
/// readOnly, local_, property )`; `None` arguments take upstream's defaults.
pub fn NodeBuilder::get_var_from_node(
  self : NodeBuilder,
  node : Node,
  name : String?,
  type_ : String?,
  shader_stage : String?,
  read_only : Bool,
  local_ : Bool,
  property : String,
) -> NodeVar {
  let type_ = match type_ {
    Some(t) => t
    None => _node_builder_str(node.get_node_type(self))
  }
  let shader_stage = match shader_stage {
    Some(s) => Some(s)
    None => self.shader_stage
  }
  let node_data = self.get_data_from_node(node, shader_stage?)
  let sub_build_variable = self.get_sub_build_property(
    property~,
    sub_builds?=node_data.sub_builds,
  )
  match node_data.vars.get(sub_build_variable) {
    Some(node_var) => node_var
    None => {
      let id_ns = if read_only { "_const" } else { "_var" }
      let stage = _node_builder_str(shader_stage)
      let vars = match self.vars.get(stage) {
        Some(v) => v
        None => {
          let v = []
          self.vars.set(stage, v)
          v
        }
      }
      let id = match self.var_ids.get(id_ns) {
        Some(id) => id
        None => {
          self.var_ids.set(id_ns, 0)
          0
        }
      }
      let mut name = match name {
        Some(n) => n
        None => {
          self.var_ids.set(id_ns, id + 1)
          (if read_only { "nodeConst" } else { "nodeVar" }) + id.to_string()
        }
      }
      if sub_build_variable != property {
        name = self.get_sub_build_property(
          property=name,
          sub_builds?=node_data.sub_builds,
        )
      }
      let count = node.get_array_count(self)
      let node_var = NodeVar::new(name, type_, read_only~, count?, local_~)
      if !read_only && !local_ {
        vars.push(node_var)
      }
      self.register_declaration(Var(node_var))
      node_data.vars.set(sub_build_variable, node_var)
      node_var
    }
  }
}

///|
/// Whether `node` (an operator/math tree of constants) gives the same value each time.
/// The operands are read by their upstream property names (`aNode`, `node`, `values`).
pub fn NodeBuilder::is_deterministic(self : NodeBuilder, node : Node) -> Bool {
  let mut node = node
  if node.has_flag("isVarNode") && node.assignable {
    node = match _node_builder_child(node, "node") {
      Some(n) => n
      None =>
        abort("TypeError: Cannot read properties of null (reading 'isVarNode')")
    }
  }
  let operand = fn(name : String) -> Bool {
    match _node_builder_child(node, name) {
      Some(n) => self.is_deterministic(n)
      None => true
    }
  }
  if node.has_flag("isMathNode") {
    operand("aNode") && operand("bNode") && operand("cNode")
  } else if node.has_flag("isOperatorNode") {
    operand("aNode") && operand("bNode")
  } else if node.has_flag("isArrayNode") {
    for child in node._get_children() {
      if child.property == "values" && !self.is_deterministic(child.child_node) {
        return false
      }
    }
    true
  } else if node.has_flag("isConstNode") {
    true
  } else {
    false
  }
}

///|
pub fn NodeBuilder::get_varying_from_node(
  self : NodeBuilder,
  node : Node,
  name? : String,
  type_? : String,
  interpolation_type? : String,
  interpolation_sampling? : String,
) -> NodeVarying {
  let type_ = match type_ {
    Some(t) => t
    None => _node_builder_str(node.get_node_type(self))
  }
  let node_data = self.get_data_from_node(node, shader_stage="any")
  let sub_build_varying = self.get_sub_build_property(
    property="varying",
    sub_builds?=node_data.sub_builds,
  )
  let existing = if sub_build_varying == "varying" {
    node_data.varying
  } else {
    node_data.sub_build_varyings.get(sub_build_varying)
  }
  match existing {
    Some(v) => v
    None => {
      let varyings = self.varyings
      let index = varyings.length()
      let mut name = match name {
        Some(n) => n
        None => "nodeVarying" + index.to_string()
      }
      if sub_build_varying != "varying" {
        name = self.get_sub_build_property(
          property=name,
          sub_builds?=node_data.sub_builds,
        )
      }
      let node_varying = NodeVarying::new(
        name,
        type_,
        interpolation_type?,
        interpolation_sampling?,
      )
      varyings.push(node_varying)
      self.register_declaration(Varying(node_varying))
      if sub_build_varying == "varying" {
        node_data.varying = Some(node_varying)
      } else {
        node_data.sub_build_varyings.set(sub_build_varying, node_varying)
      }
      node_varying
    }
  }
}

///|
pub fn NodeBuilder::register_declaration(
  self : NodeBuilder,
  node : NodeVariable,
) -> Unit {
  let shader_stage = _node_builder_str(self.shader_stage)
  let declarations = match self.declarations.get(shader_stage) {
    Some(d) => d
    None => {
      let d = Map::new()
      self.declarations.set(shader_stage, d)
      d
    }
  }
  let check_keywords = self.renderer.debug.diagnostics.keywords
  let base_name = node.name()
  let mut name = base_name
  let mut declaration_name = self.get_declaration_name(node)
  let mut index = 1
  while (check_keywords && self.is_reserved_keyword(name)) ||
        declarations.contains(declaration_name) {
    name = base_name + "_" + index.to_string()
    index += 1
    node.set_name(name)
    declaration_name = self.get_declaration_name(node)
  }
  if name != base_name {
    let type_ = node.type_()
    @core.warn(
      "TSL: Declaration name '\{base_name}' of '\{type_}' is a reserved keyword or already in use. Renamed to '\{name}'.",
    )
  }
  declarations.set(declaration_name, node)
}

///|
pub fn NodeBuilder::get_code_from_node(
  self : NodeBuilder,
  node : Node,
  type_ : String,
  shader_stage? : String,
) -> NodeCode {
  let shader_stage = match shader_stage {
    Some(s) => s
    None => _node_builder_str(self.shader_stage)
  }
  let node_data = self.get_data_from_node(node)
  match node_data.code {
    Some(c) => c
    None => {
      let codes = match self.codes.get(shader_stage) {
        Some(c) => c
        None => {
          let c = []
          self.codes.set(shader_stage, c)
          c
        }
      }
      let index = codes.length()
      let node_code = NodeCode::new("nodeCode" + index.to_string(), type_)
      codes.push(node_code)
      node_data.code = Some(node_code)
      node_code
    }
  }
}

///|
/// `addLineFlowCode( code, node )`: indents and terminates a line.
pub fn NodeBuilder::add_line_flow_code(
  self : NodeBuilder,
  code : String,
  node? : Node,
) -> NodeBuilder {
  ignore(node)
  if code == "" {
    return self
  }
  let mut code = self.tab + code
  if _node_builder_ends_with_semicolon(code) == false {
    code = code + ";\n"
  }
  self.flow.code += code
  self
}

///|
pub fn NodeBuilder::add_flow_code(
  self : NodeBuilder,
  code : String,
) -> NodeBuilder {
  self.flow.code += code
  self
}

///|
pub fn NodeBuilder::add_flow_tab(self : NodeBuilder) -> NodeBuilder {
  self.tab += "\t"
  self
}

///|
pub fn NodeBuilder::remove_flow_tab(self : NodeBuilder) -> NodeBuilder {
  let length = self.tab.length()
  self.tab = if length > 0 {
    self.tab.unsafe_substring(start=0, end=length - 1)
  } else {
    ""
  }
  self
}

///|
pub fn NodeBuilder::get_flow_data(self : NodeBuilder, node : Node) -> FlowData? {
  self.flows_data.get(node.id)
}

///|
pub fn NodeBuilder::flow_node(self : NodeBuilder, node : Node) -> FlowData {
  let output = node.get_node_type(self)
  let flow_data = self.flow_child_node(node, output?)
  self.flows_data.set(node.id, flow_data)
  flow_data
}

///|
/// `addInclude( node )`: records `node` as an include of the function being built.
pub fn NodeBuilder::add_include(self : NodeBuilder, node : Node) -> Unit {
  match self.current_function_node {
    Some(function_node) =>
      match CodeNode::of(function_node) {
        Some(code_node) =>
          if !code_node.includes.iter().any(fn(n) { physical_equal(n, node) }) {
            code_node.includes.push(node)
          }
        None =>
          abort(
            "TypeError: Cannot read properties of undefined (reading 'includes')",
          )
      }
    None => ()
  }
}

///|
/// `buildFunctionNode( shaderNode )`: the `FunctionNode` of a layout `Fn`.
pub fn NodeBuilder::build_function_node(
  self : NodeBuilder,
  shader_node : Node,
) -> Node {
  let backend = self.renderer.backend
  let cache = match _node_builder_function_node_cache.get(backend) {
    Some(c) => c
    None => {
      let c = @webgl.WeakMap::new()
      _node_builder_function_node_cache.set(backend, c)
      c
    }
  }
  match cache.get(shader_node) {
    Some(f) => f
    None => {
      let f = FunctionNode::new()
      let previous = self.current_function_node
      self.current_function_node = Some(f)
      let code = self.build_function_code(shader_node)
      match CodeNode::of(f) {
        Some(c) => c.code = code
        None => ()
      }
      self.current_function_node = previous
      cache.set(shader_node, f)
      f
    }
  }
}

///|
fn _node_builder_shader_node_internal(shader_node : Node) -> ShaderNodeInternal {
  match ShaderNodeInternal::of(shader_node) {
    Some(s) => s
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'inputs')")
  }
}

///|
fn _node_builder_layout(shader : ShaderNodeInternal) -> FnLayout {
  match shader.layout {
    Some(l) => l
    None =>
      abort("TypeError: Cannot read properties of null (reading 'inputs')")
  }
}

///|
pub fn NodeBuilder::flow_shader_node(
  self : NodeBuilder,
  shader_node : Node,
) -> FlowData {
  let shader = _node_builder_shader_node_internal(shader_node)
  let layout = _node_builder_layout(shader)
  let inputs = _node_builder_create_layout_inputs(
    layout,
    layout.inputs.map(fn(input) {
      TslValue::Node(ParameterNode::new(input.type_, name=input.name))
    }),
  )
  shader.layout = None
  let call_node = ShaderNodeInternal::call_layout_inputs(shader_node, inputs)
  let flow_data = self.flow_stages_node(call_node, output?=layout.type_)
  shader.layout = Some(layout)
  flow_data
}

///|
/// `_getLayoutInputs( shaderNode, rawInputs )`; `None` means "expand inline".
pub fn NodeBuilder::_get_layout_inputs(
  self : NodeBuilder,
  shader_node : Node,
  raw_inputs : Array[TslValue]?,
) -> Array[TslValue]? {
  let shader = _node_builder_shader_node_internal(shader_node)
  let inputs = _node_builder_layout(shader).inputs
  let first_input : TslValue = match raw_inputs {
    Some(r) if r.length() > 0 => r[0]
    _ => Null
  }
  let object : Map[String, TslValue]? = if !first_input.is_nullish() &&
    is_array_as_parameter(raw_inputs.unwrap()) == false {
    match first_input {
      Object(m) => Some(m)
      _ => None
    }
  } else {
    None
  }
  let provided = inputs.mapi(fn(i, input) {
    match object {
      Some(object) =>
        match object.get(input.name) {
          Some(Undefined) | None => false
          _ => true
        }
      None =>
        match raw_inputs {
          Some(r) => i < r.length() && !(r[i] is Undefined)
          None => false
        }
    }
  })
  if provided.iter().all(fn(p) { p }) {
    return Some(raw_inputs.unwrap_or([]))
  }
  if shader.once {
    return None
  }
  let cache = match _node_builder_layout_defaults_cache.get(shader_node) {
    Some(c) => c
    None => {
      let c = Map::new()
      _node_builder_layout_defaults_cache.set(shader_node, c)
      c
    }
  }
  let key = provided.map(fn(p) { if p { "1" } else { "0" } }).join("")
  let defaults = match cache.get(key) {
    Some(d) => d
    None => {
      let d = self._resolve_layout_defaults(shader_node, provided)
      cache.set(key, d)
      d
    }
  }
  guard defaults is Some(defaults) else { return None }
  let default_value = fn(i : Int32) -> TslValue {
    match defaults.get(i) {
      Some(Some(n)) => Node(n)
      _ => Undefined
    }
  }
  match object {
    Some(object) => {
      let completed = object.copy()
      for i, input in inputs {
        if provided[i] == false {
          completed.set(input.name, default_value(i))
        }
      }
      Some([Object(completed)])
    }
    None => {
      let raw = raw_inputs.unwrap_or([])
      Some(
        provided.mapi(fn(i, is_provided) {
          if is_provided {
            raw[i]
          } else {
            default_value(i)
          }
        }),
      )
    }
  }
}

///|
/// `_resolveLayoutDefaults( shaderNode, provided )`: the default value of each missing
/// input, found by comparing the call graphs with and without the parameters.
pub fn NodeBuilder::_resolve_layout_defaults(
  self : NodeBuilder,
  shader_node : Node,
  provided : Array[Bool],
) -> Array[Node?]? {
  let layout = _node_builder_layout(
    _node_builder_shader_node_internal(shader_node),
  )
  let parameters = layout.inputs.map(fn(input) {
    ParameterNode::new(input.type_, name=input.name)
  })
  let full_graph = self._get_layout_call_graph(
    shader_node,
    _node_builder_create_layout_inputs(
      layout,
      parameters.map(fn(p) { Node(p) }),
    ),
  )
  let partial_graph = self._get_layout_call_graph(
    shader_node,
    _node_builder_create_layout_inputs(
      layout,
      parameters.mapi(fn(i, p) { if provided[i] { Node(p) } else { Undefined } }),
    ),
  )
  let missing : Map[Int32, Int32] = Map::new()
  for i, parameter in parameters {
    if provided[i] == false {
      missing.set(parameter.id, i)
    }
  }
  let defaults : Array[Node?] = Array::make(parameters.length(), None)
  let visited : Map[Int32, Node] = Map::new()
  fn walk(a : Node?, b : Node?) -> Bool {
    match (a, b) {
      (None, None) => true
      (Some(a), Some(b)) => {
        if physical_equal(a, b) {
          return true
        }
        match missing.get(a.id) {
          Some(index) => {
            if defaults[index] is None {
              defaults[index] = Some(b)
            }
            return defaults[index] is Some(d) && physical_equal(d, b)
          }
          None => ()
        }
        match visited.get(a.id) {
          Some(v) => return physical_equal(v, b)
          None => ()
        }
        if a.class_.class_name() != b.class_.class_name() {
          return false
        }
        visited.set(a.id, b)
        let children_a = a.get_children()
        let children_b = b.get_children()
        if children_a.length() != children_b.length() {
          return false
        }
        for i in 0..<children_a.length() {
          if walk(Some(children_a[i]), Some(children_b[i])) == false {
            return false
          }
        }
        true
      }
      _ => false
    }
  }

  let extra = partial_graph.nodes.length() - full_graph.nodes.length()
  if extra < 0 {
    return None
  }
  visited.set(full_graph.node.id, partial_graph.node)
  if walk(full_graph.output_node, partial_graph.output_node) == false {
    return None
  }
  for i in 0..<full_graph.nodes.length() {
    if walk(Some(full_graph.nodes[i]), Some(partial_graph.nodes[extra + i])) ==
      false {
      return None
    }
  }
  let parameter_set = NodeSet::new()
  for p in parameters {
    parameter_set.add(p)
  }
  for _, index in missing {
    guard defaults[index] is Some(value) else { return None }
    let stack = [value]
    let seen = NodeSet::new()
    while stack.pop() is Some(node) {
      if parameter_set.has(node) {
        return None
      }
      if seen.has(node) {
        continue
      }
      seen.add(node)
      for child in node.get_children() {
        stack.push(child)
      }
    }
  }
  Some(defaults)
}

///|
/// `_getLayoutCallGraph( shaderNode, inputs )`: the stack of an inline call.
pub fn NodeBuilder::_get_layout_call_graph(
  self : NodeBuilder,
  shader_node : Node,
  inputs : Map[String, TslValue],
) -> StackNode {
  let shader = _node_builder_shader_node_internal(shader_node)
  let layout = shader.layout
  shader.layout = None
  self.add_stack() |> ignore
  let call_node = ShaderNodeInternal::call_layout_inputs(shader_node, inputs)
  self.stack.output_node = ShaderCallNodeInternal::call_body(call_node, self)
  let graph = self.remove_stack()
  shader.layout = layout
  graph
}

///|
pub fn NodeBuilder::flow_build_stage(
  self : NodeBuilder,
  node : Node,
  build_stage : String,
  output~ : BuildOutput = NoOutput,
) -> BuildResult {
  let previous_build_stage = self.get_build_stage()
  self.set_build_stage(Some(build_stage))
  let result = node.build_output(self, output)
  self.set_build_stage(previous_build_stage)
  result
}

///|
/// `flowStagesNode( node, output )`: runs setup, analyze and generate on `node` with
/// fresh vars and cache; `{ code, result, vars }`.
pub fn NodeBuilder::flow_stages_node(
  self : NodeBuilder,
  node : Node,
  output? : String,
) -> FlowData {
  let previous_flow = self.flow
  let previous_vars = self.vars
  let previous_var_ids = self.var_ids
  let previous_declarations = self.declarations
  let previous_cache = self.cache
  let previous_build_stage = self.build_stage
  let previous_stack = self.stack
  let previous_flow_block = self.flow_block
  let flow = FlowData::new()
  self.flow = flow
  self.vars = Map::new()
  self.var_ids = Map::new()
  self.declarations = Map::new()
  self.cache = NodeCache::new()
  self.stack = StackNode::create()
  self.flow_block = None
  for build_stage in default_build_stages {
    self.set_build_stage(Some(build_stage))
    flow.result = node.build_output(self, BuildOutput::of_type(output))
  }
  flow.vars = Some(self.get_vars(_node_builder_str(self.shader_stage)))
  self.flow = previous_flow
  self.vars = previous_vars
  self.var_ids = previous_var_ids
  self.declarations = previous_declarations
  self.cache = previous_cache
  self.stack = previous_stack
  self.flow_block = previous_flow_block
  self.set_build_stage(previous_build_stage)
  flow
}

///|
pub fn NodeBuilder::flow_child_node(
  self : NodeBuilder,
  node : Node,
  output? : String,
) -> FlowData {
  let previous_flow = self.flow
  let flow = FlowData::new()
  self.flow = flow
  flow.result = node.build_output(self, BuildOutput::of_type(output))
  self.flow = previous_flow
  flow
}

///|
/// `flowNodeFromShaderStage( shaderStage, node, output, propertyName )`: the flow
/// data in the generate stage, else the result of `node.build( this )` (as `result`).
pub fn NodeBuilder::flow_node_from_shader_stage(
  self : NodeBuilder,
  shader_stage : String,
  node : Node,
  output? : String,
  property_name? : String,
) -> FlowData {
  let previous_tab = self.tab
  let previous_cache = self.cache
  let previous_shader_stage = self.shader_stage
  let previous_context = self.context
  let previous_flow_block = self.flow_block
  self.set_shader_stage(Some(shader_stage))
  let context = self.context.copy()
  context.delete("nodeBlock")
  self.flow_block = None
  self.cache = self.global_cache
  self.tab = "\t"
  self.context = context
  let result = if self.build_stage == Some("generate") {
    let flow_data = self.flow_child_node(node, output?)
    match property_name {
      Some(property_name) => {
        let snippet = _node_builder_result_string(flow_data.result)
        flow_data.code += "\{self.tab}\{property_name} = \{snippet};\n"
      }
      None => ()
    }
    let flow_code = match self.flow_code.get(shader_stage) {
      Some(c) => c
      None => "undefined"
    }
    self.flow_code.set(shader_stage, flow_code + flow_data.code)
    flow_data
  } else {
    let r = node.build_output(self, NoOutput)
    { code: "", result: r, vars: None, }
  }
  self.set_shader_stage(previous_shader_stage)
  self.cache = previous_cache
  self.tab = previous_tab
  self.context = previous_context
  self.flow_block = previous_flow_block
  result
}

///|
pub fn NodeBuilder::get_attributes_array(
  self : NodeBuilder,
) -> Array[NodeAttribute] {
  self.attributes + self.buffer_attributes
}

///|
pub fn NodeBuilder::get_codes(
  self : NodeBuilder,
  shader_stage : String,
) -> String {
  let mut code = ""
  match self.codes.get(shader_stage) {
    Some(codes) =>
      for node_code in codes {
        code += node_code.code + "\n"
      }
    None => ()
  }
  code
}

///|
fn _node_builder_nullable_string(s : String?) -> @core.JsValue {
  match s {
    Some(s) => @core.JsValue::of(s)
    None => @core.JsValue::null()
  }
}

///|
pub fn NodeBuilder::get_hash(self : NodeBuilder) -> String {
  _node_builder_js_concat3(
    _node_builder_nullable_string(self.vertex_shader),
    _node_builder_nullable_string(self.fragment_shader),
    _node_builder_nullable_string(self.compute_shader),
  )
}

///|
pub fn NodeBuilder::set_shader_stage(
  self : NodeBuilder,
  shader_stage : String?,
) -> Unit {
  self.shader_stage = shader_stage
}

///|
pub fn NodeBuilder::get_shader_stage(self : NodeBuilder) -> String? {
  self.shader_stage
}

///|
pub fn NodeBuilder::set_build_stage(
  self : NodeBuilder,
  build_stage : String?,
) -> Unit {
  self.build_stage = build_stage
}

///|
pub fn NodeBuilder::get_build_stage(self : NodeBuilder) -> String? {
  self.build_stage
}

///|
/// `get subBuild()`: the innermost sub-build name, if any.
pub fn NodeBuilder::sub_build(self : NodeBuilder) -> String? {
  match self.sub_build_layers.last() {
    Some(s) if s != "" => Some(s)
    _ => None
  }
}

///|
pub fn NodeBuilder::add_sub_build(
  self : NodeBuilder,
  sub_build : String,
) -> Unit {
  self.sub_build_layers.push(sub_build)
}

///|
pub fn NodeBuilder::remove_sub_build(self : NodeBuilder) -> String? {
  self.sub_build_layers.pop()
}

///|
/// `getClosestSubBuild( data )` for a node.
pub fn NodeBuilder::get_closest_sub_build(
  self : NodeBuilder,
  node : Node,
) -> String? {
  let sub_builds = match ShaderCallNodeInternal::of(node) {
    Some(call) =>
      match ShaderNodeInternal::of(call.shader_node) {
        Some(shader) => shader.sub_builds
        None => None
      }
    None =>
      match StackNode::of(node) {
        Some(stack) =>
          match stack.get_sub_build() {
            Some(s) => Some([s])
            None => Some([])
          }
        None => self.get_data_from_node(node, shader_stage="any").sub_builds
      }
  }
  self.get_closest_sub_build_of(sub_builds)
}

///|
/// `getClosestSubBuild( data )` for a list (or `Set`) of sub-build names.
pub fn NodeBuilder::get_closest_sub_build_of(
  self : NodeBuilder,
  sub_builds : Array[String]?,
) -> String? {
  guard sub_builds is Some(sub_builds) else { return None }
  let sub_build_layers = self.sub_build_layers
  for i = sub_builds.length() - 1; i >= 0; i = i - 1 {
    let sub_build = sub_builds[i]
    if sub_build_layers.contains(sub_build) {
      return Some(sub_build)
    }
  }
  None
}

///|
pub fn NodeBuilder::get_sub_build_output(
  self : NodeBuilder,
  node : Node,
) -> String {
  self.get_sub_build_property(property="outputNode", node~)
}

///|
/// `getSubBuildProperty( property = '', node = null )`; `sub_builds` is the
/// overload upstream calls with `nodeData.subBuilds`.
pub fn NodeBuilder::get_sub_build_property(
  self : NodeBuilder,
  property~ : String = "",
  node? : Node,
  sub_builds? : Array[String],
) -> String {
  let sub_build = match (node, sub_builds) {
    (Some(node), _) => self.get_closest_sub_build(node)
    (None, Some(sub_builds)) => self.get_closest_sub_build_of(Some(sub_builds))
    (None, None) => self.sub_build_fn
  }
  match sub_build {
    Some(sub_build) if sub_build != "" =>
      if property != "" {
        sub_build + "_" + property
      } else {
        sub_build
      }
    _ => property
  }
}

///|
pub fn NodeBuilder::prebuild(self : NodeBuilder) -> Unit {
  self.class_.prebuild(self)
}

///|
/// `NodeBuilder.prototype.prebuild`.
pub fn NodeBuilder::prebuild_base(self : NodeBuilder) -> Unit {
  let renderer = self.renderer
  let material = self.material
  // < renderer.contextNode >
  if renderer.context_node.has_flag("isContextNode") {
    self.add_context(ContextNode::get_flow_context_data(renderer.context_node))
    |> ignore
  } else {
    @core.error(
      "NodeBuilder: \"renderer.contextNode\" must be an instance of `context()`.",
    )
  }
  // < material.contextNode >
  match material {
    Some(m) =>
      match NodeMaterial::of(m) {
        Some(node_material) =>
          match node_material.context_node {
            Some(context_node) =>
              if context_node.has_flag("isContextNode") {
                self.add_context(
                  ContextNode::get_flow_context_data(context_node),
                )
                |> ignore
              } else {
                @core.error(
                  "NodeBuilder: \"material.contextNode\" must be an instance of `context()`.",
                )
              }
            None => ()
          }
        None => ()
      }
    None => ()
  }
  // < nodeMaterial >
  match material {
    Some(material) => {
      let node_material = match renderer.library.from_material(material) {
        Some(m) => m
        None => {
          @core.error(
            "NodeBuilder: Material \"\{material.type_}\" is not compatible.",
          )
          NodeMaterial::new()
        }
      }
      NodeMaterial::build(node_material, self)
    }
    None =>
      match self.compute {
        Some(compute) => self.add_flow("compute", compute) |> ignore
        None =>
          abort("TypeError: Cannot read properties of null (reading 'build')")
      }
  }
}

///|
/// One build stage of `build`/`buildAsync` for one shader stage.
fn NodeBuilder::_build_shader_stage(
  self : NodeBuilder,
  build_stage : String,
  shader_stage : String,
) -> Unit {
  self.set_shader_stage(Some(shader_stage))
  let flow_nodes = match self.flow_nodes.get(shader_stage) {
    Some(f) => f
    None => []
  }
  let mut i = 0
  while i < flow_nodes.length() {
    let node = flow_nodes[i]
    if build_stage == "generate" {
      self.flow_node(node) |> ignore
    } else {
      node.build_output(self, NoOutput) |> ignore
    }
    i += 1
  }
}

///|
/// The `context.position` step at the start of a build stage.
fn NodeBuilder::_build_context_position(self : NodeBuilder) -> Unit {
  match self.context.get_node("position") {
    Some(position) =>
      self.flow_node_from_shader_stage("vertex", position) |> ignore
    None => ()
  }
}

///|
pub fn NodeBuilder::build(self : NodeBuilder) -> NodeBuilder {
  self.prebuild()
  // setup() -> stage 1: create possible new nodes and/or return an output reference node
  // analyze()   -> stage 2: analyze nodes to possible optimization and validation
  // generate()  -> stage 3: generate shader
  for build_stage in default_build_stages {
    self.set_build_stage(Some(build_stage))
    self._build_context_position()
    for shader_stage in shader_stages {
      self._build_shader_stage(build_stage, shader_stage)
    }
  }
  self.set_build_stage(None)
  self.set_shader_stage(None)
  // stage 4: build code for a specific output
  self.build_code()
  self.build_update_nodes()
  self
}

///|
/// `buildAsync( yieldFn )`: `build` with a yield after each shader stage; calls
/// `on_done` with the builder. `yield_fn` defaults to `yieldToMain`.
pub fn NodeBuilder::build_async(
  self : NodeBuilder,
  on_done : (NodeBuilder) -> Unit,
  yield_fn~ : (() -> Unit) -> Unit = _node_builder_yield_to_main,
) -> Unit {
  self.prebuild()
  let build_stages = default_build_stages
  fn step(b : Int32, s : Int32) -> Unit {
    if b >= build_stages.length() {
      self.set_build_stage(None)
      self.set_shader_stage(None)
      self.build_code()
      self.build_update_nodes()
      on_done(self)
      return
    }
    let build_stage = build_stages[b]
    if s == 0 {
      self.set_build_stage(Some(build_stage))
      self._build_context_position()
    }
    self._build_shader_stage(build_stage, shader_stages[s])
    // Yield to main thread after each shader stage to prevent blocking
    yield_fn(fn() {
      if s + 1 < shader_stages.length() {
        step(b, s + 1)
      } else {
        step(b + 1, 0)
      }
    })
  }

  step(0, 0)
}

///|
pub fn NodeBuilder::get_node_uniform(
  _self : NodeBuilder,
  uniform_node : NodeUniform,
  type_ : String,
) -> Uniform {
  match type_ {
    "float" | "int" | "uint" => NumberNodeUniform::new(uniform_node)
    "vec2" | "ivec2" | "uvec2" => Vector2NodeUniform::new(uniform_node)
    "vec3" | "ivec3" | "uvec3" => Vector3NodeUniform::new(uniform_node)
    "vec4" | "ivec4" | "uvec4" => Vector4NodeUniform::new(uniform_node)
    "color" => ColorNodeUniform::new(uniform_node)
    "mat2" => Matrix2NodeUniform::new(uniform_node)
    "mat3" => Matrix3NodeUniform::new(uniform_node)
    "mat4" => Matrix4NodeUniform::new(uniform_node)
    _ => abort("THREE.NodeBuilder: Uniform \"\{type_}\" not implemented.")
  }
}

///|
/// `format( snippet, fromType, toType )`.
pub fn NodeBuilder::format(
  self : NodeBuilder,
  snippet : String,
  from_type : String?,
  to_type : String?,
) -> String {
  let from_type = self.get_vector_type(from_type)
  let to_type = self.get_vector_type(to_type)
  if from_type == to_type || to_type is None || self.is_reference(to_type) {
    return snippet
  }
  let to_type_name = to_type.unwrap()
  let from_type_length = self.get_type_length(from_type)
  let to_type_length = self.get_type_length(to_type)
  let to_shader_type = self.get_type(to_type_name)
  if from_type_length == 16 && to_type_length == 9 {
    return "\{to_shader_type}( \{snippet}[ 0 ].xyz, \{snippet}[ 1 ].xyz, \{snippet}[ 2 ].xyz )"
  }
  if from_type_length == 9 && to_type_length == 4 {
    return "\{to_shader_type}( \{snippet}[ 0 ].xy, \{snippet}[ 1 ].xy )"
  }
  if from_type_length > 4 {
    // fromType is matrix-like
    return snippet
  }
  if to_type_length > 4 || to_type_length == 0 {
    // toType is matrix-like or unknown
    return snippet
  }
  if from_type_length == to_type_length {
    return "\{to_shader_type}( \{snippet} )"
  }
  if from_type_length > to_type_length {
    let swizzle = "xyz".unsafe_substring(start=0, end=to_type_length)
    let snippet = if to_type_name == "bool" {
      "all( \{snippet} )"
    } else {
      "\{snippet}.\{swizzle}"
    }
    let component_type = self.get_component_type(from_type)
    let from = self.get_type_from_length(to_type_length, component_type?)
    return self.format(snippet, Some(from), to_type)
  }
  if to_type_length == 4 && from_type_length > 1 {
    // toType is vec4-like
    let component_type = self.get_component_type(to_type)
    let vector_type = self.get_type_from_length(3, component_type?)
    let inner = self.format(snippet, from_type, Some(vector_type))
    let one = self.generate_const(
      _node_builder_str(component_type),
      value=if component_type == Some("bool") {
        Bool(true)
      } else {
        Number(1.0)
      },
    )
    return "\{to_shader_type}( \{inner}, \{one} )"
  }
  if from_type_length == 2 {
    // fromType is vec2-like and toType is vec3-like
    let component_type = self.get_component_type(to_type)
    let vector_type = self.get_type_from_length(2, component_type?)
    let inner = self.format(snippet, from_type, Some(vector_type))
    let zero = self.generate_const(
      _node_builder_str(component_type),
      value=if component_type == Some("bool") {
        Bool(false)
      } else {
        Number(0.0)
      },
    )
    return "\{to_shader_type}( \{inner}, \{zero} )"
  }
  let mut snippet = snippet
  let to_component_type = self.get_component_type(to_type)
  if from_type_length == 1 &&
    to_type_length > 1 &&
    from_type != to_component_type {
    // convert a number value to vector type, e.g:
    // vec3( 1u ) -> vec3( float( 1u ) )
    let component_shader_type = self.get_type(
      _node_builder_str(to_component_type),
    )
    snippet = "\{component_shader_type}( \{snippet} )"
  }
  "\{to_shader_type}( \{snippet} )"
}

///|
pub fn NodeBuilder::get_signature(_self : NodeBuilder) -> String {
  "// Three.js r\{@core.REVISION} - Node System\n"
}

///|
pub fn NodeBuilder::needs_previous_data(self : NodeBuilder) -> Bool {
  match self.renderer.get_mrt() {
    Some(mrt) =>
      // `mrt.has( 'velocity' )`: `outputNodes.velocity !== undefined`.
      mrt
      ._get_children()
      .iter()
      .any(fn(c) {
        c.property == "outputNodes" && c.index == Some(Key("velocity"))
      })
    None => false
  }
}

///|
/// The `options` of `createRenderTarget( width, height, options )`: upstream's
/// `RenderTarget` options; `None` keeps the default.
pub(all) struct RenderTargetOptions {
  type_ : Int32?
  format : Int32?
  depth_buffer : Bool?
  stencil_buffer : Bool?
  samples : Int32?
  depth_texture : @core.Texture?
  min_filter : Int32?
  mag_filter : Int32?
  generate_mipmaps : Bool?
  color_space : String?
  count : Int32?
  depth : Int32?
}

///|
/// `{ ...options }` with the given keys.
pub fn RenderTargetOptions::new(
  type_? : Int32,
  format? : Int32,
  depth_buffer? : Bool,
  stencil_buffer? : Bool,
  samples? : Int32,
  depth_texture? : @core.Texture,
  min_filter? : Int32,
  mag_filter? : Int32,
  generate_mipmaps? : Bool,
  color_space? : String,
  count? : Int32,
  depth? : Int32,
) -> RenderTargetOptions {
  {
    type_,
    format,
    depth_buffer,
    stencil_buffer,
    samples,
    depth_texture,
    min_filter,
    mag_filter,
    generate_mipmaps,
    color_space,
    count,
    depth,
  }
}
