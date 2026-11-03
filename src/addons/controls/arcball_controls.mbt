// Upstream examples/jsm/controls/ArcballControls.js.

///|
/// The trackball state (upstream's `STATE` symbols).
#derive(Eq)
pub(all) enum ArcballState {
  Idle
  Rotate
  Pan
  Scale
  Fov
  Focus
  ZRotate
  TouchMulti
  AnimationFocus
  AnimationRotate
}

///|
/// The input state (upstream's `INPUT` symbols).
#derive(Eq)
pub(all) enum ArcballInput {
  None
  OneFinger
  OneFingerSwitched
  TwoFinger
  MultFinger
  Cursor
}

///|
/// A mouse input of a mouse action: a button (`0`, `1`, `2`) or the wheel.
#derive(Eq)
pub(all) enum ArcballMouse {
  Button(Int32)
  Wheel
}

///|
/// One entry of `mouse_actions`.
pub(all) struct ArcballMouseAction {
  operation : String
  mouse : ArcballMouse
  key : String?
  state : ArcballState
}

///|
/// The camera and gizmo transformations an operation returns.
pub(all) struct ArcballTransformation {
  mut camera : @math.Matrix4?
  mut gizmos : @math.Matrix4?
}

///|
priv struct ArcballCenter {
  mut x : Double
  mut y : Double
}

///|
//cursor center coordinates
let _arcball_center : ArcballCenter = { x: 0.0, y: 0.0, }

///|
//transformation matrices for gizmos and camera
let _arcball_transformation : ArcballTransformation = {
  camera: Some(@math.Matrix4::new()),
  gizmos: Some(@math.Matrix4::new()),
}

///|
let _arcball_change_event : @core.Event = @core.Event::new("change")

///|
let _arcball_start_event : @core.Event = @core.Event::new("start")

///|
let _arcball_end_event : @core.Event = @core.Event::new("end")

///|
let _arcball_raycaster : @core.Raycaster = @core.Raycaster::new()

///|
let _arcball_offset : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _arcball_gizmo_matrix_state_temp : @math.Matrix4 = @math.Matrix4::new()

///|
let _arcball_camera_matrix_state_temp : @math.Matrix4 = @math.Matrix4::new()

///|
let _arcball_scale_point_temp : @math.Vector3 = @math.Vector3::new(
  0.0, 0.0, 0.0,
)

///|
let _arcball_eps : Double = 0.000001

///|
/// A trackball around `target` with pan, zoom, FOV, focus and touch gestures.
pub(all) struct ArcballControls {
  base : @extras.Controls
  mut scene : @core.Object3D?
  mut target : @math.Vector3
  _current_target : @math.Vector3
  mut radius_factor : Double
  mouse_actions : Array[ArcballMouseAction]
  mut _mouse_op : String?
  _v2_1 : @math.Vector2
  _v3_1 : @math.Vector3
  _v3_2 : @math.Vector3
  _m4_1 : @math.Matrix4
  _m4_2 : @math.Matrix4
  _quat : @math.Quaternion
  _translation_matrix : @math.Matrix4
  _rotation_matrix : @math.Matrix4
  _scale_matrix : @math.Matrix4
  _rotation_axis : @math.Vector3
  _camera_matrix_state : @math.Matrix4
  _camera_projection_state : @math.Matrix4
  mut _fov_state : Double
  _up_state : @math.Vector3
  mut _zoom_state : Double
  mut _near_pos : Double
  mut _far_pos : Double
  _gizmo_matrix_state : @math.Matrix4
  _up0 : @math.Vector3
  mut _zoom0 : Double
  mut _fov0 : Double
  mut _initial_near : Double
  mut _near_pos0 : Double
  mut _initial_far : Double
  mut _far_pos0 : Double
  _camera_matrix_state0 : @math.Matrix4
  _gizmo_matrix_state0 : @math.Matrix4
  _target0 : @math.Vector3
  mut _button : Double
  _touch_start : Array[@core.JsValue]
  _touch_current : Array[@core.JsValue]
  mut _input : ArcballInput
  mut _switch_sensibility : Double
  mut _start_finger_distance : Double
  mut _current_finger_distance : Double
  mut _start_finger_rotation : Double
  mut _current_finger_rotation : Double
  mut _dev_px_ratio : Double
  mut _down_valid : Bool
  mut _nclicks : Int32
  _down_events : Array[@core.JsValue]
  mut _down_start : Double
  mut _click_start : Double
  mut _max_down_time : Double
  mut _max_interval : Double
  mut _pos_threshold : Double
  mut _movement_threshold : Double
  _current_cursor_position : @math.Vector3
  _start_cursor_position : @math.Vector3
  mut _grid : @core.Object3D?
  _grid_position : @math.Vector3
  _gizmos : @core.Object3D
  mut _curve_pts : Int32
  mut _time_start : Double
  mut _animation_id : Double
  mut focus_animation_time : Double
  mut _time_prev : Double
  mut _time_current : Double
  mut _angle_prev : Double
  mut _angle_current : Double
  _cursor_pos_prev : @math.Vector3
  _cursor_pos_curr : @math.Vector3
  mut _w_prev : Double
  mut _w_curr : Double
  mut adjust_near_far : Bool
  mut scale_factor : Double
  mut damping_factor : Double
  mut w_max : Double
  mut enable_animations : Bool
  mut enable_grid : Bool
  mut cursor_zoom : Bool
  mut min_fov : Double
  mut max_fov : Double
  mut rotate_speed : Double
  mut enable_pan : Bool
  mut enable_rotate : Bool
  mut enable_zoom : Bool
  mut enable_gizmos : Bool
  mut enable_focus : Bool
  mut min_distance : Double
  mut max_distance : Double
  mut min_zoom : Double
  mut max_zoom : Double
  mut _tb_radius : Double
  mut _state : ArcballState
  mut _on_context_menu : (@core.JsValue) -> Unit
  mut _on_wheel : (@core.JsValue) -> Unit
  mut _on_pointer_up : (@core.JsValue) -> Unit
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_cancel : (@core.JsValue) -> Unit
  mut _on_window_resize : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for ArcballControls with fn event_dispatcher(self) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for ArcballControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend ArcballControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for ArcballControls with fn connect(
  self,
  _,
  _,
) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for ArcballControls with fn disconnect(
  self,
  _,
) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for ArcballControls with fn dispose(self, _) {
  self.dispose()
}

///|
pub impl @extras.ControlsExtension for ArcballControls with fn update(
  self,
  _,
  _,
) {
  self.update()
}

///|
/// `new ArcballControls( camera, domElement, scene )`.
pub fn ArcballControls::new(
  camera : @core.Object3D,
  dom_element? : @core.JsValue,
  scene? : @core.Object3D,
) -> ArcballControls {
  let base = @extras.Controls::new(camera, dom_element?)
  let self : ArcballControls = {
    base,
    scene,
    target: @math.Vector3::new(0.0, 0.0, 0.0),
    _current_target: @math.Vector3::new(0.0, 0.0, 0.0),
    radius_factor: 0.67,
    mouse_actions: [],
    _mouse_op: None,
    _v2_1: @math.Vector2::new(0.0, 0.0),
    _v3_1: @math.Vector3::new(0.0, 0.0, 0.0),
    _v3_2: @math.Vector3::new(0.0, 0.0, 0.0),
    _m4_1: @math.Matrix4::new(),
    _m4_2: @math.Matrix4::new(),
    _quat: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _translation_matrix: @math.Matrix4::new(),
    _rotation_matrix: @math.Matrix4::new(),
    _scale_matrix: @math.Matrix4::new(),
    _rotation_axis: @math.Vector3::new(0.0, 0.0, 0.0),
    _camera_matrix_state: @math.Matrix4::new(),
    _camera_projection_state: @math.Matrix4::new(),
    _fov_state: 1.0,
    _up_state: @math.Vector3::new(0.0, 0.0, 0.0),
    _zoom_state: 1.0,
    _near_pos: 0.0,
    _far_pos: 0.0,
    _gizmo_matrix_state: @math.Matrix4::new(),
    _up0: @math.Vector3::new(0.0, 0.0, 0.0),
    _zoom0: 1.0,
    _fov0: 0.0,
    _initial_near: 0.0,
    _near_pos0: 0.0,
    _initial_far: 0.0,
    _far_pos0: 0.0,
    _camera_matrix_state0: @math.Matrix4::new(),
    _gizmo_matrix_state0: @math.Matrix4::new(),
    _target0: @math.Vector3::new(0.0, 0.0, 0.0),
    _button: -1.0,
    _touch_start: [],
    _touch_current: [],
    _input: None,
    _switch_sensibility: 32.0,
    _start_finger_distance: 0.0,
    _current_finger_distance: 0.0,
    _start_finger_rotation: 0.0,
    _current_finger_rotation: 0.0,
    _dev_px_ratio: 0.0,
    _down_valid: true,
    _nclicks: 0,
    _down_events: [],
    _down_start: 0.0,
    _click_start: 0.0,
    _max_down_time: 250.0,
    _max_interval: 300.0,
    _pos_threshold: 24.0,
    _movement_threshold: 24.0,
    _current_cursor_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _start_cursor_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _grid: None,
    _grid_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _gizmos: @core.Group::new(),
    _curve_pts: 128,
    _time_start: -1.0,
    _animation_id: -1.0,
    focus_animation_time: 500.0,
    _time_prev: 0.0,
    _time_current: 0.0,
    _angle_prev: 0.0,
    _angle_current: 0.0,
    _cursor_pos_prev: @math.Vector3::new(0.0, 0.0, 0.0),
    _cursor_pos_curr: @math.Vector3::new(0.0, 0.0, 0.0),
    _w_prev: 0.0,
    _w_curr: 0.0,
    adjust_near_far: false,
    scale_factor: 1.1,
    damping_factor: 25.0,
    w_max: 20.0,
    enable_animations: true,
    enable_grid: false,
    cursor_zoom: false,
    min_fov: 5.0,
    max_fov: 90.0,
    rotate_speed: 1.0,
    enable_pan: true,
    enable_rotate: true,
    enable_zoom: true,
    enable_gizmos: true,
    enable_focus: true,
    min_distance: 0.0,
    max_distance: @double.infinity,
    min_zoom: 0.0,
    max_zoom: @double.infinity,
    _tb_radius: 1.0,
    _state: Idle,
    _on_context_menu: noop_listener,
    _on_wheel: noop_listener,
    _on_pointer_up: noop_listener,
    _on_pointer_move: noop_listener,
    _on_pointer_down: noop_listener,
    _on_pointer_cancel: noop_listener,
    _on_window_resize: noop_listener,
  }
  self.set_camera(camera)
  if self.scene is Some(scene) {
    ignore(scene.add(self._gizmos))
  }
  self.initialize_mouse_actions()
  self._on_context_menu = fn(event) { self.on_context_menu(event) }
  self._on_wheel = fn(event) { self.on_wheel(event) }
  self._on_pointer_up = fn(event) { self.on_pointer_up(event) }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
  self._on_pointer_cancel = fn(_) { self.on_pointer_cancel() }
  self._on_window_resize = fn(_) { self.on_window_resize() }
  base.extension = Some(self)
  if dom_element is Some(element) {
    self.connect(element)
  }
  self
}

///|
/// Connects the controls to the DOM element.
pub fn ArcballControls::connect(
  self : ArcballControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn ArcballControls::connect_listeners(self : ArcballControls) -> Unit {
  let window = dom_window()
  self._dev_px_ratio = dom_num(window, "devicePixelRatio")
  let element = dom_element_of(self.base)
  dom_add_event_listener(element, "contextmenu", self._on_context_menu)
  dom_add_event_listener_not_passive(element, "wheel", self._on_wheel)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "pointercancel", self._on_pointer_cancel)
  dom_add_event_listener(window, "resize", self._on_window_resize)
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn ArcballControls::disconnect(self : ArcballControls) -> Unit {
  let window = dom_window()
  let element = dom_element_of(self.base)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(element, "pointercancel", self._on_pointer_cancel)
  dom_remove_event_listener(element, "wheel", self._on_wheel)
  dom_remove_event_listener(element, "contextmenu", self._on_context_menu)
  dom_remove_event_listener(window, "pointermove", self._on_pointer_move)
  dom_remove_event_listener(window, "pointerup", self._on_pointer_up)
  dom_remove_event_listener(window, "resize", self._on_window_resize)
  dom_set_style(element, "touchAction", "")
}

///|
fn ArcballControls::_cancel_animation(self : ArcballControls) -> Unit {
  global_cancel_animation_frame(self._animation_id)
  self._animation_id = -1.0
  self._time_start = -1.0
}

///|
/// Starts a one-pointer operation: `"PAN"`, `"ROTATE"`, `"FOV"` or `"ZOOM"`.
pub fn ArcballControls::on_single_pan_start(
  self : ArcballControls,
  event : @core.JsValue,
  operation : String,
) -> Unit {
  if !self.base.enabled {
    return
  }
  self.dispatch_event(_arcball_start_event)
  self.set_center(ev_num(event, "clientX"), ev_num(event, "clientY"))
  let object = self.base.object
  let element = dom_element_of(self.base)
  match operation {
    "PAN" => {
      if !self.enable_pan {
        return
      }
      if self._animation_id != -1.0 {
        self._cancel_animation()
        self.activate_gizmos(false)
        self.dispatch_event(_arcball_change_event)
      }
      self.update_tb_state(Pan, true)
      ignore(
        self._start_cursor_position.copy(
          self.unproject_on_tb_plane(
            object,
            _arcball_center.x,
            _arcball_center.y,
            element,
          ),
        ),
      )
      if self.enable_grid {
        self.draw_grid()
        self.dispatch_event(_arcball_change_event)
      }
    }
    "ROTATE" => {
      if !self.enable_rotate {
        return
      }
      if self._animation_id != -1.0 {
        self._cancel_animation()
      }
      self.update_tb_state(Rotate, true)
      ignore(
        self._start_cursor_position.copy(
          self.unproject_on_tb_surface(
            object,
            _arcball_center.x,
            _arcball_center.y,
            element,
            self._tb_radius,
          ),
        ),
      )
      self.activate_gizmos(true)
      if self.enable_animations {
        self._time_current = performance_now()
        self._time_prev = self._time_current
        self._reset_angles()
        ignore(self._cursor_pos_prev.copy(self._start_cursor_position))
        ignore(self._cursor_pos_curr.copy(self._cursor_pos_prev))
        self._w_curr = 0.0
        self._w_prev = self._w_curr
      }
      self.dispatch_event(_arcball_change_event)
    }
    "FOV" => {
      if !object.is_perspective_camera() || !self.enable_zoom {
        return
      }
      if self._animation_id != -1.0 {
        self._cancel_animation()
        self.activate_gizmos(false)
        self.dispatch_event(_arcball_change_event)
      }
      self.update_tb_state(Fov, true)
      ignore(
        self._start_cursor_position.set_y(
          self.get_cursor_ndc(_arcball_center.x, _arcball_center.y, element).y *
          0.5,
        ),
      )
      ignore(self._current_cursor_position.copy(self._start_cursor_position))
    }
    "ZOOM" => {
      if !self.enable_zoom {
        return
      }
      if self._animation_id != -1.0 {
        self._cancel_animation()
        self.activate_gizmos(false)
        self.dispatch_event(_arcball_change_event)
      }
      self.update_tb_state(Scale, true)
      ignore(
        self._start_cursor_position.set_y(
          self.get_cursor_ndc(_arcball_center.x, _arcball_center.y, element).y *
          0.5,
        ),
      )
      ignore(self._current_cursor_position.copy(self._start_cursor_position))
    }
    _ => ()
  }
}

///|
fn ArcballControls::_reset_angles(self : ArcballControls) -> Unit {
  self._angle_prev = 0.0
  self._angle_current = self._angle_prev
}

///|
/// The size factor of a vertical drag of `movement` (in NDC / 2).
fn ArcballControls::_drag_size(
  self : ArcballControls,
  movement : Double,
) -> Double {
  let screen_notches = 8.0 //how many wheel notches corresponds to a full screen pan
  if movement < 0.0 {
    1.0 / js_pow(self.scale_factor, -movement * screen_notches)
  } else if movement > 0.0 {
    js_pow(self.scale_factor, movement * screen_notches)
  } else {
    1.0
  }
}

///|
/// The FOV ("vertigo") operation shared by mouse and three-finger drags.
fn ArcballControls::_vertigo(self : ArcballControls, size : Double) -> Unit {
  let object = self.base.object
  ignore(self._v3_1.set_from_matrix_position(self._camera_matrix_state))
  let x = self._v3_1.distance_to(self._gizmos.position)
  let mut x_new = x / size //distance between camera and gizmos if scale(size, scalepoint) would be performed
  //check min and max distance
  x_new = @math.clamp(x_new, self.min_distance, self.max_distance)
  let y = x * js_tan(@math.DEG2RAD * self._fov_state * 0.5)
  //calculate new fov
  let mut new_fov = @math.RAD2DEG * (js_atan(y / x_new) * 2.0)
  //check min and max fov
  new_fov = @math.clamp(new_fov, self.min_fov, self.max_fov)
  let new_distance = y / js_tan(@math.DEG2RAD * (new_fov / 2.0))
  let size = x / new_distance
  ignore(self._v3_2.set_from_matrix_position(self._gizmo_matrix_state))
  self.set_fov(new_fov)
  self.apply_transform_matrix(self.scale(size, self._v3_2, scale_gizmos=false))
  //adjusting distance
  ignore(
    _arcball_offset
    .copy(self._gizmos.position)
    .sub(object.position)
    .normalize()
    .multiply_scalar(new_distance / x),
  )
  ignore(
    self._m4_1.make_translation(
      _arcball_offset.x,
      _arcball_offset.y,
      _arcball_offset.z,
    ),
  )
}

///|
/// Continues a one-pointer operation in state `op_state`.
pub fn ArcballControls::on_single_pan_move(
  self : ArcballControls,
  event : @core.JsValue,
  op_state : ArcballState,
) -> Unit {
  if !self.base.enabled {
    return
  }
  let restart = op_state != self._state
  self.set_center(ev_num(event, "clientX"), ev_num(event, "clientY"))
  let object = self.base.object
  let element = dom_element_of(self.base)
  match op_state {
    Pan =>
      if self.enable_pan {
        if restart {
          //switch to pan operation
          self.dispatch_event(_arcball_end_event)
          self.dispatch_event(_arcball_start_event)
          self.update_tb_state(op_state, true)
          ignore(
            self._start_cursor_position.copy(
              self.unproject_on_tb_plane(
                object,
                _arcball_center.x,
                _arcball_center.y,
                element,
              ),
            ),
          )
          if self.enable_grid {
            self.draw_grid()
          }
          self.activate_gizmos(false)
        } else {
          //continue with pan operation
          ignore(
            self._current_cursor_position.copy(
              self.unproject_on_tb_plane(
                object,
                _arcball_center.x,
                _arcball_center.y,
                element,
              ),
            ),
          )
          self.apply_transform_matrix(
            self.pan(self._start_cursor_position, self._current_cursor_position),
          )
        }
      }
    Rotate =>
      if self.enable_rotate {
        if restart {
          //switch to rotate operation
          self.dispatch_event(_arcball_end_event)
          self.dispatch_event(_arcball_start_event)
          self.update_tb_state(op_state, true)
          ignore(
            self._start_cursor_position.copy(
              self.unproject_on_tb_surface(
                object,
                _arcball_center.x,
                _arcball_center.y,
                element,
                self._tb_radius,
              ),
            ),
          )
          if self.enable_grid {
            self.dispose_grid()
          }
          self.activate_gizmos(true)
        } else {
          //continue with rotate operation
          ignore(
            self._current_cursor_position.copy(
              self.unproject_on_tb_surface(
                object,
                _arcball_center.x,
                _arcball_center.y,
                element,
                self._tb_radius,
              ),
            ),
          )
          let distance = self._start_cursor_position.distance_to(
            self._current_cursor_position,
          )
          let angle = self._start_cursor_position.angle_to(
            self._current_cursor_position,
          )
          let amount = js_max(distance / self._tb_radius, angle) *
            self.rotate_speed //effective rotation angle
          self.apply_transform_matrix(
            self.rotate(
              self.calculate_rotation_axis(
                self._start_cursor_position,
                self._current_cursor_position,
              ),
              amount,
            ),
          )
          if self.enable_animations {
            self._time_prev = self._time_current
            self._time_current = performance_now()
            self._angle_prev = self._angle_current
            self._angle_current = amount
            ignore(self._cursor_pos_prev.copy(self._cursor_pos_curr))
            ignore(self._cursor_pos_curr.copy(self._current_cursor_position))
            self._w_prev = self._w_curr
            self._w_curr = self.calculate_angular_speed(
              self._angle_prev,
              self._angle_current,
              self._time_prev,
              self._time_current,
            )
          }
        }
      }
    Scale =>
      if self.enable_zoom {
        if restart {
          //switch to zoom operation
          self.dispatch_event(_arcball_end_event)
          self.dispatch_event(_arcball_start_event)
          self.update_tb_state(op_state, true)
          ignore(
            self._start_cursor_position.set_y(
              self.get_cursor_ndc(_arcball_center.x, _arcball_center.y, element).y *
              0.5,
            ),
          )
          ignore(
            self._current_cursor_position.copy(self._start_cursor_position),
          )
          if self.enable_grid {
            self.dispose_grid()
          }
          self.activate_gizmos(false)
        } else {
          //continue with zoom operation
          ignore(
            self._current_cursor_position.set_y(
              self.get_cursor_ndc(_arcball_center.x, _arcball_center.y, element).y *
              0.5,
            ),
          )
          let movement = self._current_cursor_position.y -
            self._start_cursor_position.y
          let size = self._drag_size(movement)
          ignore(self._v3_1.set_from_matrix_position(self._gizmo_matrix_state))
          self.apply_transform_matrix(self.scale(size, self._v3_1))
        }
      }
    Fov =>
      if self.enable_zoom && object.is_perspective_camera() {
        if restart {
          //switch to fov operation
          self.dispatch_event(_arcball_end_event)
          self.dispatch_event(_arcball_start_event)
          self.update_tb_state(op_state, true)
          ignore(
            self._start_cursor_position.set_y(
              self.get_cursor_ndc(_arcball_center.x, _arcball_center.y, element).y *
              0.5,
            ),
          )
          ignore(
            self._current_cursor_position.copy(self._start_cursor_position),
          )
          if self.enable_grid {
            self.dispose_grid()
          }
          self.activate_gizmos(false)
        } else {
          //continue with fov operation
          ignore(
            self._current_cursor_position.set_y(
              self.get_cursor_ndc(_arcball_center.x, _arcball_center.y, element).y *
              0.5,
            ),
          )
          let movement = self._current_cursor_position.y -
            self._start_cursor_position.y
          self._vertigo(self._drag_size(movement))
        }
      }
    _ => ()
  }
  self.dispatch_event(_arcball_change_event)
}

///|
/// Ends a one-pointer operation.
pub fn ArcballControls::on_single_pan_end(self : ArcballControls) -> Unit {
  if self._state == Rotate {
    if !self.enable_rotate {
      return
    }
    if self.enable_animations {
      //perform rotation animation
      let delta_time = performance_now() - self._time_current
      if delta_time < 120.0 {
        let w = js_abs((self._w_prev + self._w_curr) / 2.0)
        self._animation_id = window_request_animation_frame(fn(t) {
          self.update_tb_state(AnimationRotate, true)
          let rotation_axis = self.calculate_rotation_axis(
            self._cursor_pos_prev,
            self._cursor_pos_curr,
          )
          self.on_rotation_anim(t, rotation_axis, js_min(w, self.w_max))
        })
      } else {
        //cursor has been standing still for over 120 ms since last movement
        self.update_tb_state(Idle, false)
        self.activate_gizmos(false)
        self.dispatch_event(_arcball_change_event)
      }
    } else {
      self.update_tb_state(Idle, false)
      self.activate_gizmos(false)
      self.dispatch_event(_arcball_change_event)
    }
  } else if self._state == Pan || self._state == Idle {
    self.update_tb_state(Idle, false)
    if self.enable_grid {
      self.dispose_grid()
    }
    self.activate_gizmos(false)
    self.dispatch_event(_arcball_change_event)
  }
  self.dispatch_event(_arcball_end_event)
}

///|
/// Focuses on the point under a double tap.
pub fn ArcballControls::on_double_tap(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  if self.base.enabled &&
    self.enable_pan &&
    self.enable_focus &&
    self.scene is Some(_) {
    self.dispatch_event(_arcball_start_event)
    self.set_center(ev_num(event, "clientX"), ev_num(event, "clientY"))
    let hit_p = self.unproject_on_obj(
      self.get_cursor_ndc(
        _arcball_center.x,
        _arcball_center.y,
        dom_element_of(self.base),
      ),
      self.base.object,
    )
    if hit_p is Some(hit_p) && self.enable_animations {
      if self._animation_id != -1.0 {
        window_cancel_animation_frame(self._animation_id)
      }
      self._time_start = -1.0
      self._animation_id = window_request_animation_frame(fn(t) {
        self.update_tb_state(AnimationFocus, true)
        self.on_focus_anim(
          t,
          hit_p,
          self._camera_matrix_state,
          self._gizmo_matrix_state,
        )
      })
    } else if hit_p is Some(hit_p) && !self.enable_animations {
      self.update_tb_state(Focus, true)
      self.focus(hit_p, self.scale_factor)
      self.update_tb_state(Idle, false)
      self.dispatch_event(_arcball_change_event)
    }
  }
  self.dispatch_event(_arcball_end_event)
}

///|
fn ArcballControls::_two_finger_center(self : ArcballControls) -> Unit {
  self.set_center(
    (
      ev_num(self._touch_current[0], "clientX") +
      ev_num(self._touch_current[1], "clientX")
    ) /
    2.0,
    (
      ev_num(self._touch_current[0], "clientY") +
      ev_num(self._touch_current[1], "clientY")
    ) /
    2.0,
  )
}

///|
/// Starts a two-finger pan.
pub fn ArcballControls::on_double_pan_start(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_pan {
    self.dispatch_event(_arcball_start_event)
    self.update_tb_state(Pan, true)
    self._two_finger_center()
    ignore(
      self._start_cursor_position.copy(
        self.unproject_on_tb_plane(
          self.base.object,
          _arcball_center.x,
          _arcball_center.y,
          dom_element_of(self.base),
          initial_distance=true,
        ),
      ),
    )
    ignore(self._current_cursor_position.copy(self._start_cursor_position))
    self.activate_gizmos(false)
  }
}

///|
/// Continues a two-finger pan.
pub fn ArcballControls::on_double_pan_move(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_pan {
    self._two_finger_center()
    if self._state != Pan {
      self.update_tb_state(Pan, true)
      ignore(self._start_cursor_position.copy(self._current_cursor_position))
    }
    ignore(
      self._current_cursor_position.copy(
        self.unproject_on_tb_plane(
          self.base.object,
          _arcball_center.x,
          _arcball_center.y,
          dom_element_of(self.base),
          initial_distance=true,
        ),
      ),
    )
    self.apply_transform_matrix(
      self.pan(
        self._start_cursor_position,
        self._current_cursor_position,
        adjust=true,
      ),
    )
    self.dispatch_event(_arcball_change_event)
  }
}

///|
/// Ends a two-finger pan.
pub fn ArcballControls::on_double_pan_end(self : ArcballControls) -> Unit {
  self.update_tb_state(Idle, false)
  self.dispatch_event(_arcball_end_event)
}

///|
/// Starts a two-finger rotation around the view axis.
pub fn ArcballControls::on_rotate_start(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_rotate {
    self.dispatch_event(_arcball_start_event)
    self.update_tb_state(ZRotate, true)
    //this._startFingerRotation = event.rotation;
    self._start_finger_rotation = self.get_angle(
        self._touch_current[1],
        self._touch_current[0],
      ) +
      self.get_angle(self._touch_start[1], self._touch_start[0])
    self._current_finger_rotation = self._start_finger_rotation
    ignore(self.base.object.get_world_direction(self._rotation_axis)) //rotation axis
    if !self.enable_pan && !self.enable_zoom {
      self.activate_gizmos(true)
    }
  }
}

///|
/// Continues a two-finger rotation.
pub fn ArcballControls::on_rotate_move(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_rotate {
    self._two_finger_center()
    if self._state != ZRotate {
      self.update_tb_state(ZRotate, true)
      self._start_finger_rotation = self._current_finger_rotation
    }
    //this._currentFingerRotation = event.rotation;
    self._current_finger_rotation = self.get_angle(
        self._touch_current[1],
        self._touch_current[0],
      ) +
      self.get_angle(self._touch_start[1], self._touch_start[0])
    let object = self.base.object
    let rotation_point = if !self.enable_pan {
      @math.Vector3::new(0.0, 0.0, 0.0).set_from_matrix_position(
        self._gizmo_matrix_state,
      )
    } else {
      ignore(self._v3_2.set_from_matrix_position(self._gizmo_matrix_state))
      self
      .unproject_on_tb_plane(
        object,
        _arcball_center.x,
        _arcball_center.y,
        dom_element_of(self.base),
      )
      .apply_quaternion(object.quaternion)
      .multiply_scalar(1.0 / camera_zoom(object))
      .add(self._v3_2)
    }
    let amount = @math.DEG2RAD *
      (self._start_finger_rotation - self._current_finger_rotation)
    self.apply_transform_matrix(self.z_rotate(rotation_point, amount))
    self.dispatch_event(_arcball_change_event)
  }
}

///|
/// Ends a two-finger rotation.
pub fn ArcballControls::on_rotate_end(self : ArcballControls) -> Unit {
  self.update_tb_state(Idle, false)
  self.activate_gizmos(false)
  self.dispatch_event(_arcball_end_event)
}

///|
/// Starts a pinch.
pub fn ArcballControls::on_pinch_start(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_zoom {
    self.dispatch_event(_arcball_start_event)
    self.update_tb_state(Scale, true)
    self._start_finger_distance = self.calculate_pointers_distance(
      self._touch_current[0],
      self._touch_current[1],
    )
    self._current_finger_distance = self._start_finger_distance
    self.activate_gizmos(false)
  }
}

///|
/// Continues a pinch.
pub fn ArcballControls::on_pinch_move(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_zoom {
    self._two_finger_center()
    let min_distance = 12.0 //minimum distance between fingers (in css pixels)
    if self._state != Scale {
      self._start_finger_distance = self._current_finger_distance
      self.update_tb_state(Scale, true)
    }
    self._current_finger_distance = js_max(
      self.calculate_pointers_distance(
        self._touch_current[0],
        self._touch_current[1],
      ),
      min_distance * self._dev_px_ratio,
    )
    let amount = self._current_finger_distance / self._start_finger_distance
    let object = self.base.object
    let scale_point = if !self.enable_pan {
      self._gizmos.position
    } else if object.is_orthographic_camera() {
      self
      .unproject_on_tb_plane(
        object,
        _arcball_center.x,
        _arcball_center.y,
        dom_element_of(self.base),
      )
      .apply_quaternion(object.quaternion)
      .multiply_scalar(1.0 / camera_zoom(object))
      .add(self._gizmos.position)
    } else if object.is_perspective_camera() {
      self
      .unproject_on_tb_plane(
        object,
        _arcball_center.x,
        _arcball_center.y,
        dom_element_of(self.base),
      )
      .apply_quaternion(object.quaternion)
      .add(self._gizmos.position)
    } else {
      abort("ArcballControls: unsupported camera type")
    }
    self.apply_transform_matrix(self.scale(amount, scale_point))
    self.dispatch_event(_arcball_change_event)
  }
}

///|
/// Ends a pinch.
pub fn ArcballControls::on_pinch_end(self : ArcballControls) -> Unit {
  self.update_tb_state(Idle, false)
  self.dispatch_event(_arcball_end_event)
}

///|
fn ArcballControls::_touch_centroid(self : ArcballControls) -> Unit {
  let mut client_x = 0.0
  let mut client_y = 0.0
  let n_fingers = self._touch_current.length()
  for i in 0..<n_fingers {
    client_x += ev_num(self._touch_current[i], "clientX")
    client_y += ev_num(self._touch_current[i], "clientY")
  }
  self.set_center(
    client_x / n_fingers.to_double(),
    client_y / n_fingers.to_double(),
  )
}

///|
/// Starts a three-finger drag (FOV).
pub fn ArcballControls::on_triple_pan_start(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_zoom {
    self.dispatch_event(_arcball_start_event)
    self.update_tb_state(Scale, true)
    //const center = event.center;
    self._touch_centroid()
    ignore(
      self._start_cursor_position.set_y(
        self.get_cursor_ndc(
          _arcball_center.x,
          _arcball_center.y,
          dom_element_of(self.base),
        ).y *
        0.5,
      ),
    )
    ignore(self._current_cursor_position.copy(self._start_cursor_position))
  }
}

///|
/// Continues a three-finger drag.
pub fn ArcballControls::on_triple_pan_move(self : ArcballControls) -> Unit {
  if self.base.enabled && self.enable_zoom {
    //const center = event.center;
    self._touch_centroid()
    ignore(
      self._current_cursor_position.set_y(
        self.get_cursor_ndc(
          _arcball_center.x,
          _arcball_center.y,
          dom_element_of(self.base),
        ).y *
        0.5,
      ),
    )
    let movement = self._current_cursor_position.y -
      self._start_cursor_position.y
    self._vertigo(self._drag_size(movement))
    self.dispatch_event(_arcball_change_event)
  }
}

///|
/// Ends a three-finger drag.
pub fn ArcballControls::on_triple_pan_end(self : ArcballControls) -> Unit {
  self.update_tb_state(Idle, false)
  self.dispatch_event(_arcball_end_event)
  //this.dispatchEvent( _changeEvent );
}

///|
/// Sets the cursor center coordinates.
pub fn ArcballControls::set_center(
  self : ArcballControls,
  client_x : Double,
  client_y : Double,
) -> Unit {
  ignore(self)
  _arcball_center.x = client_x
  _arcball_center.y = client_y
}

///|
/// Sets the default mouse actions.
pub fn ArcballControls::initialize_mouse_actions(
  self : ArcballControls,
) -> Unit {
  ignore(self.set_mouse_action("PAN", Button(0), key="CTRL"))
  ignore(self.set_mouse_action("PAN", Button(2)))
  ignore(self.set_mouse_action("ROTATE", Button(0)))
  ignore(self.set_mouse_action("ZOOM", Wheel))
  ignore(self.set_mouse_action("ZOOM", Button(1)))
  ignore(self.set_mouse_action("FOV", Wheel, key="SHIFT"))
  ignore(self.set_mouse_action("FOV", Button(1), key="SHIFT"))
}

///|
/// Whether two mouse actions are equal.
pub fn ArcballControls::compare_mouse_action(
  self : ArcballControls,
  action1 : ArcballMouseAction,
  action2 : ArcballMouseAction,
) -> Bool {
  ignore(self)
  if action1.operation == action2.operation {
    if action1.mouse == action2.mouse && action1.key == action2.key {
      true
    } else {
      false
    }
  } else {
    false
  }
}

///|
/// Binds `operation` (`"PAN"`, `"ROTATE"`, `"ZOOM"`, `"FOV"`) to `mouse` and the
/// optional `key` (`"CTRL"`, `"SHIFT"`). Returns `false` for invalid input.
pub fn ArcballControls::set_mouse_action(
  self : ArcballControls,
  operation : String,
  mouse : ArcballMouse,
  key? : String,
) -> Bool {
  let operation_input = ["PAN", "ROTATE", "ZOOM", "FOV"]
  let mouse_input = [Button(0), Button(1), Button(2), Wheel]
  let key_input : Array[String?] = [Some("CTRL"), Some("SHIFT"), None]
  if !operation_input.contains(operation) ||
    !mouse_input.contains(mouse) ||
    !key_input.contains(key) {
    //invalid parameters
    return false
  }
  if mouse == Wheel {
    if operation != "ZOOM" && operation != "FOV" {
      //cannot associate 2D operation to 1D input
      return false
    }
  }
  let state : ArcballState = match operation {
    "PAN" => Pan
    "ROTATE" => Rotate
    "ZOOM" => Scale
    _ => Fov
  }
  let action = { operation, mouse, key, state, }
  for i in 0..<self.mouse_actions.length() {
    if self.mouse_actions[i].mouse == action.mouse &&
      self.mouse_actions[i].key == action.key {
      self.mouse_actions[i] = action
      return true
    }
  }
  self.mouse_actions.push(action)
  true
}

///|
/// Removes the action bound to `mouse` and `key`.
pub fn ArcballControls::unset_mouse_action(
  self : ArcballControls,
  mouse : ArcballMouse,
  key? : String,
) -> Bool {
  for i in 0..<self.mouse_actions.length() {
    if self.mouse_actions[i].mouse == mouse && self.mouse_actions[i].key == key {
      ignore(self.mouse_actions.remove(i))
      return true
    }
  }
  false
}

///|
/// The operation bound to `mouse` and `key`, falling back to `mouse` alone.
pub fn ArcballControls::get_op_from_action(
  self : ArcballControls,
  mouse : ArcballMouse?,
  key : String?,
) -> String? {
  for action in self.mouse_actions {
    if Some(action.mouse) == mouse && action.key == key {
      return Some(action.operation)
    }
  }
  if key is Some(_) {
    for action in self.mouse_actions {
      if Some(action.mouse) == mouse && action.key is None {
        return Some(action.operation)
      }
    }
  }
  None
}

///|
/// The state bound to `mouse` and `key`, falling back to `mouse` alone.
pub fn ArcballControls::get_op_state_from_action(
  self : ArcballControls,
  mouse : ArcballMouse?,
  key : String?,
) -> ArcballState? {
  for action in self.mouse_actions {
    if Some(action.mouse) == mouse && action.key == key {
      return Some(action.state)
    }
  }
  if key is Some(_) {
    for action in self.mouse_actions {
      if Some(action.mouse) == mouse && action.key is None {
        return Some(action.state)
      }
    }
  }
  None
}

///|
/// `event.button` as a mouse input (`None` when it is not a whole number).
fn arcball_button(button : Double) -> ArcballMouse? {
  let i = button.to_int()
  if i.to_double() == button {
    Some(Button(i))
  } else {
    None
  }
}

///|
/// The angle in degrees between the pointers of two events.
pub fn ArcballControls::get_angle(
  self : ArcballControls,
  p1 : @core.JsValue,
  p2 : @core.JsValue,
) -> Double {
  ignore(self)
  js_atan2(
    ev_num(p2, "clientY") - ev_num(p1, "clientY"),
    ev_num(p2, "clientX") - ev_num(p1, "clientX"),
  ) *
  180.0 /
  js_pi
}

///|
/// Replaces the stored touch event of `event`'s pointer.
pub fn ArcballControls::update_touch_event(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  let pointer_id = ev_num(event, "pointerId")
  for i in 0..<self._touch_current.length() {
    if ev_num(self._touch_current[i], "pointerId") == pointer_id {
      self._touch_current[i] = event
      break
    }
  }
}

///|
/// Applies a transformation to the camera and the gizmos.
pub fn ArcballControls::apply_transform_matrix(
  self : ArcballControls,
  transformation : ArcballTransformation,
) -> Unit {
  let object = self.base.object
  if transformation.camera is Some(camera) {
    ignore(self._m4_1.copy(self._camera_matrix_state).premultiply(camera))
    ignore(
      self._m4_1.decompose(object.position, object.quaternion, object.scale),
    )
    object.update_matrix()
    //update camera up vector
    if self._state == Rotate ||
      self._state == ZRotate ||
      self._state == AnimationRotate {
      ignore(object.up.copy(self._up_state).apply_quaternion(object.quaternion))
    }
  }
  if transformation.gizmos is Some(gizmos) {
    ignore(self._m4_1.copy(self._gizmo_matrix_state).premultiply(gizmos))
    ignore(
      self._m4_1.decompose(
        self._gizmos.position,
        self._gizmos.quaternion,
        self._gizmos.scale,
      ),
    )
    self._gizmos.update_matrix()
  }
  if self._state == Scale ||
    self._state == Focus ||
    self._state == AnimationFocus {
    self._tb_radius = self.calculate_tb_radius(object)
    if self.adjust_near_far {
      let camera_distance = object.position.distance_to(self._gizmos.position)
      let bb = @math.Box3::new()
      ignore(@core.box3_set_from_object(bb, self._gizmos))
      let sphere = @math.Sphere::new()
      ignore(bb.get_bounding_sphere(sphere))
      let adjusted_near_position = js_max(
        self._near_pos0,
        sphere.radius + sphere.center.length(),
      )
      let regular_near_position = camera_distance - self._initial_near
      let min_near_pos = js_min(adjusted_near_position, regular_near_position)
      set_camera_near(object, camera_distance - min_near_pos)
      let adjusted_far_position = js_min(
        self._far_pos0,
        -sphere.radius + sphere.center.length(),
      )
      let regular_far_position = camera_distance - self._initial_far
      let min_far_pos = js_min(adjusted_far_position, regular_far_position)
      set_camera_far(object, camera_distance - min_far_pos)
      object.update_projection_matrix()
    } else {
      let mut update = false
      if camera_near(object) != self._initial_near {
        set_camera_near(object, self._initial_near)
        update = true
      }
      if camera_far(object) != self._initial_far {
        set_camera_far(object, self._initial_far)
        update = true
      }
      if update {
        object.update_projection_matrix()
      }
    }
  }
}

///|
/// The angular speed between two rotations, in radians per second.
pub fn ArcballControls::calculate_angular_speed(
  self : ArcballControls,
  p0 : Double,
  p1 : Double,
  t0 : Double,
  t1 : Double,
) -> Double {
  ignore(self)
  let s = p1 - p0
  let t = (t1 - t0) / 1000.0
  if t == 0.0 {
    return 0.0
  }
  s / t
}

///|
/// The distance between the pointers of two events.
pub fn ArcballControls::calculate_pointers_distance(
  self : ArcballControls,
  p0 : @core.JsValue,
  p1 : @core.JsValue,
) -> Double {
  ignore(self)
  js_sqrt(
    js_pow(ev_num(p1, "clientX") - ev_num(p0, "clientX"), 2.0) +
    js_pow(ev_num(p1, "clientY") - ev_num(p0, "clientY"), 2.0),
  )
}

///|
/// The rotation axis of a drag from `vec1` to `vec2`, in world space.
pub fn ArcballControls::calculate_rotation_axis(
  self : ArcballControls,
  vec1 : @math.Vector3,
  vec2 : @math.Vector3,
) -> @math.Vector3 {
  ignore(self._rotation_matrix.extract_rotation(self._camera_matrix_state))
  ignore(self._quat.set_from_rotation_matrix(self._rotation_matrix))
  ignore(
    self._rotation_axis.cross_vectors(vec1, vec2).apply_quaternion(self._quat),
  )
  self._rotation_axis.normalize().clone()
}

///|
/// The trackball radius for `camera`.
pub fn ArcballControls::calculate_tb_radius(
  self : ArcballControls,
  camera : @core.Object3D,
) -> Double {
  let distance = camera.position.distance_to(self._gizmos.position)
  if camera.type_ == "PerspectiveCamera" {
    let half_fov_v = @math.DEG2RAD * camera_fov(camera) * 0.5 //vertical fov/2 in radians
    let half_fov_h = js_atan(camera_aspect(camera) * js_tan(half_fov_v)) //horizontal fov/2 in radians
    js_tan(js_min(half_fov_v, half_fov_h)) * distance * self.radius_factor
  } else if camera.type_ == "OrthographicCamera" {
    js_min(ortho_top(camera), ortho_right(camera)) * self.radius_factor
  } else {
    js_undefined_number()
  }
}

///|
/// Moves the camera and gizmos towards `point`, zooming by `size`.
pub fn ArcballControls::focus(
  self : ArcballControls,
  point : @math.Vector3,
  size : Double,
  amount~ : Double = 1.0,
) -> Unit {
  let object = self.base.object
  //move center of camera (along with gizmos) towards point of interest
  ignore(
    _arcball_offset
    .copy(point)
    .sub(self._gizmos.position)
    .multiply_scalar(amount),
  )
  ignore(
    self._translation_matrix.make_translation(
      _arcball_offset.x,
      _arcball_offset.y,
      _arcball_offset.z,
    ),
  )
  ignore(_arcball_gizmo_matrix_state_temp.copy(self._gizmo_matrix_state))
  ignore(self._gizmo_matrix_state.premultiply(self._translation_matrix))
  ignore(
    self._gizmo_matrix_state.decompose(
      self._gizmos.position,
      self._gizmos.quaternion,
      self._gizmos.scale,
    ),
  )
  ignore(_arcball_camera_matrix_state_temp.copy(self._camera_matrix_state))
  ignore(self._camera_matrix_state.premultiply(self._translation_matrix))
  ignore(
    self._camera_matrix_state.decompose(
      object.position,
      object.quaternion,
      object.scale,
    ),
  )
  //apply zoom
  if self.enable_zoom {
    self.apply_transform_matrix(self.scale(size, self._gizmos.position))
  }
  ignore(self._gizmo_matrix_state.copy(_arcball_gizmo_matrix_state_temp))
  ignore(self._camera_matrix_state.copy(_arcball_camera_matrix_state_temp))
}

///|
/// Draws the pan grid.
pub fn ArcballControls::draw_grid(self : ArcballControls) -> Unit {
  guard self.scene is Some(scene) else { return }
  let object = self.base.object
  let color = @math.Color::from_hex(0x888888)
  let multiplier = 3.0
  let mut size : Double? = None
  let mut divisions : Double? = None
  if object.is_orthographic_camera() {
    let width = ortho_right(object) - ortho_left(object)
    let height = ortho_bottom(object) - ortho_top(object)
    let max_length = js_max(width, height)
    let tick = max_length / 20.0
    let s = max_length / camera_zoom(object) * multiplier
    size = Some(s)
    divisions = Some(s / tick * camera_zoom(object))
  } else if object.is_perspective_camera() {
    let distance = object.position.distance_to(self._gizmos.position)
    let half_fov_v = @math.DEG2RAD * camera_fov(object) * 0.5
    let half_fov_h = js_atan(camera_aspect(object) * js_tan(half_fov_v))
    let max_length = js_tan(js_max(half_fov_v, half_fov_h)) * distance * 2.0
    let tick = max_length / 20.0
    let s = max_length * multiplier
    size = Some(s)
    divisions = Some(s / tick)
  }
  if self._grid is None {
    let grid = @helpers.GridHelper::new(
      size?,
      divisions?,
      color1=color,
      color2=color,
    )
    ignore(grid.position.copy(self._gizmos.position))
    ignore(self._grid_position.copy(grid.position))
    ignore(grid.quaternion.copy(object.quaternion))
    ignore(grid.rotate_x(js_pi * 0.5))
    ignore(scene.add(grid))
    self._grid = Some(grid)
  }
}

///|
/// Removes the listeners, the gizmos and the grid.
pub fn ArcballControls::dispose(self : ArcballControls) -> Unit {
  if self._animation_id != -1.0 {
    window_cancel_animation_frame(self._animation_id)
  }
  self.disconnect()
  if self.scene is Some(scene) {
    ignore(scene.remove(self._gizmos))
  }
  self.dispose_grid()
}

///|
/// Removes the pan grid.
pub fn ArcballControls::dispose_grid(self : ArcballControls) -> Unit {
  if self._grid is Some(grid) && self.scene is Some(scene) {
    ignore(scene.remove(grid))
    self._grid = None
  }
}

///|
/// `1 - ( 1 - t )^3`.
pub fn ArcballControls::ease_out_cubic(
  self : ArcballControls,
  t : Double,
) -> Double {
  ignore(self)
  1.0 - js_pow(1.0 - t, 3.0)
}

///|
/// Sets the gizmos' opacity for an active or inactive operation.
pub fn ArcballControls::activate_gizmos(
  self : ArcballControls,
  is_active : Bool,
) -> Unit {
  let children = self._gizmos.children
  let opacity = if is_active { 1.0 } else { 0.6 }
  for i in 0..<3 {
    let gizmo = match children.get(i) {
      Some(gizmo) => gizmo
      None => abort("ArcballControls: missing gizmo")
    }
    material_of(gizmo).opacity = opacity
  }
}

///|
/// The cursor position in NDC.
pub fn ArcballControls::get_cursor_ndc(
  self : ArcballControls,
  cursor_x : Double,
  cursor_y : Double,
  canvas : @core.JsValue,
) -> @math.Vector2 {
  let canvas_rect = dom_get_bounding_client_rect(canvas)
  ignore(
    self._v2_1.set_x(
      (cursor_x - ev_num(canvas_rect, "left")) /
      ev_num(canvas_rect, "width") *
      2.0 -
      1.0,
    ),
  )
  ignore(
    self._v2_1.set_y(
      (ev_num(canvas_rect, "bottom") - cursor_y) /
      ev_num(canvas_rect, "height") *
      2.0 -
      1.0,
    ),
  )
  self._v2_1.clone()
}

///|
/// The cursor position in the orthographic camera's view plane.
pub fn ArcballControls::get_cursor_position(
  self : ArcballControls,
  cursor_x : Double,
  cursor_y : Double,
  canvas : @core.JsValue,
) -> @math.Vector2 {
  let object = self.base.object
  ignore(self._v2_1.copy(self.get_cursor_ndc(cursor_x, cursor_y, canvas)))
  self._v2_1.x *= (ortho_right(object) - ortho_left(object)) * 0.5
  self._v2_1.y *= (ortho_top(object) - ortho_bottom(object)) * 0.5
  self._v2_1.clone()
}

///|
/// Sets the camera and rebuilds the gizmos.
pub fn ArcballControls::set_camera(
  self : ArcballControls,
  camera : @core.Object3D,
) -> Unit {
  camera.look_at(self.target)
  camera.update_matrix()
  //setting state
  if camera.type_ == "PerspectiveCamera" {
    self._fov0 = camera_fov(camera)
    self._fov_state = camera_fov(camera)
  }
  ignore(self._camera_matrix_state0.copy(camera.matrix))
  ignore(self._camera_matrix_state.copy(self._camera_matrix_state0))
  ignore(
    self._camera_projection_state.copy(camera.as_camera().projection_matrix),
  )
  self._zoom0 = camera_zoom(camera)
  self._zoom_state = self._zoom0
  self._initial_near = camera_near(camera)
  self._near_pos0 = camera.position.distance_to(self.target) -
    camera_near(camera)
  self._near_pos = self._initial_near
  self._initial_far = camera_far(camera)
  self._far_pos0 = camera.position.distance_to(self.target) - camera_far(camera)
  self._far_pos = self._initial_far
  ignore(self._up0.copy(camera.up))
  ignore(self._up_state.copy(camera.up))
  self.base.object = camera
  self.base.object.update_projection_matrix()
  //making gizmos
  self._tb_radius = self.calculate_tb_radius(camera)
  self.make_gizmos(self.target, self._tb_radius)
}

///|
/// Shows or hides the gizmos.
pub fn ArcballControls::set_gizmos_visible(
  self : ArcballControls,
  value : Bool,
) -> Unit {
  self._gizmos.visible = value
  self.dispatch_event(_arcball_change_event)
}

///|
fn ArcballControls::_set_curve_geometry(
  self : ArcballControls,
  radius : Double,
) -> Unit {
  let curve = @extras.EllipseCurve::new(
    a_x=0.0,
    a_y=0.0,
    x_radius=radius,
    y_radius=radius,
  )
  let points = curve.get_points(divisions=self._curve_pts)
  let curve_geometry = @core.BufferGeometry::new().set_from_points2(points)
  for gizmo in self._gizmos.children {
    set_geometry_of(gizmo, curve_geometry)
  }
}

///|
/// Sets the trackball radius factor and rebuilds the gizmo curves.
pub fn ArcballControls::set_tb_radius(
  self : ArcballControls,
  value : Double,
) -> Unit {
  self.radius_factor = value
  self._tb_radius = self.calculate_tb_radius(self.base.object)
  self._set_curve_geometry(self._tb_radius)
  self.dispatch_event(_arcball_change_event)
}

///|
/// Builds the three gizmo circles around `tb_center`.
pub fn ArcballControls::make_gizmos(
  self : ArcballControls,
  tb_center : @math.Vector3,
  tb_radius : Double,
) -> Unit {
  let object = self.base.object
  let curve = @extras.EllipseCurve::new(
    a_x=0.0,
    a_y=0.0,
    x_radius=tb_radius,
    y_radius=tb_radius,
  )
  let points = curve.get_points(divisions=self._curve_pts)
  //geometry
  let curve_geometry = @core.BufferGeometry::new().set_from_points2(points)
  //material
  let line_material = fn(hex : Int32) {
    let material = @core.LineBasicMaterial::new()
    ignore(color_of(material).set_hex(hex))
    material.fog = Some(false)
    material.transparent = true
    material.opacity = 0.6
    material
  }
  let curve_material_x = line_material(0xff8080)
  let curve_material_y = line_material(0x80ff80)
  let curve_material_z = line_material(0x8080ff)
  //line
  let gizmo_x = @core.Line::new(
    geometry=curve_geometry,
    material=Single(curve_material_x),
  )
  let gizmo_y = @core.Line::new(
    geometry=curve_geometry,
    material=Single(curve_material_y),
  )
  let gizmo_z = @core.Line::new(
    geometry=curve_geometry,
    material=Single(curve_material_z),
  )
  let rotation = js_pi * 0.5
  gizmo_x.rotation.set_y(rotation)
  gizmo_y.rotation.set_x(rotation)
  //setting state
  ignore(
    self._gizmo_matrix_state0
    .identity()
    .set_position(tb_center.x, tb_center.y, tb_center.z),
  )
  ignore(self._gizmo_matrix_state.copy(self._gizmo_matrix_state0))
  if camera_zoom(object) != 1.0 {
    //adapt gizmos size to camera zoom
    let size = 1.0 / camera_zoom(object)
    ignore(self._scale_matrix.make_scale(size, size, size))
    ignore(
      self._translation_matrix.make_translation(
        -tb_center.x,
        -tb_center.y,
        -tb_center.z,
      ),
    )
    ignore(
      self._gizmo_matrix_state
      .premultiply(self._translation_matrix)
      .premultiply(self._scale_matrix),
    )
    ignore(
      self._translation_matrix.make_translation(
        tb_center.x,
        tb_center.y,
        tb_center.z,
      ),
    )
    ignore(self._gizmo_matrix_state.premultiply(self._translation_matrix))
  }
  ignore(
    self._gizmo_matrix_state.decompose(
      self._gizmos.position,
      self._gizmos.quaternion,
      self._gizmos.scale,
    ),
  )
  //
  self._gizmos.traverse(fn(object) {
    if object.is_line() {
      geometry_of(object).dispose()
      material_of(object).dispose()
    }
  })
  ignore(self._gizmos.clear())
  //
  ignore(self._gizmos.add(gizmo_x))
  ignore(self._gizmos.add(gizmo_y))
  ignore(self._gizmos.add(gizmo_z))
}

///|
/// One frame of the focus animation.
pub fn ArcballControls::on_focus_anim(
  self : ArcballControls,
  time : Double,
  point : @math.Vector3,
  camera_matrix : @math.Matrix4,
  gizmo_matrix : @math.Matrix4,
) -> Unit {
  if self._time_start == -1.0 {
    //animation start
    self._time_start = time
  }
  if self._state == AnimationFocus {
    let delta_time = time - self._time_start
    let anim_time = delta_time / self.focus_animation_time
    ignore(self._gizmo_matrix_state.copy(gizmo_matrix))
    if anim_time >= 1.0 {
      //animation end
      ignore(
        self._gizmo_matrix_state.decompose(
          self._gizmos.position,
          self._gizmos.quaternion,
          self._gizmos.scale,
        ),
      )
      self.focus(point, self.scale_factor)
      self._time_start = -1.0
      self.update_tb_state(Idle, false)
      self.activate_gizmos(false)
      self.dispatch_event(_arcball_change_event)
    } else {
      let amount = self.ease_out_cubic(anim_time)
      let size = 1.0 - amount + self.scale_factor * amount
      ignore(
        self._gizmo_matrix_state.decompose(
          self._gizmos.position,
          self._gizmos.quaternion,
          self._gizmos.scale,
        ),
      )
      self.focus(point, size, amount~)
      self.dispatch_event(_arcball_change_event)
      self._animation_id = window_request_animation_frame(fn(t) {
        self.on_focus_anim(t, point, camera_matrix, gizmo_matrix.clone())
      })
    }
  } else {
    //interrupt animation
    self._animation_id = -1.0
    self._time_start = -1.0
  }
}

///|
/// One frame of the rotation animation.
pub fn ArcballControls::on_rotation_anim(
  self : ArcballControls,
  time : Double,
  rotation_axis : @math.Vector3,
  w0 : Double,
) -> Unit {
  if self._time_start == -1.0 {
    //animation start
    self._angle_prev = 0.0
    self._angle_current = 0.0
    self._time_start = time
  }
  if self._state == AnimationRotate {
    //w = w0 + alpha * t
    let delta_time = (time - self._time_start) / 1000.0
    let w = w0 + -self.damping_factor * delta_time
    if w > 0.0 {
      //tetha = 0.5 * alpha * t^2 + w0 * t + tetha0
      self._angle_current = 0.5 * -self.damping_factor * js_pow(delta_time, 2.0) +
        w0 * delta_time +
        0.0
      self.apply_transform_matrix(
        self.rotate(rotation_axis, self._angle_current),
      )
      self.dispatch_event(_arcball_change_event)
      self._animation_id = window_request_animation_frame(fn(t) {
        self.on_rotation_anim(t, rotation_axis, w0)
      })
    } else {
      self._animation_id = -1.0
      self._time_start = -1.0
      self.update_tb_state(Idle, false)
      self.activate_gizmos(false)
      self.dispatch_event(_arcball_change_event)
    }
  } else {
    //interrupt animation
    self._animation_id = -1.0
    self._time_start = -1.0
    if self._state != Rotate {
      self.activate_gizmos(false)
      self.dispatch_event(_arcball_change_event)
    }
  }
}

///|
/// The transformation of a pan from `p0` to `p1`.
pub fn ArcballControls::pan(
  self : ArcballControls,
  p0 : @math.Vector3,
  p1 : @math.Vector3,
  adjust~ : Bool = false,
) -> ArcballTransformation {
  let object = self.base.object
  let movement = p0.clone().sub(p1)
  if object.is_orthographic_camera() {
    //adjust movement amount
    ignore(movement.multiply_scalar(1.0 / camera_zoom(object)))
  } else if object.is_perspective_camera() && adjust {
    //adjust movement amount
    ignore(self._v3_1.set_from_matrix_position(self._camera_matrix_state0)) //camera's initial position
    ignore(self._v3_2.set_from_matrix_position(self._gizmo_matrix_state0)) //gizmo's initial position
    let distance_factor = self._v3_1.distance_to(self._v3_2) /
      object.position.distance_to(self._gizmos.position)
    ignore(movement.multiply_scalar(1.0 / distance_factor))
  }
  ignore(
    self._v3_1
    .set(movement.x, movement.y, 0.0)
    .apply_quaternion(object.quaternion),
  )
  ignore(self._m4_1.make_translation(self._v3_1.x, self._v3_1.y, self._v3_1.z))
  self.set_transformation_matrices(camera=self._m4_1, gizmos=self._m4_1)
  _arcball_transformation
}

///|
/// Resets the controls to the state of the last `save_state` or construction.
pub fn ArcballControls::reset(self : ArcballControls) -> Unit {
  let object = self.base.object
  ignore(self.target.copy(self._target0))
  set_camera_zoom(object, self._zoom0)
  if object.is_perspective_camera() {
    set_camera_fov(object, self._fov0)
  }
  set_camera_near(object, self._near_pos)
  set_camera_far(object, self._far_pos)
  ignore(self._camera_matrix_state.copy(self._camera_matrix_state0))
  ignore(
    self._camera_matrix_state.decompose(
      object.position,
      object.quaternion,
      object.scale,
    ),
  )
  ignore(object.up.copy(self._up0))
  object.update_matrix()
  object.update_projection_matrix()
  ignore(self._gizmo_matrix_state.copy(self._gizmo_matrix_state0))
  ignore(
    self._gizmo_matrix_state0.decompose(
      self._gizmos.position,
      self._gizmos.quaternion,
      self._gizmos.scale,
    ),
  )
  self._gizmos.update_matrix()
  self._tb_radius = self.calculate_tb_radius(object)
  self.make_gizmos(self._gizmos.position, self._tb_radius)
  object.look_at(self._gizmos.position)
  self.update_tb_state(Idle, false)
  self.dispatch_event(_arcball_change_event)
}

///|
/// The transformation of a rotation by `angle` around `axis`.
pub fn ArcballControls::rotate(
  self : ArcballControls,
  axis : @math.Vector3,
  angle : Double,
) -> ArcballTransformation {
  let point = self._gizmos.position //rotation center
  ignore(
    self._translation_matrix.make_translation(-point.x, -point.y, -point.z),
  )
  ignore(self._rotation_matrix.make_rotation_axis(axis, -angle))
  //rotate camera
  ignore(self._m4_1.make_translation(point.x, point.y, point.z))
  ignore(self._m4_1.multiply(self._rotation_matrix))
  ignore(self._m4_1.multiply(self._translation_matrix))
  self.set_transformation_matrices(camera=self._m4_1)
  _arcball_transformation
}

///|
extern "js" fn arcball_state_json(
  far : Double,
  fov : Double,
  has_fov : Bool,
  matrix : @core.JsValue,
  near : Double,
  up : @core.JsValue,
  zoom : Double,
  gizmo_matrix : @core.JsValue,
  target : @core.JsValue,
) -> String =
  #|(far, fov, hasFov, m, near, up, zoom, g, t) => JSON.stringify({ arcballState: hasFov
  #|  ? { cameraFar: far, cameraFov: fov, cameraMatrix: m, cameraNear: near, cameraUp: up, cameraZoom: zoom, gizmoMatrix: g, target: t }
  #|  : { cameraFar: far, cameraMatrix: m, cameraNear: near, cameraUp: up, cameraZoom: zoom, gizmoMatrix: g, target: t } })

///|
/// `{ elements: [ ... ] }`, as `JSON.stringify` writes a `Matrix4`.
extern "js" fn arcball_matrix_json(
  elements : FixedArray[Double],
) -> @core.JsValue = "(e) => ({ elements: Array.from(e) })"

///|
/// `{ x, y, z }`, as `JSON.stringify` writes a `Vector3`.
extern "js" fn arcball_vector_json(
  x : Double,
  y : Double,
  z : Double,
) -> @core.JsValue = "(x, y, z) => ({ x, y, z })"

///|
/// `JSON.stringify( undefined )`, which `copyState` writes for other cameras.
extern "js" fn js_undefined_string() -> String = "() => undefined"

///|
/// Copies the controls' state to the clipboard as JSON.
pub fn ArcballControls::copy_state(self : ArcballControls) -> Unit {
  let object = self.base.object
  let state = if object.is_orthographic_camera() ||
    object.is_perspective_camera() {
    arcball_state_json(
      camera_far(object),
      camera_fov(object),
      object.is_perspective_camera(),
      arcball_matrix_json(FixedArray::from_array(object.matrix.elements)),
      camera_near(object),
      arcball_vector_json(object.up.x, object.up.y, object.up.z),
      camera_zoom(object),
      arcball_matrix_json(FixedArray::from_array(self._gizmos.matrix.elements)),
      arcball_vector_json(self.target.x, self.target.y, self.target.z),
    )
  } else {
    js_undefined_string()
  }
  clipboard_write_text(state)
}

///|
/// Reads the state from the clipboard (see `copy_state`).
pub fn ArcballControls::paste_state(self : ArcballControls) -> Unit {
  clipboard_read_text(fn(value) { self.set_state_from_json(value) })
}

///|
/// Saves the current state; `reset` restores it.
pub fn ArcballControls::save_state(self : ArcballControls) -> Unit {
  let object = self.base.object
  object.update_matrix()
  self._gizmos.update_matrix()
  ignore(self._target0.copy(self.target))
  ignore(self._camera_matrix_state0.copy(object.matrix))
  ignore(self._gizmo_matrix_state0.copy(self._gizmos.matrix))
  self._near_pos = camera_near(object)
  self._far_pos = camera_far(object)
  self._zoom0 = camera_zoom(object)
  ignore(self._up0.copy(object.up))
  if object.is_perspective_camera() {
    self._fov0 = camera_fov(object)
  }
}

///|
/// The transformation of a zoom by `size` around `point`.
pub fn ArcballControls::scale(
  self : ArcballControls,
  size : Double,
  point : @math.Vector3,
  scale_gizmos~ : Bool = true,
) -> ArcballTransformation {
  let object = self.base.object
  ignore(_arcball_scale_point_temp.copy(point))
  let mut size_inverse = 1.0 / size
  if object.is_orthographic_camera() {
    //camera zoom
    set_camera_zoom(object, self._zoom_state)
    set_camera_zoom(object, camera_zoom(object) * size)
    //check min and max zoom
    if camera_zoom(object) > self.max_zoom {
      set_camera_zoom(object, self.max_zoom)
      size_inverse = self._zoom_state / self.max_zoom
    } else if camera_zoom(object) < self.min_zoom {
      set_camera_zoom(object, self.min_zoom)
      size_inverse = self._zoom_state / self.min_zoom
    }
    object.update_projection_matrix()
    ignore(self._v3_1.set_from_matrix_position(self._gizmo_matrix_state)) //gizmos position
    //scale gizmos so they appear in the same spot having the same dimension
    ignore(
      self._scale_matrix.make_scale(size_inverse, size_inverse, size_inverse),
    )
    ignore(
      self._translation_matrix.make_translation(
        -self._v3_1.x,
        -self._v3_1.y,
        -self._v3_1.z,
      ),
    )
    ignore(
      self._m4_2
      .make_translation(self._v3_1.x, self._v3_1.y, self._v3_1.z)
      .multiply(self._scale_matrix),
    )
    ignore(self._m4_2.multiply(self._translation_matrix))
    //move camera and gizmos to obtain pinch effect
    ignore(_arcball_scale_point_temp.sub(self._v3_1))
    let amount = _arcball_scale_point_temp.clone().multiply_scalar(size_inverse)
    ignore(_arcball_scale_point_temp.sub(amount))
    ignore(
      self._m4_1.make_translation(
        _arcball_scale_point_temp.x,
        _arcball_scale_point_temp.y,
        _arcball_scale_point_temp.z,
      ),
    )
    ignore(self._m4_2.premultiply(self._m4_1))
    self.set_transformation_matrices(camera=self._m4_1, gizmos=self._m4_2)
    _arcball_transformation
  } else if object.is_perspective_camera() {
    ignore(self._v3_1.set_from_matrix_position(self._camera_matrix_state))
    ignore(self._v3_2.set_from_matrix_position(self._gizmo_matrix_state))
    //move camera
    let mut distance = self._v3_1.distance_to(_arcball_scale_point_temp)
    let mut amount = distance - distance * size_inverse
    //check min and max distance
    let new_distance = distance - amount
    if new_distance < self.min_distance {
      size_inverse = self.min_distance / distance
      amount = distance - distance * size_inverse
    } else if new_distance > self.max_distance {
      size_inverse = self.max_distance / distance
      amount = distance - distance * size_inverse
    }
    ignore(
      _arcball_offset
      .copy(_arcball_scale_point_temp)
      .sub(self._v3_1)
      .normalize()
      .multiply_scalar(amount),
    )
    ignore(
      self._m4_1.make_translation(
        _arcball_offset.x,
        _arcball_offset.y,
        _arcball_offset.z,
      ),
    )
    if scale_gizmos {
      //scale gizmos so they appear in the same spot having the same dimension
      let pos = self._v3_2
      distance = pos.distance_to(_arcball_scale_point_temp)
      amount = distance - distance * size_inverse
      ignore(
        _arcball_offset
        .copy(_arcball_scale_point_temp)
        .sub(self._v3_2)
        .normalize()
        .multiply_scalar(amount),
      )
      ignore(self._translation_matrix.make_translation(pos.x, pos.y, pos.z))
      ignore(
        self._scale_matrix.make_scale(size_inverse, size_inverse, size_inverse),
      )
      ignore(
        self._m4_2
        .make_translation(
          _arcball_offset.x,
          _arcball_offset.y,
          _arcball_offset.z,
        )
        .multiply(self._translation_matrix),
      )
      ignore(self._m4_2.multiply(self._scale_matrix))
      ignore(self._translation_matrix.make_translation(-pos.x, -pos.y, -pos.z))
      ignore(self._m4_2.multiply(self._translation_matrix))
      self.set_transformation_matrices(camera=self._m4_1, gizmos=self._m4_2)
    } else {
      self.set_transformation_matrices(camera=self._m4_1)
    }
    _arcball_transformation
  } else {
    abort("ArcballControls: unsupported camera type")
  }
}

///|
/// Sets the perspective camera's FOV, clamped to `[min_fov, max_fov]`.
pub fn ArcballControls::set_fov(self : ArcballControls, value : Double) -> Unit {
  let object = self.base.object
  if object.is_perspective_camera() {
    set_camera_fov(object, @math.clamp(value, self.min_fov, self.max_fov))
    object.update_projection_matrix()
  }
}

///|
/// Stores the camera and gizmo matrices of the next transformation.
pub fn ArcballControls::set_transformation_matrices(
  self : ArcballControls,
  camera? : @math.Matrix4,
  gizmos? : @math.Matrix4,
) -> Unit {
  ignore(self)
  match camera {
    Some(camera) =>
      match _arcball_transformation.camera {
        Some(matrix) => ignore(matrix.copy(camera))
        None => _arcball_transformation.camera = Some(camera.clone())
      }
    None => _arcball_transformation.camera = None
  }
  match gizmos {
    Some(gizmos) =>
      match _arcball_transformation.gizmos {
        Some(matrix) => ignore(matrix.copy(gizmos))
        None => _arcball_transformation.gizmos = Some(gizmos.clone())
      }
    None => _arcball_transformation.gizmos = None
  }
}

///|
/// The transformation of a rotation by `angle` around the view axis through `point`.
pub fn ArcballControls::z_rotate(
  self : ArcballControls,
  point : @math.Vector3,
  angle : Double,
) -> ArcballTransformation {
  ignore(self._rotation_matrix.make_rotation_axis(self._rotation_axis, angle))
  ignore(
    self._translation_matrix.make_translation(-point.x, -point.y, -point.z),
  )
  ignore(self._m4_1.make_translation(point.x, point.y, point.z))
  ignore(self._m4_1.multiply(self._rotation_matrix))
  ignore(self._m4_1.multiply(self._translation_matrix))
  ignore(
    self._v3_1.set_from_matrix_position(self._gizmo_matrix_state).sub(point),
  ) //vector from rotation center to gizmos position
  ignore(
    self._v3_2.copy(self._v3_1).apply_axis_angle(self._rotation_axis, angle),
  ) //apply rotation
  ignore(self._v3_2.sub(self._v3_1))
  ignore(self._m4_2.make_translation(self._v3_2.x, self._v3_2.y, self._v3_2.z))
  self.set_transformation_matrices(camera=self._m4_1, gizmos=self._m4_2)
  _arcball_transformation
}

///|
/// The raycaster used for focusing (shared by every instance, as upstream).
pub fn ArcballControls::get_raycaster(
  self : ArcballControls,
) -> @core.Raycaster {
  ignore(self)
  _arcball_raycaster
}

///|
/// The first point of the scene under `cursor` (NDC), skipping the gizmos.
pub fn ArcballControls::unproject_on_obj(
  self : ArcballControls,
  cursor : @math.Vector2,
  camera : @core.Object3D,
) -> @math.Vector3? {
  let raycaster = self.get_raycaster()
  raycaster.near = camera_near(camera)
  raycaster.far = camera_far(camera)
  raycaster.set_from_camera(cursor, camera)
  let scene = match self.scene {
    Some(scene) => scene
    None => abort("ArcballControls: no scene")
  }
  let intersect = raycaster.intersect_objects(scene.children, recursive=true)
  for i in 0..<intersect.length() {
    if intersect[i].object.uuid != self._gizmos.uuid &&
      intersect[i].face is Some(_) {
      return Some(intersect[i].point.clone())
    }
  }
  None
}

///|
/// The cursor projected on the trackball surface, in camera space.
pub fn ArcballControls::unproject_on_tb_surface(
  self : ArcballControls,
  camera : @core.Object3D,
  cursor_x : Double,
  cursor_y : Double,
  canvas : @core.JsValue,
  tb_radius : Double,
) -> @math.Vector3 {
  if camera.type_ == "OrthographicCamera" {
    ignore(
      self._v2_1.copy(self.get_cursor_position(cursor_x, cursor_y, canvas)),
    )
    ignore(self._v3_1.set(self._v2_1.x, self._v2_1.y, 0.0))
    let x2 = js_pow(self._v2_1.x, 2.0)
    let y2 = js_pow(self._v2_1.y, 2.0)
    let r2 = js_pow(self._tb_radius, 2.0)
    if x2 + y2 <= r2 * 0.5 {
      //intersection with sphere
      ignore(self._v3_1.set_z(js_sqrt(r2 - (x2 + y2))))
    } else {
      //intersection with hyperboloid
      ignore(self._v3_1.set_z(r2 * 0.5 / js_sqrt(x2 + y2)))
    }
    self._v3_1
  } else if camera.type_ == "PerspectiveCamera" {
    //unproject cursor on the near plane
    ignore(self._v2_1.copy(self.get_cursor_ndc(cursor_x, cursor_y, canvas)))
    ignore(self._v3_1.set(self._v2_1.x, self._v2_1.y, -1.0))
    ignore(
      self._v3_1.apply_matrix4(camera.as_camera().projection_matrix_inverse),
    )
    let ray_dir = self._v3_1.clone().normalize() //unprojected ray direction
    let camera_gizmo_distance = camera.position.distance_to(
      self._gizmos.position,
    )
    let radius2 = js_pow(tb_radius, 2.0)
    let h = self._v3_1.z
    let l = js_sqrt(js_pow(self._v3_1.x, 2.0) + js_pow(self._v3_1.y, 2.0))
    if l == 0.0 {
      //ray aligned with camera
      ignore(ray_dir.set(self._v3_1.x, self._v3_1.y, tb_radius))
      return ray_dir
    }
    let m = h / l
    let q = camera_gizmo_distance
    // calculate intersection point between unprojected ray and trackball surface
    let mut a = js_pow(m, 2.0) + 1.0
    let mut b = 2.0 * m * q
    let mut c = js_pow(q, 2.0) - radius2
    let mut delta = js_pow(b, 2.0) - 4.0 * a * c
    if delta >= 0.0 {
      //intersection with sphere
      ignore(self._v2_1.set_x((-b - js_sqrt(delta)) / (2.0 * a)))
      ignore(self._v2_1.set_y(m * self._v2_1.x + q))
      let angle = @math.RAD2DEG * self._v2_1.angle()
      if angle >= 45.0 {
        //if angle between intersection point and X' axis is >= 45°, return that point
        //otherwise, calculate intersection point with hyperboloid
        let ray_length = js_sqrt(
          js_pow(self._v2_1.x, 2.0) +
          js_pow(camera_gizmo_distance - self._v2_1.y, 2.0),
        )
        ignore(ray_dir.multiply_scalar(ray_length))
        ray_dir.z += camera_gizmo_distance
        return ray_dir
      }
    }
    //intersection with hyperboloid
    a = m
    b = q
    c = -radius2 * 0.5
    delta = js_pow(b, 2.0) - 4.0 * a * c
    ignore(self._v2_1.set_x((-b - js_sqrt(delta)) / (2.0 * a)))
    ignore(self._v2_1.set_y(m * self._v2_1.x + q))
    let ray_length = js_sqrt(
      js_pow(self._v2_1.x, 2.0) +
      js_pow(camera_gizmo_distance - self._v2_1.y, 2.0),
    )
    ignore(ray_dir.multiply_scalar(ray_length))
    ray_dir.z += camera_gizmo_distance
    ray_dir
  } else {
    abort("ArcballControls: unsupported camera type")
  }
}

///|
/// The cursor projected on the plane through the gizmos facing the camera.
pub fn ArcballControls::unproject_on_tb_plane(
  self : ArcballControls,
  camera : @core.Object3D,
  cursor_x : Double,
  cursor_y : Double,
  canvas : @core.JsValue,
  initial_distance~ : Bool = false,
) -> @math.Vector3 {
  if camera.type_ == "OrthographicCamera" {
    ignore(
      self._v2_1.copy(self.get_cursor_position(cursor_x, cursor_y, canvas)),
    )
    ignore(self._v3_1.set(self._v2_1.x, self._v2_1.y, 0.0))
    self._v3_1.clone()
  } else if camera.type_ == "PerspectiveCamera" {
    ignore(self._v2_1.copy(self.get_cursor_ndc(cursor_x, cursor_y, canvas)))
    //unproject cursor on the near plane
    ignore(self._v3_1.set(self._v2_1.x, self._v2_1.y, -1.0))
    ignore(
      self._v3_1.apply_matrix4(camera.as_camera().projection_matrix_inverse),
    )
    let ray_dir = self._v3_1.clone().normalize() //unprojected ray direction
    let h = self._v3_1.z
    let l = js_sqrt(js_pow(self._v3_1.x, 2.0) + js_pow(self._v3_1.y, 2.0))
    let camera_gizmo_distance = if initial_distance {
      self._v3_1
      .set_from_matrix_position(self._camera_matrix_state0)
      .distance_to(
        self._v3_2.set_from_matrix_position(self._gizmo_matrix_state0),
      )
    } else {
      camera.position.distance_to(self._gizmos.position)
    }
    // calculate intersection point between unprojected ray and the plane
    if l == 0.0 {
      //ray aligned with camera
      ignore(ray_dir.set(0.0, 0.0, 0.0))
      return ray_dir
    }
    let m = h / l
    let q = camera_gizmo_distance
    let x = -q / m
    let ray_length = js_sqrt(js_pow(q, 2.0) + js_pow(x, 2.0))
    ignore(ray_dir.multiply_scalar(ray_length))
    ray_dir.z = 0.0
    ray_dir
  } else {
    abort("ArcballControls: unsupported camera type")
  }
}

///|
/// Updates the camera and gizmo state matrices.
pub fn ArcballControls::update_matrix_state(self : ArcballControls) -> Unit {
  let object = self.base.object
  //update camera and gizmos state
  ignore(self._camera_matrix_state.copy(object.matrix))
  ignore(self._gizmo_matrix_state.copy(self._gizmos.matrix))
  if object.is_orthographic_camera() {
    ignore(
      self._camera_projection_state.copy(object.as_camera().projection_matrix),
    )
    object.update_projection_matrix()
    self._zoom_state = camera_zoom(object)
  } else if object.is_perspective_camera() {
    self._fov_state = camera_fov(object)
  }
}

///|
/// Sets the trackball state, updating the state matrices if `update_matrices`.
pub fn ArcballControls::update_tb_state(
  self : ArcballControls,
  new_state : ArcballState,
  update_matrices : Bool,
) -> Unit {
  self._state = new_state
  if update_matrices {
    self.update_matrix_state()
  }
}

///|
/// Applies `target` and the min/max limits to the camera.
pub fn ArcballControls::update(self : ArcballControls) -> Unit {
  let object = self.base.object
  if !self.target.equals(self._current_target) {
    ignore(self._gizmos.position.copy(self.target)) //for correct radius calculation
    self._tb_radius = self.calculate_tb_radius(object)
    self.make_gizmos(self.target, self._tb_radius)
    ignore(self._current_target.copy(self.target))
  }
  //check min/max parameters
  if object.is_orthographic_camera() {
    //check zoom
    if camera_zoom(object) > self.max_zoom ||
      camera_zoom(object) < self.min_zoom {
      let new_zoom = @math.clamp(
        camera_zoom(object),
        self.min_zoom,
        self.max_zoom,
      )
      self.apply_transform_matrix(
        self.scale(
          new_zoom / camera_zoom(object),
          self._gizmos.position,
          scale_gizmos=true,
        ),
      )
    }
  } else if object.is_perspective_camera() {
    //check distance
    let distance = object.position.distance_to(self._gizmos.position)
    if distance > self.max_distance + _arcball_eps ||
      distance < self.min_distance - _arcball_eps {
      let new_distance = @math.clamp(
        distance,
        self.min_distance,
        self.max_distance,
      )
      self.apply_transform_matrix(
        self.scale(new_distance / distance, self._gizmos.position),
      )
      self.update_matrix_state()
    }
    //check fov
    if camera_fov(object) < self.min_fov || camera_fov(object) > self.max_fov {
      set_camera_fov(
        object,
        @math.clamp(camera_fov(object), self.min_fov, self.max_fov),
      )
      object.update_projection_matrix()
    }
    let old_radius = self._tb_radius
    self._tb_radius = self.calculate_tb_radius(object)
    if old_radius < self._tb_radius - _arcball_eps ||
      old_radius > self._tb_radius + _arcball_eps {
      let scale = (
          self._gizmos.scale.x + self._gizmos.scale.y + self._gizmos.scale.z
        ) /
        3.0
      let new_radius = self._tb_radius / scale
      self._set_curve_geometry(new_radius)
    }
  }
  object.look_at(self._gizmos.position)
}

///|
extern "js" fn js_json_parse(text : String) -> @core.JsValue = "(s) => JSON.parse(s)"

///|
extern "js" fn js_loose_not_undefined(value : @core.JsValue) -> Bool = "(v) => v != undefined"

///|
/// `array[ index ]` as a number.
extern "js" fn js_index_num(array : @core.JsValue, index : Int32) -> Double = "(a, i) => a[i]"

///|
fn js_number_array(value : @core.JsValue, length : Int32) -> Array[Double] {
  Array::makei(length, fn(i) { js_index_num(value, i) })
}

///|
/// Restores a state written by `copy_state`.
pub fn ArcballControls::set_state_from_json(
  self : ArcballControls,
  json : String,
) -> Unit {
  let state = js_json_parse(json)
  let arcball_state = state.get("arcballState")
  if js_loose_not_undefined(arcball_state) {
    let object = self.base.object
    ignore(
      self.target.from_array(js_number_array(arcball_state.get("target"), 3)),
    )
    ignore(
      self._camera_matrix_state.from_array(
        js_number_array(arcball_state.get("cameraMatrix").get("elements"), 16),
      ),
    )
    ignore(
      self._camera_matrix_state.decompose(
        object.position,
        object.quaternion,
        object.scale,
      ),
    )
    let up = arcball_state.get("cameraUp")
    ignore(object.up.set(ev_num(up, "x"), ev_num(up, "y"), ev_num(up, "z")))
    set_camera_near(object, ev_num(arcball_state, "cameraNear"))
    set_camera_far(object, ev_num(arcball_state, "cameraFar"))
    set_camera_zoom(object, ev_num(arcball_state, "cameraZoom"))
    if object.is_perspective_camera() {
      set_camera_fov(object, ev_num(arcball_state, "cameraFov"))
    }
    ignore(
      self._gizmo_matrix_state.from_array(
        js_number_array(arcball_state.get("gizmoMatrix").get("elements"), 16),
      ),
    )
    ignore(
      self._gizmo_matrix_state.decompose(
        self._gizmos.position,
        self._gizmos.quaternion,
        self._gizmos.scale,
      ),
    )
    object.update_matrix()
    object.update_projection_matrix()
    self._gizmos.update_matrix()
    self._tb_radius = self.calculate_tb_radius(object)
    let gizmo_tmp = @math.Matrix4::new().copy(self._gizmo_matrix_state0)
    self.make_gizmos(self._gizmos.position, self._tb_radius)
    ignore(self._gizmo_matrix_state0.copy(gizmo_tmp))
    object.look_at(self._gizmos.position)
    self.update_tb_state(Idle, false)
    self.dispatch_event(_arcball_change_event)
  }
}

//listeners

///|
fn ArcballControls::on_window_resize(self : ArcballControls) -> Unit {
  let scale = (
      self._gizmos.scale.x + self._gizmos.scale.y + self._gizmos.scale.z
    ) /
    3.0
  self._tb_radius = self.calculate_tb_radius(self.base.object)
  let new_radius = self._tb_radius / scale
  self._set_curve_geometry(new_radius)
  self.dispatch_event(_arcball_change_event)
}

///|
fn ArcballControls::on_context_menu(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  for action in self.mouse_actions {
    if action.mouse == Button(2) {
      //prevent only if button 2 is actually used
      prevent_default(event)
      break
    }
  }
}

///|
fn ArcballControls::on_pointer_cancel(self : ArcballControls) -> Unit {
  self._touch_start.clear()
  self._touch_current.clear()
  self._input = None
}

///|
fn arcball_modifier(event : @core.JsValue) -> String? {
  if ev_bool(event, "ctrlKey") || ev_bool(event, "metaKey") {
    Some("CTRL")
  } else if ev_bool(event, "shiftKey") {
    Some("SHIFT")
  } else {
    None
  }
}

///|
fn ArcballControls::on_pointer_down(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  let window = dom_window()
  if ev_num(event, "button") == 0.0 && ev_bool(event, "isPrimary") {
    self._down_valid = true
    self._down_events.push(event)
    self._down_start = performance_now()
  } else {
    self._down_valid = false
  }
  if ev_is(event, "pointerType", "touch") && self._input != Cursor {
    self._touch_start.push(event)
    self._touch_current.push(event)
    match self._input {
      None => {
        //singleStart
        self._input = OneFinger
        self.on_single_pan_start(event, "ROTATE")
        dom_add_event_listener(window, "pointermove", self._on_pointer_move)
        dom_add_event_listener(window, "pointerup", self._on_pointer_up)
      }
      OneFinger | OneFingerSwitched => {
        //doubleStart
        self._input = TwoFinger
        self.on_rotate_start()
        self.on_pinch_start()
        self.on_double_pan_start()
      }
      TwoFinger => {
        //multipleStart
        self._input = MultFinger
        self.on_triple_pan_start()
      }
      _ => ()
    }
  } else if !ev_is(event, "pointerType", "touch") && self._input == None {
    let modifier = arcball_modifier(event)
    self._mouse_op = self.get_op_from_action(
      arcball_button(ev_num(event, "button")),
      modifier,
    )
    if self._mouse_op is Some(mouse_op) {
      dom_add_event_listener(window, "pointermove", self._on_pointer_move)
      dom_add_event_listener(window, "pointerup", self._on_pointer_up)
      //singleStart
      self._input = Cursor
      self._button = ev_num(event, "button")
      self.on_single_pan_start(event, mouse_op)
    }
  }
}

///|
fn ArcballControls::_last_down_event(self : ArcballControls) -> @core.JsValue {
  match self._down_events.last() {
    Some(event) => event
    None => abort("ArcballControls: no pointerdown event")
  }
}

///|
fn ArcballControls::on_pointer_move(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  if ev_is(event, "pointerType", "touch") && self._input != Cursor {
    match self._input {
      OneFinger => {
        //singleMove
        self.update_touch_event(event)
        self.on_single_pan_move(event, Rotate)
      }
      OneFingerSwitched => {
        let movement = self.calculate_pointers_distance(
            self._touch_current[0],
            event,
          ) *
          self._dev_px_ratio
        if movement >= self._switch_sensibility {
          //singleMove
          self._input = OneFinger
          self.update_touch_event(event)
          self.on_single_pan_start(event, "ROTATE")
        }
      }
      TwoFinger => {
        //rotate/pan/pinchMove
        self.update_touch_event(event)
        self.on_rotate_move()
        self.on_pinch_move()
        self.on_double_pan_move()
      }
      MultFinger => {
        //multMove
        self.update_touch_event(event)
        self.on_triple_pan_move()
      }
      _ => ()
    }
  } else if !ev_is(event, "pointerType", "touch") && self._input == Cursor {
    let modifier = arcball_modifier(event)
    let mouse_op_state = self.get_op_state_from_action(
      arcball_button(self._button),
      modifier,
    )
    if mouse_op_state is Some(mouse_op_state) {
      self.on_single_pan_move(event, mouse_op_state)
    }
  }
  //checkDistance
  if self._down_valid {
    let movement = self.calculate_pointers_distance(
        self._last_down_event(),
        event,
      ) *
      self._dev_px_ratio
    if movement > self._movement_threshold {
      self._down_valid = false
    }
  }
}

///|
fn ArcballControls::on_pointer_up(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  let window = dom_window()
  if ev_is(event, "pointerType", "touch") && self._input != Cursor {
    let n_touch = self._touch_current.length()
    let pointer_id = ev_num(event, "pointerId")
    for i in 0..<n_touch {
      if ev_num(self._touch_current[i], "pointerId") == pointer_id {
        ignore(self._touch_current.remove(i))
        ignore(self._touch_start.remove(i))
        break
      }
    }
    match self._input {
      OneFinger | OneFingerSwitched => {
        //singleEnd
        dom_remove_event_listener(window, "pointermove", self._on_pointer_move)
        dom_remove_event_listener(window, "pointerup", self._on_pointer_up)
        self._input = None
        self.on_single_pan_end()
      }
      TwoFinger => {
        //doubleEnd
        self.on_double_pan_end()
        self.on_pinch_end()
        self.on_rotate_end()
        //switching to singleStart
        self._input = OneFingerSwitched
      }
      MultFinger =>
        if self._touch_current.length() == 0 {
          dom_remove_event_listener(
            window,
            "pointermove",
            self._on_pointer_move,
          )
          dom_remove_event_listener(window, "pointerup", self._on_pointer_up)
          //multCancel
          self._input = None
          self.on_triple_pan_end()
        }
      _ => ()
    }
  } else if !ev_is(event, "pointerType", "touch") && self._input == Cursor {
    dom_remove_event_listener(window, "pointermove", self._on_pointer_move)
    dom_remove_event_listener(window, "pointerup", self._on_pointer_up)
    self._input = None
    self.on_single_pan_end()
    self._button = -1.0
  }
  if ev_bool(event, "isPrimary") {
    if self._down_valid {
      let down_time = ev_num(event, "timeStamp") -
        ev_num(self._last_down_event(), "timeStamp")
      if down_time <= self._max_down_time {
        if self._nclicks == 0 {
          //first valid click detected
          self._nclicks = 1
          self._click_start = performance_now()
        } else {
          let click_interval = ev_num(event, "timeStamp") - self._click_start
          let movement = self.calculate_pointers_distance(
              self._down_events[1],
              self._down_events[0],
            ) *
            self._dev_px_ratio
          if click_interval <= self._max_interval &&
            movement <= self._pos_threshold {
            //second valid click detected
            //fire double tap and reset values
            self._nclicks = 0
            self._down_events.clear()
            self.on_double_tap(event)
          } else {
            //new 'first click'
            self._nclicks = 1
            ignore(self._down_events.remove(0))
            self._click_start = performance_now()
          }
        }
      } else {
        self._down_valid = false
        self._nclicks = 0
        self._down_events.clear()
      }
    } else {
      self._nclicks = 0
      self._down_events.clear()
    }
  }
}

///|
fn ArcballControls::on_wheel(
  self : ArcballControls,
  event : @core.JsValue,
) -> Unit {
  if self.base.enabled && self.enable_zoom {
    let modifier = arcball_modifier(event)
    let mouse_op = self.get_op_from_action(Some(Wheel), modifier)
    if mouse_op is Some(mouse_op) {
      prevent_default(event)
      self.dispatch_event(_arcball_start_event)
      let notch_delta_y = 125.0 //distance of one notch of mouse wheel
      let mut sgn = ev_num(event, "deltaY") / notch_delta_y
      let mut size = 1.0
      if sgn > 0.0 {
        size = 1.0 / self.scale_factor
      } else if sgn < 0.0 {
        size = self.scale_factor
      }
      let object = self.base.object
      match mouse_op {
        "ZOOM" => {
          self.update_tb_state(Scale, true)
          if sgn > 0.0 {
            size = 1.0 / js_pow(self.scale_factor, sgn)
          } else if sgn < 0.0 {
            size = js_pow(self.scale_factor, -sgn)
          }
          if self.cursor_zoom && self.enable_pan {
            let element = dom_element_of(self.base)
            let scale_point = if object.is_orthographic_camera() {
              self
              .unproject_on_tb_plane(
                object,
                ev_num(event, "clientX"),
                ev_num(event, "clientY"),
                element,
              )
              .apply_quaternion(object.quaternion)
              .multiply_scalar(1.0 / camera_zoom(object))
              .add(self._gizmos.position)
            } else if object.is_perspective_camera() {
              self
              .unproject_on_tb_plane(
                object,
                ev_num(event, "clientX"),
                ev_num(event, "clientY"),
                element,
              )
              .apply_quaternion(object.quaternion)
              .add(self._gizmos.position)
            } else {
              abort("ArcballControls: unsupported camera type")
            }
            self.apply_transform_matrix(self.scale(size, scale_point))
          } else {
            self.apply_transform_matrix(self.scale(size, self._gizmos.position))
          }
          if self._grid is Some(_) {
            self.dispose_grid()
            self.draw_grid()
          }
          self.update_tb_state(Idle, false)
          self.dispatch_event(_arcball_change_event)
          self.dispatch_event(_arcball_end_event)
        }
        "FOV" => {
          if object.is_perspective_camera() {
            self.update_tb_state(Fov, true)
            //Vertigo effect
            //check for iOs shift shortcut
            if ev_num(event, "deltaX") != 0.0 {
              sgn = ev_num(event, "deltaX") / notch_delta_y
              size = 1.0
              if sgn > 0.0 {
                size = 1.0 / js_pow(self.scale_factor, sgn)
              } else if sgn < 0.0 {
                size = js_pow(self.scale_factor, -sgn)
              }
            }
            ignore(
              self._v3_1.set_from_matrix_position(self._camera_matrix_state),
            )
            let x = self._v3_1.distance_to(self._gizmos.position)
            let mut x_new = x / size //distance between camera and gizmos if scale(size, scalepoint) would be performed
            //check min and max distance
            x_new = @math.clamp(x_new, self.min_distance, self.max_distance)
            let y = x * js_tan(@math.DEG2RAD * camera_fov(object) * 0.5)
            //calculate new fov
            let mut new_fov = @math.RAD2DEG * (js_atan(y / x_new) * 2.0)
            //check min and max fov
            if new_fov > self.max_fov {
              new_fov = self.max_fov
            } else if new_fov < self.min_fov {
              new_fov = self.min_fov
            }
            let new_distance = y / js_tan(@math.DEG2RAD * (new_fov / 2.0))
            size = x / new_distance
            self.set_fov(new_fov)
            self.apply_transform_matrix(
              self.scale(size, self._gizmos.position, scale_gizmos=false),
            )
          }
          if self._grid is Some(_) {
            self.dispose_grid()
            self.draw_grid()
          }
          self.update_tb_state(Idle, false)
          self.dispatch_event(_arcball_change_event)
          self.dispatch_event(_arcball_end_event)
        }
        _ => ()
      }
    }
  }
}
