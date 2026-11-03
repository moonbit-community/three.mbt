// Upstream examples/jsm/controls/TransformControls.js. Upstream defines most
// properties with `Object.defineProperty`: setting one copies it to the gizmo and the
// plane and fires `<name>-changed` (value in `event.data`) and `change`. Here they are
// read-only fields with `set_<name>` setters that do the same; `mouseDown` / `mouseUp`
// carry the mode in `event.data`.

///|
let _transform_raycaster : @core.Raycaster = @core.Raycaster::new()

///|
let _transform_temp_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _transform_temp_vector2 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _transform_temp_quaternion : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _transform_unit_x : @math.Vector3 = @math.Vector3::new(1.0, 0.0, 0.0)

///|
let _transform_unit_y : @math.Vector3 = @math.Vector3::new(0.0, 1.0, 0.0)

///|
let _transform_unit_z : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 1.0)

///|
/// Upstream `_unit[ axis ]`.
fn transform_unit(axis : String) -> @math.Vector3 {
  match axis {
    "X" => _transform_unit_x
    "Y" => _transform_unit_y
    "Z" => _transform_unit_z
    _ => abort("TransformControls: no unit vector for \{axis}")
  }
}

///|
let _transform_change_event : @core.Event = @core.Event::new("change")

///|
let _transform_object_change_event : @core.Event = @core.Event::new(
  "objectChange",
)

///|
fn transform_same_object(a : @core.Object3D?, b : @core.Object3D?) -> Bool {
  match (a, b) {
    (Some(a), Some(b)) => physical_equal(a, b)
    (None, None) => true
    _ => false
  }
}

///|
/// The pointer upstream's `getPointer` returns: NDC coordinates and the button.
pub(all) struct TransformControlsPointer {
  x : Double
  y : Double
  button : Double
}

///|
/// Translates, rotates and scales an object with a gizmo, like a 3D editor.
pub struct TransformControls {
  base : @extras.Controls
  _root : @core.Object3D
  _gizmo : @core.Object3D
  _plane : @core.Object3D
  _gizmo_state : TransformControlsState
  _plane_state : TransformControlsState
  mut camera : @core.Object3D
  mut object : @core.Object3D?
  mut enabled : Bool
  mut axis : String?
  mut mode : String
  mut translation_snap : Double?
  mut rotation_snap : Double?
  mut scale_snap : Double?
  mut space : String
  mut size : Double
  mut dragging : Bool
  mut show_x : Bool
  mut show_y : Bool
  mut show_z : Bool
  mut show_xy : Bool
  mut show_yz : Bool
  mut show_xz : Bool
  mut show_xyze : Bool
  mut show_e : Bool
  mut min_x : Double
  mut max_x : Double
  mut min_y : Double
  mut max_y : Double
  mut min_z : Double
  mut max_z : Double
  mut world_position : @math.Vector3
  mut world_position_start : @math.Vector3
  mut world_quaternion : @math.Quaternion
  mut world_quaternion_start : @math.Quaternion
  mut camera_position : @math.Vector3
  mut camera_quaternion : @math.Quaternion
  mut point_start : @math.Vector3
  mut point_end : @math.Vector3
  mut rotation_axis : @math.Vector3
  mut rotation_angle : Double
  mut eye : @math.Vector3
  /// The viewport `( x, y, width, height )` the pointer is mapped through, or `None`
  /// for the whole element.
  mut viewport : @math.Vector4?
  _offset : @math.Vector3
  _start_norm : @math.Vector3
  _end_norm : @math.Vector3
  _camera_scale : @math.Vector3
  _parent_position : @math.Vector3
  _parent_quaternion : @math.Quaternion
  _parent_quaternion_inv : @math.Quaternion
  _parent_scale : @math.Vector3
  _world_scale_start : @math.Vector3
  _world_quaternion_inv : @math.Quaternion
  _world_scale : @math.Vector3
  _position_start : @math.Vector3
  _quaternion_start : @math.Quaternion
  _scale_start : @math.Vector3
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_hover : (@core.JsValue) -> Unit
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_up : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for TransformControls with fn event_dispatcher(self) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for TransformControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend TransformControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for TransformControls with fn connect(
  self,
  _,
  _,
) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for TransformControls with fn disconnect(
  self,
  _,
) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for TransformControls with fn dispose(
  self,
  _,
) {
  self.dispose()
}

///|
/// The defaults of every passed-down property, with fresh vectors.
fn TransformControlsState::new(
  camera : @core.Object3D?,
) -> TransformControlsState {
  {
    camera,
    object: None,
    enabled: true,
    axis: None,
    mode: "translate",
    translation_snap: None,
    rotation_snap: None,
    scale_snap: None,
    space: "world",
    size: 1.0,
    dragging: false,
    show_x: true,
    show_y: true,
    show_z: true,
    show_xy: true,
    show_yz: true,
    show_xz: true,
    show_xyze: true,
    show_e: true,
    min_x: @double.neg_infinity,
    max_x: @double.infinity,
    min_y: @double.neg_infinity,
    max_y: @double.infinity,
    min_z: @double.neg_infinity,
    max_z: @double.infinity,
    world_position: @math.Vector3::new(0.0, 0.0, 0.0),
    world_position_start: @math.Vector3::new(0.0, 0.0, 0.0),
    world_quaternion: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    world_quaternion_start: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    camera_position: @math.Vector3::new(0.0, 0.0, 0.0),
    camera_quaternion: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    point_start: @math.Vector3::new(0.0, 0.0, 0.0),
    point_end: @math.Vector3::new(0.0, 0.0, 0.0),
    rotation_axis: @math.Vector3::new(0.0, 0.0, 0.0),
    rotation_angle: 0.0,
    eye: @math.Vector3::new(0.0, 0.0, 0.0),
  }
}

///|
/// `new TransformControls( camera, domElement )`. `base.object` holds the camera, as
/// the base type cannot be empty; the attached object is `object`.
pub fn TransformControls::new(
  camera : @core.Object3D,
  dom_element? : @core.JsValue,
) -> TransformControls {
  let base = @extras.Controls::new(camera, dom_element?)
  let root = @core.Object3D::new()
  root.visible = false
  let gizmo = TransformControlsGizmo::new()
  ignore(root.add(gizmo))
  let plane = TransformControlsPlane::new()
  ignore(root.add(plane))
  let gizmo_state = TransformControlsGizmo::of(gizmo).unwrap().state
  let plane_state = TransformControlsPlane::of(plane).unwrap().state
  let defaults = TransformControlsState::new(Some(camera))
  let self : TransformControls = {
    base,
    _root: root,
    _gizmo: gizmo,
    _plane: plane,
    _gizmo_state: gizmo_state,
    _plane_state: plane_state,
    camera,
    object: None,
    enabled: true,
    axis: None,
    mode: "translate",
    translation_snap: None,
    rotation_snap: None,
    scale_snap: None,
    space: "world",
    size: 1.0,
    dragging: false,
    show_x: true,
    show_y: true,
    show_z: true,
    show_xy: true,
    show_yz: true,
    show_xz: true,
    show_xyze: true,
    show_e: true,
    min_x: defaults.min_x,
    max_x: defaults.max_x,
    min_y: defaults.min_y,
    max_y: defaults.max_y,
    min_z: defaults.min_z,
    max_z: defaults.max_z,
    world_position: defaults.world_position,
    world_position_start: defaults.world_position_start,
    world_quaternion: defaults.world_quaternion,
    world_quaternion_start: defaults.world_quaternion_start,
    camera_position: defaults.camera_position,
    camera_quaternion: defaults.camera_quaternion,
    point_start: defaults.point_start,
    point_end: defaults.point_end,
    rotation_axis: defaults.rotation_axis,
    rotation_angle: 0.0,
    eye: defaults.eye,
    viewport: None,
    _offset: @math.Vector3::new(0.0, 0.0, 0.0),
    _start_norm: @math.Vector3::new(0.0, 0.0, 0.0),
    _end_norm: @math.Vector3::new(0.0, 0.0, 0.0),
    _camera_scale: @math.Vector3::new(0.0, 0.0, 0.0),
    _parent_position: @math.Vector3::new(0.0, 0.0, 0.0),
    _parent_quaternion: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _parent_quaternion_inv: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _parent_scale: @math.Vector3::new(0.0, 0.0, 0.0),
    _world_scale_start: @math.Vector3::new(0.0, 0.0, 0.0),
    _world_quaternion_inv: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _world_scale: @math.Vector3::new(0.0, 0.0, 0.0),
    _position_start: @math.Vector3::new(0.0, 0.0, 0.0),
    _quaternion_start: @math.Quaternion::new(0.0, 0.0, 0.0, 1.0),
    _scale_start: @math.Vector3::new(0.0, 0.0, 0.0),
    _on_pointer_down: noop_listener,
    _on_pointer_hover: noop_listener,
    _on_pointer_move: noop_listener,
    _on_pointer_up: noop_listener,
  }
  self._copy_props_to(plane_state)
  self._copy_props_to(gizmo_state)
  ignore(root.set_extension(TransformControlsRoot::{ controls: self, }))
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
  self._on_pointer_hover = fn(event) { self.on_pointer_hover(event) }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_up = fn(event) { self.on_pointer_up(event) }
  base.extension = Some(self)
  if dom_element is Some(element) {
    self.connect(element)
  }
  self
}

///|
/// Connects the controls to the DOM element.
pub fn TransformControls::connect(
  self : TransformControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn TransformControls::connect_listeners(self : TransformControls) -> Unit {
  let element = dom_element_of(self.base)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "pointermove", self._on_pointer_hover)
  dom_add_event_listener(element, "pointerup", self._on_pointer_up)
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn TransformControls::disconnect(self : TransformControls) -> Unit {
  let element = dom_element_of(self.base)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(element, "pointermove", self._on_pointer_hover)
  dom_remove_event_listener(element, "pointermove", self._on_pointer_move)
  dom_remove_event_listener(element, "pointerup", self._on_pointer_up)
  dom_set_style(element, "touchAction", "")
}

///|
/// The visual representation of the controls; add it to the scene.
pub fn TransformControls::get_helper(
  self : TransformControls,
) -> @core.Object3D {
  self._root
}

///|
fn TransformControls::_set_from_pointer(
  self : TransformControls,
  pointer : TransformControlsPointer?,
) -> Unit {
  if pointer is Some(pointer) {
    _transform_raycaster.set_from_camera(
      @math.Vector2::new(pointer.x, pointer.y),
      self.camera,
    )
  }
}

///|
/// Picks the axis under `pointer` (`None` reuses the raycaster's current ray).
pub fn TransformControls::pointer_hover(
  self : TransformControls,
  pointer : TransformControlsPointer?,
) -> Unit {
  if self.object is None || self.dragging {
    return
  }
  self._set_from_pointer(pointer)
  let picker = transform_lookup(
    TransformControlsGizmo::of(self._gizmo).unwrap().picker,
    self.mode,
  )
  match
    transform_intersect_object_with_ray(picker, _transform_raycaster, false) {
    Some(intersect) => self.set_axis(Some(intersect.object.name))
    None => self.set_axis(None)
  }
}

///|
/// Starts a drag on the current axis.
pub fn TransformControls::pointer_down(
  self : TransformControls,
  pointer : TransformControlsPointer?,
) -> Unit {
  guard self.object is Some(object) else { return }
  if self.dragging || (pointer is Some(p) && p.button != 0.0) {
    return
  }
  if self.axis is Some(_) {
    self._set_from_pointer(pointer)
    let plane_intersect = transform_intersect_object_with_ray(
      self._plane,
      _transform_raycaster,
      true,
    )
    if plane_intersect is Some(plane_intersect) {
      object.update_matrix_world()
      transform_parent_of(object).update_matrix_world()
      ignore(self._position_start.copy(object.position))
      ignore(self._quaternion_start.copy(object.quaternion))
      ignore(self._scale_start.copy(object.scale))
      ignore(
        object.matrix_world.decompose(
          self.world_position_start,
          self.world_quaternion_start,
          self._world_scale_start,
        ),
      )
      ignore(
        self.point_start
        .copy(plane_intersect.point)
        .sub(self.world_position_start),
      )
    }
    self.set_dragging(true)
    self.dispatch_event(
      @core.Event::new("mouseDown", data=@core.JsValue::of(self.mode)),
    )
  }
}

///|
fn transform_parent_of(object : @core.Object3D) -> @core.Object3D {
  match object.parent {
    Some(parent) => parent
    None => abort("TransformControls: the object has no parent")
  }
}

///|
fn transform_round_snap(value : Double, snap : Double) -> Double {
  js_round(value / snap) * snap
}

///|
/// Applies the drag to the object.
pub fn TransformControls::pointer_move(
  self : TransformControls,
  pointer : TransformControlsPointer?,
) -> Unit {
  let axis = self.axis
  let mode = self.mode
  let object = self.object
  let mut space = self.space
  if mode == "scale" {
    space = "local"
  } else if axis == Some("E") || axis == Some("XYZE") || axis == Some("XYZ") {
    space = "world"
  }
  guard object is Some(object) else { return }
  guard axis is Some(axis) else { return }
  if !self.dragging || (pointer is Some(p) && p.button != -1.0) {
    return
  }
  self._set_from_pointer(pointer)
  guard transform_intersect_object_with_ray(
      self._plane,
      _transform_raycaster,
      true,
    )
    is Some(plane_intersect) else {
    return
  }
  ignore(
    self.point_end.copy(plane_intersect.point).sub(self.world_position_start),
  )
  if mode == "translate" {
    // Apply translate
    ignore(self._offset.copy(self.point_end).sub(self.point_start))
    if space == "local" && axis != "XYZ" {
      ignore(self._offset.apply_quaternion(self._world_quaternion_inv))
    }
    if !axis.contains("X") {
      self._offset.x = 0.0
    }
    if !axis.contains("Y") {
      self._offset.y = 0.0
    }
    if !axis.contains("Z") {
      self._offset.z = 0.0
    }
    if space == "local" && axis != "XYZ" {
      ignore(
        self._offset
        .apply_quaternion(self._quaternion_start)
        .divide(self._parent_scale),
      )
    } else {
      ignore(
        self._offset
        .apply_quaternion(self._parent_quaternion_inv)
        .divide(self._parent_scale),
      )
    }
    ignore(object.position.copy(self._offset).add(self._position_start))
    // Apply translation snap
    if self.translation_snap is Some(snap) && js_number_truthy(snap) {
      if space == "local" {
        ignore(
          object.position.apply_quaternion(
            _transform_temp_quaternion.copy(self._quaternion_start).invert(),
          ),
        )
        if axis.contains("X") {
          object.position.x = transform_round_snap(object.position.x, snap)
        }
        if axis.contains("Y") {
          object.position.y = transform_round_snap(object.position.y, snap)
        }
        if axis.contains("Z") {
          object.position.z = transform_round_snap(object.position.z, snap)
        }
        ignore(object.position.apply_quaternion(self._quaternion_start))
      }
      if space == "world" {
        ignore(object.get_world_position(_transform_temp_vector))
        if axis.contains("X") {
          _transform_temp_vector.x = transform_round_snap(
            _transform_temp_vector.x,
            snap,
          )
        }
        if axis.contains("Y") {
          _transform_temp_vector.y = transform_round_snap(
            _transform_temp_vector.y,
            snap,
          )
        }
        if axis.contains("Z") {
          _transform_temp_vector.z = transform_round_snap(
            _transform_temp_vector.z,
            snap,
          )
        }
        ignore(
          object.position.copy(
            transform_parent_of(object).world_to_local(_transform_temp_vector),
          ),
        )
      }
    }
    object.position.x = js_max(
      self.min_x,
      js_min(self.max_x, object.position.x),
    )
    object.position.y = js_max(
      self.min_y,
      js_min(self.max_y, object.position.y),
    )
    object.position.z = js_max(
      self.min_z,
      js_min(self.max_z, object.position.z),
    )
  } else if mode == "scale" {
    if axis.contains("XYZ") {
      let mut d = self.point_end.length() / self.point_start.length()
      if self.point_end.dot(self.point_start) < 0.0 {
        d *= -1.0
      }
      ignore(_transform_temp_vector2.set(d, d, d))
    } else {
      ignore(_transform_temp_vector.copy(self.point_start))
      ignore(_transform_temp_vector2.copy(self.point_end))
      ignore(
        _transform_temp_vector.apply_quaternion(self._world_quaternion_inv),
      )
      ignore(
        _transform_temp_vector2.apply_quaternion(self._world_quaternion_inv),
      )
      ignore(_transform_temp_vector2.divide(_transform_temp_vector))
      if !axis.contains("X") {
        _transform_temp_vector2.x = 1.0
      }
      if !axis.contains("Y") {
        _transform_temp_vector2.y = 1.0
      }
      if !axis.contains("Z") {
        _transform_temp_vector2.z = 1.0
      }
    }
    // Apply scale
    ignore(
      object.scale.copy(self._scale_start).multiply(_transform_temp_vector2),
    )
    if self.scale_snap is Some(snap) && js_number_truthy(snap) {
      let snapped = fn(value : Double) {
        let v = transform_round_snap(value, snap)
        if js_number_truthy(v) {
          v
        } else {
          snap
        }
      }
      if axis.contains("X") {
        object.scale.x = snapped(object.scale.x)
      }
      if axis.contains("Y") {
        object.scale.y = snapped(object.scale.y)
      }
      if axis.contains("Z") {
        object.scale.z = snapped(object.scale.z)
      }
    }
  } else if mode == "rotate" {
    ignore(self._offset.copy(self.point_end).sub(self.point_start))
    let rotation_speed = 20.0 /
      self.world_position.distance_to(
        _transform_temp_vector.set_from_matrix_position(
          self.camera.matrix_world,
        ),
      )
    let mut in_plane_rotation = false
    if axis == "XYZE" {
      ignore(self.rotation_axis.copy(self._offset).cross(self.eye).normalize())
      self.set_rotation_angle(
        self._offset.dot(
          _transform_temp_vector.copy(self.rotation_axis).cross(self.eye),
        ) *
        rotation_speed,
      )
    } else if axis == "X" || axis == "Y" || axis == "Z" {
      ignore(self.rotation_axis.copy(transform_unit(axis)))
      ignore(_transform_temp_vector.copy(transform_unit(axis)))
      if space == "local" {
        ignore(_transform_temp_vector.apply_quaternion(self.world_quaternion))
      }
      ignore(_transform_temp_vector.cross(self.eye))
      // When _tempVector is 0 after cross with this.eye the vectors are parallel and should use in-plane rotation logic.
      if _transform_temp_vector.length() == 0.0 {
        in_plane_rotation = true
      } else {
        self.set_rotation_angle(
          self._offset.dot(_transform_temp_vector.normalize()) * rotation_speed,
        )
      }
    }
    if axis == "E" || in_plane_rotation {
      ignore(self.rotation_axis.copy(self.eye))
      self.set_rotation_angle(self.point_end.angle_to(self.point_start))
      ignore(self._start_norm.copy(self.point_start).normalize())
      ignore(self._end_norm.copy(self.point_end).normalize())
      self.set_rotation_angle(
        self.rotation_angle *
        (if self._end_norm.cross(self._start_norm).dot(self.eye) < 0.0 {
          1.0
        } else {
          -1.0
        }),
      )
    }
    // Apply rotation snap
    if self.rotation_snap is Some(snap) && js_number_truthy(snap) {
      self.set_rotation_angle(transform_round_snap(self.rotation_angle, snap))
    }
    // Apply rotate
    if space == "local" && axis != "E" && axis != "XYZE" {
      ignore(object.quaternion.copy(self._quaternion_start))
      ignore(
        object.quaternion
        .multiply(
          _transform_temp_quaternion.set_from_axis_angle(
            self.rotation_axis,
            self.rotation_angle,
          ),
        )
        .normalize(),
      )
    } else {
      ignore(self.rotation_axis.apply_quaternion(self._parent_quaternion_inv))
      ignore(
        object.quaternion.copy(
          _transform_temp_quaternion.set_from_axis_angle(
            self.rotation_axis,
            self.rotation_angle,
          ),
        ),
      )
      ignore(object.quaternion.multiply(self._quaternion_start).normalize())
    }
  }
  self.dispatch_event(_transform_change_event)
  self.dispatch_event(_transform_object_change_event)
}

///|
/// Ends the drag.
pub fn TransformControls::pointer_up(
  self : TransformControls,
  pointer : TransformControlsPointer?,
) -> Unit {
  if pointer is Some(p) && p.button != 0.0 {
    return
  }
  if self.dragging && self.axis is Some(_) {
    self.dispatch_event(
      @core.Event::new("mouseUp", data=@core.JsValue::of(self.mode)),
    )
  }
  self.set_dragging(false)
  self.set_axis(None)
}

///|
/// Removes the listeners and disposes the gizmo's geometries and materials.
pub fn TransformControls::dispose(self : TransformControls) -> Unit {
  self.disconnect()
  self._root.dispose()
}

///|
/// Attaches the controls to `object`, which must be part of the scene graph.
pub fn TransformControls::attach(
  self : TransformControls,
  object : @core.Object3D,
) -> TransformControls {
  self.set_object(Some(object))
  self._root.visible = true
  self
}

///|
/// Detaches the controls from the object.
pub fn TransformControls::detach(self : TransformControls) -> TransformControls {
  self.set_object(None)
  self.set_axis(None)
  self._root.visible = false
  self
}

///|
/// Resets the object to its transform before the current drag.
pub fn TransformControls::reset(self : TransformControls) -> Unit {
  if !self.enabled {
    return
  }
  if self.dragging {
    guard self.object is Some(object) else {
      abort("TransformControls: no object")
    }
    ignore(object.position.copy(self._position_start))
    ignore(object.quaternion.copy(self._quaternion_start))
    ignore(object.scale.copy(self._scale_start))
    self.dispatch_event(_transform_change_event)
    self.dispatch_event(_transform_object_change_event)
    ignore(self.point_start.copy(self.point_end))
  }
}

///|
/// The raycaster used for picking (shared by every instance, as upstream).
pub fn TransformControls::get_raycaster(
  self : TransformControls,
) -> @core.Raycaster {
  ignore(self)
  _transform_raycaster
}

///|
/// The transformation mode.
pub fn TransformControls::get_mode(self : TransformControls) -> String {
  self.mode
}

///|
/// `controls.viewport = viewport`.
pub fn TransformControls::set_viewport(
  self : TransformControls,
  viewport : @math.Vector4?,
) -> Unit {
  self.viewport = viewport
}

///|
/// Sets the axis colors and the highlight color of the gizmo.
pub fn TransformControls::set_colors(
  self : TransformControls,
  x_axis : @math.Color,
  y_axis : @math.Color,
  z_axis : @math.Color,
  active : @math.Color,
) -> Unit {
  let gizmo = TransformControlsGizmo::of(self._gizmo).unwrap()
  let lib = gizmo.material_lib
  ignore(color_of(lib.x_axis).copy(x_axis))
  ignore(color_of(lib.y_axis).copy(y_axis))
  ignore(color_of(lib.z_axis).copy(z_axis))
  ignore(color_of(lib.active).copy(active))
  ignore(color_of(lib.x_axis_transparent).copy(x_axis))
  ignore(color_of(lib.y_axis_transparent).copy(y_axis))
  ignore(color_of(lib.z_axis_transparent).copy(z_axis))
  ignore(color_of(lib.active_transparent).copy(active))
  // update color caches
  for
    pair in [
      (lib.x_axis, x_axis),
      (lib.y_axis, y_axis),
      (lib.z_axis, z_axis),
      (lib.active, active),
      (lib.x_axis_transparent, x_axis),
      (lib.y_axis_transparent, y_axis),
      (lib.z_axis_transparent, z_axis),
      (lib.active_transparent, active),
    ] {
    if gizmo._material_colors.get(pair.0.id) is Some(cached) {
      ignore(cached.copy(pair.1))
    }
  }
}

///|
/// `setColors` with hex colors.
pub fn TransformControls::set_colors_hex(
  self : TransformControls,
  x_axis : Int32,
  y_axis : Int32,
  z_axis : Int32,
  active : Int32,
) -> Unit {
  self.set_colors(
    @math.Color::from_hex(x_axis),
    @math.Color::from_hex(y_axis),
    @math.Color::from_hex(z_axis),
    @math.Color::from_hex(active),
  )
}

// mouse / touch event handlers

///|
fn TransformControls::_get_pointer(
  self : TransformControls,
  event : @core.JsValue,
) -> TransformControlsPointer {
  let element = dom_element_of(self.base)
  if @webgl.js_truthy(dom_owner_document(element).get("pointerLockElement")) {
    { x: 0.0, y: 0.0, button: ev_num(event, "button"), }
  } else {
    let rect = dom_get_bounding_client_rect(element)
    let (origin_x, origin_y, region_width, region_height) = match
      self.viewport {
      Some(viewport) =>
        (
          viewport.x,
          ev_num(rect, "height") - viewport.y - viewport.w,
          viewport.z,
          viewport.w,
        )
      None => (0.0, 0.0, ev_num(rect, "width"), ev_num(rect, "height"))
    }
    {
      x: (ev_num(event, "clientX") - ev_num(rect, "left") - origin_x) /
      region_width *
      2.0 -
      1.0,
      y: -(ev_num(event, "clientY") - ev_num(rect, "top") - origin_y) /
      region_height *
      2.0 +
      1.0,
      button: ev_num(event, "button"),
    }
  }
}

///|
fn TransformControls::on_pointer_hover(
  self : TransformControls,
  event : @core.JsValue,
) -> Unit {
  if !self.enabled {
    return
  }
  if ev_is(event, "pointerType", "mouse") || ev_is(event, "pointerType", "pen") {
    self.pointer_hover(Some(self._get_pointer(event)))
  }
}

///|
fn TransformControls::on_pointer_down(
  self : TransformControls,
  event : @core.JsValue,
) -> Unit {
  if !self.enabled {
    return
  }
  let element = dom_element_of(self.base)
  if !@webgl.js_truthy(dom_document().get("pointerLockElement")) {
    dom_set_pointer_capture(element, ev_num(event, "pointerId"))
  }
  dom_add_event_listener(element, "pointermove", self._on_pointer_move)
  self.pointer_hover(Some(self._get_pointer(event)))
  self.pointer_down(Some(self._get_pointer(event)))
}

///|
fn TransformControls::on_pointer_move(
  self : TransformControls,
  event : @core.JsValue,
) -> Unit {
  if !self.enabled {
    return
  }
  self.pointer_move(Some(self._get_pointer(event)))
}

///|
fn TransformControls::on_pointer_up(
  self : TransformControls,
  event : @core.JsValue,
) -> Unit {
  if !self.enabled {
    return
  }
  let element = dom_element_of(self.base)
  dom_release_pointer_capture(element, ev_num(event, "pointerId"))
  dom_remove_event_listener(element, "pointermove", self._on_pointer_move)
  self.pointer_up(Some(self._get_pointer(event)))
}

///|
fn transform_intersect_object_with_ray(
  object : @core.Object3D,
  raycaster : @core.Raycaster,
  include_invisible : Bool,
) -> @core.Intersection? {
  let all_intersections = raycaster.intersect_object(object, recursive=true)
  for intersection in all_intersections {
    if intersection.object.visible || include_invisible {
      return Some(intersection)
    }
  }
  None
}

///|
fn transform_lookup(
  map : Map[String, @core.Object3D],
  mode : String,
) -> @core.Object3D {
  match map.get(mode) {
    Some(object) => object
    None => abort("TransformControls: unknown mode \{mode}")
  }
}

///|
/// The properties `TransformControls` passes down to its gizmo and plane (upstream's
/// `defineProperty`); `camera` is `None` for a gizmo or plane made on its own.
pub(all) struct TransformControlsState {
  mut camera : @core.Object3D?
  mut object : @core.Object3D?
  mut enabled : Bool
  mut axis : String?
  mut mode : String
  mut translation_snap : Double?
  mut rotation_snap : Double?
  mut scale_snap : Double?
  mut space : String
  mut size : Double
  mut dragging : Bool
  mut show_x : Bool
  mut show_y : Bool
  mut show_z : Bool
  mut show_xy : Bool
  mut show_yz : Bool
  mut show_xz : Bool
  mut show_xyze : Bool
  mut show_e : Bool
  mut min_x : Double
  mut max_x : Double
  mut min_y : Double
  mut max_y : Double
  mut min_z : Double
  mut max_z : Double
  mut world_position : @math.Vector3
  mut world_position_start : @math.Vector3
  mut world_quaternion : @math.Quaternion
  mut world_quaternion_start : @math.Quaternion
  mut camera_position : @math.Vector3
  mut camera_quaternion : @math.Quaternion
  mut point_start : @math.Vector3
  mut point_end : @math.Vector3
  mut rotation_axis : @math.Vector3
  mut rotation_angle : Double
  mut eye : @math.Vector3
}

///|
/// `plane[ propName ] = value; gizmo[ propName ] = value` for every property.
fn TransformControls::_copy_props_to(
  self : TransformControls,
  state : TransformControlsState,
) -> Unit {
  state.camera = Some(self.camera)
  state.object = self.object
  state.enabled = self.enabled
  state.axis = self.axis
  state.mode = self.mode
  state.translation_snap = self.translation_snap
  state.rotation_snap = self.rotation_snap
  state.scale_snap = self.scale_snap
  state.space = self.space
  state.size = self.size
  state.dragging = self.dragging
  state.show_x = self.show_x
  state.show_y = self.show_y
  state.show_z = self.show_z
  state.show_xy = self.show_xy
  state.show_yz = self.show_yz
  state.show_xz = self.show_xz
  state.show_xyze = self.show_xyze
  state.show_e = self.show_e
  state.min_x = self.min_x
  state.max_x = self.max_x
  state.min_y = self.min_y
  state.max_y = self.max_y
  state.min_z = self.min_z
  state.max_z = self.max_z
  state.world_position = self.world_position
  state.world_position_start = self.world_position_start
  state.world_quaternion = self.world_quaternion
  state.world_quaternion_start = self.world_quaternion_start
  state.camera_position = self.camera_position
  state.camera_quaternion = self.camera_quaternion
  state.point_start = self.point_start
  state.point_end = self.point_end
  state.rotation_axis = self.rotation_axis
  state.rotation_angle = self.rotation_angle
  state.eye = self.eye
}

///|
/// `controls.camera = value`; fires `camera-changed` and `change` when it changes.
pub fn TransformControls::set_camera(
  self : TransformControls,
  value : @core.Object3D,
) -> Unit {
  if !physical_equal(self.camera, value) {
    self.camera = value
    self._plane_state.camera = Some(value)
    self._gizmo_state.camera = Some(value)
    self.dispatch_event(
      @core.Event::new("camera-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.object = value`; fires `object-changed` and `change` when it changes.
pub fn TransformControls::set_object(
  self : TransformControls,
  value : @core.Object3D?,
) -> Unit {
  if !transform_same_object(self.object, value) {
    self.object = value
    self._plane_state.object = value
    self._gizmo_state.object = value
    self.dispatch_event(
      @core.Event::new(
        "object-changed",
        data=match value {
          Some(v) => @core.JsValue::of(v)
          None => @core.JsValue::undefined()
        },
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.enabled = value`; fires `enabled-changed` and `change` when it changes.
pub fn TransformControls::set_enabled(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.enabled != value {
    self.enabled = value
    self.base.enabled = value
    self._plane_state.enabled = value
    self._gizmo_state.enabled = value
    self.dispatch_event(
      @core.Event::new("enabled-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.axis = value`; fires `axis-changed` and `change` when it changes.
pub fn TransformControls::set_axis(
  self : TransformControls,
  value : String?,
) -> Unit {
  if self.axis != value {
    self.axis = value
    self._plane_state.axis = value
    self._gizmo_state.axis = value
    self.dispatch_event(
      @core.Event::new(
        "axis-changed",
        data=match value {
          Some(v) => @core.JsValue::of(v)
          None => @core.JsValue::null()
        },
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `setMode( mode )`: `"translate"`, `"rotate"` or `"scale"`.
pub fn TransformControls::set_mode(
  self : TransformControls,
  value : String,
) -> Unit {
  if self.mode != value {
    self.mode = value
    self._plane_state.mode = value
    self._gizmo_state.mode = value
    self.dispatch_event(
      @core.Event::new("mode-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `setTranslationSnap( snap )`.
pub fn TransformControls::set_translation_snap(
  self : TransformControls,
  value : Double?,
) -> Unit {
  if self.translation_snap != value {
    self.translation_snap = value
    self._plane_state.translation_snap = value
    self._gizmo_state.translation_snap = value
    self.dispatch_event(
      @core.Event::new(
        "translationSnap-changed",
        data=match value {
          Some(v) => @core.JsValue::of(v)
          None => @core.JsValue::null()
        },
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `setRotationSnap( snap )`.
pub fn TransformControls::set_rotation_snap(
  self : TransformControls,
  value : Double?,
) -> Unit {
  if self.rotation_snap != value {
    self.rotation_snap = value
    self._plane_state.rotation_snap = value
    self._gizmo_state.rotation_snap = value
    self.dispatch_event(
      @core.Event::new(
        "rotationSnap-changed",
        data=match value {
          Some(v) => @core.JsValue::of(v)
          None => @core.JsValue::null()
        },
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `setScaleSnap( snap )`.
pub fn TransformControls::set_scale_snap(
  self : TransformControls,
  value : Double?,
) -> Unit {
  if self.scale_snap != value {
    self.scale_snap = value
    self._plane_state.scale_snap = value
    self._gizmo_state.scale_snap = value
    self.dispatch_event(
      @core.Event::new(
        "scaleSnap-changed",
        data=match value {
          Some(v) => @core.JsValue::of(v)
          None => @core.JsValue::null()
        },
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `setSpace( space )`: `"world"` or `"local"`.
pub fn TransformControls::set_space(
  self : TransformControls,
  value : String,
) -> Unit {
  if self.space != value {
    self.space = value
    self._plane_state.space = value
    self._gizmo_state.space = value
    self.dispatch_event(
      @core.Event::new("space-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `setSize( size )`.
pub fn TransformControls::set_size(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.size != value {
    self.size = value
    self._plane_state.size = value
    self._gizmo_state.size = value
    self.dispatch_event(
      @core.Event::new("size-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.dragging = value`; fires `dragging-changed` and `change` when it changes.
pub fn TransformControls::set_dragging(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.dragging != value {
    self.dragging = value
    self._plane_state.dragging = value
    self._gizmo_state.dragging = value
    self.dispatch_event(
      @core.Event::new("dragging-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showX = value`; fires `showX-changed` and `change` when it changes.
pub fn TransformControls::set_show_x(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_x != value {
    self.show_x = value
    self._plane_state.show_x = value
    self._gizmo_state.show_x = value
    self.dispatch_event(
      @core.Event::new("showX-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showY = value`; fires `showY-changed` and `change` when it changes.
pub fn TransformControls::set_show_y(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_y != value {
    self.show_y = value
    self._plane_state.show_y = value
    self._gizmo_state.show_y = value
    self.dispatch_event(
      @core.Event::new("showY-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showZ = value`; fires `showZ-changed` and `change` when it changes.
pub fn TransformControls::set_show_z(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_z != value {
    self.show_z = value
    self._plane_state.show_z = value
    self._gizmo_state.show_z = value
    self.dispatch_event(
      @core.Event::new("showZ-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showXY = value`; fires `showXY-changed` and `change` when it changes.
pub fn TransformControls::set_show_xy(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_xy != value {
    self.show_xy = value
    self._plane_state.show_xy = value
    self._gizmo_state.show_xy = value
    self.dispatch_event(
      @core.Event::new("showXY-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showYZ = value`; fires `showYZ-changed` and `change` when it changes.
pub fn TransformControls::set_show_yz(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_yz != value {
    self.show_yz = value
    self._plane_state.show_yz = value
    self._gizmo_state.show_yz = value
    self.dispatch_event(
      @core.Event::new("showYZ-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showXZ = value`; fires `showXZ-changed` and `change` when it changes.
pub fn TransformControls::set_show_xz(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_xz != value {
    self.show_xz = value
    self._plane_state.show_xz = value
    self._gizmo_state.show_xz = value
    self.dispatch_event(
      @core.Event::new("showXZ-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showXYZE = value`; fires `showXYZE-changed` and `change` when it changes.
pub fn TransformControls::set_show_xyze(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_xyze != value {
    self.show_xyze = value
    self._plane_state.show_xyze = value
    self._gizmo_state.show_xyze = value
    self.dispatch_event(
      @core.Event::new("showXYZE-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.showE = value`; fires `showE-changed` and `change` when it changes.
pub fn TransformControls::set_show_e(
  self : TransformControls,
  value : Bool,
) -> Unit {
  if self.show_e != value {
    self.show_e = value
    self._plane_state.show_e = value
    self._gizmo_state.show_e = value
    self.dispatch_event(
      @core.Event::new("showE-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.minX = value`; fires `minX-changed` and `change` when it changes.
pub fn TransformControls::set_min_x(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.min_x != value {
    self.min_x = value
    self._plane_state.min_x = value
    self._gizmo_state.min_x = value
    self.dispatch_event(
      @core.Event::new("minX-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.maxX = value`; fires `maxX-changed` and `change` when it changes.
pub fn TransformControls::set_max_x(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.max_x != value {
    self.max_x = value
    self._plane_state.max_x = value
    self._gizmo_state.max_x = value
    self.dispatch_event(
      @core.Event::new("maxX-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.minY = value`; fires `minY-changed` and `change` when it changes.
pub fn TransformControls::set_min_y(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.min_y != value {
    self.min_y = value
    self._plane_state.min_y = value
    self._gizmo_state.min_y = value
    self.dispatch_event(
      @core.Event::new("minY-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.maxY = value`; fires `maxY-changed` and `change` when it changes.
pub fn TransformControls::set_max_y(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.max_y != value {
    self.max_y = value
    self._plane_state.max_y = value
    self._gizmo_state.max_y = value
    self.dispatch_event(
      @core.Event::new("maxY-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.minZ = value`; fires `minZ-changed` and `change` when it changes.
pub fn TransformControls::set_min_z(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.min_z != value {
    self.min_z = value
    self._plane_state.min_z = value
    self._gizmo_state.min_z = value
    self.dispatch_event(
      @core.Event::new("minZ-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.maxZ = value`; fires `maxZ-changed` and `change` when it changes.
pub fn TransformControls::set_max_z(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.max_z != value {
    self.max_z = value
    self._plane_state.max_z = value
    self._gizmo_state.max_z = value
    self.dispatch_event(
      @core.Event::new("maxZ-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.worldPosition = value`; fires `worldPosition-changed` and `change` when it changes.
pub fn TransformControls::set_world_position(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.world_position, value) {
    self.world_position = value
    self._plane_state.world_position = value
    self._gizmo_state.world_position = value
    self.dispatch_event(
      @core.Event::new("worldPosition-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.worldPositionStart = value`; fires `worldPositionStart-changed` and `change` when it changes.
pub fn TransformControls::set_world_position_start(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.world_position_start, value) {
    self.world_position_start = value
    self._plane_state.world_position_start = value
    self._gizmo_state.world_position_start = value
    self.dispatch_event(
      @core.Event::new(
        "worldPositionStart-changed",
        data=@core.JsValue::of(value),
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.worldQuaternion = value`; fires `worldQuaternion-changed` and `change` when it changes.
pub fn TransformControls::set_world_quaternion(
  self : TransformControls,
  value : @math.Quaternion,
) -> Unit {
  if !physical_equal(self.world_quaternion, value) {
    self.world_quaternion = value
    self._plane_state.world_quaternion = value
    self._gizmo_state.world_quaternion = value
    self.dispatch_event(
      @core.Event::new("worldQuaternion-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.worldQuaternionStart = value`; fires `worldQuaternionStart-changed` and `change` when it changes.
pub fn TransformControls::set_world_quaternion_start(
  self : TransformControls,
  value : @math.Quaternion,
) -> Unit {
  if !physical_equal(self.world_quaternion_start, value) {
    self.world_quaternion_start = value
    self._plane_state.world_quaternion_start = value
    self._gizmo_state.world_quaternion_start = value
    self.dispatch_event(
      @core.Event::new(
        "worldQuaternionStart-changed",
        data=@core.JsValue::of(value),
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.cameraPosition = value`; fires `cameraPosition-changed` and `change` when it changes.
pub fn TransformControls::set_camera_position(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.camera_position, value) {
    self.camera_position = value
    self._plane_state.camera_position = value
    self._gizmo_state.camera_position = value
    self.dispatch_event(
      @core.Event::new("cameraPosition-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.cameraQuaternion = value`; fires `cameraQuaternion-changed` and `change` when it changes.
pub fn TransformControls::set_camera_quaternion(
  self : TransformControls,
  value : @math.Quaternion,
) -> Unit {
  if !physical_equal(self.camera_quaternion, value) {
    self.camera_quaternion = value
    self._plane_state.camera_quaternion = value
    self._gizmo_state.camera_quaternion = value
    self.dispatch_event(
      @core.Event::new(
        "cameraQuaternion-changed",
        data=@core.JsValue::of(value),
      ),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.pointStart = value`; fires `pointStart-changed` and `change` when it changes.
pub fn TransformControls::set_point_start(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.point_start, value) {
    self.point_start = value
    self._plane_state.point_start = value
    self._gizmo_state.point_start = value
    self.dispatch_event(
      @core.Event::new("pointStart-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.pointEnd = value`; fires `pointEnd-changed` and `change` when it changes.
pub fn TransformControls::set_point_end(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.point_end, value) {
    self.point_end = value
    self._plane_state.point_end = value
    self._gizmo_state.point_end = value
    self.dispatch_event(
      @core.Event::new("pointEnd-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.rotationAxis = value`; fires `rotationAxis-changed` and `change` when it changes.
pub fn TransformControls::set_rotation_axis(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.rotation_axis, value) {
    self.rotation_axis = value
    self._plane_state.rotation_axis = value
    self._gizmo_state.rotation_axis = value
    self.dispatch_event(
      @core.Event::new("rotationAxis-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.rotationAngle = value`; fires `rotationAngle-changed` and `change` when it changes.
pub fn TransformControls::set_rotation_angle(
  self : TransformControls,
  value : Double,
) -> Unit {
  if self.rotation_angle != value {
    self.rotation_angle = value
    self._plane_state.rotation_angle = value
    self._gizmo_state.rotation_angle = value
    self.dispatch_event(
      @core.Event::new("rotationAngle-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

///|
/// `controls.eye = value`; fires `eye-changed` and `change` when it changes.
pub fn TransformControls::set_eye(
  self : TransformControls,
  value : @math.Vector3,
) -> Unit {
  if !physical_equal(self.eye, value) {
    self.eye = value
    self._plane_state.eye = value
    self._gizmo_state.eye = value
    self.dispatch_event(
      @core.Event::new("eye-changed", data=@core.JsValue::of(value)),
    )
    self.dispatch_event(_transform_change_event)
  }
}

// Reusable utility variables

///|
let _transform_temp_euler : @math.Euler = @math.Euler::new(0.0, 0.0, 0.0)

///|
let _transform_align_vector : @math.Vector3 = @math.Vector3::new(0.0, 1.0, 0.0)

///|
let _transform_zero_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _transform_look_at_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _transform_temp_quaternion2 : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _transform_identity_quaternion : @math.Quaternion = @math.Quaternion::new(
  0.0, 0.0, 0.0, 1.0,
)

///|
let _transform_dir_vector : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _transform_temp_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _transform_v1 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _transform_v2 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _transform_v3 : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// Upstream `TransformControlsRoot`, the object `get_helper` returns. Its
/// `updateMatrixWorld` updates the controls' world transforms and keeps the gizmo
/// world-aligned.
priv struct TransformControlsRoot {
  controls : TransformControls
}

///|
impl @core.Object3DExtension for TransformControlsRoot with fn type_name(_) {
  "Object3D"
}

///|
impl @core.Object3DExtension for TransformControlsRoot with fn construct(self) {
  let root = @core.Object3D::new()
  root.visible = false
  ignore(
    root.set_extension(TransformControlsRoot::{ controls: self.controls, }),
  )
  root
}

///|
impl @core.Object3DExtension for TransformControlsRoot with fn has_flag(_, flag) {
  flag == "isTransformControlsRoot"
}

///|
// updateMatrixWorld updates key transformation variables
impl @core.Object3DExtension for TransformControlsRoot with fn update_matrix_world(
  self,
  root,
  force,
) {
  let controls = self.controls
  if controls.object is Some(object) {
    object.update_matrix_world()
    match object.parent {
      None =>
        println(
          "TransformControls: The attached 3D object must be a part of the scene graph.",
        )
      Some(parent) =>
        ignore(
          parent.matrix_world.decompose(
            controls._parent_position,
            controls._parent_quaternion,
            controls._parent_scale,
          ),
        )
    }
    ignore(
      object.matrix_world.decompose(
        controls.world_position,
        controls.world_quaternion,
        controls._world_scale,
      ),
    )
    ignore(
      controls._parent_quaternion_inv.copy(controls._parent_quaternion).invert(),
    )
    ignore(
      controls._world_quaternion_inv.copy(controls.world_quaternion).invert(),
    )
  }
  controls.camera.update_matrix_world()
  ignore(
    controls.camera.matrix_world.decompose(
      controls.camera_position,
      controls.camera_quaternion,
      controls._camera_scale,
    ),
  )
  if controls.camera.is_orthographic_camera() {
    ignore(controls.camera.get_world_direction(controls.eye).negate())
  } else {
    ignore(
      controls.eye
      .copy(controls.camera_position)
      .sub(controls.world_position)
      .normalize(),
    )
  }
  // Cancel out the parent's transform so the gizmo stays world-aligned.
  if root.parent is Some(parent) {
    ignore(_transform_temp_matrix.copy(parent.matrix_world).invert())
    ignore(
      _transform_temp_matrix.decompose(
        root.position,
        root.quaternion,
        root.scale,
      ),
    )
  }
  root.update_matrix_world_kind(force)
}

///|
impl @core.Object3DExtension for TransformControlsRoot with fn dispose(_, root) {
  root.traverse(fn(child) {
    if child.get_geometry() is Some(geometry) {
      geometry.dispose()
    }
    match child.get_material() {
      Some(Single(material)) => material.dispose()
      Some(Multiple(materials)) =>
        for material in materials {
          material.dispose()
        }
      None => ()
    }
  })
}

///|
/// The materials `set_colors` changes.
pub(all) struct TransformControlsMaterialLib {
  x_axis : @core.Material
  y_axis : @core.Material
  z_axis : @core.Material
  active : @core.Material
  x_axis_transparent : @core.Material
  y_axis_transparent : @core.Material
  z_axis_transparent : @core.Material
  active_transparent : @core.Material
}

///|
/// The handles of `TransformControls`: one group per mode in `gizmo`, `picker` and
/// `helper`. The payload of the `Object3D` `TransformControlsGizmo::new` returns.
pub(all) struct TransformControlsGizmo {
  state : TransformControlsState
  material_lib : TransformControlsMaterialLib
  gizmo : Map[String, @core.Object3D]
  picker : Map[String, @core.Object3D]
  helper : Map[String, @core.Object3D]
  /// Upstream's ad hoc `object.tag`, by object id.
  _tags : Map[Int32, String]
  /// Upstream's ad hoc `material._color`, by material id.
  _material_colors : Map[Int32, @math.Color]
  /// Upstream's ad hoc `material._opacity`, by material id.
  _material_opacities : Map[Int32, Double]
}

///|
pub impl @core.Object3DExtension for TransformControlsGizmo with fn type_name(_) {
  "TransformControlsGizmo"
}

///|
pub impl @core.Object3DExtension for TransformControlsGizmo with fn construct(_) {
  TransformControlsGizmo::new()
}

///|
pub impl @core.Object3DExtension for TransformControlsGizmo with fn has_flag(
  _,
  flag,
) {
  flag == "isTransformControlsGizmo"
}

///|
pub impl @core.Object3DExtension for TransformControlsGizmo with fn update_matrix_world(
  self,
  object,
  force,
) {
  self.update_handles()
  object.update_matrix_world_kind(force)
}

///|
#deprecated
pub extend TransformControlsGizmo with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// The `TransformControlsGizmo` payload of `object`, if it is one.
pub fn TransformControlsGizmo::of(
  object : @core.Object3D,
) -> TransformControlsGizmo? {
  match object.extension {
    Some(extension) if extension.has_flag("isTransformControlsGizmo") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
fn transform_gizmo_material() -> @core.Material {
  let material = @core.MeshBasicMaterial::new()
  material.depth_test = false
  material.depth_write = false
  material.fog = Some(false)
  material.tone_mapped = false
  material.transparent = true
  material
}

///|
fn transform_gizmo_line_material() -> @core.Material {
  let material = @core.LineBasicMaterial::new()
  material.depth_test = false
  material.depth_write = false
  material.fog = Some(false)
  material.tone_mapped = false
  material.transparent = true
  material
}

///|
fn transform_material_clone(
  material : @core.Material,
  hex? : Int32,
  opacity? : Double,
) -> @core.Material {
  let material = material.clone()
  if hex is Some(hex) {
    ignore(color_of(material).set_hex(hex))
  }
  if opacity is Some(opacity) {
    material.opacity = opacity
  }
  material
}

///|
/// One entry of upstream's gizmo maps: `[ object, position, rotation, scale, tag ]`.
priv struct TransformHandleDef {
  object : @core.Object3D
  position : (Double, Double, Double)?
  rotation : (Double, Double, Double)?
  scale : (Double, Double, Double)?
  tag : String?
}

///|
fn handle_def(
  object : @core.Object3D,
  position? : (Double, Double, Double),
  rotation? : (Double, Double, Double),
  scale? : (Double, Double, Double),
  tag? : String,
) -> TransformHandleDef {
  { object, position, rotation, scale, tag, }
}

///|
fn transform_mesh(
  geometry : @core.BufferGeometry,
  material : @core.Material,
) -> @core.Object3D {
  @core.Mesh::new(geometry~, material=Single(material))
}

///|
fn transform_line(
  geometry : @core.BufferGeometry,
  material : @core.Material,
) -> @core.Object3D {
  @core.Line::new(geometry~, material=Single(material))
}

///|
fn transform_circle_geometry(
  radius : Double,
  arc : Double,
) -> @core.BufferGeometry {
  let geometry = @geometries.TorusGeometry::new(
    radius~,
    tube=0.0075,
    radial_segments=3.0,
    tubular_segments=64.0,
    arc=arc * js_pi * 2.0,
  )
  ignore(geometry.rotate_y(js_pi / 2.0))
  ignore(geometry.rotate_x(js_pi / 2.0))
  geometry
}

///|
/// Special geometry for transform helper. If scaled with position vector it spans from [0,0,0] to position
fn transform_translate_helper_geometry() -> @core.BufferGeometry {
  let geometry = @core.BufferGeometry::new()
  ignore(
    geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([0.0, 0.0, 0.0, 1.0, 1.0, 1.0], 3),
    ),
  )
  geometry
}

///|
fn transform_cylinder(
  radius_top : Double,
  radius_bottom : Double,
  height : Double,
  radial_segments : Double,
) -> @core.BufferGeometry {
  @geometries.CylinderGeometry::new(
    radius_top~,
    radius_bottom~,
    height~,
    radial_segments~,
  )
}

///|
fn transform_box(
  width : Double,
  height : Double,
  depth : Double,
) -> @core.BufferGeometry {
  @geometries.BoxGeometry::new(width~, height~, depth~)
}

///|
/// `new TransformControlsGizmo()`.
pub fn TransformControlsGizmo::new() -> @core.Object3D {
  let object = @core.Object3D::new(type_="TransformControlsGizmo")
  // shared materials
  let gizmo_material = transform_gizmo_material()
  let gizmo_line_material = transform_gizmo_line_material()
  // Make unique material for each axis/color
  let mat_invisible = transform_material_clone(gizmo_material, opacity=0.15)
  let mat_helper = transform_material_clone(gizmo_line_material, opacity=0.5)
  let mat_red = transform_material_clone(gizmo_material, hex=0xff0000)
  let mat_green = transform_material_clone(gizmo_material, hex=0x00ff00)
  let mat_blue = transform_material_clone(gizmo_material, hex=0x0000ff)
  let mat_red_transparent = transform_material_clone(
    gizmo_material,
    hex=0xff0000,
    opacity=0.5,
  )
  let mat_green_transparent = transform_material_clone(
    gizmo_material,
    hex=0x00ff00,
    opacity=0.5,
  )
  let mat_blue_transparent = transform_material_clone(
    gizmo_material,
    hex=0x0000ff,
    opacity=0.5,
  )
  let mat_white_transparent = transform_material_clone(
    gizmo_material,
    opacity=0.25,
  )
  let mat_yellow_transparent = transform_material_clone(
    gizmo_material,
    hex=0xffff00,
    opacity=0.25,
  )
  let mat_yellow = transform_material_clone(gizmo_material, hex=0xffff00)
  let mat_gray = transform_material_clone(gizmo_material, hex=0x787878)
  // materials in the below property are configurable via setColors()
  let material_lib : TransformControlsMaterialLib = {
    x_axis: mat_red,
    y_axis: mat_green,
    z_axis: mat_blue,
    active: mat_yellow,
    x_axis_transparent: mat_red_transparent,
    y_axis_transparent: mat_green_transparent,
    z_axis_transparent: mat_blue_transparent,
    active_transparent: mat_yellow_transparent,
  }
  // reusable geometry
  let arrow_geometry = transform_cylinder(0.0, 0.04, 0.1, 12.0)
  ignore(arrow_geometry.translate(0.0, 0.05, 0.0))
  let scale_handle_geometry = transform_box(0.08, 0.08, 0.08)
  ignore(scale_handle_geometry.translate(0.0, 0.04, 0.0))
  let line_geometry = @core.BufferGeometry::new()
  ignore(
    line_geometry.set_attribute(
      "position",
      @core.Float32BufferAttribute::new([0.0, 0.0, 0.0, 1.0, 0.0, 0.0], 3),
    ),
  )
  let line_geometry2 = transform_cylinder(0.0075, 0.0075, 0.5, 3.0)
  ignore(line_geometry2.translate(0.0, 0.25, 0.0))
  let pi = js_pi
  // Gizmo definitions - custom hierarchy definitions for setupGizmo() function
  let gizmo_translate = [
    (
      "X",
      [
        handle_def(
          transform_mesh(arrow_geometry, mat_red),
          position=(0.5, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
        handle_def(
          transform_mesh(arrow_geometry, mat_red),
          position=(-0.5, 0.0, 0.0),
          rotation=(0.0, 0.0, pi / 2.0),
        ),
        handle_def(
          transform_mesh(line_geometry2, mat_red),
          position=(0.0, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_mesh(arrow_geometry, mat_green),
          position=(0.0, 0.5, 0.0),
        ),
        handle_def(
          transform_mesh(arrow_geometry, mat_green),
          position=(0.0, -0.5, 0.0),
          rotation=(pi, 0.0, 0.0),
        ),
        handle_def(transform_mesh(line_geometry2, mat_green)),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_mesh(arrow_geometry, mat_blue),
          position=(0.0, 0.0, 0.5),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
        handle_def(
          transform_mesh(arrow_geometry, mat_blue),
          position=(0.0, 0.0, -0.5),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
        handle_def(
          transform_mesh(line_geometry2, mat_blue),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XYZ",
      [
        handle_def(
          transform_mesh(
            @geometries.OctahedronGeometry::new(radius=0.1, detail=0.0),
            mat_white_transparent,
          ),
          position=(0.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XY",
      [
        handle_def(
          transform_mesh(transform_box(0.15, 0.15, 0.01), mat_blue_transparent),
          position=(0.15, 0.15, 0.0),
        ),
      ],
    ),
    (
      "YZ",
      [
        handle_def(
          transform_mesh(transform_box(0.15, 0.15, 0.01), mat_red_transparent),
          position=(0.0, 0.15, 0.15),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
    (
      "XZ",
      [
        handle_def(
          transform_mesh(transform_box(0.15, 0.15, 0.01), mat_green_transparent),
          position=(0.15, 0.0, 0.15),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
  ]
  let picker_translate = [
    (
      "X",
      [
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.3, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(-0.3, 0.0, 0.0),
          rotation=(0.0, 0.0, pi / 2.0),
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, 0.3, 0.0),
        ),
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, -0.3, 0.0),
          rotation=(0.0, 0.0, pi),
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, 0.0, 0.3),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, 0.0, -0.3),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XYZ",
      [
        handle_def(
          transform_mesh(
            @geometries.OctahedronGeometry::new(radius=0.2, detail=0.0),
            mat_invisible,
          ),
        ),
      ],
    ),
    (
      "XY",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.01), mat_invisible),
          position=(0.15, 0.15, 0.0),
        ),
      ],
    ),
    (
      "YZ",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.01), mat_invisible),
          position=(0.0, 0.15, 0.15),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
    (
      "XZ",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.01), mat_invisible),
          position=(0.15, 0.0, 0.15),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
  ]
  let helper_translate = [
    (
      "START",
      [
        handle_def(
          transform_mesh(
            @geometries.OctahedronGeometry::new(radius=0.01, detail=2.0),
            mat_helper,
          ),
          tag="helper",
        ),
      ],
    ),
    (
      "END",
      [
        handle_def(
          transform_mesh(
            @geometries.OctahedronGeometry::new(radius=0.01, detail=2.0),
            mat_helper,
          ),
          tag="helper",
        ),
      ],
    ),
    (
      "DELTA",
      [
        handle_def(
          transform_line(transform_translate_helper_geometry(), mat_helper),
          tag="helper",
        ),
      ],
    ),
    (
      "X",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(-1.0e3, 0.0, 0.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(0.0, -1.0e3, 0.0),
          rotation=(0.0, 0.0, pi / 2.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(0.0, 0.0, -1.0e3),
          rotation=(0.0, -pi / 2.0, 0.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
  ]
  let gizmo_rotate = [
    (
      "XYZE",
      [
        handle_def(
          transform_mesh(transform_circle_geometry(0.5, 1.0), mat_gray),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
    (
      "X",
      [handle_def(transform_mesh(transform_circle_geometry(0.5, 0.5), mat_red))],
    ),
    (
      "Y",
      [
        handle_def(
          transform_mesh(transform_circle_geometry(0.5, 0.5), mat_green),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_mesh(transform_circle_geometry(0.5, 0.5), mat_blue),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
    (
      "E",
      [
        handle_def(
          transform_mesh(
            transform_circle_geometry(0.75, 1.0),
            mat_yellow_transparent,
          ),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
  ]
  let helper_rotate = [
    (
      "AXIS",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(-1.0e3, 0.0, 0.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
  ]
  let torus = fn(radius : Double, radial : Double) {
    @geometries.TorusGeometry::new(
      radius~,
      tube=0.1,
      radial_segments=radial,
      tubular_segments=24.0,
    )
  }
  let picker_rotate = [
    (
      "XYZE",
      [
        handle_def(
          transform_mesh(
            @geometries.SphereGeometry::new(
              radius=0.25,
              width_segments=10.0,
              height_segments=8.0,
            ),
            mat_invisible,
          ),
        ),
      ],
    ),
    (
      "X",
      [
        handle_def(
          transform_mesh(torus(0.5, 4.0), mat_invisible),
          position=(0.0, 0.0, 0.0),
          rotation=(0.0, -pi / 2.0, -pi / 2.0),
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_mesh(torus(0.5, 4.0), mat_invisible),
          position=(0.0, 0.0, 0.0),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_mesh(torus(0.5, 4.0), mat_invisible),
          position=(0.0, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
      ],
    ),
    ("E", [handle_def(transform_mesh(torus(0.75, 2.0), mat_invisible))]),
  ]
  let gizmo_scale = [
    (
      "X",
      [
        handle_def(
          transform_mesh(scale_handle_geometry, mat_red),
          position=(0.5, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
        handle_def(
          transform_mesh(line_geometry2, mat_red),
          position=(0.0, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
        handle_def(
          transform_mesh(scale_handle_geometry, mat_red),
          position=(-0.5, 0.0, 0.0),
          rotation=(0.0, 0.0, pi / 2.0),
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_mesh(scale_handle_geometry, mat_green),
          position=(0.0, 0.5, 0.0),
        ),
        handle_def(transform_mesh(line_geometry2, mat_green)),
        handle_def(
          transform_mesh(scale_handle_geometry, mat_green),
          position=(0.0, -0.5, 0.0),
          rotation=(0.0, 0.0, pi),
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_mesh(scale_handle_geometry, mat_blue),
          position=(0.0, 0.0, 0.5),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
        handle_def(
          transform_mesh(line_geometry2, mat_blue),
          position=(0.0, 0.0, 0.0),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
        handle_def(
          transform_mesh(scale_handle_geometry, mat_blue),
          position=(0.0, 0.0, -0.5),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XY",
      [
        handle_def(
          transform_mesh(transform_box(0.15, 0.15, 0.01), mat_blue_transparent),
          position=(0.15, 0.15, 0.0),
        ),
      ],
    ),
    (
      "YZ",
      [
        handle_def(
          transform_mesh(transform_box(0.15, 0.15, 0.01), mat_red_transparent),
          position=(0.0, 0.15, 0.15),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
    (
      "XZ",
      [
        handle_def(
          transform_mesh(transform_box(0.15, 0.15, 0.01), mat_green_transparent),
          position=(0.15, 0.0, 0.15),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XYZ",
      [
        handle_def(
          transform_mesh(transform_box(0.1, 0.1, 0.1), mat_white_transparent),
        ),
      ],
    ),
  ]
  let picker_scale = [
    (
      "X",
      [
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.3, 0.0, 0.0),
          rotation=(0.0, 0.0, -pi / 2.0),
        ),
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(-0.3, 0.0, 0.0),
          rotation=(0.0, 0.0, pi / 2.0),
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, 0.3, 0.0),
        ),
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, -0.3, 0.0),
          rotation=(0.0, 0.0, pi),
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, 0.0, 0.3),
          rotation=(pi / 2.0, 0.0, 0.0),
        ),
        handle_def(
          transform_mesh(transform_cylinder(0.2, 0.0, 0.6, 4.0), mat_invisible),
          position=(0.0, 0.0, -0.3),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XY",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.01), mat_invisible),
          position=(0.15, 0.15, 0.0),
        ),
      ],
    ),
    (
      "YZ",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.01), mat_invisible),
          position=(0.0, 0.15, 0.15),
          rotation=(0.0, pi / 2.0, 0.0),
        ),
      ],
    ),
    (
      "XZ",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.01), mat_invisible),
          position=(0.15, 0.0, 0.15),
          rotation=(-pi / 2.0, 0.0, 0.0),
        ),
      ],
    ),
    (
      "XYZ",
      [
        handle_def(
          transform_mesh(transform_box(0.2, 0.2, 0.2), mat_invisible),
          position=(0.0, 0.0, 0.0),
        ),
      ],
    ),
  ]
  let helper_scale = [
    (
      "X",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(-1.0e3, 0.0, 0.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
    (
      "Y",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(0.0, -1.0e3, 0.0),
          rotation=(0.0, 0.0, pi / 2.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
    (
      "Z",
      [
        handle_def(
          transform_line(line_geometry, mat_helper),
          position=(0.0, 0.0, -1.0e3),
          rotation=(0.0, -pi / 2.0, 0.0),
          scale=(1.0e6, 1.0, 1.0),
          tag="helper",
        ),
      ],
    ),
  ]
  let tags : Map[Int32, String] = Map([])
  // Creates an Object3D with gizmos described in custom hierarchy definition.
  let setup_gizmo = fn(gizmo_map : Array[(String, Array[TransformHandleDef])]) {
    let gizmo = @core.Object3D::new()
    for entry in gizmo_map {
      let (name, defs) = entry
      for i = defs.length() - 1; i >= 0; i = i - 1 {
        let def = defs[i]
        let object = def.object.clone()
        // name and tag properties are essential for picking and updating logic.
        object.name = name
        if def.tag is Some(tag) {
          tags[object.id] = tag
        }
        if def.position is Some((x, y, z)) {
          ignore(object.position.set(x, y, z))
        }
        if def.rotation is Some((x, y, z)) {
          ignore(object.rotation.set(x, y, z))
        }
        if def.scale is Some((x, y, z)) {
          ignore(object.scale.set(x, y, z))
        }
        object.update_matrix()
        let temp_geometry = geometry_of(object).clone()
        ignore(temp_geometry.apply_matrix4(object.matrix))
        set_geometry_of(object, temp_geometry)
        object.render_order = @double.infinity
        ignore(object.position.set(0.0, 0.0, 0.0))
        ignore(object.rotation.set(0.0, 0.0, 0.0))
        ignore(object.scale.set(1.0, 1.0, 1.0))
        ignore(gizmo.add(object))
      }
    }
    gizmo
  }
  // Gizmo creation
  let gizmo : Map[String, @core.Object3D] = Map([])
  let picker : Map[String, @core.Object3D] = Map([])
  let helper : Map[String, @core.Object3D] = Map([])
  let add = fn(map : Map[String, @core.Object3D], mode : String, group) {
    map[mode] = group
    ignore(object.add(group))
  }
  add(gizmo, "translate", setup_gizmo(gizmo_translate))
  add(gizmo, "rotate", setup_gizmo(gizmo_rotate))
  add(gizmo, "scale", setup_gizmo(gizmo_scale))
  add(picker, "translate", setup_gizmo(picker_translate))
  add(picker, "rotate", setup_gizmo(picker_rotate))
  add(picker, "scale", setup_gizmo(picker_scale))
  add(helper, "translate", setup_gizmo(helper_translate))
  add(helper, "rotate", setup_gizmo(helper_rotate))
  add(helper, "scale", setup_gizmo(helper_scale))
  // Pickers should be hidden always
  picker["translate"].visible = false
  picker["rotate"].visible = false
  picker["scale"].visible = false
  let payload : TransformControlsGizmo = {
    state: TransformControlsState::new(None),
    material_lib,
    gizmo,
    picker,
    helper,
    _tags: tags,
    _material_colors: Map([]),
    _material_opacities: Map([]),
  }
  ignore(object.set_extension(payload))
  object
}

///|
fn TransformControlsGizmo::camera(
  self : TransformControlsGizmo,
) -> @core.Object3D {
  match self.state.camera {
    Some(camera) => camera
    None => abort("TransformControlsGizmo: no camera")
  }
}

///|
/// Upstream's `updateMatrixWorld` body: updates transformations and appearance of
/// individual handles.
fn TransformControlsGizmo::update_handles(
  self : TransformControlsGizmo,
) -> Unit {
  let state = self.state
  let mode = state.mode
  let space = if mode == "scale" { "local" } else { state.space } // scale always oriented to local rotation
  let quaternion = if space == "local" {
    state.world_quaternion
  } else {
    _transform_identity_quaternion
  }
  // Show only gizmos for current transform mode
  transform_lookup(self.gizmo, "translate").visible = mode == "translate"
  transform_lookup(self.gizmo, "rotate").visible = mode == "rotate"
  transform_lookup(self.gizmo, "scale").visible = mode == "scale"
  transform_lookup(self.helper, "translate").visible = mode == "translate"
  transform_lookup(self.helper, "rotate").visible = mode == "rotate"
  transform_lookup(self.helper, "scale").visible = mode == "scale"
  let handles : Array[@core.Object3D] = []
  handles.append(transform_lookup(self.picker, mode).children)
  handles.append(transform_lookup(self.gizmo, mode).children)
  handles.append(transform_lookup(self.helper, mode).children)
  let camera = self.camera()
  for handle in handles {
    // hide aligned to camera
    handle.visible = true
    ignore(handle.rotation.set(0.0, 0.0, 0.0))
    ignore(handle.position.copy(state.world_position))
    let factor = if camera.is_orthographic_camera() {
      (ortho_top(camera) - ortho_bottom(camera)) / camera_zoom(camera)
    } else {
      state.world_position.distance_to(state.camera_position) *
      js_min(
        1.9 * js_tan(js_pi * camera_fov(camera) / 360.0) / camera_zoom(camera),
        7.0,
      )
    }
    ignore(
      handle.scale.set(1.0, 1.0, 1.0).multiply_scalar(factor * state.size / 4.0),
    )
    // TODO: simplify helpers and consider decoupling from gizmo
    if self._tags.get(handle.id) == Some("helper") {
      handle.visible = false
      if handle.name == "AXIS" {
        handle.visible = state.axis is Some(axis) && axis != ""
        if state.axis == Some("X") {
          ignore(
            _transform_temp_quaternion.set_from_euler(
              _transform_temp_euler.set(0.0, 0.0, 0.0),
            ),
          )
          ignore(
            handle.quaternion
            .copy(quaternion)
            .multiply(_transform_temp_quaternion),
          )
          if js_abs(
              _transform_align_vector
              .copy(_transform_unit_x)
              .apply_quaternion(quaternion)
              .dot(state.eye),
            ) >
            0.9 {
            handle.visible = false
          }
        }
        if state.axis == Some("Y") {
          ignore(
            _transform_temp_quaternion.set_from_euler(
              _transform_temp_euler.set(0.0, 0.0, js_pi / 2.0),
            ),
          )
          ignore(
            handle.quaternion
            .copy(quaternion)
            .multiply(_transform_temp_quaternion),
          )
          if js_abs(
              _transform_align_vector
              .copy(_transform_unit_y)
              .apply_quaternion(quaternion)
              .dot(state.eye),
            ) >
            0.9 {
            handle.visible = false
          }
        }
        if state.axis == Some("Z") {
          ignore(
            _transform_temp_quaternion.set_from_euler(
              _transform_temp_euler.set(0.0, js_pi / 2.0, 0.0),
            ),
          )
          ignore(
            handle.quaternion
            .copy(quaternion)
            .multiply(_transform_temp_quaternion),
          )
          if js_abs(
              _transform_align_vector
              .copy(_transform_unit_z)
              .apply_quaternion(quaternion)
              .dot(state.eye),
            ) >
            0.9 {
            handle.visible = false
          }
        }
        if state.axis == Some("XYZE") {
          ignore(
            _transform_temp_quaternion.set_from_euler(
              _transform_temp_euler.set(0.0, js_pi / 2.0, 0.0),
            ),
          )
          ignore(_transform_align_vector.copy(state.rotation_axis))
          ignore(
            handle.quaternion.set_from_rotation_matrix(
              _transform_look_at_matrix.look_at(
                _transform_zero_vector, _transform_align_vector, _transform_unit_y,
              ),
            ),
          )
          ignore(handle.quaternion.multiply(_transform_temp_quaternion))
          handle.visible = state.dragging
        }
        if state.axis == Some("E") {
          handle.visible = false
        }
      } else if handle.name == "START" {
        ignore(handle.position.copy(state.world_position_start))
        handle.visible = state.dragging
      } else if handle.name == "END" {
        ignore(handle.position.copy(state.world_position))
        handle.visible = state.dragging
      } else if handle.name == "DELTA" {
        ignore(handle.position.copy(state.world_position_start))
        ignore(handle.quaternion.copy(state.world_quaternion_start))
        ignore(
          _transform_temp_vector
          .set(1.0e-10, 1.0e-10, 1.0e-10)
          .add(state.world_position_start)
          .sub(state.world_position)
          .multiply_scalar(-1.0),
        )
        ignore(
          _transform_temp_vector.apply_quaternion(
            state.world_quaternion_start.clone().invert(),
          ),
        )
        ignore(handle.scale.copy(_transform_temp_vector))
        handle.visible = state.dragging
      } else {
        ignore(handle.quaternion.copy(quaternion))
        if state.dragging {
          ignore(handle.position.copy(state.world_position_start))
        } else {
          ignore(handle.position.copy(state.world_position))
        }
        if state.axis is Some(axis) && axis != "" {
          handle.visible = axis.contains(handle.name)
        }
      }
      // If updating helper, skip rest of the loop
      continue
    }
    // Align handles to current local or world rotation
    ignore(handle.quaternion.copy(quaternion))
    if mode == "translate" || mode == "scale" {
      // Hide translate and scale axis facing the camera
      let axis_hide_threshold = 0.99
      let plane_hide_threshold = 0.2
      let aligned = fn(unit : @math.Vector3) {
        js_abs(
          _transform_align_vector
          .copy(unit)
          .apply_quaternion(quaternion)
          .dot(state.eye),
        )
      }
      let hide = fn() {
        ignore(handle.scale.set(1.0e-10, 1.0e-10, 1.0e-10))
        handle.visible = false
      }
      if handle.name == "X" {
        if aligned(_transform_unit_x) > axis_hide_threshold {
          hide()
        }
      }
      if handle.name == "Y" {
        if aligned(_transform_unit_y) > axis_hide_threshold {
          hide()
        }
      }
      if handle.name == "Z" {
        if aligned(_transform_unit_z) > axis_hide_threshold {
          hide()
        }
      }
      if handle.name == "XY" {
        if aligned(_transform_unit_z) < plane_hide_threshold {
          hide()
        }
      }
      if handle.name == "YZ" {
        if aligned(_transform_unit_x) < plane_hide_threshold {
          hide()
        }
      }
      if handle.name == "XZ" {
        if aligned(_transform_unit_y) < plane_hide_threshold {
          hide()
        }
      }
    } else if mode == "rotate" {
      // Align handles to current local or world rotation
      ignore(_transform_temp_quaternion2.copy(quaternion))
      ignore(
        _transform_align_vector
        .copy(state.eye)
        .apply_quaternion(_transform_temp_quaternion.copy(quaternion).invert()),
      )
      if handle.name.contains("E") {
        ignore(
          handle.quaternion.set_from_rotation_matrix(
            _transform_look_at_matrix.look_at(
              state.eye,
              _transform_zero_vector,
              _transform_unit_y,
            ),
          ),
        )
      }
      if handle.name == "X" {
        ignore(
          _transform_temp_quaternion.set_from_axis_angle(
            _transform_unit_x,
            js_atan2(-_transform_align_vector.y, _transform_align_vector.z),
          ),
        )
        ignore(
          _transform_temp_quaternion.multiply_quaternions(
            _transform_temp_quaternion2, _transform_temp_quaternion,
          ),
        )
        ignore(handle.quaternion.copy(_transform_temp_quaternion))
      }
      if handle.name == "Y" {
        ignore(
          _transform_temp_quaternion.set_from_axis_angle(
            _transform_unit_y,
            js_atan2(_transform_align_vector.x, _transform_align_vector.z),
          ),
        )
        ignore(
          _transform_temp_quaternion.multiply_quaternions(
            _transform_temp_quaternion2, _transform_temp_quaternion,
          ),
        )
        ignore(handle.quaternion.copy(_transform_temp_quaternion))
      }
      if handle.name == "Z" {
        ignore(
          _transform_temp_quaternion.set_from_axis_angle(
            _transform_unit_z,
            js_atan2(_transform_align_vector.y, _transform_align_vector.x),
          ),
        )
        ignore(
          _transform_temp_quaternion.multiply_quaternions(
            _transform_temp_quaternion2, _transform_temp_quaternion,
          ),
        )
        ignore(handle.quaternion.copy(_transform_temp_quaternion))
      }
    }
    // Hide disabled axes
    let name = handle.name
    handle.visible = handle.visible && (!name.contains("X") || state.show_x)
    handle.visible = handle.visible && (!name.contains("Y") || state.show_y)
    handle.visible = handle.visible && (!name.contains("Z") || state.show_z)
    handle.visible = handle.visible &&
      (!name.contains("E") || (state.show_x && state.show_y && state.show_z))
    // Hide disabled plane helpers
    handle.visible = handle.visible && (!name.contains("XY") || state.show_xy)
    handle.visible = handle.visible && (!name.contains("YZ") || state.show_yz)
    handle.visible = handle.visible && (!name.contains("XZ") || state.show_xz)
    // Hide disabled rotation helpers
    handle.visible = handle.visible && (name != "E" || state.show_e)
    handle.visible = handle.visible && (name != "XYZE" || state.show_xyze)
    // highlight selected axis
    let material = material_of(handle)
    let cached_color = match self._material_colors.get(material.id) {
      Some(color) => color
      None => {
        let color = color_of(material).clone()
        self._material_colors[material.id] = color
        color
      }
    }
    let cached_opacity = match self._material_opacities.get(material.id) {
      Some(opacity) if js_number_truthy(opacity) => opacity
      _ => material.opacity
    }
    self._material_opacities[material.id] = cached_opacity
    ignore(color_of(material).copy(cached_color))
    material.opacity = cached_opacity
    if state.enabled && state.axis is Some(axis) && axis != "" {
      if name == axis {
        ignore(color_of(material).copy(color_of(self.material_lib.active)))
        material.opacity = 1.0
      } else if axis.iter().any(fn(a) { name == a.to_string() }) {
        ignore(color_of(material).copy(color_of(self.material_lib.active)))
        material.opacity = 1.0
      }
    }
  }
}

///|
/// The plane the pointer is projected on while dragging. The payload of the
/// `Mesh` `TransformControlsPlane::new` returns.
pub(all) struct TransformControlsPlane {
  state : TransformControlsState
}

///|
pub impl @core.Object3DExtension for TransformControlsPlane with fn type_name(_) {
  "TransformControlsPlane"
}

///|
pub impl @core.Object3DExtension for TransformControlsPlane with fn construct(_) {
  TransformControlsPlane::new()
}

///|
pub impl @core.Object3DExtension for TransformControlsPlane with fn has_flag(
  _,
  flag,
) {
  flag == "isTransformControlsPlane"
}

///|
pub impl @core.Object3DExtension for TransformControlsPlane with fn update_matrix_world(
  self,
  object,
  force,
) {
  let state = self.state
  let mut space = state.space
  ignore(object.position.copy(state.world_position))
  if state.mode == "scale" {
    space = "local" // scale always oriented to local rotation
  }
  let quaternion = if space == "local" {
    state.world_quaternion
  } else {
    _transform_identity_quaternion
  }
  ignore(_transform_v1.copy(_transform_unit_x).apply_quaternion(quaternion))
  ignore(_transform_v2.copy(_transform_unit_y).apply_quaternion(quaternion))
  ignore(_transform_v3.copy(_transform_unit_z).apply_quaternion(quaternion))
  // Align the plane for current transform mode, axis and space.
  ignore(_transform_align_vector.copy(_transform_v2))
  match state.mode {
    "translate" | "scale" =>
      match state.axis {
        Some("X") => {
          ignore(_transform_align_vector.copy(state.eye).cross(_transform_v1))
          ignore(
            _transform_dir_vector
            .copy(_transform_v1)
            .cross(_transform_align_vector),
          )
        }
        Some("Y") => {
          ignore(_transform_align_vector.copy(state.eye).cross(_transform_v2))
          ignore(
            _transform_dir_vector
            .copy(_transform_v2)
            .cross(_transform_align_vector),
          )
        }
        Some("Z") => {
          ignore(_transform_align_vector.copy(state.eye).cross(_transform_v3))
          ignore(
            _transform_dir_vector
            .copy(_transform_v3)
            .cross(_transform_align_vector),
          )
        }
        Some("XY") => ignore(_transform_dir_vector.copy(_transform_v3))
        Some("YZ") => ignore(_transform_dir_vector.copy(_transform_v1))
        Some("XZ") => {
          ignore(_transform_align_vector.copy(_transform_v3))
          ignore(_transform_dir_vector.copy(_transform_v2))
        }
        Some("XYZ") | Some("E") =>
          ignore(_transform_dir_vector.set(0.0, 0.0, 0.0))
        _ => ()
      }
    _ =>
      // special case for rotate
      ignore(_transform_dir_vector.set(0.0, 0.0, 0.0))
  }
  if _transform_dir_vector.length() == 0.0 {
    // If in rotate mode, make the plane parallel to camera
    ignore(object.quaternion.copy(state.camera_quaternion))
  } else {
    ignore(
      _transform_temp_matrix.look_at(
        _transform_temp_vector.set(0.0, 0.0, 0.0),
        _transform_dir_vector,
        _transform_align_vector,
      ),
    )
    ignore(object.quaternion.set_from_rotation_matrix(_transform_temp_matrix))
  }
  object.update_matrix_world_kind(force)
}

///|
#deprecated
pub extend TransformControlsPlane with @core.Object3DExtension::{
  type_name,
  construct,
  payload,
  has_flag,
  raycast,
  copy_from,
  to_json,
  update_matrix_world,
  update_world_matrix,
  intersects_frustum,
  get_world_direction,
  dispose,
}

///|
/// The `TransformControlsPlane` payload of `object`, if it is one.
pub fn TransformControlsPlane::of(
  object : @core.Object3D,
) -> TransformControlsPlane? {
  match object.extension {
    Some(extension) if extension.has_flag("isTransformControlsPlane") =>
      Some(extension.payload().cast())
    _ => None
  }
}

///|
/// `new TransformControlsPlane()`.
pub fn TransformControlsPlane::new() -> @core.Object3D {
  let material = @core.MeshBasicMaterial::new()
  material.visible = false
  material.wireframe = Some(true)
  material.side = @core.DoubleSide
  material.transparent = true
  material.opacity = 0.1
  material.tone_mapped = false
  let object = @core.Mesh::new(
    geometry=@geometries.PlaneGeometry::new(
      width=100000.0,
      height=100000.0,
      width_segments=2.0,
      height_segments=2.0,
    ),
    material=Single(material),
  )
  object.type_ = "TransformControlsPlane"
  ignore(
    object.set_extension(TransformControlsPlane::{
      state: TransformControlsState::new(None),
    }),
  )
  object
}
