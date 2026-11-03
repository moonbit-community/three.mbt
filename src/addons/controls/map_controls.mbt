// Upstream examples/jsm/controls/MapControls.js: an `OrbitControls` with map-style
// mouse buttons and touches, panning in the plane orthogonal to `object.up`.

///|
let _map_plane : @math.Plane = @math.Plane::new()

///|
let _map_raycaster : @core.Raycaster = @core.Raycaster::new()

///|
let _map_mouse : @math.Vector2 = @math.Vector2::new(0.0, 0.0)

///|
let _map_pan_current : @math.Vector3 = @math.Vector3::new(0.0, 0.0, 0.0)

///|
/// Marker for the `MapControls` constructor, which returns an `OrbitControls`.
#external
pub type MapControls

///|
/// `new MapControls( object, domElement )`.
pub fn MapControls::new(
  object : @core.Object3D,
  dom_element? : @core.JsValue,
) -> OrbitControls {
  let controls = OrbitControls::new(object, dom_element?)
  controls.screen_space_panning = false
  controls.base.mouse_buttons = {
    left: Some(@core.MOUSE_PAN),
    middle: Some(@core.MOUSE_DOLLY),
    right: Some(@core.MOUSE_ROTATE),
  }
  controls.base.touches = {
    one: Some(@core.TOUCH_PAN),
    two: Some(@core.TOUCH_DOLLY_ROTATE),
  }
  controls._pan_world_start = Some(@math.Vector3::new(0.0, 0.0, 0.0))
  controls
}

///|
/// Whether `controls` was made by `MapControls::new`.
pub fn OrbitControls::is_map_controls(self : OrbitControls) -> Bool {
  self._pan_world_start is Some(_)
}

///|
/// `MapControls.prototype._handleMouseDownPan`.
fn map_handle_mouse_down_pan(
  controls : OrbitControls,
  pan_world_start : @math.Vector3,
  event : @core.JsValue,
) -> Unit {
  controls._handle_mouse_down_pan_base(event)
  ignore(controls._pan_offset.set(0.0, 0.0, 0.0))
  if controls.screen_space_panning {
    return
  }
  ignore(
    _map_plane.set_from_normal_and_coplanar_point(
      controls.base.object.up,
      controls.target,
    ),
  )
  let element = dom_element_of(controls.base)
  let rect = dom_get_bounding_client_rect(element)
  _map_mouse.x = (ev_num(event, "clientX") - ev_num(rect, "left")) /
    ev_num(rect, "width") *
    2.0 -
    1.0
  _map_mouse.y = -((ev_num(event, "clientY") - ev_num(rect, "top")) /
    ev_num(rect, "height")) *
    2.0 +
    1.0
  _map_raycaster.set_from_camera(_map_mouse, controls.base.object)
  ignore(_map_raycaster.ray.intersect_plane(_map_plane, pan_world_start))
}

///|
/// `MapControls.prototype._handleMouseMovePan`.
fn map_handle_mouse_move_pan(
  controls : OrbitControls,
  pan_world_start : @math.Vector3,
  event : @core.JsValue,
) -> Unit {
  if controls.screen_space_panning {
    controls._handle_mouse_move_pan_base(event)
    return
  }
  let element = dom_element_of(controls.base)
  let rect = dom_get_bounding_client_rect(element)
  _map_mouse.x = (ev_num(event, "clientX") - ev_num(rect, "left")) /
    ev_num(rect, "width") *
    2.0 -
    1.0
  _map_mouse.y = -((ev_num(event, "clientY") - ev_num(rect, "top")) /
    ev_num(rect, "height")) *
    2.0 +
    1.0
  _map_raycaster.set_from_camera(_map_mouse, controls.base.object)
  if _map_raycaster.ray.intersect_plane(_map_plane, _map_pan_current) is Some(_) {
    ignore(_map_pan_current.sub(pan_world_start))
    ignore(controls._pan_offset.copy(_map_pan_current).negate())
    ignore(controls.update())
  }
}
