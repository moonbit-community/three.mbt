// Upstream src/renderers/webgl/WebGLAttributes.js.

///|
/// `{ buffer, type, bytesPerElement, version, size }`.
pub(all) struct WebGLAttributeBuffer {
  buffer : GLBuffer
  type_ : Int32
  bytes_per_element : Int32
  mut version : Int32
  /// `array.byteLength` at creation; `None` for a `GLBufferAttribute`
  size : Int32?
}

///|
pub struct WebGLAttributes {
  gl : WebGL2RenderingContext
  /// keyed by the `BufferAttribute`, `InterleavedBuffer` or `GLBufferAttribute`
  buffers : WeakMap[@core.JsValue, WebGLAttributeBuffer]
}

///|
/// `new WebGLAttributes( gl )`.
pub fn WebGLAttributes::new(gl : WebGL2RenderingContext) -> WebGLAttributes {
  { gl, buffers: WeakMap::new(), }
}

///|
/// The object upstream keys the buffer by: `attribute.data` for interleaved attributes.
fn webgl_attributes_key(attribute : @core.GeometryAttribute) -> @core.JsValue {
  match attribute {
    Buffer(a) => @core.JsValue::of(a)
    // `attribute.data`, which may be a buffer attribute
    Interleaved(a) =>
      match interleaved_buffer_source(a.data) {
        Some(source) => @core.JsValue::of(source)
        None => @core.JsValue::of(a.data)
      }
    GL(a) => @core.JsValue::of(a)
  }
}

///|
/// A `BufferAttribute` or `InterleavedBuffer`: what gets uploaded.
priv enum WebGLAttributeSource {
  Plain(@core.BufferAttribute)
  Data(@core.InterleavedBuffer)
}

///|
fn WebGLAttributeSource::array(self : WebGLAttributeSource) -> @core.TypedArray {
  match self {
    Plain(a) => a.array
    Data(a) => a.array
  }
}

///|
fn WebGLAttributeSource::version(self : WebGLAttributeSource) -> Int32 {
  match self {
    Plain(a) => a.version
    Data(a) => a.version
  }
}

///|
fn WebGLAttributeSource::on_upload_callback(
  self : WebGLAttributeSource,
) -> Unit {
  match self {
    Plain(a) => (a.on_upload_callback)()
    Data(a) => (a.on_upload_callback)()
  }
}

///|
fn WebGLAttributeSource::update_ranges(
  self : WebGLAttributeSource,
) -> Array[@core.UpdateRange] {
  match self {
    Plain(a) => a.update_ranges
    Data(a) => a.update_ranges
  }
}

///|
fn WebGLAttributeSource::clear_update_ranges(
  self : WebGLAttributeSource,
) -> Unit {
  match self {
    Plain(a) => a.clear_update_ranges()
    Data(a) => a.clear_update_ranges()
  }
}

///|
fn WebGLAttributes::create_buffer(
  self : WebGLAttributes,
  attribute : WebGLAttributeSource,
  usage : Int32,
  buffer_type : Int32,
) -> WebGLAttributeBuffer {
  let gl = self.gl
  let array = attribute.array()
  let size = array.byte_length()
  let buffer = gl.create_buffer()
  gl.bind_buffer(buffer_type, Some(buffer))
  gl.buffer_data(buffer_type, array, usage)
  attribute.on_upload_callback()
  let type_ = match array.type_name() {
    "Float32Array" => GL_FLOAT
    "Float16Array" => GL_HALF_FLOAT
    "Uint16Array" =>
      if attribute is Plain(a) && a.is_float16_buffer_attribute() {
        GL_HALF_FLOAT
      } else {
        GL_UNSIGNED_SHORT
      }
    "Int16Array" => GL_SHORT
    "Uint32Array" => GL_UNSIGNED_INT
    "Int32Array" => GL_INT
    "Int8Array" => GL_BYTE
    "Uint8Array" => GL_UNSIGNED_BYTE
    "Uint8ClampedArray" => GL_UNSIGNED_BYTE
    name =>
      abort("THREE.WebGLAttributes: Unsupported buffer data format: " + name)
  }
  {
    buffer,
    type_,
    bytes_per_element: array.bytes_per_element(),
    version: attribute.version(),
    size: Some(size),
  }
}

///|
fn WebGLAttributes::update_buffer(
  self : WebGLAttributes,
  buffer : GLBuffer,
  attribute : WebGLAttributeSource,
  buffer_type : Int32,
) -> Unit {
  let gl = self.gl
  let array = attribute.array()
  let update_ranges = attribute.update_ranges()
  gl.bind_buffer(buffer_type, Some(buffer))
  if update_ranges.length() == 0 {
    // Not using update ranges
    gl.buffer_sub_data(buffer_type, 0, array)
  } else {
    // Before applying update ranges, we merge any adjacent / overlapping ranges to reduce
    // load on `gl.bufferSubData`, in place; this method clears the ranges once updated.
    stable_sort_by(update_ranges, (a, b) => (a.start - b.start).to_double())
    let mut merge_index = 0
    for i in 1..<update_ranges.length() {
      let previous_range = update_ranges[merge_index]
      let range = update_ranges[i]
      // We add one here to merge adjacent ranges. This is safe because ranges operate
      // over positive integers.
      if range.start <= previous_range.start + previous_range.count + 1 {
        previous_range.count = js_math_max(
          previous_range.count.to_double(),
          (range.start + range.count - previous_range.start).to_double(),
        ).to_int()
      } else {
        merge_index += 1
        update_ranges[merge_index] = range
      }
    }
    // Trim the array to only contain the merged ranges.
    truncate_array(update_ranges, merge_index + 1)
    let bytes_per_element = array.bytes_per_element()
    for range in update_ranges {
      gl.buffer_sub_data_range(
        buffer_type,
        range.start * bytes_per_element,
        array,
        range.start,
        range.count,
      )
    }
    attribute.clear_update_ranges()
  }
  attribute.on_upload_callback()
}

///|
/// `attributes.get( attribute )`.
pub fn WebGLAttributes::get(
  self : WebGLAttributes,
  attribute : @core.GeometryAttribute,
) -> WebGLAttributeBuffer? {
  self.buffers.get(webgl_attributes_key(attribute))
}

///|
/// `attributes.remove( attribute )`: deletes the GL buffer.
pub fn WebGLAttributes::remove(
  self : WebGLAttributes,
  attribute : @core.GeometryAttribute,
) -> Unit {
  let key = webgl_attributes_key(attribute)
  if self.buffers.get(key) is Some(data) {
    self.gl.delete_buffer(data.buffer)
    self.buffers.delete(key)
  }
}

///|
/// `attributes.update( attribute, bufferType )`: creates or refreshes the GL buffer.
pub fn WebGLAttributes::update(
  self : WebGLAttributes,
  attribute : @core.GeometryAttribute,
  buffer_type : Int32,
) -> Unit {
  let key = webgl_attributes_key(attribute)
  let source = match attribute {
    GL(a) => {
      match self.buffers.get(key) {
        Some(cached) if cached.version >= a.version => ()
        _ =>
          self.buffers.set(key, {
            buffer: a.buffer.cast(),
            type_: a.type_,
            bytes_per_element: a.element_size,
            version: a.version,
            size: None,
          })
      }
      return
    }
    Buffer(a) => Plain(a)
    Interleaved(a) =>
      match interleaved_buffer_source(a.data) {
        Some(source) => Plain(source)
        None => Data(a.data)
      }
  }
  match self.buffers.get(key) {
    None => {
      let usage = match source {
        Plain(a) => a.usage
        Data(a) => a.usage
      }
      self.buffers.set(key, self.create_buffer(source, usage, buffer_type))
    }
    Some(data) =>
      if data.version < source.version() {
        if data.size != Some(source.array().byte_length()) {
          abort(
            "THREE.WebGLAttributes: The size of the buffer attribute's array buffer does not match the original size. Resizing buffer attributes is not supported.",
          )
        }
        self.update_buffer(data.buffer, source, buffer_type)
        data.version = source.version()
      }
  }
}
