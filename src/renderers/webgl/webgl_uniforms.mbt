// Upstream src/renderers/webgl/WebGLUniforms.js. GROUP 2.
//
// The uniform tree mirrors upstream: `WebGLUniforms` is the root container (`seq`, `map`),
// `StructuredUniform` an inner node, `SingleUniform` / `PureArrayUniform` the leaves.
// Upstream picks a setter function per GL type at construction; here `set_value` matches
// on `type_`. Values are core `UniformValue`s; struct members and array elements are
// looked up by `UniformId` (`Struct` map key or `Array` index).
//
// Scalar and integer-vector uploads go through `webgl_uniforms_call`, which passes the
// JS value unchanged (booleans stay booleans, as upstream hands them to `uniform1i`).
// The cache holds numbers: a boolean is cached as 1 or 0.

///|
/// A path component: member name or array index (`id | 0`).
#derive(Eq)
pub(all) enum UniformId {
  Name(String)
  Index(Int32)
}

///|
pub extend UniformId with Eq::{equal, not_equal}

///|
/// The JS property key upstream stores the uniform under in `container.map`.
pub fn UniformId::key(self : UniformId) -> String {
  match self {
    Name(name) => name
    Index(index) => index.to_string()
  }
}

///|
/// `new SingleUniform( id, activeInfo, addr )`.
pub(all) struct SingleUniform {
  id : UniformId
  addr : GLUniformLocation
  /// last uploaded values, or the texture unit for samplers
  cache : Array[Double]
  /// `activeInfo.type`
  type_ : Int32
}

///|
/// `new PureArrayUniform( id, activeInfo, addr )`.
pub(all) struct PureArrayUniform {
  id : UniformId
  addr : GLUniformLocation
  cache : Array[Double]
  type_ : Int32
  /// `activeInfo.size`
  size : Int32
}

///|
/// `new StructuredUniform( id )`.
pub(all) struct StructuredUniform {
  id : UniformId
  seq : Array[WebGLUniformSetter]
  /// keyed by `UniformId::key`
  map : Map[String, WebGLUniformSetter]
}

///|
/// One entry of a `seq`.
pub(all) enum WebGLUniformSetter {
  Single(SingleUniform)
  PureArray(PureArrayUniform)
  Structured(StructuredUniform)
}

///|
/// `u.id`.
pub fn WebGLUniformSetter::id(self : WebGLUniformSetter) -> UniformId {
  match self {
    Single(u) => u.id
    PureArray(u) => u.id
    Structured(u) => u.id
  }
}

///|
/// `u.type`; `None` for structured nodes.
pub fn WebGLUniformSetter::type_(self : WebGLUniformSetter) -> Int32? {
  match self {
    Single(u) => Some(u.type_)
    PureArray(u) => Some(u.type_)
    Structured(_) => None
  }
}

// --- Utilities ---

///|
let webgl_uniforms_empty_texture : @core.Texture = @core.Texture::new()

///|
let webgl_uniforms_empty_shadow_texture : @core.Texture = @core.DepthTexture::new(
  width=1,
  height=1,
)

///|
let webgl_uniforms_empty_cube_shadow_texture : @core.Texture = @core.CubeDepthTexture::new(
  size=1,
)

///|
let webgl_uniforms_empty_array_texture : @core.Texture = @core.DataArrayTexture::new()

///|
let webgl_uniforms_empty_3d_texture : @core.Texture = @core.Data3DTexture::new()

///|
let webgl_uniforms_empty_cube_texture : @core.Texture = @core.CubeTexture::new()

///|
/// `arrayCacheF32`: temporary typed arrays by size.
let webgl_uniforms_array_cache_f32 : Map[Int32, @core.TypedArray] = Map([])

///|
/// `arrayCacheI32`.
let webgl_uniforms_array_cache_i32 : Map[Int32, @core.TypedArray] = Map([])

///|
let webgl_uniforms_mat4array : @core.TypedArray = @core.TypedArray::float32(16)

///|
let webgl_uniforms_mat3array : @core.TypedArray = @core.TypedArray::float32(9)

///|
let webgl_uniforms_mat2array : @core.TypedArray = @core.TypedArray::float32(4)

///|
/// `gl[ fn_name ]( addr, ...args )` with the arguments passed as JS values.
extern "js" fn webgl_uniforms_call(
  gl : WebGL2RenderingContext,
  fn_name : String,
  addr : GLUniformLocation,
  args : FixedArray[@core.JsValue],
) -> Unit = "(gl, m, l, a) => gl[m](l, ...a)"

///|
/// The JS value of a scalar uniform value.
fn webgl_uniforms_scalar_js(v : @core.UniformValue) -> @core.JsValue {
  match v {
    Bool(b) => @core.JsValue::of(b)
    Int(i) => @core.JsValue::of(i.to_double())
    Number(d) => @core.JsValue::of(d)
    Null => @core.JsValue::null()
    Other(js) => js
    _ => @core.JsValue::of(v)
  }
}

///|
/// The number `===` compares the cache with; booleans read as 1 / 0, others as NaN
/// (never equal).
fn webgl_uniforms_scalar_number(v : @core.UniformValue) -> Double {
  match v {
    Bool(b) => if b { 1.0 } else { 0.0 }
    Int(i) => i.to_double()
    Number(d) => d
    Other(js) => js_to_double(js)
    _ => 0.0 / 0.0
  }
}

///|
/// `v.x, v.y, v.z, v.w` of a vector-like value (`v.x !== undefined`): `Vector2/3/4` and
/// `Quaternion`.
fn webgl_uniforms_xyzw(v : @core.UniformValue) -> Array[Double]? {
  match v {
    // missing components are `undefined` upstream, which GL reads as NaN
    Vector2(v) => Some([v.x, v.y, 0.0 / 0.0, 0.0 / 0.0])
    Vector3(v) => Some([v.x, v.y, v.z, 0.0 / 0.0])
    Vector4(v) => Some([v.x, v.y, v.z, v.w])
    Quaternion(q) => Some([q.x, q.y, q.z, q.w])
    _ => None
  }
}

///|
/// `v.elements` of a matrix value.
fn webgl_uniforms_elements(v : @core.UniformValue) -> Array[Double]? {
  match v {
    Matrix3(m) => Some(m.elements)
    Matrix4(m) => Some(m.elements)
    _ => None
  }
}

///|
/// A flat numeric array value: `Numbers` or a typed array, as `GLData` and as numbers.
fn webgl_uniforms_flat(
  v : @core.UniformValue,
) -> (@core.JsValue, Array[Double]) {
  match v {
    Numbers(a) => (GLData::to_gl_data(a), a)
    TypedArray(t) => (@core.JsValue::of(t), t.to_array())
    Array(items) => {
      let numbers = items.map(webgl_uniforms_scalar_number)
      (GLData::to_gl_data(numbers), numbers)
    }
    Other(js) => (js, js_array_like_to_doubles(js))
    _ => abort("WebGLUniforms: unsupported uniform value")
  }
}

///|
/// `v.toArray( array, offset )` for the values `flatten` handles.
fn webgl_uniforms_to_array(
  v : @core.UniformValue,
  r : @core.TypedArray,
  offset : Int32,
) -> Unit {
  let values = match v {
    Vector2(v) => v.to_array()
    Vector3(v) => v.to_array()
    Vector4(v) => v.to_array()
    Color(c) => c.to_array()
    Quaternion(q) => q.to_array()
    Matrix3(m) => m.to_array()
    Matrix4(m) => m.to_array()
    Plane(p) => [p.normal.x, p.normal.y, p.normal.z, p.constant]
    _ => abort("WebGLUniforms: flatten: value has no toArray")
  }
  r.set_from(values, offset~)
}

///|
/// `flatten( array, nBlocks, blockSize )`: an array of vectors or matrices copied into a
/// cached `Float32Array`; flat arrays pass through.
fn webgl_uniforms_flatten(
  array : @core.UniformValue,
  n_blocks : Int32,
  block_size : Int32,
) -> @core.JsValue {
  let items = match array {
    Array(items) =>
      match items.get(0) {
        Some(Number(_)) | Some(Int(_)) | Some(Bool(_)) =>
          return webgl_uniforms_flat(array).0
        _ => items
      }
    Numbers(a) =>
      // `firstElem <= 0 || firstElem > 0` fails only for NaN and empty arrays
      if a.length() > 0 && !a[0].is_nan() {
        return GLData::to_gl_data(a)
      } else {
        a.map(fn(x) { @core.UniformValue::Number(x) })
      }
    TypedArray(t) =>
      if t.length() > 0 && !t[0].is_nan() {
        return @core.JsValue::of(t)
      } else {
        t.to_array().map(fn(x) { @core.UniformValue::Number(x) })
      }
    _ => abort("WebGLUniforms: flatten: unsupported uniform value")
  }
  let n = n_blocks * block_size
  let r = match webgl_uniforms_array_cache_f32.get(n) {
    Some(r) => r
    None => {
      let r = @core.TypedArray::float32(n)
      webgl_uniforms_array_cache_f32[n] = r
      r
    }
  }
  if n_blocks != 0 {
    webgl_uniforms_to_array(items[0], r, 0)
    let mut offset = 0
    for i in 1..<n_blocks {
      offset += block_size
      webgl_uniforms_to_array(items[i], r, offset)
    }
  }
  @core.JsValue::of(r)
}

///|
/// `arraysEqual( a, b )`.
fn webgl_uniforms_arrays_equal(a : Array[Double], b : Array[Double]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if a[i] != b[i] {
      return false
    }
  }
  true
}

///|
/// `copyArray( a, b )`.
fn webgl_uniforms_copy_array(a : Array[Double], b : Array[Double]) -> Unit {
  for i in 0..<b.length() {
    if i < a.length() {
      a[i] = b[i]
    } else {
      a.push(b[i])
    }
  }
}

///|
/// `cache[ i ] !== v`, where an index past the end is `undefined`.
fn webgl_uniforms_cache_differs(
  cache : Array[Double],
  i : Int32,
  v : Double,
) -> Bool {
  match cache.get(i) {
    Some(c) => c != v
    None => true
  }
}

///|
/// `cache[ i ] = v`.
fn webgl_uniforms_cache_set(
  cache : Array[Double],
  i : Int32,
  v : Double,
) -> Unit {
  while cache.length() < i {
    cache.push(0.0 / 0.0)
  }
  if i < cache.length() {
    cache[i] = v
  } else {
    cache.push(v)
  }
}

///|
/// `allocTexUnits( textures, n )`.
fn webgl_uniforms_alloc_tex_units(
  textures : WebGLTextures,
  n : Int32,
) -> @core.TypedArray {
  let r = match webgl_uniforms_array_cache_i32.get(n) {
    Some(r) => r
    None => {
      let r = @core.TypedArray::int32(n)
      webgl_uniforms_array_cache_i32[n] = r
      r
    }
  }
  for i in 0..<n {
    r[i] = textures.allocate_texture_unit().to_double()
  }
  r
}

///|
/// `initShadowTexture( texture )`.
fn webgl_uniforms_init_shadow_texture(texture : @core.Texture) -> @core.Texture {
  if texture.version == 0 {
    texture.compare_function = Some(@core.AlwaysCompare)
    texture.set_needs_update(true)
  }
  texture
}

///|
/// `v || emptyTexture`.
fn webgl_uniforms_texture_or(
  v : @core.UniformValue,
  empty : @core.Texture,
) -> @core.Texture {
  match v {
    Texture(t) => t
    _ => empty
  }
}

// --- Setters ---

///|
/// The element of a struct or array value under `id` (`value[ u.id ]`); `Null` when
/// missing.
fn webgl_uniforms_member(
  value : @core.UniformValue,
  id : UniformId,
) -> @core.UniformValue {
  match (value, id) {
    (Struct(map), Name(name)) => map.get(name).unwrap_or(Null)
    (Struct(map), Index(i)) => map.get(i.to_string()).unwrap_or(Null)
    (Array(items), Index(i)) => items.get(i).unwrap_or(Null)
    _ => Null
  }
}

///|
/// `getSingularSetter( type )` applied to `v`.
fn SingleUniform::set_value(
  self : SingleUniform,
  gl : WebGL2RenderingContext,
  v : @core.UniformValue,
  textures : WebGLTextures?,
) -> Unit {
  match self.type_ {
    0x1406 => self.set_scalar(gl, "uniform1f", v) // FLOAT
    0x8b50 => self.set_vector_f(gl, v, 2) // _VEC2
    0x8b51 => self.set_vector_f(gl, v, 3) // _VEC3
    0x8b52 => self.set_vector_f(gl, v, 4) // _VEC4
    0x8b5a => self.set_matrix(gl, v, webgl_uniforms_mat2array, 2) // _MAT2
    0x8b5b => self.set_matrix(gl, v, webgl_uniforms_mat3array, 3) // _MAT3
    0x8b5c => self.set_matrix(gl, v, webgl_uniforms_mat4array, 4) // _MAT4
    0x1404 | 0x8b56 => self.set_scalar(gl, "uniform1i", v) // INT, BOOL
    0x8b53 | 0x8b57 => self.set_vector_i(gl, v, 2, "uniform2i", "uniform2iv") // _VEC2
    0x8b54 | 0x8b58 => self.set_vector_i(gl, v, 3, "uniform3i", "uniform3iv") // _VEC3
    0x8b55 | 0x8b59 => self.set_vector_i(gl, v, 4, "uniform4i", "uniform4iv") // _VEC4
    0x1405 => self.set_scalar(gl, "uniform1ui", v) // UINT
    0x8dc6 => self.set_vector_i(gl, v, 2, "uniform2ui", "uniform2uiv") // _VEC2
    0x8dc7 => self.set_vector_i(gl, v, 3, "uniform3ui", "uniform3uiv") // _VEC3
    0x8dc8 => self.set_vector_i(gl, v, 4, "uniform4ui", "uniform4uiv") // _VEC4
    0x8b5e | 0x8d66 | 0x8dca | 0x8dd2 | 0x8b62 => {
      // SAMPLER_2D, SAMPLER_EXTERNAL_OES, INT_SAMPLER_2D, UNSIGNED_INT_SAMPLER_2D,
      // SAMPLER_2D_SHADOW
      let textures = textures.unwrap()
      let unit = self.set_unit(gl, textures)
      let empty_texture_2d = if self.type_ == GL_SAMPLER_2D_SHADOW {
        webgl_uniforms_init_shadow_texture(webgl_uniforms_empty_shadow_texture)
      } else {
        webgl_uniforms_empty_texture
      }
      textures.set_texture2d(
        webgl_uniforms_texture_or(v, empty_texture_2d),
        unit,
      )
    }
    0x8b5f | 0x8dcb | 0x8dd3 => {
      // SAMPLER_3D, INT_SAMPLER_3D, UNSIGNED_INT_SAMPLER_3D
      let textures = textures.unwrap()
      let unit = self.set_unit(gl, textures)
      textures.set_texture3d(
        webgl_uniforms_texture_or(v, webgl_uniforms_empty_3d_texture),
        unit,
      )
    }
    0x8b60 | 0x8dcc | 0x8dd4 | 0x8dc5 => {
      // SAMPLER_CUBE, INT_SAMPLER_CUBE, UNSIGNED_INT_SAMPLER_CUBE, SAMPLER_CUBE_SHADOW
      let textures = textures.unwrap()
      let unit = self.set_unit(gl, textures)
      let empty_texture_cube = if self.type_ == GL_SAMPLER_CUBE_SHADOW {
        webgl_uniforms_init_shadow_texture(
          webgl_uniforms_empty_cube_shadow_texture,
        )
      } else {
        webgl_uniforms_empty_cube_texture
      }
      textures.set_texture_cube(
        webgl_uniforms_texture_or(v, empty_texture_cube),
        unit,
      )
    }
    0x8dc1 | 0x8dcf | 0x8dd7 | 0x8dc4 => {
      // SAMPLER_2D_ARRAY, INT_SAMPLER_2D_ARRAY, UNSIGNED_INT_SAMPLER_2D_ARRAY,
      // SAMPLER_2D_ARRAY_SHADOW
      let textures = textures.unwrap()
      let unit = self.set_unit(gl, textures)
      textures.set_texture2d_array(
        webgl_uniforms_texture_or(v, webgl_uniforms_empty_array_texture),
        unit,
      )
    }
    // upstream has no setter for other types: `this.setValue` is undefined
    _ => abort("WebGLUniforms: no setter for uniform type \{self.type_}")
  }
}

///|
/// `setValueV1f` / `setValueV1i` / `setValueV1ui`.
fn SingleUniform::set_scalar(
  self : SingleUniform,
  gl : WebGL2RenderingContext,
  fn_name : String,
  v : @core.UniformValue,
) -> Unit {
  let cache = self.cache
  let number = webgl_uniforms_scalar_number(v)
  if !webgl_uniforms_cache_differs(cache, 0, number) {
    return
  }
  webgl_uniforms_call(gl, fn_name, self.addr, [webgl_uniforms_scalar_js(v)])
  webgl_uniforms_cache_set(cache, 0, number)
}

///|
/// `setValueV2f` / `setValueV3f` / `setValueV4f`.
fn SingleUniform::set_vector_f(
  self : SingleUniform,
  gl : WebGL2RenderingContext,
  v : @core.UniformValue,
  n : Int32,
) -> Unit {
  let cache = self.cache
  let components = match webgl_uniforms_xyzw(v) {
    Some(xyzw) => Some(xyzw)
    None =>
      match v {
        Color(c) if n == 3 => Some([c.r, c.g, c.b])
        _ => None
      }
  }
  match components {
    Some(c) => {
      let mut changed = false
      for i in 0..<n {
        if webgl_uniforms_cache_differs(cache, i, c[i]) {
          changed = true
        }
      }
      if changed {
        match n {
          2 => gl.uniform2f(self.addr, c[0], c[1])
          3 => gl.uniform3f(self.addr, c[0], c[1], c[2])
          _ => gl.uniform4f(self.addr, c[0], c[1], c[2], c[3])
        }
        for i in 0..<n {
          webgl_uniforms_cache_set(cache, i, c[i])
        }
      }
    }
    None => {
      let (data, numbers) = webgl_uniforms_flat(v)
      if webgl_uniforms_arrays_equal(cache, numbers) {
        return
      }
      match n {
        2 => gl.uniform2fv(self.addr, data)
        3 => gl.uniform3fv(self.addr, data)
        _ => gl.uniform4fv(self.addr, data)
      }
      webgl_uniforms_copy_array(cache, numbers)
    }
  }
}

///|
/// `setValueV2i` ... `setValueV4ui`.
fn SingleUniform::set_vector_i(
  self : SingleUniform,
  gl : WebGL2RenderingContext,
  v : @core.UniformValue,
  n : Int32,
  fn_name : String,
  name_v : String,
) -> Unit {
  let cache = self.cache
  match webgl_uniforms_xyzw(v) {
    Some(c) => {
      let mut changed = false
      for i in 0..<n {
        if webgl_uniforms_cache_differs(cache, i, c[i]) {
          changed = true
        }
      }
      if changed {
        let args = FixedArray::make(n, @core.JsValue::null())
        for i in 0..<n {
          args[i] = @core.JsValue::of(c[i])
        }
        webgl_uniforms_call(gl, fn_name, self.addr, args)
        for i in 0..<n {
          webgl_uniforms_cache_set(cache, i, c[i])
        }
      }
    }
    None => {
      let (data, numbers) = webgl_uniforms_flat(v)
      if webgl_uniforms_arrays_equal(cache, numbers) {
        return
      }
      webgl_uniforms_call(gl, name_v, self.addr, [data])
      webgl_uniforms_copy_array(cache, numbers)
    }
  }
}

///|
/// `setValueM2` / `setValueM3` / `setValueM4`.
fn SingleUniform::set_matrix(
  self : SingleUniform,
  gl : WebGL2RenderingContext,
  v : @core.UniformValue,
  scratch : @core.TypedArray,
  n : Int32,
) -> Unit {
  let cache = self.cache
  let (data, numbers) = match webgl_uniforms_elements(v) {
    None => {
      let (data, numbers) = webgl_uniforms_flat(v)
      if webgl_uniforms_arrays_equal(cache, numbers) {
        return
      }
      (data, numbers)
    }
    Some(elements) => {
      if webgl_uniforms_arrays_equal(cache, elements) {
        return
      }
      scratch.set_from(elements)
      (@core.JsValue::of(scratch), elements)
    }
  }
  match n {
    2 => gl.uniform_matrix2fv(self.addr, false, data)
    3 => gl.uniform_matrix3fv(self.addr, false, data)
    _ => gl.uniform_matrix4fv(self.addr, false, data)
  }
  webgl_uniforms_copy_array(cache, numbers)
}

///|
/// The texture-unit part of `setValueT1` and friends.
fn SingleUniform::set_unit(
  self : SingleUniform,
  gl : WebGL2RenderingContext,
  textures : WebGLTextures,
) -> Int32 {
  let cache = self.cache
  let unit = textures.allocate_texture_unit()
  if webgl_uniforms_cache_differs(cache, 0, unit.to_double()) {
    gl.uniform1i(self.addr, unit)
    webgl_uniforms_cache_set(cache, 0, unit.to_double())
  }
  unit
}

///|
/// `getPureArraySetter( type )` applied to `v`.
fn PureArrayUniform::set_value(
  self : PureArrayUniform,
  gl : WebGL2RenderingContext,
  v : @core.UniformValue,
  textures : WebGLTextures?,
) -> Unit {
  match self.type_ {
    0x1406 => gl.uniform1fv(self.addr, webgl_uniforms_flat(v).0) // FLOAT
    0x8b50 => gl.uniform2fv(self.addr, webgl_uniforms_flatten(v, self.size, 2)) // _VEC2
    0x8b51 => gl.uniform3fv(self.addr, webgl_uniforms_flatten(v, self.size, 3)) // _VEC3
    0x8b52 => gl.uniform4fv(self.addr, webgl_uniforms_flatten(v, self.size, 4)) // _VEC4
    0x8b5a =>
      gl.uniform_matrix2fv(
        self.addr,
        false,
        webgl_uniforms_flatten(v, self.size, 4),
      ) // _MAT2
    0x8b5b =>
      gl.uniform_matrix3fv(
        self.addr,
        false,
        webgl_uniforms_flatten(v, self.size, 9),
      ) // _MAT3
    0x8b5c =>
      gl.uniform_matrix4fv(
        self.addr,
        false,
        webgl_uniforms_flatten(v, self.size, 16),
      ) // _MAT4
    0x1404 | 0x8b56 => gl.uniform1iv(self.addr, webgl_uniforms_flat(v).0) // INT, BOOL
    0x8b53 | 0x8b57 => gl.uniform2iv(self.addr, webgl_uniforms_flat(v).0) // _VEC2
    0x8b54 | 0x8b58 => gl.uniform3iv(self.addr, webgl_uniforms_flat(v).0) // _VEC3
    0x8b55 | 0x8b59 => gl.uniform4iv(self.addr, webgl_uniforms_flat(v).0) // _VEC4
    0x1405 => gl.uniform1uiv(self.addr, webgl_uniforms_flat(v).0) // UINT
    0x8dc6 => gl.uniform2uiv(self.addr, webgl_uniforms_flat(v).0) // _VEC2
    0x8dc7 => gl.uniform3uiv(self.addr, webgl_uniforms_flat(v).0) // _VEC3
    0x8dc8 => gl.uniform4uiv(self.addr, webgl_uniforms_flat(v).0) // _VEC4
    0x8b5e | 0x8d66 | 0x8dca | 0x8dd2 | 0x8b62 => {
      // SAMPLER_2D, SAMPLER_EXTERNAL_OES, INT_SAMPLER_2D, UNSIGNED_INT_SAMPLER_2D,
      // SAMPLER_2D_SHADOW
      let textures = textures.unwrap()
      let units = self.set_units(gl, v, textures)
      let empty_texture_2d = if self.type_ == GL_SAMPLER_2D_SHADOW {
        webgl_uniforms_init_shadow_texture(webgl_uniforms_empty_shadow_texture)
      } else {
        webgl_uniforms_empty_texture
      }
      for i, item in webgl_uniforms_items(v) {
        textures.set_texture2d(
          webgl_uniforms_texture_or(item, empty_texture_2d),
          units[i],
        )
      }
    }
    0x8b5f | 0x8dcb | 0x8dd3 => {
      // SAMPLER_3D, INT_SAMPLER_3D, UNSIGNED_INT_SAMPLER_3D
      let textures = textures.unwrap()
      let units = self.set_units(gl, v, textures)
      for i, item in webgl_uniforms_items(v) {
        textures.set_texture3d(
          webgl_uniforms_texture_or(item, webgl_uniforms_empty_3d_texture),
          units[i],
        )
      }
    }
    0x8b60 | 0x8dcc | 0x8dd4 | 0x8dc5 => {
      // SAMPLER_CUBE, INT_SAMPLER_CUBE, UNSIGNED_INT_SAMPLER_CUBE, SAMPLER_CUBE_SHADOW
      let textures = textures.unwrap()
      let units = self.set_units(gl, v, textures)
      let empty_texture_cube = if self.type_ == GL_SAMPLER_CUBE_SHADOW {
        webgl_uniforms_init_shadow_texture(
          webgl_uniforms_empty_cube_shadow_texture,
        )
      } else {
        webgl_uniforms_empty_cube_texture
      }
      for i, item in webgl_uniforms_items(v) {
        textures.set_texture_cube(
          webgl_uniforms_texture_or(item, empty_texture_cube),
          units[i],
        )
      }
    }
    0x8dc1 | 0x8dcf | 0x8dd7 | 0x8dc4 => {
      // SAMPLER_2D_ARRAY, INT_SAMPLER_2D_ARRAY, UNSIGNED_INT_SAMPLER_2D_ARRAY,
      // SAMPLER_2D_ARRAY_SHADOW
      let textures = textures.unwrap()
      let units = self.set_units(gl, v, textures)
      for i, item in webgl_uniforms_items(v) {
        textures.set_texture2d_array(
          webgl_uniforms_texture_or(item, webgl_uniforms_empty_array_texture),
          units[i],
        )
      }
    }
    _ => abort("WebGLUniforms: no array setter for uniform type \{self.type_}")
  }
}

///|
/// The entries of a texture-array value (`v[ i ]`).
fn webgl_uniforms_items(v : @core.UniformValue) -> Array[@core.UniformValue] {
  match v {
    Array(items) => items
    _ => abort("WebGLUniforms: texture array uniform needs an array value")
  }
}

///|
/// The texture-unit part of `setValueT1Array` and friends: allocates `v.length` units
/// and uploads them when they changed.
fn PureArrayUniform::set_units(
  self : PureArrayUniform,
  gl : WebGL2RenderingContext,
  v : @core.UniformValue,
  textures : WebGLTextures,
) -> Array[Int32] {
  let cache = self.cache
  let n = webgl_uniforms_items(v).length()
  let units = webgl_uniforms_alloc_tex_units(textures, n)
  let unit_numbers = units.to_array()
  if !webgl_uniforms_arrays_equal(cache, unit_numbers) {
    gl.uniform1iv(self.addr, units)
    webgl_uniforms_copy_array(cache, unit_numbers)
  }
  unit_numbers.map(fn(u) { u.to_int() })
}

///|
/// `u.setValue( gl, value, textures )`. `textures` is needed for samplers only.
pub fn WebGLUniformSetter::set_value(
  self : WebGLUniformSetter,
  gl : WebGL2RenderingContext,
  value : @core.UniformValue,
  textures? : WebGLTextures,
) -> Unit {
  match self {
    Single(u) => u.set_value(gl, value, textures)
    PureArray(u) => u.set_value(gl, value, textures)
    Structured(u) =>
      for item in u.seq {
        item.set_value(gl, webgl_uniforms_member(value, item.id()), textures?)
      }
  }
}

///|
/// The root container of a program's uniforms.
pub(all) struct WebGLUniforms {
  mut seq : Array[WebGLUniformSetter]
  /// keyed by uniform name
  map : Map[String, WebGLUniformSetter]
}

///|
fn webgl_uniforms_is_word_char(c : UInt16) -> Bool {
  (c >= 'a'.to_int().to_uint16() && c <= 'z'.to_int().to_uint16()) ||
  (c >= 'A'.to_int().to_uint16() && c <= 'Z'.to_int().to_uint16()) ||
  (c >= '0'.to_int().to_uint16() && c <= '9'.to_int().to_uint16()) ||
  c == '_'.to_int().to_uint16()
}

///|
/// One `RePathPart.exec( path )` match from `start`: `(id, idIsIndex, subscript,
/// matchEnd)`; `subscript` is `""` when absent.
fn webgl_uniforms_path_part(
  path : String,
  start : Int32,
) -> (String, Bool, String, Int32)? {
  let n = path.length()
  let mut i = start
  while i < n && !webgl_uniforms_is_word_char(path.code_unit_at(i)) {
    i += 1
  }
  if i >= n {
    return None
  }
  let id_start = i
  while i < n && webgl_uniforms_is_word_char(path.code_unit_at(i)) {
    i += 1
  }
  let id = path.unsafe_substring(start=id_start, end=i)
  let mut id_is_index = false
  if i < n && path.code_unit_at(i) == ']'.to_int().to_uint16() {
    id_is_index = true
    i += 1
  }
  let mut subscript = ""
  if i < n &&
    (
      path.code_unit_at(i) == '['.to_int().to_uint16() ||
      path.code_unit_at(i) == '.'.to_int().to_uint16()
    ) {
    subscript = path.unsafe_substring(start=i, end=i + 1)
    i += 1
  }
  Some((id, id_is_index, subscript, i))
}

///|
extern "js" fn webgl_uniforms_parse_int(s : String) -> Int32 = "(s) => s | 0"

///|
/// `parseUniform( activeInfo, addr, container )`.
fn webgl_uniforms_parse_uniform(
  info : GLActiveInfo,
  addr : GLUniformLocation,
  seq : Array[WebGLUniformSetter],
  map : Map[String, WebGLUniformSetter],
) -> Unit {
  let path = info.name()
  let path_length = path.length()
  let mut seq = seq
  let mut map = map
  let mut last_index = 0
  while true {
    guard webgl_uniforms_path_part(path, last_index)
      is Some((name, id_is_index, subscript, match_end)) else {
      abort("WebGLUniforms: cannot parse uniform name " + path)
    }
    last_index = match_end
    let id : UniformId = if id_is_index {
      Index(webgl_uniforms_parse_int(name))
    } else {
      Name(name)
    }
    if subscript == "" || (subscript == "[" && match_end + 2 == path_length) {
      // bare name or "pure" bottom-level array "[0]" suffix
      let uniform_object : WebGLUniformSetter = if subscript == "" {
        Single({ id, addr, cache: [], type_: info.type_(), })
      } else {
        PureArray({
          id,
          addr,
          cache: [],
          type_: info.type_(),
          size: info.size(),
        })
      }
      seq.push(uniform_object)
      map[id.key()] = uniform_object
      break
    } else {
      // step into inner node / create it in case it doesn't exist
      let next = match map.get(id.key()) {
        Some(Structured(next)) => next
        Some(_) => abort("WebGLUniforms: uniform " + path + " is not a struct")
        None => {
          let next : StructuredUniform = { id, seq: [], map: Map([]), }
          let node : WebGLUniformSetter = Structured(next)
          seq.push(node)
          map[id.key()] = node
          next
        }
      }
      seq = next.seq
      map = next.map
    }
  }
}

///|
/// `new WebGLUniforms( gl, program )`: parses the active uniforms, shadow samplers first.
pub fn WebGLUniforms::new(
  gl : WebGL2RenderingContext,
  program : GLProgram,
) -> WebGLUniforms {
  let uniforms : WebGLUniforms = { seq: [], map: Map([]), }
  let n = js_number_to_int(
    gl.get_program_parameter(program, GL_ACTIVE_UNIFORMS),
  )
  for i in 0..<n {
    let info = gl.get_active_uniform(program, i)
    let addr : GLUniformLocation = match
      gl.get_uniform_location(program, info.name()) {
      Some(addr) => addr
      // upstream keeps `null` and hands it to `gl.uniform*`
      None => @core.JsValue::null().cast()
    }
    webgl_uniforms_parse_uniform(info, addr, uniforms.seq, uniforms.map)
  }

  // Sort uniforms to prioritize shadow samplers first (for optimal texture unit allocation)

  let shadow_samplers = []
  let other_uniforms = []
  for u in uniforms.seq {
    match u.type_() {
      Some(t) if t == GL_SAMPLER_2D_SHADOW ||
        t == GL_SAMPLER_CUBE_SHADOW ||
        t == GL_SAMPLER_2D_ARRAY_SHADOW => shadow_samplers.push(u)
      _ => other_uniforms.push(u)
    }
  }
  if shadow_samplers.length() > 0 {
    uniforms.seq = shadow_samplers + other_uniforms
  }
  uniforms
}

///|
/// `uniforms.setValue( gl, name, value, textures )`.
pub fn WebGLUniforms::set_value(
  self : WebGLUniforms,
  gl : WebGL2RenderingContext,
  name : String,
  value : @core.UniformValue,
  textures? : WebGLTextures,
) -> Unit {
  if self.map.get(name) is Some(u) {
    u.set_value(gl, value, textures?)
  }
}

///|
/// `uniforms.setOptional( gl, object, name )`: uploads `object[ name ]` when the object
/// has that property (upstream reads it dynamically; known names are `bindMatrix` and
/// `bindMatrixInverse` on skinned meshes).
pub fn WebGLUniforms::set_optional(
  self : WebGLUniforms,
  gl : WebGL2RenderingContext,
  object : @core.Object3D,
  name : String,
) -> Unit {
  let v : @core.UniformValue? = match (object.kind, name) {
    (Mesh({ kind: SkinnedMesh(skinned), .. }), "bindMatrix") =>
      Some(Matrix4(skinned.bind_matrix))
    (Mesh({ kind: SkinnedMesh(skinned), .. }), "bindMatrixInverse") =>
      Some(Matrix4(skinned.bind_matrix_inverse))
    _ => None
  }
  if v is Some(v) {
    self.set_value(gl, name, v)
  }
}

///|
/// `WebGLUniforms.upload( gl, seq, values, textures )`: uploads every `values[ u.id ]`
/// whose `needsUpdate` is not `false` (see `uniform_needs_update`).
pub fn WebGLUniforms::upload(
  gl : WebGL2RenderingContext,
  seq : Array[WebGLUniformSetter],
  values : Map[String, @core.Uniform],
  textures : WebGLTextures,
) -> Unit {
  for u in seq {
    let key = u.id().key()
    guard values.get(key) is Some(v) else {
      abort("WebGLUniforms.upload: no value for uniform " + key)
    }
    if uniform_needs_update(v) != Some(false) {
      // note: always updating when .needsUpdate is undefined
      u.set_value(gl, v.value, textures~)
    }
  }
}

///|
/// `WebGLUniforms.seqWithValue( seq, values )`: the entries whose id is a key of `values`.
pub fn WebGLUniforms::seq_with_value(
  seq : Array[WebGLUniformSetter],
  values : Map[String, @core.Uniform],
) -> Array[WebGLUniformSetter] {
  let r = []
  for u in seq {
    if values.contains(u.id().key()) {
      r.push(u)
    }
  }
  r
}
