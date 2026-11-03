// renderers/common/Buffer.js

///|
/// The `Buffer` class payload.
pub(all) struct Buffer {
  mut bytes_per_element : Int32
  mut _buffer : @core.TypedArray?
  mut _update_ranges : Array[@core.UpdateRange]
}

///|
pub impl BindingClass for Buffer with fn class_name(_) {
  "Buffer"
}

///|
pub impl BindingClass for Buffer with fn has_flag(_, flag) {
  flag == "isBuffer"
}

///|
pub impl BindingClass for Buffer with fn copy_class(self) {
  self.copy_payload()
}

///|
pub impl BindingClass for Buffer with fn update(_, _) {
  true
}

///|
pub impl BindingClass for Buffer with fn release(self, _) {
  self._buffer = None
}

///|
pub impl BindingClass for Buffer with fn buffer(self, _) {
  self._buffer
}

///|
pub impl BindingClass for Buffer with fn byte_length(_, binding) {
  match binding.buffer() {
    Some(buffer) => get_float_length(buffer.byte_length())
    None =>
      abort("TypeError: Cannot read properties of null (reading 'byteLength')")
  }
}

///|
pub impl BindingClass for Buffer with fn update_ranges(self, _) {
  self._update_ranges
}

///|
pub impl BindingClass for Buffer with fn add_update_range(
  _,
  binding,
  start,
  count,
) {
  binding.update_ranges().push({ start, count, })
}

///|
pub impl BindingClass for Buffer with fn clear_update_ranges(_, binding) {
  binding.update_ranges().clear()
}

///|
/// The fields `Object.assign` copies (arrays are shared, as upstream).
pub fn Buffer::copy_payload(self : Buffer) -> Buffer {
  {
    bytes_per_element: self.bytes_per_element,
    _buffer: self._buffer,
    _update_ranges: self._update_ranges,
  }
}

///|
/// The payload of `super( name, buffer )` for subclasses.
pub fn Buffer::construct(buffer : @core.TypedArray?) -> Buffer {
  { bytes_per_element: 4, _buffer: buffer, _update_ranges: [], }
}

///|
/// `new Buffer( name, buffer = null )`.
pub fn Buffer::new(name : String, buffer? : @core.TypedArray) -> Binding {
  let binding = Binding::new(name~)
  binding.class_ = Buffer::construct(buffer)
  binding
}

///|
pub fn Buffer::of(binding : Binding) -> Buffer? {
  match binding.class_payload("Buffer") {
    Some(p) => Some(p.cast())
    None => None
  }
}
