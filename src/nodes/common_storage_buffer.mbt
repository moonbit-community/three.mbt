// renderers/common/StorageBuffer.js

///|
/// The `StorageBuffer` class payload.
pub(all) struct StorageBuffer {
  parent_ : Buffer
  mut _attribute : @core.BufferAttribute?
}

///|
pub impl BindingClass for StorageBuffer with fn class_name(_) {
  "StorageBuffer"
}

///|
pub impl BindingClass for StorageBuffer with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for StorageBuffer with fn has_flag(self, flag) {
  flag == "isStorageBuffer" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for StorageBuffer with fn copy_class(self) {
  self.copy_payload()
}

///|
pub impl BindingClass for StorageBuffer with fn attribute(self, _) {
  self._attribute
}

///|
pub fn StorageBuffer::copy_payload(self : StorageBuffer) -> StorageBuffer {
  { parent_: self.parent_.copy_payload(), _attribute: self._attribute, }
}

///|
/// The payload of `super( name, attribute )` for subclasses.
pub fn StorageBuffer::construct(
  attribute : @core.BufferAttribute?,
) -> StorageBuffer {
  let buffer = match attribute {
    Some(a) => Some(a.array)
    None => None
  }
  { parent_: Buffer::construct(buffer), _attribute: attribute, }
}

///|
/// `new StorageBuffer( name, attribute )`.
pub fn StorageBuffer::new(
  name : String,
  attribute : @core.BufferAttribute?,
) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = StorageBuffer::construct(attribute)
  binding
}

///|
pub fn StorageBuffer::of(binding : Binding) -> StorageBuffer? {
  match binding.class_payload("StorageBuffer") {
    Some(p) => Some(p.cast())
    None => None
  }
}
