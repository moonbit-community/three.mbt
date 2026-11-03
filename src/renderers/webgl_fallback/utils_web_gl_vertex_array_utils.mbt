// renderers/webgl-fallback/utils/WebGLVertexArrayUtils.js: vertex array objects, shared
// between owners (render objects, compute pipelines) with the same attribute buffers.
//
// The owner and buffer records are the backend's JS objects (`vaoKey`, `vaoGPU`,
// `vertexBuffers`, `indexBuffer`; `vaoKeys` is a JS `Set` on the buffer records).

///|
/// A `cache` entry: `{ vaos, buffersData, usedTimes }`.
pub(all) struct WebGLVAOEntry {
  /// `vaos`: variant -> VAO, a JS `Map` in insertion order.
  vaos : Map[String, @webgl.GLVertexArrayObject]
  buffers_data : Array[@core.JsValue]
  mut used_times : Int32
}

///|
pub(all) struct WebGLVertexArrayUtils {
  backend : WebGLBackend
  /// `cache`: key -> entry.
  cache : Map[String, WebGLVAOEntry]
}

///|
/// `new WebGLVertexArrayUtils( backend )`.
pub fn WebGLVertexArrayUtils::new(
  backend : WebGLBackend,
) -> WebGLVertexArrayUtils {
  { backend, cache: Map([]), }
}

///|
/// The JS identity of a geometry attribute (the key of `backend.get( attribute )`).
fn _webgl_geometry_attribute_key(
  attribute : @core.GeometryAttribute,
) -> @core.JsValue {
  match attribute {
    Buffer(a) => @core.JsValue::of(a)
    Interleaved(a) => @core.JsValue::of(a)
    GL(a) => @core.JsValue::of(a)
  }
}

///|
extern "js" fn _webgl_vao_js_string(value : @core.JsValue) -> String = "(v) => String( v )"

///|
extern "js" fn _webgl_vao_active_buffer_index(record : @core.JsValue) -> String = "(r) => String( r.activeBufferIndex || 0 )"

///|
extern "js" fn _webgl_vao_add_key(record : @core.JsValue, key : String) -> Unit = "(r, k) => { if ( r.vaoKeys === undefined ) r.vaoKeys = new Set(); r.vaoKeys.add( k ); }"

///|
extern "js" fn _webgl_vao_delete_key(
  record : @core.JsValue,
  key : String,
) -> Unit = "(r, k) => { r.vaoKeys.delete( k ); }"

///|
extern "js" fn _webgl_vao_keys(record : @core.JsValue) -> FixedArray[String] = "(r) => Array.from( r.vaoKeys )"

///|
extern "js" fn _webgl_vao_array(
  values : FixedArray[@core.JsValue],
) -> @core.JsValue = "(a) => a"

///|
extern "js" fn _webgl_vao_array_length(array : @core.JsValue) -> Int32 = "(a) => a.length"

///|
extern "js" fn _webgl_vao_array_get(
  array : @core.JsValue,
  i : Int32,
) -> @core.JsValue = "(a, i) => a[ i ]"

///|
/// `getVAO( owner, attributes, index = null )`.
pub fn WebGLVertexArrayUtils::get_vao(
  self : WebGLVertexArrayUtils,
  owner : @core.JsValue,
  attributes : Array[@core.GeometryAttribute],
  index? : @core.GeometryAttribute,
) -> @webgl.GLVertexArrayObject {
  let backend = self.backend
  let owner_data = backend.get(owner)
  let index_data = match index {
    Some(i) => Some(backend.get(_webgl_geometry_attribute_key(i)))
    None => None
  }
  let index_gpu = match index_data {
    Some(d) => d.get("bufferGPU")
    None => @core.JsValue::null()
  }
  if self._needs_update(owner_data, attributes, index_gpu) == false {
    return owner_data.get("vaoGPU").cast()
  }
  // determine key, variant and attribute buffers
  let mut key = ""
  let mut variant = ""
  let buffers = []
  let buffers_data = []
  for attribute in attributes {
    let attribute_data = backend.get(
      backend.get_buffer_attribute(attribute).key(),
    )
    key += ":" + _webgl_vao_js_string(attribute_data.get("id"))
    if attribute is Interleaved(a) {
      key += "." + a.offset.to_string()
    }
    variant += ":" + _webgl_vao_active_buffer_index(attribute_data)
    buffers.push(attribute_data.get("bufferGPU"))
    buffers_data.push(attribute_data)
  }
  // the element buffer binding is part of the VAO state
  match index_data {
    Some(d) => {
      key += "|" + _webgl_vao_js_string(d.get("id"))
      buffers_data.push(d)
    }
    None => ()
  }
  // get cache entry
  let mut entry = self.cache.get(key)
  let vao_key = owner_data.get("vaoKey")
  if vao_key.is_undefined() || vao_key.cast() != key {
    if !vao_key.is_undefined() {
      self._release_entry(vao_key.cast()) // release old VAO
    }
    if entry is None {
      let e = { vaos: Map([]), buffers_data, used_times: 0, }
      self.cache.set(key, e)
      // each buffer knows its VAOs so they can be deleted with the buffer
      for buffer_data in buffers_data {
        _webgl_vao_add_key(buffer_data, key)
      }
      entry = Some(e)
    }
    entry.unwrap().used_times += 1
    owner_data.set("vaoKey", @core.JsValue::of(key))
  }
  let entry = entry.unwrap()
  // get correct VAO variant (variants are needed for dual buffer attributes)
  let vao_gpu = match entry.vaos.get(variant) {
    Some(v) => v
    None => {
      let v = self._create_vao(attributes, index_gpu)
      entry.vaos.set(variant, v)
      v
    }
  }
  owner_data.set("vaoGPU", @core.JsValue::of(vao_gpu))
  owner_data.set(
    "vertexBuffers",
    _webgl_vao_array(FixedArray::from_array(buffers)),
  )
  owner_data.set("indexBuffer", index_gpu)
  vao_gpu
}

///|
/// `releaseVAO( owner )`.
pub fn WebGLVertexArrayUtils::release_vao(
  self : WebGLVertexArrayUtils,
  owner : @core.JsValue,
) -> Unit {
  let owner_data = self.backend.get(owner)
  let vao_key = owner_data.get("vaoKey")
  if vao_key.is_undefined() {
    return
  }
  self._release_entry(vao_key.cast())
  owner_data.set("vaoKey", @core.JsValue::undefined())
  owner_data.set("vaoGPU", @core.JsValue::undefined())
  owner_data.set("vertexBuffers", @core.JsValue::undefined())
  owner_data.set("indexBuffer", @core.JsValue::undefined())
}

///|
/// `releaseBuffer( bufferData )`.
pub fn WebGLVertexArrayUtils::release_buffer(
  self : WebGLVertexArrayUtils,
  buffer_data : @core.JsValue,
) -> Unit {
  if buffer_data.get("vaoKeys").is_undefined() {
    return
  }
  for key in _webgl_vao_keys(buffer_data) {
    self._delete_entry(key)
  }
}

///|
/// `dispose()`.
pub fn WebGLVertexArrayUtils::dispose(self : WebGLVertexArrayUtils) -> Unit {
  let gl = self.backend.gl.unwrap()
  for _, entry in self.cache {
    for _, vao_gpu in entry.vaos {
      gl.delete_vertex_array(vao_gpu)
    }
  }
  self.cache.clear()
}

///|
/// `_needsUpdate( ownerData, attributes, indexGPU )`.
fn WebGLVertexArrayUtils::_needs_update(
  self : WebGLVertexArrayUtils,
  owner_data : @core.JsValue,
  attributes : Array[@core.GeometryAttribute],
  index_gpu : @core.JsValue,
) -> Bool {
  let buffers = owner_data.get("vertexBuffers")
  if buffers.is_undefined() ||
    _webgl_vao_array_length(buffers) != attributes.length() ||
    !owner_data.get("indexBuffer").strict_equal(index_gpu) {
    return true
  }
  for i, attribute in attributes {
    let buffer_attribute = self.backend.get_buffer_attribute(attribute)
    if !self.backend
      .get(buffer_attribute.key())
      .get("bufferGPU")
      .strict_equal(_webgl_vao_array_get(buffers, i)) {
      return true
    }
  }
  false
}

///|
/// `_releaseEntry( key )`.
fn WebGLVertexArrayUtils::_release_entry(
  self : WebGLVertexArrayUtils,
  key : String,
) -> Unit {
  let entry = match self.cache.get(key) {
    Some(e) => e
    None => return // already deleted with one of its buffers
  }
  entry.used_times -= 1
  if entry.used_times == 0 {
    self._delete_entry(key)
  }
}

///|
/// `_deleteEntry( key )`.
fn WebGLVertexArrayUtils::_delete_entry(
  self : WebGLVertexArrayUtils,
  key : String,
) -> Unit {
  let gl = self.backend.gl.unwrap()
  let state = self.backend.state.unwrap()
  let entry = match self.cache.get(key) {
    Some(e) => e
    None =>
      abort("TypeError: Cannot read properties of undefined (reading 'vaos')")
  }
  for _, vao_gpu in entry.vaos {
    if @webgl.same_handle(state.current_vao, Some(vao_gpu)) {
      state.reset_vertex_state()
    }
    gl.delete_vertex_array(vao_gpu)
  }
  for buffer_data in entry.buffers_data {
    _webgl_vao_delete_key(buffer_data, key)
  }
  self.cache.remove(key)
}

///|
/// `_createVAO( attributes, indexGPU )`.
fn WebGLVertexArrayUtils::_create_vao(
  self : WebGLVertexArrayUtils,
  attributes : Array[@core.GeometryAttribute],
  index_gpu : @core.JsValue,
) -> @webgl.GLVertexArrayObject {
  let gl = self.backend.gl.unwrap()
  let state = self.backend.state.unwrap()
  let vao_gpu = gl.create_vertex_array()
  let index_buffer : @webgl.GLBuffer? = if index_gpu.is_null() ||
    index_gpu.is_undefined() {
    None
  } else {
    Some(index_gpu.cast())
  }
  state.set_vertex_state(Some(vao_gpu), index_buffer?) |> ignore
  for i, attribute in attributes {
    let buffer_attribute = self.backend.get_buffer_attribute(attribute)
    let attribute_data = self.backend.get(buffer_attribute.key())
    let buffer_gpu = attribute_data.get("bufferGPU")
    gl.bind_buffer(
      @webgl.GL_ARRAY_BUFFER,
      if buffer_gpu.is_undefined() || buffer_gpu.is_null() {
        None
      } else {
        Some(buffer_gpu.cast())
      },
    )
    gl.enable_vertex_attrib_array(i)
    let bytes_per_element = @webgl.js_number_to_int(
      attribute_data.get("bytesPerElement"),
    )
    let (stride, offset) = match attribute {
      Interleaved(a) => {
        // interleaved attributes can also view a buffer attribute
        let buffer_stride = match buffer_attribute {
          Interleaved(b) => b.stride
          Buffer(b) => b.item_size
          GL(b) => b.item_size
        }
        (buffer_stride * bytes_per_element, a.offset * bytes_per_element)
      }
      _ => (0, 0)
    }
    let type_ = @webgl.js_number_to_int(attribute_data.get("type"))
    if @webgl.js_truthy(attribute_data.get("isInteger")) {
      gl.vertex_attrib_i_pointer(
        i,
        attribute.item_size(),
        type_,
        stride,
        offset,
      )
    } else {
      gl.vertex_attrib_pointer(
        i,
        attribute.item_size(),
        type_,
        attribute.normalized(),
        stride,
        offset,
      )
    }
    match buffer_attribute {
      Buffer(b) if b.is_instanced_buffer_attribute() =>
        gl.vertex_attrib_divisor(i, b.mesh_per_attribute)
      Interleaved(b) if b.is_instanced_interleaved_buffer =>
        gl.vertex_attrib_divisor(i, b.mesh_per_attribute)
      _ => ()
    }
  }
  gl.bind_buffer(@webgl.GL_ARRAY_BUFFER, None)
  vao_gpu
}
