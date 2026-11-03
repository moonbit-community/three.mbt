// Hand-written half of the WebGL 2 bindings: the opaque types, the `GLData` argument
// trait, property accessors and `getParameter` readers. The `gl.*` methods themselves are
// generated into gl_context.mbt.
//
// Handles are opaque JS objects. Where upstream passes or receives `null`, the binding
// takes or returns `T?`. Option of an external type is boxed on the JS backend, so never
// compare two `T?` with `physical_equal`; use `same_handle`.

///|
/// The `WebGL2RenderingContext` the renderer draws with.
#external
pub type WebGL2RenderingContext

///|
/// `WebGLBuffer`.
#external
pub type GLBuffer

///|
/// `WebGLTexture`.
#external
pub type GLTexture

///|
/// `WebGLProgram`, the GL object. The three.js class is `WebGLProgram` in this package.
#external
pub type GLProgram

///|
/// `WebGLShader`.
#external
pub type GLShader

///|
/// `WebGLFramebuffer`.
#external
pub type GLFramebuffer

///|
/// `WebGLRenderbuffer`.
#external
pub type GLRenderbuffer

///|
/// `WebGLVertexArrayObject`.
#external
pub type GLVertexArrayObject

///|
/// `WebGLUniformLocation`.
#external
pub type GLUniformLocation

///|
/// `WebGLQuery`.
#external
pub type GLQuery

///|
/// `WebGLSync`.
#external
pub type GLSync

///|
/// An extension object returned by `gl.getExtension( name )`.
#external
pub type GLExtension

///|
/// `WebGLActiveInfo`, from `getActiveAttrib` / `getActiveUniform`.
#external
pub type GLActiveInfo

///|
/// `WebGLShaderPrecisionFormat`.
#external
pub type GLShaderPrecisionFormat

///|
/// A value passed where WebGL takes a buffer source or array: typed arrays from core pass
/// through as their JS value, `Array[Double]`/`Array[Int]` as JS arrays.
pub(open) trait GLData {
  fn to_gl_data(Self) -> @core.JsValue
}

///|
pub impl GLData for @core.TypedArray with fn to_gl_data(self) {
  @core.JsValue::of(self)
}

///|
/// `T` is `Double` or `Int`; the array is copied into a JS array.
pub impl[T] GLData for Array[T] with fn to_gl_data(self) {
  @core.JsValue::of(FixedArray::from_array(self[:]))
}

///|
pub impl[T] GLData for FixedArray[T] with fn to_gl_data(self) {
  @core.JsValue::of(self)
}

///|
/// Any JS value, e.g. `JsValue::null()` for "no data".
pub impl GLData for @core.JsValue with fn to_gl_data(self) {
  self
}

///|
/// `None` passes `null`.
pub impl[T : GLData] GLData for T? with fn to_gl_data(self) {
  match self {
    Some(value) => value.to_gl_data()
    None => @core.JsValue::null()
  }
}

///|
/// `Some(x)` -> `x`, `None` -> `null`.
fn[T] gl_nullable(value : T?) -> @core.JsValue {
  match value {
    Some(v) => @core.JsValue::of(v)
    None => @core.JsValue::null()
  }
}

///|
/// `null` / `undefined` -> `None`.
fn[T] gl_option(value : @core.JsValue) -> T? {
  if value.is_null() || value.is_undefined() {
    None
  } else {
    Some(value.cast())
  }
}

///|
/// JS `a === b` on two optional handles (or any reference values): both `None`, or both
/// `Some` of the same object.
pub fn[T] same_handle(a : T?, b : T?) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) => physical_equal(x, y)
    _ => false
  }
}

///|
/// `gl.canvas`.
pub extern "js" fn WebGL2RenderingContext::canvas(
  self : WebGL2RenderingContext,
) -> HTMLCanvasElement = "(gl) => gl.canvas"

///|
/// `gl.drawingBufferColorSpace = value`.
pub extern "js" fn WebGL2RenderingContext::set_drawing_buffer_color_space(
  self : WebGL2RenderingContext,
  value : String,
) -> Unit = "(gl, v) => { gl.drawingBufferColorSpace = v; }"

///|
/// `gl.unpackColorSpace = value`.
pub extern "js" fn WebGL2RenderingContext::set_unpack_color_space(
  self : WebGL2RenderingContext,
  value : String,
) -> Unit = "(gl, v) => { gl.unpackColorSpace = v; }"

///|
/// `'texElementImage2D' in gl`.
pub extern "js" fn WebGL2RenderingContext::has_tex_element_image2d(
  self : WebGL2RenderingContext,
) -> Bool = "(gl) => 'texElementImage2D' in gl"

///|
/// `gl.texElementImage2D.length`, which tells the 3- and 6-argument forms apart.
pub extern "js" fn WebGL2RenderingContext::tex_element_image2d_length(
  self : WebGL2RenderingContext,
) -> Int32 = "(gl) => gl.texElementImage2D.length"

///|
extern "js" fn ffi_gl_get_constant(
  gl : WebGL2RenderingContext,
  name : String,
) -> @core.JsValue = "(gl, n) => gl[n]"

///|
/// `gl[ name ]`, the dynamic constant lookup `WebGLUtils.convert` falls back to.
pub fn WebGL2RenderingContext::get_constant(
  self : WebGL2RenderingContext,
  name : String,
) -> Int32? {
  gl_option(ffi_gl_get_constant(self, name))
}

///|
/// `gl.getParameter( pname )` for numeric parameters.
pub fn WebGL2RenderingContext::get_parameter_int(
  self : WebGL2RenderingContext,
  pname : Int32,
) -> Int32 {
  js_number_to_int(self.get_parameter(pname))
}

///|
/// `gl.getParameter( pname )` for string parameters such as `VERSION`.
pub fn WebGL2RenderingContext::get_parameter_string(
  self : WebGL2RenderingContext,
  pname : Int32,
) -> String {
  js_to_string(self.get_parameter(pname))
}

///|
/// `gl.getParameter( pname )` for array parameters such as `SCISSOR_BOX`, `VIEWPORT`.
pub fn WebGL2RenderingContext::get_parameter_array(
  self : WebGL2RenderingContext,
  pname : Int32,
) -> Array[Double] {
  js_array_like_to_doubles(self.get_parameter(pname))
}

///|
/// `info.name`.
pub extern "js" fn GLActiveInfo::name(self : GLActiveInfo) -> String = "(i) => i.name"

///|
/// `info.size`.
pub extern "js" fn GLActiveInfo::size(self : GLActiveInfo) -> Int32 = "(i) => i.size"

///|
/// `info.type`.
pub extern "js" fn GLActiveInfo::type_(self : GLActiveInfo) -> Int32 = "(i) => i.type"

///|
/// `format.precision`.
pub extern "js" fn GLShaderPrecisionFormat::precision(
  self : GLShaderPrecisionFormat,
) -> Int32 = "(f) => f.precision"

///|
/// `format.rangeMin`.
pub extern "js" fn GLShaderPrecisionFormat::range_min(
  self : GLShaderPrecisionFormat,
) -> Int32 = "(f) => f.rangeMin"

///|
/// `format.rangeMax`.
pub extern "js" fn GLShaderPrecisionFormat::range_max(
  self : GLShaderPrecisionFormat,
) -> Int32 = "(f) => f.rangeMax"

///|
/// `extension[ name ]`, a constant such as `COMPRESSED_RGB_S3TC_DXT1_EXT`.
pub extern "js" fn GLExtension::constant(
  self : GLExtension,
  name : String,
) -> Int32 = "(e, n) => e[n]"

///|
/// `Number( value ) | 0`; `true` reads as 1, as JS coerces it.
pub extern "js" fn js_number_to_int(value : @core.JsValue) -> Int32 = "(v) => Number(v) | 0"

///|
/// `Number( value )`.
pub extern "js" fn js_to_double(value : @core.JsValue) -> Double = "(v) => Number(v)"

///|
/// JS truthiness, `!! value`.
pub extern "js" fn js_truthy(value : @core.JsValue) -> Bool = "(v) => !!v"

///|
/// `String( value )`.
pub extern "js" fn js_to_string(value : @core.JsValue) -> String = "(v) => String(v)"

///|
/// `Array.from( value )` for an array or typed array of numbers.
pub fn js_array_like_to_doubles(value : @core.JsValue) -> Array[Double] {
  Array::from_fixed_array(ffi_array_like_to_doubles(value))
}

///|
extern "js" fn ffi_array_like_to_doubles(
  value : @core.JsValue,
) -> FixedArray[Double] = "(v) => Array.from(v)"
