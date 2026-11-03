// Upstream src/core/BufferAttribute.js: `BufferAttribute`, the typed subclasses, and
// (via `kind`) `Float16BufferAttribute`. The typed subclasses are marker types whose
// `new` returns a `BufferAttribute`, like the math interpolants.

///|
let _buffer_attribute_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _buffer_attribute_vector2 : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _buffer_attribute_id : Ref[Int32] = Ref(0)

///|
fn buffer_attribute_make(
  array : TypedArray,
  item_size : Int32,
  normalized : Bool,
  kind : BufferAttributeKind,
  mesh_per_attribute : Int32,
) -> BufferAttribute {
  let id = _buffer_attribute_id.val
  _buffer_attribute_id.val += 1
  {
    id,
    dispatcher: EventDispatcher::new(),
    name: "",
    array,
    item_size,
    count: array.length() / item_size,
    normalized,
    usage: StaticDrawUsage,
    update_ranges: [],
    gpu_type: FloatType,
    version: 0,
    on_upload_callback: () => (),
    _normalization_scale: @math.get_normalization_scale(array.kind()),
    kind,
    mesh_per_attribute,
  }
}

///|
pub fn BufferAttribute::new(
  array : TypedArray,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  buffer_attribute_make(array, item_size, normalized, PlainAttribute, 1)
}

///|
pub impl EventSource for BufferAttribute with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl EventSource for BufferAttribute with fn event_target(self) {
  BufferAttribute(self)
}

///|
pub extend BufferAttribute with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// Upstream's `needsUpdate` setter.
pub fn BufferAttribute::set_needs_update(
  self : BufferAttribute,
  value : Bool,
) -> Unit {
  if value {
    self.version += 1
  }
}

///|
pub fn BufferAttribute::set_usage(
  self : BufferAttribute,
  value : Int32,
) -> BufferAttribute {
  self.usage = value
  self
}

///|
pub fn BufferAttribute::add_update_range(
  self : BufferAttribute,
  start : Int32,
  count : Int32,
) -> Unit {
  self.update_ranges.push({ start, count, })
}

///|
pub fn BufferAttribute::clear_update_ranges(self : BufferAttribute) -> Unit {
  self.update_ranges.clear()
}

///|
pub fn BufferAttribute::copy(
  self : BufferAttribute,
  source : BufferAttribute,
) -> BufferAttribute {
  self.name = source.name
  self.array = source.array.clone()
  self.item_size = source.item_size
  self.count = source.count
  self.normalized = source.normalized
  self.usage = source.usage
  self.gpu_type = source.gpu_type
  self._normalization_scale = source._normalization_scale
  if self.is_instanced_buffer_attribute() {
    self.mesh_per_attribute = source.mesh_per_attribute
  }
  self
}

///|
pub fn BufferAttribute::copy_at(
  self : BufferAttribute,
  index1 : Int32,
  attribute : BufferAttribute,
  index2 : Int32,
) -> BufferAttribute {
  let index1 = index1 * self.item_size
  let index2 = index2 * attribute.item_size
  for i in 0..<self.item_size {
    self.array[index1 + i] = attribute.array[index2 + i]
  }
  self
}

///|
pub fn[A : TypedArrayInit] BufferAttribute::copy_array(
  self : BufferAttribute,
  array : A,
) -> BufferAttribute {
  self.array.set_from(array)
  self
}

///|
pub fn BufferAttribute::apply_matrix3(
  self : BufferAttribute,
  m : @math.Matrix3,
) -> BufferAttribute {
  if self.item_size == 2 {
    for i in 0..<self.count {
      let v = _buffer_attribute_vector2.from_buffer_attribute(self, i)
      ignore(v.apply_matrix3(m))
      ignore(self.set_xy(i, v.x, v.y))
    }
  } else if self.item_size == 3 {
    for i in 0..<self.count {
      let v = _buffer_attribute_vector.from_buffer_attribute(self, i)
      ignore(v.apply_matrix3(m))
      ignore(self.set_xyz(i, v.x, v.y, v.z))
    }
  }
  self
}

///|
pub fn BufferAttribute::apply_matrix4(
  self : BufferAttribute,
  m : @math.Matrix4,
) -> BufferAttribute {
  for i in 0..<self.count {
    let v = _buffer_attribute_vector.from_buffer_attribute(self, i)
    ignore(v.apply_matrix4(m))
    ignore(self.set_xyz(i, v.x, v.y, v.z))
  }
  self
}

///|
pub fn BufferAttribute::apply_normal_matrix(
  self : BufferAttribute,
  m : @math.Matrix3,
) -> BufferAttribute {
  for i in 0..<self.count {
    let v = _buffer_attribute_vector.from_buffer_attribute(self, i)
    ignore(v.apply_normal_matrix(m))
    ignore(self.set_xyz(i, v.x, v.y, v.z))
  }
  self
}

///|
pub fn BufferAttribute::transform_direction(
  self : BufferAttribute,
  m : @math.Matrix4,
) -> BufferAttribute {
  for i in 0..<self.count {
    let v = _buffer_attribute_vector.from_buffer_attribute(self, i)
    ignore(v.transform_direction(m))
    ignore(self.set_xyz(i, v.x, v.y, v.z))
  }
  self
}

///|
pub fn[A : TypedArrayInit] BufferAttribute::set(
  self : BufferAttribute,
  value : A,
  offset~ : Int32 = 0,
) -> BufferAttribute {
  // Matching BufferAttribute constructor, do not normalize the array.
  self.array.set_from(value, offset~)
  self
}

///|
pub fn BufferAttribute::get_component(
  self : BufferAttribute,
  index : Int32,
  component : Int32,
) -> Double {
  let value = self.array[index * self.item_size + component]
  if self.normalized {
    self._denormalize(value)
  } else {
    value
  }
}

///|
pub fn BufferAttribute::set_component(
  self : BufferAttribute,
  index : Int32,
  component : Int32,
  value : Double,
) -> BufferAttribute {
  let value = if self.normalized { self._normalize(value) } else { value }
  self.array[index * self.item_size + component] = value
  self
}

///|
pub fn BufferAttribute::get_x(self : BufferAttribute, index : Int32) -> Double {
  if self.kind is Float16Attribute {
    let x = from_half_float(self.array[index * self.item_size])
    if self.normalized {
      @math.denormalize(x, self.array.kind())
    } else {
      x
    }
  } else {
    let x = self.array[index * self.item_size]
    if self.normalized {
      self._denormalize(x)
    } else {
      x
    }
  }
}

///|
pub fn BufferAttribute::set_x(
  self : BufferAttribute,
  index : Int32,
  x : Double,
) -> BufferAttribute {
  self.array[index * self.item_size] = self._encode(x)
  self
}

///|
pub fn BufferAttribute::get_y(self : BufferAttribute, index : Int32) -> Double {
  if self.kind is Float16Attribute {
    let y = from_half_float(self.array[index * self.item_size + 1])
    if self.normalized {
      @math.denormalize(y, self.array.kind())
    } else {
      y
    }
  } else {
    let y = self.array[index * self.item_size + 1]
    if self.normalized {
      self._denormalize(y)
    } else {
      y
    }
  }
}

///|
pub fn BufferAttribute::set_y(
  self : BufferAttribute,
  index : Int32,
  y : Double,
) -> BufferAttribute {
  self.array[index * self.item_size + 1] = self._encode(y)
  self
}

///|
pub fn BufferAttribute::get_z(self : BufferAttribute, index : Int32) -> Double {
  if self.kind is Float16Attribute {
    let z = from_half_float(self.array[index * self.item_size + 2])
    if self.normalized {
      @math.denormalize(z, self.array.kind())
    } else {
      z
    }
  } else {
    let z = self.array[index * self.item_size + 2]
    if self.normalized {
      self._denormalize(z)
    } else {
      z
    }
  }
}

///|
pub fn BufferAttribute::set_z(
  self : BufferAttribute,
  index : Int32,
  z : Double,
) -> BufferAttribute {
  self.array[index * self.item_size + 2] = self._encode(z)
  self
}

///|
pub fn BufferAttribute::get_w(self : BufferAttribute, index : Int32) -> Double {
  if self.kind is Float16Attribute {
    let w = from_half_float(self.array[index * self.item_size + 3])
    if self.normalized {
      @math.denormalize(w, self.array.kind())
    } else {
      w
    }
  } else {
    let w = self.array[index * self.item_size + 3]
    if self.normalized {
      self._denormalize(w)
    } else {
      w
    }
  }
}

///|
pub fn BufferAttribute::set_w(
  self : BufferAttribute,
  index : Int32,
  w : Double,
) -> BufferAttribute {
  self.array[index * self.item_size + 3] = self._encode(w)
  self
}

///|
pub fn BufferAttribute::set_xy(
  self : BufferAttribute,
  index : Int32,
  x : Double,
  y : Double,
) -> BufferAttribute {
  let index = index * self.item_size
  self.array[index + 0] = self._encode(x)
  self.array[index + 1] = self._encode(y)
  self
}

///|
pub fn BufferAttribute::set_xyz(
  self : BufferAttribute,
  index : Int32,
  x : Double,
  y : Double,
  z : Double,
) -> BufferAttribute {
  let index = index * self.item_size
  self.array[index + 0] = self._encode(x)
  self.array[index + 1] = self._encode(y)
  self.array[index + 2] = self._encode(z)
  self
}

///|
pub fn BufferAttribute::set_xyzw(
  self : BufferAttribute,
  index : Int32,
  x : Double,
  y : Double,
  z : Double,
  w : Double,
) -> BufferAttribute {
  let index = index * self.item_size
  self.array[index + 0] = self._encode(x)
  self.array[index + 1] = self._encode(y)
  self.array[index + 2] = self._encode(z)
  self.array[index + 3] = self._encode(w)
  self
}

///|
pub fn BufferAttribute::on_upload(
  self : BufferAttribute,
  callback : () -> Unit,
) -> BufferAttribute {
  self.on_upload_callback = callback
  self
}

///|
pub fn BufferAttribute::clone(self : BufferAttribute) -> BufferAttribute {
  buffer_attribute_make(
    self.array,
    self.item_size,
    false,
    self.kind,
    self.mesh_per_attribute,
  ).copy(self)
}

///|
pub fn BufferAttribute::to_json(self : BufferAttribute) -> Json {
  let data : Map[String, Json] = {
    "itemSize": json_int(self.item_size),
    "type": Json::string(self.array.type_name()),
    "array": json_numbers(self.array.to_array()),
    "normalized": Json::boolean(self.normalized),
    "name": Json::string(self.name),
    "usage": json_int(self.usage),
    "gpuType": json_int(self.gpu_type),
  }
  if self.is_instanced_buffer_attribute() {
    data["meshPerAttribute"] = json_int(self.mesh_per_attribute)
    data["isInstancedBufferAttribute"] = Json::boolean(true)
  }
  Json::object(data)
}

///|
pub fn BufferAttribute::dispose(self : BufferAttribute) -> Unit {
  self.dispatch_event(Event::new("dispose"))
}

///|
fn BufferAttribute::_denormalize(
  self : BufferAttribute,
  value : Double,
) -> Double {
  match self._normalization_scale {
    Some(scale) => utils_math_max(value / scale, -1.0)
    None => @math.denormalize(value, self.array.kind())
  }
}

///|
fn BufferAttribute::_normalize(
  self : BufferAttribute,
  value : Double,
) -> Double {
  match self._normalization_scale {
    Some(scale) => utils_math_round(value * scale)
    None => @math.normalize(value, self.array.kind())
  }
}

///|
/// What the `setX`-style methods store: normalized if needed, half float if `Float16`.
fn BufferAttribute::_encode(self : BufferAttribute, value : Double) -> Double {
  if self.kind is Float16Attribute {
    to_half_float(
      if self.normalized {
        @math.normalize(value, self.array.kind())
      } else {
        value
      },
    )
  } else if self.normalized {
    self._normalize(value)
  } else {
    value
  }
}

///|
/// `isFloat16BufferAttribute`.
pub fn BufferAttribute::is_float16_buffer_attribute(
  self : BufferAttribute,
) -> Bool {
  self.kind is Float16Attribute
}

///|
/// `isInstancedBufferAttribute`.
pub fn BufferAttribute::is_instanced_buffer_attribute(
  self : BufferAttribute,
) -> Bool {
  self.kind is (InstancedAttribute | StorageInstancedAttribute)
}

///|
pub impl @math.BufferAttributeLike for BufferAttribute with fn get_x(
  self,
  index,
) {
  BufferAttribute::get_x(self, index)
}

///|
pub impl @math.BufferAttributeLike for BufferAttribute with fn get_y(
  self,
  index,
) {
  BufferAttribute::get_y(self, index)
}

///|
pub impl @math.BufferAttributeLike for BufferAttribute with fn get_z(
  self,
  index,
) {
  BufferAttribute::get_z(self, index)
}

///|
pub impl @math.BufferAttributeLike for BufferAttribute with fn get_w(
  self,
  index,
) {
  BufferAttribute::get_w(self, index)
}

///|
/// `new Int8BufferAttribute( array, itemSize, normalized )`.
#external
pub type Int8BufferAttribute

///|
pub fn[A : TypedArrayInit] Int8BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::int8(array), item_size, normalized~)
}

///|
/// `new Uint8BufferAttribute( array, itemSize, normalized )`.
#external
pub type Uint8BufferAttribute

///|
pub fn[A : TypedArrayInit] Uint8BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::uint8(array), item_size, normalized~)
}

///|
/// `new Uint8ClampedBufferAttribute( array, itemSize, normalized )`.
#external
pub type Uint8ClampedBufferAttribute

///|
pub fn[A : TypedArrayInit] Uint8ClampedBufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::uint8_clamped(array), item_size, normalized~)
}

///|
/// `new Int16BufferAttribute( array, itemSize, normalized )`.
#external
pub type Int16BufferAttribute

///|
pub fn[A : TypedArrayInit] Int16BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::int16(array), item_size, normalized~)
}

///|
/// `new Uint16BufferAttribute( array, itemSize, normalized )`.
#external
pub type Uint16BufferAttribute

///|
pub fn[A : TypedArrayInit] Uint16BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::uint16(array), item_size, normalized~)
}

///|
/// `new Int32BufferAttribute( array, itemSize, normalized )`.
#external
pub type Int32BufferAttribute

///|
pub fn[A : TypedArrayInit] Int32BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::int32(array), item_size, normalized~)
}

///|
/// `new Uint32BufferAttribute( array, itemSize, normalized )`.
#external
pub type Uint32BufferAttribute

///|
pub fn[A : TypedArrayInit] Uint32BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::uint32(array), item_size, normalized~)
}

///|
/// `new Float32BufferAttribute( array, itemSize, normalized )`.
#external
pub type Float32BufferAttribute

///|
pub fn[A : TypedArrayInit] Float32BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  BufferAttribute::new(TypedArray::float32(array), item_size, normalized~)
}

///|
/// `new Float16BufferAttribute( array, itemSize, normalized )`: half float bits in a
/// `Uint16Array`.
#external
pub type Float16BufferAttribute

///|
pub fn[A : TypedArrayInit] Float16BufferAttribute::new(
  array : A,
  item_size : Int32,
  normalized~ : Bool = false,
) -> BufferAttribute {
  buffer_attribute_make(
    TypedArray::uint16(array),
    item_size,
    normalized,
    Float16Attribute,
    1,
  )
}
