// Upstream examples/jsm/controls/FirstPersonControls.js.

///|
let _first_person_look_direction : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _first_person_spherical : @math.Spherical = @math.Spherical::new(
  1.0, 0.0, 0.0,
)

///|
let _first_person_target : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _first_person_target_position : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _first_person_target_velocity : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
/// Moves and looks around like a first-person game camera.
pub(all) struct FirstPersonControls {
  base : @extras.Controls
  mut movement_speed : Double
  mut look_speed : Double
  mut damping_factor : Double
  mut look_vertical : Bool
  mut auto_forward : Bool
  mut height_speed : Bool
  mut height_coef : Double
  mut height_min : Double
  mut height_max : Double
  mut constrain_vertical : Bool
  mut vertical_min : Double
  mut vertical_max : Double
  mut mouse_drag_on : Bool
  _velocity : @math.Vector3
  mut _pointer_x : Double
  mut _pointer_y : Double
  mut _pointer_down_x : Double
  mut _pointer_down_y : Double
  mut _pointer_count : Int32
  mut _key_forward : Bool
  mut _key_backward : Bool
  mut _pointer_forward : Bool
  mut _pointer_backward : Bool
  mut _move_left : Bool
  mut _move_right : Bool
  mut _move_up : Bool
  mut _move_down : Bool
  mut _lat : Double
  mut _lon : Double
  mut _lon_velocity : Double
  mut _lat_velocity : Double
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_up : (@core.JsValue) -> Unit
  mut _on_context_menu : (@core.JsValue) -> Unit
  mut _on_key_down : (@core.JsValue) -> Unit
  mut _on_key_up : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for FirstPersonControls with fn event_dispatcher(
  self,
) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for FirstPersonControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend FirstPersonControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for FirstPersonControls with fn connect(
  self,
  _,
  _,
) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for FirstPersonControls with fn disconnect(
  self,
  _,
) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for FirstPersonControls with fn dispose(
  self,
  _,
) {
  self.dispose()
}

///|
pub impl @extras.ControlsExtension for FirstPersonControls with fn update(
  self,
  _,
  delta,
) {
  self.update(delta.unwrap_or(js_undefined_number()))
}

///|
/// `new FirstPersonControls( object, domElement )`.
pub fn FirstPersonControls::new(
  object : @core.Object3D,
  dom_element? : @core.JsValue,
) -> FirstPersonControls {
  let base = @extras.Controls::new(object, dom_element?)
  let self : FirstPersonControls = {
    base,
    movement_speed: 1.0,
    look_speed: 0.005,
    damping_factor: 0.1,
    look_vertical: true,
    auto_forward: false,
    height_speed: false,
    height_coef: 1.0,
    height_min: 0.0,
    height_max: 1.0,
    constrain_vertical: false,
    vertical_min: 0.0,
    vertical_max: js_pi,
    mouse_drag_on: false,
    _velocity: @math.Vector3::new(0.0, 0.0, 0.0),
    _pointer_x: 0.0,
    _pointer_y: 0.0,
    _pointer_down_x: 0.0,
    _pointer_down_y: 0.0,
    _pointer_count: 0,
    _key_forward: false,
    _key_backward: false,
    _pointer_forward: false,
    _pointer_backward: false,
    _move_left: false,
    _move_right: false,
    _move_up: false,
    _move_down: false,
    _lat: 0.0,
    _lon: 0.0,
    _lon_velocity: 0.0,
    _lat_velocity: 0.0,
    _on_pointer_move: noop_listener,
    _on_pointer_down: noop_listener,
    _on_pointer_up: noop_listener,
    _on_context_menu: noop_listener,
    _on_key_down: noop_listener,
    _on_key_up: noop_listener,
  }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
  self._on_pointer_up = fn(event) { self.on_pointer_up(event) }
  self._on_context_menu = fn(event) { self.on_context_menu(event) }
  self._on_key_down = fn(event) { self.on_key_down(event) }
  self._on_key_up = fn(event) { self.on_key_up(event) }
  base.extension = Some(self)
  if dom_element is Some(element) {
    self.connect(element)
  }
  self._set_orientation()
  self
}

///|
/// Connects the controls to the DOM element.
pub fn FirstPersonControls::connect(
  self : FirstPersonControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn FirstPersonControls::connect_listeners(self : FirstPersonControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  dom_add_event_listener(window, "keydown", self._on_key_down)
  dom_add_event_listener(window, "keyup", self._on_key_up)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "contextmenu", self._on_context_menu)
  let owner_document = dom_owner_document(element)
  dom_add_event_listener(owner_document, "pointermove", self._on_pointer_move)
  dom_add_event_listener(owner_document, "pointerup", self._on_pointer_up)
  dom_add_event_listener(owner_document, "pointercancel", self._on_pointer_up)
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn FirstPersonControls::disconnect(self : FirstPersonControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  dom_remove_event_listener(window, "keydown", self._on_key_down)
  dom_remove_event_listener(window, "keyup", self._on_key_up)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(element, "contextmenu", self._on_context_menu)
  let owner_document = dom_owner_document(element)
  dom_remove_event_listener(
    owner_document,
    "pointermove",
    self._on_pointer_move,
  )
  dom_remove_event_listener(owner_document, "pointerup", self._on_pointer_up)
  dom_remove_event_listener(
    owner_document,
    "pointercancel",
    self._on_pointer_up,
  )
  dom_set_style(element, "touchAction", "")
}

///|
/// Frees the controls' resources and removes all event listeners.
pub fn FirstPersonControls::dispose(self : FirstPersonControls) -> Unit {
  self.disconnect()
}

///|
/// Points the object at `target` and updates the look angles.
pub fn FirstPersonControls::look_at(
  self : FirstPersonControls,
  target : @math.Vector3,
) -> FirstPersonControls {
  ignore(_first_person_target.copy(target))
  self.base.object.look_at(_first_person_target)
  self._set_orientation()
  self
}

///|
/// `lookAt( x, y, z )`.
pub fn FirstPersonControls::look_at_xyz(
  self : FirstPersonControls,
  x : Double,
  y : Double,
  z : Double,
) -> FirstPersonControls {
  ignore(_first_person_target.set(x, y, z))
  self.base.object.look_at(_first_person_target)
  self._set_orientation()
  self
}

///|
/// Moves and turns the object; `delta` is the time step in seconds.
pub fn FirstPersonControls::update(
  self : FirstPersonControls,
  delta : Double,
) -> Unit {
  if !self.base.enabled {
    return
  }
  let object = self.base.object
  let mut drive = (if self._key_forward { 1.0 } else { 0.0 }) -
    (if self._key_backward { 1.0 } else { 0.0 })
  let mut look_move = (if self._pointer_forward { 1.0 } else { 0.0 }) -
    (if self._pointer_backward { 1.0 } else { 0.0 })
  if self.auto_forward && drive == 0.0 && look_move == 0.0 {
    look_move = 1.0
  }
  // faster forward movement the higher the camera is
  let mut forward_speed = self.movement_speed
  if self.height_speed {
    let y = @math.clamp(object.position.y, self.height_min, self.height_max)
    forward_speed += (y - self.height_min) * self.height_coef
  }
  // target velocity in world space: keys are world axis aligned, moving in the
  // XZ plane from the camera's yaw only (R / F along world Y), while pointer
  // and touch input moves along the look direction
  let yaw = @math.deg_to_rad(self._lon)
  let sin_yaw = js_sin(yaw)
  let cos_yaw = js_cos(yaw)
  let mut strafe = (if self._move_right { 1.0 } else { 0.0 }) -
    (if self._move_left { 1.0 } else { 0.0 })
  let mut climb = (if self._move_up { 1.0 } else { 0.0 }) -
    (if self._move_down { 1.0 } else { 0.0 })
  // normalize combined key input so diagonal movement isn't faster
  let key_scale = 1.0 /
    js_max(1.0, js_sqrt(strafe * strafe + climb * climb + drive * drive))
  strafe *= self.movement_speed * key_scale
  climb *= self.movement_speed * key_scale
  drive *= (if drive > 0.0 { forward_speed } else { self.movement_speed }) *
    key_scale
  ignore(
    _first_person_target_velocity.set(
      sin_yaw * drive - cos_yaw * strafe,
      climb,
      cos_yaw * drive + sin_yaw * strafe,
    ),
  )
  if look_move != 0.0 {
    ignore(
      _first_person_look_direction
      .set(0.0, 0.0, -1.0)
      .apply_quaternion(object.quaternion),
    )
    ignore(
      _first_person_target_velocity.add_scaled_vector(
        _first_person_look_direction,
        look_move *
        (if look_move > 0.0 { forward_speed } else { self.movement_speed }),
      ),
    )
  }
  // ease toward the target velocity for smooth acceleration and deceleration
  ignore(
    self._velocity.lerp(_first_person_target_velocity, self.damping_factor),
  )
  ignore(object.position.add_scaled_vector(self._velocity, delta))
  let mut vertical_look_ratio = 1.0
  if self.constrain_vertical {
    vertical_look_ratio = js_pi / (self.vertical_max - self.vertical_min)
  }
  // target look velocity, zero when not dragging so the view eases to a stop
  let target_lon = if self.mouse_drag_on {
    -self._pointer_x * self.look_speed
  } else {
    0.0
  }
  let target_lat = if self.mouse_drag_on && self.look_vertical {
    -self._pointer_y * self.look_speed * vertical_look_ratio
  } else {
    0.0
  }
  self._lon_velocity = @math.lerp(
    self._lon_velocity,
    target_lon,
    self.damping_factor,
  )
  self._lat_velocity = @math.lerp(
    self._lat_velocity,
    target_lat,
    self.damping_factor,
  )
  self._lon += self._lon_velocity * delta
  self._lat += self._lat_velocity * delta
  self._lat = js_max(-85.0, js_min(85.0, self._lat))
  let mut phi = @math.deg_to_rad(90.0 - self._lat)
  let theta = @math.deg_to_rad(self._lon)
  if self.constrain_vertical {
    phi = @math.map_linear(
      phi,
      0.0,
      js_pi,
      self.vertical_min,
      self.vertical_max,
    )
  }
  let position = object.position
  ignore(
    _first_person_target_position
    .set_from_spherical_coords(1.0, phi, theta)
    .add(position),
  )
  object.look_at(_first_person_target_position)
}

///|
fn FirstPersonControls::_set_orientation(self : FirstPersonControls) -> Unit {
  let quaternion = self.base.object.quaternion
  ignore(
    _first_person_look_direction
    .set(0.0, 0.0, -1.0)
    .apply_quaternion(quaternion),
  )
  ignore(_first_person_spherical.set_from_vector3(_first_person_look_direction))
  self._lat = 90.0 - @math.rad_to_deg(_first_person_spherical.phi)
  self._lon = @math.rad_to_deg(_first_person_spherical.theta)
}

///|
/// Removed upstream; warns as upstream does.
pub fn FirstPersonControls::handle_resize(self : FirstPersonControls) -> Unit {
  ignore(self)
  println("THREE.FirstPersonControls: handleResize() has been removed.")
}

///|
fn FirstPersonControls::on_pointer_down(
  self : FirstPersonControls,
  event : @core.JsValue,
) -> Unit {
  let element = dom_element_of(self.base)
  if !element.strict_equal(dom_document()) {
    dom_focus(element)
  }
  dom_set_pointer_capture(element, ev_num(event, "pointerId"))
  self._pointer_count += 1
  if ev_is(event, "pointerType", "touch") {
    self._pointer_forward = self._pointer_count == 1
    self._pointer_backward = self._pointer_count >= 2
  } else {
    let button = ev_num(event, "button")
    if button == 0.0 {
      if !self._key_forward && !self._key_backward {
        self._pointer_forward = true
      }
    } else if button == 2.0 {
      if !self._key_forward && !self._key_backward {
        self._pointer_backward = true
      }
    }
  }
  self._pointer_down_x = ev_num(event, "pageX")
  self._pointer_down_y = ev_num(event, "pageY")
  self._pointer_x = 0.0
  self._pointer_y = 0.0
  self.mouse_drag_on = true
}

///|
fn FirstPersonControls::on_pointer_up(
  self : FirstPersonControls,
  event : @core.JsValue,
) -> Unit {
  if !self.mouse_drag_on {
    return
  }
  dom_release_pointer_capture(
    dom_element_of(self.base),
    ev_num(event, "pointerId"),
  )
  self._pointer_count -= 1
  if ev_is(event, "pointerType", "touch") {
    self._pointer_forward = self._pointer_count == 1
    self._pointer_backward = false
  } else {
    let button = ev_num(event, "button")
    if button == 0.0 {
      self._pointer_forward = false
    } else if button == 2.0 {
      self._pointer_backward = false
    }
  }
  self._pointer_x = 0.0
  self._pointer_y = 0.0
  if self._pointer_count == 0 {
    self.mouse_drag_on = false
  }
}

///|
fn FirstPersonControls::on_pointer_move(
  self : FirstPersonControls,
  event : @core.JsValue,
) -> Unit {
  if !self.mouse_drag_on {
    return
  }
  self._pointer_x = ev_num(event, "pageX") - self._pointer_down_x
  self._pointer_y = ev_num(event, "pageY") - self._pointer_down_y
}

///|
fn FirstPersonControls::on_key_down(
  self : FirstPersonControls,
  event : @core.JsValue,
) -> Unit {
  match ev_str(event, "code") {
    Some("ArrowUp") | Some("KeyW") => self._key_forward = true
    Some("ArrowLeft") | Some("KeyA") => self._move_left = true
    Some("ArrowDown") | Some("KeyS") => self._key_backward = true
    Some("ArrowRight") | Some("KeyD") => self._move_right = true
    Some("KeyR") => self._move_up = true
    Some("KeyF") => self._move_down = true
    _ => ()
  }
}

///|
fn FirstPersonControls::on_key_up(
  self : FirstPersonControls,
  event : @core.JsValue,
) -> Unit {
  match ev_str(event, "code") {
    Some("ArrowUp") | Some("KeyW") => self._key_forward = false
    Some("ArrowLeft") | Some("KeyA") => self._move_left = false
    Some("ArrowDown") | Some("KeyS") => self._key_backward = false
    Some("ArrowRight") | Some("KeyD") => self._move_right = false
    Some("KeyR") => self._move_up = false
    Some("KeyF") => self._move_down = false
    _ => ()
  }
}

///|
fn FirstPersonControls::on_context_menu(
  self : FirstPersonControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  prevent_default(event)
}
