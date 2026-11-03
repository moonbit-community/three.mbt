// MoonBit side of the controls differential harness. run.mjs drives both sides
// through the same adapter interface (see adapter_up.mjs for upstream's).

///|
extern "js" fn js_arr() -> @core.JsValue = "() => []"

///|
extern "js" fn js_push(a : @core.JsValue, v : @core.JsValue) -> Unit = "(a, v) => { a.push(v); }"

///|
extern "js" fn js_len(a : @core.JsValue) -> Int = "(a) => a.length"

///|
extern "js" fn js_at(a : @core.JsValue, i : Int) -> @core.JsValue = "(a, i) => a[i]"

///|
extern "js" fn js_is_undef(a : @core.JsValue) -> Bool = "(a) => a === undefined"

///|
extern "js" fn js_is_nullish(a : @core.JsValue) -> Bool = "(a) => a === undefined || a === null"

///|
extern "js" fn js_str(s : String) -> @core.JsValue = "(s) => s"

///|
extern "js" fn js_null() -> @core.JsValue = "() => null"

///|
extern "js" fn js_undefined() -> @core.JsValue = "() => undefined"

///|
fn num(v : Double) -> @core.JsValue {
  @core.JsValue::of(v)
}

///|
fn bool(v : Bool) -> @core.JsValue {
  @core.JsValue::of(v)
}

///|
fn nums(values : Array[Double]) -> @core.JsValue {
  let a = js_arr()
  for v in values {
    js_push(a, num(v))
  }
  a
}

///|
fn v3(v : @math.Vector3) -> @core.JsValue {
  nums([v.x, v.y, v.z])
}

///|
fn v2(v : @math.Vector2) -> @core.JsValue {
  nums([v.x, v.y])
}

///|
fn q4(q : @math.Quaternion) -> @core.JsValue {
  nums([q.x, q.y, q.z, q.w])
}

///|
fn sph(s : @math.Spherical) -> @core.JsValue {
  nums([s.radius, s.phi, s.theta])
}

///|
fn m4(m : @math.Matrix4) -> @core.JsValue {
  nums(m.elements)
}

///|
fn opt_num(v : Double?) -> @core.JsValue {
  match v {
    Some(v) => num(v)
    None => js_null()
  }
}

///|
fn opt_str(v : String?) -> @core.JsValue {
  match v {
    Some(v) => js_str(v)
    None => js_null()
  }
}

///|
fn opt_int(v : Int?) -> @core.JsValue {
  match v {
    Some(v) => num(v.to_double())
    None => js_null()
  }
}

///|
/// `_pointerPositions` as "id:[x,y];..." sorted by id, as adapter_up.mjs prints it.
fn positions(m : Map[Double, @math.Vector2]) -> @core.JsValue {
  let keys = m.keys().collect()
  keys.sort()
  let parts = keys.map(fn(k) {
    let p = m.get(k).unwrap()
    "\{fmt_num(k)}:[\{fmt_num(p.x)},\{fmt_num(p.y)}]"
  })
  js_str(parts.join(";"))
}

///|
extern "js" fn fmt_num(v : Double) -> String = "(v) => Object.is(v, -0) ? '-0' : String(v)"

///|
fn arg(args : @core.JsValue, i : Int) -> @core.JsValue {
  js_at(args, i)
}

///|
fn arg_num(args : @core.JsValue, i : Int) -> Double {
  js_at(args, i).cast()
}

///|
fn arg_opt_num(args : @core.JsValue, i : Int) -> Double? {
  let v = js_at(args, i)
  if js_is_nullish(v) {
    None
  } else {
    Some(v.cast())
  }
}

///|
fn vnum(v : @core.JsValue) -> Double {
  v.cast()
}

///|
fn vbool(v : @core.JsValue) -> Bool {
  v.cast()
}

///|
fn vstr(v : @core.JsValue) -> String {
  v.cast()
}

///|
fn vopt_num(v : @core.JsValue) -> Double? {
  if js_is_nullish(v) {
    None
  } else {
    Some(v.cast())
  }
}

///|
fn vopt_int(v : @core.JsValue) -> Int? {
  if js_is_nullish(v) {
    None
  } else {
    Some(vnum(v).to_int())
  }
}

///|
fn set_v3(target : @math.Vector3, v : @core.JsValue) -> Unit {
  ignore(target.set(vnum(js_at(v, 0)), vnum(js_at(v, 1)), vnum(js_at(v, 2))))
}

// objects

///|
pub fn perspective(
  fov : Double,
  aspect : Double,
  near : Double,
  far : Double,
) -> @core.JsValue {
  @core.JsValue::of(@core.PerspectiveCamera::new(fov~, aspect~, near~, far~))
}

///|
pub fn ortho(
  left : Double,
  right : Double,
  top : Double,
  bottom : Double,
  near : Double,
  far : Double,
) -> @core.JsValue {
  @core.JsValue::of(
    @core.OrthographicCamera::new(left~, right~, top~, bottom~, near~, far~),
  )
}

///|
fn obj(v : @core.JsValue) -> @core.Object3D {
  v.cast()
}

///|
pub fn set_vec(
  o : @core.JsValue,
  which : String,
  x : Double,
  y : Double,
  z : Double,
) -> Unit {
  let o = obj(o)
  match which {
    "position" => ignore(o.position.set(x, y, z))
    "up" => ignore(o.up.set(x, y, z))
    "scale" => ignore(o.scale.set(x, y, z))
    "rotation" => ignore(o.rotation.set(x, y, z))
    _ => abort("set_vec \{which}")
  }
}

///|
pub fn look_at(o : @core.JsValue, x : Double, y : Double, z : Double) -> Unit {
  obj(o).look_at_xyz(x, y, z)
}

///|
pub fn update_matrix_world(o : @core.JsValue) -> Unit {
  obj(o).update_matrix_world()
}

///|
pub fn add_child(parent : @core.JsValue, child : @core.JsValue) -> Unit {
  ignore(obj(parent).add(obj(child)))
}

///|
pub fn set_name(o : @core.JsValue, name : String) -> Unit {
  obj(o).name = name
}

///|
pub fn obj_name(o : @core.JsValue) -> String {
  obj(o).name
}

///|
extern "js" fn js_obj() -> @core.JsValue = "() => ({})"

///|
extern "js" fn js_set(o : @core.JsValue, k : String, v : @core.JsValue) -> Unit = "(o, k, v) => { o[k] = v; }"

///|
pub fn obj_state(o : @core.JsValue) -> @core.JsValue {
  let o = obj(o)
  let out = js_obj()
  js_set(out, "position", v3(o.position))
  js_set(out, "quaternion", q4(o.quaternion))
  js_set(out, "scale", v3(o.scale))
  js_set(out, "up", v3(o.up))
  js_set(out, "visible", bool(o.visible))
  js_set(out, "matrixWorld", m4(o.matrix_world))
  match o.kind {
    Camera({ kind: PerspectiveCamera(c), projection_matrix, .. }) => {
      js_set(out, "zoom", num(c.zoom))
      js_set(out, "fov", num(c.fov))
      js_set(out, "near", num(c.near))
      js_set(out, "far", num(c.far))
      js_set(out, "projectionMatrix", m4(projection_matrix))
    }
    Camera({ kind: OrthographicCamera(c), projection_matrix, .. }) => {
      js_set(out, "zoom", num(c.zoom))
      js_set(out, "near", num(c.near))
      js_set(out, "far", num(c.far))
      js_set(out, "projectionMatrix", m4(projection_matrix))
    }
    _ => ()
  }
  out
}

// events

///|
/// What run.mjs logs for an event's payload.
extern "js" fn describe(v : @core.JsValue) -> @core.JsValue = "(v) => globalThis.__describe(v)"

///|
fn listener(cb : (String, @core.JsValue) -> Unit) -> (@core.Event) -> Unit {
  fn(e) {
    let data = match e.data {
      Some(d) => describe(d)
      None => js_undefined()
    }
    cb(e.type_, data)
  }
}

// controls

///|
pub fn create(
  kind : String,
  camera : @core.JsValue,
  dom : @core.JsValue,
  extra : @core.JsValue,
) -> @core.JsValue {
  let camera = obj(camera)
  let dom_element = if js_is_nullish(dom) { None } else { Some(dom) }
  ignore(extra)
  match kind {
    "orbit" =>
      @core.JsValue::of(@controls.OrbitControls::new(camera, dom_element?))
    "map" => @core.JsValue::of(@controls.MapControls::new(camera, dom_element?))
    "fly" => @core.JsValue::of(@controls.FlyControls::new(camera, dom_element?))
    "firstperson" =>
      @core.JsValue::of(@controls.FirstPersonControls::new(camera, dom_element?))
    "pointerlock" =>
      @core.JsValue::of(@controls.PointerLockControls::new(camera, dom_element?))
    "trackball" =>
      @core.JsValue::of(@controls.TrackballControls::new(camera, dom_element?))
    "drag" => {
      let list = extra.get("objects")
      let objects = Array::makei(js_len(list), fn(i) { obj(js_at(list, i)) })
      @core.JsValue::of(@controls.DragControls::new(objects, camera, dom_element?))
    }
    "transform" =>
      @core.JsValue::of(@controls.TransformControls::new(camera, dom_element?))
    "arcball" => {
      let scene = if js_is_nullish(extra) || js_is_nullish(extra.get("scene")) {
        None
      } else {
        Some(obj(extra.get("scene")))
      }
      @core.JsValue::of(
        @controls.ArcballControls::new(camera, dom_element?, scene?),
      )
    }
    _ => abort("create \{kind}")
  }
}

///|
pub fn listen(
  ctrl : @core.JsValue,
  kind : String,
  type_ : String,
  cb : (String, @core.JsValue) -> Unit,
) -> Unit {
  match kind {
    "orbit" | "map" => {
      let c : @controls.OrbitControls = ctrl.cast()
      c.add_event_listener(type_, listener(cb))
    }
    "fly" => (ctrl.cast() : @controls.FlyControls).add_event_listener(type_, listener(cb))
    "firstperson" => (ctrl.cast() : @controls.FirstPersonControls).add_event_listener(type_, listener(cb))
    "pointerlock" => (ctrl.cast() : @controls.PointerLockControls).add_event_listener(type_, listener(cb))
    "trackball" => (ctrl.cast() : @controls.TrackballControls).add_event_listener(type_, listener(cb))
    "drag" => (ctrl.cast() : @controls.DragControls).add_event_listener(type_, listener(cb))
    "transform" => (ctrl.cast() : @controls.TransformControls).add_event_listener(type_, listener(cb))
    "arcball" => (ctrl.cast() : @controls.ArcballControls).add_event_listener(type_, listener(cb))
    _ => abort("listen \{kind}")
  }
}

///|
pub fn set(
  ctrl : @core.JsValue,
  kind : String,
  prop : String,
  value : @core.JsValue,
) -> Unit {
  match kind {
    "orbit" | "map" => orbit_set(ctrl.cast(), prop, value)
    "fly" => fly_set(ctrl.cast(), prop, value)
    "firstperson" => fp_set(ctrl.cast(), prop, value)
    "pointerlock" => pl_set(ctrl.cast(), prop, value)
    "trackball" => tb_set(ctrl.cast(), prop, value)
    "drag" => drag_set(ctrl.cast(), prop, value)
    "transform" => tc_set(ctrl.cast(), prop, value)
    "arcball" => ab_set(ctrl.cast(), prop, value)
    _ => abort("set \{kind}")
  }
}

///|
pub fn call(
  ctrl : @core.JsValue,
  kind : String,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match kind {
    "orbit" | "map" => orbit_call(ctrl.cast(), method, args)
    "fly" => fly_call(ctrl.cast(), method, args)
    "firstperson" => fp_call(ctrl.cast(), method, args)
    "pointerlock" => pl_call(ctrl.cast(), method, args)
    "trackball" => tb_call(ctrl.cast(), method, args)
    "drag" => drag_call(ctrl.cast(), method, args)
    "transform" => tc_call(ctrl.cast(), method, args)
    "arcball" => ab_call(ctrl.cast(), method, args)
    _ => abort("call \{kind}")
  }
}

///|
pub fn get(ctrl : @core.JsValue, kind : String, path : String) -> @core.JsValue {
  match kind {
    "orbit" | "map" => orbit_get(ctrl.cast(), path)
    "fly" => fly_get(ctrl.cast(), path)
    "firstperson" => fp_get(ctrl.cast(), path)
    "pointerlock" => pl_get(ctrl.cast(), path)
    "trackball" => tb_get(ctrl.cast(), path)
    "drag" => drag_get(ctrl.cast(), path)
    "transform" | "transform_full" => tc_get(ctrl.cast(), path)
    "arcball" => ab_get(ctrl.cast(), path)
    _ => abort("get \{kind}")
  }
}

///|
fn base_set(base : @extras.Controls, prop : String, v : @core.JsValue) -> Bool {
  match prop {
    "enabled" => base.enabled = vbool(v)
    "keys" => base.keys = v
    "mouseButtons" =>
      base.mouse_buttons = {
        left: vopt_int(v.get("LEFT")),
        middle: vopt_int(v.get("MIDDLE")),
        right: vopt_int(v.get("RIGHT")),
      }
    "touches" =>
      base.touches = {
        one: vopt_int(v.get("ONE")),
        two: vopt_int(v.get("TWO")),
      }
    _ => return false
  }
  true
}

///|
fn base_get(base : @extras.Controls, path : String) -> @core.JsValue? {
  match path {
    "enabled" => Some(bool(base.enabled))
    "state" => Some(num(base.state.to_double()))
    "keys" => Some(base.keys)
    "mouseButtons" =>
      Some(
        nums([
          opt_d(base.mouse_buttons.left),
          opt_d(base.mouse_buttons.middle),
          opt_d(base.mouse_buttons.right),
        ]),
      )
    "touches" => Some(nums([opt_d(base.touches.one), opt_d(base.touches.two)]))
    "domElement" =>
      Some(
        match base.dom_element {
          Some(d) => d
          None => js_null()
        },
      )
    _ => None
  }
}

///|
fn orbit_set(
  c : @controls.OrbitControls,
  prop : String,
  v : @core.JsValue,
) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "enableDamping" => c.enable_damping = vbool(v)
    "dampingFactor" => c.damping_factor = vnum(v)
    "autoRotate" => c.auto_rotate = vbool(v)
    "autoRotateSpeed" => c.auto_rotate_speed = vnum(v)
    "zoomToCursor" => c.zoom_to_cursor = vbool(v)
    "screenSpacePanning" => c.screen_space_panning = vbool(v)
    "minDistance" => c.min_distance = vnum(v)
    "maxDistance" => c.max_distance = vnum(v)
    "minZoom" => c.min_zoom = vnum(v)
    "maxZoom" => c.max_zoom = vnum(v)
    "minPolarAngle" => c.min_polar_angle = vnum(v)
    "maxPolarAngle" => c.max_polar_angle = vnum(v)
    "minAzimuthAngle" => c.min_azimuth_angle = vnum(v)
    "maxAzimuthAngle" => c.max_azimuth_angle = vnum(v)
    "minTargetRadius" => c.min_target_radius = vnum(v)
    "maxTargetRadius" => c.max_target_radius = vnum(v)
    "enableRotate" => c.enable_rotate = vbool(v)
    "enablePan" => c.enable_pan = vbool(v)
    "enableZoom" => c.enable_zoom = vbool(v)
    "rotateSpeed" => c.rotate_speed = vnum(v)
    "panSpeed" => c.pan_speed = vnum(v)
    "zoomSpeed" => c.zoom_speed = vnum(v)
    "keyPanSpeed" => c.key_pan_speed = vnum(v)
    "keyRotateSpeed" => c.key_rotate_speed = vnum(v)
    "target" => set_v3(c.target, v)
    "cursor" => set_v3(c.cursor, v)
    "cursorStyle" => c.set_cursor_style(vstr(v))
    _ => abort("orbit_set \{prop}")
  }
}

///|
fn orbit_call(
  c : @controls.OrbitControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "update" =>
      bool(
        if js_len(args) == 0 {
          c.update()
        } else {
          c.update(delta_time?=arg_opt_num(args, 0))
        },
      )
    "saveState" => {
      c.save_state()
      js_undefined()
    }
    "reset" => {
      c.reset()
      js_undefined()
    }
    "dispose" => {
      c.dispose()
      js_undefined()
    }
    "connect" => {
      c.connect(arg(args, 0))
      js_undefined()
    }
    "disconnect" => {
      c.disconnect()
      js_undefined()
    }
    "listenToKeyEvents" => {
      c.listen_to_key_events(arg(args, 0))
      js_undefined()
    }
    "stopListenToKeyEvents" => {
      c.stop_listen_to_key_events()
      js_undefined()
    }
    "pan" => {
      c.pan(arg_num(args, 0), arg_num(args, 1))
      js_undefined()
    }
    "dollyIn" => {
      c.dolly_in(arg_num(args, 0))
      js_undefined()
    }
    "dollyOut" => {
      c.dolly_out(arg_num(args, 0))
      js_undefined()
    }
    "rotateLeft" => {
      c.rotate_left(arg_num(args, 0))
      js_undefined()
    }
    "rotateUp" => {
      c.rotate_up(arg_num(args, 0))
      js_undefined()
    }
    "getDistance" => num(c.get_distance())
    "getPolarAngle" => num(c.get_polar_angle())
    "getAzimuthalAngle" => num(c.get_azimuthal_angle())
    _ => abort("orbit_call \{method}")
  }
}

///|
fn orbit_get(c : @controls.OrbitControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  match path {
    "target" => v3(c.target)
    "cursor" => v3(c.cursor)
    "target0" => v3(c.target0)
    "position0" => v3(c.position0)
    "zoom0" => num(c.zoom0)
    "cursorStyle" => js_str(c.cursor_style())
    "enablePan" => bool(c.enable_pan)
    "enableZoom" => bool(c.enable_zoom)
    "zoomToCursor" => bool(c.zoom_to_cursor)
    "_spherical" => sph(c._spherical)
    "_sphericalDelta" => sph(c._spherical_delta)
    "_scale" => num(c._scale)
    "_panOffset" => v3(c._pan_offset)
    "_rotateStart" => v2(c._rotate_start)
    "_rotateEnd" => v2(c._rotate_end)
    "_rotateDelta" => v2(c._rotate_delta)
    "_panStart" => v2(c._pan_start)
    "_panEnd" => v2(c._pan_end)
    "_panDelta" => v2(c._pan_delta)
    "_dollyStart" => v2(c._dolly_start)
    "_dollyEnd" => v2(c._dolly_end)
    "_dollyDelta" => v2(c._dolly_delta)
    "_dollyDirection" => v3(c._dolly_direction)
    "_mouse" => v2(c._mouse)
    "_performCursorZoom" => bool(c._perform_cursor_zoom)
    "_pointers" => nums(c._pointers)
    "_pointerPositions" => positions(c._pointer_positions)
    "_controlActive" => bool(c._control_active)
    "_lastPosition" => v3(c._last_position)
    "_lastQuaternion" => q4(c._last_quaternion)
    "_lastTargetPosition" => v3(c._last_target_position)
    "_quat" => q4(c._quat)
    "_quatInverse" => q4(c._quat_inverse)
    "_panWorldStart" =>
      match c._pan_world_start {
        Some(v) => v3(v)
        None => js_undefined()
      }
    "keys" => c.base.keys
    "mouseButtons" =>
      nums([
        opt_d(c.base.mouse_buttons.left),
        opt_d(c.base.mouse_buttons.middle),
        opt_d(c.base.mouse_buttons.right),
      ])
    "touches" =>
      nums([opt_d(c.base.touches.one), opt_d(c.base.touches.two)])
    _ => abort("orbit_get \{path}")
  }
}

///|
fn opt_d(v : Int?) -> Double {
  match v {
    Some(v) => v.to_double()
    None => -99.0
  }
}

///|
fn main {

}
