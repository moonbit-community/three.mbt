// Pieces the objects share: upstream's `{ name, uniforms, vertexShader, fragmentShader }`
// shader objects (`Reflector.ReflectorShader`, `Sky.SkyShader`, ...) and JS bindings.

///|
/// A shader object as upstream writes them: `Reflector.ReflectorShader` and the like.
/// `name` is `None` where upstream leaves it undefined.
pub(all) struct ShaderDefinition {
  name : String?
  uniforms : Map[String, @core.Uniform]
  vertex_shader : String
  fragment_shader : String
}

///|
/// JS `Math.sign`.
extern "js" fn objects_math_sign(x : Double) -> Double = "Math.sign"

///|
/// JS `Math.sqrt`.
extern "js" fn objects_math_sqrt(x : Double) -> Double = "Math.sqrt"

///|
/// JS `Math.floor`.
extern "js" fn objects_math_floor(x : Double) -> Double = "Math.floor"

///|
/// JS `Math.abs`.
extern "js" fn objects_math_abs(x : Double) -> Double = "Math.abs"

///|
/// JS `Math.min`.
extern "js" fn objects_math_min(a : Double, b : Double) -> Double = "Math.min"

///|
/// The `WebGLRenderer` an `onBeforeRender` callback receives.
fn objects_webgl_renderer(renderer : @core.JsValue) -> @webgl.WebGLRenderer {
  renderer.cast()
}

///|
/// The camera payload of an object upstream treats as a camera.
fn objects_camera(camera : @core.Object3D) -> @core.Camera {
  match camera.kind {
    Camera(c) => c
    _ => abort("TypeError: not a camera")
  }
}

///|
/// `camera.far`; `None` is `undefined` (a base `Camera`).
fn objects_camera_far(camera : @core.Object3D) -> Double? {
  match objects_camera(camera).kind {
    PerspectiveCamera(p) => Some(p.far)
    OrthographicCamera(o) => Some(o.far)
    BaseCamera => None
  }
}

///|
/// `target.far = source.far`.
fn objects_copy_camera_far(
  target : @core.Object3D,
  source : @core.Object3D,
) -> Unit {
  match (objects_camera(target).kind, objects_camera_far(source)) {
    (PerspectiveCamera(p), Some(far)) => p.far = far
    (OrthographicCamera(o), Some(far)) => o.far = far
    (PerspectiveCamera(p), None) => p.far = 0.0 / 0.0
    (OrthographicCamera(o), None) => o.far = 0.0 / 0.0
    (BaseCamera, _) => ()
  }
}

///|
/// `material.uniforms[ name ]`.
fn objects_uniform(material : @core.Material, name : String) -> @core.Uniform {
  match material.uniforms {
    Some(uniforms) =>
      match uniforms.get(name) {
        Some(u) => u
        None =>
          abort(
            "TypeError: Cannot set properties of undefined (uniform \{name})",
          )
      }
    None => abort("TypeError: material has no uniforms")
  }
}

///|
/// The vector a `Vector4` uniform holds.
fn objects_uniform_vector4(uniform : @core.Uniform) -> @math.Vector4 {
  match uniform.value {
    Vector4(v) => v
    _ => abort("TypeError: uniform value is not a Vector4")
  }
}

///|
/// The payload of an add-on object, as `X::of` returns it.
fn[T] objects_payload(object : @core.Object3D, flag : String) -> T? {
  match object.extension {
    Some(extension) if extension.has_flag(flag) =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `objects_payload` for methods called on the object; aborts like upstream's
/// `TypeError` on another object.
fn[T] objects_require(object : @core.Object3D, flag : String) -> T {
  match objects_payload(object, flag) {
    Some(payload) => payload
    None => abort("TypeError: object is not \{flag}")
  }
}

///|
/// `texture( value )` where upstream passes an option that may be `undefined` (the
/// empty texture then).
fn objects_texture_node(value : @core.Texture?) -> @nodes.Node {
  match value {
    Some(t) => @nodes.texture(t)
    None => @nodes.texture((Undefined : @nodes.TslValue))
  }
}
