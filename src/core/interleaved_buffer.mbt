// Upstream src/core/InterleavedBuffer.js.

///|
pub fn InterleavedBuffer::new(
  array : TypedArray,
  stride : Int32,
) -> InterleavedBuffer {
  {
    array,
    stride,
    count: array.length() / stride,
    usage: StaticDrawUsage,
    update_ranges: [],
    version: 0,
    uuid: @math.generate_uuid(),
    on_upload_callback: () => (),
    is_instanced_interleaved_buffer: false,
    mesh_per_attribute: 1,
  }
}

///|
/// Upstream's `needsUpdate` setter.
pub fn InterleavedBuffer::set_needs_update(
  self : InterleavedBuffer,
  value : Bool,
) -> Unit {
  if value {
    self.version += 1
  }
}

///|
pub fn InterleavedBuffer::set_usage(
  self : InterleavedBuffer,
  value : Int32,
) -> InterleavedBuffer {
  self.usage = value
  self
}

///|
pub fn InterleavedBuffer::add_update_range(
  self : InterleavedBuffer,
  start : Int32,
  count : Int32,
) -> Unit {
  self.update_ranges.push({ start, count, })
}

///|
pub fn InterleavedBuffer::clear_update_ranges(self : InterleavedBuffer) -> Unit {
  self.update_ranges.clear()
}

///|
pub fn InterleavedBuffer::copy(
  self : InterleavedBuffer,
  source : InterleavedBuffer,
) -> InterleavedBuffer {
  self.array = source.array.clone()
  self.count = source.count
  self.stride = source.stride
  self.usage = source.usage
  if self.is_instanced_interleaved_buffer {
    self.mesh_per_attribute = source.mesh_per_attribute
  }
  self
}

///|
pub fn InterleavedBuffer::copy_at(
  self : InterleavedBuffer,
  index1 : Int32,
  interleaved_buffer : InterleavedBuffer,
  index2 : Int32,
) -> InterleavedBuffer {
  let index1 = index1 * self.stride
  let index2 = index2 * interleaved_buffer.stride
  for i in 0..<self.stride {
    self.array[index1 + i] = interleaved_buffer.array[index2 + i]
  }
  self
}

///|
pub fn[A : TypedArrayInit] InterleavedBuffer::set(
  self : InterleavedBuffer,
  value : A,
  offset~ : Int32 = 0,
) -> InterleavedBuffer {
  self.array.set_from(value, offset~)
  self
}

///|
pub fn InterleavedBuffer::clone(
  self : InterleavedBuffer,
  data : AttributeCloneData,
) -> InterleavedBuffer {
  let key = interleaved_buffer_array_key(self.array)
  let buffer = match data.array_buffers.get(key) {
    Some(buffer) => buffer
    None => {
      let buffer = self.array.slice().buffer()
      data.array_buffers[key] = buffer
      buffer
    }
  }
  let array = self.array.new_like_from_buffer(buffer)
  let ib = InterleavedBuffer::new(array, self.stride)
  ib.is_instanced_interleaved_buffer = self.is_instanced_interleaved_buffer
  ib.mesh_per_attribute = self.mesh_per_attribute
  ignore(ib.set_usage(self.usage))
  ib
}

///|
pub fn InterleavedBuffer::on_upload(
  self : InterleavedBuffer,
  callback : () -> Unit,
) -> InterleavedBuffer {
  self.on_upload_callback = callback
  self
}

///|
/// `data` is the object `arrayBuffers` is collected in, as upstream.
pub fn InterleavedBuffer::to_json(
  self : InterleavedBuffer,
  data : Map[String, Json],
) -> Json {
  let array_buffers = match data.get("arrayBuffers") {
    Some(Object(array_buffers)) => array_buffers
    _ => {
      let array_buffers = Map([])
      data["arrayBuffers"] = Json::object(array_buffers)
      array_buffers
    }
  }
  let key = interleaved_buffer_array_key(self.array)
  if !array_buffers.contains(key) {
    let words = TypedArray::view_by_name(
      "Uint32Array",
      self.array.slice().buffer(),
    )
    array_buffers[key] = json_numbers(words.to_array())
  }
  let json : Map[String, Json] = {
    "uuid": Json::string(self.uuid),
    "buffer": Json::string(key),
    "type": Json::string(self.array.type_name()),
    "stride": json_int(self.stride),
    "usage": json_int(self.usage),
  }
  if self.is_instanced_interleaved_buffer {
    json["isInstancedInterleavedBuffer"] = Json::boolean(true)
    json["meshPerAttribute"] = json_int(self.mesh_per_attribute)
  }
  Json::object(json)
}

///|
/// The key under which the data of `array` is shared when cloning or serializing: views
/// at different offsets into one array buffer share only over the same range.
fn interleaved_buffer_array_key(array : TypedArray) -> String {
  let buffer = array.buffer()
  let uuid = buffer.uuid()
  if array.byte_offset() == 0 && array.byte_length() == buffer.byte_length() {
    uuid
  } else {
    "\{uuid}:\{array.byte_offset()}:\{array.byte_length()}"
  }
}
