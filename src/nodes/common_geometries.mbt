// renderers/common/Geometries.js

///|
/// `getWireframeVersion( geometry )`.
fn _geometries_wireframe_version(geometry : @core.BufferGeometry) -> Int32 {
  match geometry.index {
    Some(index) => index.version()
    None => _geometries_position(geometry).version()
  }
}

///|
/// The wireframe source id: the index or position attribute's id (`undefined` for
/// attributes without one).
fn _geometries_wireframe_id(geometry : @core.BufferGeometry) -> Int32? {
  let attribute = match geometry.index {
    Some(index) => index
    None => _geometries_position(geometry)
  }
  match attribute {
    Buffer(a) => Some(a.id)
    _ => None
  }
}

///|
fn _geometries_position(
  geometry : @core.BufferGeometry,
) -> @core.GeometryAttribute {
  match geometry.get_attribute("position") {
    Some(p) => p
    None =>
      abort(
        "TypeError: Cannot read properties of undefined (reading 'version')",
      )
  }
}

///|
/// `getWireframeIndex( geometry )`: a line-list index drawing each triangle's edges.
fn _geometries_wireframe_index(
  geometry : @core.BufferGeometry,
) -> WireframeAttribute {
  let geometry_index = geometry.index
  let geometry_position = _geometries_position(geometry)
  let count = match geometry_index {
    Some(index) => index.array().length().to_double()
    None => geometry_position.array().length().to_double() / 3.0 - 1.0
  }
  let length = ((count / 3.0).ceil() * 6.0).to_int()
  let attribute = if geometry_position.count() >= 65535 {
    @core.Uint32BufferAttribute::new(length, 1)
  } else {
    @core.Uint16BufferAttribute::new(length, 1)
  }
  let indices = attribute.array
  let mut i = 0
  let mut j = 0
  while i.to_double() < count {
    let (a, b, c) = match geometry_index {
      Some(index) => {
        let array = index.array()
        (array.get(i + 0), array.get(i + 1), array.get(i + 2))
      }
      None => ((i + 0).to_double(), (i + 1).to_double(), (i + 2).to_double())
    }
    indices.set(j, a)
    indices.set(j + 1, b)
    indices.set(j + 2, b)
    indices.set(j + 3, c)
    indices.set(j + 4, c)
    indices.set(j + 5, a)
    j += 6
    i += 3
  }
  attribute.version = _geometries_wireframe_version(geometry)
  { attribute, id: _geometries_wireframe_id(geometry), }
}

///|
/// A wireframe index and the `__id` of the attribute it was built from.
priv struct WireframeAttribute {
  attribute : @core.BufferAttribute
  id : Int32?
}

///|
/// The record of a geometry in `Geometries`.
pub(all) struct GeometryData {
  mut initialized : Bool?
  mut on_dispose : ((@core.Event) -> Unit)?
  mut ref_ : @webgl.WeakRef[@core.BufferGeometry]?
}

///|
/// Tracks geometries and keeps their attributes' buffers up to date.
pub struct Geometries {
  priv map : DataMap[@core.BufferGeometry, GeometryData]
  backend : Backend
  attributes : Attributes
  info : Info
  priv wireframes : @webgl.WeakMap[@core.BufferGeometry, WireframeAttribute]
  /// `attributeCall`: the render call in which each buffer was last updated.
  priv attribute_call : @webgl.WeakMap[@core.JsValue, Int32]
  priv _tracked : RefSet[@webgl.WeakRef[@core.BufferGeometry]]
  priv _registry : @webgl.FinalizationRegistry[
    @webgl.WeakRef[@core.BufferGeometry],
  ]
}

///|
/// `new Geometries( backend, attributes, info )`.
pub fn Geometries::new(
  backend : Backend,
  attributes : Attributes,
  info : Info,
) -> Geometries {
  let tracked : RefSet[@webgl.WeakRef[@core.BufferGeometry]] = RefSet::new()
  {
    map: DataMap::new(fn() {
      { initialized: None, on_dispose: None, ref_: None, }
    }),
    backend,
    attributes,
    info,
    wireframes: @webgl.WeakMap::new(),
    attribute_call: @webgl.WeakMap::new(),
    _tracked: tracked,
    _registry: @webgl.FinalizationRegistry::new(fn(ref_) {
      tracked.delete(ref_)
    }),
  }
}

///|
/// `get( geometry )`: the geometry's record.
pub fn Geometries::get(
  self : Geometries,
  geometry : @core.BufferGeometry,
) -> GeometryData {
  self.map.get(geometry)
}

///|
/// `delete( geometry )`.
pub fn Geometries::delete(
  self : Geometries,
  geometry : @core.BufferGeometry,
) -> GeometryData? {
  self.map.delete(geometry)
}

///|
/// `has( geometry )`: whether the geometry is initialized.
pub fn Geometries::has(
  self : Geometries,
  geometry : @core.BufferGeometry,
) -> Bool {
  self.map.has(geometry) && self.get(geometry).initialized == Some(true)
}

///|
/// `updateForRender( renderObject )`.
pub fn Geometries::update_for_render(
  self : Geometries,
  render_object : RenderObject,
) -> Unit {
  let geometry = render_object.geometry
  if !self.has(geometry) {
    self.init_geometry(geometry)
  }
  self.update_attributes(render_object)
}

///|
/// `initGeometry( geometry )`: counts the geometry and frees its buffers on dispose.
pub fn Geometries::init_geometry(
  self : Geometries,
  geometry : @core.BufferGeometry,
) -> Unit {
  let geometry_data = self.get(geometry)
  geometry_data.initialized = Some(true)
  self.info.memory.geometries += 1
  let on_dispose = fn(_e : @core.Event) {
    self.info.memory.geometries -= 1
    match geometry.index {
      Some(index) =>
        self.attributes.delete(self.backend.get_buffer_attribute(index))
        |> ignore
      None => ()
    }
    for _, attribute in geometry.attributes {
      self.attributes.delete(self.backend.get_buffer_attribute(attribute))
      |> ignore
    }
    match self.wireframes.get(geometry) {
      Some(w) => self.attributes.delete(Buffer(w.attribute)) |> ignore
      None => ()
    }
    match geometry_data.on_dispose {
      Some(f) => geometry.remove_event_listener("dispose", f)
      None => ()
    }
    match geometry_data.ref_ {
      Some(r) => {
        self._tracked.delete(r)
        self._registry.unregister(r)
      }
      None => ()
    }
    self.delete(geometry) |> ignore
  }
  geometry_data.on_dispose = Some(on_dispose)
  geometry.add_event_listener("dispose", on_dispose)
  let r = @webgl.WeakRef::new(geometry)
  geometry_data.ref_ = Some(r)
  self._tracked.add(r)
  self._registry.register(geometry, r, r)
}

///|
/// `updateAttributes( renderObject )`.
pub fn Geometries::update_attributes(
  self : Geometries,
  render_object : RenderObject,
) -> Unit {
  let attributes = render_object.get_attributes()
  for attribute in attributes {
    match attribute {
      Buffer(a) if is_storage_buffer_attribute(a) ||
        is_storage_instanced_buffer_attribute(a) =>
        self.update_attribute(attribute, STORAGE)
      _ => self.update_attribute(attribute, VERTEX)
    }
  }
  match self.get_index(render_object) {
    Some(index) => self.update_attribute(index, INDEX)
    None => ()
  }
  match render_object.geometry.indirect {
    Some(indirect) => self.update_attribute(Buffer(indirect), INDIRECT)
    None => ()
  }
}

///|
/// `updateAttribute( attribute, type )`: updates a buffer once per render call.
pub fn Geometries::update_attribute(
  self : Geometries,
  attribute : @core.GeometryAttribute,
  type_ : AttributeType,
) -> Unit {
  let call_id = self.info.render.calls
  let buffer_attribute = self.backend.get_buffer_attribute(attribute)
  let key = buffer_attribute.key()
  if self.attribute_call.get(key) != Some(call_id) {
    self.attributes.update(buffer_attribute, type_)
    self.attribute_call.set(key, call_id)
  }
}

///|
/// `getIndirect( renderObject )`.
pub fn Geometries::get_indirect(
  self : Geometries,
  render_object : RenderObject,
) -> @core.BufferAttribute? {
  ignore(self)
  render_object.geometry.indirect
}

///|
/// `getIndirectOffset( renderObject )`.
pub fn Geometries::get_indirect_offset(
  self : Geometries,
  render_object : RenderObject,
) -> Array[Int32] {
  ignore(self)
  render_object.geometry.indirect_offset
}

///|
/// `getIndex( renderObject )`: the geometry's index, or a wireframe index for
/// wireframe materials.
pub fn Geometries::get_index(
  self : Geometries,
  render_object : RenderObject,
) -> @core.GeometryAttribute? {
  let geometry = render_object.geometry
  let material = render_object.material
  let mut index = geometry.index
  if material.wireframe == Some(true) {
    let wireframes = self.wireframes
    let wireframe_attribute = match wireframes.get(geometry) {
      None => {
        let w = _geometries_wireframe_index(geometry)
        wireframes.set(geometry, w)
        w
      }
      Some(w) =>
        if w.attribute.version != _geometries_wireframe_version(geometry) ||
          w.id != _geometries_wireframe_id(geometry) {
          self.attributes.delete(Buffer(w.attribute)) |> ignore
          let w = _geometries_wireframe_index(geometry)
          wireframes.set(geometry, w)
          w
        } else {
          w
        }
    }
    index = Some(Buffer(wireframe_attribute.attribute))
  }
  index
}

///|
/// `deleteNodeAttributes( renderObject )`: frees the node attributes that are not the
/// geometry's own.
pub fn Geometries::delete_node_attributes(
  self : Geometries,
  render_object : RenderObject,
) -> Unit {
  let current_attributes = render_object.geometry.attributes.values().collect()
  for attribute in render_object.get_attributes() {
    if !current_attributes
      .iter()
      .any(fn(a) { _render_object_same_attribute(a, attribute) }) {
      self.attributes.delete(self.backend.get_buffer_attribute(attribute))
      |> ignore
    }
  }
}

///|
/// `deleteVertexState( renderObject )`.
pub fn Geometries::delete_vertex_state(
  self : Geometries,
  render_object : RenderObject,
) -> Unit {
  self.backend.delete_vertex_state(render_object)
}

///|
/// `dispose()`: disposes every tracked geometry's buffers.
pub fn Geometries::dispose(self : Geometries) -> Unit {
  self._tracked.each(fn(r) {
    match r.deref() {
      Some(geometry) => {
        let geometry_data = self.get(geometry)
        match geometry_data.on_dispose {
          Some(f) => f(@core.Event::new("dispose"))
          None => abort("TypeError: geometryData.onDispose is not a function")
        }
      }
      None => ()
    }
  })
  self._tracked.clear()
  self.map.dispose()
}
