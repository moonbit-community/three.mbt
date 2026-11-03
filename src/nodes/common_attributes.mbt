// renderers/common/Attributes.js

///|
let _attributes_generation : Ref[Int32] = Ref(0)

///|
/// What `backend.getBufferAttribute( attribute )` returns: the object a GPU buffer
/// belongs to (the `InterleavedBuffer` of an interleaved attribute).
pub(all) enum AttributeBuffer {
  Buffer(@core.BufferAttribute)
  Interleaved(@core.InterleavedBuffer)
  GL(@core.GLBufferAttribute)
}

///|
/// The object as a JS identity key.
pub fn AttributeBuffer::key(self : AttributeBuffer) -> @core.JsValue {
  match self {
    Buffer(a) => @core.JsValue::of(a)
    Interleaved(a) => @core.JsValue::of(a)
    GL(a) => @core.JsValue::of(a)
  }
}

///|
/// `attribute.version`.
pub fn AttributeBuffer::version(self : AttributeBuffer) -> Int32 {
  match self {
    Buffer(a) => a.version
    Interleaved(a) => a.version
    GL(a) => a.version
  }
}

///|
/// `attribute.usage`; `None` is `undefined` (`GLBufferAttribute`).
pub fn AttributeBuffer::usage(self : AttributeBuffer) -> Int32? {
  match self {
    Buffer(a) => Some(a.usage)
    Interleaved(a) => Some(a.usage)
    GL(_) => None
  }
}

///|
/// `attribute.array`; `None` is `undefined` (`GLBufferAttribute`).
pub fn AttributeBuffer::array(self : AttributeBuffer) -> @core.TypedArray? {
  match self {
    Buffer(a) => Some(a.array)
    Interleaved(a) => Some(a.array)
    GL(_) => None
  }
}

///|
/// Identity of the underlying object.
pub fn AttributeBuffer::same(
  self : AttributeBuffer,
  other : AttributeBuffer,
) -> Bool {
  match (self, other) {
    (Buffer(a), Buffer(b)) => physical_equal(a, b)
    (Interleaved(a), Interleaved(b)) => physical_equal(a, b)
    (GL(a), GL(b)) => physical_equal(a, b)
    _ => false
  }
}

///|
/// The per-attribute record of `Attributes`.
pub(all) struct AttributeData {
  /// `undefined` until the attribute is created.
  mut version : Int32?
  mut generation : Int32?
  mut on_dispose : ((@core.Event) -> Unit)?
  mut ref_ : @webgl.WeakRef[@core.BufferAttribute]?
}

///|
/// Creates, updates and destroys the GPU buffers of attributes.
pub struct Attributes {
  priv map : DataMap[@core.JsValue, AttributeData]
  backend : Backend
  info : Info
  priv _tracked : RefSet[@webgl.WeakRef[@core.BufferAttribute]]
  priv _registry : @webgl.FinalizationRegistry[
    @webgl.WeakRef[@core.BufferAttribute],
  ]
  mut dispose_version : Int32
}

///|
/// `new Attributes( backend, info )`.
pub fn Attributes::new(backend : Backend, info : Info) -> Attributes {
  let tracked : RefSet[@webgl.WeakRef[@core.BufferAttribute]] = RefSet::new()
  {
    map: DataMap::new(fn() {
      { version: None, generation: None, on_dispose: None, ref_: None, }
    }),
    backend,
    info,
    _tracked: tracked,
    _registry: @webgl.FinalizationRegistry::new(fn(ref_) {
      tracked.delete(ref_)
    }),
    dispose_version: 0,
  }
}

///|
/// `get( attribute )`: the attribute's record.
pub fn Attributes::get(
  self : Attributes,
  attribute : AttributeBuffer,
) -> AttributeData {
  self.map.get(attribute.key())
}

///|
/// `has( attribute )`.
pub fn Attributes::has(self : Attributes, attribute : AttributeBuffer) -> Bool {
  self.map.has(attribute.key())
}

///|
/// `delete( attribute )`: destroys the attribute's buffer; the removed record or `None`.
pub fn Attributes::delete(
  self : Attributes,
  attribute : AttributeBuffer,
) -> AttributeData? {
  let attribute_data = self.map.delete(attribute.key())
  match attribute_data {
    Some(data) => {
      self.dispose_version += 1
      match attribute {
        Buffer(a) => {
          match data.on_dispose {
            Some(f) => a.remove_event_listener("dispose", f)
            None => ()
          }
          match data.ref_ {
            Some(r) => {
              self._tracked.delete(r)
              self._registry.unregister(r)
            }
            None => ()
          }
        }
        _ => ()
      }
      self.backend.destroy_attribute(attribute)
      self.info.destroy_attribute(attribute)
    }
    None => ()
  }
  attribute_data
}

///|
/// `update( attribute, type )`: creates the buffer, or updates it when the attribute
/// changed or is dynamic.
pub fn Attributes::update(
  self : Attributes,
  attribute : AttributeBuffer,
  type_ : AttributeType,
) -> Unit {
  let data = self.get(attribute)
  match data.version {
    None => {
      match type_ {
        VERTEX => {
          self.backend.create_attribute(attribute)
          self.info.create_attribute(attribute)
        }
        INDEX => {
          self.backend.create_index_attribute(attribute)
          self.info.create_index_attribute(attribute)
        }
        STORAGE => {
          self.backend.create_storage_attribute(attribute)
          self.info.create_storage_attribute(attribute)
        }
        INDIRECT => {
          self.backend.create_indirect_storage_attribute(attribute)
          self.info.create_indirect_storage_attribute(attribute)
        }
      }
      data.version = Some(attribute.version())
      data.generation = Some(_attributes_generation.val)
      _attributes_generation.val += 1
      match attribute {
        Buffer(a) => {
          let on_dispose = fn(_e : @core.Event) {
            self.delete(attribute) |> ignore
          }
          data.on_dispose = Some(on_dispose)
          a.add_event_listener("dispose", on_dispose)
          let r = @webgl.WeakRef::new(a)
          data.ref_ = Some(r)
          self._tracked.add(r)
          self._registry.register(a, r, r)
        }
        _ => ()
      }
    }
    Some(version) =>
      if version < attribute.version() ||
        attribute.usage() == Some(@core.DynamicDrawUsage) {
        self.backend.update_attribute(attribute)
        data.version = Some(attribute.version())
      }
  }
}

///|
/// `dispose()`: destroys every tracked attribute.
pub fn Attributes::dispose(self : Attributes) -> Unit {
  self._tracked.each(fn(r) {
    match r.deref() {
      Some(attribute) =>
        if self.has(Buffer(attribute)) {
          self.delete(Buffer(attribute)) |> ignore
        }
      None => ()
    }
  })
  self._tracked.clear()
  self.map.dispose()
}
