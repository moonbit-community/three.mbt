// Upstream src/extras/Controls.js.

///|
/// The overrides of a subclass of `Controls`, which live above this package.
pub(open) trait ControlsExtension {
  /// Runs after the base `connect` has stored the element.
  fn connect(Self, Controls, @core.JsValue) -> Unit = _
  fn disconnect(Self, Controls) -> Unit = _
  fn dispose(Self, Controls) -> Unit = _
  fn update(Self, Controls, Double?) -> Unit = _
}

///|
impl ControlsExtension with fn connect(_self, _controls, _element) {

}

///|
impl ControlsExtension with fn disconnect(_self, _controls) {

}

///|
impl ControlsExtension with fn dispose(_self, _controls) {

}

///|
impl ControlsExtension with fn update(_self, _controls, _delta) {

}

///|
/// Upstream `mouseButtons`.
pub(all) struct ControlsMouseButtons {
  mut left : Int32?
  mut middle : Int32?
  mut right : Int32?
}

///|
/// Upstream `touches`.
pub(all) struct ControlsTouches {
  mut one : Int32?
  mut two : Int32?
}

///|
/// Abstract base class for controls.
pub(all) struct Controls {
  dispatcher : @core.EventDispatcher
  mut object : @core.Object3D
  mut dom_element : @core.JsValue?
  mut enabled : Bool
  mut state : Int32
  mut keys : @core.JsValue
  mut mouse_buttons : ControlsMouseButtons
  mut touches : ControlsTouches
  mut extension : &ControlsExtension?
}

///|
pub impl @core.EventSource for Controls with fn event_dispatcher(self) {
  self.dispatcher
}

///|
pub impl @core.EventSource for Controls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend Controls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub fn Controls::new(
  object : @core.Object3D,
  dom_element? : @core.JsValue,
) -> Controls {
  {
    dispatcher: @core.EventDispatcher::new(),
    object,
    dom_element,
    enabled: true,
    state: -1,
    keys: @core.JsValue::object(),
    mouse_buttons: { left: None, middle: None, right: None, },
    touches: { one: None, two: None, },
    extension: None,
  }
}

///|
/// Connects the controls to the DOM.
pub fn Controls::connect(self : Controls, element : @core.JsValue) -> Unit {
  if self.dom_element is Some(_) {
    self.disconnect()
  }
  self.dom_element = Some(element)
  if self.extension is Some(extension) {
    extension.connect(self, element)
  }
}

///|
/// Disconnects the controls from the DOM.
pub fn Controls::disconnect(self : Controls) -> Unit {
  if self.extension is Some(extension) {
    extension.disconnect(self)
  }
}

///|
/// Frees all internal resources and removes all event listeners.
pub fn Controls::dispose(self : Controls) -> Unit {
  if self.extension is Some(extension) {
    extension.dispose(self)
  }
}

///|
/// Updates the internal state per simulation step.
pub fn Controls::update(self : Controls, delta? : Double) -> Unit {
  if self.extension is Some(extension) {
    extension.update(self, delta)
  }
}
