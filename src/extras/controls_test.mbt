// Upstream has no test file for Controls.

///|
test "Controls defaults" {
  let object = @core.Object3D::new()
  let controls = @extras.Controls::new(object)
  assert_true(physical_equal(controls.object, object))
  assert_true(controls.dom_element is None)
  assert_true(controls.enabled)
  assert_eq(controls.state, -1)
  assert_eq(controls.keys.key_count(), 0)
  assert_true(controls.mouse_buttons.left is None)
  assert_true(controls.touches.two is None)
}

///|
test "Controls dispatches events as an EventDispatcher" {
  let controls = @extras.Controls::new(@core.Object3D::new())
  let mut calls = 0
  let listener = fn(event : @core.Event) {
    calls += 1
    assert_true(event.target is Some(Other(_))) catch {
      _ => abort("no target")
    }
  }
  controls.add_event_listener("change", listener)
  assert_true(controls.has_event_listener("change", listener))
  controls.dispatch_event(@core.Event::new("change"))
  assert_eq(calls, 1)
  controls.remove_event_listener("change", listener)
  controls.dispatch_event(@core.Event::new("change"))
  assert_eq(calls, 1)
}

///|
priv struct RecordingControls {
  log : Array[String]
}

///|
impl @extras.ControlsExtension for RecordingControls with fn connect(
  self,
  _controls,
  _element,
) {
  self.log.push("connect")
}

///|
impl @extras.ControlsExtension for RecordingControls with fn disconnect(
  self,
  _controls,
) {
  self.log.push("disconnect")
}

///|
impl @extras.ControlsExtension for RecordingControls with fn dispose(
  self,
  _controls,
) {
  self.log.push("dispose")
}

///|
impl @extras.ControlsExtension for RecordingControls with fn update(
  self,
  _controls,
  delta,
) {
  self.log.push(if delta is Some(_) { "update" } else { "update none" })
}

///|
test "Controls connect disconnects from the previous element first" {
  let recording = RecordingControls::{ log: [], }
  let controls = @extras.Controls::new(@core.Object3D::new())
  controls.extension = Some(recording)
  let first = @core.JsValue::object()
  let second = @core.JsValue::object()
  controls.connect(first)
  assert_eq(recording.log, ["connect"])
  controls.connect(second)
  assert_eq(recording.log, ["connect", "disconnect", "connect"])
  assert_true(controls.dom_element.unwrap().strict_equal(second))
  controls.update(delta=0.5)
  controls.dispose()
  assert_eq(recording.log.length(), 5)
}

///|
test "Controls base methods do nothing without an extension" {
  let controls = @extras.Controls::new(
    @core.Object3D::new(),
    dom_element=@core.JsValue::object(),
  )
  controls.disconnect()
  controls.dispose()
  controls.update()
  assert_true(controls.dom_element is Some(_))
}
