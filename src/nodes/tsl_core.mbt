// nodes/tsl/TSLCore.js: `nodeObject`, the shared constants, the type conversions
// (`float`, `vec3`, ...), `Fn` (`FnNode`, `ShaderNodeInternal`,
// `ShaderCallNodeInternal`), `If`/`Switch`/`Stack`, and the `Node` methods TSLCore adds
// (`assign`, `get`, the chained `toStack`/`toFloat`/.../`element`/`convert`, `n[ i ]`).
// The swizzle getters are generated into tsl_swizzle.mbt by tools/gen_swizzle.mjs.
//
// JS rest parameters: a type conversion takes one value (`vec3(x)`, the chained
// `to_vec3`) or, for any count, an array (`vec3_of([x, y, z])`), since MoonBit has no
// optional positional parameters.

///|
let current_stack : Ref[StackNode?] = Ref(None)

///|
/// `setCurrentStack( stack )`.
pub fn set_current_stack(stack : StackNode?) -> Unit {
  current_stack.val = stack
}

///|
/// `getCurrentStack()`.
pub fn get_current_stack() -> StackNode? {
  current_stack.val
}

// ---------------------------------------------------------------------------
// nodeObject

///|
/// `nodeObject( value, altType = null )` with its JS result: nodes stay, numbers,
/// booleans, vectors, colors, matrices and `ArrayBuffer`s become (shared) constants,
/// plain functions become `Fn`s, anything else (strings, arrays, plain objects,
/// `undefined`) is returned as is.
pub fn node_object_value(value : TslValue, alt_type? : String) -> TslValue {
  match get_value_type(value) {
    Some("node") => value
    Some("shader") =>
      match value {
        Shader(f) => Node(fn_(f.f))
        _ => abort("nodeObject: a JS function cannot become a Fn")
      }
    Some("string") | None => value
    Some(_) => Node(get_const_node(value, type_?=alt_type))
  }
}

///|
/// `nodeObject( value, altType = null )` for values that become nodes.
pub fn node_object(value : TslValue, alt_type? : String) -> Node {
  match node_object_value(value, alt_type?) {
    Node(n) => n
    v => abort("nodeObject: \{tsl_core_describe(v)} is not a node")
  }
}

///|
fn tsl_core_describe(value : TslValue) -> String {
  match value {
    Undefined => "undefined"
    Null => "null"
    String(s) => "the string \"\{s}\""
    Array(_) => "an array"
    Object(_) => "an object"
    Texture(_) => "a texture"
    _ => "the value"
  }
}

///|
/// `nodeObjectAssignable( value, altType = null )`: an assignable node, copying a
/// shared constant first.
pub fn node_object_assignable(value : &IntoTsl, alt_type? : String) -> Node {
  let mut node = node_object(value.to_tsl(), alt_type?)
  // Shared constants need their own assignable node.
  if ConstNode::of(node) is Some(c) &&
    tsl_core_const_nodes().get(c.input.value) is Some(shared) &&
    physical_equal(shared, node) {
    let copy = ConstNode::new(c.input.value, node_type?=node.node_type)
    ConstNode::of(copy).unwrap().is_weak = c.is_weak
    node = copy
  }
  node.to_assignable()
}

///|
/// `nodeObjects( objects, altType = null )`: converts the values in place.
pub fn node_objects(
  objects : Map[String, TslValue],
  alt_type? : String,
) -> Map[String, TslValue] {
  for name, value in objects {
    objects[name] = node_object_value(value, alt_type?)
  }
  objects
}

///|
/// `nodeArray( array, altType = null )`: converts the elements in place.
pub fn node_array(
  array : Array[TslValue],
  alt_type? : String,
) -> Array[TslValue] {
  for i in 0..<array.length() {
    array[i] = node_object_value(array[i], alt_type?)
  }
  array
}

// ---------------------------------------------------------------------------
// Shared constants

///|
/// A JS `Map` keyed by numbers and booleans (`SameValueZero`: `-0` is `0`).
priv struct TslConstCache {
  bools : Map[Bool, Node]
  numbers : Map[Double, Node]
}

///|
fn TslConstCache::new() -> TslConstCache {
  { bools: Map([]), numbers: Map([]), }
}

///|
fn tsl_core_number_key(value : Double) -> Double {
  if value == 0.0 {
    0.0
  } else {
    value
  }
}

///|
fn TslConstCache::get(self : TslConstCache, value : TslValue) -> Node? {
  match value {
    Bool(b) => self.bools.get(b)
    Number(d) => self.numbers.get(tsl_core_number_key(d))
    _ => None
  }
}

///|
fn TslConstCache::set_number(
  self : TslConstCache,
  value : Double,
  node : Node,
) -> Unit {
  self.numbers.set(tsl_core_number_key(value), node)
}

///|
priv struct TslConstCaches {
  bools : TslConstCache
  uints : TslConstCache
  ints : TslConstCache
  floats : TslConstCache
  /// `constNodesCacheMap`: the constants `nodeObject` shares.
  const_nodes : TslConstCache
}

///|
/// The caches, created in upstream's order (node ids follow creation order).
fn tsl_core_create_caches() -> TslConstCaches {
  let pi = 3.141592653589793
  let floats = [
    0.5,
    1.5,
    1.0 / 3.0,
    1.0e-6,
    1.0e6,
    pi,
    pi * 2.0,
    1.0 / pi,
    2.0 / pi,
    1.0 / (pi * 2.0),
    pi / 2.0,
  ]
  let bools = TslConstCache::new()
  module_nodes("nodes/tsl/TSLCore.js:boolsCacheMap", fn() {
    for b in [false, true] {
      bools.bools.set(b, ConstNode::new(Bool(b)))
    }
  })
  let uints = TslConstCache::new()
  module_nodes("nodes/tsl/TSLCore.js:uintsCacheMap", fn() {
    for u in [0.0, 1.0, 2.0, 3.0] {
      uints.set_number(u, ConstNode::new(Number(u), node_type="uint"))
    }
  })
  let ints = TslConstCache::new()
  module_nodes("nodes/tsl/TSLCore.js:intsCacheMap", fn() {
    for value in uints.numbers.keys() {
      ints.set_number(value, ConstNode::new(Number(value), node_type="int"))
    }
    for i in [-1.0, -2.0] {
      ints.set_number(i, ConstNode::new(Number(i), node_type="int"))
    }
  })
  let float_cache = TslConstCache::new()
  module_nodes("nodes/tsl/TSLCore.js:floatsCacheMap", fn() {
    for value in ints.numbers.keys() {
      float_cache.set_number(value, ConstNode::new(Number(value)))
    }
    for f in floats {
      float_cache.set_number(f, ConstNode::new(Number(f)))
    }
    for f in floats {
      float_cache.set_number(-f, ConstNode::new(Number(-f)))
    }
  })
  let const_nodes = TslConstCache::new()
  for b, node in bools.bools {
    const_nodes.bools.set(b, node)
  }
  module_nodes("nodes/tsl/TSLCore.js:constNodesCacheMap", fn() {
    for value in float_cache.numbers.keys() {
      // `getConstNode( value )`: an implicit number, so weak
      let node = ConstNode::new(Number(value))
      ConstNode::of(node).unwrap().is_weak = true
      const_nodes.set_number(value, node)
    }
  })
  { bools, uints, ints, floats: float_cache, const_nodes, }
}

///|
let _tsl_core_caches : TslConstCaches = tsl_core_create_caches()

///|
fn tsl_core_const_nodes() -> TslConstCache {
  _tsl_core_caches.const_nodes
}

///|
/// The shared constant `nodeObject` returns for a number or boolean, if any
/// (`constNodesCacheMap.get( value )`).
pub fn get_shared_const_node(value : TslValue) -> Node? {
  tsl_core_const_nodes().get(value)
}

///|
/// `getConstNode( value, type )`: the shared constant, the node itself, or a new
/// `ConstNode` (weak for implicit numbers).
pub fn get_const_node(value : TslValue, type_? : String) -> Node {
  if tsl_core_const_nodes().get(value) is Some(node) {
    return node
  }
  match value {
    Node(n) => n
    Undefined | Null =>
      abort(
        "getConstNode: Cannot read properties of \{tsl_core_describe(value)} (reading 'isNode')",
      )
    _ => {
      let node = ConstNode::new(value, node_type?=type_)
      // Implicit numbers are weak and can adapt to the type of other operands.
      let implicit = match type_ {
        None | Some("") => true
        Some(_) => false
      }
      ConstNode::of(node).unwrap().is_weak = implicit && value is Number(_)
      node
    }
  }
}

// ---------------------------------------------------------------------------
// ConvertType

///|
/// `typeof param !== 'object' && typeof param !== 'function'`.
fn tsl_core_is_primitive(value : TslValue) -> Bool {
  match value {
    Undefined | Number(_) | Bool(_) | String(_) => true
    Js(v) => tsl_core_js_is_primitive(v)
    _ => false
  }
}

///|
extern "js" fn tsl_core_js_is_primitive(value : @core.JsValue) -> Bool = "(v) => typeof v !== 'object' && typeof v !== 'function'"

///|
/// The function `ConvertType( type, cacheMap )` returns, applied to `params`.
fn tsl_core_convert_type(
  type_ : String,
  cache_map : TslConstCache?,
  params : Array[TslValue],
) -> Node {
  for param in params {
    if param is Undefined {
      @core.error("TSL: Invalid parameter for the type \"\{type_}\".")
      return ConstNode::new(Number(0.0), node_type=type_)
    }
  }
  let mut params = params
  let scalar = type_ is ("bool" | "float" | "int" | "uint")
  if params.length() == 0 ||
    (!scalar && params.iter().all(tsl_core_is_primitive)) {
    params = [get_value_from_type(Some(type_), params)]
  }
  if params.length() == 1 &&
    cache_map is Some(cache) &&
    cache.get(params[0]) is Some(cached) {
    return ConstNode::new(
      InputNode::get_value(cached),
      node_type?=cached.node_type,
    ).to_assignable()
  }
  if params.length() == 1 {
    let param = params[0]
    let node = get_const_node(param, type_~)
    if node.node_type == Some(type_) {
      // A node given by the user or a shared constant must not become the variable itself.
      if param is Node(p) && physical_equal(p, node) {
        return ConvertNode::new(node, type_).to_assignable()
      }
      if tsl_core_const_nodes().get(param) is Some(shared) &&
        physical_equal(shared, node) {
        return ConstNode::new(
          InputNode::get_value(node),
          node_type?=node.node_type,
        ).to_assignable()
      }
      return node.to_assignable()
    }
    return ConvertNode::new(node, type_).to_assignable()
  }
  let nodes = params.map(fn(param) { get_const_node(param) })
  JoinNode::new(nodes~, node_type=type_).to_assignable()
}

///|
fn tsl_core_values(params : Array[&IntoTsl]) -> Array[TslValue] {
  params.map(fn(p) { p.to_tsl() })
}

///|
/// `color( value )`: a `Color` constant (a number is a hex value) or a conversion.
pub fn color(value : &IntoTsl) -> Node {
  tsl_core_convert_type("color", None, [value.to_tsl()])
}

///|
/// `color( ...params )`.
pub fn color_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("color", None, tsl_core_values(params))
}

///|
pub fn float(value : &IntoTsl) -> Node {
  tsl_core_convert_type("float", Some(_tsl_core_caches.floats), [value.to_tsl()])
}

///|
/// `float( ...params )`; `float_of([])` is `float()`.
pub fn float_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type(
    "float",
    Some(_tsl_core_caches.floats),
    tsl_core_values(params),
  )
}

///|
pub fn int(value : &IntoTsl) -> Node {
  tsl_core_convert_type("int", Some(_tsl_core_caches.ints), [value.to_tsl()])
}

///|
pub fn int_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type(
    "int",
    Some(_tsl_core_caches.ints),
    tsl_core_values(params),
  )
}

///|
pub fn uint(value : &IntoTsl) -> Node {
  tsl_core_convert_type("uint", Some(_tsl_core_caches.uints), [value.to_tsl()])
}

///|
pub fn uint_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type(
    "uint",
    Some(_tsl_core_caches.uints),
    tsl_core_values(params),
  )
}

///|
pub fn bool(value : &IntoTsl) -> Node {
  tsl_core_convert_type("bool", Some(_tsl_core_caches.bools), [value.to_tsl()])
}

///|
pub fn bool_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type(
    "bool",
    Some(_tsl_core_caches.bools),
    tsl_core_values(params),
  )
}

///|
pub fn vec2(value : &IntoTsl) -> Node {
  tsl_core_convert_type("vec2", None, [value.to_tsl()])
}

///|
/// `vec2( ...params )`: `vec2_of([x, y])`.
pub fn vec2_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("vec2", None, tsl_core_values(params))
}

///|
pub fn ivec2(value : &IntoTsl) -> Node {
  tsl_core_convert_type("ivec2", None, [value.to_tsl()])
}

///|
pub fn ivec2_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("ivec2", None, tsl_core_values(params))
}

///|
pub fn uvec2(value : &IntoTsl) -> Node {
  tsl_core_convert_type("uvec2", None, [value.to_tsl()])
}

///|
pub fn uvec2_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("uvec2", None, tsl_core_values(params))
}

///|
pub fn bvec2(value : &IntoTsl) -> Node {
  tsl_core_convert_type("bvec2", None, [value.to_tsl()])
}

///|
pub fn bvec2_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("bvec2", None, tsl_core_values(params))
}

///|
pub fn vec3(value : &IntoTsl) -> Node {
  tsl_core_convert_type("vec3", None, [value.to_tsl()])
}

///|
/// `vec3( ...params )`: `vec3_of([x, y, z])`, `vec3_of([xy, z])`.
pub fn vec3_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("vec3", None, tsl_core_values(params))
}

///|
pub fn ivec3(value : &IntoTsl) -> Node {
  tsl_core_convert_type("ivec3", None, [value.to_tsl()])
}

///|
pub fn ivec3_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("ivec3", None, tsl_core_values(params))
}

///|
pub fn uvec3(value : &IntoTsl) -> Node {
  tsl_core_convert_type("uvec3", None, [value.to_tsl()])
}

///|
pub fn uvec3_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("uvec3", None, tsl_core_values(params))
}

///|
pub fn bvec3(value : &IntoTsl) -> Node {
  tsl_core_convert_type("bvec3", None, [value.to_tsl()])
}

///|
pub fn bvec3_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("bvec3", None, tsl_core_values(params))
}

///|
pub fn vec4(value : &IntoTsl) -> Node {
  tsl_core_convert_type("vec4", None, [value.to_tsl()])
}

///|
/// `vec4( ...params )`: `vec4_of([rgb, 1])`.
pub fn vec4_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("vec4", None, tsl_core_values(params))
}

///|
pub fn ivec4(value : &IntoTsl) -> Node {
  tsl_core_convert_type("ivec4", None, [value.to_tsl()])
}

///|
pub fn ivec4_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("ivec4", None, tsl_core_values(params))
}

///|
pub fn uvec4(value : &IntoTsl) -> Node {
  tsl_core_convert_type("uvec4", None, [value.to_tsl()])
}

///|
pub fn uvec4_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("uvec4", None, tsl_core_values(params))
}

///|
pub fn bvec4(value : &IntoTsl) -> Node {
  tsl_core_convert_type("bvec4", None, [value.to_tsl()])
}

///|
pub fn bvec4_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("bvec4", None, tsl_core_values(params))
}

///|
pub fn mat2(value : &IntoTsl) -> Node {
  tsl_core_convert_type("mat2", None, [value.to_tsl()])
}

///|
pub fn mat2_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("mat2", None, tsl_core_values(params))
}

///|
pub fn mat3(value : &IntoTsl) -> Node {
  tsl_core_convert_type("mat3", None, [value.to_tsl()])
}

///|
/// `mat3( ...params )`: `mat3_of([c0, c1, c2])`.
pub fn mat3_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("mat3", None, tsl_core_values(params))
}

///|
pub fn mat4(value : &IntoTsl) -> Node {
  tsl_core_convert_type("mat4", None, [value.to_tsl()])
}

///|
pub fn mat4_of(params : Array[&IntoTsl]) -> Node {
  tsl_core_convert_type("mat4", None, tsl_core_values(params))
}

// ---------------------------------------------------------------------------
// Chained methods (`addMethodChaining`)

///|
/// `Node.prototype[ name ]` of `addMethodChaining( name, element )`: a stack adds
/// `element( ...params )`, any other node is `element( this, ...params )`.
fn Node::chain(
  self : Node,
  element : (Array[TslValue]) -> Node,
  params : Array[TslValue],
) -> Node {
  match StackNode::of(self) {
    Some(stack) => {
      stack.add_to_stack(element(params)) |> ignore
      self
    }
    None => element([Node(self), ..params])
  }
}

///|
/// `Stack( node )`: adds `node` to the current stack.
pub fn stack_(node : Node) -> Node {
  if current_stack.val is Some(stack) {
    stack.add_to_stack(node) |> ignore
  }
  node
}

///|
/// `Stack( node )`, chained as `toStack`.
pub fn Node::to_stack(self : Node) -> Node {
  match StackNode::of(self) {
    Some(_) => {
      // `this.addToStack( Stack() )`: both add `undefined`
      if current_stack.val is Some(_) {
        @core.error("TSL: Invalid node added to stack.")
      }
      @core.error("TSL: Invalid node added to stack.")
      self
    }
    None => stack_(self)
  }
}

///|
pub fn Node::to_color(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("color", None, p) }, [])
}

///|
pub fn Node::to_float(self : Node) -> Node {
  self.chain(
    fn(p) { tsl_core_convert_type("float", Some(_tsl_core_caches.floats), p) },
    [],
  )
}

///|
pub fn Node::to_int(self : Node) -> Node {
  self.chain(
    fn(p) { tsl_core_convert_type("int", Some(_tsl_core_caches.ints), p) },
    [],
  )
}

///|
pub fn Node::to_uint(self : Node) -> Node {
  self.chain(
    fn(p) { tsl_core_convert_type("uint", Some(_tsl_core_caches.uints), p) },
    [],
  )
}

///|
pub fn Node::to_bool(self : Node) -> Node {
  self.chain(
    fn(p) { tsl_core_convert_type("bool", Some(_tsl_core_caches.bools), p) },
    [],
  )
}

///|
pub fn Node::to_vec2(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("vec2", None, p) }, [])
}

///|
pub fn Node::to_ivec2(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("ivec2", None, p) }, [])
}

///|
pub fn Node::to_uvec2(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("uvec2", None, p) }, [])
}

///|
pub fn Node::to_bvec2(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("bvec2", None, p) }, [])
}

///|
pub fn Node::to_vec3(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("vec3", None, p) }, [])
}

///|
pub fn Node::to_ivec3(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("ivec3", None, p) }, [])
}

///|
pub fn Node::to_uvec3(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("uvec3", None, p) }, [])
}

///|
pub fn Node::to_bvec3(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("bvec3", None, p) }, [])
}

///|
pub fn Node::to_vec4(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("vec4", None, p) }, [])
}

///|
pub fn Node::to_ivec4(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("ivec4", None, p) }, [])
}

///|
pub fn Node::to_uvec4(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("uvec4", None, p) }, [])
}

///|
pub fn Node::to_bvec4(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("bvec4", None, p) }, [])
}

///|
pub fn Node::to_mat2(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("mat2", None, p) }, [])
}

///|
pub fn Node::to_mat3(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("mat3", None, p) }, [])
}

///|
pub fn Node::to_mat4(self : Node) -> Node {
  self.chain(fn(p) { tsl_core_convert_type("mat4", None, p) }, [])
}

///|
/// `element = nodeProxy( ArrayElementNode ).setParameterLength( 2 )`.
fn tsl_core_element(params : Array[TslValue]) -> Node {
  let params = if params.length() < 2 {
    @core.error(
      "TSL: \"ArrayElementNode\" parameter length is less than minimum required.",
    )
    let padded = params.copy()
    while padded.length() < 2 {
      padded.push(Number(0.0))
    }
    padded
  } else {
    params
  }
  ArrayElementNode::new(node_object(params[0]), node_object(params[1]))
}

///|
/// `element( node, indexNode )`: `node[ indexNode ]`.
pub fn element(node : &IntoTsl, index_node : &IntoTsl) -> Node {
  tsl_core_element([node.to_tsl(), index_node.to_tsl()])
}

///|
/// The chained `element( indexNode )`, or the class's own `element` (storage buffers,
/// uniform arrays, references).
pub fn Node::element(self : Node, index_node : &IntoTsl) -> Node {
  // converted once, as upstream's single `nodeObject` on either path
  let index = node_object(index_node.to_tsl())
  match self.class_.element(self, index) {
    Some(n) => n
    None => self.chain(tsl_core_element, [Node(index)])
  }
}

///|
/// `convert( node, types )`: a `ConvertNode`.
pub fn convert(node : &IntoTsl, types : String) -> Node {
  ConvertNode::new(node_object(node.to_tsl()), types)
}

///|
pub fn Node::convert(self : Node, types : String) -> Node {
  self.chain(
    fn(p) {
      match p {
        [node, String(types)] => ConvertNode::new(node_object(node), types)
        _ => abort("TSL: convert() needs a node and the types")
      }
    },
    [String(types)],
  )
}

///|
/// `split( node, channels )`: a `SplitNode`.
pub fn split(node : &IntoTsl, channels~ : String = "x") -> Node {
  SplitNode::new(node_object(node.to_tsl()), components=channels)
}

///|
/// `get( value )`: the struct member `value` (a `MemberNode`).
pub fn Node::get(self : Node, value : String) -> Node {
  MemberNode::new(self, value)
}

///|
/// `assign( value )`: adds `this = value` to the current stack. Returns `this`.
pub fn Node::assign_node(self : Node, value : &IntoTsl) -> Node {
  let value = value.to_tsl()
  if self.class_.assign(self, value) is Some(n) {
    return n
  }
  match StackNode::of(self) {
    None => {
      match current_stack.val {
        Some(stack) => tsl_core_stack_assign(stack, self, value)
        None =>
          @core.error(
            "TSL: No stack defined for assign operation. Make sure the assign is inside a Fn().",
          )
      }
      self
    }
    Some(stack) => {
      // `this.addToStack( assign( value ) )`: one parameter of two
      @core.error(
        "TSL: \"AssignNode\" parameter length is less than minimum required.",
      )
      stack.add_to_stack(assign(value, 0)) |> ignore
      self
    }
  }
}

///|
/// `assign( value )` as a statement.
pub fn Node::assign(self : Node, value : &IntoTsl) -> Unit {
  self.assign_node(value) |> ignore
}

///|
/// `stack.assign( target, value )`: `stack.addToStack( assign( target, value ) )`.
fn tsl_core_stack_assign(
  stack : StackNode,
  target : Node,
  value : TslValue,
) -> Unit {
  stack.add_to_stack(assign(target, value)) |> ignore
}

///|
/// `call( ...params )`: a `Fn` call, or the chained `call` of FunctionCallNode for other
/// nodes (a `FunctionNode` called with its parameters).
pub fn Node::call(self : Node, params : Array[&IntoTsl]) -> Node {
  let values = tsl_core_values(params)
  match self.class_.call(self, values) {
    Some(n) => n
    None =>
      match StackNode::of(self) {
        Some(stack) => {
          let func = if values.length() > 0 { values[0] } else { Undefined }
          let rest = if values.length() > 0 {
            values[1:].to_owned()
          } else {
            []
          }
          stack.add_to_stack(function_call(func, rest)) |> ignore
          self
        }
        None => function_call(self, values)
      }
  }
}

///|
/// `f( { a, b } )`: a call with one plain-object argument.
pub fn Node::call_named(self : Node, params : Map[String, &IntoTsl]) -> Node {
  let object : Map[String, TslValue] = Map([])
  for name, value in params {
    object[name] = value.to_tsl()
  }
  self.call([TslValue::Object(object)])
}

///|
/// `defined( value )`: the truthiness of a value, or of the last constant in a node.
pub fn defined(value : TslValue) -> Bool {
  let mut value = value
  if value is Node(node) {
    node.traverse(fn(n) {
      if ConstNode::of(n) is Some(c) {
        value = c.input.value
      }
    })
  }
  tsl_truthy(value)
}

///|
/// `getConstNodeType( value )`: `value.nodeType || value.convertTo`, or a type name.
pub fn get_const_node_type(value : TslValue) -> String? {
  match value {
    Undefined | Null => None
    Node(n) =>
      match n.node_type {
        Some(t) if t != "" => Some(t)
        _ =>
          match ConvertNode::of(n) {
            Some(c) if c.convert_to != "" => Some(c.convert_to)
            _ => None
          }
      }
    String(s) => Some(s)
    _ => None
  }
}

// ---------------------------------------------------------------------------
// If, Switch

///|
fn tsl_core_require_stack(name : String) -> StackNode {
  match current_stack.val {
    Some(stack) => stack
    None =>
      abort(
        "TSL: \{name}() needs a current stack (Cannot read properties of null)",
      )
  }
}

///|
/// `If( boolNode, method )`, chained with `.else_if( ... )` and `.else_( ... )`.
pub fn if_(bool_node : &IntoTsl, body : () -> Unit) -> StackNode {
  tsl_core_require_stack("If").if_(bool_node, body)
}

///|
/// `If( boolNode, method )` whose body returns a node (the branch output).
pub fn if_value(bool_node : &IntoTsl, body : () -> Node) -> StackNode {
  tsl_core_require_stack("If").if_value(bool_node, body)
}

///|
/// `Switch( expression )`, chained with `.case_( ... )` and `.default( ... )`.
pub fn switch_(expression : &IntoTsl) -> StackNode {
  tsl_core_require_stack("Switch").switch_(expression)
}

// ---------------------------------------------------------------------------
// Swizzles and `n[ i ]`

///|
/// `_swizzleCache`: the `SplitNode`s and `ArrayElementNode`s made for each node.
let _tsl_core_swizzle_cache : @webgl.WeakMap[Node, Map[String, Node]] = @webgl.WeakMap::new()

///|
fn tsl_core_get_swizzle_cache(node : Node) -> Map[String, Node] {
  match _tsl_core_swizzle_cache.get(node) {
    Some(cache) => cache
    None => {
      let cache = Map([])
      _tsl_core_swizzle_cache.set(node, cache)
      cache
    }
  }
}

///|
/// `parseSwizzle( props )`: `rgba` and `stpq` to `xyzw`.
pub fn parse_swizzle(props : String) -> String {
  let out = StringBuilder()
  for c in props {
    out.write_char(
      match c {
        'r' | 's' => 'x'
        'g' | 't' => 'y'
        'b' | 'p' => 'z'
        'a' | 'q' => 'w'
        c => c
      },
    )
  }
  out.to_string()
}

///|
/// `parseSwizzleAndSort( props )`: `parseSwizzle`, then the characters sorted.
pub fn parse_swizzle_and_sort(props : String) -> String {
  let chars = parse_swizzle(props).to_array()
  chars.sort()
  String::from_array(chars)
}

///|
/// The swizzle getter `node[ property ]` (`property` in `xyzw` form): a cached
/// `SplitNode`.
pub fn Node::swizzle(self : Node, property : String) -> Node {
  let cache = tsl_core_get_swizzle_cache(self)
  match cache.get(property) {
    Some(split) => split
    None => {
      let split = SplitNode::new(self, components=property)
      cache[property] = split
      split
    }
  }
}

///|
/// `node[ 'set' + PROPERTY ]( value )`: a `SetNode` replacing the components.
pub fn Node::set_swizzle(
  self : Node,
  property : String,
  value : &IntoTsl,
) -> Node {
  let swizzle = parse_swizzle_and_sort(property)
  SetNode::new(self, swizzle, node_object(value.to_tsl()))
}

///|
/// `node[ 'flip' + PROPERTY ]()`: a `FlipNode` computing `1 - c` for the components.
pub fn Node::flip_swizzle(self : Node, property : String) -> Node {
  let swizzle = parse_swizzle_and_sort(property)
  FlipNode::new(self, swizzle)
}

///|
/// `node[ i ]` for `0 <= i < 32`: a cached `ArrayElementNode` with a `uint` index.
#alias("_[_]")
pub fn Node::at(self : Node, i : Int32) -> Node {
  if i < 0 || i >= 32 {
    abort("TSL: node[ \{i} ] is undefined (indices 0 to 31 are defined)")
  }
  let cache = tsl_core_get_swizzle_cache(self)
  let key = i.to_string()
  match cache.get(key) {
    Some(element) => element
    None => {
      let element = ArrayElementNode::new(
        self,
        ConstNode::new(Number(i.to_double()), node_type="uint"),
      )
      cache[key] = element
      element
    }
  }
}

///|
/// `node[ i ] = value`: `node[ i ].assign( nodeObject( value ) )`.
#alias("_[_]=_")
pub fn Node::set_at(self : Node, i : Int32, value : &IntoTsl) -> Unit {
  self.at(i).assign(node_object(value.to_tsl()))
}

// ---------------------------------------------------------------------------
// Fn

///|
/// One input of a function layout: `{ name, type, qualifier, count }`.
pub(all) struct FnLayoutInput {
  name : String
  type_ : String
  qualifier : String?
  count : Int32?
}

///|
/// `Fn` layouts: `{ name, type, inputs }`.
pub(all) struct FnLayout {
  mut name : String
  mut type_ : String?
  inputs : Array[FnLayoutInput]
}

///|
/// The short layout form of `Fn( f, { a: 'float', return: 'vec3' } )` (named
/// `'fn' + fnId++` by `FnNode.setLayout`), or a return type (`Fn( f, 'vec3' )`).
/// `Library(key, ..)` is a short layout of an upstream library `Fn`, named from
/// tsl_fn_layout_names.mbt (generated by tools/gen_fn_layout_names.mjs).
pub(all) enum FnLayoutArg {
  Full(FnLayout)
  Short(Array[(String, String)], String?)
  ReturnType(String)
  Library(String, Array[(String, String)], String?)
}

///|
/// `{ a: 'float', b: 'vec2', return: 'vec3' }`, for `fn_(f, layout=...)`. Library
/// functions pass `upstream="<path below src>:<const name>"` so they get upstream's
/// `fn<id>` name whatever MoonBit's initialization order.
pub fn FnLayout::short(
  inputs : Array[(String, String)],
  return_? : String,
  upstream? : String,
) -> FnLayoutArg {
  match upstream {
    Some(key) => Library(key, inputs, return_)
    None => Short(inputs, return_)
  }
}

///|
/// `{ name, type, inputs: [ { name, type } ] }`.
pub fn FnLayout::full(
  name~ : String,
  type_? : String,
  inputs~ : Array[(String, String)],
) -> FnLayout {
  {
    name,
    type_,
    inputs: inputs.map(fn(i) {
      { name: i.0, type_: i.1, qualifier: None, count: None, }
    }),
  }
}

///|
/// `fnId`, the counter naming short-form layouts. Upstream's library functions take
/// the first `TSL_FN_FIRST_USER_ID` names while it loads (tsl_fn_layout_names.mbt).
let _tsl_core_fn_id : Ref[Int32] = Ref(TSL_FN_FIRST_USER_ID)

///|
/// `ShaderNodeInternal`: a TSL function body as a node.
pub(all) struct ShaderNodeInternal {
  js_func : ShaderFn
  mut layout : FnLayout?
  mut once : Bool
  /// `subBuilds` passed to `once( subBuilds )`; `None` is `null`.
  mut sub_builds : Array[String]?
}

///|
pub impl NodeClass for ShaderNodeInternal with fn class_name(_) {
  "ShaderNodeInternal"
}

///|
pub impl NodeClass for ShaderNodeInternal with fn type_name(_) {
  "Node"
}

///|
pub impl NodeClass for ShaderNodeInternal with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for ShaderNodeInternal with fn setup(_, node, _) {
  Some(ShaderNodeInternal::call_inputs(node))
}

///|
/// `shaderNode.call( rawInputs )` reached through `Node::call`.
pub impl NodeClass for ShaderNodeInternal with fn call(_, node, params) {
  match params {
    [Array(raw), ..] =>
      Some(ShaderNodeInternal::call_inputs(node, raw_inputs=raw))
    [Object(inputs), ..] =>
      Some(ShaderNodeInternal::call_layout_inputs(node, inputs))
    _ => Some(ShaderNodeInternal::call_inputs(node))
  }
}

///|
pub fn ShaderNodeInternal::of(node : Node) -> ShaderNodeInternal? {
  match node.class_payload("ShaderNodeInternal") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `new ShaderNodeInternal( jsFunc, nodeType )`.
pub fn ShaderNodeInternal::new(js_func : ShaderFn, node_type? : String) -> Node {
  let node = Node::alloc(node_type?)
  node.global = true
  node.set_class(ShaderNodeInternal::{
    js_func,
    layout: None,
    once: false,
    sub_builds: None,
  })
}

///|
/// `ShaderNode( jsFunc, nodeType )` (`new ShaderNodeInternal( jsFunc, nodeType )`).
pub fn shader_node(js_func : ShaderFn, node_type? : String) -> Node {
  ShaderNodeInternal::new(js_func, node_type?)
}

///|
/// `setLayout( layout )`.
pub fn ShaderNodeInternal::set_layout(node : Node, layout : FnLayout?) -> Node {
  ShaderNodeInternal::of(node).unwrap().layout = layout
  node
}

///|
/// `getLayout()`.
pub fn ShaderNodeInternal::get_layout(node : Node) -> FnLayout? {
  ShaderNodeInternal::of(node).unwrap().layout
}

///|
/// `call( rawInputs = null )`: a `ShaderCallNodeInternal`.
pub fn ShaderNodeInternal::call_inputs(
  node : Node,
  raw_inputs? : Array[TslValue],
) -> Node {
  ShaderCallNodeInternal::new(node, raw_inputs)
}

///|
/// `call( inputs )` with the inputs object of NodeBuilder's `_createLayoutInputs`:
/// named members (in layout order) that array destructuring reads in order.
pub fn ShaderNodeInternal::call_layout_inputs(
  node : Node,
  inputs : Map[String, TslValue],
) -> Node {
  ShaderCallNodeInternal::new(node, Some([Object(inputs)]), layout_inputs=true)
}

///|
/// `ShaderCallNodeInternal`: one call of a `ShaderNodeInternal`.
pub(all) struct ShaderCallNodeInternal {
  /// The `ShaderNodeInternal` node.
  shader_node : Node
  /// `rawInputs`; `None` is `null`.
  raw_inputs : Array[TslValue]?
  /// Whether `raw_inputs` is `[ inputs ]` for an `_createLayoutInputs` object
  /// (upstream passes the object itself as `rawInputs`).
  layout_inputs : Bool
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn class_name(_) {
  "ShaderCallNodeInternal"
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn type_name(_) {
  "Node"
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn has_flag(_, flag) {
  flag == "isShaderCallNodeInternal"
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn children(self, _, out) {
  push_child(out, "shaderNode", Some(self.shader_node))
  match self.raw_inputs {
    Some([Object(inputs)]) if self.layout_inputs =>
      for key, value in inputs {
        if !key.has_prefix("_") && value is Node(child_node) {
          out.push({ property: "rawInputs", index: Some(Key(key)), child_node, })
        }
      }
    Some(raw) =>
      for i, value in raw {
        if value is Node(child_node) {
          out.push({ property: "rawInputs", index: Some(Index(i)), child_node, })
        }
      }
    None => ()
  }
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn is_cacheable(
  self,
  node,
  builder,
) {
  // A call is an expression unless its body has statements.
  self.output_stack(node, builder).nodes.length() == 0
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn generate_node_type(
  self,
  node,
  builder,
  _,
) {
  match self.shader_node.node_type {
    Some(t) if t != "" => Some(t)
    _ => self.get_output_node(node, builder).get_node_type(builder)
  }
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn get_element_type(
  self,
  node,
  builder,
) {
  self.get_output_node(node, builder).get_element_type(builder)
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn get_member_type(
  self,
  node,
  builder,
  name,
) {
  self.get_output_node(node, builder).get_member_type(builder, name)
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn generate(
  self,
  node,
  builder,
  output,
) {
  match
    self
    .get_output_node(node, builder)
    .build_output(builder, BuildOutput::of_type(output)) {
    Snippet(s) => Some(s)
    _ => Some("")
  }
}

///|
pub impl NodeClass for ShaderCallNodeInternal with fn build(
  self,
  node,
  builder,
  output,
) {
  // The call does not use Node.build(), so it handles the inspector node, shared and
  // overridden nodes and assignable state here.
  node._setup_inspector(builder)
  let ref_node = node.get_shared(builder)
  if !physical_equal(node, ref_node) {
    return ref_node.build_output(builder, output)
  }
  let mut result : BuildResult = Null
  let build_stage = builder.get_build_stage()
  let properties = builder.get_node_properties(node)
  let node_data = if node.assignable {
    Some(builder.get_data_from_node(node))
  } else {
    None
  }
  if node_data is Some(data) {
    node._update_assignable(builder, data)
  }
  let sub_build_output = builder.get_sub_build_output(node)
  let output_node = self.get_output_node(node, builder)
  let previous_fn_call = builder.fn_call
  builder.fn_call = Some(node)
  if build_stage == Some("setup") {
    let sub_build_initialized = builder.get_sub_build_property(
      property="initialized",
      node~,
    )
    if properties.get_bool(sub_build_initialized) != Some(true) {
      properties.set_bool(sub_build_initialized, true)
      let out = self.get_output_node(node, builder)
      properties.set_node(sub_build_output, out)
      out.build_output(builder, NoOutput) |> ignore
      // If the shaderNode has subBuilds, add them to the chaining nodes
      // so they can be built later in the build process.
      let shader = ShaderNodeInternal::of(self.shader_node).unwrap()
      if shader.sub_builds is Some(sub_builds) {
        for chained in builder.chaining {
          let data = builder.get_data_from_node(chained, shader_stage="any")
          let set = match data.sub_builds {
            Some(s) => s
            None => {
              let s = []
              data.sub_builds = Some(s)
              s
            }
          }
          for sub_build in sub_builds {
            if !set.contains(sub_build) {
              set.push(sub_build)
            }
          }
        }
      }
    }
    result = match properties.get_node(sub_build_output) {
      Some(n) => NodeResult(n)
      None => Null
    }
  } else if build_stage == Some("analyze") {
    // A variable is evaluated once, so its value is analyzed only once.
    let analyze = match node_data {
      None => true
      Some(data) =>
        !node._is_variable(builder, data) || builder.increase_usage(node) == 1
    }
    if analyze {
      output_node.build_output(builder, output) |> ignore
    }
  } else if build_stage == Some("generate") {
    match node_data {
      Some(data) if node._is_variable(builder, data) => {
        node._check_flow_block(builder, data)
        let is_cached = data.property_name is Some(_)
        let flow_code_length = builder.flow.code.length()
        result = Snippet(node._build_variable(builder, data, output.type_()))
        node._set_flow_block(builder, data, is_cached, flow_code_length)
      }
      _ =>
        result = Snippet(
          match output_node.build_output(builder, output) {
            Snippet(s) => s
            _ => ""
          },
        )
    }
  }
  builder.fn_call = previous_fn_call
  result
}

///|
/// `new ShaderCallNodeInternal( shaderNode, rawInputs )`.
pub fn ShaderCallNodeInternal::new(
  shader_node : Node,
  raw_inputs : Array[TslValue]?,
  layout_inputs~ : Bool = false,
) -> Node {
  let node = Node::alloc()
  node.set_class(ShaderCallNodeInternal::{
    shader_node,
    raw_inputs,
    layout_inputs,
  })
}

///|
pub fn ShaderCallNodeInternal::of(node : Node) -> ShaderCallNodeInternal? {
  match node.class_payload("ShaderCallNodeInternal") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `call( builder )`: runs the function body (or calls the layout function) once per
/// sub-build when `once`; the result node, `None` for `undefined`.
pub fn ShaderCallNodeInternal::call_body(
  node : Node,
  builder : NodeBuilder,
) -> Node? {
  let self = ShaderCallNodeInternal::of(node).unwrap()
  let shader_node = self.shader_node
  let shader = ShaderNodeInternal::of(shader_node).unwrap()
  let properties = builder.get_node_properties(shader_node)
  let sub_build = builder
    .get_closest_sub_build_of(shader.sub_builds)
    .unwrap_or("")
  let sub_build_property = if sub_build == "" { "default" } else { sub_build }
  if properties.get_node(sub_build_property) is Some(cached) {
    return Some(cached)
  }
  let previous_sub_build_fn = builder.sub_build_fn
  let previous_fn_call = builder.fn_call
  builder.sub_build_fn = Some(sub_build)
  builder.fn_call = Some(node)
  let mut result : Node? = None
  // A layout call needs every input. Missing inputs are completed with the default values
  // of the function parameters; if they can't be resolved, the function is expanded inline.
  let layout_inputs = match shader.layout {
    Some(_) => builder._get_layout_inputs(shader_node, self.raw_inputs)
    None => None
  }
  match (layout_inputs, shader.layout) {
    (Some(layout_inputs), Some(layout)) => {
      // build inputs first, use layout inputs to ensure that no extra parameters are built
      let layout_parameters = layout.inputs
      if is_array_as_parameter(layout_inputs) {
        for i in 0..<layout_parameters.length() {
          if i < layout_inputs.length() &&
            layout_inputs[i] is Node(raw_parameter) {
            raw_parameter.build(builder) |> ignore
          }
        }
      } else {
        match layout_inputs {
          [Object(raw_object_parameters), ..] =>
            for param in layout_parameters {
              if raw_object_parameters.get(param.name)
                is Some(Node(raw_parameter)) {
                raw_parameter.build(builder) |> ignore
              }
            }
          _ =>
            if layout_parameters.length() > 0 {
              abort(
                "TSL: Cannot read properties of undefined (reading '\{layout_parameters[0].name}')",
              )
            }
        }
      }
      let function_node = builder.build_function_node(shader_node)
      builder.add_include(function_node)
      let inputs = tsl_core_get_layout_parameters(layout_inputs)
      result = Some(function_node.call([inputs]))
    }
    _ => {
      let inputs = match self.raw_inputs {
        Some(raw) => tsl_core_get_proxy_parameters(raw, self.layout_inputs)
        None => FnInputs::new([])
      }
      // `hasParameters || jsFunc.length > 1` only decides whether JS passes the
      // builder first or second; the MoonBit body always gets both.
      let output_node = (shader.js_func.f)(inputs, builder)
      result = output_node
    }
  }
  builder.sub_build_fn = previous_sub_build_fn
  builder.fn_call = previous_fn_call
  if shader.once {
    properties.set_node_or_null(sub_build_property, result)
  }
  result
}

///|
/// `setupOutput( builder )`: the stack the body runs in, with the result as output.
pub fn ShaderCallNodeInternal::setup_output(
  _self : ShaderCallNodeInternal,
  node : Node,
  builder : NodeBuilder,
) -> Node {
  builder.add_stack() |> ignore
  builder.stack.output_node = ShaderCallNodeInternal::call_body(node, builder)
  builder.remove_stack().node
}

///|
/// `getOutputNode( builder )`: the stack of this call in the current sub-build.
pub fn ShaderCallNodeInternal::get_output_node(
  self : ShaderCallNodeInternal,
  node : Node,
  builder : NodeBuilder,
) -> Node {
  let properties = builder.get_node_properties(node)
  let sub_build_output = builder.get_sub_build_output(node)
  let output = match properties.get_node(sub_build_output) {
    Some(n) => n
    None => self.setup_output(node, builder)
  }
  properties.set_node(sub_build_output, output)
  StackNode::of(output)
  .unwrap()
  .set_sub_build(builder.get_closest_sub_build(node))
  output
}

///|
fn ShaderCallNodeInternal::output_stack(
  self : ShaderCallNodeInternal,
  node : Node,
  builder : NodeBuilder,
) -> StackNode {
  StackNode::of(self.get_output_node(node, builder)).unwrap()
}

///|
/// `getLayoutParameters( params )`: the inputs of a layout call, an array or the
/// object of a named call.
fn tsl_core_get_layout_parameters(params : Array[TslValue]) -> TslValue {
  node_array(params) |> ignore
  if is_array_as_parameter(params) {
    Array(params.copy())
  } else if params.length() > 0 {
    params[0]
  } else {
    Undefined
  }
}

///|
/// `getProxyParameters( params )`: converts the arguments in place and wraps them.
fn tsl_core_get_proxy_parameters(
  params : Array[TslValue],
  layout_inputs : Bool,
) -> FnInputs {
  match params {
    [Object(inputs)] if layout_inputs => node_objects(inputs) |> ignore
    _ => node_array(params) |> ignore
  }
  FnInputs::new(params)
}

///|
/// `FnNode`, what `Fn( jsFunc, layout )` returns.
pub(all) struct FnNode {
  /// The `ShaderNodeInternal` node.
  shader_node : Node
}

///|
pub impl NodeClass for FnNode with fn class_name(_) {
  "FnNode"
}

///|
pub impl NodeClass for FnNode with fn type_name(_) {
  "Node"
}

///|
pub impl NodeClass for FnNode with fn has_flag(_, flag) {
  flag == "isFn"
}

///|
pub impl NodeClass for FnNode with fn children(self, _, out) {
  push_child(out, "shaderNode", Some(self.shader_node))
}

///|
pub impl NodeClass for FnNode with fn generate_uses_output(_) {
  false
}

///|
pub impl NodeClass for FnNode with fn is_cacheable(_, _, _) {
  false
}

///|
pub impl NodeClass for FnNode with fn generate_node_type(self, _, builder, _) {
  match self.shader_node.get_node_type(builder) {
    Some(t) if t != "" => Some(t)
    _ => Some("float")
  }
}

///|
pub impl NodeClass for FnNode with fn call(self, _, params) {
  Some(self.call_params(params))
}

///|
pub impl NodeClass for FnNode with fn generate(_, node, builder, _) {
  let type_ = node.get_node_type(builder)
  @core.error(
    "TSL: \"Fn()\" was declared but not invoked. Try calling it like \"Fn()( ...params )\".",
  )
  Some(builder.generate_const(type_.unwrap_or("float")))
}

///|
pub fn FnNode::of(node : Node) -> FnNode? {
  match node.class_payload("FnNode") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `new FnNode( jsFunc, layout = null )`.
pub fn FnNode::new(js_func : ShaderFn, layout? : FnLayoutArg) -> Node {
  let node = Node::alloc()
  let mut layout = layout
  let node_type = match layout {
    // `layout.return`
    Some(Full(_)) => None
    Some(Short(_, return_)) | Some(Library(_, _, return_)) => return_
    Some(ReturnType(t)) => {
      layout = None
      Some(t)
    }
    None => None
  }
  let fn_node = FnNode::{ shader_node: shader_node(js_func, node_type?), }
  node.set_class(fn_node) |> ignore
  if layout is Some(layout) {
    fn_node.set_layout(layout)
  }
  node
}

///|
/// `setLayout( layout )`: a short layout gets the name `'fn' + fnId++`.
pub fn FnNode::set_layout(self : FnNode, layout : FnLayoutArg) -> Unit {
  let node_type = self.shader_node.node_type
  let layout = match layout {
    Full(layout) => layout
    Short(inputs, _) | Library(_, inputs, _) => {
      let name = match layout {
        Library(key, _, _) =>
          match tsl_fn_library_id(key) {
            Some(id) => {
              tsl_fn_library_created[key] = tsl_fn_library_created
                .get(key)
                .unwrap_or(0) +
                1
              "fn" + id.to_string()
            }
            None =>
              abort(
                "TSL: \{key} is not an upstream library Fn (tools/gen_fn_layout_names.mjs)",
              )
          }
        _ => {
          let name = "fn" + _tsl_core_fn_id.val.to_string()
          _tsl_core_fn_id.val += 1
          name
        }
      }
      let full_layout = FnLayout::{ name, type_: node_type, inputs: [], }
      for input in inputs {
        if input.0 == "return" {
          continue
        }
        full_layout.inputs.push({
          name: input.0,
          type_: input.1,
          qualifier: None,
          count: None,
        })
      }
      full_layout
    }
    ReturnType(t) => abort("TSL: setLayout( '\{t}' ) needs a layout object")
  }
  ShaderNodeInternal::set_layout(self.shader_node, Some(layout)) |> ignore
}

///|
/// `call( ...params )`: a statement for `void` functions, else an assignable call.
pub fn FnNode::call_params(self : FnNode, params : Array[TslValue]) -> Node {
  let fn_call = ShaderNodeInternal::call_inputs(
    self.shader_node,
    raw_inputs=params,
  )
  // A call without a return value is a statement.
  if self.shader_node.node_type == Some("void") {
    return fn_call.to_stack()
  }
  fn_call.to_assignable()
}

///|
/// `Fn( jsFunc, layout = null )`. The body gets the call inputs and the builder.
pub fn fn_(
  js_func : (FnInputs, NodeBuilder) -> Node?,
  layout? : FnLayoutArg,
) -> Node {
  FnNode::new({ f: js_func, }, layout?)
}

///|
fn tsl_core_fn_node(node : Node, name : String) -> FnNode {
  match FnNode::of(node) {
    Some(f) => f
    None => abort("TypeError: \{node.type_()}.\{name} is not a function")
  }
}

///|
/// `fn.setLayout( { name, type, inputs } )` on a `Fn`.
pub fn Node::set_layout(
  self : Node,
  name~ : String,
  type_? : String,
  inputs~ : Array[(String, String)],
) -> Node {
  tsl_core_fn_node(self, "setLayout").set_layout(
    Full(FnLayout::full(name~, type_?, inputs~)),
  )
  self
}

///|
/// `fn.setLayout( layout )` with a full or short layout.
pub fn Node::set_fn_layout(self : Node, layout : FnLayoutArg) -> Node {
  tsl_core_fn_node(self, "setLayout").set_layout(layout)
  self
}

///|
/// `fn.once( subBuilds = null )`: the body runs once per build (and sub-build).
pub fn Node::once(self : Node, sub_builds? : Array[String]) -> Node {
  let f = tsl_core_fn_node(self, "once")
  let shader = ShaderNodeInternal::of(f.shader_node).unwrap()
  shader.once = true
  shader.sub_builds = sub_builds
  self
}
