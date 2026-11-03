// Upstream examples/jsm/controls/OrbitControls.js. MapControls (map_controls.mbt) is
// an OrbitControls whose `_handle_mouse_down_pan` / `_handle_mouse_move_pan` are
// overridden; `_pan_world_start` is `Some` for it.

///|
let _orbit_change_event : @core.Event = @core.Event::new("change")

///|
let _orbit_start_event : @core.Event = @core.Event::new("start")

///|
let _orbit_end_event : @core.Event = @core.Event::new("end")

///|
let _orbit_ray : @math.Ray = @math.Ray::new()

///|
let _orbit_plane : @math.Plane = @math.Plane::new()

///|
let _orbit_tilt_limit : Double = js_cos(70.0 * @math.DEG2RAD)

///|
let _orbit_v : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _orbit_two_pi : Double = 2.0 * js_pi

///|
const ORBIT_STATE_NONE : Int32 = -1

///|
const ORBIT_STATE_ROTATE : Int32 = 0

///|
const ORBIT_STATE_DOLLY : Int32 = 1

///|
const ORBIT_STATE_PAN : Int32 = 2

///|
const ORBIT_STATE_TOUCH_ROTATE : Int32 = 3

///|
const ORBIT_STATE_TOUCH_PAN : Int32 = 4

///|
const ORBIT_STATE_TOUCH_DOLLY_PAN : Int32 = 5

///|
const ORBIT_STATE_TOUCH_DOLLY_ROTATE : Int32 = 6

///|
let _orbit_eps : Double = 0.000001

///|
extern "js" fn orbit_default_keys() -> @core.JsValue = "() => ({ LEFT: 'ArrowLeft', UP: 'ArrowUp', RIGHT: 'ArrowRight', BOTTOM: 'ArrowDown' })"

///|
/// Orbits, dollies (zooms) and pans a camera around `target`.
pub(all) struct OrbitControls {
  /// The `Controls` part: `object`, `dom_element`, `enabled`, `state`, `keys`,
  /// `mouse_buttons`, `touches` and the event dispatcher.
  base : @extras.Controls
  mut target : @math.Vector3
  mut cursor : @math.Vector3
  mut min_distance : Double
  mut max_distance : Double
  mut min_zoom : Double
  mut max_zoom : Double
  mut min_target_radius : Double
  mut max_target_radius : Double
  mut min_polar_angle : Double
  mut max_polar_angle : Double
  mut min_azimuth_angle : Double
  mut max_azimuth_angle : Double
  mut enable_damping : Bool
  mut damping_factor : Double
  mut enable_zoom : Bool
  mut zoom_speed : Double
  mut enable_rotate : Bool
  mut rotate_speed : Double
  mut key_rotate_speed : Double
  mut enable_pan : Bool
  mut pan_speed : Double
  mut screen_space_panning : Bool
  mut key_pan_speed : Double
  mut zoom_to_cursor : Bool
  mut auto_rotate : Bool
  mut auto_rotate_speed : Double
  mut target0 : @math.Vector3
  mut position0 : @math.Vector3
  mut zoom0 : Double
  mut _cursor_style : String
  mut _dom_element_key_events : @core.JsValue?
  _last_position : @math.Vector3
  _last_quaternion : @math.Quaternion
  _last_target_position : @math.Vector3
  mut _quat : @math.Quaternion
  mut _quat_inverse : @math.Quaternion
  _spherical : @math.Spherical
  _spherical_delta : @math.Spherical
  mut _scale : Double
  _pan_offset : @math.Vector3
  _rotate_start : @math.Vector2
  _rotate_end : @math.Vector2
  _rotate_delta : @math.Vector2
  _pan_start : @math.Vector2
  _pan_end : @math.Vector2
  _pan_delta : @math.Vector2
  _dolly_start : @math.Vector2
  _dolly_end : @math.Vector2
  _dolly_delta : @math.Vector2
  _dolly_direction : @math.Vector3
  _mouse : @math.Vector2
  mut _perform_cursor_zoom : Bool
  _pointers : Array[Double]
  mut _pointer_positions : Map[Double, @math.Vector2]
  mut _control_active : Bool
  /// `MapControls`' `_panWorldStart`; `None` for a plain `OrbitControls`.
  mut _pan_world_start : @math.Vector3?
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_up : (@core.JsValue) -> Unit
  mut _on_context_menu : (@core.JsValue) -> Unit
  mut _on_mouse_wheel : (@core.JsValue) -> Unit
  mut _on_key_down : (@core.JsValue) -> Unit
  mut _on_touch_start : (@core.JsValue) -> Unit
  mut _on_touch_move : (@core.JsValue) -> Unit
  mut _on_mouse_down : (@core.JsValue) -> Unit
  mut _on_mouse_move : (@core.JsValue) -> Unit
  mut _intercept_control_down : (@core.JsValue) -> Unit
  mut _intercept_control_up : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for OrbitControls with fn event_dispatcher(self) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for OrbitControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend OrbitControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for OrbitControls with fn connect(self, _, _) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for OrbitControls with fn disconnect(self, _) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for OrbitControls with fn dispose(self, _) {
  self.dispose()
}

///|
pub impl @extras.ControlsExtension for OrbitControls with fn update(
  self,
  _,
  delta,
) {
  ignore(self.update(delta_time?=delta))
}

///|
/// `new OrbitControls( object, domElement )`.
pub fn OrbitControls::new(
  object : @core.Object3D,
  dom_element? : @core.JsValue,
) -> OrbitControls {
  let base = @extras.Controls::new(object, dom_element?)
  base.state = ORBIT_STATE_NONE
  base.keys = orbit_default_keys()
  base.mouse_buttons = {
    left: Some(@core.MOUSE_ROTATE),
    middle: Some(@core.MOUSE_DOLLY),
    right: Some(@core.MOUSE_PAN),
  }
  base.touches = {
    one: Some(@core.TOUCH_ROTATE),
    two: Some(@core.TOUCH_DOLLY_PAN),
  }
  let target = @math.Vector3::new(0.0, 0.0, 0.0)
  let quat = @math.Quaternion::new(0.0, 0.0, 0.0, 1.0).set_from_unit_vectors(
    object.up,
    @math.Vector3::new(0.0, 1.0, 0.0),
  )
  let self : OrbitControls = {
    base,
    target,
    cursor: @math.Vector3::new(0.0, 0.0, 0.0),
    min_distance: 0.0,
    max_distance: @double.infinity,
    min_zoom: 0.0,
    max_zoom: @double.infinity,
    min_target_radius: 0.0,
    max_target_radius: @double.infinity,
    min_polar_angle: 0.0,
    max_polar_angle: js_pi,
    min_azimuth_angle: @double.neg_infinity,
    max_azimuth_angle: @double.infinity,
    enable_damping: false,
    damping_factor: 0.05,
    enable_zoom: true,
    zoom_speed: 1.0,
    enable_rotate: true,
    rotate_speed: 1.0,
    key_rotate_speed: 1.0,
    enable_pan: true,
    pan_speed: 1.0,
    screen_space_panning: true,
    key_pan_speed: 7.0,
    zoom_to_cursor: false,
    auto_rotate: false,
    auto_rotate_speed: 2.0,
    target0: target.clone(),
    position0: object.position.clone(),
    zoom0: camera_zoom(object),
    _cursor_style: "auto",
    _dom_element_key_events: None,
    _last_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _last_quaternion: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _last_target_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _quat: quat,
    _quat_inverse: quat.clone().invert(),
    _spherical: @math.Spherical::new(1.0, 0.0, 0.0),
    _spherical_delta: @math.Spherical::new(1.0, 0.0, 0.0),
    _scale: 1.0,
    _pan_offset: @math.Vector3::new(0.0, 0.0, 0.0),
    _rotate_start: @math.Vector2::new(0.0, 0.0),
    _rotate_end: @math.Vector2::new(0.0, 0.0),
    _rotate_delta: @math.Vector2::new(0.0, 0.0),
    _pan_start: @math.Vector2::new(0.0, 0.0),
    _pan_end: @math.Vector2::new(0.0, 0.0),
    _pan_delta: @math.Vector2::new(0.0, 0.0),
    _dolly_start: @math.Vector2::new(0.0, 0.0),
    _dolly_end: @math.Vector2::new(0.0, 0.0),
    _dolly_delta: @math.Vector2::new(0.0, 0.0),
    _dolly_direction: @math.Vector3::new(0.0, 0.0, 0.0),
    _mouse: @math.Vector2::new(0.0, 0.0),
    _perform_cursor_zoom: false,
    _pointers: [],
    _pointer_positions: Map([]),
    _control_active: false,
    _pan_world_start: None,
    _on_pointer_move: noop_listener,
    _on_pointer_down: noop_listener,
    _on_pointer_up: noop_listener,
    _on_context_menu: noop_listener,
    _on_mouse_wheel: noop_listener,
    _on_key_down: noop_listener,
    _on_touch_start: noop_listener,
    _on_touch_move: noop_listener,
    _on_mouse_down: noop_listener,
    _on_mouse_move: noop_listener,
    _intercept_control_down: noop_listener,
    _intercept_control_up: noop_listener,
  }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
  self._on_pointer_up = fn(event) { self.on_pointer_up(event) }
  self._on_context_menu = fn(event) { self.on_context_menu(event) }
  self._on_mouse_wheel = fn(event) { self.on_mouse_wheel(event) }
  self._on_key_down = fn(event) { self.on_key_down(event) }
  self._on_touch_start = fn(event) { self.on_touch_start(event) }
  self._on_touch_move = fn(event) { self.on_touch_move(event) }
  self._on_mouse_down = fn(event) { self.on_mouse_down(event) }
  self._on_mouse_move = fn(event) { self.on_mouse_move(event) }
  self._intercept_control_down = fn(event) {
    self.intercept_control_down(event)
  }
  self._intercept_control_up = fn(event) { self.intercept_control_up(event) }
  base.extension = Some(self)
  if base.dom_element is Some(element) {
    self.connect(element)
  }
  ignore(self.update())
  self
}

///|
/// `controls.cursorStyle = type`: `'grab'` or `'auto'`.
pub fn OrbitControls::set_cursor_style(
  self : OrbitControls,
  type_ : String,
) -> Unit {
  self._cursor_style = type_
  let element = dom_element_of(self.base)
  if type_ == "grab" {
    dom_set_style(element, "cursor", "grab")
  } else {
    dom_set_style(element, "cursor", "auto")
  }
}

///|
/// `controls.cursorStyle`.
pub fn OrbitControls::cursor_style(self : OrbitControls) -> String {
  self._cursor_style
}

///|
/// Connects the controls to the DOM element.
pub fn OrbitControls::connect(
  self : OrbitControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn OrbitControls::connect_listeners(self : OrbitControls) -> Unit {
  let element = dom_element_of(self.base)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "pointercancel", self._on_pointer_up)
  dom_add_event_listener(element, "contextmenu", self._on_context_menu)
  dom_add_event_listener_not_passive(element, "wheel", self._on_mouse_wheel)
  dom_add_event_listener_passive_capture(
    dom_owner_document(element),
    "keydown",
    self._intercept_control_down,
  )
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn OrbitControls::disconnect(self : OrbitControls) -> Unit {
  self.base.state = ORBIT_STATE_NONE
  let element = dom_element_of(self.base)
  let document = dom_owner_document(element)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(document, "pointermove", self._on_pointer_move)
  dom_remove_event_listener(document, "pointerup", self._on_pointer_up)
  dom_remove_event_listener(element, "pointercancel", self._on_pointer_up)
  dom_remove_event_listener(element, "wheel", self._on_mouse_wheel)
  dom_remove_event_listener(element, "contextmenu", self._on_context_menu)
  self.stop_listen_to_key_events()
  dom_remove_event_listener_capture(
    document,
    "keydown",
    self._intercept_control_down,
  )
  dom_remove_event_listener_capture(
    document,
    "keyup",
    self._intercept_control_up,
  )
  self._control_active = false
  self._pointers.clear()
  self._pointer_positions = Map([])
  dom_set_style(element, "touchAction", "")
  dom_set_style(element, "cursor", "auto")
}

///|
/// Frees the controls' resources and removes all event listeners.
pub fn OrbitControls::dispose(self : OrbitControls) -> Unit {
  self.disconnect()
}

///|
/// The current vertical rotation, in radians.
pub fn OrbitControls::get_polar_angle(self : OrbitControls) -> Double {
  self._spherical.phi
}

///|
/// The current horizontal rotation, in radians.
pub fn OrbitControls::get_azimuthal_angle(self : OrbitControls) -> Double {
  self._spherical.theta
}

///|
/// The distance from the camera to the target.
pub fn OrbitControls::get_distance(self : OrbitControls) -> Double {
  self.base.object.position.distance_to(self.target)
}

///|
/// Adds key event listeners to `dom_element` (`window` is recommended).
pub fn OrbitControls::listen_to_key_events(
  self : OrbitControls,
  dom_element : @core.JsValue,
) -> Unit {
  dom_add_event_listener(dom_element, "keydown", self._on_key_down)
  self._dom_element_key_events = Some(dom_element)
}

///|
/// Removes the key event listener added by `listen_to_key_events`.
pub fn OrbitControls::stop_listen_to_key_events(self : OrbitControls) -> Unit {
  if self._dom_element_key_events is Some(element) {
    dom_remove_event_listener(element, "keydown", self._on_key_down)
    self._dom_element_key_events = None
  }
}

///|
/// Saves the current state; `reset` restores it.
pub fn OrbitControls::save_state(self : OrbitControls) -> Unit {
  ignore(self.target0.copy(self.target))
  ignore(self.position0.copy(self.base.object.position))
  self.zoom0 = camera_zoom(self.base.object)
}

///|
/// Resets the controls to the state of the last `save_state` or construction.
pub fn OrbitControls::reset(self : OrbitControls) -> Unit {
  ignore(self.target.copy(self.target0))
  ignore(self.base.object.position.copy(self.position0))
  set_camera_zoom(self.base.object, self.zoom0)
  self.base.object.update_projection_matrix()
  self.dispatch_event(_orbit_change_event)
  ignore(self.update())
  self.base.state = ORBIT_STATE_NONE
}

///|
/// Pans the camera by `delta_x`, `delta_y` pixels.
pub fn OrbitControls::pan(
  self : OrbitControls,
  delta_x : Double,
  delta_y : Double,
) -> Unit {
  self._pan(delta_x, delta_y)
  ignore(self.update())
}

///|
/// Dollies in (zooms in for a perspective camera).
pub fn OrbitControls::dolly_in(
  self : OrbitControls,
  dolly_scale : Double,
) -> Unit {
  self._dolly_in(dolly_scale)
  ignore(self.update())
}

///|
/// Dollies out (zooms out for a perspective camera).
pub fn OrbitControls::dolly_out(
  self : OrbitControls,
  dolly_scale : Double,
) -> Unit {
  self._dolly_out(dolly_scale)
  ignore(self.update())
}

///|
/// Rotates the camera left around the vertical axis.
pub fn OrbitControls::rotate_left(self : OrbitControls, angle : Double) -> Unit {
  self._rotate_left(angle)
  ignore(self.update())
}

///|
/// Rotates the camera up around the horizontal axis.
pub fn OrbitControls::rotate_up(self : OrbitControls, angle : Double) -> Unit {
  self._rotate_up(angle)
  ignore(self.update())
}

///|
/// Updates the camera; returns whether it changed. `delta_time` is in seconds.
pub fn OrbitControls::update(
  self : OrbitControls,
  delta_time? : Double,
) -> Bool {
  let object = self.base.object
  let position = object.position
  ignore(_orbit_v.copy(position).sub(self.target))
  // rotate offset to "y-axis-is-up" space
  ignore(_orbit_v.apply_quaternion(self._quat))
  // angle from z-axis around y-axis
  ignore(self._spherical.set_from_vector3(_orbit_v))
  if self.auto_rotate && self.base.state == ORBIT_STATE_NONE {
    self._rotate_left(self._get_auto_rotation_angle(delta_time))
  }
  if self.enable_damping {
    self._spherical.theta += self._spherical_delta.theta * self.damping_factor
    self._spherical.phi += self._spherical_delta.phi * self.damping_factor
  } else {
    self._spherical.theta += self._spherical_delta.theta
    self._spherical.phi += self._spherical_delta.phi
  }
  // restrict theta to be between desired limits
  let mut min = self.min_azimuth_angle
  let mut max = self.max_azimuth_angle
  if js_is_finite(min) && js_is_finite(max) {
    if min < -js_pi {
      min += _orbit_two_pi
    } else if min > js_pi {
      min -= _orbit_two_pi
    }
    if max < -js_pi {
      max += _orbit_two_pi
    } else if max > js_pi {
      max -= _orbit_two_pi
    }
    if min <= max {
      self._spherical.theta = js_max(min, js_min(max, self._spherical.theta))
    } else {
      self._spherical.theta = if self._spherical.theta > (min + max) / 2.0 {
        js_max(min, self._spherical.theta)
      } else {
        js_min(max, self._spherical.theta)
      }
    }
  }
  // restrict phi to be between desired limits
  self._spherical.phi = js_max(
    self.min_polar_angle,
    js_min(self.max_polar_angle, self._spherical.phi),
  )
  ignore(self._spherical.make_safe())
  // move target to panned location
  if self.enable_damping {
    ignore(self.target.add_scaled_vector(self._pan_offset, self.damping_factor))
  } else {
    ignore(self.target.add(self._pan_offset))
  }
  // Limit the target distance from the cursor to create a sphere around the center of interest
  ignore(self.target.sub(self.cursor))
  ignore(
    self.target.clamp_length(self.min_target_radius, self.max_target_radius),
  )
  ignore(self.target.add(self.cursor))
  let mut zoom_changed = false
  // adjust the camera position based on zoom only if we're not zooming to the cursor or if it's an ortho camera
  // we adjust zoom later in these cases
  if (self.zoom_to_cursor && self._perform_cursor_zoom) ||
    object.is_orthographic_camera() {
    self._spherical.radius = self._clamp_distance(self._spherical.radius)
  } else {
    let prev_radius = self._spherical.radius
    self._spherical.radius = self._clamp_distance(
      self._spherical.radius * self._scale,
    )
    zoom_changed = prev_radius != self._spherical.radius
  }
  ignore(_orbit_v.set_from_spherical(self._spherical))
  // rotate offset back to "camera-up-vector-is-up" space
  ignore(_orbit_v.apply_quaternion(self._quat_inverse))
  ignore(position.copy(self.target).add(_orbit_v))
  object.look_at(self.target)
  if self.enable_damping {
    self._spherical_delta.theta *= 1.0 - self.damping_factor
    self._spherical_delta.phi *= 1.0 - self.damping_factor
    ignore(self._pan_offset.multiply_scalar(1.0 - self.damping_factor))
  } else {
    ignore(self._spherical_delta.set(0.0, 0.0, 0.0))
    ignore(self._pan_offset.set(0.0, 0.0, 0.0))
  }
  // adjust camera position
  if self.zoom_to_cursor && self._perform_cursor_zoom {
    let mut new_radius : Double? = None
    if object.is_perspective_camera() {
      // move the camera down the pointer ray
      // this method avoids floating point error
      let prev_radius = _orbit_v.length()
      let radius = self._clamp_distance(prev_radius * self._scale)
      new_radius = Some(radius)
      let radius_delta = prev_radius - radius
      ignore(
        object.position.add_scaled_vector(self._dolly_direction, radius_delta),
      )
      object.update_matrix_world()
      zoom_changed = js_number_truthy(radius_delta)
    } else if object.is_orthographic_camera() {
      // adjust the ortho camera position based on zoom changes
      let mouse_before = @math.Vector3::new(self._mouse.x, self._mouse.y, 0.0)
      ignore(mouse_before.unproject(object))
      let prev_zoom = camera_zoom(object)
      set_camera_zoom(
        object,
        js_max(
          self.min_zoom,
          js_min(self.max_zoom, camera_zoom(object) / self._scale),
        ),
      )
      object.update_projection_matrix()
      zoom_changed = prev_zoom != camera_zoom(object)
      let mouse_after = @math.Vector3::new(self._mouse.x, self._mouse.y, 0.0)
      ignore(mouse_after.unproject(object))
      ignore(object.position.sub(mouse_after).add(mouse_before))
      object.update_matrix_world()
      new_radius = Some(_orbit_v.length())
    } else {
      println(
        "WARNING: OrbitControls.js encountered an unknown camera type - zoom to cursor disabled.",
      )
      self.zoom_to_cursor = false
    }
    // handle the placement of the target
    if new_radius is Some(new_radius) {
      if self.screen_space_panning {
        // position the orbit target in front of the new camera position
        ignore(
          self.target
          .set(0.0, 0.0, -1.0)
          .transform_direction(object.matrix)
          .multiply_scalar(new_radius)
          .add(object.position),
        )
      } else {
        // get the ray and translation plane to compute target
        ignore(_orbit_ray.origin.copy(object.position))
        ignore(
          _orbit_ray.direction
          .set(0.0, 0.0, -1.0)
          .transform_direction(object.matrix),
        )
        // if the camera is 20 degrees above the horizon then don't adjust the focus target to avoid
        // extremely large values
        if js_abs(object.up.dot(_orbit_ray.direction)) < _orbit_tilt_limit {
          object.look_at(self.target)
        } else {
          ignore(
            _orbit_plane.set_from_normal_and_coplanar_point(
              object.up,
              self.target,
            ),
          )
          ignore(_orbit_ray.intersect_plane(_orbit_plane, self.target))
        }
      }
    }
  } else if object.is_orthographic_camera() {
    let prev_zoom = camera_zoom(object)
    set_camera_zoom(
      object,
      js_max(
        self.min_zoom,
        js_min(self.max_zoom, camera_zoom(object) / self._scale),
      ),
    )
    if prev_zoom != camera_zoom(object) {
      object.update_projection_matrix()
      zoom_changed = true
    }
  }
  self._scale = 1.0
  self._perform_cursor_zoom = false
  // update condition is:
  // min(camera displacement, camera rotation in radians)^2 > EPS
  // using small-angle approximation cos(x/2) = 1 - x^2 / 8
  if zoom_changed ||
    self._last_position.distance_to_squared(object.position) > _orbit_eps ||
    8.0 * (1.0 - self._last_quaternion.dot(object.quaternion)) > _orbit_eps ||
    self._last_target_position.distance_to_squared(self.target) > _orbit_eps {
    self.dispatch_event(_orbit_change_event)
    ignore(self._last_position.copy(object.position))
    ignore(self._last_quaternion.copy(object.quaternion))
    ignore(self._last_target_position.copy(self.target))
    return true
  }
  false
}

///|
fn OrbitControls::_get_auto_rotation_angle(
  self : OrbitControls,
  delta_time : Double?,
) -> Double {
  match delta_time {
    Some(delta_time) =>
      _orbit_two_pi / 60.0 * self.auto_rotate_speed * delta_time
    None => _orbit_two_pi / 60.0 / 60.0 * self.auto_rotate_speed
  }
}

///|
fn OrbitControls::_get_zoom_scale(
  self : OrbitControls,
  delta : Double,
) -> Double {
  let normalized_delta = js_abs(delta * 0.01)
  js_pow(0.95, self.zoom_speed * normalized_delta)
}

///|
fn OrbitControls::_rotate_left(self : OrbitControls, angle : Double) -> Unit {
  self._spherical_delta.theta -= angle
}

///|
fn OrbitControls::_rotate_up(self : OrbitControls, angle : Double) -> Unit {
  self._spherical_delta.phi -= angle
}

///|
fn OrbitControls::_pan_left(
  self : OrbitControls,
  distance : Double,
  object_matrix : @math.Matrix4,
) -> Unit {
  ignore(_orbit_v.set_from_matrix_column(object_matrix, 0)) // get X column of objectMatrix
  ignore(_orbit_v.multiply_scalar(-distance))
  ignore(self._pan_offset.add(_orbit_v))
}

///|
fn OrbitControls::_pan_up(
  self : OrbitControls,
  distance : Double,
  object_matrix : @math.Matrix4,
) -> Unit {
  if self.screen_space_panning {
    ignore(_orbit_v.set_from_matrix_column(object_matrix, 1))
  } else {
    ignore(_orbit_v.set_from_matrix_column(object_matrix, 0))
    ignore(_orbit_v.cross_vectors(self.base.object.up, _orbit_v))
  }
  ignore(_orbit_v.multiply_scalar(distance))
  ignore(self._pan_offset.add(_orbit_v))
}

///|
/// `deltaX` and `deltaY` are in pixels; right and down are positive.
fn OrbitControls::_pan(
  self : OrbitControls,
  delta_x : Double,
  delta_y : Double,
) -> Unit {
  let object = self.base.object
  if object.is_perspective_camera() {
    let element = dom_element_of(self.base)
    // perspective
    let position = object.position
    ignore(_orbit_v.copy(position).sub(self.target))
    let mut target_distance = _orbit_v.length()
    // half of the fov is center to top of screen
    target_distance *= js_tan(camera_fov(object) / 2.0 * js_pi / 180.0)
    // we use only clientHeight here so aspect ratio does not distort speed
    self._pan_left(
      2.0 * delta_x * target_distance / dom_num(element, "clientHeight"),
      object.matrix,
    )
    self._pan_up(
      2.0 * delta_y * target_distance / dom_num(element, "clientHeight"),
      object.matrix,
    )
  } else if object.is_orthographic_camera() {
    let element = dom_element_of(self.base)
    // orthographic
    self._pan_left(
      delta_x *
      (ortho_right(object) - ortho_left(object)) /
      camera_zoom(object) /
      dom_num(element, "clientWidth"),
      object.matrix,
    )
    self._pan_up(
      delta_y *
      (ortho_top(object) - ortho_bottom(object)) /
      camera_zoom(object) /
      dom_num(element, "clientHeight"),
      object.matrix,
    )
  } else {
    // camera neither orthographic nor perspective
    println(
      "WARNING: OrbitControls.js encountered an unknown camera type - pan disabled.",
    )
    self.enable_pan = false
  }
}

///|
fn OrbitControls::_dolly_out(
  self : OrbitControls,
  dolly_scale : Double,
) -> Unit {
  let object = self.base.object
  if object.is_perspective_camera() || object.is_orthographic_camera() {
    self._scale /= dolly_scale
  } else {
    println(
      "WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.",
    )
    self.enable_zoom = false
  }
}

///|
fn OrbitControls::_dolly_in(self : OrbitControls, dolly_scale : Double) -> Unit {
  let object = self.base.object
  if object.is_perspective_camera() || object.is_orthographic_camera() {
    self._scale *= dolly_scale
  } else {
    println(
      "WARNING: OrbitControls.js encountered an unknown camera type - dolly/zoom disabled.",
    )
    self.enable_zoom = false
  }
}

///|
fn OrbitControls::_update_zoom_parameters(
  self : OrbitControls,
  x : Double,
  y : Double,
) -> Unit {
  if !self.zoom_to_cursor {
    return
  }
  self._perform_cursor_zoom = true
  let rect = dom_get_bounding_client_rect(dom_element_of(self.base))
  let dx = x - ev_num(rect, "left")
  let dy = y - ev_num(rect, "top")
  let w = ev_num(rect, "width")
  let h = ev_num(rect, "height")
  self._mouse.x = dx / w * 2.0 - 1.0
  self._mouse.y = -(dy / h) * 2.0 + 1.0
  ignore(
    self._dolly_direction
    .set(self._mouse.x, self._mouse.y, 1.0)
    .unproject(self.base.object)
    .sub(self.base.object.position)
    .normalize(),
  )
}

///|
fn OrbitControls::_clamp_distance(
  self : OrbitControls,
  dist : Double,
) -> Double {
  js_max(self.min_distance, js_min(self.max_distance, dist))
}

// event callbacks - update the object state

///|
fn OrbitControls::_handle_mouse_down_rotate(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  ignore(
    self._rotate_start.set(ev_num(event, "clientX"), ev_num(event, "clientY")),
  )
}

///|
fn OrbitControls::_handle_mouse_down_dolly(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  self._update_zoom_parameters(
    ev_num(event, "clientX"),
    ev_num(event, "clientY"),
  )
  ignore(
    self._dolly_start.set(ev_num(event, "clientX"), ev_num(event, "clientY")),
  )
}

///|
fn OrbitControls::_handle_mouse_down_pan(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if self._pan_world_start is Some(pan_world_start) {
    map_handle_mouse_down_pan(self, pan_world_start, event)
  } else {
    self._handle_mouse_down_pan_base(event)
  }
}

///|
/// `OrbitControls.prototype._handleMouseDownPan`.
fn OrbitControls::_handle_mouse_down_pan_base(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  ignore(
    self._pan_start.set(ev_num(event, "clientX"), ev_num(event, "clientY")),
  )
}

///|
fn OrbitControls::_handle_mouse_move_rotate(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  ignore(
    self._rotate_end.set(ev_num(event, "clientX"), ev_num(event, "clientY")),
  )
  ignore(
    self._rotate_delta
    .sub_vectors(self._rotate_end, self._rotate_start)
    .multiply_scalar(self.rotate_speed),
  )
  let element = dom_element_of(self.base)
  self._rotate_left(
    _orbit_two_pi * self._rotate_delta.x / dom_num(element, "clientHeight"),
  ) // yes, height
  self._rotate_up(
    _orbit_two_pi * self._rotate_delta.y / dom_num(element, "clientHeight"),
  )
  ignore(self._rotate_start.copy(self._rotate_end))
  ignore(self.update())
}

///|
fn OrbitControls::_handle_mouse_move_dolly(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  ignore(
    self._dolly_end.set(ev_num(event, "clientX"), ev_num(event, "clientY")),
  )
  ignore(self._dolly_delta.sub_vectors(self._dolly_end, self._dolly_start))
  if self._dolly_delta.y > 0.0 {
    self._dolly_out(self._get_zoom_scale(self._dolly_delta.y))
  } else if self._dolly_delta.y < 0.0 {
    self._dolly_in(self._get_zoom_scale(self._dolly_delta.y))
  }
  ignore(self._dolly_start.copy(self._dolly_end))
  if self.zoom_to_cursor {
    // update() resets the cursor zoom, so keep zooming towards the position where the drag started
    self._perform_cursor_zoom = true
    ignore(
      self._dolly_direction
      .set(self._mouse.x, self._mouse.y, 1.0)
      .unproject(self.base.object)
      .sub(self.base.object.position)
      .normalize(),
    )
  }
  ignore(self.update())
}

///|
fn OrbitControls::_handle_mouse_move_pan(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if self._pan_world_start is Some(pan_world_start) {
    map_handle_mouse_move_pan(self, pan_world_start, event)
  } else {
    self._handle_mouse_move_pan_base(event)
  }
}

///|
/// `OrbitControls.prototype._handleMouseMovePan`.
fn OrbitControls::_handle_mouse_move_pan_base(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  ignore(self._pan_end.set(ev_num(event, "clientX"), ev_num(event, "clientY")))
  ignore(
    self._pan_delta
    .sub_vectors(self._pan_end, self._pan_start)
    .multiply_scalar(self.pan_speed),
  )
  self._pan(self._pan_delta.x, self._pan_delta.y)
  ignore(self._pan_start.copy(self._pan_end))
  ignore(self.update())
}

///|
fn OrbitControls::_handle_mouse_wheel(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  self._update_zoom_parameters(
    ev_num(event, "clientX"),
    ev_num(event, "clientY"),
  )
  let delta_y = ev_num(event, "deltaY")
  if delta_y < 0.0 {
    self._dolly_in(self._get_zoom_scale(delta_y))
  } else if delta_y > 0.0 {
    self._dolly_out(self._get_zoom_scale(delta_y))
  }
  ignore(self.update())
}

///|
fn OrbitControls::_handle_key_down(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let mut needs_update = false
  let code = event.get("code")
  let keys = self.base.keys
  let modified = ev_bool(event, "ctrlKey") ||
    ev_bool(event, "metaKey") ||
    ev_bool(event, "shiftKey")
  let height = fn() { dom_num(dom_element_of(self.base), "clientHeight") }
  if code.strict_equal(keys.get("UP")) {
    if modified {
      if self.enable_rotate {
        self._rotate_up(_orbit_two_pi * self.key_rotate_speed / height())
      }
    } else if self.enable_pan {
      self._pan(0.0, self.key_pan_speed)
    }
    needs_update = true
  } else if code.strict_equal(keys.get("BOTTOM")) {
    if modified {
      if self.enable_rotate {
        self._rotate_up(-_orbit_two_pi * self.key_rotate_speed / height())
      }
    } else if self.enable_pan {
      self._pan(0.0, -self.key_pan_speed)
    }
    needs_update = true
  } else if code.strict_equal(keys.get("LEFT")) {
    if modified {
      if self.enable_rotate {
        self._rotate_left(_orbit_two_pi * self.key_rotate_speed / height())
      }
    } else if self.enable_pan {
      self._pan(self.key_pan_speed, 0.0)
    }
    needs_update = true
  } else if code.strict_equal(keys.get("RIGHT")) {
    if modified {
      if self.enable_rotate {
        self._rotate_left(-_orbit_two_pi * self.key_rotate_speed / height())
      }
    } else if self.enable_pan {
      self._pan(-self.key_pan_speed, 0.0)
    }
    needs_update = true
  }
  if needs_update {
    // prevent the browser from scrolling on cursor keys
    prevent_default(event)
    ignore(self.update())
  }
}

///|
/// The midpoint of `event` and the second pointer when two are down.
fn OrbitControls::_touch_center(
  self : OrbitControls,
  event : @core.JsValue,
) -> (Double, Double) {
  if self._pointers.length() == 1 {
    (ev_num(event, "pageX"), ev_num(event, "pageY"))
  } else {
    let position = self._get_second_pointer_position(event)
    let x = 0.5 * (ev_num(event, "pageX") + position.x)
    let y = 0.5 * (ev_num(event, "pageY") + position.y)
    (x, y)
  }
}

///|
fn OrbitControls::_handle_touch_start_rotate(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let (x, y) = self._touch_center(event)
  ignore(self._rotate_start.set(x, y))
}

///|
fn OrbitControls::_handle_touch_start_pan(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let (x, y) = self._touch_center(event)
  ignore(self._pan_start.set(x, y))
}

///|
fn OrbitControls::_handle_touch_start_dolly(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let position = self._get_second_pointer_position(event)
  let dx = ev_num(event, "pageX") - position.x
  let dy = ev_num(event, "pageY") - position.y
  let distance = js_sqrt(dx * dx + dy * dy)
  ignore(self._dolly_start.set(0.0, distance))
}

///|
fn OrbitControls::_handle_touch_start_dolly_pan(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if self.enable_zoom {
    self._handle_touch_start_dolly(event)
  }
  if self.enable_pan {
    self._handle_touch_start_pan(event)
  }
}

///|
fn OrbitControls::_handle_touch_start_dolly_rotate(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if self.enable_zoom {
    self._handle_touch_start_dolly(event)
  }
  if self.enable_rotate {
    self._handle_touch_start_rotate(event)
  }
}

///|
fn OrbitControls::_handle_touch_move_rotate(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let (x, y) = self._touch_center(event)
  ignore(self._rotate_end.set(x, y))
  ignore(
    self._rotate_delta
    .sub_vectors(self._rotate_end, self._rotate_start)
    .multiply_scalar(self.rotate_speed),
  )
  let element = dom_element_of(self.base)
  self._rotate_left(
    _orbit_two_pi * self._rotate_delta.x / dom_num(element, "clientHeight"),
  ) // yes, height
  self._rotate_up(
    _orbit_two_pi * self._rotate_delta.y / dom_num(element, "clientHeight"),
  )
  ignore(self._rotate_start.copy(self._rotate_end))
}

///|
fn OrbitControls::_handle_touch_move_pan(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let (x, y) = self._touch_center(event)
  ignore(self._pan_end.set(x, y))
  ignore(
    self._pan_delta
    .sub_vectors(self._pan_end, self._pan_start)
    .multiply_scalar(self.pan_speed),
  )
  self._pan(self._pan_delta.x, self._pan_delta.y)
  ignore(self._pan_start.copy(self._pan_end))
}

///|
fn OrbitControls::_handle_touch_move_dolly(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let position = self._get_second_pointer_position(event)
  let dx = ev_num(event, "pageX") - position.x
  let dy = ev_num(event, "pageY") - position.y
  let distance = js_sqrt(dx * dx + dy * dy)
  ignore(self._dolly_end.set(0.0, distance))
  ignore(
    self._dolly_delta.set(
      0.0,
      js_pow(self._dolly_end.y / self._dolly_start.y, self.zoom_speed),
    ),
  )
  self._dolly_out(self._dolly_delta.y)
  ignore(self._dolly_start.copy(self._dolly_end))
  let center_x = (ev_num(event, "pageX") + position.x) * 0.5
  let center_y = (ev_num(event, "pageY") + position.y) * 0.5
  self._update_zoom_parameters(center_x, center_y)
}

///|
fn OrbitControls::_handle_touch_move_dolly_pan(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if self.enable_zoom {
    self._handle_touch_move_dolly(event)
  }
  if self.enable_pan {
    self._handle_touch_move_pan(event)
  }
}

///|
fn OrbitControls::_handle_touch_move_dolly_rotate(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if self.enable_zoom {
    self._handle_touch_move_dolly(event)
  }
  if self.enable_rotate {
    self._handle_touch_move_rotate(event)
  }
}

// pointers

///|
fn OrbitControls::_add_pointer(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  self._pointers.push(ev_num(event, "pointerId"))
}

///|
fn OrbitControls::_remove_pointer(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let pointer_id = ev_num(event, "pointerId")
  self._pointer_positions.remove(pointer_id)
  for i in 0..<self._pointers.length() {
    if self._pointers[i] == pointer_id {
      ignore(self._pointers.remove(i))
      return
    }
  }
}

///|
fn OrbitControls::_is_tracking_pointer(
  self : OrbitControls,
  event : @core.JsValue,
) -> Bool {
  let pointer_id = ev_num(event, "pointerId")
  for i in 0..<self._pointers.length() {
    if self._pointers[i] == pointer_id {
      return true
    }
  }
  false
}

///|
fn OrbitControls::_track_pointer(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let pointer_id = ev_num(event, "pointerId")
  let position = match self._pointer_positions.get(pointer_id) {
    Some(position) => position
    None => {
      let position = @math.Vector2::new(0.0, 0.0)
      self._pointer_positions[pointer_id] = position
      position
    }
  }
  ignore(position.set(ev_num(event, "pageX"), ev_num(event, "pageY")))
}

///|
fn OrbitControls::_get_second_pointer_position(
  self : OrbitControls,
  event : @core.JsValue,
) -> @math.Vector2 {
  let pointer_id = if ev_num(event, "pointerId") == self._pointers[0] {
    self._pointers[1]
  } else {
    self._pointers[0]
  }
  match self._pointer_positions.get(pointer_id) {
    Some(position) => position
    None => abort("OrbitControls: no position for pointer")
  }
}

///|
fn OrbitControls::_custom_wheel_event(
  self : OrbitControls,
  event : @core.JsValue,
) -> @core.JsValue {
  let mode = ev_num(event, "deltaMode")
  // minimal wheel event altered to meet delta-zoom demand
  let mut delta_y = ev_num(event, "deltaY")
  if mode == 1.0 {
    // LINE_MODE
    delta_y *= 16.0
  } else if mode == 2.0 {
    // PAGE_MODE
    delta_y *= 100.0
  }
  // detect if event was triggered by pinching
  if ev_bool(event, "ctrlKey") && !self._control_active {
    delta_y *= 10.0
  }
  make_wheel_event(ev_num(event, "clientX"), ev_num(event, "clientY"), delta_y)
}

///|
fn OrbitControls::on_pointer_down(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  let element = dom_element_of(self.base)
  if self._pointers.length() == 0 {
    dom_set_pointer_capture(element, ev_num(event, "pointerId"))
    dom_add_event_listener(
      dom_owner_document(element),
      "pointermove",
      self._on_pointer_move,
    )
    dom_add_event_listener(
      dom_owner_document(element),
      "pointerup",
      self._on_pointer_up,
    )
  }
  //
  if self._is_tracking_pointer(event) {
    return
  }
  //
  self._add_pointer(event)
  if ev_is(event, "pointerType", "touch") {
    (self._on_touch_start)(event)
  } else {
    (self._on_mouse_down)(event)
  }
  if self._cursor_style == "grab" {
    dom_set_style(element, "cursor", "grabbing")
  }
}

///|
fn OrbitControls::on_pointer_move(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if ev_is(event, "pointerType", "touch") {
    (self._on_touch_move)(event)
  } else {
    (self._on_mouse_move)(event)
  }
}

///|
fn OrbitControls::on_pointer_up(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  self._remove_pointer(event)
  match self._pointers.length() {
    0 => {
      let element = dom_element_of(self.base)
      dom_release_pointer_capture(element, ev_num(event, "pointerId"))
      dom_remove_event_listener(
        dom_owner_document(element),
        "pointermove",
        self._on_pointer_move,
      )
      dom_remove_event_listener(
        dom_owner_document(element),
        "pointerup",
        self._on_pointer_up,
      )
      self.dispatch_event(_orbit_end_event)
      self.base.state = ORBIT_STATE_NONE
      if self._cursor_style == "grab" {
        dom_set_style(element, "cursor", "grab")
      }
    }
    1 => {
      let pointer_id = self._pointers[0]
      let position = match self._pointer_positions.get(pointer_id) {
        Some(position) => position
        None => abort("OrbitControls: no position for pointer")
      }
      // minimal placeholder event - allows state correction on pointer-up
      (self._on_touch_start)(
        make_pointer_event(pointer_id, position.x, position.y),
      )
    }
    _ => ()
  }
}

///|
fn OrbitControls::on_mouse_down(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  let button = ev_num(event, "button")
  let mouse_action = if button == 0.0 {
    self.base.mouse_buttons.left
  } else if button == 1.0 {
    self.base.mouse_buttons.middle
  } else if button == 2.0 {
    self.base.mouse_buttons.right
  } else {
    Some(-1)
  }
  let modified = ev_bool(event, "ctrlKey") ||
    ev_bool(event, "metaKey") ||
    ev_bool(event, "shiftKey")
  match mouse_action {
    Some(action) if action == @core.MOUSE_DOLLY => {
      if !self.enable_zoom {
        return
      }
      self._handle_mouse_down_dolly(event)
      self.base.state = ORBIT_STATE_DOLLY
    }
    Some(action) if action == @core.MOUSE_ROTATE =>
      if modified {
        if !self.enable_pan {
          return
        }
        self._handle_mouse_down_pan(event)
        self.base.state = ORBIT_STATE_PAN
      } else {
        if !self.enable_rotate {
          return
        }
        self._handle_mouse_down_rotate(event)
        self.base.state = ORBIT_STATE_ROTATE
      }
    Some(action) if action == @core.MOUSE_PAN =>
      if modified {
        if !self.enable_rotate {
          return
        }
        self._handle_mouse_down_rotate(event)
        self.base.state = ORBIT_STATE_ROTATE
      } else {
        if !self.enable_pan {
          return
        }
        self._handle_mouse_down_pan(event)
        self.base.state = ORBIT_STATE_PAN
      }
    _ => self.base.state = ORBIT_STATE_NONE
  }
  if self.base.state != ORBIT_STATE_NONE {
    self.dispatch_event(_orbit_start_event)
  }
}

///|
fn OrbitControls::on_mouse_move(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  match self.base.state {
    ORBIT_STATE_ROTATE => {
      if !self.enable_rotate {
        return
      }
      self._handle_mouse_move_rotate(event)
    }
    ORBIT_STATE_DOLLY => {
      if !self.enable_zoom {
        return
      }
      self._handle_mouse_move_dolly(event)
    }
    ORBIT_STATE_PAN => {
      if !self.enable_pan {
        return
      }
      self._handle_mouse_move_pan(event)
    }
    _ => ()
  }
}

///|
fn OrbitControls::on_mouse_wheel(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled ||
    !self.enable_zoom ||
    self.base.state != ORBIT_STATE_NONE {
    return
  }
  prevent_default(event)
  self.dispatch_event(_orbit_start_event)
  self._handle_mouse_wheel(self._custom_wheel_event(event))
  self.dispatch_event(_orbit_end_event)
}

///|
fn OrbitControls::on_key_down(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  self._handle_key_down(event)
}

///|
fn OrbitControls::on_touch_start(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  self._track_pointer(event)
  match self._pointers.length() {
    1 =>
      match self.base.touches.one {
        Some(touch) if touch == @core.TOUCH_ROTATE =>
          if !self.enable_rotate {
            self.base.state = ORBIT_STATE_NONE
          } else {
            self._handle_touch_start_rotate(event)
            self.base.state = ORBIT_STATE_TOUCH_ROTATE
          }
        Some(touch) if touch == @core.TOUCH_PAN =>
          if !self.enable_pan {
            self.base.state = ORBIT_STATE_NONE
          } else {
            self._handle_touch_start_pan(event)
            self.base.state = ORBIT_STATE_TOUCH_PAN
          }
        _ => self.base.state = ORBIT_STATE_NONE
      }
    2 =>
      match self.base.touches.two {
        Some(touch) if touch == @core.TOUCH_DOLLY_PAN => {
          if !self.enable_zoom && !self.enable_pan {
            return
          }
          self._handle_touch_start_dolly_pan(event)
          self.base.state = ORBIT_STATE_TOUCH_DOLLY_PAN
        }
        Some(touch) if touch == @core.TOUCH_DOLLY_ROTATE => {
          if !self.enable_zoom && !self.enable_rotate {
            return
          }
          self._handle_touch_start_dolly_rotate(event)
          self.base.state = ORBIT_STATE_TOUCH_DOLLY_ROTATE
        }
        _ => self.base.state = ORBIT_STATE_NONE
      }
    _ => self.base.state = ORBIT_STATE_NONE
  }
  if self.base.state != ORBIT_STATE_NONE {
    self.dispatch_event(_orbit_start_event)
  }
}

///|
fn OrbitControls::on_touch_move(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  self._track_pointer(event)
  match self.base.state {
    ORBIT_STATE_TOUCH_ROTATE => {
      if !self.enable_rotate {
        return
      }
      self._handle_touch_move_rotate(event)
      ignore(self.update())
    }
    ORBIT_STATE_TOUCH_PAN => {
      if !self.enable_pan {
        return
      }
      self._handle_touch_move_pan(event)
      ignore(self.update())
    }
    ORBIT_STATE_TOUCH_DOLLY_PAN => {
      if !self.enable_zoom && !self.enable_pan {
        return
      }
      self._handle_touch_move_dolly_pan(event)
      ignore(self.update())
    }
    ORBIT_STATE_TOUCH_DOLLY_ROTATE => {
      if !self.enable_zoom && !self.enable_rotate {
        return
      }
      self._handle_touch_move_dolly_rotate(event)
      ignore(self.update())
    }
    _ => self.base.state = ORBIT_STATE_NONE
  }
}

///|
fn OrbitControls::on_context_menu(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  prevent_default(event)
}

///|
fn OrbitControls::intercept_control_down(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if ev_is(event, "key", "Control") {
    self._control_active = true
    dom_add_event_listener_passive_capture(
      dom_owner_document(dom_element_of(self.base)),
      "keyup",
      self._intercept_control_up,
    )
  }
}

///|
fn OrbitControls::intercept_control_up(
  self : OrbitControls,
  event : @core.JsValue,
) -> Unit {
  if ev_is(event, "key", "Control") {
    self._control_active = false
    dom_remove_event_listener_passive_capture(
      dom_owner_document(dom_element_of(self.base)),
      "keyup",
      self._intercept_control_up,
    )
  }
}
