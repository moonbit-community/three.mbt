// renderers/webgl-fallback/utils/WebGLAttributeUtils.js: the GPU buffers of attributes.
//
// The per-attribute record (`backend.get( bufferAttribute )`) is a plain JS object, as
// upstream: `{ bufferGPU, bufferType, type, byteLength, bytesPerElement, version, pbo,
// isInteger, id }`, or a `DualAttributeData` instance (a JS class with the `bufferGPU` /
// `transformBuffer` getters) for storage attributes.

///|
/// `_id`: the next attribute data id.
let _webgl_attribute_utils_id : Ref[Int32] = Ref(0)

///|
/// The `DualAttributeData` class (upstream's JS class, so the backend reads its getters
/// through the record like any other).
let _webgl_dual_attribute_data_class : @core.JsValue = _webgl_dual_attribute_data_define()

///|
extern "js" fn _webgl_dual_attribute_data_define() -> @core.JsValue =
  #|() => class DualAttributeData {
  #|  constructor( attributeData, dualBuffer ) {
  #|    this.buffers = [ attributeData.bufferGPU, dualBuffer ];
  #|    this.type = attributeData.type;
  #|    this.bufferType = attributeData.bufferType;
  #|    this.pbo = attributeData.pbo;
  #|    this.byteLength = attributeData.byteLength;
  #|    this.bytesPerElement = attributeData.BYTES_PER_ELEMENT;
  #|    this.version = attributeData.version;
  #|    this.isInteger = attributeData.isInteger;
  #|    this.activeBufferIndex = 0;
  #|    this.id = attributeData.id;
  #|  }
  #|  get bufferGPU() { return this.buffers[ this.activeBufferIndex ]; }
  #|  get transformBuffer() { return this.buffers[ this.activeBufferIndex ^ 1 ]; }
  #|  switchBuffers() { this.activeBufferIndex ^= 1; }
  #|}

///|
extern "js" fn _webgl_dual_attribute_data_new(
  class_ : @core.JsValue,
  attribute_data : @core.JsValue,
  dual_buffer : @core.JsValue,
) -> @core.JsValue = "(C, a, d) => new C( a, d )"

///|
/// `new DualAttributeData( attributeData, dualBuffer )`.
pub fn DualAttributeData::new(
  attribute_data : @core.JsValue,
  dual_buffer : @webgl.GLBuffer,
) -> @core.JsValue {
  _webgl_dual_attribute_data_new(
    _webgl_dual_attribute_data_class,
    attribute_data,
    @core.JsValue::of(dual_buffer),
  )
}

///|
/// `dualAttributeData.switchBuffers()`.
pub extern "js" fn DualAttributeData::switch_buffers(
  data : @core.JsValue,
) -> Unit = "(d) => { d.switchBuffers(); }"

///|
/// Upstream's `DualAttributeData` class (records are JS instances of it).
#external
pub type DualAttributeData

///|
/// The attribute data record of `createAttribute`, in upstream's key order.
extern "js" fn _webgl_attribute_data(
  buffer_gpu : @core.JsValue,
  buffer_type : Int32,
  type_ : Int32,
  byte_length : Int32,
  bytes_per_element : Int32,
  version : Int32,
  pbo : @core.JsValue,
  is_integer : Bool,
  id : Int32,
) -> @core.JsValue =
  #|( bufferGPU, bufferType, type, byteLength, bytesPerElement, version, pbo, isInteger, id ) => ( {
  #|  bufferGPU, bufferType, type, byteLength, bytesPerElement, version, pbo, isInteger, id
  #|} )

///|
/// The GL type of an attribute array (`createAttribute`'s `instanceof` chain); -1 for an
/// unsupported array.
extern "js" fn _webgl_attribute_gl_type(
  array : @core.JsValue,
  is_float16 : Bool,
) -> Int32 =
  #|( array, isFloat16 ) => {
  #|  if ( array instanceof Float32Array ) return 0x1406;
  #|  else if ( typeof Float16Array !== 'undefined' && array instanceof Float16Array ) return 0x140B;
  #|  else if ( array instanceof Uint16Array ) return isFloat16 ? 0x140B : 0x1403;
  #|  else if ( array instanceof Int16Array ) return 0x1402;
  #|  else if ( array instanceof Uint32Array ) return 0x1405;
  #|  else if ( array instanceof Int32Array ) return 0x1404;
  #|  else if ( array instanceof Int8Array ) return 0x1400;
  #|  else if ( array instanceof Uint8Array ) return 0x1401;
  #|  else if ( array instanceof Uint8ClampedArray ) return 0x1401;
  #|  return - 1;
  #|}

///|
extern "js" fn _webgl_js_string(value : @core.JsValue) -> String = "(v) => String( v )"

///|
extern "js" fn _webgl_new_uint8_array(byte_length : Int32) -> @core.JsValue = "(n) => new Uint8Array( new ArrayBuffer( n ) )"

///|
extern "js" fn _webgl_array_buffer_of(view : @core.JsValue) -> @core.JsValue = "(v) => v.buffer"

///|
/// `record[ key ]` as a GL handle (`None` for `null`/`undefined`).
fn[T] _webgl_record_handle(record : @core.JsValue, key : String) -> T? {
  let v = record.get(key)
  if v.is_undefined() || v.is_null() {
    None
  } else {
    Some(v.cast())
  }
}

///|
/// `record[ key ]` as an integer.
fn _webgl_record_int(record : @core.JsValue, key : String) -> Int32 {
  @webgl.js_number_to_int(record.get(key))
}

///|
pub(all) struct WebGLAttributeUtils {
  backend : WebGLBackend
}

///|
/// `new WebGLAttributeUtils( backend )`.
pub fn WebGLAttributeUtils::new(backend : WebGLBackend) -> WebGLAttributeUtils {
  { backend, }
}

///|
/// `createAttribute( attribute, bufferType )`.
pub fn WebGLAttributeUtils::create_attribute(
  self : WebGLAttributeUtils,
  attribute : @nodes.AttributeBuffer,
  buffer_type : Int32,
) -> Unit {
  let backend = self.backend
  let gl = backend.gl.unwrap()
  let buffer_attribute = attribute
  if !backend.get(buffer_attribute.key()).get("bufferGPU").is_undefined() {
    return
  }
  let array = match attribute.array() {
    Some(a) => a
    None =>
      abort("THREE.WebGLBackend: Unsupported buffer data format: undefined")
  }
  let usage = match attribute.usage() {
    Some(u) if u != 0 => u
    _ => @webgl.GL_STATIC_DRAW
  }
  let buffer_gpu = self._create_buffer(gl, buffer_type, array, usage)
  //attribute.onUploadCallback();
  let is_float16 = match attribute {
    Buffer(a) => a.is_float16_buffer_attribute()
    _ => false
  }
  let type_ = _webgl_attribute_gl_type(@core.JsValue::of(array), is_float16)
  if type_ == -1 {
    abort(
      "THREE.WebGLBackend: Unsupported buffer data format: " +
      _webgl_js_string(@core.JsValue::of(array)),
    )
  }
  let gpu_is_int = match attribute {
    Buffer(a) => a.gpu_type == @core.IntType
    _ => false
  }
  let pbo = match attribute {
    Buffer(a) =>
      match glsl_attribute_pbo(a) {
        Some(t) => @core.JsValue::of(t)
        None => @core.JsValue::undefined()
      }
    _ => @core.JsValue::undefined()
  }
  let id = _webgl_attribute_utils_id.val
  _webgl_attribute_utils_id.val += 1
  let mut attribute_data = _webgl_attribute_data(
    @core.JsValue::of(buffer_gpu),
    buffer_type,
    type_,
    array.byte_length(),
    array.bytes_per_element(),
    buffer_attribute.version(),
    pbo,
    type_ == @webgl.GL_INT || type_ == @webgl.GL_UNSIGNED_INT || gpu_is_int,
    id,
  )
  let is_storage = match attribute {
    Buffer(a) => a.kind is (StorageAttribute | StorageInstancedAttribute)
    _ => false
  }
  if is_storage {
    // create buffer for transform feedback use
    let buffer_gpu_dual = self._create_buffer(gl, buffer_type, array, usage)
    attribute_data = DualAttributeData::new(attribute_data, buffer_gpu_dual)
  }
  backend.set(buffer_attribute.key(), attribute_data)
}

///|
/// `updateAttribute( attribute )`.
pub fn WebGLAttributeUtils::update_attribute(
  self : WebGLAttributeUtils,
  attribute : @nodes.AttributeBuffer,
) -> Unit {
  let backend = self.backend
  let gl = backend.gl.unwrap()
  let array = attribute.array().unwrap()
  let buffer_attribute = attribute
  let buffer_data = backend.get(buffer_attribute.key())
  let update_ranges = match buffer_attribute {
    Buffer(a) => a.update_ranges
    Interleaved(a) => a.update_ranges
    GL(_) =>
      abort("TypeError: Cannot read properties of undefined (reading 'length')")
  }
  // the element buffer binding is part of the VAO state, so index buffers are updated
  // via the copy target to keep the bound VAO intact
  let buffer_type = _webgl_record_int(buffer_data, "bufferType")
  let target = if buffer_type == @webgl.GL_ELEMENT_ARRAY_BUFFER {
    @webgl.GL_COPY_WRITE_BUFFER
  } else {
    buffer_type
  }
  gl.bind_buffer(target, _webgl_record_handle(buffer_data, "bufferGPU"))
  if update_ranges.length() == 0 {
    // Not using update ranges
    gl.buffer_sub_data(target, 0, array)
  } else {
    for range in update_ranges {
      gl.buffer_sub_data_range(
        target,
        range.start * array.bytes_per_element(),
        array,
        range.start,
        range.count,
      )
    }
    match buffer_attribute {
      Buffer(a) => a.clear_update_ranges()
      Interleaved(a) => a.clear_update_ranges()
      GL(_) => ()
    }
  }
  gl.bind_buffer(target, None)
  buffer_data.set("version", @core.JsValue::of(buffer_attribute.version()))
}

///|
extern "js" fn _webgl_record_buffers(
  record : @core.JsValue,
) -> FixedArray[@webgl.GLBuffer] = "(r) => r.buffers"

///|
/// `destroyAttribute( attribute )`.
pub fn WebGLAttributeUtils::destroy_attribute(
  self : WebGLAttributeUtils,
  attribute : @nodes.AttributeBuffer,
) -> Unit {
  let backend = self.backend
  let gl = backend.gl.unwrap()
  let buffer_attribute = attribute
  let attribute_data = backend.get(buffer_attribute.key())
  if !attribute_data.get("buffers").is_undefined() {
    // storage attributes hold a second buffer for transform feedback
    for buffer in _webgl_record_buffers(attribute_data) {
      gl.delete_buffer(buffer)
    }
  } else {
    gl.delete_buffer(attribute_data.get("bufferGPU").cast())
  }
  backend.delete(buffer_attribute.key())
}

///|
/// `async getArrayBufferAsync( attribute, target = null, offset = 0, count = - 1 )`:
/// calls back with the `ArrayBuffer`, or the `ReadbackBuffer` when one is given.
pub fn WebGLAttributeUtils::get_array_buffer_async(
  self : WebGLAttributeUtils,
  attribute : @nodes.AttributeBuffer,
  target : @nodes.ReadbackBuffer?,
  offset : Int32,
  count : Int32,
  on_done : (@core.JsValue) -> Unit,
) -> Unit {
  let backend = self.backend
  let gl = backend.gl.unwrap()
  let buffer_attribute = attribute
  let attribute_info = backend.get(buffer_attribute.key())
  let buffer_gpu : @webgl.GLBuffer? = _webgl_record_handle(
    attribute_info, "bufferGPU",
  )
  let byte_length = if count == -1 {
    _webgl_record_int(attribute_info, "byteLength") - offset
  } else {
    count
  }
  // read the data back
  let dst_buffer = match target {
    None => _webgl_new_uint8_array(byte_length)
    Some(target) => {
      if target._mapped == true {
        abort(
          "THREE.WebGPURenderer: ReadbackBuffer must be released before being used again.",
        )
      }
      let release_callback : Ref[(@core.Event) -> Unit] = Ref(fn(_) {  })
      release_callback.val = fn(_) {
        target.buffer = None
        target._mapped = false
        @core.EventSource::remove_event_listener(
          target,
          "release",
          release_callback.val,
        )
        @core.EventSource::remove_event_listener(
          target,
          "dispose",
          release_callback.val,
        )
      }
      @core.EventSource::add_event_listener(
        target,
        "release",
        release_callback.val,
      )
      @core.EventSource::add_event_listener(
        target,
        "dispose",
        release_callback.val,
      )
      // WebGL has no concept of a "mapped" data buffer so we create a new buffer, instead.
      let dst = _webgl_new_uint8_array(byte_length)
      target.buffer = Some(_webgl_array_buffer_of(dst))
      dst
    }
  }
  // Ensure the buffer is bound before reading
  gl.bind_buffer(@webgl.GL_COPY_READ_BUFFER, buffer_gpu)
  gl.get_buffer_sub_data(@webgl.GL_COPY_READ_BUFFER, offset, dst_buffer)
  gl.bind_buffer(@webgl.GL_COPY_READ_BUFFER, None)
  gl.bind_buffer(@webgl.GL_COPY_WRITE_BUFFER, None)
  // return the appropriate type
  match target {
    Some(t) => on_done(@core.JsValue::of(t))
    None => on_done(_webgl_array_buffer_of(dst_buffer))
  }
}

///|
/// `_createBuffer( gl, bufferType, array, usage )`.
fn WebGLAttributeUtils::_create_buffer(
  self : WebGLAttributeUtils,
  gl : @webgl.WebGL2RenderingContext,
  buffer_type : Int32,
  array : @core.TypedArray,
  usage : Int32,
) -> @webgl.GLBuffer {
  let buffer_gpu = gl.create_buffer()
  // the element buffer binding is part of the VAO state, so the bound VAO must not be affected.
  // the first binding defines the buffer type so the copy target can not be used here
  let state = self.backend.state.unwrap()
  if buffer_type == @webgl.GL_ELEMENT_ARRAY_BUFFER &&
    state.current_vao is Some(_) {
    state.reset_vertex_state()
  }
  gl.bind_buffer(buffer_type, Some(buffer_gpu))
  gl.buffer_data(buffer_type, array, usage)
  gl.bind_buffer(buffer_type, None)
  buffer_gpu
}
