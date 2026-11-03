// Upstream src/core/GLBufferAttribute.js.

///|
/// `buffer` is the application's `WebGLBuffer`; `type_` a GL type constant.
pub fn GLBufferAttribute::new(
  buffer : JsValue,
  type_ : Int32,
  item_size : Int32,
  element_size : Int32,
  count : Int32,
  normalized~ : Bool = false,
) -> GLBufferAttribute {
  {
    name: "",
    buffer,
    type_,
    item_size,
    element_size,
    count,
    normalized,
    version: 0,
  }
}

///|
/// Upstream's `needsUpdate` setter.
pub fn GLBufferAttribute::set_needs_update(
  self : GLBufferAttribute,
  value : Bool,
) -> Unit {
  if value {
    self.version += 1
  }
}

///|
pub fn GLBufferAttribute::set_buffer(
  self : GLBufferAttribute,
  buffer : JsValue,
) -> GLBufferAttribute {
  self.buffer = buffer
  self
}

///|
pub fn GLBufferAttribute::set_type(
  self : GLBufferAttribute,
  type_ : Int32,
  element_size : Int32,
) -> GLBufferAttribute {
  self.type_ = type_
  self.element_size = element_size
  self
}

///|
pub fn GLBufferAttribute::set_item_size(
  self : GLBufferAttribute,
  item_size : Int32,
) -> GLBufferAttribute {
  self.item_size = item_size
  self
}

///|
pub fn GLBufferAttribute::set_count(
  self : GLBufferAttribute,
  count : Int32,
) -> GLBufferAttribute {
  self.count = count
  self
}
