// renderers/common/UniformsGroup.js: a uniform buffer packing typed `Uniform`s with
// std140-style offsets. `values` mirrors the buffer with the JS values last written,
// compared with `!==`, as upstream (it holds unrounded numbers and booleans).

///|
extern "js" fn uniforms_group_strict_equal(
  a : @core.JsValue,
  b : @core.JsValue,
) -> Bool = "(a, b) => a === b"

///|
extern "js" fn uniforms_group_set_value(
  array : @core.TypedArray,
  index : Int32,
  value : @core.JsValue,
) -> Unit = "(a, i, v) => { a[i] = v; }"

///|
/// The `UniformsGroup` class payload.
pub(all) struct UniformsGroup {
  parent_ : UniformBuffer
  mut _values : Array[@core.JsValue]?
  mut uniforms : Array[Uniform]
  mut _update_range_cache : Map[Int32, @core.UpdateRange]
  mut _added_indices : Set[Int32]
}

///|
pub impl BindingClass for UniformsGroup with fn class_name(_) {
  "UniformsGroup"
}

///|
pub impl BindingClass for UniformsGroup with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for UniformsGroup with fn has_flag(self, flag) {
  flag == "isUniformsGroup" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for UniformsGroup with fn copy_class(self) {
  self.copy_payload()
}

///|
pub impl BindingClass for UniformsGroup with fn clear_update_ranges(
  self,
  binding,
) {
  self._added_indices.clear()
  self.parent_.clear_update_ranges(binding)
}

///|
pub impl BindingClass for UniformsGroup with fn buffer(self, binding) {
  let buffer_payload = self.parent_.parent_
  match buffer_payload._buffer {
    Some(buffer) => Some(buffer)
    None => {
      let byte_length = binding.byte_length()
      let buffer = @core.TypedArray::view_by_name(
        "Float32Array",
        @core.ArrayBuffer::new(byte_length),
      )
      buffer_payload._buffer = Some(buffer)
      Some(buffer)
    }
  }
}

///|
pub impl BindingClass for UniformsGroup with fn byte_length(self, binding) {
  let bytes_per_element = self.parent_.parent_.bytes_per_element
  let mut offset = 0 // global buffer offset in bytes
  for i, uniform in self.uniforms {
    let boundary = uniform.boundary
    if boundary == 0 {
      abort("UniformsGroup: \{binding.name} holds a uniform without a boundary")
    }
    let item_size = uniform.item_size * bytes_per_element // size of the uniform in bytes
    let chunk_offset = offset % GPU_CHUNK_BYTES // offset in the current chunk
    let chunk_padding = chunk_offset % boundary // required padding to match boundary
    let chunk_start = chunk_offset + chunk_padding // start position in the current chunk for the data
    offset += chunk_padding
    if chunk_start != 0 && GPU_CHUNK_BYTES - chunk_start < item_size {
      offset += GPU_CHUNK_BYTES - chunk_start
    }
    uniform.offset = offset / bytes_per_element
    uniform.index = i
    offset += item_size
  }
  (offset + GPU_CHUNK_BYTES - 1) / GPU_CHUNK_BYTES * GPU_CHUNK_BYTES
}

///|
pub impl BindingClass for UniformsGroup with fn update(self, binding) {
  let mut updated = false
  for uniform in self.uniforms {
    if binding.update_by_type(uniform) {
      updated = true
    }
  }
  updated
}

///|
pub impl BindingClass for UniformsGroup with fn release(self, binding) {
  self.parent_.release(binding)
  self._values = None
}

///|
pub impl BindingClass for UniformsGroup with fn clone(self, binding) {
  let clone = match self.parent() {
    Some(p) => p.clone(binding)
    None => binding.clone_base()
  }
  match UniformsGroup::of(clone) {
    Some(group) => {
      group.parent_.parent_._buffer = None
      group._values = None
      group.parent_.parent_._update_ranges = []
      group._update_range_cache = Map([])
      group._added_indices = Set([])
    }
    None => ()
  }
  clone
}

///|
/// The fields `Object.assign` copies (arrays, maps and sets are shared, as upstream).
pub fn UniformsGroup::copy_payload(self : UniformsGroup) -> UniformsGroup {
  {
    parent_: self.parent_.copy_payload(),
    _values: self._values,
    uniforms: self.uniforms,
    _update_range_cache: self._update_range_cache,
    _added_indices: self._added_indices,
  }
}

///|
/// The payload of `super( name )` for subclasses.
pub fn UniformsGroup::construct() -> UniformsGroup {
  {
    parent_: UniformBuffer::construct(None),
    _values: None,
    uniforms: [],
    _update_range_cache: Map([]),
    _added_indices: Set([]),
  }
}

///|
/// `new UniformsGroup( name )`.
pub fn UniformsGroup::new(name : String) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = UniformsGroup::construct()
  binding
}

///|
pub fn UniformsGroup::of(binding : Binding) -> UniformsGroup? {
  match binding.class_payload("UniformsGroup") {
    Some(p) => Some(p.cast())
    None => None
  }
}

///|
fn _uniforms_group(binding : Binding) -> UniformsGroup {
  match UniformsGroup::of(binding) {
    Some(group) => group
    None => abort("TypeError: \{binding.name} is not a UniformsGroup")
  }
}

///|
/// `uniformsGroup.uniforms`.
pub fn Binding::uniforms(self : Binding) -> Array[Uniform] {
  _uniforms_group(self).uniforms
}

///|
/// `addUniformUpdateRange( uniform )`.
pub fn Binding::add_uniform_update_range(
  self : Binding,
  uniform : Uniform,
) -> Unit {
  let group = _uniforms_group(self)
  let index = uniform.index
  if group._added_indices.contains(index) {
    return
  }
  let range = match group._update_range_cache.get(index) {
    Some(range) => range
    None => {
      let range : @core.UpdateRange = { start: 0, count: 0, }
      group._update_range_cache.set(index, range)
      range
    }
  }
  range.start = uniform.offset
  range.count = uniform.item_size
  group._added_indices.add(index)
  self.update_ranges().push(range)
}

///|
/// `addUniform( uniform )`.
pub fn Binding::add_uniform(self : Binding, uniform : Uniform) -> Binding {
  _uniforms_group(self).uniforms.push(uniform)
  self
}

///|
/// `removeUniform( uniform )`.
pub fn Binding::remove_uniform(self : Binding, uniform : Uniform) -> Binding {
  let uniforms = _uniforms_group(self).uniforms
  for i, u in uniforms {
    if physical_equal(u, uniform) {
      uniforms.remove(i) |> ignore
      break
    }
  }
  self
}

///|
/// `get values()`: the JS values last written, starting as `Array.from( buffer )`.
pub fn Binding::values(self : Binding) -> Array[@core.JsValue] {
  let group = _uniforms_group(self)
  match group._values {
    Some(values) => values
    None => {
      let buffer = self.buffer().unwrap()
      let values = []
      for i in 0..<buffer.length() {
        values.push(@core.JsValue::of(buffer.get(i)))
      }
      group._values = Some(values)
      values
    }
  }
}

///|
/// `updateByType( uniform )`; an unsupported uniform reports an error and is `false`.
pub fn Binding::update_by_type(self : Binding, uniform : Uniform) -> Bool {
  if uniform.has_flag("isNumberUniform") {
    return self.update_number(uniform)
  }
  if uniform.has_flag("isVector2Uniform") {
    return self.update_vector2(uniform)
  }
  if uniform.has_flag("isVector3Uniform") {
    return self.update_vector3(uniform)
  }
  if uniform.has_flag("isVector4Uniform") {
    return self.update_vector4(uniform)
  }
  if uniform.has_flag("isColorUniform") {
    return self.update_color(uniform)
  }
  if uniform.has_flag("isMatrix3Uniform") {
    return self.update_matrix3(uniform)
  }
  if uniform.has_flag("isMatrix4Uniform") {
    return self.update_matrix4(uniform)
  }
  @core.error("WebGPUUniformsGroup: Unsupported uniform type.")
  false
}

///|
/// The JS value of a scalar uniform value.
fn _uniforms_group_scalar(value : TslValue) -> @core.JsValue {
  match value {
    Number(n) => @core.JsValue::of(n)
    Bool(b) => @core.JsValue::of(b)
    String(s) => @core.JsValue::of(s)
    Undefined => @core.JsValue::undefined()
    Null => @core.JsValue::null()
    Js(v) => v
    _ => abort("UniformsGroup: a number uniform holds a non-scalar value")
  }
}

///|
/// Writes `v` to `b[ offset ]` and `a[ offset ]`.
fn _uniforms_group_write(
  a : Array[@core.JsValue],
  b : @core.TypedArray,
  offset : Int32,
  v : @core.JsValue,
) -> Unit {
  uniforms_group_set_value(b, offset, v)
  _uniforms_group_set_array(a, offset, v)
}

///|
/// Whether `a[ offset ] !== v`; past the end of `a` is `undefined`.
fn _uniforms_group_differs(
  a : Array[@core.JsValue],
  offset : Int32,
  v : @core.JsValue,
) -> Bool {
  let current = if offset < a.length() {
    a[offset]
  } else {
    @core.JsValue::undefined()
  }
  !uniforms_group_strict_equal(current, v)
}

///|
/// `updateNumber( uniform )`.
pub fn Binding::update_number(self : Binding, uniform : Uniform) -> Bool {
  let mut updated = false
  let a = self.values()
  let v = _uniforms_group_scalar(uniform.get_value())
  let offset = uniform.offset
  let type_ = uniform.get_type()
  if _uniforms_group_differs(a, offset, v) {
    let b = self._get_buffer_for_type(type_)
    _uniforms_group_write(a, b, offset, v)
    updated = true
    self.add_uniform_update_range(uniform)
  }
  updated
}

///|
fn _uniforms_group_components(value : TslValue, count : Int32) -> Array[Double] {
  match (value, count) {
    (Vector2(v), 2) => [v.x, v.y]
    (Vector3(v), 3) => [v.x, v.y, v.z]
    (Vector4(v), 4) => [v.x, v.y, v.z, v.w]
    (Color(c), 3) => [c.r, c.g, c.b]
    _ =>
      abort(
        "UniformsGroup: the uniform value does not have \{count} components",
      )
  }
}

///|
fn Binding::_update_components(
  self : Binding,
  uniform : Uniform,
  count : Int32,
  typed : Bool,
) -> Bool {
  let mut updated = false
  let a = self.values()
  let v = _uniforms_group_components(uniform.get_value(), count)
  let offset = uniform.offset
  let b = if typed {
    let type_ = uniform.get_type()
    Some(type_)
  } else {
    None
  }
  let mut differs = false
  for i in 0..<count {
    if _uniforms_group_differs(a, offset + i, @core.JsValue::of(v[i])) {
      differs = true
      break
    }
  }
  if differs {
    let buffer = match b {
      Some(type_) => self._get_buffer_for_type(type_)
      None => self.buffer().unwrap()
    }
    for i in 0..<count {
      _uniforms_group_write(a, buffer, offset + i, @core.JsValue::of(v[i]))
    }
    updated = true
    self.add_uniform_update_range(uniform)
  }
  updated
}

///|
/// `updateVector2( uniform )`.
pub fn Binding::update_vector2(self : Binding, uniform : Uniform) -> Bool {
  self._update_components(uniform, 2, true)
}

///|
/// `updateVector3( uniform )`.
pub fn Binding::update_vector3(self : Binding, uniform : Uniform) -> Bool {
  self._update_components(uniform, 3, true)
}

///|
/// `updateVector4( uniform )`.
pub fn Binding::update_vector4(self : Binding, uniform : Uniform) -> Bool {
  self._update_components(uniform, 4, true)
}

///|
/// `updateColor( uniform )`.
pub fn Binding::update_color(self : Binding, uniform : Uniform) -> Bool {
  self._update_components(uniform, 3, false)
}

///|
/// `updateMatrix3( uniform )`: three columns padded to four floats each.
pub fn Binding::update_matrix3(self : Binding, uniform : Uniform) -> Bool {
  let mut updated = false
  let a = self.values()
  let e = match uniform.get_value() {
    Matrix3(m) => m.elements
    _ => abort("UniformsGroup: a Matrix3 uniform holds another value")
  }
  let offset = uniform.offset
  let slots = [0, 1, 2, 4, 5, 6, 8, 9, 10]
  let mut differs = false
  for i, slot in slots {
    if _uniforms_group_differs(a, offset + slot, @core.JsValue::of(e[i])) {
      differs = true
      break
    }
  }
  if differs {
    let b = self.buffer().unwrap()
    for i, slot in slots {
      _uniforms_group_write(a, b, offset + slot, @core.JsValue::of(e[i]))
    }
    updated = true
    self.add_uniform_update_range(uniform)
  }
  updated
}

///|
/// `updateMatrix4( uniform )`.
pub fn Binding::update_matrix4(self : Binding, uniform : Uniform) -> Bool {
  let mut updated = false
  let a = self.values()
  let e = match uniform.get_value() {
    Matrix4(m) => m.elements
    _ => abort("UniformsGroup: a Matrix4 uniform holds another value")
  }
  let offset = uniform.offset
  let mut equal = true
  for i in 0..<e.length() {
    if _uniforms_group_differs(a, offset + i, @core.JsValue::of(e[i])) {
      equal = false
      break
    }
  }
  if !equal {
    let b = self.buffer().unwrap()
    for i in 0..<e.length() {
      b.set(offset + i, e[i])
    }
    for i in 0..<e.length() {
      _uniforms_group_set_array(a, offset + i, @core.JsValue::of(e[i]))
    }
    updated = true
    self.add_uniform_update_range(uniform)
  }
  updated
}

///|
/// `a[ i ] = v` on a JS array, which grows (with holes) past its end.
fn _uniforms_group_set_array(
  a : Array[@core.JsValue],
  i : Int32,
  v : @core.JsValue,
) -> Unit {
  while a.length() < i {
    a.push(@core.JsValue::undefined())
  }
  if i == a.length() {
    a.push(v)
  } else {
    a[i] = v
  }
}

///|
/// `_getBufferForType( type )`: an `Int32Array` or `Uint32Array` view for integer types.
pub fn Binding::_get_buffer_for_type(
  self : Binding,
  type_ : String,
) -> @core.TypedArray {
  let buffer = self.buffer().unwrap()
  if type_ == "int" || type_ == "ivec2" || type_ == "ivec3" || type_ == "ivec4" {
    return @core.TypedArray::view_by_name("Int32Array", buffer.buffer())
  }
  if type_ == "uint" || type_ == "uvec2" || type_ == "uvec3" || type_ == "uvec4" {
    return @core.TypedArray::view_by_name("Uint32Array", buffer.buffer())
  }
  buffer
}
