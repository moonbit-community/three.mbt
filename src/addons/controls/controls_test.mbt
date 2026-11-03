// Upstream has no unit tests for the controls; these check the DOM-free paths. The
// event-driven behaviour is checked against upstream by the differential harness
// (diff/addons/controls, `node run.mjs`).

///|
fn camera_at(x : Double, y : Double, z : Double) -> @core.Object3D {
  let camera = @core.PerspectiveCamera::new(
    fov=50.0,
    aspect=1.5,
    near=0.1,
    far=100.0,
  )
  ignore(camera.position.set(x, y, z))
  camera
}

///|
fn approx_eq(a : Double, b : Double) -> Bool {
  (a - b).abs() < 1.0e-9
}

///|
test "OrbitControls orbits and resets" {
  let camera = camera_at(0.0, 0.0, 10.0)
  let controls = @controls.OrbitControls::new(camera)
  let mut changes = 0
  controls.add_event_listener("change", fn(_) { changes += 1 })
  assert_true(approx_eq(controls.get_distance(), 10.0))
  assert_true(approx_eq(controls.get_azimuthal_angle(), 0.0))
  controls.rotate_left(0.5)
  assert_true(approx_eq(controls.get_azimuthal_angle(), -0.5))
  assert_true(approx_eq(controls.get_distance(), 10.0))
  assert_eq(changes, 1)
  controls.dolly_in(0.5)
  assert_true(approx_eq(controls.get_distance(), 5.0))
  controls.reset()
  assert_true(approx_eq(camera.position.z, 10.0))
  assert_true(approx_eq(controls.get_azimuthal_angle(), 0.0))
  assert_true(changes >= 3)
}

///|
test "OrbitControls update reports changes and damping coasts" {
  let camera = camera_at(3.0, 4.0, 10.0)
  let controls = @controls.OrbitControls::new(camera)
  assert_false(controls.update())
  controls.enable_damping = true
  controls.rotate_up(0.2)
  let first = controls.get_polar_angle()
  assert_true(controls.update())
  assert_true(controls.get_polar_angle() < first)
  controls.max_distance = 5.0
  assert_true(controls.update())
  assert_true(approx_eq(controls.get_distance(), 5.0))
}

///|
test "OrbitControls drives the base Controls" {
  let controls = @controls.OrbitControls::new(camera_at(0.0, 0.0, 5.0))
  controls.auto_rotate = true
  let before = controls.get_azimuthal_angle()
  controls.base.update(delta=1.0)
  assert_true(controls.get_azimuthal_angle() < before)
  assert_eq(controls.base.mouse_buttons.left, Some(@core.MOUSE_ROTATE))
}

///|
test "MapControls defaults" {
  let controls = @controls.MapControls::new(camera_at(0.0, 10.0, 0.0))
  assert_true(controls.is_map_controls())
  assert_false(controls.screen_space_panning)
  assert_eq(controls.base.mouse_buttons.left, Some(@core.MOUSE_PAN))
  assert_eq(controls.base.touches.two, Some(@core.TOUCH_DOLLY_ROTATE))
  assert_false(
    @controls.OrbitControls::new(camera_at(0.0, 0.0, 1.0)).is_map_controls(),
  )
}

///|
test "TrackballControls update and reset" {
  let camera = camera_at(0.0, 0.0, 10.0)
  let controls = @controls.TrackballControls::new(camera)
  controls.target.x = 1.0
  controls.update()
  assert_true(approx_eq(controls.target.x, 1.0))
  controls.reset()
  assert_true(approx_eq(controls.target.x, 0.0))
  assert_true(approx_eq(camera.position.z, 10.0))
}

///|
test "FlyControls and FirstPersonControls move the camera" {
  let camera = camera_at(0.0, 0.0, 0.0)
  let fly = @controls.FlyControls::new(camera)
  fly.update(0.5)
  assert_true(approx_eq(camera.position.z, 0.0))
  let first_person = @controls.FirstPersonControls::new(camera)
  first_person.auto_forward = true
  first_person.update(1.0)
  assert_true(camera.position.z < 0.0)
  let looker = @controls.FirstPersonControls::new(camera_at(0.0, 0.0, 0.0))
  ignore(looker.look_at_xyz(1.0, 0.0, 0.0))
  assert_true(approx_eq(looker._lon, 90.0))
}

///|
test "PointerLockControls moves parallel to the ground" {
  let camera = camera_at(0.0, 1.0, 0.0)
  camera.update_matrix()
  let controls = @controls.PointerLockControls::new(camera)
  controls.move_forward(2.0)
  assert_true(approx_eq(camera.position.z, -2.0))
  controls.move_right(1.0)
  assert_true(approx_eq(camera.position.x, 1.0))
  let direction = controls.get_direction(@math.Vector3::new(0.0, 0.0, 0.0))
  assert_true(approx_eq(direction.z, -1.0))
  controls.base.enabled = false
  controls.move_forward(5.0)
  assert_true(approx_eq(camera.position.z, -2.0))
}

///|
test "TransformControls properties fire events" {
  let camera = camera_at(3.0, 4.0, 6.0)
  let controls = @controls.TransformControls::new(camera)
  let log : Array[String] = []
  controls.add_event_listener("mode-changed", fn(e) { log.push(e.type_) })
  controls.add_event_listener("change", fn(e) { log.push(e.type_) })
  controls.set_mode("rotate")
  controls.set_mode("rotate")
  assert_eq(log, ["mode-changed", "change"])
  assert_eq(controls.get_mode(), "rotate")
  let scene = @core.Scene::new()
  let box_ = @core.Mesh::new(
    geometry=@geometries.BoxGeometry::new(),
    material=Single(@core.MeshBasicMaterial::new()),
  )
  ignore(scene.add(box_))
  ignore(scene.add(controls.get_helper()))
  ignore(controls.attach(box_))
  assert_true(controls.get_helper().visible)
  scene.update_matrix_world()
  let gizmo = @controls.TransformControlsGizmo::of(
    controls.get_helper().children[0],
  ).unwrap()
  assert_eq(gizmo.state.mode, "rotate")
  assert_true(gizmo.gizmo.get("rotate").unwrap().visible)
  assert_false(gizmo.gizmo.get("translate").unwrap().visible)
  ignore(controls.detach())
  assert_false(controls.get_helper().visible)
}

///|
test "ArcballControls mouse actions" {
  let camera = camera_at(0.0, 0.0, 10.0)
  let controls = @controls.ArcballControls::new(camera)
  assert_eq(controls.mouse_actions.length(), 7)
  assert_false(controls.set_mouse_action("ROTATE", Wheel))
  assert_false(controls.set_mouse_action("PAN", Button(3)))
  assert_true(controls.set_mouse_action("FOV", Button(2)))
  assert_eq(controls.mouse_actions.length(), 7)
  assert_eq(
    controls.get_op_from_action(Some(Button(2)), Some("SHIFT")),
    Some("FOV"),
  )
  assert_true(controls.unset_mouse_action(Button(2)))
  assert_eq(controls.get_op_from_action(Some(Button(2)), None), None)
  assert_eq(controls._gizmos.children.length(), 3)
  controls.target.x = 1.0
  controls.update()
  assert_true(approx_eq(controls._gizmos.position.x, 1.0))
}

///|
test "DragControls defaults" {
  let controls = @controls.DragControls::new([], camera_at(0.0, 0.0, 5.0))
  assert_true(controls.recursive)
  assert_eq(controls.base.mouse_buttons.right, Some(@core.MOUSE_ROTATE))
  assert_eq(controls.base.touches.one, Some(@core.TOUCH_PAN))
}
