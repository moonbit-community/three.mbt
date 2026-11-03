// Upstream src/core/Uniform.js.

///|
extern "js" fn uniform_clone_other(value : JsValue) -> JsValue =
  #|(v) => ( v === null || v === undefined || v.clone === undefined ) ? v : v.clone()

///|
pub fn Uniform::new(value : UniformValue) -> Uniform {
  { value, }
}

///|
/// `value.clone === undefined ? value : value.clone()`.
pub fn UniformValue::clone(self : UniformValue) -> UniformValue {
  match self {
    Vector2(v) => Vector2(v.clone())
    Vector3(v) => Vector3(v.clone())
    Vector4(v) => Vector4(v.clone())
    Color(v) => Color(v.clone())
    Quaternion(v) => Quaternion(v.clone())
    Matrix3(v) => Matrix3(v.clone())
    Matrix4(v) => Matrix4(v.clone())
    Plane(v) => Plane(v.clone())
    Texture(v) => Texture(v.clone())
    Other(v) => Other(uniform_clone_other(v))
    Null
    | Bool(_)
    | Int(_)
    | Number(_)
    | Numbers(_)
    | TypedArray(_)
    | Array(_)
    | Struct(_) => self
  }
}

///|
pub fn Uniform::clone(self : Uniform) -> Uniform {
  Uniform::new(self.value.clone())
}
