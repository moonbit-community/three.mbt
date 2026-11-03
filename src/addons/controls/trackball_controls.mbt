// Upstream examples/jsm/controls/TrackballControls.js.

///|
let _trackball_change_event : @core.Event = @core.Event::new("change")

///|
let _trackball_start_event : @core.Event = @core.Event::new("start")

///|
let _trackball_end_event : @core.Event = @core.Event::new("end")

///|
let _trackball_eps : Double = 0.000001

///|
const TRACKBALL_STATE_NONE : Int32 = -1

///|
const TRACKBALL_STATE_ROTATE : Int32 = 0

///|
const TRACKBALL_STATE_ZOOM : Int32 = 1

///|
const TRACKBALL_STATE_PAN : Int32 = 2

///|
const TRACKBALL_STATE_TOUCH_ROTATE : Int32 = 3

///|
const TRACKBALL_STATE_TOUCH_ZOOM_PAN : Int32 = 4

///|
let _trackball_v2 : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _trackball_mouse_change : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _trackball_object_up : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _trackball_pan : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _trackball_axis : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _trackball_quaternion : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _trackball_eye_direction : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _trackball_object_up_direction : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _trackball_object_sideways_direction : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _trackball_move_direction : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
extern "js" fn trackball_default_keys() -> @core.JsValue = "() => [ 'KeyA', 'KeyS', 'KeyD' ]"

///|
extern "js" fn js_index(value : @core.JsValue, index : Int32) -> @core.JsValue = "(v, i) => v[i]"

///|
/// Upstream `screen`: the element's page rectangle, set by `handle_resize`.
pub(all) struct TrackballScreen {
  mut left : Double
  mut top : Double
  mut width : Double
  mut height : Double
}

///|
/// Rotates, zooms and pans a camera freely, without a fixed up direction.
pub(all) struct TrackballControls {
  base : @extras.Controls
  screen : TrackballScreen
  mut rotate_speed : Double
  mut zoom_speed : Double
  mut pan_speed : Double
  mut roll_speed : Double
  mut no_rotate : Bool
  mut no_zoom : Bool
  mut no_pan : Bool
  mut multi_touch_roll : Bool
  mut static_moving : Bool
  mut dynamic_damping_factor : Double
  mut min_distance : Double
  mut max_distance : Double
  mut min_zoom : Double
  mut max_zoom : Double
  mut target : @math.Vector3
  mut key_state : Int32
  _last_position : @math.Vector3
  _last_up : @math.Vector3
  mut _last_zoom : Double
  mut _touch_zoom_distance_start : Double
  mut _touch_zoom_distance_end : Double
  mut _touch_roll_angle : Double
  mut _touch_roll_pointer_ids : String
  mut _last_angle : Double
  mut _last_roll_angle : Double
  _eye : @math.Vector3
  _move_prev : @math.Vector2
  _move_curr : @math.Vector2
  _last_axis : @math.Vector3
  _zoom_start : @math.Vector2
  _zoom_end : @math.Vector2
  _pan_start : @math.Vector2
  _pan_end : @math.Vector2
  /// The `pointerdown` events of the pointers that are down.
  _pointers : Array[@core.JsValue]
  mut _pointer_positions : Map[Double, @math.Vector2]
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_up : (@core.JsValue) -> Unit
  mut _on_pointer_cancel : (@core.JsValue) -> Unit
  mut _on_context_menu : (@core.JsValue) -> Unit
  mut _on_mouse_wheel : (@core.JsValue) -> Unit
  mut _on_key_down : (@core.JsValue) -> Unit
  mut _on_key_up : (@core.JsValue) -> Unit
  mut _on_touch_start : (@core.JsValue) -> Unit
  mut _on_touch_move : (@core.JsValue) -> Unit
  mut _on_touch_end : (@core.JsValue) -> Unit
  mut _on_mouse_down : (@core.JsValue) -> Unit
  mut _on_mouse_move : (@core.JsValue) -> Unit
  mut _on_mouse_up : (@core.JsValue) -> Unit
  mut _target0 : @math.Vector3
  mut _position0 : @math.Vector3
  mut _up0 : @math.Vector3
  mut _zoom0 : Double
}

///|
pub impl @core.EventSource for TrackballControls with fn event_dispatcher(self) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for TrackballControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend TrackballControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for TrackballControls with fn connect(
  self,
  _,
  _,
) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for TrackballControls with fn disconnect(
  self,
  _,
) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for TrackballControls with fn dispose(
  self,
  _,
) {
  self.dispose()
}

///|
pub impl @extras.ControlsExtension for TrackballControls with fn update(
  self,
  _,
  _,
) {
  self.update()
}

///|
/// `new TrackballControls( object, domElement )`.
pub fn TrackballControls::new(
  object : @core.Object3D,
  dom_element? : @core.JsValue,
) -> TrackballControls {
  let base = @extras.Controls::new(object, dom_element?)
  base.keys = trackball_default_keys()
  base.mouse_buttons = {
    left: Some(@core.MOUSE_ROTATE),
    middle: Some(@core.MOUSE_DOLLY),
    right: Some(@core.MOUSE_PAN),
  }
  base.state = TRACKBALL_STATE_NONE
  let target = @math.Vector3::new(0.0, 0.0, 0.0)
  let self : TrackballControls = {
    base,
    screen: { left: 0.0, top: 0.0, width: 0.0, height: 0.0, },
    rotate_speed: 1.0,
    zoom_speed: 1.2,
    pan_speed: 0.3,
    roll_speed: 1.0,
    no_rotate: false,
    no_zoom: false,
    no_pan: false,
    multi_touch_roll: false,
    static_moving: false,
    dynamic_damping_factor: 0.2,
    min_distance: 0.0,
    max_distance: @double.infinity,
    min_zoom: 0.0,
    max_zoom: @double.infinity,
    target,
    key_state: TRACKBALL_STATE_NONE,
    _last_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _last_up: @math.Vector3::new(0.0, 0.0, 0.0),
    _last_zoom: 1.0,
    _touch_zoom_distance_start: 0.0,
    _touch_zoom_distance_end: 0.0,
    _touch_roll_angle: 0.0,
    _touch_roll_pointer_ids: "",
    _last_angle: 0.0,
    _last_roll_angle: 0.0,
    _eye: @math.Vector3::new(0.0, 0.0, 0.0),
    _move_prev: @math.Vector2::new(0.0, 0.0),
    _move_curr: @math.Vector2::new(0.0, 0.0),
    _last_axis: @math.Vector3::new(0.0, 0.0, 0.0),
    _zoom_start: @math.Vector2::new(0.0, 0.0),
    _zoom_end: @math.Vector2::new(0.0, 0.0),
    _pan_start: @math.Vector2::new(0.0, 0.0),
    _pan_end: @math.Vector2::new(0.0, 0.0),
    _pointers: [],
    _pointer_positions: Map([]),
    _on_pointer_move: noop_listener,
    _on_pointer_down: noop_listener,
    _on_pointer_up: noop_listener,
    _on_pointer_cancel: noop_listener,
    _on_context_menu: noop_listener,
    _on_mouse_wheel: noop_listener,
    _on_key_down: noop_listener,
    _on_key_up: noop_listener,
    _on_touch_start: noop_listener,
    _on_touch_move: noop_listener,
    _on_touch_end: noop_listener,
    _on_mouse_down: noop_listener,
    _on_mouse_move: noop_listener,
    _on_mouse_up: noop_listener,
    _target0: target.clone(),
    _position0: object.position.clone(),
    _up0: object.up.clone(),
    _zoom0: camera_zoom(object),
  }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
  self._on_pointer_up = fn(event) { self.on_pointer_up(event) }
  self._on_pointer_cancel = fn(event) { self.on_pointer_cancel(event) }
  self._on_context_menu = fn(event) { self.on_context_menu(event) }
  self._on_mouse_wheel = fn(event) { self.on_mouse_wheel(event) }
  self._on_key_down = fn(event) { self.on_key_down(event) }
  self._on_key_up = fn(_) { self.on_key_up() }
  self._on_touch_start = fn(event) { self.on_touch_start(event) }
  self._on_touch_move = fn(event) { self.on_touch_move(event) }
  self._on_touch_end = fn(event) { self.on_touch_end(event) }
  self._on_mouse_down = fn(event) { self.on_mouse_down(event) }
  self._on_mouse_move = fn(event) { self.on_mouse_move(event) }
  self._on_mouse_up = fn(_) { self.on_mouse_up() }
  base.extension = Some(self)
  if dom_element is Some(element) {
    self.connect(element)
    self.handle_resize()
  }
  // force an update at start
  self.update()
  self
}

///|
/// Connects the controls to the DOM element.
pub fn TrackballControls::connect(
  self : TrackballControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn TrackballControls::connect_listeners(self : TrackballControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  dom_add_event_listener(window, "keydown", self._on_key_down)
  dom_add_event_listener(window, "keyup", self._on_key_up)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "pointercancel", self._on_pointer_cancel)
  dom_add_event_listener_not_passive(element, "wheel", self._on_mouse_wheel)
  dom_add_event_listener(element, "contextmenu", self._on_context_menu)
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn TrackballControls::disconnect(self : TrackballControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  let document = dom_owner_document(element)
  dom_remove_event_listener(window, "keydown", self._on_key_down)
  dom_remove_event_listener(window, "keyup", self._on_key_up)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(document, "pointermove", self._on_pointer_move)
  dom_remove_event_listener(document, "pointerup", self._on_pointer_up)
  dom_remove_event_listener(element, "pointercancel", self._on_pointer_cancel)
  dom_remove_event_listener(element, "wheel", self._on_mouse_wheel)
  dom_remove_event_listener(element, "contextmenu", self._on_context_menu)
  dom_set_style(element, "touchAction", "")
}

///|
/// Frees the controls' resources and removes all event listeners.
pub fn TrackballControls::dispose(self : TrackballControls) -> Unit {
  self.disconnect()
}

///|
/// Updates `screen` from the element's position; call it when the element resizes.
pub fn TrackballControls::handle_resize(self : TrackballControls) -> Unit {
  let element = dom_element_of(self.base)
  let box_ = dom_get_bounding_client_rect(element)
  // adjustments come from similar code in the jquery offset() function
  let d = dom_owner_document(element).get("documentElement")
  let window = dom_window()
  self.screen.left = ev_num(box_, "left") +
    dom_num(window, "pageXOffset") -
    ev_num(d, "clientLeft")
  self.screen.top = ev_num(box_, "top") +
    dom_num(window, "pageYOffset") -
    ev_num(d, "clientTop")
  self.screen.width = ev_num(box_, "width")
  self.screen.height = ev_num(box_, "height")
}

///|
/// Updates the camera from the accumulated input.
pub fn TrackballControls::update(self : TrackballControls) -> Unit {
  let object = self.base.object
  ignore(self._eye.sub_vectors(object.position, self.target))
  if !self.no_rotate {
    self._rotate_camera()
    if self.multi_touch_roll {
      self._roll_camera()
    }
  }
  if !self.no_zoom {
    self._zoom_camera()
  }
  if !self.no_pan {
    self._pan_camera()
  }
  ignore(object.position.add_vectors(self.target, self._eye))
  if object.is_perspective_camera() {
    self._check_distances()
    object.look_at(self.target)
    let position_changed = self._last_position.distance_to_squared(
        object.position,
      ) >
      _trackball_eps
    let roll_changed = self._last_up.distance_to_squared(object.up) >
      _trackball_eps
    if position_changed || roll_changed {
      self.dispatch_event(_trackball_change_event)
      ignore(self._last_position.copy(object.position))
      ignore(self._last_up.copy(object.up))
    }
  } else if object.is_orthographic_camera() {
    object.look_at(self.target)
    let position_changed = self._last_position.distance_to_squared(
        object.position,
      ) >
      _trackball_eps
    let roll_changed = self._last_up.distance_to_squared(object.up) >
      _trackball_eps
    let zoom_changed = self._last_zoom != camera_zoom(object)
    if position_changed || roll_changed || zoom_changed {
      self.dispatch_event(_trackball_change_event)
      ignore(self._last_position.copy(object.position))
      ignore(self._last_up.copy(object.up))
      self._last_zoom = camera_zoom(object)
    }
  } else {
    println("THREE.TrackballControls: Unsupported camera type.")
  }
}

///|
/// Resets the camera to its state at construction.
pub fn TrackballControls::reset(self : TrackballControls) -> Unit {
  let object = self.base.object
  self.base.state = TRACKBALL_STATE_NONE
  self.key_state = TRACKBALL_STATE_NONE
  ignore(self.target.copy(self._target0))
  ignore(object.position.copy(self._position0))
  ignore(object.up.copy(self._up0))
  set_camera_zoom(object, self._zoom0)
  object.update_projection_matrix()
  ignore(self._eye.sub_vectors(object.position, self.target))
  object.look_at(self.target)
  self.dispatch_event(_trackball_change_event)
  ignore(self._last_position.copy(object.position))
  ignore(self._last_up.copy(object.up))
  self._last_zoom = camera_zoom(object)
}

///|
fn TrackballControls::_pan_camera(self : TrackballControls) -> Unit {
  let object = self.base.object
  ignore(_trackball_mouse_change.copy(self._pan_end).sub(self._pan_start))
  if js_number_truthy(_trackball_mouse_change.length_sq()) {
    if object.is_orthographic_camera() {
      let element = dom_element_of(self.base)
      let scale_x = (ortho_right(object) - ortho_left(object)) /
        camera_zoom(object) /
        dom_num(element, "clientWidth")
      let scale_y = (ortho_top(object) - ortho_bottom(object)) /
        camera_zoom(object) /
        dom_num(element, "clientWidth")
      _trackball_mouse_change.x *= scale_x
      _trackball_mouse_change.y *= scale_y
    }
    ignore(
      _trackball_mouse_change.multiply_scalar(
        self._eye.length() * self.pan_speed,
      ),
    )
    ignore(
      _trackball_pan
      .copy(self._eye)
      .cross(object.up)
      .set_length(_trackball_mouse_change.x),
    )
    ignore(
      _trackball_pan.add(
        _trackball_object_up
        .copy(object.up)
        .set_length(_trackball_mouse_change.y),
      ),
    )
    ignore(object.position.add(_trackball_pan))
    ignore(self.target.add(_trackball_pan))
    if self.static_moving {
      ignore(self._pan_start.copy(self._pan_end))
    } else {
      ignore(
        self._pan_start.add(
          _trackball_mouse_change
          .sub_vectors(self._pan_end, self._pan_start)
          .multiply_scalar(self.dynamic_damping_factor),
        ),
      )
    }
  }
}

///|
fn TrackballControls::_rotate_camera(self : TrackballControls) -> Unit {
  let object = self.base.object
  ignore(
    _trackball_move_direction.set(
      self._move_curr.x - self._move_prev.x,
      self._move_curr.y - self._move_prev.y,
      0.0,
    ),
  )
  let mut angle = _trackball_move_direction.length()
  if js_number_truthy(angle) {
    ignore(self._eye.copy(object.position).sub(self.target))
    ignore(_trackball_eye_direction.copy(self._eye).normalize())
    ignore(_trackball_object_up_direction.copy(object.up).normalize())
    ignore(
      _trackball_object_sideways_direction
      .cross_vectors(_trackball_object_up_direction, _trackball_eye_direction)
      .normalize(),
    )
    ignore(
      _trackball_object_up_direction.set_length(
        self._move_curr.y - self._move_prev.y,
      ),
    )
    ignore(
      _trackball_object_sideways_direction.set_length(
        self._move_curr.x - self._move_prev.x,
      ),
    )
    ignore(
      _trackball_move_direction.copy(
        _trackball_object_up_direction.add(_trackball_object_sideways_direction),
      ),
    )
    ignore(
      _trackball_axis
      .cross_vectors(_trackball_move_direction, self._eye)
      .normalize(),
    )
    angle *= self.rotate_speed
    ignore(_trackball_quaternion.set_from_axis_angle(_trackball_axis, angle))
    ignore(self._eye.apply_quaternion(_trackball_quaternion))
    ignore(object.up.apply_quaternion(_trackball_quaternion))
    ignore(self._last_axis.copy(_trackball_axis))
    self._last_angle = angle
  } else if !self.static_moving && js_number_truthy(self._last_angle) {
    self._last_angle *= js_sqrt(1.0 - self.dynamic_damping_factor)
    ignore(self._eye.copy(object.position).sub(self.target))
    ignore(
      _trackball_quaternion.set_from_axis_angle(
        self._last_axis,
        self._last_angle,
      ),
    )
    ignore(self._eye.apply_quaternion(_trackball_quaternion))
    ignore(object.up.apply_quaternion(_trackball_quaternion))
  }
  ignore(self._move_prev.copy(self._move_curr))
}

///|
fn TrackballControls::_roll_camera(self : TrackballControls) -> Unit {
  let angle = self._get_touch_roll_angle()
  if js_number_truthy(angle) {
    self._last_roll_angle = angle * self.roll_speed
  } else if !self.static_moving && js_number_truthy(self._last_roll_angle) {
    self._last_roll_angle *= js_sqrt(1.0 - self.dynamic_damping_factor)
  } else {
    return
  }
  ignore(_trackball_eye_direction.copy(self._eye).normalize())
  ignore(
    _trackball_quaternion.set_from_axis_angle(
      _trackball_eye_direction,
      self._last_roll_angle,
    ),
  )
  ignore(self.base.object.up.apply_quaternion(_trackball_quaternion))
}

///|
extern "js" fn trackball_pointer_ids(
  first : @core.JsValue,
  second : @core.JsValue,
) -> String = "(a, b) => `${ a.pointerId },${ b.pointerId }`"

///|
fn TrackballControls::_get_touch_roll_angle(self : TrackballControls) -> Double {
  if self._pointers.length() < 2 ||
    !ev_is(self._pointers[0], "pointerType", "touch") ||
    !ev_is(self._pointers[1], "pointerType", "touch") {
    self._touch_roll_pointer_ids = ""
    return 0.0
  }
  let first = self._pointers[0]
  let second = self._pointers[1]
  let pointer_ids = trackball_pointer_ids(first, second)
  let position_first = self._position_of(ev_num(first, "pointerId"))
  let position_second = self._position_of(ev_num(second, "pointerId"))
  let roll_angle = js_atan2(
    position_second.y - position_first.y,
    position_second.x - position_first.x,
  )
  // fingers changed or new gesture started
  if pointer_ids != self._touch_roll_pointer_ids {
    self._touch_roll_pointer_ids = pointer_ids
    self._touch_roll_angle = roll_angle
    return 0.0
  }
  let mut angle = roll_angle - self._touch_roll_angle
  self._touch_roll_angle = roll_angle
  if angle > js_pi {
    angle -= 2.0 * js_pi
  } else if angle < -js_pi {
    angle += 2.0 * js_pi
  }
  angle
}

///|
fn TrackballControls::_zoom_camera(self : TrackballControls) -> Unit {
  let object = self.base.object
  if self.base.state == TRACKBALL_STATE_TOUCH_ZOOM_PAN {
    let factor = self._touch_zoom_distance_start / self._touch_zoom_distance_end
    self._touch_zoom_distance_start = self._touch_zoom_distance_end
    if object.is_perspective_camera() {
      ignore(self._eye.multiply_scalar(factor))
    } else if object.is_orthographic_camera() {
      set_camera_zoom(
        object,
        @math.clamp(camera_zoom(object) / factor, self.min_zoom, self.max_zoom),
      )
      if self._last_zoom != camera_zoom(object) {
        object.update_projection_matrix()
      }
    } else {
      println("THREE.TrackballControls: Unsupported camera type")
    }
  } else {
    let factor = 1.0 + (self._zoom_end.y - self._zoom_start.y) * self.zoom_speed
    if factor != 1.0 && factor > 0.0 {
      if object.is_perspective_camera() {
        ignore(self._eye.multiply_scalar(factor))
      } else if object.is_orthographic_camera() {
        set_camera_zoom(
          object,
          @math.clamp(
            camera_zoom(object) / factor,
            self.min_zoom,
            self.max_zoom,
          ),
        )
        if self._last_zoom != camera_zoom(object) {
          object.update_projection_matrix()
        }
      } else {
        println("THREE.TrackballControls: Unsupported camera type")
      }
    }
    if self.static_moving {
      ignore(self._zoom_start.copy(self._zoom_end))
    } else {
      self._zoom_start.y += (self._zoom_end.y - self._zoom_start.y) *
        self.dynamic_damping_factor
    }
  }
}

///|
fn TrackballControls::_get_mouse_on_screen(
  self : TrackballControls,
  page_x : Double,
  page_y : Double,
) -> @math.Vector2 {
  _trackball_v2.set(
    (page_x - self.screen.left) / self.screen.width,
    (page_y - self.screen.top) / self.screen.height,
  )
}

///|
fn TrackballControls::_get_mouse_on_circle(
  self : TrackballControls,
  page_x : Double,
  page_y : Double,
) -> @math.Vector2 {
  _trackball_v2.set(
    (page_x - self.screen.width * 0.5 - self.screen.left) /
    (self.screen.width * 0.5),
    (self.screen.height + 2.0 * (self.screen.top - page_y)) / self.screen.width, // screen.width intentional
  )
}

///|
fn TrackballControls::_add_pointer(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  self._pointers.push(event)
}

///|
fn TrackballControls::_remove_pointer(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  let pointer_id = ev_num(event, "pointerId")
  self._pointer_positions.remove(pointer_id)
  for i in 0..<self._pointers.length() {
    if ev_num(self._pointers[i], "pointerId") == pointer_id {
      ignore(self._pointers.remove(i))
      return
    }
  }
}

///|
fn TrackballControls::_track_pointer(
  self : TrackballControls,
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
fn TrackballControls::_position_of(
  self : TrackballControls,
  pointer_id : Double,
) -> @math.Vector2 {
  match self._pointer_positions.get(pointer_id) {
    Some(position) => position
    None => abort("TrackballControls: no position for pointer")
  }
}

///|
fn TrackballControls::_get_second_pointer_position(
  self : TrackballControls,
  event : @core.JsValue,
) -> @math.Vector2 {
  let pointer = if ev_num(event, "pointerId") ==
    ev_num(self._pointers[0], "pointerId") {
    self._pointers[1]
  } else {
    self._pointers[0]
  }
  self._position_of(ev_num(pointer, "pointerId"))
}

///|
fn TrackballControls::_check_distances(self : TrackballControls) -> Unit {
  let object = self.base.object
  if !self.no_zoom || !self.no_pan {
    if self._eye.length_sq() > self.max_distance * self.max_distance {
      ignore(
        object.position.add_vectors(
          self.target,
          self._eye.set_length(self.max_distance),
        ),
      )
      ignore(self._zoom_start.copy(self._zoom_end))
    }
    if self._eye.length_sq() < self.min_distance * self.min_distance {
      ignore(
        object.position.add_vectors(
          self.target,
          self._eye.set_length(self.min_distance),
        ),
      )
      ignore(self._zoom_start.copy(self._zoom_end))
    }
  }
}

///|
fn TrackballControls::on_pointer_down(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if self._pointers.length() == 0 {
    let element = dom_element_of(self.base)
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
  self._add_pointer(event)
  if ev_is(event, "pointerType", "touch") {
    (self._on_touch_start)(event)
  } else {
    (self._on_mouse_down)(event)
  }
}

///|
fn TrackballControls::on_pointer_move(
  self : TrackballControls,
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
fn TrackballControls::on_pointer_up(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if ev_is(event, "pointerType", "touch") {
    (self._on_touch_end)(event)
  } else {
    (self._on_mouse_up)(event)
  }
  //
  self._remove_pointer(event)
  if self._pointers.length() == 0 {
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
  }
}

///|
fn TrackballControls::on_pointer_cancel(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  self._remove_pointer(event)
}

///|
fn TrackballControls::on_key_up(self : TrackballControls) -> Unit {
  if !self.base.enabled {
    return
  }
  self.key_state = TRACKBALL_STATE_NONE
  dom_add_event_listener(dom_window(), "keydown", self._on_key_down)
}

///|
fn TrackballControls::on_key_down(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  dom_remove_event_listener(dom_window(), "keydown", self._on_key_down)
  let code = event.get("code")
  let keys = self.base.keys
  if self.key_state != TRACKBALL_STATE_NONE {
    return
  } else if code.strict_equal(js_index(keys, TRACKBALL_STATE_ROTATE)) &&
    !self.no_rotate {
    self.key_state = TRACKBALL_STATE_ROTATE
  } else if code.strict_equal(js_index(keys, TRACKBALL_STATE_ZOOM)) &&
    !self.no_zoom {
    self.key_state = TRACKBALL_STATE_ZOOM
  } else if code.strict_equal(js_index(keys, TRACKBALL_STATE_PAN)) &&
    !self.no_pan {
    self.key_state = TRACKBALL_STATE_PAN
  }
}

///|
fn TrackballControls::on_mouse_down(
  self : TrackballControls,
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
  self.base.state = match mouse_action {
    Some(action) if action == @core.MOUSE_DOLLY => TRACKBALL_STATE_ZOOM
    Some(action) if action == @core.MOUSE_ROTATE => TRACKBALL_STATE_ROTATE
    Some(action) if action == @core.MOUSE_PAN => TRACKBALL_STATE_PAN
    _ => TRACKBALL_STATE_NONE
  }
  let state = if self.key_state != TRACKBALL_STATE_NONE {
    self.key_state
  } else {
    self.base.state
  }
  let page_x = ev_num(event, "pageX")
  let page_y = ev_num(event, "pageY")
  if state == TRACKBALL_STATE_ROTATE && !self.no_rotate {
    ignore(self._move_curr.copy(self._get_mouse_on_circle(page_x, page_y)))
    ignore(self._move_prev.copy(self._move_curr))
  } else if state == TRACKBALL_STATE_ZOOM && !self.no_zoom {
    ignore(self._zoom_start.copy(self._get_mouse_on_screen(page_x, page_y)))
    ignore(self._zoom_end.copy(self._zoom_start))
  } else if state == TRACKBALL_STATE_PAN && !self.no_pan {
    ignore(self._pan_start.copy(self._get_mouse_on_screen(page_x, page_y)))
    ignore(self._pan_end.copy(self._pan_start))
  }
  self.dispatch_event(_trackball_start_event)
}

///|
fn TrackballControls::on_mouse_move(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  let state = if self.key_state != TRACKBALL_STATE_NONE {
    self.key_state
  } else {
    self.base.state
  }
  let page_x = ev_num(event, "pageX")
  let page_y = ev_num(event, "pageY")
  if state == TRACKBALL_STATE_ROTATE && !self.no_rotate {
    ignore(self._move_curr.copy(self._get_mouse_on_circle(page_x, page_y)))
  } else if state == TRACKBALL_STATE_ZOOM && !self.no_zoom {
    ignore(self._zoom_end.copy(self._get_mouse_on_screen(page_x, page_y)))
  } else if state == TRACKBALL_STATE_PAN && !self.no_pan {
    ignore(self._pan_end.copy(self._get_mouse_on_screen(page_x, page_y)))
  }
}

///|
fn TrackballControls::on_mouse_up(self : TrackballControls) -> Unit {
  self.base.state = TRACKBALL_STATE_NONE
  self.dispatch_event(_trackball_end_event)
}

///|
fn TrackballControls::on_mouse_wheel(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  if self.no_zoom {
    return
  }
  prevent_default(event)
  let delta_mode = ev_num(event, "deltaMode")
  if delta_mode == 2.0 {
    // Zoom in pages
    self._zoom_start.y -= ev_num(event, "deltaY") * 0.025
  } else if delta_mode == 1.0 {
    // Zoom in lines
    self._zoom_start.y -= ev_num(event, "deltaY") * 0.01
  } else {
    // undefined, 0, assume pixels
    self._zoom_start.y -= ev_num(event, "deltaY") * 0.00025
  }
  self.dispatch_event(_trackball_start_event)
  self.dispatch_event(_trackball_end_event)
}

///|
fn TrackballControls::on_context_menu(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  prevent_default(event)
}

///|
fn TrackballControls::on_touch_start(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  self._track_pointer(event)
  match self._pointers.length() {
    1 => {
      self.base.state = TRACKBALL_STATE_TOUCH_ROTATE
      ignore(
        self._move_curr.copy(
          self._get_mouse_on_circle(
            ev_num(self._pointers[0], "pageX"),
            ev_num(self._pointers[0], "pageY"),
          ),
        ),
      )
      ignore(self._move_prev.copy(self._move_curr))
    }
    _ => {
      // 2 or more
      self.base.state = TRACKBALL_STATE_TOUCH_ZOOM_PAN
      let p0 = self._pointers[0]
      let p1 = self._pointers[1]
      let dx = ev_num(p0, "pageX") - ev_num(p1, "pageX")
      let dy = ev_num(p0, "pageY") - ev_num(p1, "pageY")
      self._touch_zoom_distance_start = js_sqrt(dx * dx + dy * dy)
      self._touch_zoom_distance_end = self._touch_zoom_distance_start
      let x = (ev_num(p0, "pageX") + ev_num(p1, "pageX")) / 2.0
      let y = (ev_num(p0, "pageY") + ev_num(p1, "pageY")) / 2.0
      ignore(self._pan_start.copy(self._get_mouse_on_screen(x, y)))
      ignore(self._pan_end.copy(self._pan_start))
    }
  }
  self.dispatch_event(_trackball_start_event)
}

///|
fn TrackballControls::on_touch_move(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  self._track_pointer(event)
  match self._pointers.length() {
    1 =>
      ignore(
        self._move_curr.copy(
          self._get_mouse_on_circle(
            ev_num(event, "pageX"),
            ev_num(event, "pageY"),
          ),
        ),
      )
    _ => {
      // 2 or more
      let position = self._get_second_pointer_position(event)
      let dx = ev_num(event, "pageX") - position.x
      let dy = ev_num(event, "pageY") - position.y
      self._touch_zoom_distance_end = js_sqrt(dx * dx + dy * dy)
      let x = (ev_num(event, "pageX") + position.x) / 2.0
      let y = (ev_num(event, "pageY") + position.y) / 2.0
      ignore(self._pan_end.copy(self._get_mouse_on_screen(x, y)))
    }
  }
}

///|
fn TrackballControls::on_touch_end(
  self : TrackballControls,
  event : @core.JsValue,
) -> Unit {
  match self._pointers.length() {
    0 => self.base.state = TRACKBALL_STATE_NONE
    1 => {
      self.base.state = TRACKBALL_STATE_TOUCH_ROTATE
      ignore(
        self._move_curr.copy(
          self._get_mouse_on_circle(
            ev_num(event, "pageX"),
            ev_num(event, "pageY"),
          ),
        ),
      )
      ignore(self._move_prev.copy(self._move_curr))
    }
    2 => {
      self.base.state = TRACKBALL_STATE_TOUCH_ZOOM_PAN
      let pointer_id = ev_num(event, "pointerId")
      for pointer in self._pointers {
        if ev_num(pointer, "pointerId") != pointer_id {
          let position = self._position_of(ev_num(pointer, "pointerId"))
          ignore(
            self._move_curr.copy(
              self._get_mouse_on_circle(position.x, position.y),
            ),
          )
          ignore(self._move_prev.copy(self._move_curr))
          break
        }
      }
    }
    _ => ()
  }
  self.dispatch_event(_trackball_end_event)
}
