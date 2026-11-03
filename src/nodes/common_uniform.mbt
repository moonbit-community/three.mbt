// renderers/common/Uniform.js: `Uniform` and its typed subclasses. Subclasses above
// (the node uniforms, ...) plug in through `UniformClass`.

///|
/// The overridable members of `Uniform` subclasses; defaults walk to `parent`.
pub(open) trait UniformClass {
  fn class_name(Self) -> String
  fn parent(Self) -> &UniformClass? = _
  fn payload(Self) -> @core.JsValue = _
  fn has_flag(Self, String) -> Bool = _
  /// `getValue()`.
  fn get_value(Self, Uniform) -> TslValue = _
  /// `getType()` of the node uniforms.
  fn get_type(Self, Uniform) -> String = _
}

///|
impl UniformClass with fn parent(_) {
  None
}

///|
impl UniformClass with fn payload(self) {
  @core.JsValue::of(self)
}

///|
impl UniformClass with fn has_flag(self, flag) {
  match self.parent() {
    Some(p) => p.has_flag(flag)
    None => false
  }
}

///|
impl UniformClass with fn get_value(self, uniform) {
  match self.parent() {
    Some(p) => p.get_value(uniform)
    None => uniform.value
  }
}

///|
impl UniformClass with fn get_type(self, uniform) {
  match self.parent() {
    Some(p) => p.get_type(uniform)
    None => abort("TypeError: uniform.getType is not a function")
  }
}

///|
/// The class of a plain `new Uniform( name, value )`.
pub(all) struct BaseUniform {}

///|
pub impl UniformClass for BaseUniform with fn class_name(_) {
  "Uniform"
}

///|
/// Upstream's `Uniform` fields; `class_` is the most derived class payload.
pub(all) struct Uniform {
  mut name : String
  mut value : TslValue
  mut boundary : Int32
  mut item_size : Int32
  mut offset : Int32
  mut index : Int32
  mut class_ : &UniformClass
}

///|
/// `new Uniform( name, value )`.
pub fn Uniform::new(name : String, value : TslValue) -> Uniform {
  {
    name,
    value,
    boundary: 0,
    item_size: 0,
    offset: 0,
    index: -1,
    class_: BaseUniform::{ },
  }
}

///|
pub fn Uniform::set_value(self : Uniform, value : TslValue) -> Unit {
  self.value = value
}

///|
pub fn Uniform::get_value(self : Uniform) -> TslValue {
  self.class_.get_value(self)
}

///|
/// `getType()` (node uniforms only).
pub fn Uniform::get_type(self : Uniform) -> String {
  self.class_.get_type(self)
}

///|
/// An upstream `isFoo` flag: `uniform.has_flag("isNumberUniform")`.
pub fn Uniform::has_flag(self : Uniform, flag : String) -> Bool {
  self.class_.has_flag(flag)
}

///|
/// Finds the payload of class `name` in the chain, as a JS value for `X::of` to cast.
pub fn Uniform::class_payload(self : Uniform, name : String) -> @core.JsValue? {
  let mut c : &UniformClass? = Some(self.class_)
  while c is Some(k) {
    if k.class_name() == name {
      return Some(k.payload())
    }
    c = k.parent()
  }
  None
}

///|
pub(all) struct NumberUniform {}

///|
pub impl UniformClass for NumberUniform with fn class_name(_) {
  "NumberUniform"
}

///|
pub impl UniformClass for NumberUniform with fn has_flag(_, flag) {
  flag == "isNumberUniform"
}

///|
/// `new NumberUniform( name, value )`; `Undefined` takes upstream's default.
pub fn NumberUniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined { Number(0.0) } else { value }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 4
  uniform.item_size = 1
  uniform.class_ = NumberUniform::{ }
  uniform
}

///|
pub(all) struct Vector2Uniform {}

///|
pub impl UniformClass for Vector2Uniform with fn class_name(_) {
  "Vector2Uniform"
}

///|
pub impl UniformClass for Vector2Uniform with fn has_flag(_, flag) {
  flag == "isVector2Uniform"
}

///|
/// `new Vector2Uniform( name, value )`; `Undefined` takes upstream's default.
pub fn Vector2Uniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Vector2(@math.Vector2::new(0.0, 0.0))
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 8
  uniform.item_size = 2
  uniform.class_ = Vector2Uniform::{ }
  uniform
}

///|
pub(all) struct Vector3Uniform {}

///|
pub impl UniformClass for Vector3Uniform with fn class_name(_) {
  "Vector3Uniform"
}

///|
pub impl UniformClass for Vector3Uniform with fn has_flag(_, flag) {
  flag == "isVector3Uniform"
}

///|
/// `new Vector3Uniform( name, value )`; `Undefined` takes upstream's default.
pub fn Vector3Uniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Vector3(@math.Vector3::new(0.0, 0.0, 0.0))
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 16
  uniform.item_size = 3
  uniform.class_ = Vector3Uniform::{ }
  uniform
}

///|
pub(all) struct Vector4Uniform {}

///|
pub impl UniformClass for Vector4Uniform with fn class_name(_) {
  "Vector4Uniform"
}

///|
pub impl UniformClass for Vector4Uniform with fn has_flag(_, flag) {
  flag == "isVector4Uniform"
}

///|
/// `new Vector4Uniform( name, value )`; `Undefined` takes upstream's default.
pub fn Vector4Uniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Vector4(@math.Vector4::new(0.0, 0.0, 0.0, 1.0))
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 16
  uniform.item_size = 4
  uniform.class_ = Vector4Uniform::{ }
  uniform
}

///|
pub(all) struct ColorUniform {}

///|
pub impl UniformClass for ColorUniform with fn class_name(_) {
  "ColorUniform"
}

///|
pub impl UniformClass for ColorUniform with fn has_flag(_, flag) {
  flag == "isColorUniform"
}

///|
/// `new ColorUniform( name, value )`; `Undefined` takes upstream's default.
pub fn ColorUniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Color(@math.Color::new(1.0, 1.0, 1.0))
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 16
  uniform.item_size = 3
  uniform.class_ = ColorUniform::{ }
  uniform
}

///|
pub(all) struct Matrix2Uniform {}

///|
pub impl UniformClass for Matrix2Uniform with fn class_name(_) {
  "Matrix2Uniform"
}

///|
pub impl UniformClass for Matrix2Uniform with fn has_flag(_, flag) {
  flag == "isMatrix2Uniform"
}

///|
/// `new Matrix2Uniform( name, value )`; `Undefined` takes upstream's default.
pub fn Matrix2Uniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Matrix2(@math.Matrix2::new())
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 8
  uniform.item_size = 4
  uniform.class_ = Matrix2Uniform::{ }
  uniform
}

///|
pub(all) struct Matrix3Uniform {}

///|
pub impl UniformClass for Matrix3Uniform with fn class_name(_) {
  "Matrix3Uniform"
}

///|
pub impl UniformClass for Matrix3Uniform with fn has_flag(_, flag) {
  flag == "isMatrix3Uniform"
}

///|
/// `new Matrix3Uniform( name, value )`; `Undefined` takes upstream's default.
pub fn Matrix3Uniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Matrix3(@math.Matrix3::new())
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 48
  uniform.item_size = 12
  uniform.class_ = Matrix3Uniform::{ }
  uniform
}

///|
pub(all) struct Matrix4Uniform {}

///|
pub impl UniformClass for Matrix4Uniform with fn class_name(_) {
  "Matrix4Uniform"
}

///|
pub impl UniformClass for Matrix4Uniform with fn has_flag(_, flag) {
  flag == "isMatrix4Uniform"
}

///|
/// `new Matrix4Uniform( name, value )`; `Undefined` takes upstream's default.
pub fn Matrix4Uniform::new(
  name : String,
  value~ : TslValue = Undefined,
) -> Uniform {
  let value : TslValue = if value is Undefined {
    Matrix4(@math.Matrix4::new())
  } else {
    value
  }
  let uniform = Uniform::new(name, value)
  uniform.boundary = 64
  uniform.item_size = 16
  uniform.class_ = Matrix4Uniform::{ }
  uniform
}
