// Upstream examples/jsm/controls/DragControls.js. Its events carry the dragged or
// hovered object in `event.data` (`@core.JsValue::of(object)`, upstream's
// `event.object`).

///|
let _drag_plane : @math.Plane = @math.Plane::new()

///|
let _drag_pointer : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _drag_offset : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _drag_diff : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _drag_previous_pointer : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _drag_intersection : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _drag_world_position : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _drag_inverse_matrix : @math.Matrix4 = @math.Matrix4::new()

///|
let _drag_up : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
let _drag_right : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// Upstream's module-level `_selected`, shared by every instance.
let _drag_selected : Ref[@core.Object3D?] = Ref(None)

///|
/// Upstream's module-level `_hovered`, shared by every instance.
let _drag_hovered : Ref[@core.Object3D?] = Ref(None)

///|
let _drag_intersections : Array[@core.Intersection] = []

///|
const DRAG_STATE_NONE : Int32 = -1

///|
const DRAG_STATE_PAN : Int32 = 0

///|
const DRAG_STATE_ROTATE : Int32 = 1

///|
/// Drags and rotates objects with the pointer.
pub(all) struct DragControls {
  base : @extras.Controls
  mut objects : Array[@core.Object3D]
  mut recursive : Bool
  mut transform_group : Bool
  mut rotate_speed : Double
  mut raycaster : @core.Raycaster
  mut _on_pointer_move : (@core.JsValue) -> Unit
  mut _on_pointer_down : (@core.JsValue) -> Unit
  mut _on_pointer_cancel : (@core.JsValue) -> Unit
  mut _on_context_menu : (@core.JsValue) -> Unit
}

///|
pub impl @core.EventSource for DragControls with fn event_dispatcher(self) {
  self.base.dispatcher
}

///|
pub impl @core.EventSource for DragControls with fn event_target(self) {
  Other(@core.JsValue::of(self))
}

///|
pub extend DragControls with @core.EventSource::{
  event_dispatcher,
  event_target,
  add_event_listener,
  has_event_listener,
  remove_event_listener,
  dispatch_event,
}

///|
pub impl @extras.ControlsExtension for DragControls with fn connect(self, _, _) {
  self.connect_listeners()
}

///|
pub impl @extras.ControlsExtension for DragControls with fn disconnect(self, _) {
  self.disconnect()
}

///|
pub impl @extras.ControlsExtension for DragControls with fn dispose(self, _) {
  self.dispose()
}

///|
/// `new DragControls( objects, camera, domElement )`.
pub fn DragControls::new(
  objects : Array[@core.Object3D],
  camera : @core.Object3D,
  dom_element? : @core.JsValue,
) -> DragControls {
  let base = @extras.Controls::new(camera, dom_element?)
  base.mouse_buttons = {
    left: Some(@core.MOUSE_PAN),
    middle: Some(@core.MOUSE_PAN),
    right: Some(@core.MOUSE_ROTATE),
  }
  base.touches = { one: Some(@core.TOUCH_PAN), two: None, }
  let self : DragControls = {
    base,
    objects,
    recursive: true,
    transform_group: false,
    rotate_speed: 1.0,
    raycaster: @core.Raycaster::new(),
    _on_pointer_move: noop_listener,
    _on_pointer_down: noop_listener,
    _on_pointer_cancel: noop_listener,
    _on_context_menu: noop_listener,
  }
  self._on_pointer_move = fn(event) { self.on_pointer_move(event) }
  self._on_pointer_down = fn(event) { self.on_pointer_down(event) }
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
pub fn DragControls::connect(
  self : DragControls,
  element : @core.JsValue,
) -> Unit {
  self.base.connect(element)
}

///|
fn DragControls::connect_listeners(self : DragControls) -> Unit {
  let element = dom_element_of(self.base)
  dom_add_event_listener(element, "pointermove", self._on_pointer_move)
  dom_add_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_add_event_listener(element, "pointerup", self._on_pointer_cancel)
  dom_add_event_listener(element, "pointerleave", self._on_pointer_cancel)
  dom_add_event_listener(element, "contextmenu", self._on_context_menu)
  dom_set_style(element, "touchAction", "none")
}

///|
/// Disconnects the controls from the DOM.
pub fn DragControls::disconnect(self : DragControls) -> Unit {
  let element = dom_element_of(self.base)
  dom_remove_event_listener(element, "pointermove", self._on_pointer_move)
  dom_remove_event_listener(element, "pointerdown", self._on_pointer_down)
  dom_remove_event_listener(element, "pointerup", self._on_pointer_cancel)
  dom_remove_event_listener(element, "pointerleave", self._on_pointer_cancel)
  dom_remove_event_listener(element, "contextmenu", self._on_context_menu)
  dom_set_style(element, "touchAction", "")
  dom_set_style(element, "cursor", "")
}

///|
/// Frees the controls' resources and removes all event listeners.
pub fn DragControls::dispose(self : DragControls) -> Unit {
  self.disconnect()
}

///|
fn DragControls::_update_pointer(
  self : DragControls,
  event : @core.JsValue,
) -> Unit {
  let rect = dom_get_bounding_client_rect(dom_element_of(self.base))
  _drag_pointer.x = (ev_num(event, "clientX") - ev_num(rect, "left")) /
    ev_num(rect, "width") *
    2.0 -
    1.0
  _drag_pointer.y = -(ev_num(event, "clientY") - ev_num(rect, "top")) /
    ev_num(rect, "height") *
    2.0 +
    1.0
}

///|
fn DragControls::_update_state(
  self : DragControls,
  event : @core.JsValue,
) -> Unit {
  // determine action
  let action = if ev_is(event, "pointerType", "touch") {
    self.base.touches.one
  } else {
    let button = ev_num(event, "button")
    if button == 0.0 {
      self.base.mouse_buttons.left
    } else if button == 1.0 {
      self.base.mouse_buttons.middle
    } else if button == 2.0 {
      self.base.mouse_buttons.right
    } else {
      None
    }
  }
  // determine state
  self.base.state = match action {
    Some(action) if action == @core.MOUSE_PAN || action == @core.TOUCH_PAN =>
      DRAG_STATE_PAN
    Some(action) if action == @core.MOUSE_ROTATE || action == @core.TOUCH_ROTATE =>
      DRAG_STATE_ROTATE
    _ => DRAG_STATE_NONE
  }
}

///|
fn drag_event(type_ : String, object : @core.Object3D) -> @core.Event {
  @core.Event::new(type_, data=@core.JsValue::of(object))
}

///|
fn DragControls::on_pointer_move(
  self : DragControls,
  event : @core.JsValue,
) -> Unit {
  let camera = self.base.object
  let raycaster = self.raycaster
  if !self.base.enabled {
    return
  }
  let dom_element = dom_element_of(self.base)
  self._update_pointer(event)
  raycaster.set_from_camera(_drag_pointer, camera)
  if _drag_selected.val is Some(selected) {
    if self.base.state == DRAG_STATE_PAN {
      if raycaster.ray.intersect_plane(_drag_plane, _drag_intersection)
        is Some(_) {
        ignore(
          selected.position.copy(
            _drag_intersection
            .sub(_drag_offset)
            .apply_matrix4(_drag_inverse_matrix),
          ),
        )
        self.dispatch_event(drag_event("drag", selected))
      }
    } else if self.base.state == DRAG_STATE_ROTATE {
      ignore(
        _drag_diff
        .sub_vectors(_drag_pointer, _drag_previous_pointer)
        .multiply_scalar(self.rotate_speed),
      )
      ignore(selected.rotate_on_world_axis(_drag_up, _drag_diff.x))
      ignore(
        selected.rotate_on_world_axis(_drag_right.normalize(), -_drag_diff.y),
      )
      self.dispatch_event(drag_event("drag", selected))
    }
    ignore(_drag_previous_pointer.copy(_drag_pointer))
  } else if ev_is(event, "pointerType", "mouse") ||
    ev_is(event, "pointerType", "pen") {
    // hover support
    _drag_intersections.clear()
    raycaster.set_from_camera(_drag_pointer, camera)
    ignore(
      raycaster.intersect_objects(
        self.objects,
        recursive=self.recursive,
        intersects=_drag_intersections,
      ),
    )
    if _drag_intersections.length() > 0 {
      let object = _drag_intersections[0].object
      ignore(
        _drag_plane.set_from_normal_and_coplanar_point(
          camera.get_world_direction(_drag_plane.normal),
          _drag_world_position.set_from_matrix_position(object.matrix_world),
        ),
      )
      if _drag_hovered.val is Some(hovered) && !physical_equal(hovered, object) {
        self.dispatch_event(drag_event("hoveroff", hovered))
        dom_set_style(dom_element, "cursor", "auto")
        _drag_hovered.val = None
      }
      if !(_drag_hovered.val is Some(hovered) && physical_equal(hovered, object)) {
        self.dispatch_event(drag_event("hoveron", object))
        dom_set_style(dom_element, "cursor", "pointer")
        _drag_hovered.val = Some(object)
      }
    } else if _drag_hovered.val is Some(hovered) {
      self.dispatch_event(drag_event("hoveroff", hovered))
      dom_set_style(dom_element, "cursor", "auto")
      _drag_hovered.val = None
    }
  }
  ignore(_drag_previous_pointer.copy(_drag_pointer))
}

///|
fn DragControls::on_pointer_down(
  self : DragControls,
  event : @core.JsValue,
) -> Unit {
  let camera = self.base.object
  let raycaster = self.raycaster
  if !self.base.enabled {
    return
  }
  let dom_element = dom_element_of(self.base)
  self._update_pointer(event)
  self._update_state(event)
  _drag_intersections.clear()
  raycaster.set_from_camera(_drag_pointer, camera)
  ignore(
    raycaster.intersect_objects(
      self.objects,
      recursive=self.recursive,
      intersects=_drag_intersections,
    ),
  )
  if _drag_intersections.length() > 0 {
    _drag_selected.val = if self.transform_group {
      // look for the outermost group in the object's upper hierarchy
      drag_find_group(_drag_intersections[0].object, None)
    } else {
      Some(_drag_intersections[0].object)
    }
    guard _drag_selected.val is Some(selected) else {
      abort("DragControls: no group above the intersected object")
    }
    ignore(
      _drag_plane.set_from_normal_and_coplanar_point(
        camera.get_world_direction(_drag_plane.normal),
        _drag_world_position.set_from_matrix_position(selected.matrix_world),
      ),
    )
    if raycaster.ray.intersect_plane(_drag_plane, _drag_intersection) is Some(_) {
      if self.base.state == DRAG_STATE_PAN {
        guard selected.parent is Some(parent) else {
          abort("DragControls: the selected object has no parent")
        }
        ignore(_drag_inverse_matrix.copy(parent.matrix_world).invert())
        ignore(
          _drag_offset
          .copy(_drag_intersection)
          .sub(
            _drag_world_position.set_from_matrix_position(selected.matrix_world),
          ),
        )
        dom_set_style(dom_element, "cursor", "move")
        self.dispatch_event(drag_event("dragstart", selected))
      } else if self.base.state == DRAG_STATE_ROTATE {
        // the controls only support Y+ up
        ignore(
          _drag_up
          .set(0.0, 1.0, 0.0)
          .apply_quaternion(camera.quaternion)
          .normalize(),
        )
        ignore(
          _drag_right
          .set(1.0, 0.0, 0.0)
          .apply_quaternion(camera.quaternion)
          .normalize(),
        )
        dom_set_style(dom_element, "cursor", "move")
        self.dispatch_event(drag_event("dragstart", selected))
      }
    }
  }
  ignore(_drag_previous_pointer.copy(_drag_pointer))
}

///|
fn DragControls::on_pointer_cancel(self : DragControls) -> Unit {
  if !self.base.enabled {
    return
  }
  if _drag_selected.val is Some(selected) {
    self.dispatch_event(drag_event("dragend", selected))
    _drag_selected.val = None
  }
  dom_set_style(
    dom_element_of(self.base),
    "cursor",
    if _drag_hovered.val is Some(_) {
      "pointer"
    } else {
      "auto"
    },
  )
  self.base.state = DRAG_STATE_NONE
}

///|
fn DragControls::on_context_menu(
  self : DragControls,
  event : @core.JsValue,
) -> Unit {
  if !self.base.enabled {
    return
  }
  prevent_default(event)
}

///|
fn drag_find_group(
  obj : @core.Object3D,
  group : @core.Object3D?,
) -> @core.Object3D? {
  let group = if obj.is_group() { Some(obj) } else { group }
  match obj.parent {
    None => group
    Some(parent) => drag_find_group(parent, group)
  }
}
