// Upstream src/renderers/webgl/WebGLUniformsGroups.js. GROUP 2.
//
// Upstream stores `__size` / `__cache` on the `UniformsGroup` and `__data` / `__offset` on
// each `Uniform`; core's types have no such fields, so they live in the two `WeakMap`s
// here. A uniform's `type` ('int', 'uint') comes from `uniform_type` (webgl_hooks.mbt).

///|
/// `uniformsGroup.__size` / `uniformsGroup.__cache`.
pub(all) struct UniformsGroupLayout {
  mut size : Int32
  /// `__cache`: last uploaded value per `index_k` key, as `hasUniformChanged` keeps it
  cache : Map[String, @core.UniformValue]
}

///|
/// `uniform.__data` / `uniform.__offset`.
pub(all) struct UniformBufferData {
  data : @core.TypedArray
  offset : Int32
}

///|
pub struct WebGLUniformsGroups {
  gl : WebGL2RenderingContext
  info : WebGLInfo
  capabilities : WebGLCapabilities
  state : WebGLState
  /// uniforms group id -> buffer
  mut buffers : Map[Int32, GLBuffer]
  /// uniforms group id -> frame of the last upload
  mut update_list : Map[Int32, Int32]
  layouts : WeakMap[@core.UniformsGroup, UniformsGroupLayout]
  uniform_data : WeakMap[@core.Uniform, UniformBufferData]
  /// `onUniformsGroupsDispose`, kept so it can be removed
  mut on_uniforms_group_dispose : (@core.Event) -> Unit
}

///|
/// `new WebGLUniformsGroups( gl, info, capabilities, state )`.
pub fn WebGLUniformsGroups::new(
  gl : WebGL2RenderingContext,
  info : WebGLInfo,
  capabilities : WebGLCapabilities,
  state : WebGLState,
) -> WebGLUniformsGroups {
  let self : WebGLUniformsGroups = {
    gl,
    info,
    capabilities,
    state,
    buffers: Map([]),
    update_list: Map([]),
    layouts: WeakMap::new(),
    uniform_data: WeakMap::new(),
    on_uniforms_group_dispose: _ => (),
  }
  self.on_uniforms_group_dispose = event => {
    match event.target {
      Some(UniformsGroup(uniforms_group)) =>
        self.uniforms_group_disposed(uniforms_group)
      _ => ()
    }
  }
  self
}

///|
/// `onUniformsGroupsDispose( event )`.
fn WebGLUniformsGroups::uniforms_group_disposed(
  self : WebGLUniformsGroups,
  uniforms_group : @core.UniformsGroup,
) -> Unit {
  uniforms_group.remove_event_listener(
    "dispose",
    self.on_uniforms_group_dispose,
  )
  let buffer : GLBuffer = match self.buffers.get(uniforms_group.id) {
    Some(buffer) => buffer
    // upstream passes `undefined` when the buffers were already disposed
    None => @core.JsValue::undefined().cast()
  }
  self.gl.delete_buffer(buffer)
  self.buffers.remove(uniforms_group.id)
  self.update_list.remove(uniforms_group.id)
}

///|
/// `uniformsGroups.bind( uniformsGroup, program )`.
pub fn WebGLUniformsGroups::bind(
  self : WebGLUniformsGroups,
  uniforms_group : @core.UniformsGroup,
  program : WebGLProgram,
) -> Unit {
  let webgl_program = program.program.unwrap()
  self.state.uniform_block_binding(
    uniforms_group,
    webgl_program,
    self.buffers.get(uniforms_group.id),
  )
}

///|
/// `uniformsGroups.update( uniformsGroup, program )`.
pub fn WebGLUniformsGroups::update(
  self : WebGLUniformsGroups,
  uniforms_group : @core.UniformsGroup,
  program : WebGLProgram,
) -> Unit {
  if !self.buffers.contains(uniforms_group.id) {
    self.prepare_uniforms_group(uniforms_group)
    let buffer = self.create_buffer(uniforms_group)
    self.buffers[uniforms_group.id] = buffer
    uniforms_group.add_event_listener("dispose", self.on_uniforms_group_dispose)
  }

  // ensure to update the binding points/block indices mapping for this program

  let webgl_program = program.program.unwrap()
  self.state.update_ubo_mapping(uniforms_group, webgl_program)

  // update UBO once per frame

  let frame = self.info.render.frame
  if self.update_list.get(uniforms_group.id) != Some(frame) {
    self.update_buffer_data(uniforms_group)
    self.update_list[uniforms_group.id] = frame
  }
}

///|
/// `createBuffer( uniformsGroup )`.
fn WebGLUniformsGroups::create_buffer(
  self : WebGLUniformsGroups,
  uniforms_group : @core.UniformsGroup,
) -> GLBuffer {
  let gl = self.gl
  let buffer = gl.create_buffer()
  let size = self.layouts.get(uniforms_group).unwrap().size
  let usage = uniforms_group.usage
  gl.bind_buffer(GL_UNIFORM_BUFFER, Some(buffer))
  gl.buffer_data_size(GL_UNIFORM_BUFFER, size, usage)
  gl.bind_buffer(GL_UNIFORM_BUFFER, None)
  buffer
}

///|
/// `updateBufferData( uniformsGroup )`.
fn WebGLUniformsGroups::update_buffer_data(
  self : WebGLUniformsGroups,
  uniforms_group : @core.UniformsGroup,
) -> Unit {
  let gl = self.gl
  let buffer = self.buffers.get(uniforms_group.id)
  let uniforms = uniforms_group.uniforms
  let cache = self.layouts.get(uniforms_group).unwrap().cache
  gl.bind_buffer(GL_UNIFORM_BUFFER, buffer)
  for i, uniform_item in uniforms {
    match uniform_item {
      Multiple(items) =>
        for j, item in items {
          self.update_uniform(item, i, j, cache)
        }
      Single(item) => self.update_uniform(item, i, 0, cache)
    }
  }
  gl.bind_buffer(GL_UNIFORM_BUFFER, None)
}

///|
/// `Array.isArray( value )`: `Array` values and plain number arrays.
fn webgl_uniforms_groups_array_items(
  value : @core.UniformValue,
) -> Array[@core.UniformValue]? {
  match value {
    Array(items) => Some(items)
    Numbers(numbers) =>
      Some(numbers.map(fn(n) { @core.UniformValue::Number(n) }))
    _ => None
  }
}

///|
/// `updateUniform( uniform, index, indexArray, cache )`.
fn WebGLUniformsGroups::update_uniform(
  self : WebGLUniformsGroups,
  uniform : @core.Uniform,
  index : Int32,
  index_array : Int32,
  cache : Map[String, @core.UniformValue],
) -> Unit {
  if webgl_uniforms_groups_has_uniform_changed(
      uniform, index, index_array, cache,
    ) {
    let buffer_data = self.uniform_data.get(uniform).unwrap()
    let offset = buffer_data.offset
    let value = uniform.value
    match webgl_uniforms_groups_array_items(value) {
      Some(values) => {
        let mut array_offset = 0
        for val in values {
          let info = webgl_uniforms_groups_uniform_size(val, true)
          webgl_uniforms_groups_write_uniform_value(
            val,
            buffer_data.data,
            array_offset,
          )
          array_offset += info.1 / 4
        }
      }
      None =>
        webgl_uniforms_groups_write_uniform_value(value, buffer_data.data, 0)
    }
    self.gl.buffer_sub_data(GL_UNIFORM_BUFFER, offset, buffer_data.data)
  }
}

///|
/// `writeUniformValue( value, data, offset )`.
fn webgl_uniforms_groups_write_uniform_value(
  value : @core.UniformValue,
  data : @core.TypedArray,
  offset : Int32,
) -> Unit {
  // TODO add integer vector and struct support
  match value {
    Number(n) => data[offset] = n
    Int(n) => data[offset] = n.to_double()
    Bool(b) => data[offset] = if b { 1.0 } else { 0.0 }
    Matrix3(m) => {
      // manually converting 3x3 to 3x4
      let e = m.elements
      data[offset] = e[0]
      data[offset + 1] = e[1]
      data[offset + 2] = e[2]
      data[offset + 3] = 0.0
      data[offset + 4] = e[3]
      data[offset + 5] = e[4]
      data[offset + 6] = e[5]
      data[offset + 7] = 0.0
      data[offset + 8] = e[6]
      data[offset + 9] = e[7]
      data[offset + 10] = e[8]
      data[offset + 11] = 0.0
    }
    TypedArray(t) =>
      // copy the buffer data using "set"
      data.set_from(t.subarray(start=0, end=data.length() - offset), offset~)
    _ => {
      let values = match value {
        Vector2(v) => v.to_array()
        Vector3(v) => v.to_array()
        Vector4(v) => v.to_array()
        Color(c) => c.to_array()
        Quaternion(q) => q.to_array()
        Matrix4(m) => m.to_array()
        _ => abort("WebGLUniformsGroups: value has no toArray")
      }
      // `toArray` into a typed array drops writes past its end
      let n = js_math_min(
        values.length().to_double(),
        (data.length() - offset).to_double(),
      ).to_int()
      for i in 0..<n {
        data[offset + i] = values[i]
      }
    }
  }
}

///|
/// `hasUniformChanged( uniform, index, indexArray, cache )`.
fn webgl_uniforms_groups_has_uniform_changed(
  uniform : @core.Uniform,
  index : Int32,
  index_array : Int32,
  cache : Map[String, @core.UniformValue],
) -> Bool {
  let value = uniform.value
  let index_string = "\{index}_\{index_array}"
  match webgl_uniforms_groups_array_items(value) {
    Some(values) => {
      // arrays are cached per element

      let cached_array = match cache.get(index_string) {
        Some(Array(cached)) => cached
        _ => {
          let cached = []
          cache[index_string] = Array(cached)
          cached
        }
      }
      let mut changed = false
      for k, item in values {
        if webgl_uniforms_groups_has_value_changed(item, cached_array, k) {
          changed = true
        }
      }
      changed
    }
    None => {
      let cached = cache.get(index_string)
      let (result, stored) = webgl_uniforms_groups_value_changed(value, cached)
      if stored is Some(stored) {
        cache[index_string] = stored
      }
      result
    }
  }
}

///|
/// `hasValueChanged( value, cachedArray, k )` for an element of an array value.
fn webgl_uniforms_groups_has_value_changed(
  value : @core.UniformValue,
  cache : Array[@core.UniformValue],
  key : Int32,
) -> Bool {
  let (result, stored) = webgl_uniforms_groups_value_changed(
    value,
    cache.get(key),
  )
  if stored is Some(stored) {
    if key < cache.length() {
      cache[key] = stored
    } else {
      while cache.length() < key {
        cache.push(Null)
      }
      cache.push(stored)
    }
  }
  result
}

///|
/// `hasValueChanged`'s body: whether `value` differs from the cached entry, and the value
/// to store in the cache (`None` to leave it).
fn webgl_uniforms_groups_value_changed(
  value : @core.UniformValue,
  cached : @core.UniformValue?,
) -> (Bool, @core.UniformValue?) {
  match cached {
    None =>
      // cache entry does not exist so far
      match value {
        Number(_) | Int(_) | Bool(_) => (true, Some(value))
        TypedArray(t) => (true, Some(TypedArray(t.slice())))
        _ => (true, Some(webgl_uniforms_groups_clone(value)))
      }
    Some(cached_object) =>
      // compare current value with cached entry
      match value {
        Number(_) | Int(_) | Bool(_) =>
          if !webgl_uniforms_scalar_js(cached_object).strict_equal(
              webgl_uniforms_scalar_js(value),
            ) {
            (true, Some(value))
          } else {
            (false, None)
          }
        // always update the array buffers
        TypedArray(_) => (true, None)
        _ =>
          if !webgl_uniforms_groups_equals(cached_object, value) {
            webgl_uniforms_groups_copy(cached_object, value)
            (true, None)
          } else {
            (false, None)
          }
      }
  }
}

///|
/// `value.clone()`.
fn webgl_uniforms_groups_clone(
  value : @core.UniformValue,
) -> @core.UniformValue {
  match value {
    Vector2(v) => Vector2(v.clone())
    Vector3(v) => Vector3(v.clone())
    Vector4(v) => Vector4(v.clone())
    Color(c) => Color(c.clone())
    Quaternion(q) => Quaternion(q.clone())
    Matrix3(m) => Matrix3(m.clone())
    Matrix4(m) => Matrix4(m.clone())
    _ => abort("WebGLUniformsGroups: value has no clone")
  }
}

///|
/// `cachedObject.equals( value )`.
fn webgl_uniforms_groups_equals(
  cached : @core.UniformValue,
  value : @core.UniformValue,
) -> Bool {
  match (cached, value) {
    (Vector2(a), Vector2(b)) => a.equals(b)
    (Vector3(a), Vector3(b)) => a.equals(b)
    (Vector4(a), Vector4(b)) => a.equals(b)
    (Color(a), Color(b)) => a.equals(b)
    (Quaternion(a), Quaternion(b)) => a.equals(b)
    (Matrix3(a), Matrix3(b)) => a.equals(b)
    (Matrix4(a), Matrix4(b)) => a.equals(b)
    _ => false
  }
}

///|
/// `cachedObject.copy( value )`.
fn webgl_uniforms_groups_copy(
  cached : @core.UniformValue,
  value : @core.UniformValue,
) -> Unit {
  match (cached, value) {
    (Vector2(a), Vector2(b)) => ignore(a.copy(b))
    (Vector3(a), Vector3(b)) => ignore(a.copy(b))
    (Vector4(a), Vector4(b)) => ignore(a.copy(b))
    (Color(a), Color(b)) => ignore(a.copy(b))
    (Quaternion(a), Quaternion(b)) => ignore(a.copy(b))
    (Matrix3(a), Matrix3(b)) => ignore(a.copy(b))
    (Matrix4(a), Matrix4(b)) => ignore(a.copy(b))
    _ => abort("WebGLUniformsGroups: cached value type changed")
  }
}

///|
/// `prepareUniformsGroup( uniformsGroup )`: the STD140 layout.
fn WebGLUniformsGroups::prepare_uniforms_group(
  self : WebGLUniformsGroups,
  uniforms_group : @core.UniformsGroup,
) -> Unit {
  // determine total buffer size according to the STD140 layout
  // Hint: STD140 is the only supported layout in WebGL 2

  let uniforms = uniforms_group.uniforms
  let mut offset = 0 // global buffer offset in bytes
  let chunk_size = 16 // size of a chunk in bytes
  for entry in uniforms {
    let (uniform_array, entry_is_array) = match entry {
      Single(u) => ([u], false)
      Multiple(us) => (us, true)
    }
    for uniform in uniform_array {
      let (values, value_is_array) = match
        webgl_uniforms_groups_array_items(uniform.value) {
        Some(items) => (items, true)
        None => ([uniform.value], false)
      }

      // arrays of uniforms and uniforms with array values both represent GLSL arrays
      let is_array = entry_is_array || value_is_array
      let mut start = offset
      for k, value in values {
        let (boundary, storage) = webgl_uniforms_groups_uniform_size(
          value, is_array,
        )
        let chunk_offset = offset % chunk_size // offset in the current chunk
        let chunk_padding = if boundary == 0 {
          0
        } else {
          chunk_offset % boundary
        } // required padding to match boundary
        let chunk_start = chunk_offset + chunk_padding // the start position in the current chunk for the data
        offset += chunk_padding

        // Check for chunk overflow
        if chunk_start != 0 && chunk_size - chunk_start < storage {
          // Add padding and adjust offset
          offset += chunk_size - chunk_start
        }
        if k == 0 {
          start = offset
        }

        // Update the global offset
        offset += storage
      }

      // the following two properties will be used for partial buffer updates
      let length = (offset - start) / 4
      let data = match uniform_type(uniform) {
        Some("int") => @core.TypedArray::int32(length)
        Some("uint") => @core.TypedArray::uint32(length)
        _ => @core.TypedArray::float32(length)
      }
      self.uniform_data.set(uniform, { data, offset: start, })
    }
  }

  // ensure correct final padding

  let chunk_offset = offset % chunk_size
  if chunk_offset > 0 {
    offset += chunk_size - chunk_offset
  }

  //

  self.layouts.set(uniforms_group, { size: offset, cache: Map([]), })
}

///|
/// `getUniformSize( value, isArrayElement )`: `(boundary, storage)` in bytes.
fn webgl_uniforms_groups_uniform_size(
  value : @core.UniformValue,
  is_array_element : Bool,
) -> (Int32, Int32) {
  // determine sizes according to STD140

  let (boundary, storage) = match value {
    // float/int/bool
    Number(_) | Int(_) | Bool(_) => (4, 4)
    // vec2
    Vector2(_) => (8, 8)
    // vec3; evil: vec3 must start on a 16-byte boundary but it only consumes 12 bytes
    Vector3(_) | Color(_) => (16, 12)
    // vec4
    Vector4(_) => (16, 16)
    // mat3 (in STD140 a 3x3 matrix is represented as 3x4)
    Matrix3(_) => (16, 48)
    // mat4
    Matrix4(_) => (16, 64)
    Texture(_) => {
      @core.warn(
        "WebGLRenderer: Texture samplers can not be part of an uniforms group.",
      )
      (0, 0)
    }
    TypedArray(t) => (16, t.byte_length())
    _ => {
      @core.warn("WebGLRenderer: Unsupported uniform value type.")
      (0, 0)
    }
  }
  if is_array_element {
    // the alignment and stride of array elements are rounded up to the size of a vec4

    return (16, (storage + 15) / 16 * 16)
  }
  (boundary, storage)
}

///|
/// `uniformsGroups.dispose()`.
pub fn WebGLUniformsGroups::dispose(self : WebGLUniformsGroups) -> Unit {
  let ids = self.buffers.keys().collect()
  ids.sort()
  for id in ids {
    self.gl.delete_buffer(self.buffers[id])
  }
  self.buffers = Map([])
  self.update_list = Map([])
}
