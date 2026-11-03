// Upstream examples/jsm/controls/PointerLockControls.js.

///|
let _pointer_lock_euler : @math.Euler = @math.Euler::new(
  0.0,
  0.0,
  0.0,
  order="YXZ",
)

///|
let _pointer_lock_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _pointer_lock_change_event : @core.Event = @core.Event::new("change")

///|
let _pointer_lock_lock_event : @core.Event = @core.Event::new("lock")

///|
let _pointer_lock_unlock_event : @core.Event = @core.Event::new("unlock")

///|
let _pointer_lock_mouse_sensitivity : Double = 0.002

///|
let _pointer_lock_pi_2 : Double = js_pi / 2.0

///|
/// Mouse look through the Pointer Lock API, for first-person games.
pub(all) struct PointerLockControls {
  base : @extras.Controls
  mut is_locked : Bool
  mut min_polar_angle : Double
  mut max_polar_angle : Double
  mut pointer_speed : Double
  mut _on_mouse_move : (@core.JsValue) -> Unit
  mut _on_pointerlock_change : (@core.JsValue) -> Unit
  mut _on_pointerlock_error : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for PointerLockControls with fn event_dispatcher(
  self,
) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for PointerLockControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend PointerLockControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for PointerLockControls with fn connect(
  self,
  _,
  _,
) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for PointerLockControls with fn disconnect(
  self,
  _,
) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for PointerLockControls with fn dispose(
  self,
  _,
) {
  self.dispose()
}

///|
/// `new PointerLockControls( camera, domElement )`.
pub fn PointerLockControls::new(
  camera : @core.Object3D,
  dom_element? : @core.JsValue,
) -> PointerLockControls {
  let base = @extras.Controls::new(camera, dom_element?)
  let self : PointerLockControls = {
    base,
    is_locked: false,
    min_polar_angle: 0.0,
    max_polar_angle: js_pi,
    pointer_speed: 1.0,
    _on_mouse_move: noop_listener,
    _on_pointerlock_change: noop_listener,
    _on_pointerlock_error: noop_listener,
  }
  self._on_mouse_move = fn(event) { self.on_mouse_move(event) }
  self._on_pointerlock_change = fn(_) { self.on_pointerlock_change() }
  self._on_pointerlock_error = fn(_) { self.on_pointerlock_error() }
  base.extension = Some(self)
  if base.dom_element is Some(element) {
    self.connect(element)
  }
  self
}

///|
/// Connects the controls to the DOM element.
pub fn PointerLockControls::connect(
  self : PointerLockControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn PointerLockControls::connect_listeners(self : PointerLockControls) -> Unit {
  let document = dom_owner_document(dom_element_of(self.base))
  dom_add_event_listener(document, "mousemove", self._on_mouse_move)
  dom_add_event_listener(
    document,
    "pointerlockchange",
    self._on_pointerlock_change,
  )
  dom_add_event_listener(
    document,
    "pointerlockerror",
    self._on_pointerlock_error,
  )
}

///|
/// Disconnects the controls from the DOM.
pub fn PointerLockControls::disconnect(self : PointerLockControls) -> Unit {
  let document = dom_owner_document(dom_element_of(self.base))
  dom_remove_event_listener(document, "mousemove", self._on_mouse_move)
  dom_remove_event_listener(
    document,
    "pointerlockchange",
    self._on_pointerlock_change,
  )
  dom_remove_event_listener(
    document,
    "pointerlockerror",
    self._on_pointerlock_error,
  )
}

///|
/// Frees the controls' resources and removes all event listeners.
pub fn PointerLockControls::dispose(self : PointerLockControls) -> Unit {
  self.disconnect()
}

///|
/// Writes the look direction of the camera to `v` and returns it.
pub fn PointerLockControls::get_direction(
  self : PointerLockControls,
  v : @math.Vector3,
) -> @math.Vector3 {
  v.set(0.0, 0.0, -1.0).apply_quaternion(self.base.object.quaternion)
}

///|
/// Moves the camera forward parallel to the xz-plane; assumes `camera.up` is y-up.
pub fn PointerLockControls::move_forward(
  self : PointerLockControls,
  distance : Double,
) -> Unit {
  if !self.base.enabled {
    return
  }
  let camera = self.base.object
  ignore(_pointer_lock_vector.set_from_matrix_column(camera.matrix, 0))
  ignore(_pointer_lock_vector.cross_vectors(camera.up, _pointer_lock_vector))
  ignore(camera.position.add_scaled_vector(_pointer_lock_vector, distance))
}

///|
/// Moves the camera sidewards parallel to the xz-plane.
pub fn PointerLockControls::move_right(
  self : PointerLockControls,
  distance : Double,
) -> Unit {
  if !self.base.enabled {
    return
  }
  let camera = self.base.object
  ignore(_pointer_lock_vector.set_from_matrix_column(camera.matrix, 0))
  ignore(camera.position.add_scaled_vector(_pointer_lock_vector, distance))
}

///|
/// Activates the pointer lock.
pub fn PointerLockControls::lock(
  self : PointerLockControls,
  unadjusted_movement~ : Bool = false,
) -> Unit {
  dom_request_pointer_lock(dom_element_of(self.base), unadjusted_movement)
}

///|
/// Exits the pointer lock.
pub fn PointerLockControls::unlock(self : PointerLockControls) -> Unit {
  dom_exit_pointer_lock(dom_owner_document(dom_element_of(self.base)))
}

///|
fn PointerLockControls::on_mouse_move(
  self : PointerLockControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled || !self.is_locked {
    return
  }
  let camera = self.base.object
  ignore(_pointer_lock_euler.set_from_quaternion(camera.quaternion))
  _pointer_lock_euler.set_y(
    _pointer_lock_euler.y -
    ev_num(event, "movementX") *
    _pointer_lock_mouse_sensitivity *
    self.pointer_speed,
  )
  _pointer_lock_euler.set_x(
    _pointer_lock_euler.x -
    ev_num(event, "movementY") *
    _pointer_lock_mouse_sensitivity *
    self.pointer_speed,
  )
  _pointer_lock_euler.set_x(
    js_max(
      _pointer_lock_pi_2 - self.max_polar_angle,
      js_min(_pointer_lock_pi_2 - self.min_polar_angle, _pointer_lock_euler.x),
    ),
  )
  ignore(camera.quaternion.set_from_euler(_pointer_lock_euler))
  self.dispatch_event(_pointer_lock_change_event)
}

///|
fn PointerLockControls::on_pointerlock_change(
  self : PointerLockControls,
) -> Unit {
  let element = dom_element_of(self.base)
  if dom_owner_document(element).get("pointerLockElement").strict_equal(element) {
    self.dispatch_event(_pointer_lock_lock_event)
    self.is_locked = true
  } else {
    self.dispatch_event(_pointer_lock_unlock_event)
    self.is_locked = false
  }
}

///|
fn PointerLockControls::on_pointerlock_error(
  self : PointerLockControls,
) -> Unit {
  ignore(self)
  println("THREE.PointerLockControls: Unable to use Pointer Lock API")
}
