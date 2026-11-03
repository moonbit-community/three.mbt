// Upstream src/core/EventDispatcher.js. Listener identity is `physical_equal`, which is
// JS `===` on closures on this backend, so re-adding or removing the same closure value
// behaves as upstream; see event_dispatcher_test.mbt.

///|
/// A type extending upstream `EventDispatcher`. Implement the first two methods, then
/// `pub extend T with EventSource::{add_event_listener, has_event_listener,
/// remove_event_listener, dispatch_event}`. Classes above core use `Other` as target.
pub(open) trait EventSource {
  fn event_dispatcher(Self) -> EventDispatcher
  /// What `event.target` is set to.
  fn event_target(Self) -> EventTarget
  fn add_event_listener(Self, String, (Event) -> Unit) -> Unit = _
  fn has_event_listener(Self, String, (Event) -> Unit) -> Bool = _
  fn remove_event_listener(Self, String, (Event) -> Unit) -> Unit = _
  fn dispatch_event(Self, Event) -> Unit = _
}

///|
impl EventSource with fn add_event_listener(self, type_, listener) {
  let dispatcher = self.event_dispatcher()
  let listeners = match dispatcher._listeners {
    Some(listeners) => listeners
    None => {
      let listeners = Map([])
      dispatcher._listeners = Some(listeners)
      listeners
    }
  }
  let array = match listeners.get(type_) {
    Some(array) => array
    None => {
      let array = []
      listeners[type_] = array
      array
    }
  }
  if event_listener_index(array, listener) == -1 {
    array.push(listener)
  }
}

///|
impl EventSource with fn has_event_listener(self, type_, listener) {
  guard self.event_dispatcher()._listeners is Some(listeners) else {
    return false
  }
  match listeners.get(type_) {
    Some(array) => event_listener_index(array, listener) != -1
    None => false
  }
}

///|
impl EventSource with fn remove_event_listener(self, type_, listener) {
  guard self.event_dispatcher()._listeners is Some(listeners) else { return }
  if listeners.get(type_) is Some(array) {
    let index = event_listener_index(array, listener)
    if index != -1 {
      ignore(array.remove(index))
    }
  }
}

///|
impl EventSource with fn dispatch_event(self, event) {
  guard self.event_dispatcher()._listeners is Some(listeners) else { return }
  if listeners.get(event.type_) is Some(listener_array) {
    event.target = Some(self.event_target())
    // Make a copy, in case listeners are removed while iterating.
    let array = listener_array.copy()
    for listener in array {
      listener(event)
    }
    event.target = None
  }
}

///|
fn event_listener_index(
  array : Array[(Event) -> Unit],
  listener : (Event) -> Unit,
) -> Int32 {
  for i, item in array {
    if physical_equal(item, listener) {
      return i
    }
  }
  -1
}

///|
pub fn EventDispatcher::new() -> EventDispatcher {
  { _listeners: None, }
}

///|
pub impl EventSource for EventDispatcher with fn event_dispatcher(self) {
  self
}

///|
pub impl EventSource for EventDispatcher with fn event_target(self) {
  Dispatcher(self)
}

///|
pub extend EventDispatcher with EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
/// Creates the event object upstream writes as `{ type: 'name' }`.
pub fn Event::new(type_ : String, child? : Object3D, data? : JsValue) -> Event {
  { type_, target: None, child, data, }
}
