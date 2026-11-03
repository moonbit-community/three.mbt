// Upstream src/renderers/webgl/WebGLBindingStates.js. One vertex array object per
// (geometry, instanced mesh or 0, program, wireframe). Upstream keys the nested maps by
// numbers in plain objects, which iterate in ascending order; the loops below sort the
// keys to match.

///|
/// `cache[ name ]` from `saveCache`.
pub(all) struct BindingCacheEntry {
  attribute : @core.GeometryAttribute?
  /// `attribute.data` of an interleaved attribute
  data : @core.InterleavedBuffer?
}

///|
/// `createBindingState( vao )`.
pub(all) struct BindingState {
  // for backward compatibility on non-VAO support browser
  mut geometry : @core.BufferGeometry?
  mut program : WebGLProgram?
  mut wireframe : Bool
  new_attributes : Array[Int32]
  enabled_attributes : Array[Int32]
  attribute_divisors : Array[Int32]
  /// the VAO; `None` for the default state
  object : GLVertexArrayObject?
  mut attributes : Map[String, BindingCacheEntry]
  mut attributes_num : Int32?
  mut index : @core.GeometryAttribute?
}

///|
pub struct WebGLBindingStates {
  gl : WebGL2RenderingContext
  attributes : WebGLAttributes
  max_vertex_attributes : Int32
  /// geometry id -> object id -> program id -> wireframe -> state
  binding_states : Map[Int32, Map[Int32, Map[Int32, Map[Bool, BindingState]]]]
  default_state : BindingState
  mut current_state : BindingState
  mut force_update : Bool
}

///|
/// `new WebGLBindingStates( gl, attributes )`.
pub fn WebGLBindingStates::new(
  gl : WebGL2RenderingContext,
  attributes : WebGLAttributes,
) -> WebGLBindingStates {
  let max_vertex_attributes = gl.get_parameter_int(GL_MAX_VERTEX_ATTRIBS)
  let default_state = webgl_create_binding_state(max_vertex_attributes, None)
  {
    gl,
    attributes,
    max_vertex_attributes,
    binding_states: {},
    default_state,
    current_state: default_state,
    force_update: false,
  }
}

///|
fn webgl_create_binding_state(
  max_vertex_attributes : Int32,
  vao : GLVertexArrayObject?,
) -> BindingState {
  {
    geometry: None,
    program: None,
    wireframe: false,
    new_attributes: Array::make(max_vertex_attributes, 0),
    enabled_attributes: Array::make(max_vertex_attributes, 0),
    attribute_divisors: Array::make(max_vertex_attributes, 0),
    object: vao,
    attributes: {},
    attributes_num: None,
    index: None,
  }
}

///|
/// The object a `GeometryAttribute` stands for, for `===` comparisons.
fn webgl_geometry_attribute_identity(
  attribute : @core.GeometryAttribute,
) -> @core.JsValue {
  match attribute {
    Buffer(a) => @core.JsValue::of(a)
    Interleaved(a) => @core.JsValue::of(a)
    GL(a) => @core.JsValue::of(a)
  }
}

///|
fn webgl_same_geometry_attribute(
  a : @core.GeometryAttribute?,
  b : @core.GeometryAttribute?,
) -> Bool {
  match (a, b) {
    (None, None) => true
    (Some(x), Some(y)) =>
      webgl_geometry_attribute_identity(x).strict_equal(
        webgl_geometry_attribute_identity(y),
      )
    _ => false
  }
}

///|
/// `geometry.attributes[ name ]`, falling back to the instanced mesh's `instanceMatrix`
/// and `instanceColor`.
fn webgl_binding_geometry_attribute(
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  name : String,
) -> @core.GeometryAttribute? {
  match geometry.attributes.get(name) {
    Some(attribute) => Some(attribute)
    None =>
      match object.kind {
        Mesh({ kind: InstancedMesh(instanced_mesh), .. }) =>
          if name == "instanceMatrix" {
            Some(Buffer(instanced_mesh.instance_matrix))
          } else if name == "instanceColor" &&
            instanced_mesh.instance_color is Some(instance_color) {
            Some(Buffer(instance_color))
          } else {
            None
          }
        _ => None
      }
  }
}

///|
/// `bindingStates.setup( object, material, program, geometry, index )`.
pub fn WebGLBindingStates::setup(
  self : WebGLBindingStates,
  object : @core.Object3D,
  material : @core.Material,
  program : WebGLProgram,
  geometry : @core.BufferGeometry,
  index : @core.GeometryAttribute?,
) -> Unit {
  let state = self.get_binding_state(object, geometry, program, material)
  if !physical_equal(self.current_state, state) {
    self.current_state = state
    self.gl.bind_vertex_array(self.current_state.object)
  }
  let update_buffers = self.needs_update(object, geometry, program, index)
  if update_buffers {
    self.save_cache(object, geometry, program, index)
  }
  if index is Some(index) {
    self.attributes.update(index, GL_ELEMENT_ARRAY_BUFFER)
  }
  if update_buffers || self.force_update {
    self.force_update = false
    self.setup_vertex_attributes(object, material, program, geometry)
    if index is Some(index) {
      self.gl.bind_buffer(
        GL_ELEMENT_ARRAY_BUFFER,
        self.attributes.get(index).map(data => data.buffer),
      )
    }
  }
}

///|
fn WebGLBindingStates::get_binding_state(
  self : WebGLBindingStates,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  program : WebGLProgram,
  material : @core.Material,
) -> BindingState {
  let wireframe = material.wireframe == Some(true)
  let object_map = match self.binding_states.get(geometry.id) {
    Some(map) => map
    None => {
      let map = Map([])
      self.binding_states[geometry.id] = map
      map
    }
  }
  // Each InstancedMesh requires unique binding states because it contains instanced
  // attributes.
  let object_id = if object.is_instanced_mesh() { object.id } else { 0 }
  let program_map = match object_map.get(object_id) {
    Some(map) => map
    None => {
      let map = Map([])
      object_map[object_id] = map
      map
    }
  }
  let state_map = match program_map.get(program.id) {
    Some(map) => map
    None => {
      let map = Map([])
      program_map[program.id] = map
      map
    }
  }
  match state_map.get(wireframe) {
    Some(state) => state
    None => {
      let state = webgl_create_binding_state(
        self.max_vertex_attributes,
        Some(self.gl.create_vertex_array()),
      )
      state_map[wireframe] = state
      state
    }
  }
}

///|
fn WebGLBindingStates::needs_update(
  self : WebGLBindingStates,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  program : WebGLProgram,
  index : @core.GeometryAttribute?,
) -> Bool {
  let cached_attributes = self.current_state.attributes
  let mut attributes_num = 0
  let program_attributes = program.get_attributes()
  for name, program_attribute in program_attributes {
    if program_attribute.location >= 0 {
      let geometry_attribute = webgl_binding_geometry_attribute(
        object, geometry, name,
      )
      guard cached_attributes.get(name) is Some(cached_attribute) else {
        return true
      }
      if !webgl_same_geometry_attribute(
          cached_attribute.attribute,
          geometry_attribute,
        ) {
        return true
      }
      if geometry_attribute is Some(geometry_attribute) {
        let data = match geometry_attribute {
          Interleaved(a) => Some(a.data)
          _ => None
        }
        if !same_handle(cached_attribute.data, data) {
          return true
        }
      }
      attributes_num += 1
    }
  }
  if self.current_state.attributes_num != Some(attributes_num) {
    return true
  }
  if !webgl_same_geometry_attribute(self.current_state.index, index) {
    return true
  }
  false
}

///|
fn WebGLBindingStates::save_cache(
  self : WebGLBindingStates,
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
  program : WebGLProgram,
  index : @core.GeometryAttribute?,
) -> Unit {
  let cache : Map[String, BindingCacheEntry] = Map([])
  let mut attributes_num = 0
  let program_attributes = program.get_attributes()
  for name, program_attribute in program_attributes {
    if program_attribute.location >= 0 {
      let attribute = webgl_binding_geometry_attribute(object, geometry, name)
      let data = match attribute {
        Some(Interleaved(a)) => Some(a.data)
        _ => None
      }
      cache[name] = { attribute, data, }
      attributes_num += 1
    }
  }
  self.current_state.attributes = cache
  self.current_state.attributes_num = Some(attributes_num)
  self.current_state.index = index
}

///|
/// `bindingStates.initAttributes()`.
pub fn WebGLBindingStates::init_attributes(self : WebGLBindingStates) -> Unit {
  let new_attributes = self.current_state.new_attributes
  for i in 0..<new_attributes.length() {
    new_attributes[i] = 0
  }
}

///|
/// `bindingStates.enableAttribute( attribute )`.
pub fn WebGLBindingStates::enable_attribute(
  self : WebGLBindingStates,
  attribute : Int32,
) -> Unit {
  self.enable_attribute_and_divisor(attribute, 0)
}

///|
fn WebGLBindingStates::enable_attribute_and_divisor(
  self : WebGLBindingStates,
  attribute : Int32,
  mesh_per_attribute : Int32,
) -> Unit {
  let new_attributes = self.current_state.new_attributes
  let enabled_attributes = self.current_state.enabled_attributes
  let attribute_divisors = self.current_state.attribute_divisors
  new_attributes[attribute] = 1
  if enabled_attributes[attribute] == 0 {
    self.gl.enable_vertex_attrib_array(attribute)
    enabled_attributes[attribute] = 1
  }
  if attribute_divisors[attribute] != mesh_per_attribute {
    self.gl.vertex_attrib_divisor(attribute, mesh_per_attribute)
    attribute_divisors[attribute] = mesh_per_attribute
  }
}

///|
/// `bindingStates.disableUnusedAttributes()`.
pub fn WebGLBindingStates::disable_unused_attributes(
  self : WebGLBindingStates,
) -> Unit {
  let new_attributes = self.current_state.new_attributes
  let enabled_attributes = self.current_state.enabled_attributes
  for i in 0..<enabled_attributes.length() {
    if enabled_attributes[i] != new_attributes[i] {
      self.gl.disable_vertex_attrib_array(i)
      enabled_attributes[i] = 0
    }
  }
}

///|
fn WebGLBindingStates::vertex_attrib_pointer(
  self : WebGLBindingStates,
  index : Int32,
  size : Int32,
  type_ : Int32,
  normalized : Bool,
  stride : Int32,
  offset : Int32,
  integer : Bool,
) -> Unit {
  if integer {
    self.gl.vertex_attrib_i_pointer(index, size, type_, stride, offset)
  } else {
    self.gl.vertex_attrib_pointer(
      index, size, type_, normalized, stride, offset,
    )
  }
}

///|
fn WebGLBindingStates::setup_vertex_attributes(
  self : WebGLBindingStates,
  object : @core.Object3D,
  material : @core.Material,
  program : WebGLProgram,
  geometry : @core.BufferGeometry,
) -> Unit {
  self.init_attributes()
  let program_attributes = program.get_attributes()
  let material_default_attribute_values = material.default_attribute_values
  for name, program_attribute in program_attributes {
    if program_attribute.location < 0 {
      continue
    }
    let location = program_attribute.location
    let location_size = program_attribute.location_size
    match webgl_binding_geometry_attribute(object, geometry, name) {
      Some(geometry_attribute) => {
        let normalized = geometry_attribute.normalized()
        let size = geometry_attribute.item_size()
        // TODO Attribute may not be available on context restore
        guard self.attributes.get(geometry_attribute) is Some(attribute) else {
          continue
        }
        let buffer = attribute.buffer
        let type_ = attribute.type_
        let bytes_per_element = attribute.bytes_per_element
        // check for integer attributes
        let gpu_type_is_int = match geometry_attribute {
          Buffer(a) => a.gpu_type == @core.IntType
          _ => false
        }
        let integer = type_ == GL_INT ||
          type_ == GL_UNSIGNED_INT ||
          gpu_type_is_int
        match geometry_attribute {
          Interleaved(interleaved) => {
            let data = interleaved.data
            let stride = data.stride
            let offset = interleaved.offset
            if data.is_instanced_interleaved_buffer {
              for i in 0..<location_size {
                self.enable_attribute_and_divisor(
                  location + i,
                  data.mesh_per_attribute,
                )
              }
              if !object.is_instanced_mesh() &&
                geometry_max_instance_count(geometry) is None {
                set_geometry_max_instance_count(
                  geometry,
                  data.mesh_per_attribute * data.count,
                )
              }
            } else {
              for i in 0..<location_size {
                self.enable_attribute(location + i)
              }
            }
            self.gl.bind_buffer(GL_ARRAY_BUFFER, Some(buffer))
            for i in 0..<location_size {
              self.vertex_attrib_pointer(
                location + i,
                size / location_size,
                type_,
                normalized,
                stride * bytes_per_element,
                (offset + size / location_size * i) * bytes_per_element,
                integer,
              )
            }
          }
          _ => {
            let instanced = match geometry_attribute {
              Buffer(a) if a.is_instanced_buffer_attribute() => Some(a)
              _ => None
            }
            match instanced {
              Some(a) => {
                for i in 0..<location_size {
                  self.enable_attribute_and_divisor(
                    location + i,
                    a.mesh_per_attribute,
                  )
                }
                if !object.is_instanced_mesh() &&
                  geometry_max_instance_count(geometry) is None {
                  set_geometry_max_instance_count(
                    geometry,
                    a.mesh_per_attribute * a.count,
                  )
                }
              }
              None =>
                for i in 0..<location_size {
                  self.enable_attribute(location + i)
                }
            }
            self.gl.bind_buffer(GL_ARRAY_BUFFER, Some(buffer))
            for i in 0..<location_size {
              self.vertex_attrib_pointer(
                location + i,
                size / location_size,
                type_,
                normalized,
                size * bytes_per_element,
                size / location_size * i * bytes_per_element,
                integer,
              )
            }
          }
        }
      }
      None =>
        if material_default_attribute_values is Some(values) &&
          values.get(name) is Some(value) {
          match value.length() {
            2 => self.gl.vertex_attrib2fv(location, value)
            3 => self.gl.vertex_attrib3fv(location, value)
            4 => self.gl.vertex_attrib4fv(location, value)
            _ => self.gl.vertex_attrib1fv(location, value)
          }
        }
    }
  }
  self.disable_unused_attributes()
}

///|
fn[V] webgl_sorted_keys(map : Map[Int32, V]) -> Array[Int32] {
  let keys = map.keys().collect()
  keys.sort()
  keys
}

///|
/// Deletes every VAO of `state_map` and empties it.
fn WebGLBindingStates::release_state_map(
  self : WebGLBindingStates,
  state_map : Map[Bool, BindingState],
) -> Unit {
  for wireframe in state_map.keys().collect() {
    if state_map.get(wireframe) is Some({ object: Some(vao), .. }) {
      self.gl.delete_vertex_array(vao)
    }
    state_map.remove(wireframe)
  }
}

///|
/// Releases every state of `program_map` and empties it.
fn WebGLBindingStates::release_program_map(
  self : WebGLBindingStates,
  program_map : Map[Int32, Map[Bool, BindingState]],
) -> Unit {
  for program_id in webgl_sorted_keys(program_map) {
    self.release_state_map(program_map[program_id])
    program_map.remove(program_id)
  }
}

///|
/// `bindingStates.dispose()`.
pub fn WebGLBindingStates::dispose(self : WebGLBindingStates) -> Unit {
  self.reset()
  for geometry_id in webgl_sorted_keys(self.binding_states) {
    let object_map = self.binding_states[geometry_id]
    for object_id in webgl_sorted_keys(object_map) {
      self.release_program_map(object_map[object_id])
    }
    self.binding_states.remove(geometry_id)
  }
}

///|
/// `bindingStates.releaseStatesOfGeometry( geometry )`.
pub fn WebGLBindingStates::release_states_of_geometry(
  self : WebGLBindingStates,
  geometry : @core.BufferGeometry,
) -> Unit {
  guard self.binding_states.get(geometry.id) is Some(object_map) else { return }
  for object_id in webgl_sorted_keys(object_map) {
    self.release_program_map(object_map[object_id])
  }
  self.binding_states.remove(geometry.id)
}

///|
/// `bindingStates.releaseStatesOfProgram( program )`.
pub fn WebGLBindingStates::release_states_of_program(
  self : WebGLBindingStates,
  program : WebGLProgram,
) -> Unit {
  for geometry_id in webgl_sorted_keys(self.binding_states) {
    let object_map = self.binding_states[geometry_id]
    for object_id in webgl_sorted_keys(object_map) {
      let program_map = object_map[object_id]
      guard program_map.get(program.id) is Some(state_map) else { continue }
      self.release_state_map(state_map)
      program_map.remove(program.id)
    }
  }
}

///|
/// `bindingStates.releaseStatesOfObject( object )`.
pub fn WebGLBindingStates::release_states_of_object(
  self : WebGLBindingStates,
  object : @core.Object3D,
) -> Unit {
  for geometry_id in webgl_sorted_keys(self.binding_states) {
    let object_map = self.binding_states[geometry_id]
    let object_id = if object.is_instanced_mesh() { object.id } else { 0 }
    guard object_map.get(object_id) is Some(program_map) else { continue }
    self.release_program_map(program_map)
    object_map.remove(object_id)
    if object_map.is_empty() {
      self.binding_states.remove(geometry_id)
    }
  }
}

///|
/// `bindingStates.reset()`.
pub fn WebGLBindingStates::reset(self : WebGLBindingStates) -> Unit {
  self.reset_default_state()
  self.force_update = true
  if physical_equal(self.current_state, self.default_state) {
    return
  }
  self.current_state = self.default_state
  self.gl.bind_vertex_array(self.current_state.object)
}

///|
/// `bindingStates.resetDefaultState()` (for backward-compatibility).
pub fn WebGLBindingStates::reset_default_state(
  self : WebGLBindingStates,
) -> Unit {
  self.default_state.geometry = None
  self.default_state.program = None
  self.default_state.wireframe = false
}
