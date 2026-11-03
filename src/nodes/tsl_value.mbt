// The JS values TSL accepts where upstream takes "a node or anything `nodeObject`
// converts": numbers, booleans, vectors, colors, matrices, plain functions, arrays.
// TSL functions take `&IntoTsl`, so `vec3( 1, x, 0.5 )` reads the same in MoonBit:
// `vec3(1, x, 0.5)` coerces `Int`, `Node` and `Double` to the trait object.
// Part of the foundation (see the WebGPU and TSL section of PORTING.md).

///|
/// A plain JS function used as a TSL function body: `( inputs, builder ) => node`.
/// `nodeObject` wraps it with `Fn`.
pub(all) struct ShaderFn {
  f : (FnInputs, NodeBuilder) -> Node?
}

///|
/// Any value a TSL function or `InputNode.value` can hold.
pub(all) enum TslValue {
  Undefined
  Null
  Node(Node)
  /// A JS number. `Int` arguments become numbers too, as in JS: `int( 1 )` is the
  /// way to get an integer constant, exactly as upstream.
  Number(Double)
  Bool(Bool)
  String(String)
  Vector2(@math.Vector2)
  Vector3(@math.Vector3)
  Vector4(@math.Vector4)
  Color(@math.Color)
  Matrix2(@math.Matrix2)
  Matrix3(@math.Matrix3)
  Matrix4(@math.Matrix4)
  Texture(@core.Texture)
  Array(Array[TslValue])
  /// A plain object, `{ a: x, b: y }`, in key insertion order.
  Object(Map[String, TslValue])
  /// A plain JS function (`getValueType` 'shader').
  Shader(ShaderFn)
  /// Anything else (typed arrays, `ArrayBuffer`, objects TSL only passes along).
  Js(@core.JsValue)
}

///|
/// Converts a MoonBit value to the JS value TSL sees.
pub(open) trait IntoTsl {
  fn to_tsl(Self) -> TslValue
}

///|
pub impl IntoTsl for TslValue with fn to_tsl(self) {
  self
}

///|
pub impl IntoTsl for Node with fn to_tsl(self) {
  Node(self)
}

///|
pub impl IntoTsl for Double with fn to_tsl(self) {
  Number(self)
}

///|
pub impl IntoTsl for Int32 with fn to_tsl(self) {
  Number(self.to_double())
}

///|
pub impl IntoTsl for Bool with fn to_tsl(self) {
  Bool(self)
}

///|
pub impl IntoTsl for String with fn to_tsl(self) {
  String(self)
}

///|
pub impl IntoTsl for @math.Vector2 with fn to_tsl(self) {
  Vector2(self)
}

///|
pub impl IntoTsl for @math.Vector3 with fn to_tsl(self) {
  Vector3(self)
}

///|
pub impl IntoTsl for @math.Vector4 with fn to_tsl(self) {
  Vector4(self)
}

///|
pub impl IntoTsl for @math.Color with fn to_tsl(self) {
  Color(self)
}

///|
pub impl IntoTsl for @math.Matrix2 with fn to_tsl(self) {
  Matrix2(self)
}

///|
pub impl IntoTsl for @math.Matrix3 with fn to_tsl(self) {
  Matrix3(self)
}

///|
pub impl IntoTsl for @math.Matrix4 with fn to_tsl(self) {
  Matrix4(self)
}

///|
pub impl IntoTsl for @core.Texture with fn to_tsl(self) {
  Texture(self)
}

///|
pub impl IntoTsl for ShaderFn with fn to_tsl(self) {
  Shader(self)
}

///|
pub impl[T : IntoTsl] IntoTsl for Array[T] with fn to_tsl(self) {
  Array(self.map(fn(v) { v.to_tsl() }))
}

///|
pub impl[T : IntoTsl] IntoTsl for T? with fn to_tsl(self) {
  match self {
    Some(v) => v.to_tsl()
    None => Null
  }
}

///|
/// `value.isNode === true`.
pub fn TslValue::as_node(self : TslValue) -> Node? {
  match self {
    Node(n) => Some(n)
    _ => None
  }
}

///|
/// `value === undefined || value === null`.
pub fn TslValue::is_nullish(self : TslValue) -> Bool {
  self is (Undefined | Null)
}

///|
/// The arguments a TSL function body receives: upstream's `getProxyParameters`. Read
/// them positionally (`inputs.get(0)`, for `( [ a, b ] ) =>`) or by name
/// (`inputs.named("a")`, for `( { a, b } ) =>`). `None` is `undefined`, so a JS default
/// parameter `[ a = uv() ]` is `inputs.get(0).or_else(fn() { uv() })`.
pub(all) struct FnInputs {
  /// The raw call arguments, already passed through `nodeObject`.
  params : Array[TslValue]
  /// The proxy's running index for names the first object argument lacks.
  mut index : Int32
}

///|
pub fn FnInputs::new(params : Array[TslValue]) -> FnInputs {
  { params, index: 0, }
}

///|
/// `inputs.length`.
pub fn FnInputs::length(self : FnInputs) -> Int32 {
  self.params.length()
}

///|
/// `inputs[ i ]` (array destructuring), as a node; `None` is `undefined`.
pub fn FnInputs::get(self : FnInputs, i : Int32) -> Node? {
  // A lone plain object is NodeBuilder's `_createLayoutInputs` object, whose
  // iterator yields its values in layout order.
  let value = match self.params {
    [Object(object)] => {
      let mut found : TslValue = Undefined
      let mut j = 0
      for _, v in object {
        if j == i {
          found = v
          break
        }
        j += 1
      }
      found
    }
    _ => self.value(i)
  }
  match value {
    Node(n) => Some(n)
    Undefined | Null => None
    v => Some(node_object(v))
  }
}

///|
/// `inputs[ i ]` as the raw value.
pub fn FnInputs::value(self : FnInputs, i : Int32) -> TslValue {
  if i >= 0 && i < self.params.length() {
    self.params[i]
  } else {
    Undefined
  }
}

///|
/// `inputs.name` (object destructuring). As upstream's proxy: the named member of a
/// plain-object first argument, else the next positional argument.
pub fn FnInputs::named(self : FnInputs, name : String) -> Node? {
  if self.params.length() == 0 {
    return None
  }
  match self.params[0] {
    Object(object) =>
      match object.get(name) {
        Some(v) => self.to_node(v)
        None => {
          let v = match object.get(self.index.to_string()) {
            Some(v) => v
            None => Undefined
          }
          self.index += 1
          self.to_node(v)
        }
      }
    Node(_) => {
      let v = self.value(self.index)
      self.index += 1
      self.to_node(v)
    }
    _ => None
  }
}

///|
fn FnInputs::to_node(_self : FnInputs, v : TslValue) -> Node? {
  match v {
    Node(n) => Some(n)
    Undefined | Null => None
    v => Some(node_object(v))
  }
}
