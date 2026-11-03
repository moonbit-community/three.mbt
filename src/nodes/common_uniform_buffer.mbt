// renderers/common/UniformBuffer.js

///|
/// The `UniformBuffer` class payload.
pub(all) struct UniformBuffer {
  parent_ : Buffer
}

///|
pub impl BindingClass for UniformBuffer with fn class_name(_) {
  "UniformBuffer"
}

///|
pub impl BindingClass for UniformBuffer with fn parent(self) {
  Some(self.parent_)
}

///|
pub impl BindingClass for UniformBuffer with fn has_flag(self, flag) {
  flag == "isUniformBuffer" || self.parent_.has_flag(flag)
}

///|
pub impl BindingClass for UniformBuffer with fn copy_class(self) {
  self.copy_payload()
}

///|
pub fn UniformBuffer::copy_payload(self : UniformBuffer) -> UniformBuffer {
  { parent_: self.parent_.copy_payload(), }
}

///|
/// The payload of `super( name, buffer )` for subclasses.
pub fn UniformBuffer::construct(buffer : @core.TypedArray?) -> UniformBuffer {
  { parent_: Buffer::construct(buffer), }
}

///|
/// `new UniformBuffer( name, buffer = null )`.
pub fn UniformBuffer::new(name : String, buffer? : @core.TypedArray) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = UniformBuffer::construct(buffer)
  binding
}

///|
pub fn UniformBuffer::of(binding : Binding) -> UniformBuffer? {
  match binding.class_payload("UniformBuffer") {
    Some(p) => Some(p.cast())
    None => None
  }
}
