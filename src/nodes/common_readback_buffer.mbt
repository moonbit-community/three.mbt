// renderers/common/ReadbackBuffer.js

///|
/// A GPU buffer that data is copied into for reading back on the CPU.
pub(all) struct ReadbackBuffer {
  dispatcher : @core.EventDispatcher
  mut name : String
  /// The backend's GPU buffer; `None` is `null`.
  mut buffer : @core.JsValue?
  mut max_byte_length : Int32
  mut _mapped : Bool
}

///|
pub impl @core.EventSource for ReadbackBuffer with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl @core.EventSource for ReadbackBuffer with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend ReadbackBuffer with @core.EventSource::{
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// `new ReadbackBuffer( maxByteLength )`.
pub fn ReadbackBuffer::new(max_byte_length : Int32) -> ReadbackBuffer {
  {
    dispatcher: @core.EventDispatcher::new(),
    name: "",
    buffer: None,
    max_byte_length,
    _mapped: false,
  }
}

///|
/// `release()`: dispatches `release`.
pub fn ReadbackBuffer::release(self : ReadbackBuffer) -> Unit {
  self.dispatch_event(@core.Event::new("release"))
}

///|
/// `dispose()`: dispatches `dispose`.
pub fn ReadbackBuffer::dispose(self : ReadbackBuffer) -> Unit {
  self.dispatch_event(@core.Event::new("dispose"))
}
