// DOM, event and JS math bindings shared by the controls, plus accessors for the camera
// properties upstream reads off `this.object` without knowing its class.

///|
extern "js" fn js_pow(x : Double, y : Double) -> Double = "Math.pow"

///|
extern "js" fn js_tan(x : Double) -> Double = "Math.tan"

///|
extern "js" fn js_atan(x : Double) -> Double = "Math.atan"

///|
extern "js" fn js_atan2(y : Double, x : Double) -> Double = "Math.atan2"

///|
extern "js" fn js_sin(x : Double) -> Double = "Math.sin"

///|
extern "js" fn js_cos(x : Double) -> Double = "Math.cos"

///|
extern "js" fn js_sqrt(x : Double) -> Double = "Math.sqrt"

///|
extern "js" fn js_abs(x : Double) -> Double = "Math.abs"

///|
extern "js" fn js_round(x : Double) -> Double = "Math.round"

///|
extern "js" fn js_is_finite(x : Double) -> Bool = "isFinite"

///|
fn js_min(a : Double, b : Double) -> Double {
  @webgl.js_math_min(a, b)
}

///|
fn js_max(a : Double, b : Double) -> Double {
  @webgl.js_math_max(a, b)
}

///|
let js_pi : Double = 3.141592653589793

///|
/// `undefined` read as a number, so arithmetic gives `NaN` as in JS.
extern "js" fn js_undefined_number() -> Double = "() => undefined"

///|
/// JS truthiness of a number (`0` and `NaN` are falsy).
extern "js" fn js_number_truthy(x : Double) -> Bool = "(x) => !!x"

// Events: a DOM event is a `JsValue`; these read its properties.

///|
/// `event[ key ]` as a number. Missing properties stay `undefined`, which behaves as in
/// JS in arithmetic and comparisons.
extern "js" fn ev_num(event : @core.JsValue, key : String) -> Double = "(e, k) => e[k]"

///|
/// The truthiness of `event[ key ]`.
extern "js" fn ev_bool(event : @core.JsValue, key : String) -> Bool = "(e, k) => !!e[k]"

///|
/// `event[ key ] === value`.
extern "js" fn ev_is(
  event : @core.JsValue,
  key : String,
  value : String,
) -> Bool = "(e, k, v) => e[k] === v"

///|
extern "js" fn js_typeof_string(value : @core.JsValue) -> Bool = "(v) => typeof v === 'string'"

///|
/// `event[ key ]` when it is a string.
fn ev_str(event : @core.JsValue, key : String) -> String? {
  let value = event.get(key)
  if js_typeof_string(value) {
    Some(value.cast())
  } else {
    None
  }
}

///|
/// `event.preventDefault()`.
fn prevent_default(event : @core.JsValue) -> Unit {
  @webgl.dom_event_prevent_default(event)
}

///|
/// `{ pointerId, pageX, pageY }`.
extern "js" fn make_pointer_event(
  pointer_id : Double,
  page_x : Double,
  page_y : Double,
) -> @core.JsValue = "(i, x, y) => ({ pointerId: i, pageX: x, pageY: y })"

///|
/// `{ clientX, clientY, deltaY }`.
extern "js" fn make_wheel_event(
  client_x : Double,
  client_y : Double,
  delta_y : Double,
) -> @core.JsValue = "(x, y, d) => ({ clientX: x, clientY: y, deltaY: d })"

// DOM elements and globals.

///|
type Listener = (@core.JsValue) -> Unit

///|
fn noop_listener(_event : @core.JsValue) -> Unit {

}

///|
extern "js" fn dom_add_event_listener(
  target : @core.JsValue,
  type_ : String,
  listener : Listener,
) -> Unit = "(t, n, l) => t.addEventListener(n, l)"

///|
extern "js" fn dom_remove_event_listener(
  target : @core.JsValue,
  type_ : String,
  listener : Listener,
) -> Unit = "(t, n, l) => t.removeEventListener(n, l)"

///|
/// `addEventListener( type, listener, { passive: false } )`.
extern "js" fn dom_add_event_listener_not_passive(
  target : @core.JsValue,
  type_ : String,
  listener : Listener,
) -> Unit = "(t, n, l) => t.addEventListener(n, l, { passive: false })"

///|
/// `addEventListener( type, listener, { passive: true, capture: true } )`.
extern "js" fn dom_add_event_listener_passive_capture(
  target : @core.JsValue,
  type_ : String,
  listener : Listener,
) -> Unit = "(t, n, l) => t.addEventListener(n, l, { passive: true, capture: true })"

///|
/// `removeEventListener( type, listener, { capture: true } )`.
extern "js" fn dom_remove_event_listener_capture(
  target : @core.JsValue,
  type_ : String,
  listener : Listener,
) -> Unit = "(t, n, l) => t.removeEventListener(n, l, { capture: true })"

///|
/// `removeEventListener( type, listener, { passive: true, capture: true } )`.
extern "js" fn dom_remove_event_listener_passive_capture(
  target : @core.JsValue,
  type_ : String,
  listener : Listener,
) -> Unit = "(t, n, l) => t.removeEventListener(n, l, { passive: true, capture: true })"

///|
extern "js" fn dom_owner_document(element : @core.JsValue) -> @core.JsValue = "(e) => e.ownerDocument"

///|
/// The global `window`.
extern "js" fn dom_window() -> @core.JsValue = "() => window"

///|
/// The global `document`.
extern "js" fn dom_document() -> @core.JsValue = "() => document"

///|
extern "js" fn dom_set_pointer_capture(
  element : @core.JsValue,
  pointer_id : Double,
) -> Unit = "(e, i) => e.setPointerCapture(i)"

///|
extern "js" fn dom_release_pointer_capture(
  element : @core.JsValue,
  pointer_id : Double,
) -> Unit = "(e, i) => e.releasePointerCapture(i)"

///|
extern "js" fn dom_get_bounding_client_rect(
  element : @core.JsValue,
) -> @core.JsValue = "(e) => e.getBoundingClientRect()"

///|
/// `element.style[ key ] = value`.
extern "js" fn dom_set_style(
  element : @core.JsValue,
  key : String,
  value : String,
) -> Unit = "(e, k, v) => { e.style[k] = v; }"

///|
extern "js" fn dom_focus(element : @core.JsValue) -> Unit = "(e) => e.focus()"

///|
/// `element.requestPointerLock( { unadjustedMovement } )`.
extern "js" fn dom_request_pointer_lock(
  element : @core.JsValue,
  unadjusted_movement : Bool,
) -> Unit = "(e, u) => e.requestPointerLock({ unadjustedMovement: u })"

///|
extern "js" fn dom_exit_pointer_lock(document : @core.JsValue) -> Unit = "(d) => d.exitPointerLock()"

///|
/// `performance.now()`.
extern "js" fn performance_now() -> Double = "() => performance.now()"

///|
/// `window.requestAnimationFrame( callback )`.
extern "js" fn window_request_animation_frame(
  callback : (Double) -> Unit,
) -> Double = "(f) => window.requestAnimationFrame(f)"

///|
/// `window.cancelAnimationFrame( id )`.
extern "js" fn window_cancel_animation_frame(id : Double) -> Unit = "(i) => window.cancelAnimationFrame(i)"

///|
/// The global `cancelAnimationFrame( id )`.
extern "js" fn global_cancel_animation_frame(id : Double) -> Unit = "(i) => cancelAnimationFrame(i)"

///|
/// `navigator.clipboard.writeText( text )`.
extern "js" fn clipboard_write_text(text : String) -> Unit = "(t) => { navigator.clipboard.writeText(t); }"

///|
/// `navigator.clipboard.readText().then( callback )`.
extern "js" fn clipboard_read_text(callback : (String) -> Unit) -> Unit = "(f) => { navigator.clipboard.readText().then(f); }"

///|
/// The element events are bound to. Aborts like upstream's `TypeError` without one.
fn dom_element_of(base : @extras.Controls) -> @core.JsValue {
  match base.dom_element {
    Some(element) => element
    None => abort("Controls: domElement is null")
  }
}

///|
fn dom_num(element : @core.JsValue, key : String) -> Double {
  ev_num(element, key)
}

// Camera properties upstream reads as `this.object.zoom` etc.

///|
fn camera_zoom(object : @core.Object3D) -> Double {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.zoom
    Camera({ kind: OrthographicCamera(camera), .. }) => camera.zoom
    _ => js_undefined_number()
  }
}

///|
fn set_camera_zoom(object : @core.Object3D, zoom : Double) -> Unit {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.zoom = zoom
    Camera({ kind: OrthographicCamera(camera), .. }) => camera.zoom = zoom
    _ => ()
  }
}

///|
fn camera_fov(object : @core.Object3D) -> Double {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.fov
    _ => js_undefined_number()
  }
}

///|
fn set_camera_fov(object : @core.Object3D, fov : Double) -> Unit {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.fov = fov
    _ => ()
  }
}

///|
fn camera_aspect(object : @core.Object3D) -> Double {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.aspect
    _ => js_undefined_number()
  }
}

///|
fn camera_near(object : @core.Object3D) -> Double {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.near
    Camera({ kind: OrthographicCamera(camera), .. }) => camera.near
    _ => js_undefined_number()
  }
}

///|
fn set_camera_near(object : @core.Object3D, near : Double) -> Unit {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.near = near
    Camera({ kind: OrthographicCamera(camera), .. }) => camera.near = near
    _ => ()
  }
}

///|
fn camera_far(object : @core.Object3D) -> Double {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.far
    Camera({ kind: OrthographicCamera(camera), .. }) => camera.far
    _ => js_undefined_number()
  }
}

///|
fn set_camera_far(object : @core.Object3D, far : Double) -> Unit {
  match object.kind {
    Camera({ kind: PerspectiveCamera(camera), .. }) => camera.far = far
    Camera({ kind: OrthographicCamera(camera), .. }) => camera.far = far
    _ => ()
  }
}

///|
/// `left`, `right`, `top` and `bottom` of an orthographic camera.
fn ortho_bounds(object : @core.Object3D) -> (Double, Double, Double, Double) {
  match object.kind {
    Camera({ kind: OrthographicCamera(camera), .. }) =>
      (camera.left, camera.right, camera.top, camera.bottom)
    _ =>
      (
        js_undefined_number(),
        js_undefined_number(),
        js_undefined_number(),
        js_undefined_number(),
      )
  }
}

///|
fn ortho_left(object : @core.Object3D) -> Double {
  ortho_bounds(object).0
}

///|
fn ortho_right(object : @core.Object3D) -> Double {
  ortho_bounds(object).1
}

///|
fn ortho_top(object : @core.Object3D) -> Double {
  ortho_bounds(object).2
}

///|
fn ortho_bottom(object : @core.Object3D) -> Double {
  ortho_bounds(object).3
}

///|
/// `object.geometry` of a mesh, line or points.
fn geometry_of(object : @core.Object3D) -> @core.BufferGeometry {
  match object.get_geometry() {
    Some(geometry) => geometry
    None => abort("Controls: object has no geometry")
  }
}

///|
/// `object.geometry = geometry` on a mesh or line.
fn set_geometry_of(
  object : @core.Object3D,
  geometry : @core.BufferGeometry,
) -> Unit {
  match object.kind {
    Mesh(mesh) => mesh.geometry = geometry
    Line(line) => line.geometry = geometry
    Points(points) => points.geometry = geometry
    _ => ()
  }
}

///|
/// `object.material` when it is a single material.
fn material_of(object : @core.Object3D) -> @core.Material {
  match object.get_material() {
    Some(Single(material)) => material
    _ => abort("Controls: object has no single material")
  }
}

///|
fn color_of(material : @core.Material) -> @math.Color {
  match material.color {
    Some(color) => color
    None => abort("Controls: material has no color")
  }
}
