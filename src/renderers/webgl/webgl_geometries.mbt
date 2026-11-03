// Upstream src/renderers/webgl/WebGLGeometries.js.

///|
pub struct WebGLGeometries {
  gl : WebGL2RenderingContext
  attributes : WebGLAttributes
  info : WebGLInfo
  binding_states : WebGLBindingStates
  /// geometry id -> geometry, iterated in ascending id order like upstream's object keys
  geometries : Map[Int32, WeakRef[@core.BufferGeometry]]
  wireframe_attributes : WeakMap[@core.BufferGeometry, @core.BufferAttribute]
  registry : FinalizationRegistry[Int32]
  /// `onGeometryDispose`, kept so it can be removed
  mut on_geometry_dispose : (@core.Event) -> Unit
}

///|
/// `new WebGLGeometries( gl, attributes, info, bindingStates )`.
pub fn WebGLGeometries::new(
  gl : WebGL2RenderingContext,
  attributes : WebGLAttributes,
  info : WebGLInfo,
  binding_states : WebGLBindingStates,
) -> WebGLGeometries {
  let geometries : Map[Int32, WeakRef[@core.BufferGeometry]] = Map([])
  let self : WebGLGeometries = {
    gl,
    attributes,
    info,
    binding_states,
    geometries,
    wireframe_attributes: WeakMap::new(),
    registry: FinalizationRegistry::new(id => geometries.remove(id)),
    on_geometry_dispose: _ => (),
  }
  self.on_geometry_dispose = event => {
    match event.target {
      Some(BufferGeometry(geometry)) => self.destroy_geometry(geometry)
      _ => ()
    }
  }
  self
}

///|
fn WebGLGeometries::destroy_geometry(
  self : WebGLGeometries,
  geometry : @core.BufferGeometry,
) -> Unit {
  if geometry.index is Some(index) {
    self.attributes.remove(index)
  }
  for _, attribute in geometry.attributes {
    self.attributes.remove(attribute)
  }
  geometry.remove_event_listener("dispose", self.on_geometry_dispose)
  self.geometries.remove(geometry.id)
  self.registry.unregister(geometry)
  if self.wireframe_attributes.get(geometry) is Some(attribute) {
    self.attributes.remove(Buffer(attribute))
    self.wireframe_attributes.delete(geometry)
  }
  self.binding_states.release_states_of_geometry(geometry)
  if geometry.is_instanced_buffer_geometry {
    delete_geometry_max_instance_count(geometry)
  }
  //
  self.info.memory.geometries -= 1
}

///|
/// `geometries.get( object, geometry )`: starts tracking `geometry`.
pub fn WebGLGeometries::get(
  self : WebGLGeometries,
  _object : @core.Object3D,
  geometry : @core.BufferGeometry,
) -> @core.BufferGeometry {
  if self.geometries.contains(geometry.id) {
    return geometry
  }
  geometry.add_event_listener("dispose", self.on_geometry_dispose)
  self.geometries[geometry.id] = WeakRef::new(geometry)
  self.registry.register(geometry, geometry.id, geometry)
  self.info.memory.geometries += 1
  geometry
}

///|
/// `geometries.update( geometry )`: uploads the vertex attributes (the index is uploaded
/// by `WebGLBindingStates`).
pub fn WebGLGeometries::update(
  self : WebGLGeometries,
  geometry : @core.BufferGeometry,
) -> Unit {
  for _, attribute in geometry.attributes {
    self.attributes.update(attribute, GL_ARRAY_BUFFER)
  }
}

///|
fn WebGLGeometries::update_wireframe_attribute(
  self : WebGLGeometries,
  geometry : @core.BufferGeometry,
) -> Unit {
  let geometry_index = geometry.index
  guard geometry.attributes.get("position") is Some(geometry_position) else {
    return
  }
  let mut version = 0
  let count = match geometry_index {
    Some(index) => index.array().length().to_double()
    None => geometry_position.array().length().to_double() / 3.0 - 1.0
  }
  // check whether a 32 bit or 16 bit buffer is required to store the indices
  // account for PRIMITIVE_RESTART_FIXED_INDEX, #24565
  let length = ((count / 3.0).ceil() * 6.0).to_int()
  let attribute = if geometry_position.count() >= 65535 {
    @core.Uint32BufferAttribute::new(length, 1)
  } else {
    @core.Uint16BufferAttribute::new(length, 1)
  }
  let indices = attribute.array
  match geometry_index {
    Some(index) => {
      let array = index.array()
      version = index.version()
      let mut j = 0
      for i = 0; i.to_double() < count; i = i + 3 {
        let a = array[i + 0]
        let b = array[i + 1]
        let c = array[i + 2]
        indices[j] = a
        indices[j + 1] = b
        indices[j + 2] = b
        indices[j + 3] = c
        indices[j + 4] = c
        indices[j + 5] = a
        j += 6
      }
    }
    None => {
      version = geometry_position.version()
      let mut j = 0
      for i = 0; i.to_double() < count; i = i + 3 {
        let a = (i + 0).to_double()
        let b = (i + 1).to_double()
        let c = (i + 2).to_double()
        indices[j] = a
        indices[j + 1] = b
        indices[j + 2] = b
        indices[j + 3] = c
        indices[j + 4] = c
        indices[j + 5] = a
        j += 6
      }
    }
  }
  attribute.version = version
  // Updating index buffer in VAO now. See WebGLBindingStates
  //
  if self.wireframe_attributes.get(geometry) is Some(previous_attribute) {
    self.attributes.remove(Buffer(previous_attribute))
  }
  //
  self.wireframe_attributes.set(geometry, attribute)
}

///|
/// `geometries.getWireframeAttribute( geometry )`: the line index for wireframe drawing;
/// `None` without a position attribute.
pub fn WebGLGeometries::get_wireframe_attribute(
  self : WebGLGeometries,
  geometry : @core.BufferGeometry,
) -> @core.BufferAttribute? {
  match self.wireframe_attributes.get(geometry) {
    Some(current_attribute) =>
      if geometry.index is Some(geometry_index) {
        // if the attribute is obsolete, create a new one
        if current_attribute.version < geometry_index.version() {
          self.update_wireframe_attribute(geometry)
        }
      }
    None => self.update_wireframe_attribute(geometry)
  }
  self.wireframe_attributes.get(geometry)
}

///|
/// `geometries.dispose()`.
pub fn WebGLGeometries::dispose(self : WebGLGeometries) -> Unit {
  let ids = self.geometries.keys().collect()
  ids.sort()
  for id in ids {
    if self.geometries.get(id) is Some(ref_) && ref_.deref() is Some(geometry) {
      self.destroy_geometry(geometry)
    }
  }
}
