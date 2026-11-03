// Shared support for the TSL add-ons (examples/jsm/tsl/**) in this package. Used by both
// TSL add-on agents (A4: half of tsl/display; A5: the other half, lighting, math, shadows,
// utils). Two conventions:
//
// 1. Node classes outside src/nodes. A class is a payload struct implementing
//    `@nodes.NodeClass` (the trait is `pub(open)`), exactly as src/nodes builds its own:
//    - `X::construct(node, ...) -> X` is the constructor body after `super()`; a subclass
//      of `Node` sets base fields on `node` (`node.update_before_type = ...`), a subclass of
//      another class calls its `construct` first and embeds the returned payload
//      (`StereoCompositePassNode { pass : @nodes.PassNode, ... }`, `parent()` returns it).
//    - `X::new(...)` is `let node = @nodes.Node::alloc(node_type=...)` (the id is taken
//      before the constructor creates child nodes, as `super()` does upstream), then
//      `node.set_class(X::construct(node, ...))`.
//    - `X::of(node)` is `addon_class_of(node, "X")`; `class_name` returns upstream's class
//      name and `type_name` its `static get type()`.
//    - `children` lists node-valued own properties in JS order (`@nodes.push_child`),
//      skipping `_`-prefixed ones, after the parent's.
//    - Overridden methods take the `Node`; `super.m( ... )` is `node.m_base(...)` for
//      direct subclasses of `Node` (e.g. `node.dispose_base()`), `self.parent_payload.m(node,
//      ...)` otherwise. Families with their own virtual methods use src/nodes' traits
//      (`@nodes.PassNodeClass`, `@nodes.AnalyticLightNodeClass`, `@nodes.ShadowNodeClass`,
//      ...): store `mut class_ : &Trait` and set it to the most derived payload.
//    - Upstream's deprecated `TempNode` base is not used (r187's add-ons extend `Node`).
//    - Ad-hoc properties set on materials (`material.colorTexture = colorTexture`) live in
//      the owning payload instead.
//
// 2. Module-level state. MoonBit initializes top-level lets in its own order (and drops
//    those a program does not read), so add-on module-level nodes, `Fn`s with short layouts
//    (whose `fn<id>` names count on from the library's 130) and module-level objects
//    (`_quadMesh`, which takes Object3D / Material / BufferGeometry ids) are built lazily:
//    - each file keeps them in a private record inside an `AddonModule[T]`, whose
//      initializer first loads the add-on modules the file imports (upstream's import
//      order), then creates the nodes in upstream statement order;
//    - exported module-level nodes become accessors (`pub fn d_gtr() -> Node`), and every
//      public entry point goes through the module;
//    - `pub fn load_<file>()` (e.g. `load_utils_specular_helpers()`) evaluates the module,
//      as an ES `import` does: harnesses and apps call these to mirror upstream's import
//      order, since upstream evaluates imported add-on modules before user code.
//    The initializer must not use string constants at load time (no work happens at load:
//    `AddonModule::new` only stores the closure).

///|
/// An add-on ES module's top-level state, evaluated once on first use (`get`).
pub struct AddonModule[T] {
  priv init : () -> T
  priv mut value : T?
}

///|
/// A module whose top-level statements are `init` (not run until `get`).
pub fn[T] AddonModule::new(init : () -> T) -> AddonModule[T] {
  { init, value: None, }
}

///|
/// The module's state, evaluating the module on first use.
pub fn[T] AddonModule::get(self : AddonModule[T]) -> T {
  match self.value {
    Some(v) => v
    None => {
      let v = (self.init)()
      self.value = Some(v)
      v
    }
  }
}

///|
/// Whether the module has been evaluated.
pub fn[T] AddonModule::is_loaded(self : AddonModule[T]) -> Bool {
  self.value is Some(_)
}

///|
/// The class payload `name` of `node`'s class chain, cast to `T` (`X::of`).
pub fn[T] addon_class_of(node : @nodes.Node, name : String) -> T? {
  match node.class_payload(name) {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
/// `x.isNode ? x : uniform( x )`, the constructor idiom of the display nodes.
pub fn addon_node_or_uniform(value : &@nodes.IntoTsl) -> @nodes.Node {
  match value.to_tsl() {
    Node(n) => n
    v => @nodes.uniform(v)
  }
}

///|
/// `nodeObject( value )` on a TSL value.
pub fn addon_node_object(value : &@nodes.IntoTsl) -> @nodes.Node {
  @nodes.node_object(value.to_tsl())
}

///|
/// A JS object argument (`{ a: x, b: y }`) for add-on functions taking options.
pub fn addon_options(
  entries : Array[(String, &@nodes.IntoTsl)],
) -> @nodes.TslValue {
  Object(Map::from_array(entries.map(fn(e) { (e.0, e.1.to_tsl()) })))
}

///|
/// `options.<key>` of a JS object argument; `Undefined` when absent or not an object.
pub fn addon_option(options : @nodes.TslValue, key : String) -> @nodes.TslValue {
  match options {
    Object(m) => m.get(key).unwrap_or(Undefined)
    _ => Undefined
  }
}

///|
/// JS truthiness of a TSL value (`x || y` on options).
pub fn addon_truthy(v : @nodes.TslValue) -> Bool {
  match v {
    Undefined | Null => false
    Bool(b) => b
    Number(n) => !(n == 0.0 || n.is_nan())
    String(s) => s != ""
    _ => true
  }
}

///|
/// JS `Math.PI`.
pub const ADDON_PI : Double = 3.141592653589793

///|
/// A short layout (`{ a: 'float', return: 'vec3' }`): named `fn<id>` from the counter.
pub fn addon_short_layout(
  inputs : Array[(String, String)],
  return_ : String,
) -> @nodes.FnLayoutArg {
  @nodes.FnLayout::short(inputs, return_~)
}

///|
/// The `i`-th destructured `Fn` parameter, which must be given.
pub fn addon_arg(inputs : @nodes.FnInputs, i : Int32) -> @nodes.Node {
  inputs.get(i).unwrap()
}

///|
/// The `i`-th `Fn` parameter as the `Object3D` it is (a camera passed through a call).
pub fn addon_object3d_arg(
  inputs : @nodes.FnInputs,
  i : Int32,
) -> @core.Object3D {
  match inputs.value(i) {
    Js(v) => v.cast()
    _ => abort("TSL add-on: parameter \{i} is not an Object3D")
  }
}

///|
/// JS `a ** b` (as upstream's constant folding computes it).
pub extern "js" fn addon_js_pow(a : Double, b : Double) -> Double =
  #|(a, b) => a ** b

///|
/// `textureNode.uvNode`: `None` when the node is not a texture node or it is `null`.
pub fn addon_texture_uv_node(node : @nodes.Node) -> @nodes.Node? {
  match @nodes.TextureNode::of(node) {
    Some(t) => t.uv_node
    None => None
  }
}
