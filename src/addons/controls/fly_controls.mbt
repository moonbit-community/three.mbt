// Upstream examples/jsm/controls/FlyControls.js.

///|
let _fly_change_event : @core.Event = @core.Event::new("change")

///|
let _fly_eps : Double = 0.000001

///|
let _fly_tmp_quaternion : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
/// Upstream `_moveState`.
pub(all) struct FlyMoveState {
  mut up : Double
  mut down : Double
  mut left : Double
  mut right : Double
  mut forward : Double
  mut back : Double
  mut pitch_up : Double
  mut pitch_down : Double
  mut yaw_left : Double
  mut yaw_right : Double
  mut roll_left : Double
  mut roll_right : Double
}

///|
/// Flies an object around with WASD/RF, the arrow keys, QE and the pointer.
pub(all) struct FlyControls {
  base : @extras.Controls
  mut movement_speed : Double
  mut roll_speed : Double
  mut drag_to_look : Bool
  mut auto_forward : Bool
  /// Set by the Shift keys; upstream never reads it.
  mut movement_speed_multiplier : Double?
  _move_state : FlyMoveState
  _move_vector : @math.Vector3
  _rotation_vector : @math.Vector3
  _last_quaternion : @math.Quaternion
  _last_position : @math.Vector3
  mut _status : Int32
  mut _on_key_down : (@core.JsValue) -> Unit
  mut _on_key_up : (@core.JsValue) -> Unit
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_up : (@core.JsValue) -> Unit
  mut _on_pointer_cancel : (@core.JsValue) -> Unit
  mut _on_context_menu : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for FlyControls with fn event_dispatcher(self) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for FlyControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend FlyControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for FlyControls with fn connect(self, _, _) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for FlyControls with fn disconnect(self, _) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for FlyControls with fn dispose(self, _) {
  self.dispose()
}

///|
pub impl @extras.ControlsExtension for FlyControls with fn update(
  self,
  _,
  delta,
) {
  self.update(delta.unwrap_or(js_undefined_number()))
}

///|
/// `new FlyControls( object, domElement )`.
pub fn FlyControls::new(
  object : @core.Object3D,
  dom_element? : @core.JsValue,
) -> FlyControls {
  let base = @extras.Controls::new(object, dom_element?)
  let self : FlyControls = {
    base,
    movement_speed: 1.0,
    roll_speed: 0.005,
    drag_to_look: false,
    auto_forward: false,
    movement_speed_multiplier: None,
    _move_state: {
      up: 0.0,
      down: 0.0,
      left: 0.0,
      right: 0.0,
      forward: 0.0,
      back: 0.0,
      pitch_up: 0.0,
      pitch_down: 0.0,
      yaw_left: 0.0,
      yaw_right: 0.0,
      roll_left: 0.0,
      roll_right: 0.0,
    },
    _move_vector: @math.Vector3::new(0.0, 0.0, 0.0),
    _rotation_vector: @math.Vector3::new(0.0, 0.0, 0.0),
    _last_quaternion: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _last_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _status: 0,
    _on_key_down: noop_listener,
    _on_key_up: noop_listener,
    _on_pointer_move: noop_listener,
    _on_pointer_down: noop_listener,
    _on_pointer_up: noop_listener,
    _on_pointer_cancel: noop_listener,
    _on_context_menu: noop_listener,
  }
  self._on_key_down = fn(event) { self.on_key_down(event) }
  self._on_key_up = fn(event) { self.on_key_up(event) }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
  self._on_pointer_up = fn(event) { self.on_pointer_up(event) }
  self._on_pointer_cancel = fn(_) { self.on_pointer_cancel() }
  self._on_context_menu = fn(event) { self.on_context_menu(event) }
  base.extension = Some(self)
  if dom_element is Some(element) {
    self.connect(element)
  }
  self
}

///|
/// Connects the controls to the DOM element.
pub fn FlyControls::connect(
  self : FlyControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn FlyControls::connect_listeners(self : FlyControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  dom_add_event_listener(window, "keydown", self._on_key_down)
  dom_add_event_listener(window, "keyup", self._on_key_up)
  dom_add_event_listener(element, "pointermove", self._on_pointer_move)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "pointerup", self._on_pointer_up)
  dom_add_event_listener(element, "pointercancel", self._on_pointer_cancel)
  dom_add_event_listener(element, "contextmenu", self._on_context_menu)
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn FlyControls::disconnect(self : FlyControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  dom_remove_event_listener(window, "keydown", self._on_key_down)
  dom_remove_event_listener(window, "keyup", self._on_key_up)
  dom_remove_event_listener(element, "pointermove", self._on_pointer_move)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(element, "pointerup", self._on_pointer_up)
  dom_remove_event_listener(element, "pointercancel", self._on_pointer_cancel)
  dom_remove_event_listener(element, "contextmenu", self._on_context_menu)
  dom_set_style(element, "touchAction", "")
}

///|
/// Frees the controls' resources and removes all event listeners.
pub fn FlyControls::dispose(self : FlyControls) -> Unit {
  self.disconnect()
}

///|
/// Moves and rotates the object; `delta` is the time step in seconds.
pub fn FlyControls::update(self : FlyControls, delta : Double) -> Unit {
  if !self.base.enabled {
    return
  }
  let object = self.base.object
  let move_mult = delta * self.movement_speed
  let rot_mult = delta * self.roll_speed
  ignore(object.translate_x(self._move_vector.x * move_mult))
  ignore(object.translate_y(self._move_vector.y * move_mult))
  ignore(object.translate_z(self._move_vector.z * move_mult))
  ignore(
    _fly_tmp_quaternion
    .set(
      self._rotation_vector.x * rot_mult,
      self._rotation_vector.y * rot_mult,
      self._rotation_vector.z * rot_mult,
      1.0,
    )
    .normalize(),
  )
  ignore(object.quaternion.multiply(_fly_tmp_quaternion))
  if self._last_position.distance_to_squared(object.position) > _fly_eps ||
    8.0 * (1.0 - self._last_quaternion.dot(object.quaternion)) > _fly_eps {
    self.dispatch_event(_fly_change_event)
    ignore(self._last_quaternion.copy(object.quaternion))
    ignore(self._last_position.copy(object.position))
  }
}

///|
fn FlyControls::_update_movement_vector(self : FlyControls) -> Unit {
  let state = self._move_state
  let forward = if js_number_truthy(state.forward) ||
    (self.auto_forward && !js_number_truthy(state.back)) {
    1.0
  } else {
    0.0
  }
  self._move_vector.x = -state.left + state.right
  self._move_vector.y = -state.down + state.up
  self._move_vector.z = -forward + state.back
}

///|
fn FlyControls::_update_rotation_vector(self : FlyControls) -> Unit {
  let state = self._move_state
  self._rotation_vector.x = -state.pitch_down + state.pitch_up
  self._rotation_vector.y = -state.yaw_right + state.yaw_left
  self._rotation_vector.z = -state.roll_right + state.roll_left
}

///|
/// `size` and `offset` of the container, as `[ width, height ]` and `[ left, top ]`.
fn FlyControls::_get_container_dimensions(
  self : FlyControls,
) -> ((Double, Double), (Double, Double)) {
  let element = dom_element_of(self.base)
  if !element.strict_equal(dom_document()) {
    (
      (dom_num(element, "offsetWidth"), dom_num(element, "offsetHeight")),
      (dom_num(element, "offsetLeft"), dom_num(element, "offsetTop")),
    )
  } else {
    let window = dom_window()
    (
      (dom_num(window, "innerWidth"), dom_num(window, "innerHeight")),
      (0.0, 0.0),
    )
  }
}

///|
fn FlyControls::on_key_down(self : FlyControls, event : @core.JsValue) -> Unit {
  if ev_bool(event, "altKey") || !self.base.enabled {
    return
  }
  let state = self._move_state
  match ev_str(event, "code") {
    Some("ShiftLeft") | Some("ShiftRight") =>
      self.movement_speed_multiplier = Some(0.1)
    Some("KeyW") => state.forward = 1.0
    Some("KeyS") => state.back = 1.0
    Some("KeyA") => state.left = 1.0
    Some("KeyD") => state.right = 1.0
    Some("KeyR") => state.up = 1.0
    Some("KeyF") => state.down = 1.0
    Some("ArrowUp") => state.pitch_up = 1.0
    Some("ArrowDown") => state.pitch_down = 1.0
    Some("ArrowLeft") => state.yaw_left = 1.0
    Some("ArrowRight") => state.yaw_right = 1.0
    Some("KeyQ") => state.roll_left = 1.0
    Some("KeyE") => state.roll_right = 1.0
    _ => ()
  }
  self._update_movement_vector()
  self._update_rotation_vector()
}

///|
fn FlyControls::on_key_up(self : FlyControls, event : @core.JsValue) -> Unit {
  if !self.base.enabled {
    return
  }
  let state = self._move_state
  match ev_str(event, "code") {
    Some("ShiftLeft") | Some("ShiftRight") =>
      self.movement_speed_multiplier = Some(1.0)
    Some("KeyW") => state.forward = 0.0
    Some("KeyS") => state.back = 0.0
    Some("KeyA") => state.left = 0.0
    Some("KeyD") => state.right = 0.0
    Some("KeyR") => state.up = 0.0
    Some("KeyF") => state.down = 0.0
    Some("ArrowUp") => state.pitch_up = 0.0
    Some("ArrowDown") => state.pitch_down = 0.0
    Some("ArrowLeft") => state.yaw_left = 0.0
    Some("ArrowRight") => state.yaw_right = 0.0
    Some("KeyQ") => state.roll_left = 0.0
    Some("KeyE") => state.roll_right = 0.0
    _ => ()
  }
  self._update_movement_vector()
  self._update_rotation_vector()
}

///|
fn FlyControls::on_pointer_down(
  self : FlyControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if self.drag_to_look {
    self._status += 1
  } else {
    let button = ev_num(event, "button")
    if button == 0.0 {
      self._move_state.forward = 1.0
    } else if button == 2.0 {
      self._move_state.back = 1.0
    }
    self._update_movement_vector()
  }
}

///|
fn FlyControls::on_pointer_move(
  self : FlyControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if !self.drag_to_look || self._status > 0 {
    let ((width, height), (left, top)) = self._get_container_dimensions()
    let half_width = width / 2.0
    let half_height = height / 2.0
    self._move_state.yaw_left = -(ev_num(event, "pageX") - left - half_width) /
      half_width
    self._move_state.pitch_down = (ev_num(event, "pageY") - top - half_height) /
      half_height
    self._update_rotation_vector()
  }
}

///|
fn FlyControls::on_pointer_up(
  self : FlyControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if self.drag_to_look {
    self._status -= 1
    self._move_state.pitch_down = 0.0
    self._move_state.yaw_left = 0.0
  } else {
    let button = ev_num(event, "button")
    if button == 0.0 {
      self._move_state.forward = 0.0
    } else if button == 2.0 {
      self._move_state.back = 0.0
    }
    self._update_movement_vector()
  }
  self._update_rotation_vector()
}

///|
fn FlyControls::on_pointer_cancel(self : FlyControls) -> Unit {
  if !self.base.enabled {
    return
  }
  if self.drag_to_look {
    self._status = 0
    self._move_state.pitch_down = 0.0
    self._move_state.yaw_left = 0.0
  } else {
    self._move_state.forward = 0.0
    self._move_state.back = 0.0
    self._update_movement_vector()
  }
  self._update_rotation_vector()
}

///|
fn FlyControls::on_context_menu(
  self : FlyControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  prevent_default(event)
}
