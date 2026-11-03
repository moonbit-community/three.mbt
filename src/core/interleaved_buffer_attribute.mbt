// Upstream src/core/InterleavedBufferAttribute.js.

///|
let _interleaved_buffer_attribute_vector : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
pub fn InterleavedBufferAttribute::new(
  interleaved_buffer : InterleavedBuffer,
  item_size : Int32,
  offset : Int32,
  normalized~ : Bool = false,
) -> InterleavedBufferAttribute {
  {
    name: "",
    data: interleaved_buffer,
    item_size,
    offset,
    normalized,
    _normalization_scale: @math.get_normalization_scale(
      interleaved_buffer.array.kind(),
    ),
  }
}

///|
/// Upstream's `count` getter.
pub fn InterleavedBufferAttribute::count(
  self : InterleavedBufferAttribute,
) -> Int32 {
  self.data.count
}

///|
/// Upstream's `array` getter.
pub fn InterleavedBufferAttribute::array(
  self : InterleavedBufferAttribute,
) -> TypedArray {
  self.data.array
}

///|
/// Upstream's `needsUpdate` setter.
pub fn InterleavedBufferAttribute::set_needs_update(
  self : InterleavedBufferAttribute,
  value : Bool,
) -> Unit {
  self.data.set_needs_update(value)
}

///|
pub fn InterleavedBufferAttribute::apply_matrix4(
  self : InterleavedBufferAttribute,
  m : @math.Matrix4,
) -> InterleavedBufferAttribute {
  for i in 0..<self.count() {
    let v = _interleaved_buffer_attribute_vector.from_buffer_attribute(self, i)
    ignore(v.apply_matrix4(m))
    ignore(self.set_xyz(i, v.x, v.y, v.z))
  }
  self
}

///|
pub fn InterleavedBufferAttribute::apply_normal_matrix(
  self : InterleavedBufferAttribute,
  m : @math.Matrix3,
) -> InterleavedBufferAttribute {
  for i in 0..<self.count() {
    let v = _interleaved_buffer_attribute_vector.from_buffer_attribute(self, i)
    ignore(v.apply_normal_matrix(m))
    ignore(self.set_xyz(i, v.x, v.y, v.z))
  }
  self
}

///|
pub fn InterleavedBufferAttribute::transform_direction(
  self : InterleavedBufferAttribute,
  m : @math.Matrix4,
) -> InterleavedBufferAttribute {
  for i in 0..<self.count() {
    let v = _interleaved_buffer_attribute_vector.from_buffer_attribute(self, i)
    ignore(v.transform_direction(m))
    ignore(self.set_xyz(i, v.x, v.y, v.z))
  }
  self
}

///|
pub fn InterleavedBufferAttribute::get_component(
  self : InterleavedBufferAttribute,
  index : Int32,
  component : Int32,
) -> Double {
  let value = self.data.array[index * self.data.stride + self.offset + component]
  if self.normalized {
    self._denormalize(value)
  } else {
    value
  }
}

///|
pub fn InterleavedBufferAttribute::set_component(
  self : InterleavedBufferAttribute,
  index : Int32,
  component : Int32,
  value : Double,
) -> InterleavedBufferAttribute {
  let value = if self.normalized { self._normalize(value) } else { value }
  self.data.array[index * self.data.stride + self.offset + component] = value
  self
}

///|
pub fn InterleavedBufferAttribute::set_x(
  self : InterleavedBufferAttribute,
  index : Int32,
  x : Double,
) -> InterleavedBufferAttribute {
  let x = if self.normalized { self._normalize(x) } else { x }
  self.data.array[index * self.data.stride + self.offset] = x
  self
}

///|
pub fn InterleavedBufferAttribute::get_x(
  self : InterleavedBufferAttribute,
  index : Int32,
) -> Double {
  let x = self.data.array[index * self.data.stride + self.offset]
  if self.normalized {
    self._denormalize(x)
  } else {
    x
  }
}

///|
pub fn InterleavedBufferAttribute::set_y(
  self : InterleavedBufferAttribute,
  index : Int32,
  y : Double,
) -> InterleavedBufferAttribute {
  let y = if self.normalized { self._normalize(y) } else { y }
  self.data.array[index * self.data.stride + self.offset + 1] = y
  self
}

///|
pub fn InterleavedBufferAttribute::get_y(
  self : InterleavedBufferAttribute,
  index : Int32,
) -> Double {
  let y = self.data.array[index * self.data.stride + self.offset + 1]
  if self.normalized {
    self._denormalize(y)
  } else {
    y
  }
}

///|
pub fn InterleavedBufferAttribute::set_z(
  self : InterleavedBufferAttribute,
  index : Int32,
  z : Double,
) -> InterleavedBufferAttribute {
  let z = if self.normalized { self._normalize(z) } else { z }
  self.data.array[index * self.data.stride + self.offset + 2] = z
  self
}

///|
pub fn InterleavedBufferAttribute::get_z(
  self : InterleavedBufferAttribute,
  index : Int32,
) -> Double {
  let z = self.data.array[index * self.data.stride + self.offset + 2]
  if self.normalized {
    self._denormalize(z)
  } else {
    z
  }
}

///|
pub fn InterleavedBufferAttribute::set_w(
  self : InterleavedBufferAttribute,
  index : Int32,
  w : Double,
) -> InterleavedBufferAttribute {
  let w = if self.normalized { self._normalize(w) } else { w }
  self.data.array[index * self.data.stride + self.offset + 3] = w
  self
}

///|
pub fn InterleavedBufferAttribute::get_w(
  self : InterleavedBufferAttribute,
  index : Int32,
) -> Double {
  let w = self.data.array[index * self.data.stride + self.offset + 3]
  if self.normalized {
    self._denormalize(w)
  } else {
    w
  }
}

///|
fn InterleavedBufferAttribute::_encode(
  self : InterleavedBufferAttribute,
  value : Double,
) -> Double {
  if self.normalized {
    self._normalize(value)
  } else {
    value
  }
}

///|
pub fn InterleavedBufferAttribute::set_xy(
  self : InterleavedBufferAttribute,
  index : Int32,
  x : Double,
  y : Double,
) -> InterleavedBufferAttribute {
  let index = index * self.data.stride + self.offset
  self.data.array[index + 0] = self._encode(x)
  self.data.array[index + 1] = self._encode(y)
  self
}

///|
pub fn InterleavedBufferAttribute::set_xyz(
  self : InterleavedBufferAttribute,
  index : Int32,
  x : Double,
  y : Double,
  z : Double,
) -> InterleavedBufferAttribute {
  let index = index * self.data.stride + self.offset
  self.data.array[index + 0] = self._encode(x)
  self.data.array[index + 1] = self._encode(y)
  self.data.array[index + 2] = self._encode(z)
  self
}

///|
pub fn InterleavedBufferAttribute::set_xyzw(
  self : InterleavedBufferAttribute,
  index : Int32,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> InterleavedBufferAttribute {
  let index = index * self.data.stride + self.offset
  self.data.array[index + 0] = self._encode(x)
  self.data.array[index + 1] = self._encode(y)
  self.data.array[index + 2] = self._encode(z)
  self.data.array[index + 3] = self._encode(w)
  self
}

///|
fn InterleavedBufferAttribute::_deinterleaved(
  self : InterleavedBufferAttribute,
) -> Array[Double] {
  let array = []
  for i in 0..<self.count() {
    let index = i * self.data.stride + self.offset
    for j in 0..<self.item_size {
      array.push(self.data.array[index + j])
    }
  }
  array
}

///|
/// Without `data` this de-interleaves into a `BufferAttribute`, as upstream.
pub fn InterleavedBufferAttribute::clone(
  self : InterleavedBufferAttribute,
  data? : AttributeCloneData,
) -> GeometryAttribute {
  match data {
    None => {
      log(
        "InterleavedBufferAttribute.clone(): Cloning an interleaved buffer attribute will de-interleave buffer data.",
      )
      Buffer(
        BufferAttribute::new(
          self.data.array.new_like(self._deinterleaved()),
          self.item_size,
          normalized=self.normalized,
        ),
      )
    }
    Some(data) => {
      let interleaved = match data.interleaved_buffers.get(self.data.uuid) {
        Some(buffer) => buffer
        None => {
          let buffer = self.data.clone(data)
          data.interleaved_buffers[self.data.uuid] = buffer
          buffer
        }
      }
      Interleaved(
        InterleavedBufferAttribute::new(
          interleaved,
          self.item_size,
          self.offset,
          normalized=self.normalized,
        ),
      )
    }
  }
}

///|
/// `data` is the object shared buffers are collected in, as upstream.
pub fn InterleavedBufferAttribute::to_json(
  self : InterleavedBufferAttribute,
  data? : Map[String, Json],
) -> Json {
  match data {
    None => {
      log(
        "InterleavedBufferAttribute.toJSON(): Serializing an interleaved buffer attribute will de-interleave buffer data.",
      )
      // de-interleave data and save it as an ordinary buffer attribute for now
      Json::object({
        "itemSize": json_int(self.item_size),
        "type": Json::string(self.data.array.type_name()),
        "array": json_numbers(self._deinterleaved()),
        "normalized": Json::boolean(self.normalized),
      })
    }
    Some(data) => {
      // save as true interleaved attribute
      let interleaved_buffers = match data.get("interleavedBuffers") {
        Some(Object(interleaved_buffers)) => interleaved_buffers
        _ => {
          let interleaved_buffers = Map([])
          data["interleavedBuffers"] = Json::object(interleaved_buffers)
          interleaved_buffers
        }
      }
      if !interleaved_buffers.contains(self.data.uuid) {
        interleaved_buffers[self.data.uuid] = self.data.to_json(data)
      }
      Json::object({
        "isInterleavedBufferAttribute": Json::boolean(true),
        "itemSize": json_int(self.item_size),
        "data": Json::string(self.data.uuid),
        "offset": json_int(self.offset),
        "normalized": Json::boolean(self.normalized),
      })
    }
  }
}

///|
fn InterleavedBufferAttribute::_denormalize(
  self : InterleavedBufferAttribute,
  value : Double,
) -> Double {
  match self._normalization_scale {
    Some(scale) => utils_math_max(value / scale, -1.0)
    None => @math.denormalize(value, self.data.array.kind())
  }
}

///|
fn InterleavedBufferAttribute::_normalize(
  self : InterleavedBufferAttribute,
  value : Double,
) -> Double {
  match self._normalization_scale {
    Some(scale) => utils_math_round(value * scale)
    None => @math.normalize(value, self.data.array.kind())
  }
}

///|
pub impl @math.BufferAttributeLike for InterleavedBufferAttribute with fn get_x(
  self,
  index,
) {
  InterleavedBufferAttribute::get_x(self, index)
}

///|
pub impl @math.BufferAttributeLike for InterleavedBufferAttribute with fn get_y(
  self,
  index,
) {
  InterleavedBufferAttribute::get_y(self, index)
}

///|
pub impl @math.BufferAttributeLike for InterleavedBufferAttribute with fn get_z(
  self,
  index,
) {
  InterleavedBufferAttribute::get_z(self, index)
}

///|
pub impl @math.BufferAttributeLike for InterleavedBufferAttribute with fn get_w(
  self,
  index,
) {
  InterleavedBufferAttribute::get_w(self, index)
}
