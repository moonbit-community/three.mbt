// Per-control set/call/get for the harness (keys are upstream's property names).

///|
fn undef() -> @core.JsValue {
  js_undefined()
}

///|
fn strs(values : Array[String]) -> @core.JsValue {
  let a = js_arr()
  for v in values {
    js_push(a, js_str(v))
  }
  a
}

///|
fn ids_of(events : Array[@core.JsValue]) -> @core.JsValue {
  nums(events.map(fn(e) { vnum(e.get("pointerId")) }))
}

// scene helpers

///|
pub fn scene() -> @core.JsValue {
  @core.JsValue::of(@core.Scene::new())
}

///|
pub fn group() -> @core.JsValue {
  @core.JsValue::of(@core.Group::new())
}

///|
pub fn box_mesh(w : Double, h : Double, d : Double) -> @core.JsValue {
  @core.JsValue::of(
    @core.Mesh::new(
      geometry=@geometries.BoxGeometry::new(width=w, height=h, depth=d),
      material=Single(@core.MeshBasicMaterial::new()),
    ),
  )
}

// fly

///|
fn fly_set(c : @controls.FlyControls, prop : String, v : @core.JsValue) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "movementSpeed" => c.movement_speed = vnum(v)
    "rollSpeed" => c.roll_speed = vnum(v)
    "dragToLook" => c.drag_to_look = vbool(v)
    "autoForward" => c.auto_forward = vbool(v)
    _ => abort("fly_set \{prop}")
  }
}

///|
fn fly_call(
  c : @controls.FlyControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "update" => c.update(arg_num(args, 0))
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("fly_call \{method}")
  }
  undef()
}

///|
fn fly_get(c : @controls.FlyControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  let m = c._move_state
  match path {
    "movementSpeedMultiplier" =>
      match c.movement_speed_multiplier {
        Some(v) => num(v)
        None => undef()
      }
    "_moveState" =>
      nums([
        m.up,
        m.down,
        m.left,
        m.right,
        m.forward,
        m.back,
        m.pitch_up,
        m.pitch_down,
        m.yaw_left,
        m.yaw_right,
        m.roll_left,
        m.roll_right,
      ])
    "_moveVector" => v3(c._move_vector)
    "_rotationVector" => v3(c._rotation_vector)
    "_lastQuaternion" => q4(c._last_quaternion)
    "_lastPosition" => v3(c._last_position)
    "_status" => num(c._status.to_double())
    _ => abort("fly_get \{path}")
  }
}

// first person

///|
fn fp_set(
  c : @controls.FirstPersonControls,
  prop : String,
  v : @core.JsValue,
) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "movementSpeed" => c.movement_speed = vnum(v)
    "lookSpeed" => c.look_speed = vnum(v)
    "dampingFactor" => c.damping_factor = vnum(v)
    "lookVertical" => c.look_vertical = vbool(v)
    "autoForward" => c.auto_forward = vbool(v)
    "heightSpeed" => c.height_speed = vbool(v)
    "heightCoef" => c.height_coef = vnum(v)
    "heightMin" => c.height_min = vnum(v)
    "heightMax" => c.height_max = vnum(v)
    "constrainVertical" => c.constrain_vertical = vbool(v)
    "verticalMin" => c.vertical_min = vnum(v)
    "verticalMax" => c.vertical_max = vnum(v)
    _ => abort("fp_set \{prop}")
  }
}

///|
fn fp_call(
  c : @controls.FirstPersonControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "update" => c.update(arg_num(args, 0))
    "lookAt" =>
      if js_len(args) == 3 {
        ignore(c.look_at_xyz(arg_num(args, 0), arg_num(args, 1), arg_num(args, 2)))
      } else {
        let t = @math.Vector3::new(0.0, 0.0, 0.0)
        set_v3(t, arg(args, 0))
        ignore(c.look_at(t))
      }
    "handleResize" => c.handle_resize()
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("fp_call \{method}")
  }
  undef()
}

///|
fn fp_get(c : @controls.FirstPersonControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  match path {
    "mouseDragOn" => bool(c.mouse_drag_on)
    "_velocity" => v3(c._velocity)
    "_pointerX" => num(c._pointer_x)
    "_pointerY" => num(c._pointer_y)
    "_pointerDownX" => num(c._pointer_down_x)
    "_pointerDownY" => num(c._pointer_down_y)
    "_pointerCount" => num(c._pointer_count.to_double())
    "_keyForward" => bool(c._key_forward)
    "_keyBackward" => bool(c._key_backward)
    "_pointerForward" => bool(c._pointer_forward)
    "_pointerBackward" => bool(c._pointer_backward)
    "_moveLeft" => bool(c._move_left)
    "_moveRight" => bool(c._move_right)
    "_moveUp" => bool(c._move_up)
    "_moveDown" => bool(c._move_down)
    "_lat" => num(c._lat)
    "_lon" => num(c._lon)
    "_lonVelocity" => num(c._lon_velocity)
    "_latVelocity" => num(c._lat_velocity)
    _ => abort("fp_get \{path}")
  }
}

// pointer lock

///|
fn pl_set(
  c : @controls.PointerLockControls,
  prop : String,
  v : @core.JsValue,
) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "minPolarAngle" => c.min_polar_angle = vnum(v)
    "maxPolarAngle" => c.max_polar_angle = vnum(v)
    "pointerSpeed" => c.pointer_speed = vnum(v)
    _ => abort("pl_set \{prop}")
  }
}

///|
fn pl_call(
  c : @controls.PointerLockControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "getDirection" => return v3(c.get_direction(@math.Vector3::new(9.0, 9.0, 9.0)))
    "moveForward" => c.move_forward(arg_num(args, 0))
    "moveRight" => c.move_right(arg_num(args, 0))
    "lock" =>
      if js_len(args) == 0 {
        c.lock()
      } else {
        c.lock(unadjusted_movement=vbool(arg(args, 0)))
      }
    "unlock" => c.unlock()
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("pl_call \{method}")
  }
  undef()
}

///|
fn pl_get(c : @controls.PointerLockControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  match path {
    "isLocked" => bool(c.is_locked)
    _ => abort("pl_get \{path}")
  }
}

// trackball

///|
fn tb_set(
  c : @controls.TrackballControls,
  prop : String,
  v : @core.JsValue,
) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "rotateSpeed" => c.rotate_speed = vnum(v)
    "zoomSpeed" => c.zoom_speed = vnum(v)
    "panSpeed" => c.pan_speed = vnum(v)
    "rollSpeed" => c.roll_speed = vnum(v)
    "noRotate" => c.no_rotate = vbool(v)
    "noZoom" => c.no_zoom = vbool(v)
    "noPan" => c.no_pan = vbool(v)
    "multiTouchRoll" => c.multi_touch_roll = vbool(v)
    "staticMoving" => c.static_moving = vbool(v)
    "dynamicDampingFactor" => c.dynamic_damping_factor = vnum(v)
    "minDistance" => c.min_distance = vnum(v)
    "maxDistance" => c.max_distance = vnum(v)
    "minZoom" => c.min_zoom = vnum(v)
    "maxZoom" => c.max_zoom = vnum(v)
    "target" => set_v3(c.target, v)
    _ => abort("tb_set \{prop}")
  }
}

///|
fn tb_call(
  c : @controls.TrackballControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "update" => c.update()
    "reset" => c.reset()
    "handleResize" => c.handle_resize()
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("tb_call \{method}")
  }
  undef()
}

///|
fn tb_get(c : @controls.TrackballControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  match path {
    "screen" =>
      nums([c.screen.left, c.screen.top, c.screen.width, c.screen.height])
    "keyState" => num(c.key_state.to_double())
    "target" => v3(c.target)
    "_lastPosition" => v3(c._last_position)
    "_lastUp" => v3(c._last_up)
    "_lastZoom" => num(c._last_zoom)
    "_touchZoomDistanceStart" => num(c._touch_zoom_distance_start)
    "_touchZoomDistanceEnd" => num(c._touch_zoom_distance_end)
    "_touchRollAngle" => num(c._touch_roll_angle)
    "_touchRollPointerIds" => js_str(c._touch_roll_pointer_ids)
    "_lastAngle" => num(c._last_angle)
    "_lastRollAngle" => num(c._last_roll_angle)
    "_eye" => v3(c._eye)
    "_movePrev" => v2(c._move_prev)
    "_moveCurr" => v2(c._move_curr)
    "_lastAxis" => v3(c._last_axis)
    "_zoomStart" => v2(c._zoom_start)
    "_zoomEnd" => v2(c._zoom_end)
    "_panStart" => v2(c._pan_start)
    "_panEnd" => v2(c._pan_end)
    "_pointers" => ids_of(c._pointers)
    "_pointerPositions" => positions(c._pointer_positions)
    "_target0" => v3(c._target0)
    "_position0" => v3(c._position0)
    "_up0" => v3(c._up0)
    "_zoom0" => num(c._zoom0)
    _ => abort("tb_get \{path}")
  }
}

// drag

///|
fn drag_set(c : @controls.DragControls, prop : String, v : @core.JsValue) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "recursive" => c.recursive = vbool(v)
    "transformGroup" => c.transform_group = vbool(v)
    "rotateSpeed" => c.rotate_speed = vnum(v)
    _ => abort("drag_set \{prop}")
  }
}

///|
fn drag_call(
  c : @controls.DragControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("drag_call \{method}")
  }
  undef()
}

///|
fn drag_get(c : @controls.DragControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  match path {
    "recursive" => bool(c.recursive)
    "transformGroup" => bool(c.transform_group)
    "raycaster.ray.origin" => v3(c.raycaster.ray.origin)
    "raycaster.ray.direction" => v3(c.raycaster.ray.direction)
    _ => abort("drag_get \{path}")
  }
}

// transform

///|
fn tc_set(
  c : @controls.TransformControls,
  prop : String,
  v : @core.JsValue,
) -> Unit {
  match prop {
    "enabled" => c.set_enabled(vbool(v))
    "mode" => c.set_mode(vstr(v))
    "space" => c.set_space(vstr(v))
    "size" => c.set_size(vnum(v))
    "translationSnap" => c.set_translation_snap(vopt_num(v))
    "rotationSnap" => c.set_rotation_snap(vopt_num(v))
    "scaleSnap" => c.set_scale_snap(vopt_num(v))
    "showX" => c.set_show_x(vbool(v))
    "showY" => c.set_show_y(vbool(v))
    "showZ" => c.set_show_z(vbool(v))
    "showXY" => c.set_show_xy(vbool(v))
    "showYZ" => c.set_show_yz(vbool(v))
    "showXZ" => c.set_show_xz(vbool(v))
    "showXYZE" => c.set_show_xyze(vbool(v))
    "showE" => c.set_show_e(vbool(v))
    "minX" => c.set_min_x(vnum(v))
    "maxX" => c.set_max_x(vnum(v))
    "minY" => c.set_min_y(vnum(v))
    "maxY" => c.set_max_y(vnum(v))
    "minZ" => c.set_min_z(vnum(v))
    "maxZ" => c.set_max_z(vnum(v))
    "axis" =>
      c.set_axis(
        if js_is_nullish(v) {
          None
        } else {
          Some(vstr(v))
        },
      )
    "camera" => c.set_camera(obj(v))
    "viewport" =>
      c.set_viewport(
        if js_is_nullish(v) {
          None
        } else {
          Some(
            @math.Vector4::new(
              vnum(v.get("x")),
              vnum(v.get("y")),
              vnum(v.get("z")),
              vnum(v.get("w")),
            ),
          )
        },
      )
    _ => abort("tc_set \{prop}")
  }
}

///|
fn tc_pointer(v : @core.JsValue) -> @controls.TransformControlsPointer? {
  if js_is_nullish(v) {
    None
  } else {
    Some({ x: vnum(v.get("x")), y: vnum(v.get("y")), button: vnum(v.get("button")) })
  }
}

///|
fn tc_call(
  c : @controls.TransformControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  match method {
    "attach" => ignore(c.attach(obj(arg(args, 0))))
    "detach" => ignore(c.detach())
    "reset" => c.reset()
    "getMode" => return js_str(c.get_mode())
    "setMode" => c.set_mode(vstr(arg(args, 0)))
    "setSpace" => c.set_space(vstr(arg(args, 0)))
    "setSize" => c.set_size(arg_num(args, 0))
    "setTranslationSnap" => c.set_translation_snap(arg_opt_num(args, 0))
    "setRotationSnap" => c.set_rotation_snap(arg_opt_num(args, 0))
    "setScaleSnap" => c.set_scale_snap(arg_opt_num(args, 0))
    "setColors" =>
      c.set_colors_hex(
        arg_num(args, 0).to_int(),
        arg_num(args, 1).to_int(),
        arg_num(args, 2).to_int(),
        arg_num(args, 3).to_int(),
      )
    "pointerHover" => c.pointer_hover(tc_pointer(arg(args, 0)))
    "pointerDown" => c.pointer_down(tc_pointer(arg(args, 0)))
    "pointerMove" => c.pointer_move(tc_pointer(arg(args, 0)))
    "pointerUp" => c.pointer_up(tc_pointer(arg(args, 0)))
    "getHelper" => return @core.JsValue::of(c.get_helper())
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("tc_call \{method}")
  }
  undef()
}

///|
/// Every handle of the gizmo: name, visibility, transform and highlight.
fn tc_handles(c : @controls.TransformControls) -> @core.JsValue {
  let gizmo = @controls.TransformControlsGizmo::of(c._gizmo).unwrap()
  let out = js_arr()
  for group in [gizmo.picker, gizmo.gizmo, gizmo.helper] {
    for mode in ["translate", "rotate", "scale"] {
      let g = group.get(mode).unwrap()
      js_push(out, js_str("\{mode} group visible=\{g.visible}"))
      for h in g.children {
        let m = match h.get_material() {
          Some(Single(m)) => m
          _ => abort("material")
        }
        let col = m.color.unwrap()
        js_push(
          out,
          js_str(
            "\{h.name} v=\{h.visible} p=\{fmt3(h.position)} q=\{fmtq(h.quaternion)} s=\{fmt3(h.scale)} c=\{fmt_num(col.r)},\{fmt_num(col.g)},\{fmt_num(col.b)} o=\{fmt_num(m.opacity)} mw=\{fmt_m(h.matrix_world)}",
          ),
        )
      }
    }
  }
  out
}

///|
fn fmt3(v : @math.Vector3) -> String {
  "\{fmt_num(v.x)},\{fmt_num(v.y)},\{fmt_num(v.z)}"
}

///|
fn fmtq(v : @math.Quaternion) -> String {
  "\{fmt_num(v.x)},\{fmt_num(v.y)},\{fmt_num(v.z)},\{fmt_num(v.w)}"
}

///|
fn fmt_m(m : @math.Matrix4) -> String {
  m.elements.map(fmt_num).join(",")
}

///|
fn tc_get(c : @controls.TransformControls, path : String) -> @core.JsValue {
  match path {
    "enabled" => bool(c.enabled)
    "object" =>
      match c.object {
        Some(o) => js_str("obj:" + o.name)
        None => undef()
      }
    "camera" => js_str("obj:" + c.camera.name)
    "axis" => opt_str(c.axis)
    "mode" => js_str(c.mode)
    "translationSnap" => opt_num(c.translation_snap)
    "rotationSnap" => opt_num(c.rotation_snap)
    "scaleSnap" => opt_num(c.scale_snap)
    "space" => js_str(c.space)
    "size" => num(c.size)
    "dragging" => bool(c.dragging)
    "showX" => bool(c.show_x)
    "showE" => bool(c.show_e)
    "minX" => num(c.min_x)
    "maxZ" => num(c.max_z)
    "worldPosition" => v3(c.world_position)
    "worldPositionStart" => v3(c.world_position_start)
    "worldQuaternion" => q4(c.world_quaternion)
    "worldQuaternionStart" => q4(c.world_quaternion_start)
    "cameraPosition" => v3(c.camera_position)
    "cameraQuaternion" => q4(c.camera_quaternion)
    "pointStart" => v3(c.point_start)
    "pointEnd" => v3(c.point_end)
    "rotationAxis" => v3(c.rotation_axis)
    "rotationAngle" => num(c.rotation_angle)
    "eye" => v3(c.eye)
    "_offset" => v3(c._offset)
    "_startNorm" => v3(c._start_norm)
    "_endNorm" => v3(c._end_norm)
    "_cameraScale" => v3(c._camera_scale)
    "_parentPosition" => v3(c._parent_position)
    "_parentQuaternion" => q4(c._parent_quaternion)
    "_parentQuaternionInv" => q4(c._parent_quaternion_inv)
    "_parentScale" => v3(c._parent_scale)
    "_worldScaleStart" => v3(c._world_scale_start)
    "_worldQuaternionInv" => q4(c._world_quaternion_inv)
    "_worldScale" => v3(c._world_scale)
    "_positionStart" => v3(c._position_start)
    "_quaternionStart" => q4(c._quaternion_start)
    "_scaleStart" => v3(c._scale_start)
    "_root.visible" => bool(c._root.visible)
    "_root.matrixWorld" => m4(c._root.matrix_world)
    "_plane.position" => v3(c._plane.position)
    "_plane.quaternion" => q4(c._plane.quaternion)
    "_plane.matrixWorld" => m4(c._plane.matrix_world)
    "_gizmo.mode" => js_str(c._gizmo_state.mode)
    "_gizmo.axis" => opt_str(c._gizmo_state.axis)
    "_gizmo.dragging" => bool(c._gizmo_state.dragging)
    "_gizmo.rotationAngle" => num(c._gizmo_state.rotation_angle)
    "_plane.space" => js_str(c._plane_state.space)
    "_plane.axis" => opt_str(c._plane_state.axis)
    "handles" => tc_handles(c)
    _ => abort("tc_get \{path}")
  }
}

// arcball

///|
fn ab_state_name(s : @controls.ArcballState) -> String {
  match s {
    Idle => "IDLE"
    Rotate => "ROTATE"
    Pan => "PAN"
    Scale => "SCALE"
    Fov => "FOV"
    Focus => "FOCUS"
    ZRotate => "ZROTATE"
    TouchMulti => "TOUCH_MULTI"
    AnimationFocus => "ANIMATION_FOCUS"
    AnimationRotate => "ANIMATION_ROTATE"
  }
}

///|
fn ab_input_name(s : @controls.ArcballInput) -> String {
  match s {
    None => "NONE"
    OneFinger => "ONE_FINGER"
    OneFingerSwitched => "ONE_FINGER_SWITCHED"
    TwoFinger => "TWO_FINGER"
    MultFinger => "MULT_FINGER"
    Cursor => "CURSOR"
  }
}

///|
fn ab_mouse(v : @core.JsValue) -> @controls.ArcballMouse {
  if js_typeof_str(v) {
    Wheel
  } else {
    Button(vnum(v).to_int())
  }
}

///|
extern "js" fn js_typeof_str(v : @core.JsValue) -> Bool = "(v) => typeof v === 'string'"

///|
fn ab_set(c : @controls.ArcballControls, prop : String, v : @core.JsValue) -> Unit {
  if base_set(c.base, prop, v) {
    return
  }
  match prop {
    "adjustNearFar" => c.adjust_near_far = vbool(v)
    "scaleFactor" => c.scale_factor = vnum(v)
    "dampingFactor" => c.damping_factor = vnum(v)
    "wMax" => c.w_max = vnum(v)
    "enableAnimations" => c.enable_animations = vbool(v)
    "enableGrid" => c.enable_grid = vbool(v)
    "cursorZoom" => c.cursor_zoom = vbool(v)
    "minFov" => c.min_fov = vnum(v)
    "maxFov" => c.max_fov = vnum(v)
    "rotateSpeed" => c.rotate_speed = vnum(v)
    "enablePan" => c.enable_pan = vbool(v)
    "enableRotate" => c.enable_rotate = vbool(v)
    "enableZoom" => c.enable_zoom = vbool(v)
    "enableGizmos" => c.enable_gizmos = vbool(v)
    "enableFocus" => c.enable_focus = vbool(v)
    "minDistance" => c.min_distance = vnum(v)
    "maxDistance" => c.max_distance = vnum(v)
    "minZoom" => c.min_zoom = vnum(v)
    "maxZoom" => c.max_zoom = vnum(v)
    "focusAnimationTime" => c.focus_animation_time = vnum(v)
    "radiusFactor" => c.radius_factor = vnum(v)
    "target" => set_v3(c.target, v)
    _ => abort("ab_set \{prop}")
  }
}

///|
fn ab_call(
  c : @controls.ArcballControls,
  method : String,
  args : @core.JsValue,
) -> @core.JsValue {
  let key = fn(i : Int) -> String? {
    let v = arg(args, i)
    if js_is_nullish(v) {
      None
    } else {
      Some(vstr(v))
    }
  }
  match method {
    "update" => c.update()
    "reset" => c.reset()
    "saveState" => c.save_state()
    "copyState" => c.copy_state()
    "pasteState" => c.paste_state()
    "setStateFromJSON" => c.set_state_from_json(vstr(arg(args, 0)))
    "setGizmosVisible" => c.set_gizmos_visible(vbool(arg(args, 0)))
    "setTbRadius" => c.set_tb_radius(arg_num(args, 0))
    "setMouseAction" =>
      return bool(
        c.set_mouse_action(vstr(arg(args, 0)), ab_mouse(arg(args, 1)), key?=key(2)),
      )
    "unsetMouseAction" =>
      return bool(c.unset_mouse_action(ab_mouse(arg(args, 0)), key?=key(1)))
    "setCamera" => c.set_camera(obj(arg(args, 0)))
    "dispose" => c.dispose()
    "connect" => c.connect(arg(args, 0))
    "disconnect" => c.disconnect()
    _ => abort("ab_call \{method}")
  }
  undef()
}

///|
fn ab_get(c : @controls.ArcballControls, path : String) -> @core.JsValue {
  if base_get(c.base, path) is Some(v) {
    return v
  }
  match path {
    "target" => v3(c.target)
    "_currentTarget" => v3(c._current_target)
    "radiusFactor" => num(c.radius_factor)
    "_state" => js_str(ab_state_name(c._state))
    "_input" => js_str(ab_input_name(c._input))
    "_mouseOp" => opt_str(c._mouse_op)
    "_rotationAxis" => v3(c._rotation_axis)
    "_cameraMatrixState" => m4(c._camera_matrix_state)
    "_cameraProjectionState" => m4(c._camera_projection_state)
    "_fovState" => num(c._fov_state)
    "_upState" => v3(c._up_state)
    "_zoomState" => num(c._zoom_state)
    "_nearPos" => num(c._near_pos)
    "_farPos" => num(c._far_pos)
    "_gizmoMatrixState" => m4(c._gizmo_matrix_state)
    "_up0" => v3(c._up0)
    "_zoom0" => num(c._zoom0)
    "_fov0" => num(c._fov0)
    "_initialNear" => num(c._initial_near)
    "_nearPos0" => num(c._near_pos0)
    "_initialFar" => num(c._initial_far)
    "_farPos0" => num(c._far_pos0)
    "_cameraMatrixState0" => m4(c._camera_matrix_state0)
    "_gizmoMatrixState0" => m4(c._gizmo_matrix_state0)
    "_target0" => v3(c._target0)
    "_button" => num(c._button)
    "_touchStart" => ids_of(c._touch_start)
    "_touchCurrent" => ids_of(c._touch_current)
    "_startFingerDistance" => num(c._start_finger_distance)
    "_currentFingerDistance" => num(c._current_finger_distance)
    "_startFingerRotation" => num(c._start_finger_rotation)
    "_currentFingerRotation" => num(c._current_finger_rotation)
    "_devPxRatio" => num(c._dev_px_ratio)
    "_downValid" => bool(c._down_valid)
    "_nclicks" => num(c._nclicks.to_double())
    "_downEvents" =>
      nums(c._down_events.map(fn(e) { vnum(e.get("timeStamp")) }))
    "_downStart" => num(c._down_start)
    "_clickStart" => num(c._click_start)
    "_currentCursorPosition" => v3(c._current_cursor_position)
    "_startCursorPosition" => v3(c._start_cursor_position)
    "_grid" =>
      match c._grid {
        Some(g) => js_str("grid " + fmt3(g.position) + " " + fmtq(g.quaternion))
        None => js_null()
      }
    "_gridPosition" => v3(c._grid_position)
    "_gizmos" => {
      let g = c._gizmos
      let parts = [
        "v=\{g.visible} p=\{fmt3(g.position)} q=\{fmtq(g.quaternion)} s=\{fmt3(g.scale)} m=\{fmt_m(g.matrix)}",
      ]
      for ch in g.children {
        let m = match ch.get_material() {
          Some(Single(m)) => m
          _ => abort("material")
        }
        let pos = ch.get_geometry().unwrap().get_attribute("position").unwrap()
        parts.push(
          "o=\{fmt_num(m.opacity)} n=\{pos.count()} r=\{fmtq(ch.quaternion)} x0=\{fmt_num(pos.get_x(1))}",
        )
      }
      js_str(parts.join(" | "))
    }
    "_timeStart" => num(c._time_start)
    "_animationId" => num(c._animation_id)
    "_timePrev" => num(c._time_prev)
    "_timeCurrent" => num(c._time_current)
    "_anglePrev" => num(c._angle_prev)
    "_angleCurrent" => num(c._angle_current)
    "_cursorPosPrev" => v3(c._cursor_pos_prev)
    "_cursorPosCurr" => v3(c._cursor_pos_curr)
    "_wPrev" => num(c._w_prev)
    "_wCurr" => num(c._w_curr)
    "_tbRadius" => num(c._tb_radius)
    "mouseActions" =>
      strs(
        c.mouse_actions.map(fn(a) {
          let mouse = match a.mouse {
            Button(b) => b.to_string()
            Wheel => "WHEEL"
          }
          let key = match a.key {
            Some(k) => k
            None => "null"
          }
          "\{a.operation}:\{mouse}:\{key}:\{ab_state_name(a.state)}"
        }),
      )
    _ => abort("ab_get \{path}")
  }
}
